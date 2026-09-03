pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    property string outputName: ""
    readonly property string _configPath: "background.widgets." + root.configEntryName

    function _setOutputValues(values): void {
        if (!values || typeof values !== "object")
            return
        if (root.outputName.length > 0) {
            DesktopWidgetLayout.setValues(root.outputName, root.configEntryName, values)
            return
        }
        const updates = ({})
        for (const key of Object.keys(values))
            updates[root._configPath + "." + key] = values[key]
        Config.setNestedValues(updates)
    }

    function _setOutputValue(key: string, value): void {
        const values = ({})
        values[key] = value
        root._setOutputValues(values)
    }
    property bool visibleWhenLocked: false
    property int widgetIndex: 0 // stable base stacking order
    readonly property string editInstanceKey: root.outputName + "::" + root.configEntryName
    readonly property bool editSelected: GlobalStates.widgetEditMode
        && GlobalStates.selectedDesktopWidget === root.editInstanceKey
    readonly property int desktopPersistentZ: {
        Config.revision
        const order = Config.getNestedValue("background.widgets.layerOrder", []) ?? []
        const index = order.indexOf(root.editInstanceKey)
        return index >= 0 ? 1000 + index : root.widgetIndex
    }
    // Selection temporarily rises above every widget while editing, but the
    // persisted order remains active both inside and outside edit mode.
    readonly property int desktopStackZ: root.editSelected
        ? 10000 : root.desktopPersistentZ
    // Diagnostic-only control, supplied by Background.qml when the supervised
    // shell is loaded with INIR_REGION_DEBUG=1.
    property bool debugQuickControlsOpen: false
    property bool debugLayoutProbeActive: false
    property int debugLayoutProbeX: 0
    property int debugLayoutProbeY: 0
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
    // scaleFactor is persistent geometry only. Selection/press feedback must
    // never modify this value: widgets multiply their layout dimensions and
    // font sizes by it, so the old 1.05 press bump physically moved/resized the
    // widget as soon as it was selected.
    property bool _isResizing: false
    property var _resizePreviewValues: ({})
    readonly property real scaleFactor: _baseScale
    readonly property real widgetOpacity: {
        const v = Number(root._readConfigKey("widgetOpacity") ?? 100);
        return Math.max(0, Math.min(1, Number.isFinite(v) ? v / 100 : 1.0));
    }
    // One dim contract for every desktop widget. Stored config remains
    // 0 = no dim, 100 = strongest dim. The shared root attenuation replaces
    // per-widget color/opacity implementations that disagreed or did nothing.
    readonly property real dimAmount: {
        const v = Number(root._readConfigKey("dim") ?? 0);
        return Math.max(0, Math.min(1, Number.isFinite(v) ? v / 100 : 0));
    }
    readonly property real dimOpacity: 1.0 - root.dimAmount * 0.6
    readonly property bool showBackground: root._readConfigKey("showBackground") ?? true
    readonly property bool useBlur: root._readConfigKey("useBlur") ?? false
    readonly property bool _widgetIslandStyle: !Appearance.zzzEverywhere && !Appearance.cookieEverywhere
        && !Appearance.angelEverywhere && !Appearance.auroraEverywhere && !Appearance.inirEverywhere
        && (Config.options?.background?.widgets?.style ?? "panel") === "island"
    readonly property bool blurAvailable: Appearance.effectsEnabled
        && (Appearance.angelEverywhere
            || (Appearance.auroraEverywhere && !Appearance.inirEverywhere)
            || (root._widgetIslandStyle
                && (Config.options?.appearance?.island?.glass ?? true)
                && (Config.options?.appearance?.island?.opacity ?? 1) < 0.999))
    readonly property bool effectiveBlur: root.showBackground && root.useBlur && root.blurAvailable
    readonly property bool showBorder: root._readConfigKey("showBorder") ?? true
    // Granular card controls — override booleans when present
    readonly property real backgroundOpacity: {
        if (!showBackground) return 0;
        const v = root._readConfigKey("backgroundOpacity");
        return (v !== undefined && v !== null) ? Math.max(0, Math.min(1, Number(v))) : (showBackground ? 0.06 : 0);
    }
    readonly property real borderWidth: {
        if (!showBorder) return 0;
        const v = root._readConfigKey("borderWidth");
        return (v !== undefined && v !== null) ? Math.max(0, Math.min(8, Number(v))) : (showBorder ? 1 : 0);
    }
    readonly property real borderOpacity: {
        const v = root._readConfigKey("borderOpacity");
        return (v !== undefined && v !== null) ? Math.max(0, Math.min(1, Number(v))) : 0.08;
    }
    readonly property real cornerRadiusOverride: root._readConfigKey("cornerRadius") ?? -1
    readonly property string colorMode: root._readConfigKey("colorMode") ?? "auto"
    // A direct binding creates a resize/config revision cycle.
    property string placementStrategy: "free"

    function _syncPlacementStrategy(): void {
        const next = root._readConfigKey("placementStrategy") ?? "free";
        if (root.placementStrategy !== next)
            root.placementStrategy = next;
    }

    Connections {
        target: Config
        function onRevisionChanged(): void {
            root._syncPlacementStrategy();
        }
    }
    on_IsResizingChanged: root._syncPlacementStrategy()

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
    // Free placement spans the complete output. Zone placement separately
    // respects the live bar/dock edge so an automatic snap stays visible after
    // edit mode restores those movable surfaces.
    readonly property var _workArea: ShellLayoutController.desktopWorkArea(
        root.outputName, root.scaledScreenWidth, root.scaledScreenHeight)
    readonly property var _zoneWorkArea: ShellLayoutController.desktopZoneWorkArea(
        root.outputName, root.scaledScreenWidth, root.scaledScreenHeight)
    readonly property real _safeLeft: root._workArea.left ?? 0
    readonly property real _safeTop: root._workArea.top ?? 0
    readonly property real _safeRight: root._workArea.right ?? root.scaledScreenWidth
    readonly property real _safeBottom: root._workArea.bottom ?? root.scaledScreenHeight
    readonly property real _safeWidth: root._workArea.width ?? 0
    readonly property real _safeHeight: root._workArea.height ?? 0
    readonly property real _zoneSafeLeft: root._zoneWorkArea.left ?? root._safeLeft
    readonly property real _zoneSafeTop: root._zoneWorkArea.top ?? root._safeTop
    readonly property real _zoneSafeRight: root._zoneWorkArea.right ?? root._safeRight
    readonly property real _zoneSafeBottom: root._zoneWorkArea.bottom ?? root._safeBottom
    readonly property int _zoneMargin: 16
    readonly property int _analysisPadding: 48

    function _getZonePosition(zone: string): point {
        const left = root._zoneSafeLeft + root._zoneMargin
        const top = root._zoneSafeTop + root._zoneMargin
        const right = Math.max(left,
            root._zoneSafeRight - root._zoneMargin - root.width)
        const bottom = Math.max(top,
            root._zoneSafeBottom - root._zoneMargin - root.height)
        const cx = left + (right - left) / 2
        const cy = top + (bottom - top) / 2
        switch (zone) {
            case "topLeft":      return Qt.point(left, top)
            case "topCenter":    return Qt.point(cx, top)
            case "topRight":     return Qt.point(right, top)
            case "centerLeft":   return Qt.point(left, cy)
            case "center":       return Qt.point(cx, cy)
            case "centerRight":  return Qt.point(right, cy)
            case "bottomLeft":   return Qt.point(left, bottom)
            case "bottomCenter": return Qt.point(cx, bottom)
            case "bottomRight":  return Qt.point(right, bottom)
            default:               return Qt.point(cx, cy)
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
            root._setOutputValues({
                placementStrategy: "free",
                x: root._snapToPixel(root.x),
                y: root._snapToPixel(root.y)
            })
            return;
        }
        root.snapToZone(root._nearestZone(root.x, root.y));
    }

    function snapToZone(zone: string): void {
        const pos = root._getZonePosition(zone);
        const finalX = root._snapToPixel(pos.x);
        const finalY = root._snapToPixel(pos.y);
        const updates = ({})
        if (root.placementStrategy !== zone)
            updates.placementStrategy = zone
        if (Number(root._readConfigKey("x")) !== finalX)
            updates.x = finalX
        if (Number(root._readConfigKey("y")) !== finalY)
            updates.y = finalY
        if (Object.keys(updates).length > 0)
            root._setOutputValues(updates)
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
        const maxX = Math.max(root._safeLeft, root._safeRight - root.width)
        return root._snapToPixel(Math.max(root._safeLeft,
            Math.min(Number(value) || 0, maxX)))
    }

    function _clampY(value: real): real {
        const maxY = Math.max(root._safeTop, root._safeBottom - root.height)
        return root._snapToPixel(Math.max(root._safeTop,
            Math.min(Number(value) || 0, maxY)))
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

    // Free-mode overflow re-clamp is imperative (in _geometryPlacementDebounce)
    // — a Binding that reads root.x while writing it loops (Qt warning at :245).
    Behavior on x {
        enabled: Appearance.animationsEnabled && root._autoPosition
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
    Behavior on y {
        enabled: Appearance.animationsEnabled && root._autoPosition
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }

    // ══════════════════════════════════════════════════════════════════════
    // CHAOS MODE — physics responses to mascot impacts (MascotChaos bus)
    // ══════════════════════════════════════════════════════════════════════
    // Impacts animate a visual transform only; the position machinery above
    // is never touched mid-flight. On landing the displacement either
    // persists (one config write, free-mode only) or springs back home.
    property real _chaosDX: 0
    property real _chaosDY: 0
    property real _chaosAngle: 0
    property real _flingX: 0
    property real _flingY: 0
    property real _flingRise: 120
    property real _flingSpin: 0
    property bool _flingPersist: false
    property bool _flingWreck: false

    transform: [
        Rotation { origin.x: root.width / 2; origin.y: root.height / 2; angle: root._chaosAngle },
        Translate { x: root._chaosDX; y: root._chaosDY }
    ]

    // Live geometry report so the romp knows where to aim (chaos-gated)
    readonly property bool _chaosWatch: MascotChaos.enabled && root.visible
    Timer {
        id: _chaosReportDebounce
        interval: 250
        onTriggered: MascotChaos.report(root.configEntryName, root.x, root.y, root.width, root.height)
        // widgets born while chaos is already on still need a first report
        Component.onCompleted: if (root._chaosWatch) restart()
    }
    on_ChaosWatchChanged: {
        if (_chaosWatch) _chaosReportDebounce.restart()
        else MascotChaos.unreport(root.configEntryName)
    }
    Connections {
        target: root
        enabled: root._chaosWatch
        function onXChanged() { _chaosReportDebounce.restart() }
        function onYChanged() { _chaosReportDebounce.restart() }
        function onWidthChanged() { _chaosReportDebounce.restart() }
        function onHeightChanged() { _chaosReportDebounce.restart() }
    }

    SequentialAnimation {
        id: _chaosFling
        ParallelAnimation {
            NumberAnimation { target: root; property: "_chaosDX"; to: root._flingX; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "_chaosAngle"; to: root._flingSpin; duration: 700; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: root; property: "_chaosDY"; to: -root._flingRise; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "_chaosDY"; to: root._flingY; duration: 440; easing.type: Easing.InQuad }
                NumberAnimation { target: root; property: "_chaosDY"; to: root._flingY - 14; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "_chaosDY"; to: root._flingY; duration: 140; easing.type: Easing.InQuad }
            }
        }
        onStopped: root._chaosSettle()
    }
    ParallelAnimation {
        id: _chaosReturn
        NumberAnimation { target: root; property: "_chaosDX"; to: 0; duration: 550; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "_chaosDY"; to: 0; duration: 550; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "_chaosAngle"; to: 0; duration: 550; easing.type: Easing.OutBack }
    }
    NumberAnimation { id: _chaosStraighten; target: root; property: "_chaosAngle"; to: 0; duration: 300; easing.type: Easing.OutQuad }

    function _chaosSettle(): void {
        if (root._flingWreck) {
            // stays face-down on the floor until tidy() picks it back up
            return
        }
        if (root._flingPersist) {
            const nx = root._clampX(root.x + root._chaosDX)
            const ny = root._clampY(root.y + root._chaosDY)
            root._chaosDX = 0
            root._chaosDY = 0
            root._setOutputValues({ x: Math.round(nx), y: Math.round(ny) })
            root.syncFreePositionFromConfig()
            _chaosStraighten.restart()
        } else {
            _chaosReturn.restart()
        }
    }

    Connections {
        target: MascotChaos
        enabled: MascotChaos.enabled
        function onImpact(widgetKey, vx, vy, mode) {
            if (widgetKey !== root.configEntryName) return
            if (GlobalStates.screenLocked || !root.visible) return
            _chaosFling.stop()
            _chaosReturn.stop()
            MascotChaos.rememberOriginal(root.configEntryName, root.x, root.y)
            root._flingWreck = mode === "wreck" || mode === "vanish"
            root._flingPersist = mode === "persist" && root.placementStrategy === "free" && !root.locked
            root._flingX = vx
            if (mode === "vanish") {
                // stolen: carried clean off the screen edge until tidy
                root._flingX = vx >= 0
                    ? root.scaledScreenWidth - root.x + root.width
                    : -(root.x + root.width * 2)
                root._flingY = 0
                root._flingRise = 30
                root._flingSpin = 0
            } else if (root._flingWreck) {
                // knocked out: drop to the floor and lie there, badly
                root._flingY = Math.max(0, root.scaledScreenHeight - root.y - root.height - 8)
                root._flingRise = 40 + Math.random() * 40
                root._flingSpin = (vx >= 0 ? 1 : -1) * (60 + Math.random() * 30)
            } else {
                root._flingY = root._flingPersist ? vy : 0
                root._flingRise = 90 + Math.random() * 70
                root._flingSpin = (vx >= 0 ? 1 : -1) * (8 + Math.random() * 14)
            }
            _chaosFling.restart()
        }
        function onTidied() {
            _chaosFling.stop()
            _chaosReturn.stop()
            root._flingWreck = false
            // ease everything back upright instead of teleporting
            _chaosReturn.restart()
        }
    }

    visible: opacity > 0
    opacity: ((GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1)
        * root.widgetOpacity * root.dimOpacity
    enabled: !GlobalStates.screenLocked
    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    // ══════════════════════════════════════════════════════════════════════
    // POWER MANAGEMENT - Inherited by all widgets
    // ══════════════════════════════════════════════════════════════════════
    // Widgets should check these properties before running expensive operations
    // (blur layers, animations, Cava subscriptions, frequent timers)

    // Fullscreen and window-presence triggers are scoped to this widget's output.
    // Manual GameMode remains intentionally global.
    readonly property bool powerActive: WidgetPowerManager.widgetsActiveForOutput(root.outputName)
    readonly property bool powerReduced: WidgetPowerManager.reducedModeForOutput(root.outputName)

    // Effective animation state: animations enabled AND power active
    readonly property bool animationsActive: Appearance.animationsEnabled && root.powerActive

    // Visual feedback when paused - desaturation + slight dim
    // Config option to disable visual effect if user only wants GPU savings
    readonly property bool _showPausedEffect: Config.options?.background?.widgets?.powerSaving?.showPausedEffect ?? true
    readonly property real _pausedSaturation: root.powerActive ? 0 : -0.7  // -0.7 = mostly grayscale
    readonly property real _pausedBrightness: root.powerActive ? 0 : -0.15 // slight dim
    
    layer.enabled: !root.powerActive && root._showPausedEffect && root.visible
    layer.effect: MultiEffect {
        saturation: root._pausedSaturation
        brightness: root._pausedBrightness
        
        Behavior on saturation {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        Behavior on brightness {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
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
            // Local wallpaper sampling is explicitly opt-in. Zone placement
            // itself remains independent from color adaptation.
            if (root.positionColorAdaptationEnabled && root.needsColText)
                _placementDebounce.restart();
        } else {
            syncFreePositionFromConfig();
            refreshPlacementIfNeeded();
        }
    }

    readonly property int _editGridSize: Config.getNestedValue("background.widgets.editGrid.size", 32)
    readonly property bool _snapEnabled: GlobalStates.widgetEditMode && (Config.getNestedValue("background.widgets.editGrid.snap", true))

    readonly property int _editScreenMargin: 8
    readonly property int _editToolbarGap: 12
    readonly property int _editPopoverGap: 6
    readonly property real quickControlsAvailableWidth: Math.max(0,
        root._safeRight - root._safeLeft - 2 * root._editScreenMargin)
    readonly property real quickControlsAvailableHeight: Math.max(0,
        root._safeBottom - root._safeTop - editToolbar.height
            - root._editPopoverGap)
    readonly property bool quickControlsDense:
        root.quickControlsAvailableHeight < 760
    readonly property bool quickControlsWide: root.quickControlsDense
        && root.quickControlsAvailableWidth >= 480
    function _resolveEditControlsGeometry(widgetX: real, widgetY: real, popoverVisible: bool): var {
        const leftBound = root._safeLeft + root._editScreenMargin
        const topBound = root._safeTop + root._editScreenMargin
        const rightBound = root._safeRight - root._editScreenMargin
        const bottomBound = root._safeBottom - root._editScreenMargin
        const safeX = root._clampX(widgetX)
        const safeY = root._clampY(widgetY)
        const popoverHeight = popoverVisible ? editPopoverPanel.height : 0
        const stackHeight = editToolbar.height
            + (popoverVisible ? popoverHeight + root._editPopoverGap : 0)
        const spaceAbove = Math.max(0, safeY - topBound - root._editToolbarGap)
        const spaceBelow = Math.max(0,
            bottomBound - safeY - root.height - root._editToolbarGap)
        const fitsAbove = spaceAbove >= stackHeight
        const fitsBelow = spaceBelow >= stackHeight
        const spaceLeft = Math.max(0,
            safeX - leftBound - root._editToolbarGap)
        const spaceRight = Math.max(0,
            rightBound - safeX - root.width - root._editToolbarGap)
        const fitsLeft = popoverVisible
            && spaceLeft >= editPopoverPanel.width
        const fitsRight = popoverVisible
            && spaceRight >= editPopoverPanel.width
        const useSide = !fitsAbove && !fitsBelow && (fitsLeft || fitsRight)
        const side = useSide
            ? (fitsLeft && fitsRight
                ? (spaceRight >= spaceLeft ? "right" : "left")
                : fitsRight ? "right" : "left")
            : (fitsAbove ? "above" : fitsBelow ? "below"
                : spaceBelow > spaceAbove ? "below" : "above")
        const below = side === "below"
        const toolbarMaxX = Math.max(leftBound, rightBound - editToolbar.width)
        const toolbarX = Math.max(leftBound, Math.min(toolbarMaxX,
            safeX + (root.width - editToolbar.width) / 2))
        let toolbarY
        let popoverX
        let popoverY
        if (useSide) {
            const toolbarAbove = safeY - root._editToolbarGap
                - editToolbar.height >= topBound
            toolbarY = toolbarAbove
                ? safeY - root._editToolbarGap - editToolbar.height
                : Math.min(bottomBound - editToolbar.height,
                    safeY + root.height + root._editToolbarGap)
            popoverX = side === "left"
                ? safeX - root._editToolbarGap - editPopoverPanel.width
                : safeX + root.width + root._editToolbarGap
            popoverY = Math.max(topBound, Math.min(
                bottomBound - editPopoverPanel.height,
                safeY + (root.height - editPopoverPanel.height) / 2))
        } else {
            const preferredStackY = below
                ? safeY + root.height + root._editToolbarGap
                : safeY - root._editToolbarGap - stackHeight
            const stackMaxY = Math.max(topBound, bottomBound - stackHeight)
            const stackY = Math.max(topBound,
                Math.min(stackMaxY, preferredStackY))
            toolbarY = below
                ? stackY
                : stackY + (popoverVisible
                    ? popoverHeight + root._editPopoverGap : 0)
            const popoverMaxX = Math.max(leftBound,
                rightBound - editPopoverPanel.width)
            popoverX = Math.max(leftBound, Math.min(popoverMaxX,
                toolbarX + (editToolbar.width - editPopoverPanel.width) / 2))
            popoverY = below
                ? toolbarY + editToolbar.height + root._editPopoverGap
                : stackY
        }
        const toolbarInBounds = toolbarX >= leftBound && toolbarY >= topBound
            && toolbarX + editToolbar.width <= rightBound
            && toolbarY + editToolbar.height <= bottomBound
        const popoverInBounds = !popoverVisible || (popoverX >= leftBound && popoverY >= topBound
            && popoverX + editPopoverPanel.width <= rightBound
            && popoverY + editPopoverPanel.height <= bottomBound)
        return {
            widgetX: safeX,
            widgetY: safeY,
            below: below,
            side: side,
            toolbarX: toolbarX,
            toolbarY: toolbarY,
            popoverX: popoverX,
            popoverY: popoverY,
            inBounds: toolbarInBounds && popoverInBounds
        };
    }

    readonly property var _editControlsGeometry: root._resolveEditControlsGeometry(
        root.x, root.y, editPopoverPanel.open)
    readonly property bool _editControlsBelow: root._editControlsGeometry.below

    // Loader containment masks consume this exact union instead of a huge
    // per-widget rectangle. Overlapping widgets therefore follow visual z
    // order, while the selected widget still owns its toolbar and popover.
    readonly property real editInputX: {
        if (!GlobalStates.widgetEditMode || !root._editControlsShown)
            return -8
        const toolbarX = root._editControlsGeometry.toolbarX - root.x
        const popoverX = root._editControlsGeometry.popoverX - root.x
        return Math.min(-8, toolbarX - 8,
            editPopoverPanel.open ? popoverX - 8 : 0)
    }
    readonly property real editInputY: {
        if (!GlobalStates.widgetEditMode || !root._editControlsShown)
            return -8
        const toolbarY = root._editControlsGeometry.toolbarY - root.y
        const popoverY = root._editControlsGeometry.popoverY - root.y
        return Math.min(-8, toolbarY - 8,
            editPopoverPanel.open ? popoverY - 8 : 0)
    }
    readonly property real editInputWidth: {
        if (!GlobalStates.widgetEditMode || !root._editControlsShown)
            return root.width + 16
        const toolbarRight = root._editControlsGeometry.toolbarX - root.x
            + editToolbar.width + 8
        const popoverRight = root._editControlsGeometry.popoverX - root.x
            + editPopoverPanel.width + 8
        return Math.max(root.width + 8, toolbarRight,
            editPopoverPanel.open ? popoverRight : 0) - root.editInputX
    }
    readonly property real editInputHeight: {
        if (!GlobalStates.widgetEditMode || !root._editControlsShown)
            return root.height + 16
        const toolbarBottom = root._editControlsGeometry.toolbarY - root.y
            + editToolbar.height + 8
        const popoverBottom = root._editControlsGeometry.popoverY - root.y
            + editPopoverPanel.height + 8
        return Math.max(root.height + 8, toolbarBottom,
            editPopoverPanel.open ? popoverBottom : 0) - root.editInputY
    }

    readonly property int overlappingLayerCount: {
        Config.revision
        root.x
        root.y
        root.width
        root.height
        const canvas = root.parent?.parent ?? null
        if (!canvas || typeof canvas.overlappingDesktopWidgetCount !== "function")
            return 1
        return canvas.overlappingDesktopWidgetCount(root.editInstanceKey)
    }

    function _cycleOverlappingWidget(): void {
        const canvas = root.parent?.parent ?? null
        if (!canvas || typeof canvas.cycleOverlappingDesktopWidget !== "function")
            return
        canvas.cycleOverlappingDesktopWidget(root.editInstanceKey)
    }

    function _bringToFront(): void {
        const canvas = root.parent?.parent ?? null
        if (!canvas || typeof canvas.promoteDesktopWidget !== "function")
            return
        canvas.promoteDesktopWidget(root.editInstanceKey)
    }

    readonly property string editControlsGeometryReport: {
        const requestedX = root.debugLayoutProbeActive ? root.debugLayoutProbeX : root.x;
        const requestedY = root.debugLayoutProbeActive ? root.debugLayoutProbeY : root.y;
        const geometry = root._resolveEditControlsGeometry(
            requestedX, requestedY, editPopoverPanel.open);
        return JSON.stringify({
            widget: root.configEntryName,
            screen: { width: root.scaledScreenWidth, height: root.scaledScreenHeight },
            probe: root.debugLayoutProbeActive,
            requested: { x: Math.round(requestedX), y: Math.round(requestedY) },
            position: { x: Math.round(geometry.widgetX), y: Math.round(geometry.widgetY) },
            below: geometry.below,
            side: geometry.side,
            toolbar: { x: Math.round(geometry.toolbarX), y: Math.round(geometry.toolbarY), width: Math.round(editToolbar.width), height: Math.round(editToolbar.height) },
            popover: { visible: editPopoverPanel.open, x: Math.round(geometry.popoverX), y: Math.round(geometry.popoverY), width: Math.round(editPopoverPanel.width), height: Math.round(editPopoverPanel.height) },
            inBounds: geometry.inBounds
        });
    }

    onDebugQuickControlsOpenChanged: {
        if (Quickshell.env("INIR_REGION_DEBUG") === "1")
            editPopoverPanel.open = root.debugQuickControlsOpen;
    }
    onLockedChanged: if (root.locked) editPopoverPanel.open = false
    onEditSelectedChanged: {
        _editDisengageTimer.stop()
        if (root.editSelected) {
            root._editControlsShown = true
        } else {
            editPopoverPanel.open = false
            // Selection is explicit. Releasing the previous toolbar and its
            // containment mask immediately lets the newly selected layer own
            // the next pointer event instead of blocking it for 350 ms.
            root._editControlsShown = false
        }
    }

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void {
            if (!GlobalStates.widgetEditMode)
                editPopoverPanel.open = false
            _geometryPlacementDebounce.restart()
        }
        function onDesktopWidgetQuickControlsChanged(): void {
            if (GlobalStates.desktopWidgetQuickControls !== root.editInstanceKey
                    || root.locked || root._effectivePopover === null)
                return
            _editDisengageTimer.stop()
            root._editControlsShown = true
            editPopoverPanel.open = true
        }
    }

    function _snapToGrid(value: real, origin: real): real {
        return origin + Math.round((value - origin) / _editGridSize) * _editGridSize
    }

    // Grid snapping uses the panel-aware work area. The grid can therefore
    // magnetize a widget to the live bar/dock boundary while free placement
    // remains available across the full desktop when snapping is disabled.
    readonly property real _editMagnetThreshold: Math.max(6,
        Math.min(18, root._editGridSize * 0.4))

    function _snapEditEdge(value: real, start: real, end: real): real {
        const minValue = Number(start) || 0
        const maxValue = Math.max(minValue, Number(end) || 0)
        const raw = Math.max(minValue, Math.min(maxValue, Number(value) || 0))
        const threshold = root._editMagnetThreshold
        if (Math.abs(raw - minValue) <= threshold)
            return root._snapToPixel(minValue)
        if (Math.abs(raw - maxValue) <= threshold)
            return root._snapToPixel(maxValue)
        const center = minValue + (maxValue - minValue) / 2
        if (Math.abs(raw - center) <= threshold)
            return root._snapToPixel(center)
        return root._snapToPixel(Math.max(minValue,
            Math.min(maxValue, root._snapToGrid(raw, minValue))))
    }

    function _snapEditAxis(value: real, extent: real,
            start: real, end: real): real {
        const minValue = Number(start) || 0
        const maxValue = Math.max(minValue, (Number(end) || 0) - extent)
        const raw = Math.max(minValue, Math.min(maxValue, Number(value) || 0))
        const threshold = root._editMagnetThreshold

        // Safe-area edges are stronger targets than the regular lattice. They
        // correspond to bar/dock boundaries when those surfaces occupy an edge.
        if (Math.abs(raw - minValue) <= threshold)
            return root._snapToPixel(minValue)
        if (Math.abs(raw - maxValue) <= threshold)
            return root._snapToPixel(maxValue)

        // A center rail makes balanced layouts deterministic even when the
        // current work-area width is not divisible by the configured grid size.
        const center = minValue + Math.max(0, maxValue - minValue) / 2
        if (Math.abs(raw - center) <= threshold)
            return root._snapToPixel(center)

        return root._snapToPixel(Math.max(minValue,
            Math.min(maxValue, root._snapToGrid(raw, minValue))))
    }

    function _snapEditX(value: real): real {
        return root._snapEditAxis(value, root.width,
            root._zoneSafeLeft, root._zoneSafeRight)
    }

    function _snapEditY(value: real): real {
        return root._snapEditAxis(value, root.height,
            root._zoneSafeTop, root._zoneSafeBottom)
    }

    // The ghost is the exact position that will be committed on release.
    property real _snapPreviewX: _snapEnabled ? root._snapEditX(root.x) : root.x
    property real _snapPreviewY: _snapEnabled ? root._snapEditY(root.y) : root.y
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

    // ── Edit engagement ──────────────────────────────────────
    // Heavy controls belong to the explicit selection, never to incidental
    // pointer travel. Hover only previews the outline/name; pressing promotes
    // that widget to the active editing layer.
    readonly property bool _editEngaged: GlobalStates.widgetEditMode
        && (root.editSelected || toolbarEditHover.hovered
            || root.containsPress || root.isDragging || root._isResizing
            || root._releaseGuard || editPopoverPanel.open
            || root.debugQuickControlsOpen)
    property bool _editControlsShown: false
    on_EditEngagedChanged: {
        if (root._editEngaged) {
            _editDisengageTimer.stop()
            root._editControlsShown = true
        } else {
            _editDisengageTimer.restart()
        }
    }
    onVisibleChanged: if (!root.visible) root._editControlsShown = false

    Timer {
        id: _editDisengageTimer
        interval: 350
        onTriggered: root._editControlsShown = false
    }

    HoverHandler {
        id: widgetEditHover
        enabled: GlobalStates.widgetEditMode
    }

    onPressed: {
        if (GlobalStates.widgetEditMode)
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
    }

    // Locked widgets intentionally disable AbstractWidget's drag MouseArea.
    // Keep selection available through a separate tap handler so locking a
    // widget never makes it unreachable from the desktop editor.
    TapHandler {
        enabled: GlobalStates.widgetEditMode && root.locked
        acceptedButtons: Qt.LeftButton
        onTapped: GlobalStates.selectDesktopWidget(root.editInstanceKey)
    }

    TapHandler {
        enabled: GlobalStates.widgetEditMode
        acceptedButtons: Qt.RightButton
        onTapped: {
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
            widgetEditContextMenu.requestOpen()
        }
    }

    Item {
        id: widgetEditContextAnchor
        width: 1
        height: 1
        x: Math.max(0, Math.min(root.width,
            root.width - root._editScreenMargin))
        y: Math.max(0, Math.min(root.height,
            root.height / 2))
    }

    ContextMenu {
        id: widgetEditContextMenu
        anchorItem: widgetEditContextAnchor
        popupAbove: root.y > root.scaledScreenHeight / 2
        // The desktop editor runs on Niri layer surfaces. A focus-loss backdrop
        // can sit above the popup and consume its own clicks, so use the same
        // hover-close contract as the desktop context menu.
        closeOnFocusLost: false
        closeOnHoverLost: true
        closeOnHoverLostAfterEntered: true
        closeOnHoverLostDelay: 700
        model: [
            {
                text: root.locked ? Translation.tr("Unlock position")
                    : Translation.tr("Lock position"),
                iconName: root.locked ? "lock_open" : "lock",
                monochromeIcon: true,
                action: () => root._setOutputValue("locked", !root.locked)
            },
            {
                text: Translation.tr("Bring to front"),
                iconName: "layers",
                monochromeIcon: true,
                action: () => root._bringToFront()
            },
            ...((root._effectivePopover !== null && !root.locked) ? [{
                text: Translation.tr("Quick controls"),
                iconName: "tune",
                monochromeIcon: true,
                action: () => GlobalStates.requestDesktopWidgetQuickControls(
                    root.editInstanceKey)
            }] : []),
            ...(!root.locked ? [
                { type: "separator" },
                {
                    text: Translation.tr("Reset to defaults"),
                    iconName: "restart_alt",
                    monochromeIcon: true,
                    action: () => root.resetToDefaults()
                }
            ] : [])
        ]
    }

    // ── Edit mode toolbar (proper Material action bar) ─────────
    // Toolbar is in screen-pixel space (no Item.scale on widget)
    Item {
        id: editToolbar
        z: 200
        visible: opacity > 0
        opacity: GlobalStates.widgetEditMode && root._editControlsShown ? 1 : 0

        HoverHandler {
            id: toolbarEditHover
            enabled: GlobalStates.widgetEditMode
        }
        x: root._editControlsGeometry.toolbarX - root.x
        y: root._editControlsGeometry.toolbarY - root.y
        width: toolbarRow.implicitWidth + 16
        height: 40

        Behavior on x {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }

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

        Toolbar {
            anchors.fill: parent
            padding: 0
            spacing: 0
            screenX: root.x + editToolbar.x
            screenY: root.y + editToolbar.y
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
                downAction: () => root._setOutputValue("locked", !root.locked)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.locked ? "lock" : "lock_open"
                    iconSize: 18
                    color: root.locked ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: root.locked ? Translation.tr("Unlock position") : Translation.tr("Lock position") }
            }

            RippleButton {
                visible: root.overlappingLayerCount > 1
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                // Switch only after a completed click. `releaseAction` also runs
                // on pointer cancellation, which previously changed layers when
                // the press was dragged away from the button.
                onClicked: Qt.callLater(() => root._cycleOverlappingWidget())
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "layers"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }
                StyledToolTip {
                    text: Translation.tr("Bring next overlapping widget forward (%1)")
                        .arg(root.overlappingLayerCount)
                }
            }

            RippleButton {
                id: snapZoneBtn
                visible: !root.locked
                width: placementStateRow.implicitWidth + 16; height: 32
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
                contentItem: Row {
                    id: placementStateRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._isZonePlacement ? "grid_on" : "open_with"
                        iconSize: 16
                        color: root._isZonePlacement ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._isZonePlacement ? Translation.tr("Zone") : Translation.tr("Free")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: root._isZonePlacement ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                    }
                }
                StyledToolTip { text: root._isZonePlacement ? Translation.tr("Zone placement active — click for free placement, right-click to cycle") : Translation.tr("Attach this widget to the nearest screen zone") }
            }

            RippleButton {
                id: resetBtn
                property bool armed: false
                visible: !root.locked
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                toggled: armed
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colBackgroundToggled: ColorUtils.applyAlpha(root.widgetSignal, 0.16)
                colBackgroundToggledHover: ColorUtils.applyAlpha(root.widgetSignal, 0.24)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                downAction: () => {
                    if (resetBtn.armed) {
                        resetBtn.armed = false
                        resetConfirmTimer.stop()
                        root.resetToDefaults()
                    } else {
                        resetBtn.armed = true
                        resetConfirmTimer.restart()
                    }
                }
                Timer {
                    id: resetConfirmTimer
                    interval: 2500
                    onTriggered: resetBtn.armed = false
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: resetBtn.armed ? "warning" : "restart_alt"
                    iconSize: 18
                    color: resetBtn.armed ? root.widgetSignal : Appearance.colors.colOnLayer2
                }
                StyledToolTip {
                    text: resetBtn.armed
                        ? Translation.tr("Click again to reset this widget")
                        : Translation.tr("Reset to defaults")
                }
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
                toggled: editPopoverPanel.open
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                downAction: () => { editPopoverPanel.open = !editPopoverPanel.open }
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

        // Inline popover panel follows the toolbar to whichever side has room.
        Item {
            id: editPopoverPanel
            property bool open: false
            onOpenChanged: {
                if (!open && GlobalStates.desktopWidgetQuickControls === root.editInstanceKey)
                    GlobalStates.desktopWidgetQuickControls = ""
            }
            visible: opacity > 0
            enabled: open
            opacity: open ? 1 : 0
            x: root._editControlsGeometry.popoverX - root._editControlsGeometry.toolbarX
            y: root._editControlsGeometry.popoverY - root._editControlsGeometry.toolbarY
            width: Math.min(root.quickControlsAvailableWidth,
                popoverLoader.item ? popoverLoader.item.implicitWidth + 16 : 200)
            height: popoverLoader.item ? popoverLoader.item.implicitHeight + 16 : 0

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            Behavior on x {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animationCurves.standardDecel
                }
            }
            Behavior on y {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animationCurves.standardDecel
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
            }

            PanelSurface {
                id: editPopoverSurface
                anchors.fill: parent
                elevation: 2
                // Floats straight on the wallpaper like the widget manager panel:
                // without a backdrop the aurora/angel fill is a hole, not glass.
                wallpaperBackdrop: true
                readonly property point _screenPos: {
                    void root.x; void root.y;
                    void editPopoverPanel.x; void editPopoverPanel.y;
                    void editPopoverPanel.width; void editPopoverPanel.height;
                    return editPopoverSurface.mapToItem(null, 0, 0)
                }
                backdropScreenX: _screenPos.x
                backdropScreenY: _screenPos.y
                backdropScreenWidth: root.screenWidth
                backdropScreenHeight: root.screenHeight
                radiusOverride: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.small
            }

            Loader {
                id: popoverLoader
                anchors.centerIn: parent
                sourceComponent: root._effectivePopover
                // `visible` is effective visibility and inherits the parent chain;
                // using it as Loader state can latch this popover unloaded forever.
                active: editPopoverPanel.open && root._effectivePopover !== null
            }
        }
    }

    // ── Edit mode widget name label ─────────────────────────
    Row {
        z: 200
        visible: GlobalStates.widgetEditMode
        // Calm-state identity: selection is explicit; hover is only a preview.
        opacity: root.editSelected ? 1 : widgetEditHover.hovered ? 0.78 : 0.46
        x: Math.round((root.width - width) / 2)
        y: root._editControlsBelow ? -height - 6 : root.height + 6
        spacing: 4

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }

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
            width: root.editSelected || root.locked ? 2 : 1
            color: root.locked
                ? ColorUtils.applyAlpha(Appearance.colors.colError,
                    root.editSelected ? 0.86 : 0.42)
                : ColorUtils.applyAlpha(Appearance.colors.colPrimary,
                    root.editSelected ? 0.88
                        : widgetEditHover.hovered ? 0.62 : 0.26)
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    // ── Edit mode resize handles ─────────────────────────────
    readonly property bool _hasResize: Object.keys(root.resizableAxes).length > 0
    readonly property bool _resizeVisible: GlobalStates.widgetEditMode
        && root._hasResize && !root.locked && root._editControlsShown

    // Resize handle component — small draggable square at edges/corners
    component ResizeHandle: Rectangle {
        id: rh
        // Which edges this handle controls
        property bool resizeLeft: false
        property bool resizeRight: false
        property bool resizeTop: false
        property bool resizeBottom: false

        readonly property bool _corner: (resizeLeft || resizeRight)
            && (resizeTop || resizeBottom)
        readonly property bool _axisSupported: {
            const axes = root.resizableAxes
            if (axes.uniform)
                return rh._corner
            const horizontal = (resizeLeft || resizeRight) && Boolean(axes.width)
            const vertical = (resizeTop || resizeBottom) && Boolean(axes.height)
            return rh._corner ? horizontal && vertical : horizontal || vertical
        }

        z: 201
        visible: root._resizeVisible && rh._axisSupported
        width: 12; height: 12
        radius: 4
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
            anchors.margins: -6
            hoverEnabled: rh.visible
            visible: rh.visible
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
                if (axes.width) {
                    const storedWidth = Number(root._readConfigKey(axes.width));
                    vals.width = Number.isFinite(storedWidth) && storedWidth > 0
                        ? storedWidth : Math.round(root.width / root.scaleFactor);
                }
                if (axes.height) {
                    const storedHeight = Number(root._readConfigKey(axes.height));
                    vals.height = Number.isFinite(storedHeight) && storedHeight > 0
                        ? storedHeight : Math.round(root.height / root.scaleFactor);
                }
                rh._startConfigVals = vals
                root._resizePreviewValues = ({})
                root._isResizing = true
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const mapped = rhArea.mapToItem(root.parent, mouse.x, mouse.y);
                const dx = mapped.x - rh._canvasStartX;
                const dy = mapped.y - rh._canvasStartY;
                const axes = root.resizableAxes
                const isUniform = !!axes.uniform

                let newW = rh._startWidth;
                let newH = rh._startHeight;
                let newX = rh._startX;
                let newY = rh._startY;

                if (rh.resizeRight) {
                    let rightEdge = rh._startX + rh._startWidth + dx
                    if (root._snapEnabled)
                        rightEdge = root._snapEditEdge(rightEdge,
                            root._zoneSafeLeft, root._zoneSafeRight)
                    newW = Math.max(root.resizeMinWidth, Math.min(root.resizeMaxWidth,
                        rightEdge - rh._startX))
                }
                if (rh.resizeLeft) {
                    const fixedRight = rh._startX + rh._startWidth
                    let leftEdge = rh._startX + dx
                    if (root._snapEnabled)
                        leftEdge = root._snapEditEdge(leftEdge,
                            root._zoneSafeLeft, root._zoneSafeRight)
                    const dw = Math.max(root.resizeMinWidth, Math.min(root.resizeMaxWidth,
                        fixedRight - leftEdge))
                    newX = fixedRight - dw
                    newW = dw
                }
                if (rh.resizeBottom) {
                    let bottomEdge = rh._startY + rh._startHeight + dy
                    if (root._snapEnabled)
                        bottomEdge = root._snapEditEdge(bottomEdge,
                            root._zoneSafeTop, root._zoneSafeBottom)
                    newH = Math.max(root.resizeMinHeight, Math.min(root.resizeMaxHeight,
                        bottomEdge - rh._startY))
                }
                if (rh.resizeTop) {
                    const fixedBottom = rh._startY + rh._startHeight
                    let topEdge = rh._startY + dy
                    if (root._snapEnabled)
                        topEdge = root._snapEditEdge(topEdge,
                            root._zoneSafeTop, root._zoneSafeBottom)
                    const dh = Math.max(root.resizeMinHeight, Math.min(root.resizeMaxHeight,
                        fixedBottom - topEdge))
                    newY = fixedBottom - dh
                    newH = dh
                }

                const preview = {}
                if (isUniform) {
                    const startSize = Math.max(rh._startWidth, rh._startHeight)
                    const newSize = Math.max(newW, newH)
                    const ratio = startSize > 0 ? newSize / startSize : 1
                    preview[axes.uniform] = Math.round(
                        rh._startConfigVals.uniform * ratio)
                } else {
                    if (axes.width && (rh.resizeLeft || rh.resizeRight)) {
                        const ratio = rh._startWidth > 0 ? newW / rh._startWidth : 1
                        preview[axes.width] = Math.round(
                            rh._startConfigVals.width * ratio)
                    }
                    if (axes.height && (rh.resizeTop || rh.resizeBottom)) {
                        const ratio = rh._startHeight > 0 ? newH / rh._startHeight : 1
                        preview[axes.height] = Math.round(
                            rh._startConfigVals.height * ratio)
                    }
                }
                root._resizePreviewValues = preview
                if (rh.resizeLeft)
                    root.x = root._clampX(newX)
                if (rh.resizeTop)
                    root.y = root._clampY(newY)
            }

            onReleased: {
                const updates = ({})
                const preview = root._resizePreviewValues
                for (const key in preview)
                    updates[key] = preview[key]
                if (rh.resizeLeft)
                    updates.x = Math.round(root.x)
                if (rh.resizeTop)
                    updates.y = Math.round(root.y)
                if (Object.keys(updates).length > 0)
                    root._setOutputValues(updates)
                root._resizePreviewValues = ({})
                root._isResizing = false
                if (root._isZonePlacement) {
                    root.snapToZone(root.placementStrategy)
                    if (root.needsColText) _placementDebounce.restart()
                } else if (root._isAutoPlacement) {
                    root.refreshPlacementIfNeeded()
                } else if (root.needsColText) {
                    _placementDebounce.restart()
                }
            }

            onCanceled: {
                root.x = rh._startX
                root.y = rh._startY
                root._resizePreviewValues = ({})
                root._isResizing = false
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

    ShellEditSizeBadge {
        z: 203
        anchors.centerIn: parent
        active: root._isResizing
        valueText: Math.round(root.width) + " × " + Math.round(root.height) + " px"
        accentColor: Appearance.colors.colPrimary
        surfaceColor: Appearance.colors.colLayer2
        textColor: Appearance.colors.colOnLayer2
        fontFamily: Appearance.font.family.main
        fontPixelSize: Appearance.font.pixelSize.smaller
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
            newX = root._snapEditX(newX)
            newY = root._snapEditY(newY)
        }
        const finalX = root._snapEnabled ? newX : root._clampX(newX)
        const finalY = root._snapEnabled ? newY : root._clampY(newY)
        root.x = finalX;
        root.y = finalY;
        const updates = { x: finalX, y: finalY }
        if (root.placementStrategy !== "free")
            updates.placementStrategy = "free"
        root._setOutputValues(updates)
        if (root.needsColText) _placementDebounce.restart();
    }

    // ── Inline popover for quick controls ─────────────────────
    // Widget-specific controls stay primary. Color customization uses the same
    // preset-card language as Settings; detailed role remapping lives there.
    property Component editPopoverContent: null
    property var manifestConfigKeys: ({})
    property bool semanticPaletteControls: !root.configEntryName.startsWith("custom.")
    property bool semanticPaletteQuickControls: semanticPaletteControls
    readonly property var _manifestKeyList: {
        const keys = root.manifestConfigKeys;
        if (!keys || typeof keys !== "object") return [];
        return Object.keys(keys).map(k => ({ key: k, spec: keys[k] }));
    }
    property Component _autoPopoverComponent: _manifestKeyList.length > 0 ? _autoPopoverRef : null
    readonly property Component _widgetSpecificPopover: root.editPopoverContent
        ?? (root._manifestKeyList.length > 0 ? root._autoPopoverComponent : null)
    readonly property Component _effectivePopover:
        root._widgetSpecificPopover !== null || root.semanticPaletteControls
            ? root._semanticPalettePopover : null

    Component {
        id: _autoPopoverRef
        ManifestPopover {
            configEntryName: root.configEntryName
            manifestKeys: root._manifestKeyList
            readConfigKey: (key) => root._readConfigKey(key)
        }
    }

    property Component _semanticPalettePopover: Component {
        WidgetQuickControlsLayout {
            id: semanticQuickRoot
            availableWidth: root.quickControlsAvailableWidth - 16
            availableHeight: root.quickControlsAvailableHeight - 16
            regularWidth: Math.max(244,
                specificQuickLoader.item?.implicitWidth ?? 0)

            Loader {
                id: specificQuickLoader
                active: root._widgetSpecificPopover !== null
                visible: active
                sourceComponent: root._widgetSpecificPopover
                Layout.fillWidth: true
                Layout.preferredHeight: item?.implicitHeight ?? 0
            }

            Rectangle {
                visible: root._widgetSpecificPopover !== null && root.semanticPaletteQuickControls
                Layout.fillWidth: true
                implicitHeight: visible ? 1 : 0
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.10)
            }

            ColumnLayout {
                id: paletteQuickSection
                visible: root.semanticPaletteQuickControls
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    MaterialSymbol {
                        text: "palette"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("Colors")
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: root.widgetPalettePresetLabel
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: semanticQuickRoot.metricColumns
                    columnSpacing: 5
                    rowSpacing: 5

                    Repeater {
                        model: root.widgetPalettePresets

                        delegate: RippleButton {
                            id: palettePresetButton
                            required property var modelData
                            readonly property color presetAccent: root.widgetSemanticColor(modelData.roles[0])
                            Layout.fillWidth: true
                            Layout.minimumWidth: 112
                            Layout.preferredHeight: 34
                            buttonRadius: Appearance.rounding.small
                            toggled: root.widgetPalettePreset === modelData.value
                            colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.045)
                            colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.085)
                            colBackgroundToggled: ColorUtils.applyAlpha(palettePresetButton.presetAccent, 0.10)
                            colBackgroundToggledHover: ColorUtils.applyAlpha(palettePresetButton.presetAccent, 0.15)
                            colRipple: ColorUtils.applyAlpha(palettePresetButton.presetAccent, 0.10)
                            colRippleToggled: ColorUtils.applyAlpha(palettePresetButton.presetAccent, 0.14)
                            downAction: () => root.applyWidgetPalettePreset(modelData.value)

                            contentItem: Item {
                                Rectangle {
                                    anchors.fill: parent
                                    radius: palettePresetButton.buttonRadius
                                    color: "transparent"
                                    border.width: palettePresetButton.toggled ? 1.5 : 0
                                    border.color: palettePresetButton.presetAccent
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 7
                                    anchors.rightMargin: 7
                                    spacing: 6

                                    Row {
                                        spacing: -3
                                        Repeater {
                                            model: palettePresetButton.modelData.roles
                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: root.widgetSemanticColor(modelData)
                                                border.width: 1
                                                border.color: Qt.rgba(0, 0, 0, 0.25)
                                                z: 3 - index
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: palettePresetButton.modelData.label
                                        color: palettePresetButton.toggled
                                            ? palettePresetButton.presetAccent
                                            : Appearance.colors.colOnLayer2
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: palettePresetButton.toggled
                                            ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
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
        if (root._isResizing
                && Object.prototype.hasOwnProperty.call(root._resizePreviewValues, key))
            return root._resizePreviewValues[key]
        return DesktopWidgetLayout.value(root.outputName, root.configEntryName,
            key, Config.getNestedValue(root._configPath + "." + key, undefined))
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
            if (Config.getNestedValue(prefix + "." + key, undefined) === undefined)
                updates[prefix + "." + key] = root.defaultConfig[key];
        }
        if (Object.keys(updates).length > 0)
            Config.setNestedValues(updates);
    }
    Component.onCompleted: {
        _seedDefaultsIfNeeded();
        root._syncPlacementStrategy();
        Qt.callLater(root.applyPlacementFromConfig);
    }
    function resetToDefaults(): void {
        const prefix = root._configPath;
        const defaults = root.defaultConfig;
        const updates = {};
        for (const key in defaults) {
            // Resetting a visible widget must not make it disappear or change
            // the lock state that guards this action. Those are lifecycle and
            // interaction controls, not visual defaults.
            if (key === "enable" || key === "locked")
                continue;
            updates[prefix + "." + key] = defaults[key];
        }
        updates[prefix + ".palette.primary"] = "primary"
        updates[prefix + ".palette.secondary"] = "secondary"
        updates[prefix + ".palette.tertiary"] = "tertiary"
        updates[prefix + ".palette.signal"] = "signal"
        updates[prefix + ".palette.surface"] = "surface"
        Config.setNestedValues(updates);
        const layoutKeys = ["locked", "placementStrategy", "x", "y", "widgetScale",
            "palette.primary", "palette.secondary", "palette.tertiary", "palette.signal", "palette.surface"]
        for (const axis of Object.keys(root.resizableAxes ?? {})) {
            const key = String(root.resizableAxes[axis] ?? "")
            if (key.length > 0 && !layoutKeys.includes(key))
                layoutKeys.push(key)
        }
        DesktopWidgetLayout.clearValues(root.outputName, root.configEntryName, layoutKeys)
        syncFreePositionFromConfig();
        refreshPlacementIfNeeded();
    }

    property bool needsColText: false
    readonly property bool positionColorAdaptationEnabled: Boolean(
        Config.getNestedValue("background.widgets.adaptColorsToWallpaperPosition", false))
    // Opt-in for widgets whose bare content changes ink with the wallpaper under
    // them. Sampling is throttled while dragging; the shared process remains
    // serialized so pointer movement can never spawn an unbounded process fanout.
    property bool liveColorTracking: false
    property int liveColorTrackingInterval: 220
    property color dominantColor: Appearance.colors.colPrimary
    // Wallpaper region brightness (0-1, from image analysis). -1 = not yet analyzed.
    property real regionBrightness: -1
    readonly property bool _hasBrightness: regionBrightness >= 0
    // How "busy"/high-contrast the region is (0-1, = brightness std-dev / 255).
    // 0 = flat region (the mean is trustworthy). Higher = textured region where the
    // mean lies, so legibility must target worst-case sub-areas, not the average.
    property real regionBrightnessSpread: 0
    // Representative color of the wallpaper region behind the widget.
    // dominantColor carries the hue/saturation; regionBrightness is the reliable
    // luminance anchor (the dominant color alone can lie about overall lightness).
    readonly property color _regionBg: {
        const dom = Qt.color(root.dominantColor);
        if (!root._hasBrightness) return dom;
        return Qt.hsla(dom.hslHue, dom.hslSaturation, root.regionBrightness, 1.0);
    }
    // Body-text tones that carry wallpaper CHARACTER while staying legible — the exact
    // move the shell's ZZZ style makes for its on-surface ink (Appearance.zzz.onColor):
    // keep a confident near-white / near-black LIGHTNESS so text always reads, but inject
    // the wallpaper HUE at LOW saturation so the widget belongs to the wallpaper instead
    // of being flat grey. Earlier extremes were wrong in both directions: a 10% mix toward
    // colPrimary dragged the lightness and turned text muddy/yellow on yellow walls, while
    // pure neutral lost all colour generation. A low-sat hue tint at a fixed light/dark
    // lightness is the legible middle the shell already uses.
    // Use the shell's own Material on-surface tokens so widget text matches the rest of
    // the UI's colour generation: colOnLayer0 is the generated on-surface ink (light in
    // dark mode), m3inverseOnSurface is its generated opposite (dark in dark mode). We
    // pick whichever opposes the wallpaper region's luminance, so text is light on dark
    // regions and dark on bright ones — same tokens, region-aware selection.
    readonly property color _inkLight: Appearance.m3colors.darkmode
        ? Appearance.colors.colOnLayer0 : Appearance.m3colors.m3inverseOnSurface
    readonly property color _inkDark: Appearance.m3colors.darkmode
        ? Appearance.m3colors.m3inverseOnSurface : Appearance.colors.colOnLayer0
    readonly property bool forceLightInk: root.colorMode === "light"
    readonly property bool forceDarkInk: root.colorMode === "dark"
    property color colText: {
        if (root.colorMode === "light") return root._inkLight;
        if (root.colorMode === "dark") return root._inkDark;
        const onBlurredLock = (GlobalStates.screenLocked && (Config.options?.lock?.blur?.enable ?? false))
        if (onBlurredLock) return Appearance.colors.colOnLayer0;
        if (!root.positionColorAdaptationEnabled)
            return Appearance.colors.colOnLayer0;

        // Auto: pick the neutral whose luminance opposes the region's MEAN brightness, so
        // text is DARK on bright wallpapers and LIGHT on dark ones — clean and legible,
        // never the muddy tinted tone that disappeared on same-hue wallpapers. The halo
        // (colHalo, scaled by region busyness) carries legibility over textured pixels.
        const bg = root._regionBg;
        const wantLight = ColorUtils.contrastRatio(Qt.rgba(1, 1, 1, 1), bg) >= ColorUtils.contrastRatio(Qt.rgba(0, 0, 0, 1), bg);
        return wantLight ? root._inkLight : root._inkDark;
    }

    // ── Centralized desktop-widget semantic palette ──────────────────────────
    // Every built-in widget selects from the palette already generated by the
    // wallpaper/theme. Local region analysis may choose WHICH generated token is
    // readable, but never synthesizes a new hue/lightness variant.
    readonly property string widgetPrimaryRole: String(Config.getNestedValue(root._configPath + ".palette.primary", "primary"))
    readonly property string widgetSecondaryRole: String(Config.getNestedValue(root._configPath + ".palette.secondary", "secondary"))
    readonly property string widgetTertiaryRole: String(Config.getNestedValue(root._configPath + ".palette.tertiary", "tertiary"))
    readonly property string widgetSignalRole: String(Config.getNestedValue(root._configPath + ".palette.signal", "signal"))
    readonly property string widgetSurfaceRole: String(Config.getNestedValue(root._configPath + ".palette.surface", "surface"))

    readonly property var widgetPalettePresets: [
        { value: "balanced", label: Translation.tr("Default"), roles: ["primary", "secondary", "tertiary"] },
        { value: "primary", label: Translation.tr("Primary"), roles: ["primary", "primary", "primary"] },
        { value: "secondary", label: Translation.tr("Secondary"), roles: ["secondary", "secondary", "secondary"] },
        { value: "tertiary", label: Translation.tr("Tertiary"), roles: ["tertiary", "tertiary", "tertiary"] }
    ]

    function widgetPalettePresetSpec(preset: string): var {
        switch (preset) {
        case "primary":
            return { primary: "primary", secondary: "primary", tertiary: "primary", signal: "signal", surface: "surface" };
        case "secondary":
            return { primary: "secondary", secondary: "secondary", tertiary: "secondary", signal: "signal", surface: "surface" };
        case "tertiary":
            return { primary: "tertiary", secondary: "tertiary", tertiary: "tertiary", signal: "signal", surface: "surface" };
        default:
            return { primary: "primary", secondary: "secondary", tertiary: "tertiary", signal: "signal", surface: "surface" };
        }
    }

    readonly property string widgetPalettePreset: {
        const roles = {
            primary: root.widgetPrimaryRole,
            secondary: root.widgetSecondaryRole,
            tertiary: root.widgetTertiaryRole,
            signal: root.widgetSignalRole,
            surface: root.widgetSurfaceRole
        };
        for (const preset of root.widgetPalettePresets) {
            const spec = root.widgetPalettePresetSpec(preset.value);
            if (roles.primary === spec.primary && roles.secondary === spec.secondary
                    && roles.tertiary === spec.tertiary && roles.signal === spec.signal
                    && roles.surface === spec.surface)
                return preset.value;
        }
        return "custom";
    }
    readonly property string widgetPalettePresetLabel: {
        const match = root.widgetPalettePresets.find(preset => preset.value === root.widgetPalettePreset);
        return match ? match.label : Translation.tr("Custom");
    }

    function applyWidgetPalettePreset(preset: string): void {
        const spec = root.widgetPalettePresetSpec(preset);
        const prefix = root._configPath + ".palette.";
        const updates = {};
        updates[prefix + "primary"] = spec.primary;
        updates[prefix + "secondary"] = spec.secondary;
        updates[prefix + "tertiary"] = spec.tertiary;
        updates[prefix + "signal"] = spec.signal;
        updates[prefix + "surface"] = spec.surface;
        Config.setNestedValues(updates);
    }

    function widgetSemanticSet(role: string): var {
        const c = Appearance.colors;
        switch (role) {
        case "secondary":
            return { color: c.colSecondary, onColor: c.colOnSecondary,
                container: c.colSecondaryContainer, onContainer: c.colOnSecondaryContainer };
        case "tertiary":
            return { color: c.colTertiary, onColor: c.colOnTertiary,
                container: c.colTertiaryContainer, onContainer: c.colOnTertiaryContainer };
        case "warning":
            return { color: c.colWarning, onColor: c.colOnTertiary,
                container: c.colWarningContainer, onContainer: c.colOnWarningContainer };
        case "signal":
            return {
                color: Appearance.zzzEverywhere ? Appearance.zzz.signal
                    : Appearance.inirEverywhere ? Appearance.inir.colError : c.colError,
                onColor: Appearance.zzzEverywhere ? Appearance.zzz.onSignal : c.colOnError,
                container: c.colErrorContainer,
                onContainer: c.colOnErrorContainer
            };
        case "surface":
            return {
                color: c.colOnSurfaceVariant,
                onColor: c.colLayer2,
                container: Appearance.zzzEverywhere ? Appearance.zzz.chrome
                    : Appearance.cookieEverywhere ? c.colLayer2
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : c.colLayer1,
                onContainer: Appearance.zzzEverywhere ? Appearance.zzz.onBg
                    : Appearance.cookieEverywhere ? Appearance.cookie.onColor
                    : c.colOnLayer1
            };
        default:
            return { color: c.colPrimary, onColor: c.colOnPrimary,
                container: c.colPrimaryContainer, onContainer: c.colOnPrimaryContainer };
        }
    }

    function widgetSemanticColor(role: string): color {
        return root.widgetSemanticSet(role).color;
    }
    function widgetSemanticContainer(role: string): color {
        return root.widgetSemanticSet(role).container;
    }
    function widgetSemanticOnColor(role: string): color {
        return root.widgetSemanticSet(role).onColor;
    }
    function widgetSemanticOnContainer(role: string): color {
        return root.widgetSemanticSet(role).onContainer;
    }

    readonly property color widgetAccent: root.widgetSemanticColor(root.widgetPrimaryRole)
    readonly property color widgetAccent2: root.widgetSemanticColor(root.widgetSecondaryRole)
    readonly property color widgetAccent3: root.widgetSemanticColor(root.widgetTertiaryRole)
    readonly property color widgetSignal: root.widgetSemanticColor(root.widgetSignalRole)
    readonly property bool widgetHasSurface: root.backgroundOpacity > 0 || root.effectiveBlur
    readonly property bool regionIsBright: root.positionColorAdaptationEnabled && root._hasBrightness
        ? root.regionBrightness > 0.55 : !Appearance.m3colors.darkmode

    // Surfaces use semantic containers directly. This removes the old HSL
    // wallpaper-region re-toning that could turn generated warm palettes muddy.
    readonly property color widgetPlateColor: root.widgetSemanticContainer(root.widgetSurfaceRole)
    readonly property bool widgetPlateIsDark: ColorUtils.relativeLuminance(root.widgetPlateColor) < 0.38
    readonly property color widgetSurfaceInk: root.forceLightInk ? root._inkLight
        : root.forceDarkInk ? root._inkDark
        : root.widgetSemanticOnContainer(root.widgetSurfaceRole)
    readonly property color widgetInk: root.widgetHasSurface ? root.widgetSurfaceInk : root.colText
    readonly property color widgetInkMuted: ColorUtils.applyAlpha(root.widgetInk, 0.66)
    readonly property color widgetInkSubtle: ColorUtils.applyAlpha(root.widgetInk, 0.58)
    readonly property real widgetCardRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.cookieEverywhere ? Appearance.cookie.roundLarge
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal

    property color accentBackdrop: root.widgetHasSurface ? root.widgetPlateColor
        : root.positionColorAdaptationEnabled && root._hasBrightness ? root._regionBg
        : Appearance.colors.colLayer0

    // Pick only among existing generated semantic tokens. Movement can therefore
    // change polarity when required, but cannot manufacture a brown/gray/red hue.
    function widgetSemanticForeground(role: string, backdrop = root.accentBackdrop,
            targetContrast = 3.0): color {
        const set = root.widgetSemanticSet(role);
        const candidates = [set.color, set.onContainer, set.onColor, set.container, root.widgetInk];
        let best = candidates[0];
        let bestRatio = ColorUtils.contrastRatio(best, backdrop);
        for (let i = 0; i < candidates.length; i++) {
            const candidate = Qt.color(candidates[i]);
            if (!candidate.valid) continue;
            const ratio = ColorUtils.contrastRatio(candidate, backdrop);
            if (ratio >= targetContrast) return candidate;
            if (ratio > bestRatio) {
                best = candidate;
                bestRatio = ratio;
            }
        }
        return best;
    }

    // Compatibility for manual/custom palettes. Built-in semantic graphics should
    // use widgetSemanticForeground() or widgetAccent* instead.
    function widgetRoleColor(seed, targetContrast = 4.0, minSaturation = 0.45) {
        const source = Qt.color(seed);
        if (!source.valid) return root.widgetInk;
        return ColorUtils.readableAccentInk(source, root.accentBackdrop,
            targetContrast, root.widgetInk);
    }

    readonly property color widgetAccentVisible: root.widgetSemanticForeground(root.widgetPrimaryRole)
    readonly property color widgetAccent2Visible: root.widgetSemanticForeground(root.widgetSecondaryRole)
    readonly property color widgetAccent3Visible: root.widgetSemanticForeground(root.widgetTertiaryRole)

    // Legibility shadow placed BEHIND text and plate-less elements so they
    // detach from any wallpaper without a visible card. Always dark (a true
    // shadow) — a white halo behind dark text on bright wallpapers read as a
    // glow, not a shadow. colHalo is consumed only by the clock.
    // Alpha scales with region busyness: near-invisible on flat regions, strong
    // on textured ones — a legibility shadow only where it's actually needed.
    readonly property real _haloAlpha: root.positionColorAdaptationEnabled
        ? 0.35 + 0.45 * Math.min(1, root.regionBrightnessSpread / 0.28) : 0.35
    readonly property color colHalo: ColorUtils.applyAlpha(Qt.rgba(0, 0, 0, 1), root._haloAlpha)

    // Compatibility helper: accent identity is owned by MaterialThemeLoader, not by
    // the later wallpaper-region analysis.
    function ensureVisible(c: color): color {
        return c;
    }

    property bool wallpaperIsVideo: {
        const p = (Config.options?.background?.wallpaperPath ?? "").toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
    }
    property string wallpaperPath: wallpaperIsVideo ? (Config.options?.background?.thumbnailPath ?? "") : (Config.options?.background?.wallpaperPath ?? "")
    
    onWallpaperPathChanged: {
        root.regionBrightness = -1
        root.regionBrightnessSpread = 0
        if (root.wallpaperPath.length > 0
                && (root._isAutoPlacement
                    || (root.positionColorAdaptationEnabled && root.needsColText)))
            _placementDebounce.restart()
    }
    onPositionColorAdaptationEnabledChanged: {
        root.regionBrightness = -1
        root.regionBrightnessSpread = 0
        root.dominantColor = Appearance.colors.colPrimary
        root._colorRerunQueued = false
        _liveColorAnalysisTimer.stop()
        if (colorOnlyProc.running)
            colorOnlyProc.running = false
        if (root.positionColorAdaptationEnabled && root.needsColText
                && root.wallpaperPath.length > 0)
            _placementDebounce.restart()
    }
    // Widgets may gate needsColText on runtime state (e.g. mascot only when its
    // card is on) — kick the analysis when it turns on after load.
    onNeedsColTextChanged: if (needsColText && positionColorAdaptationEnabled)
        _placementDebounce.restart()
    onXChanged: root._queueLiveColorAnalysis()
    onYChanged: root._queueLiveColorAnalysis()
    onIsDraggingChanged: {
        if (!root.positionColorAdaptationEnabled
                || !root.liveColorTracking || !root.needsColText)
            return;
        if (root.isDragging)
            root._queueLiveColorAnalysis();
        else
            _placementDebounce.restart();
    }
    onPlacementStrategyChanged: Qt.callLater(root.applyPlacementFromConfig)
    // Re-snap zone positions when screen size changes
    onScaledScreenWidthChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
        else if (root.placementStrategy === "free") _geometryPlacementDebounce.restart()
    onScaledScreenHeightChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
        else if (root.placementStrategy === "free") _geometryPlacementDebounce.restart()
    on_SafeLeftChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
        else _geometryPlacementDebounce.restart()
    on_SafeTopChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
        else _geometryPlacementDebounce.restart()
    on_SafeRightChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
        else _geometryPlacementDebounce.restart()
    on_SafeBottomChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
        else _geometryPlacementDebounce.restart()
    on_ZoneSafeLeftChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
    on_ZoneSafeTopChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
    on_ZoneSafeRightChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
    on_ZoneSafeBottomChanged: if (root._isZonePlacement) _zoneResnapDebounce.restart()
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
            else if (root.placementStrategy === "free") {
                // Re-clamp rendered position against the full desktop canvas.
                // Saved coordinates stay untouched until the next user gesture.
                const clampedX = root._clampX(root.x)
                const clampedY = root._clampY(root.y)
                if (Math.round(root.x) !== Math.round(clampedX))
                    root.x = clampedX
                if (Math.round(root.y) !== Math.round(clampedY))
                    root.y = clampedY
            }
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
    Timer {
        id: _liveColorAnalysisTimer
        interval: root.liveColorTrackingInterval
        repeat: false
        onTriggered: {
            if (root.positionColorAdaptationEnabled && root.liveColorTracking
                    && root.needsColText && root.isDragging
                    && !GlobalStates.widgetEditMode)
                root._runColorAnalysis();
        }
    }
    function _queueLiveColorAnalysis(): void {
        // Edit mode prioritizes stable feedback: pointer movement can cross very
        // different wallpaper regions in a few frames, and applying intermediate
        // color samples makes a widget visibly flash between palettes. Freeze the
        // sampled palette during the gesture and analyze the final geometry once
        // on release. Outside edit mode, opt-in live tracking keeps its old role.
        if (GlobalStates.widgetEditMode || !root.positionColorAdaptationEnabled
                || !root.liveColorTracking || !root.needsColText || !root.isDragging)
            return;
        if (!_liveColorAnalysisTimer.running)
            _liveColorAnalysisTimer.start();
    }
    function refreshPlacementIfNeeded() {
        if (Quickshell.env("INIR_REGION_DEBUG") === "1")
            console.log("[Region]", root.configEntryName, "refresh @", Math.round(root.x), Math.round(root.y),
                "strategy", root.placementStrategy, "needsColText", root.needsColText);
        if (!Config.ready) return;
        if (!root.wallpaperPath || root.wallpaperPath.length === 0) return;
        // For auto-placement (leastBusy/mostBusy): full analysis (position + color)
        if (root._isAutoPlacement) {
            leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
            leastBusyRegionProc.running = false;
            leastBusyRegionProc.running = true;
            return;
        }
        // For free/zone widgets, local color analysis is an explicit global opt-in.
        if (root.positionColorAdaptationEnabled && root.needsColText)
            root._runColorAnalysis();
    }

    // The colour analysis is a subprocess and the widget can move while it runs.
    // Restarting it with `running = false; running = true` did NOT discard the run
    // in flight: its result still landed, carrying the colour of the position the
    // widget had LEFT, and whichever of the two finished last won. That is the
    // double colour change on every drag — one correct answer and one stale answer
    // fighting, applied in completion order.
    //
    // So: never overlap runs, pin the position the run was launched for instead of
    // letting it track root.x/y, and throw away any answer computed for somewhere
    // the widget no longer is.
    property bool _colorRerunQueued: false

    function _colorTargetX(): int { return Math.max(0, Math.round(root.x / Math.max(root.wallpaperScale, 0.001))); }
    function _colorTargetY(): int { return Math.max(0, Math.round(root.y / Math.max(root.wallpaperScale, 0.001))); }
    function _colorTargetWidth(): int { return Math.max(1, Math.round(root.width / Math.max(root.wallpaperScale, 0.001))); }
    function _colorTargetHeight(): int { return Math.max(1, Math.round(root.height / Math.max(root.wallpaperScale, 0.001))); }

    function _runColorAnalysis(): void {
        if (!root.positionColorAdaptationEnabled || !root.needsColText)
            return;
        if (colorOnlyProc.running) {
            root._colorRerunQueued = true;
            return;
        }
        root._colorRerunQueued = false;
        colorOnlyProc.posX = root._colorTargetX();
        colorOnlyProc.posY = root._colorTargetY();
        colorOnlyProc.sampleWidth = root._colorTargetWidth();
        colorOnlyProc.sampleHeight = root._colorTargetHeight();
        colorOnlyProc.sampleScreenWidth = Math.round(root.scaledScreenWidth)
        colorOnlyProc.sampleScreenHeight = Math.round(root.scaledScreenHeight)
        colorOnlyProc.sampleWallpaperPath = root.wallpaperPath
        colorOnlyProc.running = true;
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        property int contentWidth: Math.max(1, Math.round(root.width / Math.max(root.wallpaperScale, 0.001)))
        property int contentHeight: Math.max(1, Math.round(root.height / Math.max(root.wallpaperScale, 0.001)))
        property int horizontalPadding: root._analysisPadding
        property int verticalPadding: root._analysisPadding
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
                    if (Quickshell.env("INIR_REGION_DEBUG") === "1")
                        console.log("[Region]", root.configEntryName, "LEAST-BUSY landed",
                            "dom", parsedContent.dominant_color, "bright", parsedContent.brightness);
                    if (root.positionColorAdaptationEnabled) {
                        root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                        if (parsedContent.brightness !== undefined)
                            root.regionBrightness = parsedContent.brightness / 255.0;
                        if (parsedContent.brightness_std !== undefined)
                            root.regionBrightnessSpread = parsedContent.brightness_std / 255.0;
                    }
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
        // Pinned at launch, NOT bound to root.x/y: the command must describe the
        // position this run was actually started for, and the result has to be
        // checked against it when it lands.
        property int posX: 0
        property int posY: 0
        property int sampleWidth: 1
        property int sampleHeight: 1
        property int sampleScreenWidth: 1
        property int sampleScreenHeight: 1
        property string sampleWallpaperPath: ""
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh")
            , "--color-only"
            , "--position-x", posX
            , "--position-y", posY
            , "--screen-width", sampleScreenWidth
            , "--screen-height", sampleScreenHeight
            , "--width", sampleWidth
            , "--height", sampleHeight
            , sampleWallpaperPath
        ]
        stdout: StdioCollector {
            id: colorOnlyOutputCollector
            onStreamFinished: {
                if (!root.positionColorAdaptationEnabled) return;
                const output = colorOnlyOutputCollector.text;
                if (output.length === 0) return;
                try {
                    const parsedContent = JSON.parse(output);
                    const geometryChanged = colorOnlyProc.posX !== root._colorTargetX()
                        || colorOnlyProc.posY !== root._colorTargetY()
                        || colorOnlyProc.sampleWidth !== root._colorTargetWidth()
                        || colorOnlyProc.sampleHeight !== root._colorTargetHeight()
                        || colorOnlyProc.sampleScreenWidth !== Math.round(root.scaledScreenWidth)
                        || colorOnlyProc.sampleScreenHeight !== Math.round(root.scaledScreenHeight)
                        || colorOnlyProc.sampleWallpaperPath !== root.wallpaperPath
                    // Opt-in live tracking may consume a recent position sample
                    // during ordinary dragging, but edit mode never does: editor
                    // feedback stays chromatically stable until the final drop.
                    const acceptsLiveSample = root.liveColorTracking && root.isDragging
                        && !GlobalStates.widgetEditMode
                    const stale = geometryChanged && !acceptsLiveSample;
                    if (Quickshell.env("INIR_REGION_DEBUG") === "1")
                        console.log("[Region]", root.configEntryName, "COLOR-ONLY for", colorOnlyProc.posX, colorOnlyProc.posY,
                            "now at", root._colorTargetX(), root._colorTargetY(),
                            "bright", parsedContent.brightness,
                            stale ? "-> STALE, discarded" : acceptsLiveSample && geometryChanged ? "-> LIVE sample" : "-> applied");
                    // The widget moved while this was being computed: this colour is
                    // for a place it is not any more. Applying it is the second,
                    // wrong colour change. Drop it and analyse where it actually is.
                    if (stale) {
                        root._colorRerunQueued = true;
                        return;
                    }
                    root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                    if (parsedContent.brightness !== undefined)
                        root.regionBrightness = parsedContent.brightness / 255.0;
                    if (parsedContent.brightness_std !== undefined)
                        root.regionBrightnessSpread = parsedContent.brightness_std / 255.0;
                } catch (e) {
                    console.warn("[Widgets] Failed to parse color-only output:", e);
                }
            }
        }
        // Runs are serialised, so a request that arrived while this one was busy —
        // or a result thrown away as stale — is picked up here, once, at the
        // position the widget actually ended up at.
        onExited: if (root.positionColorAdaptationEnabled && root._colorRerunQueued)
            Qt.callLater(root._runColorAnalysis)
    }
}
