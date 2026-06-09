pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Native screenshot annotation editor. Loads a cropped screenshot, lets the
// user draw (pen / rectangle / arrow / text / highlight), then exports the
// composited result to the clipboard and the screenshots folder. Replaces the
// external swappy/satty editor for the region selector's Edit action.
PanelWindow {
    id: root

    property string imagePath: GlobalStates.annotationEditorPath
    signal finished()

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:annotationEditor"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    screen: Quickshell.screens[0] ?? null
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    // ── Tool state ──────────────────────────────────────────────────────────
    property string tool: "pen"           // pen | rect | arrow | text | highlight
    property color strokeColor: Appearance.m3colors.m3primary
    property real strokeWidth: 4
    property var strokes: []              // committed shape strokes
    property var texts: []                // committed text annotations
    property var history: []              // creation order: {kind:"shape"|"text"}
    property var current: null            // live shape being drawn
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

    function setCurrent(s) { root.current = s; }

    function commitShape(s) {
        const arr = root.strokes.slice(); arr.push(s); root.strokes = arr;
        const h = root.history.slice(); h.push({ kind: "shape" }); root.history = h;
    }
    function addText(x, y) {
        const arr = root.texts.slice();
        arr.push({ x: x, y: y, text: "", color: String(root.strokeColor), size: Math.max(14, root.strokeWidth * 5) });
        root.texts = arr;
        const h = root.history.slice(); h.push({ kind: "text" }); root.history = h;
        textRepeater.focusLast();
    }
    function undo() {
        if (root.history.length === 0) return;
        const h = root.history.slice(); const last = h.pop(); root.history = h;
        if (last.kind === "shape") { const a = root.strokes.slice(); a.pop(); root.strokes = a; }
        else { const a = root.texts.slice(); a.pop(); root.texts = a; }
    }
    function clearAll() { root.strokes = []; root.texts = []; root.history = []; root.current = null; }

    function close() {
        GlobalStates.annotationEditorOpen = false;
        GlobalStates.annotationEditorPath = "";
        root.finished();
    }

    // Build the polyline points for a shape stroke based on its tool.
    function pointsFor(s) {
        if (!s || !s.pts || s.pts.length === 0) return [];
        if (s.tool === "pen" || s.tool === "highlight") return s.pts;
        const a = s.pts[0]; const b = s.pts[s.pts.length - 1];
        if (s.tool === "rect")
            return [Qt.point(a.x, a.y), Qt.point(b.x, a.y), Qt.point(b.x, b.y), Qt.point(a.x, b.y), Qt.point(a.x, a.y)];
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

    // Keyboard shortcuts. PanelWindow is not an Item, so Keys must attach to an
    // Item; this focus holder catches Esc/Ctrl+Z when no text field is editing.
    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true; }
            else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Z) { root.undo(); e.accepted = true; }
        }
    }

    // Dim background
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    ColumnLayout {
        id: editorStack
        anchors.centerIn: parent
        spacing: 18
        // Avoid the empty-canvas flash while the screenshot decodes.
        opacity: sourceImage.status === Image.Ready || sourceImage.status === Image.Error ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type }
        }

        // ── Canvas (image + annotations) — this is what gets exported ─────────
        Item {
            id: captureArea
            Layout.alignment: Qt.AlignHCenter
            readonly property real maxW: root.width * 0.82
            readonly property real maxH: root.height * 0.74
            readonly property real iw: sourceImage.sourceSize.width
            readonly property real ih: sourceImage.sourceSize.height
            readonly property real fit: (iw > 0 && ih > 0) ? Math.min(maxW / iw, maxH / ih, 1) : 1
            implicitWidth: iw > 0 ? Math.round(iw * fit) : 480
            implicitHeight: ih > 0 ? Math.round(ih * fit) : 320
            width: implicitWidth
            height: implicitHeight

            // Visual frame only; export still captures the source image bounds.
            Rectangle {
                id: captureClip
                anchors.fill: parent
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                Behavior on radius {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type }
                }
            }

            Image {
                id: sourceImage
                anchors.fill: parent
                source: root.imagePath !== "" ? `file://${root.imagePath}` : ""
                fillMode: Image.Stretch
                smooth: true
                cache: false
            }

            // Committed shapes
            Repeater {
                model: root.strokes
                delegate: Shape {
                    id: shapeDelegate
                    required property var modelData
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: shapeDelegate.modelData.color
                        strokeWidth: shapeDelegate.modelData.width
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: root.pointsFor(shapeDelegate.modelData) }
                    }
                }
            }

            // Canvas avoids rebuilding Shape/PathPolyline geometry per mouse move.
            Canvas {
                id: liveCanvas
                anchors.fill: parent
                z: 10
                visible: root.current !== null
                // Threaded paint keeps the input path responsive while drawing.
                renderStrategy: Canvas.Threaded
                renderTarget: Canvas.Image

                property var s: root.current

                Connections {
                    target: root
                    function onCurrentChanged() {
                        liveCanvas.s = root.current;
                        liveCanvas.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!liveCanvas.s) return;
                    const pts = root.pointsFor(liveCanvas.s);
                    if (pts.length < 2) return;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.lineWidth = liveCanvas.s.width;
                    ctx.strokeStyle = liveCanvas.s.color;
                    ctx.globalAlpha = liveCanvas.s.tool === "highlight" ? 0.4 : 1.0;
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x, pts[0].y);
                    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
                    ctx.stroke();
                    ctx.globalAlpha = 1.0;
                }
            }

            // Committed text annotations
            Repeater {
                id: textRepeater
                model: root.texts
                function focusLast() { if (count > 0) itemAt(count - 1)?.focusInput(); }
                delegate: TextInput {
                    id: textInput
                    z: 20
                    required property var modelData
                    required property int index
                    function focusInput() { textInput.forceActiveFocus(); }
                    x: modelData.x
                    y: modelData.y
                    color: modelData.color
                    font.pixelSize: modelData.size
                    font.family: Appearance.font.family.main
                    text: modelData.text
                    onTextChanged: root.texts[index].text = text
                    selectByMouse: true
                    cursorVisible: activeFocus
                    Component.onCompleted: if (text === "") forceActiveFocus()
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 5
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.CrossCursor
                // Reduce slow-stroke point spam without visible shape loss.
                readonly property real minPointStep: 2.5
                property point _lastPenPoint: Qt.point(NaN, NaN)

                onPressed: (m) => {
                    if (root.tool === "text") { root.addText(m.x, m.y); return; }
                    _lastPenPoint = Qt.point(m.x, m.y);
                    root.setCurrent({
                        tool: root.tool,
                        color: root.tool === "highlight" ? ColorUtils.transparentize(root.strokeColor, 0.6) : String(root.strokeColor),
                        width: root.tool === "highlight" ? root.strokeWidth * 4 : root.strokeWidth,
                        pts: [Qt.point(m.x, m.y)]
                    });
                }
                onPositionChanged: (m) => {
                    if (!root.current) return;
                    const c = root.current;
                    const dx = m.x - _lastPenPoint.x;
                    const dy = m.y - _lastPenPoint.y;
                    if (dx*dx + dy*dy < minPointStep * minPointStep) return;
                    _lastPenPoint = Qt.point(m.x, m.y);
                    if (c.tool === "pen" || c.tool === "highlight") c.pts.push(Qt.point(m.x, m.y));
                    else c.pts = [c.pts[0], Qt.point(m.x, m.y)];
                    root.setCurrent(c);
                }
                onReleased: () => {
                    if (root.current) { root.commitShape(root.current); root.setCurrent(null); }
                    _lastPenPoint = Qt.point(NaN, NaN);
                }
            }
        }

        // ── Tool palette ──────────────────────────────────────────────────────
        // Gives the existing Toolbar widget a stable M3-height shell.
        Item {
            id: toolbarShell
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: editorToolbar.implicitWidth
            implicitHeight: 64

            Toolbar {
                id: editorToolbar
                anchors.fill: parent
                padding: 10
                radius: Appearance.rounding.full
                spacing: 6

                // Use the native toolbar button so style dispatch stays centralized.
                Repeater {
                    model: [
                        { "tool": "pen", "icon": "edit" },
                        { "tool": "rect", "icon": "rectangle" },
                        { "tool": "arrow", "icon": "north_east" },
                        { "tool": "text", "icon": "title" },
                        { "tool": "highlight", "icon": "ink_highlighter" }
                    ]
                    delegate: IconToolbarButton {
                        id: toolBtn
                        required property var modelData
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillHeight: true
                        text: modelData.icon
                        toggled: root.tool === modelData.tool
                        onClicked: root.tool = modelData.tool
                        StyledToolTip { text: Translation.tr(modelData.tool === "pen" ? "Pen"
                            : modelData.tool === "rect" ? "Rectangle"
                            : modelData.tool === "arrow" ? "Arrow"
                            : modelData.tool === "text" ? "Text"
                            : "Highlighter") }
                    }
                }

                // Divider
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 1
                    implicitHeight: 22
                    color: Appearance.colors.colOutlineVariant
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }

                // Color swatches with animated checked ring.
                Repeater {
                    model: root.palette
                    delegate: Rectangle {
                        id: swatch
                        required property var modelData
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: swatch.modelData
                        border.width: root.strokeColor == swatch.modelData ? 3 : 1
                        border.color: root.strokeColor == swatch.modelData
                            ? Appearance.colors.colOnLayer1
                            : Appearance.colors.colOutlineVariant
                        Behavior on border.width {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.strokeColor = swatch.modelData
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 1
                    implicitHeight: 22
                    color: Appearance.colors.colOutlineVariant
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }

                StyledSlider {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 96
                    from: 1; to: 24
                    value: root.strokeWidth
                    onValueChanged: root.strokeWidth = value
                    StyledToolTip { text: Translation.tr("Stroke width") }
                }

                IconToolbarButton {
                    id: undoBtn
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    text: "undo"
                    enabled: root.history.length > 0
                    onClicked: root.undo()
                    opacity: enabled ? 1 : 0.4
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                    StyledToolTip { text: Translation.tr("Undo (Ctrl+Z)") }
                }

                // Done communicates completion better than the old copy icon.
                FloatingActionButton {
                    id: saveFab
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    baseSize: 44
                    iconText: "done"
                    onClicked: root.exportImage()
                    StyledToolTip { text: Translation.tr("Save & copy to clipboard") }
                }

                IconToolbarButton {
                    id: closeBtn
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    text: "close"
                    onClicked: root.close()
                    StyledToolTip { text: Translation.tr("Discard (Esc)") }
                }
            }
        }
    }

    // ── Export ────────────────────────────────────────────────────────────────
    // Stable per-session temp path keeps Process.command binding simple.
    readonly property string _tempDir: (Quickshell.env("XDG_RUNTIME_DIR") && Quickshell.env("XDG_RUNTIME_DIR").length > 0)
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell"
        : "/tmp/quickshell"
    property string _outPath: _tempDir + "/annotated.png"

    function exportImage() {
        // Drop text focus so the cursor isn't captured in the grab.
        keySink.forceActiveFocus();

        // Wait for intrinsic size; grabbing while Loading can produce 0x0 output.
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

        const iw = sourceImage.sourceSize.width;
        const ih = sourceImage.sourceSize.height;
        if (iw <= 0 || ih <= 0) {
            console.warn("[AnnotationEditor] source size 0, aborting export");
            Quickshell.execDetached(["/usr/bin/notify-send", "Edit failed", "Image not ready", "-a", "Screenshot", "-t", "3000"]);
            return;
        }

        captureArea.grabToImage(function(result) {
            // This Qt build exposes only the sync saveToFile() form.
            const saved = result.saveToFile(root._outPath);
            if (!saved) {
                console.warn("[AnnotationEditor] saveToFile failed for", root._outPath);
                Quickshell.execDetached(["/usr/bin/notify-send", "Edit failed", "Could not write temp file", "-a", "Screenshot", "-t", "3000"]);
                return;
            }
            // Let cp/wl-copy read the temp file before cleanup.
            cleanupProc.startDetached();
            saveProc.startDetached();
            root.close();
        }, Qt.size(iw, ih));
    }

    // Best-effort temp cleanup after cp/wl-copy have had time to read it.
    Process {
        id: cleanupProc
        command: ["/usr/bin/bash", "-c", `sleep 3 && /usr/bin/rm -f '${root._outPath}'`]
        onExited: (code) => { if (code !== 0) console.warn("[AnnotationEditor] cleanup exit", code); }
    }

    Process {
        id: prepareTempProc
        command: ["/usr/bin/mkdir", "-p", root._tempDir]
        running: true
        onExited: (code) => { if (code !== 0) console.warn("[AnnotationEditor] temp dir mkdir exit", code); }
    }

    // Raw ms (P0-10): this is export polling, not visual animation.
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
                console.warn("[AnnotationEditor] image load timed out");
                Quickshell.execDetached(["/usr/bin/notify-send", "Edit failed", "Image load timed out", "-a", "Screenshot", "-t", "3000"]);
            }
        }
    }

    // Clipboard is best-effort; saving to disk must still report success.
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
            # Clipboard is best-effort. wl-copy returns non-zero if the
            # wl-clipboard manager isn't running — don't fail the whole chain.
            _clip_msg="";
            if command -v /usr/bin/wl-copy >/dev/null 2>&1 && /usr/bin/wl-copy < "$_ss" 2>/dev/null && echo -n "$_ss" | /usr/bin/wl-copy --primary 2>/dev/null; then
                _clip_msg=" — copied to clipboard";
            else
                _clip_msg=" — clipboard unavailable (is wl-clipboard running?)";
            fi;
            /usr/bin/notify-send "Screenshot edited" "Saved to $_ss$_clip_msg" -a "Screenshot" -i camera-photo -t 4000;
        `]
        onExited: (code) => {
            if (code !== 0) console.warn("[AnnotationEditor] saveProc exit", code);
        }
    }
}
