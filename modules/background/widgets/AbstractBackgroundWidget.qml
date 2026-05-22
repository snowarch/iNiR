pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas

AbstractWidget {
    id: root

    required property string configEntryName
    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    readonly property string _configPath: "background.widgets." + root.configEntryName
    property bool visibleWhenLocked: false
    property int widgetIndex: 0 // used to offset auto-placed widgets so they don't stack
    // Supports nested configEntryName like "custom.my-widget"
    // Custom widget data lives in Config.customWidgetData (outside adapter).
    property var configEntry: Config.getNestedValue(root._configPath, ({}))
    // Disable base class x/y behaviors — we define our own with _autoPosition gating
    animateXPos: false
    animateYPos: false

    // ── Per-widget lock (prevent accidental drag/resize) ──
    readonly property bool locked: Boolean(root._readConfigKey("locked") ?? false)

    // ── Per-widget customization (inherited by all widgets) ──
    readonly property real _baseScale: {
        const v = Number(root._readConfigKey("widgetScale") ?? 100);
        return Math.max(0.5, Math.min(2.0, Number.isFinite(v) ? v / 100 : 1.0));
    }
    // scaleFactor: the final multiplier widgets use for layout dimensions and font sizes.
    // Includes press bump when dragging. Widgets should multiply their sizes by this
    // instead of relying on Item.scale (which causes bitmap blur).
    property bool _isResizing: false
    readonly property real scaleFactor: ((draggable && containsPress && !_isResizing) ? 1.05 : 1.0) * _baseScale
    readonly property real widgetOpacity: {
        const v = Number(root._readConfigKey("widgetOpacity") ?? 100);
        return Math.max(0, Math.min(1, Number.isFinite(v) ? v / 100 : 1.0));
    }
    readonly property bool showBackground: root._readConfigKey("showBackground") ?? true
    readonly property bool useBlur: root._readConfigKey("useBlur") ?? false
    readonly property bool showBorder: root._readConfigKey("showBorder") ?? true
    // Granular card controls — override booleans when present
    readonly property real backgroundOpacity: {
        const v = root._readConfigKey("backgroundOpacity");
        return (v !== undefined && v !== null) ? Math.max(0, Math.min(1, Number(v))) : (showBackground ? 0.06 : 0);
    }
    readonly property real borderWidth: {
        const v = root._readConfigKey("borderWidth");
        return (v !== undefined && v !== null) ? Math.max(0, Math.min(8, Number(v))) : (showBorder ? 1 : 0);
    }
    readonly property real borderOpacity: {
        const v = root._readConfigKey("borderOpacity");
        return (v !== undefined && v !== null) ? Math.max(0, Math.min(1, Number(v))) : 0.08;
    }
    readonly property real cornerRadiusOverride: root._readConfigKey("cornerRadius") ?? -1
    readonly property string colorMode: root._readConfigKey("colorMode") ?? "auto"
    property string placementStrategy: root._readConfigKey("placementStrategy") ?? "free"

    // ── Snap zones ────────────────────────────────────────────
    // 9 screen regions for quick widget placement
    readonly property var _snapZones: [
        "topLeft", "topCenter", "topRight",
        "centerLeft", "center", "centerRight",
        "bottomLeft", "bottomCenter", "bottomRight"
    ]
    readonly property var _snapZoneLabels: ({
        topLeft: "↖", topCenter: "↑", topRight: "↗",
        centerLeft: "←", center: "⊙", centerRight: "→",
        bottomLeft: "↙", bottomCenter: "↓", bottomRight: "↘"
    })
    // Margin from screen edges for zone placement
    readonly property int _zoneMargin: 48

    function _getZonePosition(zone: string): point {
        const m = root._zoneMargin;
        const w = root.scaledScreenWidth;
        const h = root.scaledScreenHeight;
        const ww = root.width;
        const wh = root.height;
        const cx = (w - ww) / 2;
        const cy = (h - wh) / 2;
        switch (zone) {
            case "topLeft":      return Qt.point(m, m);
            case "topCenter":    return Qt.point(cx, m);
            case "topRight":     return Qt.point(w - ww - m, m);
            case "centerLeft":   return Qt.point(m, cy);
            case "center":       return Qt.point(cx, cy);
            case "centerRight":  return Qt.point(w - ww - m, cy);
            case "bottomLeft":   return Qt.point(m, h - wh - m);
            case "bottomCenter": return Qt.point(cx, h - wh - m);
            case "bottomRight":  return Qt.point(w - ww - m, h - wh - m);
            default:             return Qt.point(cx, cy);
        }
    }

    function _cycleSnapZone(): void {
        const current = root.placementStrategy;
        const idx = root._snapZones.indexOf(current);
        const next = root._snapZones[(idx + 1) % root._snapZones.length];
        root.snapToZone(next);
    }

    function _toggleZonePlacement(): void {
        if (root._isZonePlacement) {
            const prefix = root._configPath;
            let updates = {};
            updates[prefix + ".placementStrategy"] = "free";
            updates[prefix + ".x"] = root._snapToPixel(root.x);
            updates[prefix + ".y"] = root._snapToPixel(root.y);
            Config.setNestedValues(updates);
            return;
        }
        root.snapToZone(root._nearestZone(root.x, root.y));
    }

    function snapToZone(zone: string): void {
        const pos = root._getZonePosition(zone);
        const finalX = root._snapToPixel(pos.x);
        const finalY = root._snapToPixel(pos.y);
        const prefix = root._configPath;
        let updates = {};
        if (root.placementStrategy !== zone)
            updates[prefix + ".placementStrategy"] = zone;
        if (Number(root._readConfigKey("x")) !== finalX)
            updates[prefix + ".x"] = finalX;
        if (Number(root._readConfigKey("y")) !== finalY)
            updates[prefix + ".y"] = finalY;
        if (Object.keys(updates).length > 0)
            Config.setNestedValues(updates);
    }

    // Detect which zone a position is closest to (for drag-to-snap)
    function _nearestZone(px: real, py: real): string {
        let closest = "center";
        let minDist = Infinity;
        for (let i = 0; i < root._snapZones.length; i++) {
            const zone = root._snapZones[i];
            const pos = root._getZonePosition(zone);
            const dx = px - pos.x;
            const dy = py - pos.y;
            const dist = dx * dx + dy * dy;
            if (dist < minDist) {
                minDist = dist;
                closest = zone;
            }
        }
        return closest;
    }

    function _snapToPixel(value: real): real {
        const numeric = Number(value)
        return Math.round(Number.isFinite(numeric) ? numeric : 0)
    }

    // Auto-placement results from image analysis (leastBusy/mostBusy)
    property real _autoPlaceX: 0
    property real _autoPlaceY: 0
    readonly property bool _isAutoPlacement: root.placementStrategy === "leastBusy" || root.placementStrategy === "mostBusy"

    function _clampX(value: real): real {
        const maxX = Math.max(0, root.scaledScreenWidth - root.width);
        return root._snapToPixel(Math.max(0, Math.min(Number(value) || 0, maxX)));
    }

    function _clampY(value: real): real {
        const maxY = Math.max(0, root.scaledScreenHeight - root.height);
        return root._snapToPixel(Math.max(0, Math.min(Number(value) || 0, maxY)));
    }

    // Target position — zones read stored config, free clamps to screen
    property real targetX: {
        if (root._isZonePlacement) {
            const rawX = Number(root._readConfigKey("x") ?? 0);
            return _snapToPixel(Number.isFinite(rawX) ? rawX : 0);
        }
        if (root.placementStrategy === "free") {
            const rawX = Number(root._readConfigKey("x") ?? 0);
            const safeX = Number.isFinite(rawX) ? rawX : 0;
            return root._clampX(safeX);
        }
        return root._clampX(root._autoPlaceX);
    }
    property real targetY: {
        if (root._isZonePlacement) {
            const rawY = Number(root._readConfigKey("y") ?? 0);
            return _snapToPixel(Number.isFinite(rawY) ? rawY : 0);
        }
        if (root.placementStrategy === "free") {
            const rawY = Number(root._readConfigKey("y") ?? 0);
            const safeY = Number.isFinite(rawY) ? rawY : 0;
            return root._clampY(safeY);
        }
        return root._clampY(root._autoPlaceY);
    }

    // Guard: briefly suppress auto-position after release so onReleased can update config
    property bool _releaseGuard: false
    Timer {
        id: _releaseGuardTimer
        interval: 50
        onTriggered: root._releaseGuard = false
    }

    // Auto-position when NOT free and NOT actively being dragged in edit mode
    readonly property bool _autoPosition: root.placementStrategy !== "free" && !(GlobalStates.widgetEditMode && (root.isDragging || root.containsPress || root._isResizing || root._releaseGuard))
    Binding {
        target: root
        property: "x"
        value: root.targetX
        when: root._autoPosition
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "y"
        value: root.targetY
        when: root._autoPosition
        restoreMode: Binding.RestoreNone
    }

    // Re-clamp position in "free" mode when the widget grows past the screen
    // edge (e.g. media widget gaining an extra MPRIS player). Without these,
    // the user has to manually reposition each time content size changes.
    // Bindings are inactive while user is interacting (drag/resize), and never
    // overwrite the saved config — only the rendered position.
    readonly property bool _freeModeOverflowGuard: root.placementStrategy === "free"
        && Config.ready
        && root.width > 0 && root.height > 0
        && !(GlobalStates.widgetEditMode && (root.isDragging || root.containsPress || root._isResizing || root._releaseGuard))
    readonly property bool _xOverflows: root.x + root.width > root.scaledScreenWidth
    readonly property bool _yOverflows: root.y + root.height > root.scaledScreenHeight
    Binding {
        target: root
        property: "x"
        value: Math.max(0, root.scaledScreenWidth - root.width)
        when: root._freeModeOverflowGuard && root._xOverflows
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "y"
        value: Math.max(0, root.scaledScreenHeight - root.height)
        when: root._freeModeOverflowGuard && root._yOverflows
        restoreMode: Binding.RestoreNone
    }
    Behavior on x {
        enabled: Appearance.animationsEnabled && root._autoPosition
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
    Behavior on y {
        enabled: Appearance.animationsEnabled && root._autoPosition
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }

    visible: opacity > 0
    opacity: ((GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1) * widgetOpacity
    enabled: !GlobalStates.screenLocked
    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    // No Item.scale — widgets use scaleFactor for layout math to avoid bitmap blur

    // In edit mode, allow dragging regardless of strategy (user can reposition freely)
    readonly property bool _isZonePlacement: root._snapZones.indexOf(root.placementStrategy) >= 0
    draggable: (placementStrategy === "free" || GlobalStates.widgetEditMode) && !GlobalStates.screenLocked && !root.locked
    function syncFreePositionFromConfig(): void {
        if (!Config.ready) return;
        if (root.placementStrategy !== "free") return;
        root.x = root.targetX;
        root.y = root.targetY;
    }

    function applyPlacementFromConfig(): void {
        if (!Config.ready) return;
        if (root._isZonePlacement) {
            root.snapToZone(root.placementStrategy);
            // Zone widgets still need color analysis at their position
            if (root.needsColText) _placementDebounce.restart();
        } else {
            syncFreePositionFromConfig();
            refreshPlacementIfNeeded();
        }
    }

    readonly property int _editGridSize: Config.getNestedValue("background.widgets.editGrid.size", 32)
    readonly property bool _snapEnabled: GlobalStates.widgetEditMode && (Config.getNestedValue("background.widgets.editGrid.snap", true))

    function _snapToGrid(value: real): real {
        return Math.round(value / _editGridSize) * _editGridSize;
    }

    // Snap preview ghost — shows where widget will land while dragging
    property real _snapPreviewX: _snapEnabled ? _snapToGrid(root.x) : root.x
    property real _snapPreviewY: _snapEnabled ? _snapToGrid(root.y) : root.y
    Rectangle {
        id: snapGhost
        visible: root.containsPress && root._snapEnabled && root.draggable
        x: root._snapPreviewX - root.x
        y: root._snapPreviewY - root.y
        width: root.width
        height: root.height
        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 1.5
        border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.35)
        opacity: 0.7
    }

    // ── Edit mode toolbar (proper Material action bar) ─────────
    // Toolbar is in screen-pixel space (no Item.scale on widget)
    Item {
        id: editToolbar
        z: 200
        visible: opacity > 0
        opacity: GlobalStates.widgetEditMode ? 1 : 0
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.top
            bottomMargin: 12
        }
        width: toolbarRow.implicitWidth + 12
        height: 36

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Prevent drag from starting on toolbar clicks
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.AllButtons
            propagateComposedEvents: false
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer2
            border { width: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12) }
        }

        Row {
            id: toolbarRow
            anchors.centerIn: parent
            spacing: 2

            RippleButton {
                id: lockBtn
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                toggled: root.locked
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colError, 0.14)
                colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.22)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                downAction: () => Config.setNestedValue(root._configPath + ".locked", !root.locked)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.locked ? "lock" : "lock_open"
                    iconSize: 18
                    color: root.locked ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: root.locked ? Translation.tr("Unlock position") : Translation.tr("Lock position") }
            }

            RippleButton {
                id: snapZoneBtn
                visible: !root.locked
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                toggled: root._isZonePlacement
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                colRippleToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                downAction: () => { root._toggleZonePlacement() }
                altAction: () => { root._cycleSnapZone() }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root._isZonePlacement ? "grid_on" : "grid_view"
                    iconSize: 18
                    color: root._isZonePlacement ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: root._isZonePlacement ? Translation.tr("Zone placement active — click for free placement, right-click to cycle") : Translation.tr("Use nearest snap zone") }
            }

            RippleButton {
                id: resetBtn
                visible: !root.locked
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                downAction: () => { root.resetToDefaults() }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "restart_alt"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: Translation.tr("Reset to defaults") }
            }

            Rectangle {
                visible: !root.locked
                width: 1; height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.15)
            }

            RippleButton {
                id: popoverBtn
                visible: root._effectivePopover !== null && !root.locked
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                toggled: editPopoverPanel.visible
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                downAction: () => { editPopoverPanel.visible = !editPopoverPanel.visible }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "tune"
                    iconSize: 18
                    color: popoverBtn.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: Translation.tr("Quick controls") }
            }

            RippleButton {
                id: settingsBtn
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                downAction: () => {
                    if (Config.options?.settingsUi?.overlayMode !== false) {
                        GlobalStates.settingsOverlayRequestedPage = 14
                        GlobalStates.settingsOverlayOpen = true
                    } else {
                        Quickshell.execDetached(["/usr/bin/env", "QS_SETTINGS_PAGE=14", Quickshell.shellPath("scripts/inir"), "settings-window"])
                    }
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "settings"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: Translation.tr("Widget settings") }
            }
        }

        // Inline popover panel (appears above the toolbar, away from widget)
        Item {
            id: editPopoverPanel
            visible: false
            anchors {
                bottom: toolbarRow.top
                bottomMargin: 6
                horizontalCenter: toolbarRow.horizontalCenter
            }
            width: popoverLoader.item ? popoverLoader.item.implicitWidth + 16 : 200
            height: popoverLoader.item ? popoverLoader.item.implicitHeight + 16 : 0

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
            }

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border { width: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12) }
            }

            Loader {
                id: popoverLoader
                anchors.centerIn: parent
                sourceComponent: root._effectivePopover
                active: editPopoverPanel.visible && root._effectivePopover !== null
            }
        }
    }

    // ── Edit mode widget name label ─────────────────────────
    Row {
        z: 200
        visible: GlobalStates.widgetEditMode
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.bottom
            topMargin: 6
        }
        spacing: 4

        // Placement strategy badge
        Rectangle {
            visible: root.placementStrategy !== "free"
            anchors.verticalCenter: parent.verticalCenter
            width: strategyIcon.implicitWidth + 6
            height: strategyIcon.implicitHeight + 4
            radius: Appearance.rounding.small
            color: ColorUtils.applyAlpha(
                root.locked ? Appearance.colors.colError
                    : root._isZonePlacement ? Appearance.colors.colPrimary
                    : Appearance.colors.colTertiary, 0.18)
            MaterialSymbol {
                id: strategyIcon
                anchors.centerIn: parent
                iconSize: 10
                text: root.locked ? "lock"
                    : root._isZonePlacement ? "grid_on"
                    : root._isAutoPlacement ? "auto_awesome" : ""
                color: root.locked ? Appearance.colors.colError
                    : root._isZonePlacement ? Appearance.colors.colPrimary
                    : Appearance.colors.colTertiary
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.configEntryName.split(".").pop()
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.5)
        }
    }

    // ── Edit mode selection outline ──────────────────────────
    Rectangle {
        z: 199
        anchors.fill: parent
        anchors.margins: -4
        visible: GlobalStates.widgetEditMode
        color: "transparent"
        radius: Appearance.rounding.small + 4
        border {
            width: root.locked ? 2 : 1.5
            color: root.locked
                ? ColorUtils.applyAlpha(Appearance.colors.colError, 0.35)
                : ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.4)
        }
    }

    // ── Edit mode resize handles ─────────────────────────────
    readonly property bool _hasResize: Object.keys(root.resizableAxes).length > 0
    readonly property bool _resizeVisible: GlobalStates.widgetEditMode && root._hasResize && !root.locked

    // Resize handle component — small draggable square at edges/corners
    component ResizeHandle: Rectangle {
        id: rh
        // Which edges this handle controls
        property bool resizeLeft: false
        property bool resizeRight: false
        property bool resizeTop: false
        property bool resizeBottom: false

        z: 201
        visible: root._resizeVisible
        width: 10; height: 10
        radius: 3
        color: Appearance.colors.colPrimary
        border { width: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.3) }
        opacity: rhArea.containsMouse || rhArea.pressed ? 1.0 : 0.7

        // Track drag start state in canvas-space to avoid feedback loops
        property real _startWidth: 0
        property real _startHeight: 0
        property real _startX: 0
        property real _startY: 0
        property real _canvasStartX: 0
        property real _canvasStartY: 0
        // Starting config values for ratio-based resize
        property var _startConfigVals: ({})

        MouseArea {
            id: rhArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: root._resizeVisible
            visible: root._resizeVisible
            cursorShape: {
                if ((rh.resizeLeft && rh.resizeTop) || (rh.resizeRight && rh.resizeBottom)) return Qt.SizeFDiagCursor;
                if ((rh.resizeRight && rh.resizeTop) || (rh.resizeLeft && rh.resizeBottom)) return Qt.SizeBDiagCursor;
                if (rh.resizeLeft || rh.resizeRight) return Qt.SizeHorCursor;
                if (rh.resizeTop || rh.resizeBottom) return Qt.SizeVerCursor;
                return Qt.ArrowCursor;
            }
            preventStealing: true

            onPressed: (mouse) => {
                rh._startWidth = root.width;
                rh._startHeight = root.height;
                rh._startX = root.x;
                rh._startY = root.y;
                const mapped = rhArea.mapToItem(root.parent, mouse.x, mouse.y);
                rh._canvasStartX = mapped.x;
                rh._canvasStartY = mapped.y;
                // Capture config values at drag start for ratio calculation
                const axes = root.resizableAxes;
                let vals = {};
                if (axes.uniform) vals.uniform = Number(root._readConfigKey(axes.uniform) ?? 100);
                if (axes.width) vals.width = Number(root._readConfigKey(axes.width) ?? Math.round(root.width / root.scaleFactor));
                if (axes.height) vals.height = Number(root._readConfigKey(axes.height) ?? Math.round(root.height / root.scaleFactor));
                rh._startConfigVals = vals;
                root._isResizing = true;
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const mapped = rhArea.mapToItem(root.parent, mouse.x, mouse.y);
                const dx = mapped.x - rh._canvasStartX;
                const dy = mapped.y - rh._canvasStartY;
                const prefix = root._configPath;
                const axes = root.resizableAxes;
                const isUniform = !!axes.uniform;

                let newW = rh._startWidth;
                let newH = rh._startHeight;
                let newX = rh._startX;
                let newY = rh._startY;

                if (rh.resizeRight) newW = Math.max(root.resizeMinWidth, Math.min(root.resizeMaxWidth, rh._startWidth + dx));
                if (rh.resizeLeft) {
                    const dw = Math.max(root.resizeMinWidth, Math.min(root.resizeMaxWidth, rh._startWidth - dx));
                    newX = rh._startX + (rh._startWidth - dw);
                    newW = dw;
                }
                if (rh.resizeBottom) newH = Math.max(root.resizeMinHeight, Math.min(root.resizeMaxHeight, rh._startHeight + dy));
                if (rh.resizeTop) {
                    const dh = Math.max(root.resizeMinHeight, Math.min(root.resizeMaxHeight, rh._startHeight - dy));
                    newY = rh._startY + (rh._startHeight - dh);
                    newH = dh;
                }

                // Ratio-based: multiply starting config value by size ratio
                if (isUniform) {
                    const startSize = Math.max(rh._startWidth, rh._startHeight);
                    const newSize = Math.max(newW, newH);
                    const ratio = startSize > 0 ? newSize / startSize : 1;
                    Config.setNestedValue(prefix + "." + axes.uniform, Math.round(rh._startConfigVals.uniform * ratio));
                } else {
                    if (axes.width && (rh.resizeLeft || rh.resizeRight)) {
                        const ratio = rh._startWidth > 0 ? newW / rh._startWidth : 1;
                        Config.setNestedValue(prefix + "." + axes.width, Math.round(rh._startConfigVals.width * ratio));
                    }
                    if (axes.height && (rh.resizeTop || rh.resizeBottom)) {
                        const ratio = rh._startHeight > 0 ? newH / rh._startHeight : 1;
                        Config.setNestedValue(prefix + "." + axes.height, Math.round(rh._startConfigVals.height * ratio));
                    }
                }
                if (rh.resizeLeft) {
                    Config.setNestedValue(prefix + ".x", Math.round(newX));
                    root.x = newX;
                }
                if (rh.resizeTop) {
                    Config.setNestedValue(prefix + ".y", Math.round(newY));
                    root.y = newY;
                }
            }

            onReleased: {
                root._isResizing = false;
                if (root._isZonePlacement)
                    root.snapToZone(root.placementStrategy);
                else if (root._isAutoPlacement)
                    root.refreshPlacementIfNeeded();
            }
        }
    }

    // Corner handles (4 corners)
    ResizeHandle {
        anchors { right: parent.left; bottom: parent.top; margins: -1 }
        resizeLeft: true; resizeTop: true
    }
    ResizeHandle {
        anchors { left: parent.right; bottom: parent.top; margins: -1 }
        resizeRight: true; resizeTop: true
    }
    ResizeHandle {
        anchors { right: parent.left; top: parent.bottom; margins: -1 }
        resizeLeft: true; resizeBottom: true
    }
    ResizeHandle {
        anchors { left: parent.right; top: parent.bottom; margins: -1 }
        resizeRight: true; resizeBottom: true
    }
    // Edge handles (4 midpoints)
    ResizeHandle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: -1 }
        resizeTop: true
    }
    ResizeHandle {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: -1 }
        resizeBottom: true
    }
    ResizeHandle {
        anchors { right: parent.left; verticalCenter: parent.verticalCenter; rightMargin: -1 }
        resizeLeft: true
    }
    ResizeHandle {
        anchors { left: parent.right; verticalCenter: parent.verticalCenter; leftMargin: -1 }
        resizeRight: true
    }

    onReleased: {
        if (GlobalStates.screenLocked) return;
        // Suppress _autoPosition Binding for a frame so it doesn't snap back
        root._releaseGuard = true;
        _releaseGuardTimer.restart();

        let newX = root.x;
        let newY = root.y;

        // In edit mode: zone-placed widgets re-snap to nearest zone
        if (GlobalStates.widgetEditMode && root._isZonePlacement) {
            const nearest = root._nearestZone(newX, newY);
            root.snapToZone(nearest);
            if (root.needsColText) _placementDebounce.restart();
            return;
        }

        if (root._snapEnabled) {
            newX = root._snapToGrid(newX);
            newY = root._snapToGrid(newY);
        }
        const finalX = root._snapToPixel(newX);
        const finalY = root._snapToPixel(newY);
        root.x = finalX;
        root.y = finalY;
        const prefix = root._configPath;
        let updates = {};
        updates[prefix + ".x"] = finalX;
        updates[prefix + ".y"] = finalY;
        if (root.placementStrategy !== "free")
            updates[prefix + ".placementStrategy"] = "free";
        Config.setNestedValues(updates);
        if (root.needsColText) _placementDebounce.restart();
    }

    // ── Inline popover for quick controls ─────────────────────
    // Override in subclasses to provide a per-widget quick-edit panel.
    // If null and manifestConfigKeys is non-empty, an auto-generated popover is used.
    property Component editPopoverContent: null
    // Manifest-declared config keys for auto-popover (set via setSource for custom widgets)
    property var manifestConfigKeys: ({})
    readonly property var _manifestKeyList: {
        const keys = root.manifestConfigKeys;
        if (!keys || typeof keys !== "object") return [];
        return Object.keys(keys).map(k => ({ key: k, spec: keys[k] }));
    }
    // Effective popover: custom if provided, otherwise auto-generated from manifest
    readonly property Component _effectivePopover: root.editPopoverContent ?? (root._manifestKeyList.length > 0 ? _autoPopoverComponent : null)

    // Auto-generated popover from manifest configKeys (loaded as separate component)
    property Component _autoPopoverComponent: _manifestKeyList.length > 0 ? _autoPopoverRef : null
    Component {
        id: _autoPopoverRef
        ManifestPopover {
            configEntryName: root.configEntryName
            manifestKeys: root._manifestKeyList
            readConfigKey: (key) => root._readConfigKey(key)
        }
    }

    // ── Resize handles system ─────────────────────────────────
    // Override in subclasses to enable resize in edit mode.
    // Keys: "width", "height" → config key name for that axis
    // Or: "uniform" → single config key for aspect-locked resize
    property var resizableAxes: ({})
    property int resizeMinWidth: 60
    property int resizeMinHeight: 40
    property int resizeMaxWidth: 1200
    property int resizeMaxHeight: 800

    // Read a possibly-nested key from configEntry (e.g. "cookie.size" → configEntry.cookie.size)
    function _readConfigKey(key: string): var {
        return Config.getNestedValue(root._configPath + "." + key, undefined);
    }

    // Override in subclasses with widget-specific default values
    property var defaultConfig: ({})
    // Seed defaults into Config on first load when config entry is empty
    function _seedDefaultsIfNeeded(): void {
        if (!Config.ready) return;
        if (Object.keys(root.defaultConfig).length === 0) return;
        const prefix = root._configPath;
        let updates = {};
        for (const key in root.defaultConfig) {
            if (root._readConfigKey(key) === undefined)
                updates[prefix + "." + key] = root.defaultConfig[key];
        }
        if (Object.keys(updates).length > 0)
            Config.setNestedValues(updates);
    }
    Component.onCompleted: {
        _seedDefaultsIfNeeded();
        Qt.callLater(root.applyPlacementFromConfig);
    }
    function resetToDefaults(): void {
        const prefix = root._configPath;
        const defaults = root.defaultConfig;
        for (const key in defaults) {
            Config.setNestedValue(prefix + "." + key, defaults[key]);
        }
        syncFreePositionFromConfig();
        refreshPlacementIfNeeded();
    }

    property bool needsColText: false
    property color dominantColor: Appearance.colors.colPrimary
    property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    // Wallpaper region brightness (0-1, from image analysis). -1 = not yet analyzed.
    property real regionBrightness: -1
    readonly property bool _hasBrightness: regionBrightness >= 0
    readonly property bool _regionIsLight: _hasBrightness ? regionBrightness > 0.5 : !dominantColorIsDark
    property color colText: {
        // colorMode override: force light/dark text
        if (root.colorMode === "light") return Qt.rgba(1, 1, 1, 0.92);
        if (root.colorMode === "dark") return Qt.rgba(0, 0, 0, 0.87);
        const onBlurredLock = (GlobalStates.screenLocked && (Config.options?.lock?.blur?.enable ?? false))
        if (onBlurredLock) return Appearance.colors.colOnLayer0;
        // Use wallpaper brightness for contrast-aware text color
        const accent = Appearance.colors.colPrimary
        if (root._regionIsLight) {
            // Light wallpaper region → dark text
            const dark = Qt.rgba(0, 0, 0, 0.87)
            return ColorUtils.mix(dark, accent, 0.12)
        } else {
            // Dark wallpaper region → light text
            const light = Qt.rgba(1, 1, 1, 0.92)
            return ColorUtils.mix(light, accent, 0.15)
        }
    }

    property bool wallpaperIsVideo: {
        const p = (Config.options?.background?.wallpaperPath ?? "").toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
    }
    property string wallpaperPath: wallpaperIsVideo ? (Config.options?.background?.thumbnailPath ?? "") : (Config.options?.background?.wallpaperPath ?? "")
    
    onWallpaperPathChanged: {
        root.regionBrightness = -1
        if (root.wallpaperPath.length > 0)
            _placementDebounce.restart()
    }
    onPlacementStrategyChanged: Qt.callLater(root.applyPlacementFromConfig)
    // Re-snap zone positions when screen size changes
    onScaledScreenWidthChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
    onScaledScreenHeightChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
    onWidthChanged: _geometryPlacementDebounce.restart()
    onHeightChanged: _geometryPlacementDebounce.restart()
    Timer {
        id: _zoneResnapDebounce
        interval: 100; repeat: false
        onTriggered: root.snapToZone(root.placementStrategy)
    }
    Timer {
        id: _geometryPlacementDebounce
        interval: 120; repeat: false
        onTriggered: {
            if (!Config.ready || root.containsPress || root._isResizing)
                return;
            if (root._isZonePlacement)
                root.snapToZone(root.placementStrategy);
            else if (root._isAutoPlacement)
                root.refreshPlacementIfNeeded();
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            root._seedDefaultsIfNeeded();
            root.applyPlacementFromConfig();
        }
    }
    Timer {
        id: _placementDebounce
        interval: 500
        repeat: false
        onTriggered: root.refreshPlacementIfNeeded()
    }
    function refreshPlacementIfNeeded() {
        if (!Config.ready) return;
        if (!root.wallpaperPath || root.wallpaperPath.length === 0) return;
        // For auto-placement (leastBusy/mostBusy): full analysis (position + color)
        if (root._isAutoPlacement) {
            leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
            leastBusyRegionProc.running = false;
            leastBusyRegionProc.running = true;
            return;
        }
        // For free/zone widgets that need color: position-aware color-only analysis
        if (root.needsColText) {
            colorOnlyProc.running = false;
            colorOnlyProc.running = true;
        }
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        property int contentWidth: Math.max(1, Math.round(root.width / Math.max(root.wallpaperScale, 0.001)))
        property int contentHeight: Math.max(1, Math.round(root.height / Math.max(root.wallpaperScale, 0.001)))
        property int horizontalPadding: root._zoneMargin
        property int verticalPadding: root._zoneMargin
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh") // Comments to force the formatter to break lines
            , "--screen-width", Math.round(root.scaledScreenWidth) //
            , "--screen-height", Math.round(root.scaledScreenHeight) //
            , "--width", contentWidth //
            , "--height", contentHeight //
            , "--horizontal-padding", horizontalPadding //
            , "--vertical-padding", verticalPadding //
            , wallpaperPath //
            , ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                if (output.length === 0) return;
                try {
                    const parsedContent = JSON.parse(output);
                    root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                    if (parsedContent.brightness !== undefined)
                        root.regionBrightness = parsedContent.brightness / 255.0;
                    if (!root._isAutoPlacement) return;
                    root._autoPlaceX = root._clampX(parsedContent.center_x * root.wallpaperScale - root.width / 2);
                    root._autoPlaceY = root._clampY(parsedContent.center_y * root.wallpaperScale - root.height / 2);
                } catch (e) {
                    console.warn("[Widgets] Failed to parse placement output:", e);
                }
            }
        }
    }
    // Color-only analysis for free/zone widgets at their actual position
    Process {
        id: colorOnlyProc
        property int posX: Math.max(0, Math.round(root.x / Math.max(root.wallpaperScale, 0.001)))
        property int posY: Math.max(0, Math.round(root.y / Math.max(root.wallpaperScale, 0.001)))
        property int contentWidth: Math.max(1, Math.round(root.width / Math.max(root.wallpaperScale, 0.001)))
        property int contentHeight: Math.max(1, Math.round(root.height / Math.max(root.wallpaperScale, 0.001)))
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh")
            , "--color-only"
            , "--position-x", posX
            , "--position-y", posY
            , "--screen-width", Math.round(root.scaledScreenWidth)
            , "--screen-height", Math.round(root.scaledScreenHeight)
            , "--width", contentWidth
            , "--height", contentHeight
            , root.wallpaperPath
        ]
        stdout: StdioCollector {
            id: colorOnlyOutputCollector
            onStreamFinished: {
                const output = colorOnlyOutputCollector.text;
                if (output.length === 0) return;
                try {
                    const parsedContent = JSON.parse(output);
                    root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                    if (parsedContent.brightness !== undefined)
                        root.regionBrightness = parsedContent.brightness / 255.0;
                } catch (e) {
                    console.warn("[Widgets] Failed to parse color-only output:", e);
                }
            }
        }
    }
}
