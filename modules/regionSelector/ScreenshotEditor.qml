pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Unified capture flow for the screenshotEdit action: one screen, one dock,
// no phases. Captures the full screen, shows it dimmed full-bleed with the
// complete annotation toolbar (pen/rect/arrow/text/highlight/move) active
// from the start, and a crop rectangle — defaulting to the full screen,
// resizable via corner handles at any time — that Done exports to.
// Self-contained on purpose — a separate file from AnnotationEditor.qml so
// the other region-selector actions (copy/search/ocr/record/the old Edit
// path) stay untouched.
// Multi-monitor: one editor instance per output for dim+capture, but only one
// output is interactive (first press claims). Exclusive keyboard focus follows
// the claimed (or initially focused) output so Esc/Enter don't fight.
PanelWindow {
    id: root
    visible: true
    color: "transparent"
    WlrLayershell.namespace: "quickshell:screenshotEditor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.hasKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }

    signal dismiss()

    function close() { root.dismiss(); }

    readonly property string focusedOutputName: CompositorService.isNiri
        ? (NiriService.currentOutput ?? "")
        : (Hyprland.focusedMonitor?.name ?? "")
    // First click claims this output for the whole session; others stay dim-only.
    readonly property bool isActiveEditor: GlobalStates.screenshotEditorActiveScreen === root.screen.name
    readonly property bool canInteract: GlobalStates.screenshotEditorActiveScreen === "" || root.isActiveEditor
    // Keyboard: claimed output wins. Before claim, only the compositor-focused
    // output (or screens[0]) — never all outputs, or Exclusive focus thrashs.
    readonly property bool hasKeyboardFocus: {
        const active = GlobalStates.screenshotEditorActiveScreen;
        if (active !== "")
            return active === root.screen.name;
        const focused = root.focusedOutputName;
        if (focused !== "")
            return focused === root.screen.name;
        return Quickshell.screens.length > 0 && Quickshell.screens[0].name === root.screen.name;
    }

    // Only stamp the active output. Do NOT forceActiveFocus / flip layershell
    // keyboard ownership here — that runs mid-press and can drop the pointer
    // grab (fast crop "sticks" with cropDrawing true / a 0×0 crop that blocks
    // a second try). Focus is applied on release via endPointerGesture().
    function claimActive() {
        if (GlobalStates.screenshotEditorActiveScreen === "")
            GlobalStates.screenshotEditorActiveScreen = root.screen.name;
    }

    // True while color popup (or similar) owns Esc — don't dismiss the whole editor.
    property bool suppressGlobalKeys: false
    // True only for a crop large enough to keep (not the live 0×0 press seed).
    property bool hasCrop: false
    // Pointer is down on this editor — suppress focus thrash mid-gesture.
    property bool pointerDown: false

    function endPointerGesture() {
        root.pointerDown = false;
        if (root.hasKeyboardFocus)
            root.focusKeySink();
    }

    function cropIsValid(c) {
        return c !== null && c !== undefined && c.w >= root.cropMinSize && c.h >= root.cropMinSize;
    }

    // ApplicationShortcut: layershell windows are often not Qt-"active", so
    // WindowShortcut silently never fires.
    // Esc dismisses. Ctrl+S saves to disk. Ctrl+C copies image to clipboard only.
    // Bound to the instance that has the crop (not merely compositor focus).
    Shortcut {
        sequence: "Escape"
        enabled: root.hasKeyboardFocus && !root.suppressGlobalKeys
        context: Qt.ApplicationShortcut
        onActivated: root.close()
    }
    Shortcut {
        sequence: "Ctrl+S"
        enabled: root.hasCrop && !root.suppressGlobalKeys
        context: Qt.ApplicationShortcut
        onActivated: root.requestSave()
    }
    Shortcut {
        sequence: "Ctrl+C"
        enabled: root.hasCrop && !root.suppressGlobalKeys
        context: Qt.ApplicationShortcut
        onActivated: root.requestClipboard()
    }

    onHasKeyboardFocusChanged: {
        // Never steal focus while the user is dragging a crop — Wayland
        // layershell keyboardFocus toggles mid-grab are what made quick crops stick.
        if (root.hasKeyboardFocus && !root.pointerDown)
            root.focusKeySink();
    }

    function setCrop(c) {
        root.crop = c;
        root.hasCrop = root.cropIsValid(c);
    }

    // "save" = disk only; "clipboard" = wl-copy only. Debounced for multi-path keys.
    property bool _exportRequested: false
    property string _exportMode: "save"
    function requestSave() { root.requestExport("save"); }
    function requestClipboard() { root.requestExport("clipboard"); }
    function requestExport(mode) {
        if (root.suppressGlobalKeys || root._exportRequested || root._exportPending)
            return;
        if (!root.hasCrop || root.crop === null) {
            Quickshell.execDetached(["/usr/bin/notify-send", "Screenshot", "Crop a region first", "-a", "Screenshot", "-t", "2000"]);
            return;
        }
        GlobalStates.screenshotEditorActiveScreen = root.screen.name;
        root._exportMode = mode === "clipboard" ? "clipboard" : "save";
        root._exportRequested = true;
        Qt.callLater(() => {
            root._exportRequested = false;
            root.exportImage();
        });
    }

    // Shared key handler for combos (Ctrl+*) and Esc.
    function handleEditorKey(e) {
        if (root.suppressGlobalKeys)
            return;
        if (e.key === Qt.Key_Escape) {
            root.close();
            e.accepted = true;
            return;
        }
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_S) {
            root.requestSave();
            e.accepted = true;
            return;
        }
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) {
            root.requestClipboard();
            e.accepted = true;
            return;
        }
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Z && (e.modifiers & Qt.ShiftModifier)) {
            root.redo();
            e.accepted = true;
            return;
        }
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Z) {
            root.undo();
            e.accepted = true;
            return;
        }
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Y) {
            root.redo();
            e.accepted = true;
            return;
        }
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_D) {
            root.duplicateSelected();
            e.accepted = true;
            return;
        }
        if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) && root.selected) {
            root.deleteSelected();
            e.accepted = true;
        }
    }

    readonly property string fullScreenshotPath: `${Directories.screenshotTemp}/edit-full-${root.screen.name}.png`
    property bool screenshotReady: false

    // ── Crop rectangle — defaults to the whole screen, resizable via handles ──
    property var crop: null       // {x, y, w, h} in window-local coords, null until capture completes
    property int cropDragHandle: -1   // 0..3 = corner index, -1 = idle
    property int cropDragEdge: -1     // 0=top, 1=right, 2=bottom, 3=left, -1 = idle
    property point cropDragAnchor     // opposite corner/edge, stays fixed while resizing
    readonly property int cropMinSize: 20

    function clampCrop(c) {
        const x = Math.max(0, Math.min(c.x, root.width));
        const y = Math.max(0, Math.min(c.y, root.height));
        const w = Math.max(0, Math.min(c.w, root.width - x));
        const h = Math.max(0, Math.min(c.h, root.height - y));
        return { x: x, y: y, w: w, h: h };
    }
    function cropHandlePositions(c) {
        return [Qt.point(c.x, c.y), Qt.point(c.x + c.w, c.y), Qt.point(c.x + c.w, c.y + c.h), Qt.point(c.x, c.y + c.h)];
    }
    // Hit-test the crop corner handles; returns a handle index or -1.
    function cropHandleAt(x, y) {
        if (!root.crop) return -1;
        const handles = root.cropHandlePositions(root.crop);
        for (let i = 0; i < handles.length; i++) {
            if (Math.hypot(x - handles[i].x, y - handles[i].y) <= 18) return i;
        }
        return -1;
    }
    // Hit-test the crop edges (whole side, not just the corner dot); 0=top,1=right,2=bottom,3=left, or -1.
    function cropEdgeAt(x, y) {
        if (!root.crop) return -1;
        const c = root.crop, tol = 14;
        if (Math.abs(y - c.y) <= tol && x >= c.x - tol && x <= c.x + c.w + tol) return 0;
        if (Math.abs(x - (c.x + c.w)) <= tol && y >= c.y - tol && y <= c.y + c.h + tol) return 1;
        if (Math.abs(y - (c.y + c.h)) <= tol && x >= c.x - tol && x <= c.x + c.w + tol) return 2;
        if (Math.abs(x - c.x) <= tol && y >= c.y - tol && y <= c.y + c.h + tol) return 3;
        return -1;
    }
    property bool cropDrawing: false  // dragging out a brand-new crop rect from scratch

    // Dashed selection/edit-box outline. Reusable across object kinds — set
    // bx/by/bw/bh to the box in local coordinates and visible per caller.
    component DashedSelectionBox: Shape {
        id: dashBox
        property real bx: 0
        property real by: 0
        property real bw: 0
        property real bh: 0
        x: bx
        y: by
        width: bw
        height: bh
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Appearance.m3colors.m3primary
            strokeWidth: 1.5
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: "transparent"
            PathPolyline {
                path: [
                    Qt.point(0, 0), Qt.point(dashBox.width, 0),
                    Qt.point(dashBox.width, dashBox.height), Qt.point(0, dashBox.height),
                    Qt.point(0, 0)
                ]
            }
        }
    }

    // Drag handle dot for crop corners and shape endpoints.
    component HandleDot: Rectangle {
        required property var modelData
        x: modelData.x - width / 2
        y: modelData.y - height / 2
        width: 14
        height: 14
        radius: 7
        color: Appearance.m3colors.m3primary
        border.width: 2
        border.color: "#ffffff"
    }

    component ToolbarDivider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 22
        color: Appearance.colors.colOutlineVariant
        Layout.leftMargin: 4
        Layout.rightMargin: 4
    }

    component FadeIconButton: IconToolbarButton {
        Layout.alignment: Qt.AlignVCenter
        Layout.fillHeight: true
        // Toolbar is mouse-driven; never steal Enter/Esc from the editor.
        focusPolicy: Qt.NoFocus
        opacity: enabled ? 1 : 0.4
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    Component.onCompleted: captureProc.running = true

    Process {
        id: captureProc
        command: ["/usr/bin/bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(Directories.screenshotTemp)}' && /usr/bin/grim -o '${StringUtils.shellSingleQuoteEscape(root.screen.name)}' '${StringUtils.shellSingleQuoteEscape(root.fullScreenshotPath)}'`]
        onExited: (code) => {
            if (code !== 0) {
                Quickshell.execDetached(["/usr/bin/notify-send", "Screenshot failed", "grim failed to capture the screen", "-a", "Screenshot", "-t", "4000"]);
                root.close();
                return;
            }
            root.screenshotReady = true;
        }
    }

    // ── Tool state ───────────────────────────────────────────────────────────
    property string tool: "pen"           // pen | line | rect | circle | arrow | text | highlight | blur | counter | move
    readonly property string _initialCustomColor: Config.options?.regionSelector?.lastCustomColor ?? ""
    property color strokeColor: root._initialCustomColor !== "" ? root._initialCustomColor : Appearance.m3colors.m3primary
    property real strokeWidth: Config.options?.regionSelector?.lastStrokeWidth ?? 4
    property var strokes: []              // committed shape strokes
    property var texts: []                // committed text annotations
    // Snapshot-based history: each entry is a full {strokes, texts} copy taken
    // before a mutation, so create/move/resize/recolor/restyle/delete are all
    // undoable uniformly without per-operation inverses.
    property var undoStack: []
    property var redoStack: []
    property var current: null            // live shape being drawn
    property bool fillShape: false        // solid fill for new rect/circle
    property var dragging: null           // move-tool drag state
    property var selected: null           // {kind, index} — for resize handles and recolor
    property bool _exportPending: false   // dedupe for exportImage re-entry

    // Color-picker preset exception: white/black/gray stay literal.
    readonly property var palette: [
        Appearance.m3colors.m3primary,
        Appearance.m3colors.m3secondary,
        Appearance.m3colors.m3tertiary,
        Appearance.m3colors.m3error,
        "#9e9e9e",
        "#ffffff",
        "#000000"
    ]
    readonly property bool strokeColorIsCustom: !root.palette.some(c => c == root.strokeColor)

    // Custom colors picked across sessions, so reusing one doesn't mean retyping the hex.
    property var savedCustomColors: Config.options?.regionSelector?.customColors ?? []
    function saveCustomColor(hex) {
        if (root.palette.some(c => c == hex) || root.savedCustomColors.some(c => c === hex)) return;
        const arr = root.savedCustomColors.slice();
        arr.push(hex);
        if (arr.length > 5) arr.shift();
        root.savedCustomColors = arr;
        Config.setNestedValue("regionSelector.customColors", arr);
    }

    // The picker swatch shows this instead of the rainbow icon once set.
    property string lastCustomColor: root._initialCustomColor
    function setLastCustomColor(hex) {
        root.lastCustomColor = hex;
        Config.setNestedValue("regionSelector.lastCustomColor", hex);
    }

    function setCurrent(s) { root.current = s; }
    function focusKeySink() {
        // Prefer the canvas: it owns drawing gestures and always has Keys handlers.
        if (canvasMouse)
            canvasMouse.forceActiveFocus();
        else
            keySink.forceActiveFocus();
    }

    // ── History (snapshot based) ─────────────────────────────────────────────
    function _cloneState() {
        return {
            strokes: root.strokes.map(s => Object.assign({}, s, { pts: s.pts.slice() })),
            texts: root.texts.map(t => Object.assign({}, t))
        };
    }
    // Call once BEFORE any mutation (at gesture start for drags) to make it undoable.
    function pushHistory() {
        const arr = root.undoStack.slice();
        arr.push(root._cloneState());
        if (arr.length > 60) arr.shift();
        root.undoStack = arr;
        root.redoStack = [];
    }
    function _applyState(st) {
        root.strokes = st.strokes;
        root.texts = st.texts;
        root.selected = null;
        root.current = null;
    }
    function undo() {
        keySink.forceActiveFocus();
        if (root.undoStack.length === 0) return;
        const u = root.undoStack.slice();
        const prev = u.pop();
        const r = root.redoStack.slice(); r.push(root._cloneState());
        root.undoStack = u;
        root.redoStack = r;
        root._applyState(prev);
    }
    function redo() {
        keySink.forceActiveFocus();
        if (root.redoStack.length === 0) return;
        const r = root.redoStack.slice();
        const next = r.pop();
        const u = root.undoStack.slice(); u.push(root._cloneState());
        root.redoStack = r;
        root.undoStack = u;
        root._applyState(next);
    }

    // Merges `changes` into text[index], preserving every other field.
    function updateText(index, changes) {
        if (index < 0 || index >= root.texts.length) return;
        const arr = root.texts.slice();
        arr[index] = Object.assign({}, arr[index], changes);
        root.texts = arr;
    }
    // Merges `changes` into strokes[index], preserving every other field (e.g. counter's n).
    function updateShape(index, changes) {
        if (index < 0 || index >= root.strokes.length) return;
        const arr = root.strokes.slice();
        arr[index] = Object.assign({}, arr[index], changes);
        root.strokes = arr;
    }
    readonly property var selectedText: (root.selected && root.selected.kind === "text" && root.selected.index < root.texts.length)
        ? root.texts[root.selected.index] : null
    readonly property var selectedShape: (root.selected && root.selected.kind === "shape" && root.selected.index < root.strokes.length)
        ? root.strokes[root.selected.index] : null
    function _isFillable(s) { return s && (s.tool === "rect" || s.tool === "circle"); }
    // Fill toggle applies to a selected rect/circle, else to the draw default.
    readonly property bool fillApplicable: root._isFillable(root.selectedShape)
        || root.tool === "rect" || root.tool === "circle"
    readonly property bool fillActive: root._isFillable(root.selectedShape)
        ? (root.selectedShape.filled ?? false) : root.fillShape
    function toggleFill() {
        keySink.forceActiveFocus();
        if (root._isFillable(root.selectedShape)) {
            const next = !(root.selectedShape.filled ?? false);
            root.pushHistory();
            root.updateShape(root.selected.index, { filled: next });
            root.fillShape = next;
        } else {
            root.fillShape = !root.fillShape;
        }
    }

    // Recolors the selected object if one is selected; always updates the draw color too.
    function setStrokeColor(c) {
        root.strokeColor = c;
        keySink.forceActiveFocus();
        if (!root.selected) return;
        root.pushHistory();
        if (root.selected.kind === "shape" && root.selected.index < root.strokes.length) {
            // Highlight stays opaque in storage; the layer opacity handles translucency.
            root.updateShape(root.selected.index, { color: String(c) });
        } else if (root.selected.kind === "text") {
            root.updateText(root.selected.index, { color: String(c) });
        }
    }

    // Resizes the selected shape's stroke (or selected text's font size) if
    // one is selected; always updates the draw width too.
    function setStrokeWidth(w) {
        root.strokeWidth = w;
        Config.setNestedValue("regionSelector.lastStrokeWidth", w);
        if (!root.selected) return;
        if (root.selected.kind === "shape" && root.selected.index < root.strokes.length) {
            const s = root.strokes[root.selected.index];
            // Highlighter stores 4x the base width, so keep that multiplier.
            root.updateShape(root.selected.index, { width: s.tool === "highlight" ? w * 4 : w });
        } else if (root.selected.kind === "text") {
            root.updateText(root.selected.index, { size: Math.max(14, w * 5) });
        }
    }

    // Flips a boolean font-style flag (bold/italic/underline/strikeout) on the selected text.
    function toggleTextStyle(flag) {
        if (!root.selectedText) return;
        root.pushHistory();
        const changes = {};
        changes[flag] = !root.selectedText[flag];
        root.updateText(root.selected.index, changes);
        keySink.forceActiveFocus();
    }

    // History is snapshotted by the caller (at draw start) before commit.
    function commitShape(s) {
        const arr = root.strokes.slice(); arr.push(s); root.strokes = arr;
        // Auto-select the just-drawn shape so the stroke slider/color target it
        // immediately, same as a text stays selected after typing.
        root.selected = { kind: "shape", index: arr.length - 1 };
    }
    function addText(x, y) {
        root.pushHistory();
        const arr = root.texts.slice();
        arr.push({ x: x, y: y, text: "", color: String(root.strokeColor), size: Math.max(14, root.strokeWidth * 5), bold: false, italic: false, underline: false, strikeout: false });
        root.texts = arr;
        textRepeater.focusLast();
    }

    // Bounding box of a point list, for move-tool hit testing.
    function boundsForPts(pts) {
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const p of pts) {
            if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
            if (p.y < minY) minY = p.y; if (p.y > maxY) maxY = p.y;
        }
        return { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
    }

    // Topmost stroke/text under (x, y), or null.
    function hitTest(x, y) {
        const pad = 10;
        for (let i = root.texts.length - 1; i >= 0; i--) {
            const t = root.texts[i];
            const lines = t.text.split("\n");
            const longestLine = Math.max(...lines.map(l => l.length));
            const w = Math.max(20, longestLine * t.size * 0.55);
            const h = lines.length * t.size * 1.3;
            if (x >= t.x - pad && x <= t.x + w + pad && y >= t.y - pad && y <= t.y + h + pad)
                return { kind: "text", index: i };
        }
        for (let i = root.strokes.length - 1; i >= 0; i--) {
            const s = root.strokes[i];
            if (s.tool === "counter") {
                const r = 14 + s.width * 1.5;
                if (Math.hypot(x - s.pts[0].x, y - s.pts[0].y) <= r) return { kind: "shape", index: i };
                continue;
            }
            const sp = s.width <= 1 ? 1 : Math.round(s.width * 0.7 + 0.5);
            // Circle only hits on its ring, not the empty interior.
            if (s.tool === "circle") {
                const a = s.pts[0], e = s.pts[s.pts.length - 1];
                const cx = (a.x + e.x) / 2, cy = (a.y + e.y) / 2;
                const rx = Math.max(1, Math.abs(e.x - a.x) / 2), ry = Math.max(1, Math.abs(e.y - a.y) / 2);
                const d = Math.hypot((x - cx) / rx, (y - cy) / ry);
                if (Math.abs(d - 1) <= (sp + 6) / Math.min(rx, ry)) return { kind: "shape", index: i };
                continue;
            }
            const b = root.boundsForPts(s.pts);
            if (x >= b.minX - sp && x <= b.maxX + sp && y >= b.minY - sp && y <= b.maxY + sp)
                return { kind: "shape", index: i };
        }
        return null;
    }

    // 2-point shapes [start, end] — those two points double as resize handles.
    function isResizable(s) { return s && (s.tool === "rect" || s.tool === "circle" || s.tool === "line" || s.tool === "arrow" || s.tool === "blur"); }
    function handlePositions(s) { return [s.pts[0], s.pts[s.pts.length - 1]]; }

    // Next counter number = highest existing counter + 1.
    function nextCounterNumber() {
        let max = 0;
        for (const s of root.strokes) if (s.tool === "counter" && (s.n ?? 0) > max) max = s.n;
        return max + 1;
    }
    function addCounter(x, y) {
        root.pushHistory();
        const arr = root.strokes.slice();
        arr.push({ tool: "counter", color: String(root.strokeColor), width: root.strokeWidth, pts: [Qt.point(x, y)], n: root.nextCounterNumber() });
        root.strokes = arr;
        root.selected = { kind: "shape", index: arr.length - 1 };
    }

    function beginMove(x, y) {
        if (root.selected && root.selected.kind === "shape" && root.selected.index < root.strokes.length) {
            const s = root.strokes[root.selected.index];
            if (root.isResizable(s)) {
                const handles = root.handlePositions(s);
                for (let i = 0; i < handles.length; i++) {
                    if (Math.hypot(x - handles[i].x, y - handles[i].y) <= 12) {
                        root.dragging = { kind: "resize", index: root.selected.index, handle: i, lastX: x, lastY: y };
                        return;
                    }
                }
            }
        }
        const hit = root.hitTest(x, y);
        // Sticky: only a real hit changes the selection — clicking empty
        // space (e.g. on the way to the toolbar) never deselects by accident.
        if (hit) {
            root.selected = { kind: hit.kind, index: hit.index };
            root.strokeColor = hit.kind === "shape" ? root.strokes[hit.index].color : root.texts[hit.index].color;
            if (hit.kind === "shape") {
                const s = root.strokes[hit.index];
                // Undo the highlighter 4x so the slider shows the base width.
                root.strokeWidth = s.tool === "highlight" ? s.width / 4 : s.width;
            } else {
                root.strokeWidth = Math.min(24, Math.max(1, root.texts[hit.index].size / 5));
            }
        }
        root.dragging = hit ? { kind: hit.kind, index: hit.index, lastX: x, lastY: y } : null;
    }

    function moveDrag(x, y) {
        if (!root.dragging) return;
        if (root.dragging.kind === "resize") {
            const s = root.strokes[root.dragging.index];
            const pts = s.pts.slice();
            pts[root.dragging.handle === 0 ? 0 : pts.length - 1] = Qt.point(x, y);
            root.updateShape(root.dragging.index, { pts: pts });
            root.dragging = { kind: "resize", index: root.dragging.index, handle: root.dragging.handle, lastX: x, lastY: y };
            return;
        }
        const dx = x - root.dragging.lastX, dy = y - root.dragging.lastY;
        if (root.dragging.kind === "shape") {
            const s = root.strokes[root.dragging.index];
            root.updateShape(root.dragging.index, { pts: s.pts.map(p => Qt.point(p.x + dx, p.y + dy)) });
        } else {
            const t = root.texts[root.dragging.index];
            root.updateText(root.dragging.index, { x: t.x + dx, y: t.y + dy });
        }
        root.dragging = { kind: root.dragging.kind, index: root.dragging.index, lastX: x, lastY: y };
    }

    function endMove() { root.dragging = null; }

    // Clones the selected shape/text with a small offset; the copy becomes the selection.
    function duplicateSelected() {
        if (!root.selected) return;
        root.pushHistory();
        const off = 20;
        if (root.selected.kind === "shape" && root.selected.index < root.strokes.length) {
            const s = root.strokes[root.selected.index];
            const copy = Object.assign({}, s, { pts: s.pts.map(p => Qt.point(p.x + off, p.y + off)) });
            if (s.tool === "counter") copy.n = root.nextCounterNumber();
            const arr = root.strokes.slice(); arr.push(copy); root.strokes = arr;
            root.selected = { kind: "shape", index: arr.length - 1 };
        } else if (root.selected.kind === "text" && root.selected.index < root.texts.length) {
            const t = Object.assign({}, root.texts[root.selected.index]);
            t.x += off; t.y += off;
            const arr = root.texts.slice(); arr.push(t); root.texts = arr;
            root.selected = { kind: "text", index: arr.length - 1 };
        }
        keySink.forceActiveFocus();
    }

    // Removes the selected shape/text outright.
    function deleteSelected() {
        if (!root.selected) return;
        root.pushHistory();
        if (root.selected.kind === "shape" && root.selected.index < root.strokes.length) {
            const arr = root.strokes.slice();
            arr.splice(root.selected.index, 1);
            root.strokes = arr;
        } else if (root.selected.kind === "text" && root.selected.index < root.texts.length) {
            const arr = root.texts.slice();
            arr.splice(root.selected.index, 1);
            root.texts = arr;
        }
        root.selected = null;
        keySink.forceActiveFocus();
    }

    // Build the polyline points for a shape stroke based on its tool.
    function pointsFor(s) {
        if (!s || !s.pts || s.pts.length === 0) return [];
        if (s.tool === "pen" || s.tool === "highlight") return s.pts;
        const a = s.pts[0]; const b = s.pts[s.pts.length - 1];
        if (s.tool === "rect" || s.tool === "blur")
            return [Qt.point(a.x, a.y), Qt.point(b.x, a.y), Qt.point(b.x, b.y), Qt.point(a.x, b.y), Qt.point(a.x, a.y)];
        if (s.tool === "line") return [Qt.point(a.x, a.y), Qt.point(b.x, b.y)];
        if (s.tool === "circle") {
            const cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2;
            const rx = Math.abs(b.x - a.x) / 2, ry = Math.abs(b.y - a.y) / 2;
            const pts = [];
            for (let i = 0; i <= 48; i++) {
                const t = i / 48 * Math.PI * 2;
                pts.push(Qt.point(cx + rx * Math.cos(t), cy + ry * Math.sin(t)));
            }
            return pts;
        }
        if (s.tool === "arrow") {
            const dx = b.x - a.x, dy = b.y - a.y;
            const len = Math.max(1, Math.hypot(dx, dy));
            const ux = dx / len, uy = dy / len;
            const head = Math.min(22, len * 0.4);
            const ang = 0.5;
            const lx = b.x - head * (ux * Math.cos(ang) - uy * Math.sin(ang));
            const ly = b.y - head * (uy * Math.cos(ang) + ux * Math.sin(ang));
            const rx = b.x - head * (ux * Math.cos(ang) + uy * Math.sin(ang));
            const ry = b.y - head * (uy * Math.cos(ang) - ux * Math.sin(ang));
            return [Qt.point(a.x, a.y), Qt.point(b.x, b.y), Qt.point(lx, ly), Qt.point(b.x, b.y), Qt.point(rx, ry)];
        }
        return s.pts;
    }

    // FocusScope owns keyboard: Esc + Ctrl combos (save/clipboard live on Shortcuts too).
    FocusScope {
        id: keySink
        anchors.fill: parent
        focus: root.hasKeyboardFocus
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (e) => root.handleEditorKey(e)
        Keys.onEscapePressed: (e) => { root.close(); e.accepted = true; }

    // ── Canvas (image + annotations) — the grabToImage export source ─────────
    Item {
        id: captureArea
        anchors.fill: parent

        Image {
            id: sourceImage
            anchors.fill: parent
            source: root.screenshotReady ? `file://${root.fullScreenshotPath}` : ""
            // Stretch so window-local crop coords map 1:1 onto the grab/export pixel grid.
            fillMode: Image.Stretch
            smooth: true
            cache: false
        }

        Repeater {
            model: root.strokes
            delegate: Item {
                id: shapeDelegate
                required property var modelData
                anchors.fill: parent
                // Two-point bbox (blur/counter share the rect geometry).
                readonly property var p0: modelData.pts[0]
                readonly property var p1: modelData.pts[modelData.pts.length - 1]
                readonly property real bx: Math.min(p0.x, p1.x)
                readonly property real by: Math.min(p0.y, p1.y)
                readonly property real bw: Math.abs(p1.x - p0.x)
                readonly property real bh: Math.abs(p1.y - p0.y)

                // Line-based tools (pen/rect/arrow/highlight).
                // Freehand thick strokes use GeometryRenderer — CurveRenderer spikes
                // at sharp reversals on wide strokes (visible with the highlighter).
                Shape {
                    anchors.fill: parent
                    visible: shapeDelegate.modelData.tool !== "blur" && shapeDelegate.modelData.tool !== "counter" && shapeDelegate.modelData.tool !== "rect"
                    preferredRendererType: (shapeDelegate.modelData.tool === "pen" || shapeDelegate.modelData.tool === "highlight")
                        ? Shape.GeometryRenderer : Shape.CurveRenderer
                    // Highlight composites as a single translucent layer, so overlapping
                    // segments within one stroke don't stack alpha into dark ticks.
                    opacity: shapeDelegate.modelData.tool === "highlight" ? 0.4 : 1
                    layer.enabled: shapeDelegate.modelData.tool === "highlight"
                    ShapePath {
                        strokeColor: shapeDelegate.modelData.color
                        // Filled circle drops the outline for a clean solid, matching filled rect.
                        strokeWidth: (shapeDelegate.modelData.tool === "circle" && (shapeDelegate.modelData.filled ?? false)) ? 0 : shapeDelegate.modelData.width
                        fillColor: (shapeDelegate.modelData.tool === "circle" && (shapeDelegate.modelData.filled ?? false)) ? shapeDelegate.modelData.color : "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: root.pointsFor(shapeDelegate.modelData) }
                    }
                }

                // Rectangle — native rounded corners + optional solid fill.
                Rectangle {
                    visible: shapeDelegate.modelData.tool === "rect"
                    readonly property bool isFilled: shapeDelegate.modelData.filled ?? false
                    x: shapeDelegate.bx
                    y: shapeDelegate.by
                    width: shapeDelegate.bw
                    height: shapeDelegate.bh
                    radius: Math.min(width / 2, height / 2, 6 + shapeDelegate.modelData.width * 1.2)
                    color: isFilled ? shapeDelegate.modelData.color : "transparent"
                    border.width: isFilled ? 0 : shapeDelegate.modelData.width
                    border.color: shapeDelegate.modelData.color
                }

                // Blur — the patch is captured into a low-resolution texture and
                // smoothly upscaled, so strength comes from the downscale factor
                // (inherently smooth) rather than a wide-radius sampling that
                // goes grainy. A small fixed MultiEffect pass removes the
                // bilinear seams. Each blur costs one region FBO, not a full copy.
                Item {
                    visible: shapeDelegate.modelData.tool === "blur"
                    x: shapeDelegate.bx
                    y: shapeDelegate.by
                    width: shapeDelegate.bw
                    height: shapeDelegate.bh
                    clip: true
                    readonly property real blurMargin: 32
                    // Stroke width (1..24) sets how hard the patch is downsampled.
                    readonly property real downscale: 1 + shapeDelegate.modelData.width * 0.9

                    ShaderEffectSource {
                        id: blurPatchSource
                        anchors.fill: parent
                        anchors.margins: -parent.blurMargin
                        visible: false
                        smooth: true
                        sourceItem: sourceImage
                        sourceRect: Qt.rect(
                            shapeDelegate.bx - parent.blurMargin,
                            shapeDelegate.by - parent.blurMargin,
                            shapeDelegate.bw + parent.blurMargin * 2,
                            shapeDelegate.bh + parent.blurMargin * 2)
                        textureSize: Qt.size(
                            Math.max(2, width / parent.downscale),
                            Math.max(2, height / parent.downscale))
                    }
                    MultiEffect {
                        source: blurPatchSource
                        anchors.fill: parent
                        anchors.margins: -parent.blurMargin
                        blurEnabled: true
                        blur: 1
                        blurMax: 16
                    }
                }

                // Counter — auto-numbered bubble.
                Item {
                    visible: shapeDelegate.modelData.tool === "counter"
                    readonly property real r: 14 + shapeDelegate.modelData.width * 1.5
                    x: shapeDelegate.p0.x - r
                    y: shapeDelegate.p0.y - r
                    width: r * 2
                    height: r * 2
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: shapeDelegate.modelData.color
                        border.width: 2
                        border.color: ColorUtils.contrastColor(shapeDelegate.modelData.color)
                    }
                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: shapeDelegate.modelData.n ?? 1
                        color: ColorUtils.contrastColor(shapeDelegate.modelData.color)
                        font.pixelSize: parent.r
                        font.bold: true
                        font.family: Appearance.font.family.main
                    }
                }
            }
        }

        Canvas {
            id: liveCanvas
            anchors.fill: parent
            z: 10
            visible: root.current !== null
            renderStrategy: Canvas.Threaded
            renderTarget: Canvas.Image

            property var s: root.current
            onSChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!liveCanvas.s) return;
                const pts = root.pointsFor(liveCanvas.s);
                if (pts.length < 2) return;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                // Blur previews as a thin neutral dashed outline, not a thick colored rect.
                if (liveCanvas.s.tool === "blur") {
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = "#ffffff";
                    ctx.setLineDash([4, 4]);
                } else {
                    ctx.lineWidth = liveCanvas.s.width;
                    ctx.strokeStyle = liveCanvas.s.color;
                    ctx.setLineDash([]);
                }
                ctx.globalAlpha = liveCanvas.s.tool === "highlight" ? 0.4 : 1.0;
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
                const fillPreview = liveCanvas.s.filled && (liveCanvas.s.tool === "rect" || liveCanvas.s.tool === "circle");
                if (fillPreview) {
                    ctx.closePath();
                    ctx.fillStyle = liveCanvas.s.color;
                    ctx.fill();
                } else {
                    ctx.stroke();
                }
                ctx.globalAlpha = 1.0;
                ctx.setLineDash([]);
            }
        }

        Repeater {
            id: textRepeater
            model: root.texts
            function focusLast() { if (count > 0) itemAt(count - 1)?.focusInput(); }
            delegate: Item {
                id: textWrap
                z: 20
                required property var modelData
                required property int index
                function focusInput() {
                    textInput.forceActiveFocus();
                    textInput.cursorPosition = textInput.text.length;
                }
                x: modelData.x
                y: modelData.y
                implicitWidth: textInput.implicitWidth
                implicitHeight: textInput.implicitHeight
                readonly property color outlineColor: ColorUtils.contrastColor(modelData.color)

                // Outline: native outline style behind the editable text.
                // Bound to textInput.text (not modelData.text, which is mutated
                // in place and never signals) so it tracks typing live.
                Text {
                    style: Text.Outline
                    styleColor: textWrap.outlineColor
                    text: textInput.text
                    color: textWrap.modelData.color
                    font.pixelSize: textWrap.modelData.size
                    font.family: Appearance.font.family.main
                    font.bold: textWrap.modelData.bold ?? false
                    font.italic: textWrap.modelData.italic ?? false
                    font.underline: textWrap.modelData.underline ?? false
                    font.strikeout: textWrap.modelData.strikeout ?? false
                }

                TextEdit {
                    id: textInput
                    enabled: root.tool !== "move"
                    wrapMode: TextEdit.NoWrap
                    color: textWrap.modelData.color
                    font.pixelSize: textWrap.modelData.size
                    font.family: Appearance.font.family.main
                    font.bold: textWrap.modelData.bold ?? false
                    font.italic: textWrap.modelData.italic ?? false
                    font.underline: textWrap.modelData.underline ?? false
                    font.strikeout: textWrap.modelData.strikeout ?? false
                    text: textWrap.modelData.text
                    onTextChanged: root.texts[textWrap.index].text = text
                    selectByMouse: true
                    cursorVisible: activeFocus
                    // Editing a text auto-selects it so the width slider drives its font size.
                    onActiveFocusChanged: if (activeFocus) {
                        root.selected = { kind: "text", index: textWrap.index };
                        root.strokeWidth = Math.min(24, Math.max(1, textWrap.modelData.size / 5));
                    }
                    Component.onCompleted: if (text === "") forceActiveFocus()
                }

                // Dashed edit-box outline while actively typing or selected.
                DashedSelectionBox {
                    bx: -6
                    by: -6
                    bw: textInput.implicitWidth + 12
                    bh: textInput.implicitHeight + 12
                    visible: textInput.activeFocus || (root.selected && root.selected.kind === "text" && root.selected.index === textWrap.index)
                }
            }
        }

        // Resize handles for the selected rect/arrow.
        Repeater {
            model: (root.tool === "move" && root.selected && root.selected.kind === "shape" && root.selected.index < root.strokes.length && root.isResizable(root.strokes[root.selected.index]))
                ? root.handlePositions(root.strokes[root.selected.index]) : []
            delegate: HandleDot { z: 30 }
        }

        // Dashed selection outline for pen/highlight strokes (no resize handles apply to freehand paths).
        DashedSelectionBox {
            z: 30
            readonly property bool showFor: root.tool === "move" && root.selected && root.selected.kind === "shape"
                && root.selected.index < root.strokes.length && !root.isResizable(root.strokes[root.selected.index])
            readonly property var bounds: showFor ? root.boundsForPts(root.strokes[root.selected.index].pts) : null
            // Pad by the drawn thickness (or bubble radius for counters) so the box wraps the actual ink.
            readonly property real pad: {
                if (!showFor) return 0;
                const s = root.strokes[root.selected.index];
                if (s.tool === "counter") return 14 + s.width * 1.5 + 4;
                return s.width <= 1 ? 1 : Math.round(s.width * 0.7 + 0.5);
            }
            visible: showFor
            bx: bounds ? bounds.minX - pad : 0
            by: bounds ? bounds.minY - pad : 0
            bw: bounds ? bounds.maxX - bounds.minX + pad * 2 : 0
            bh: bounds ? bounds.maxY - bounds.minY + pad * 2 : 0
        }
    }

    // Fully dim until a crop exists — starts black, selection reveals the shot.
    Rectangle {
        anchors.fill: parent
        visible: root.crop === null
        color: Qt.rgba(0, 0, 0, 0.85)
    }

    // ── Crop rectangle — dims outside it, always resizable via corner handles ──
    Item {
        anchors.fill: parent
        visible: root.crop !== null
        readonly property var c: root.crop ?? { x: 0, y: 0, w: 0, h: 0 }
        Rectangle { x: 0; y: 0; width: parent.width; height: parent.c.y; color: Qt.rgba(0, 0, 0, 0.85) }
        Rectangle { x: 0; y: parent.c.y + parent.c.h; width: parent.width; height: parent.height - parent.c.y - parent.c.h; color: Qt.rgba(0, 0, 0, 0.85) }
        Rectangle { x: 0; y: parent.c.y; width: parent.c.x; height: parent.c.h; color: Qt.rgba(0, 0, 0, 0.85) }
        Rectangle { x: parent.c.x + parent.c.w; y: parent.c.y; width: parent.width - parent.c.x - parent.c.w; height: parent.c.h; color: Qt.rgba(0, 0, 0, 0.85) }
        Rectangle {
            x: parent.c.x; y: parent.c.y; width: parent.c.w; height: parent.c.h
            color: "transparent"
            border.width: 2
            border.color: Appearance.m3colors.m3primary
        }
    }
    Repeater {
        model: root.crop !== null ? root.cropHandlePositions(root.crop) : []
        delegate: HandleDot { z: 40 }
    }

    // ── Interaction — crop-handle drag takes priority over the active tool ────
    MouseArea {
        id: canvasMouse
        anchors.fill: parent
        z: 5
        focus: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.cropDragHandle >= 0 ? Qt.SizeFDiagCursor
            : (root.cropDragEdge === 0 || root.cropDragEdge === 2) ? Qt.SizeVerCursor
            : (root.cropDragEdge === 1 || root.cropDragEdge === 3) ? Qt.SizeHorCursor
            : root.tool === "move" ? (root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.CrossCursor
        readonly property real minPointStep: 2.5
        property point _lastPenPoint: Qt.point(NaN, NaN)
        property bool _dragSnapped: false
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (e) => root.handleEditorKey(e)
        Keys.onEscapePressed: (e) => { root.close(); e.accepted = true; }

        onPressed: (m) => {
            // Another output already owns the session — dim-only here.
            if (!root.canInteract) return;
            root.pointerDown = true;
            root.claimActive();
            // Do not forceActiveFocus here: it reassigns layershell keyboard
            // focus mid-press and can cancel the pointer grab on quick drags.

            // Recover from an interrupted previous drag (no release delivered).
            if (root.cropDrawing) {
                root.cropDrawing = false;
                if (!root.cropIsValid(root.crop))
                    root.setCrop(null);
            }
            root.cropDragHandle = -1;
            root.cropDragEdge = -1;

            // Invalid/tiny leftover crop must not block starting a new one.
            if (root.crop && !root.cropIsValid(root.crop) && !root.cropDrawing)
                root.setCrop(null);

            const handle = root.cropIsValid(root.crop) ? root.cropHandleAt(m.x, m.y) : -1;
            if (handle >= 0) {
                root.cropDragHandle = handle;
                root.cropDragAnchor = root.cropHandlePositions(root.crop)[(handle + 2) % 4];
                return;
            }
            const edge = root.cropIsValid(root.crop) ? root.cropEdgeAt(m.x, m.y) : -1;
            if (edge >= 0) {
                const c = root.crop;
                root.cropDragEdge = edge;
                root.cropDragAnchor = edge === 0 ? Qt.point(0, c.y + c.h)
                    : edge === 2 ? Qt.point(0, c.y)
                    : edge === 1 ? Qt.point(c.x, 0)
                    : Qt.point(c.x + c.w, 0);
                return;
            }
            // No valid crop yet: draw it from scratch. Once one exists, only
            // handles/edges touch it — a stray click never wipes a good crop.
            if (!root.cropIsValid(root.crop)) {
                root.cropDrawing = true;
                root.cropDragAnchor = Qt.point(m.x, m.y);
                root.setCrop({ x: m.x, y: m.y, w: 0, h: 0 });
                return;
            }
            if (root.tool === "move") { _dragSnapped = false; root.beginMove(m.x, m.y); return; }
            if (root.tool === "text") {
                const textHit = root.hitTest(m.x, m.y);
                if (textHit && textHit.kind === "text") {
                    root.selected = { kind: "text", index: textHit.index };
                    textRepeater.itemAt(textHit.index)?.focusInput();
                } else {
                    root.addText(m.x, m.y);
                }
                return;
            }
            if (root.tool === "counter") { root.addCounter(m.x, m.y); return; }
            root.pushHistory();
            _lastPenPoint = Qt.point(m.x, m.y);
            root.setCurrent({
                tool: root.tool,
                color: String(root.strokeColor),
                width: root.tool === "highlight" ? root.strokeWidth * 4 : root.strokeWidth,
                filled: (root.tool === "rect" || root.tool === "circle") ? root.fillShape : false,
                pts: [Qt.point(m.x, m.y)]
            });
        }
        onPositionChanged: (m) => {
            // Keep updating an in-progress crop even if claim/focus flickered;
            // only hard-stop when another output owns the session and we are idle.
            if (!root.canInteract && !root.cropDrawing && root.cropDragHandle < 0 && root.cropDragEdge < 0)
                return;
            if (root.cropDragHandle >= 0 || root.cropDrawing) {
                const a = root.cropDragAnchor;
                let c = root.clampCrop({
                    x: Math.min(a.x, m.x), y: Math.min(a.y, m.y),
                    w: Math.abs(m.x - a.x), h: Math.abs(m.y - a.y)
                });
                // Handle-drag enforces the minimum; fresh drawing may stay tiny (cancelled on release).
                if (root.cropDragHandle >= 0) {
                    if (c.w < root.cropMinSize) c.w = root.cropMinSize;
                    if (c.h < root.cropMinSize) c.h = root.cropMinSize;
                }
                root.setCrop(c);
                return;
            }
            if (root.cropDragEdge >= 0) {
                const a = root.cropDragAnchor;
                let c;
                if (root.cropDragEdge === 0) { // top: bottom (a.y) fixed
                    const y = Math.min(m.y, a.y - root.cropMinSize);
                    c = { x: root.crop.x, y: y, w: root.crop.w, h: a.y - y };
                } else if (root.cropDragEdge === 2) { // bottom: top (a.y) fixed
                    const h = Math.max(root.cropMinSize, m.y - a.y);
                    c = { x: root.crop.x, y: a.y, w: root.crop.w, h: h };
                } else if (root.cropDragEdge === 1) { // right: left (a.x) fixed
                    const w = Math.max(root.cropMinSize, m.x - a.x);
                    c = { x: a.x, y: root.crop.y, w: w, h: root.crop.h };
                } else { // left: right (a.x) fixed
                    const x = Math.min(m.x, a.x - root.cropMinSize);
                    c = { x: x, y: root.crop.y, w: a.x - x, h: root.crop.h };
                }
                root.setCrop(root.clampCrop(c));
                return;
            }
            if (root.tool === "move") {
                // One snapshot per move/resize gesture, taken on the first real drag.
                if (root.dragging && !_dragSnapped) { root.pushHistory(); _dragSnapped = true; }
                root.moveDrag(m.x, m.y);
                return;
            }
            if (!root.current) return;
            const c = root.current;
            const dx = m.x - _lastPenPoint.x;
            const dy = m.y - _lastPenPoint.y;
            if (dx*dx + dy*dy < minPointStep * minPointStep) return;
            _lastPenPoint = Qt.point(m.x, m.y);
            // New object, not mutated in place: same-reference assignment skips currentChanged.
            const pts = (c.tool === "pen" || c.tool === "highlight")
                ? c.pts.concat([Qt.point(m.x, m.y)])
                : [c.pts[0], Qt.point(m.x, m.y)];
            root.setCurrent({ tool: c.tool, color: c.color, width: c.width, filled: c.filled ?? false, pts: pts });
        }
        onReleased: () => {
            if (root.cropDragHandle >= 0) {
                root.cropDragHandle = -1;
                root.endPointerGesture();
                return;
            }
            if (root.cropDragEdge >= 0) {
                root.cropDragEdge = -1;
                root.endPointerGesture();
                return;
            }
            if (root.cropDrawing) {
                root.cropDrawing = false;
                if (!root.cropIsValid(root.crop))
                    root.setCrop(null);
                root.endPointerGesture();
                return;
            }
            if (root.tool === "move") { root.endMove(); root.endPointerGesture(); return; }
            if (root.current) { root.commitShape(root.current); root.setCurrent(null); }
            _lastPenPoint = Qt.point(NaN, NaN);
            root.endPointerGesture();
        }
        // If the compositor drops the grab (focus thrash / monitor claim), still clear drag state.
        onCanceled: () => {
            if (root.cropDrawing) {
                root.cropDrawing = false;
                if (!root.cropIsValid(root.crop))
                    root.setCrop(null);
            }
            root.cropDragHandle = -1;
            root.cropDragEdge = -1;
            if (root.current) { root.setCurrent(null); }
            root.endPointerGesture();
        }
        onDoubleClicked: (m) => {
            const hit = root.hitTest(m.x, m.y);
            if (!hit || hit.kind !== "text") return;
            root.tool = "text";
            root.selected = { kind: "text", index: hit.index };
            textRepeater.itemAt(hit.index)?.focusInput();
        }
    }

    // ── Tool palette — always active, no separate phase ─────────────────────
    Item {
        id: toolbarShell
        z: 100
        // Hidden until a real crop exists (not the live 0×0 press seed).
        visible: root.hasCrop
        readonly property bool useWaffle: Config.options?.panelFamily === "waffle"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        implicitWidth: editorToolbar.implicitWidth
        implicitHeight: 64

        // Waffle (Windows 11) container styling — flat Fluent pane behind the
        // same tools. Icons stay MaterialSymbol since the Fluent set lacks them.
        Rectangle {
            anchors.fill: parent
            visible: toolbarShell.useWaffle
            radius: Looks.radius.large
            color: Looks.colors.bgPanelFooterBase
            border.width: 1
            border.color: Looks.colors.bg2Border
            WRectangularShadow { target: parent }
        }

        Toolbar {
            id: editorToolbar
            anchors.fill: parent
            transparent: toolbarShell.useWaffle
            padding: 10
            radius: Appearance.rounding.full
            spacing: 6

            // Move/select mode, set apart from the drawing tools.
            IconToolbarButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                focusPolicy: Qt.NoFocus
                text: "open_with"
                toggled: root.tool === "move"
                onClicked: { if (root.tool !== "move") root.selected = null; root.tool = "move"; root.focusKeySink(); }
                StyledToolTip { text: Translation.tr("Move") }
            }

            ToolbarDivider {}

            Repeater {
                model: [
                    { "tool": "pen", "icon": "edit", "name": Translation.tr("Pen") },
                    { "tool": "line", "icon": "horizontal_rule", "name": Translation.tr("Line") },
                    { "tool": "rect", "icon": "rectangle", "name": Translation.tr("Rectangle") },
                    { "tool": "circle", "icon": "circle", "name": Translation.tr("Circle") },
                    { "tool": "arrow", "icon": "north_east", "name": Translation.tr("Arrow") },
                    { "tool": "text", "icon": "title", "name": Translation.tr("Text") },
                    { "tool": "highlight", "icon": "ink_highlighter", "name": Translation.tr("Highlighter") },
                    { "tool": "blur", "icon": "blur_on", "name": Translation.tr("Blur") },
                    { "tool": "counter", "icon": "counter_1", "name": Translation.tr("Counter") }
                ]
                delegate: IconToolbarButton {
                    id: toolBtn
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    focusPolicy: Qt.NoFocus
                    text: modelData.icon
                    toggled: root.tool === modelData.tool
                    // Switching tools drops the selection so the stroke slider
                    // targets the next drawing, not the previously selected object.
                    onClicked: { if (root.tool !== modelData.tool) root.selected = null; root.tool = modelData.tool; root.focusKeySink(); }
                    StyledToolTip { text: toolBtn.modelData.name }
                }
            }

            ToolbarDivider {}

            AnnotationColorPicker {
                editor: root
                Layout.alignment: Qt.AlignVCenter
            }

            ToolbarDivider {}

            StyledSlider {
                id: widthSlider
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 96
                focusPolicy: Qt.NoFocus
                from: 1; to: 24
                value: root.strokeWidth
                // One snapshot per slider drag (only when a selected object will change).
                onPressedChanged: if (pressed && root.selected) root.pushHistory()
                onValueChanged: root.setStrokeWidth(value)
                StyledToolTip { text: Translation.tr("Stroke width") }
            }

            // Fill toggle — shown for rect/circle tools or a selected rect/circle.
            ToolbarDivider { visible: root.fillApplicable }
            IconToolbarButton {
                visible: root.fillApplicable
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                focusPolicy: Qt.NoFocus
                text: "format_color_fill"
                toggled: root.fillActive
                onClicked: root.toggleFill()
                StyledToolTip { text: Translation.tr("Fill") }
            }

            // Text styling — shown only while a text object is selected.
            ToolbarDivider { visible: root.selectedText !== null }
            Repeater {
                model: [
                    { "flag": "bold", "icon": "format_bold", "name": Translation.tr("Bold") },
                    { "flag": "italic", "icon": "format_italic", "name": Translation.tr("Italic") },
                    { "flag": "underline", "icon": "format_underlined", "name": Translation.tr("Underline") },
                    { "flag": "strikeout", "icon": "strikethrough_s", "name": Translation.tr("Strikethrough") }
                ]
                delegate: IconToolbarButton {
                    id: styleBtn
                    required property var modelData
                    visible: root.selectedText !== null
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    focusPolicy: Qt.NoFocus
                    text: modelData.icon
                    toggled: root.selectedText ? (root.selectedText[modelData.flag] ?? false) : false
                    onClicked: root.toggleTextStyle(modelData.flag)
                    StyledToolTip { text: modelData.name }
                }
            }

            FadeIconButton {
                text: "control_point_duplicate"
                enabled: root.selected !== null
                onClicked: root.duplicateSelected()
                StyledToolTip { text: Translation.tr("Duplicate (Ctrl+D)") }
            }

            FadeIconButton {
                text: "delete"
                enabled: root.selected !== null
                onClicked: root.deleteSelected()
                StyledToolTip { text: Translation.tr("Delete (Del)") }
            }

            FadeIconButton {
                text: "undo"
                enabled: root.undoStack.length > 0
                onClicked: root.undo()
                StyledToolTip { text: Translation.tr("Undo (Ctrl+Z)") }
            }

            FadeIconButton {
                text: "redo"
                enabled: root.redoStack.length > 0
                onClicked: root.redo()
                StyledToolTip { text: Translation.tr("Redo (Ctrl+Y)") }
            }

            IconToolbarButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                focusPolicy: Qt.NoFocus
                text: "content_copy"
                onClicked: root.requestClipboard()
                StyledToolTip { text: Translation.tr("Copy to clipboard (Ctrl+C)") }
            }

            FloatingActionButton {
                id: saveFab
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                focusPolicy: Qt.NoFocus
                baseSize: 44
                iconText: "done"
                onClicked: root.requestSave()
                StyledToolTip { text: Translation.tr("Save to screenshots folder (Ctrl+S)") }
            }

            IconToolbarButton {
                id: closeBtn
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                focusPolicy: Qt.NoFocus
                text: "close"
                onClicked: root.close()
                StyledToolTip { text: Translation.tr("Discard (Esc)") }
            }
        }
    }

    } // keySink

    // ── Export ────────────────────────────────────────────────────────────────
    readonly property string _tempDir: (Quickshell.env("XDG_RUNTIME_DIR") && Quickshell.env("XDG_RUNTIME_DIR").length > 0)
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell"
        : "/tmp/quickshell"
    readonly property string _outPath: _tempDir + "/annotated-" + root.screen.name + ".png"

    // Offscreen crop of captureArea in the same coordinate space as the white
    // selection rect. Avoids grabToImage+magick scale/DPR mismatches that made
    // the saved region look nothing like the on-screen crop.
    ShaderEffectSource {
        id: exportClip
        visible: false
        live: false
        hideSource: false
        recursive: true
        sourceItem: captureArea
        width: 1
        height: 1
        sourceRect: Qt.rect(0, 0, 1, 1)
    }

    function exportImage() {
        if (root.crop === null) {
            Quickshell.execDetached(["/usr/bin/notify-send", "Screenshot", "Crop a region first", "-a", "Screenshot", "-t", "2000"]);
            return;
        }
        if (GlobalStates.screenshotEditorActiveScreen === "")
            GlobalStates.screenshotEditorActiveScreen = root.screen.name;
        if (GlobalStates.screenshotEditorActiveScreen !== ""
            && GlobalStates.screenshotEditorActiveScreen !== root.screen.name) {
            console.warn("[ScreenshotEditor] export ignored on", root.screen.name,
                "— active is", GlobalStates.screenshotEditorActiveScreen);
            return;
        }

        if (sourceImage.status !== Image.Ready) {
            if (_exportPending) return;
            _exportPending = true;
            exportWaitTimer.start();
            exportGiveUpTimer.start();
            return;
        }
        _exportPending = false;
        exportWaitTimer.stop();
        exportGiveUpTimer.stop();

        const c = root.crop;
        const aw = Math.max(1, captureArea.width);
        const ah = Math.max(1, captureArea.height);
        const cx = Math.max(0, Math.min(c.x, aw - 1));
        const cy = Math.max(0, Math.min(c.y, ah - 1));
        const cw = Math.max(1, Math.min(c.w, aw - cx));
        const ch = Math.max(1, Math.min(c.h, ah - cy));

        exportClip.sourceRect = Qt.rect(cx, cy, cw, ch);
        exportClip.width = cw;
        exportClip.height = ch;

        // Prefer native screenshot pixel density when available.
        const srcW = sourceImage.sourceSize.width;
        const srcH = sourceImage.sourceSize.height;
        const scale = (srcW > 0 && srcH > 0) ? Math.max(srcW / aw, srcH / ah, 1) : 1;
        const outW = Math.max(1, Math.round(cw * scale));
        const outH = Math.max(1, Math.round(ch * scale));

        exportClip.scheduleUpdate();
        // One frame so the ShaderEffectSource texture reflects sourceRect.
        Qt.callLater(() => {
            exportClip.grabToImage(function(result) {
                if (!result) {
                    console.warn("[ScreenshotEditor] crop grabToImage returned null");
                    Quickshell.execDetached(["/usr/bin/notify-send", "Edit failed", "Could not capture editor", "-a", "Screenshot", "-t", "3000"]);
                    return;
                }
                const saved = result.saveToFile(root._outPath);
                if (!saved) {
                    console.warn("[ScreenshotEditor] saveToFile failed for", root._outPath);
                    Quickshell.execDetached(["/usr/bin/notify-send", "Edit failed", "Could not write temp file", "-a", "Screenshot", "-t", "3000"]);
                    return;
                }
                cleanupProc.startDetached();
                if (root._exportMode === "clipboard")
                    clipboardProc.startDetached();
                else
                    saveProc.startDetached();
                root.close();
            }, Qt.size(outW, outH));
        });
    }

    // Best-effort temp cleanup after cp/wl-copy have had time to read it.
    Process {
        id: cleanupProc
        command: ["/usr/bin/bash", "-c", `sleep 3 && /usr/bin/rm -f '${root._outPath}'`]
        onExited: (code) => { if (code !== 0) console.warn("[ScreenshotEditor] cleanup exit", code); }
    }

    Process {
        id: prepareTempProc
        command: ["/usr/bin/mkdir", "-p", root._tempDir]
        running: true
        onExited: (code) => { if (code !== 0) console.warn("[ScreenshotEditor] temp dir mkdir exit", code); }
    }

    Timer {
        id: exportWaitTimer
        interval: 50
        repeat: true
        onTriggered: {
            if (sourceImage.status === Image.Ready) {
                stop();
                _exportPending = false;
                root.exportImage();
            }
        }
    }
    Timer {
        id: exportGiveUpTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (_exportPending) {
                _exportPending = false;
                exportWaitTimer.stop();
                console.warn("[ScreenshotEditor] image load timed out");
                Quickshell.execDetached(["/usr/bin/notify-send", "Edit failed", "Image load timed out", "-a", "Screenshot", "-t", "3000"]);
            }
        }
    }

    // Disk only (Ctrl+S / Done).
    Process {
        id: saveProc
        command: ["/usr/bin/bash", "-c", `
            _dir='${StringUtils.shellSingleQuoteEscape(Directories.screenshotsPath)}';
            _fmt='${StringUtils.shellSingleQuoteEscape(Config.options?.regionSelector?.screenshotNameFormat ?? "ss-%Y%m%d-%H%M%S")}';
            mkdir -p "$_dir" || { echo "mkdir failed: $_dir" >&2; exit 1; };
            _ss="$_dir/$(date +"$_fmt").png";
            if ! cp '${root._outPath}' "$_ss"; then
                echo "cp failed: ${root._outPath} -> $_ss" >&2;
                /usr/bin/notify-send "Edit failed" "Could not copy to screenshots folder" -a "Screenshot" -i camera-photo -t 4000;
                exit 2;
            fi;
            /usr/bin/notify-send "Screenshot edited" "Saved to $_ss" -a "Screenshot" -i camera-photo -t 4000;
        `]
        onExited: (code) => {
            if (code !== 0) console.warn("[ScreenshotEditor] saveProc exit", code);
        }
    }

    // Clipboard only (Ctrl+C / copy button). No file in screenshots folder.
    Process {
        id: clipboardProc
        command: ["/usr/bin/bash", "-c", `
            if ! command -v /usr/bin/wl-copy >/dev/null 2>&1; then
                /usr/bin/notify-send "Edit failed" "wl-copy not found (install wl-clipboard)" -a "Screenshot" -i camera-photo -t 4000;
                exit 1;
            fi;
            if ! /usr/bin/wl-copy < '${root._outPath}' 2>/dev/null; then
                /usr/bin/notify-send "Edit failed" "Could not copy image to clipboard" -a "Screenshot" -i camera-photo -t 4000;
                exit 2;
            fi;
            /usr/bin/notify-send "Screenshot edited" "Copied to clipboard" -a "Screenshot" -i camera-photo -t 3000;
        `]
        onExited: (code) => {
            if (code !== 0) console.warn("[ScreenshotEditor] clipboardProc exit", code);
        }
    }
}
