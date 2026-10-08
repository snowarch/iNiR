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
import qs.modules.iris.style
import qs.modules.iris.widgets
import qs.modules.iris.components

AbstractWidget {
    id: root

    required property string configEntryName
    readonly property bool widgetIrisFamily: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property bool widgetIris: root.widgetIrisFamily && root.irisDesign === "iris"
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
        // A style picked on one widget while a design covers it makes that widget an exception.
        if (root.widgetSharedDesign !== "individual"
                && (values.style !== undefined || values.displayMode !== undefined))
            values = Object.assign({}, values, root.widgetIrisFamily ? { "iris.design": "material" } : { design: "individual" })
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
    // iRiS stack (DesktopWidgetStacks): this widget is one page of several that share a place.
    readonly property var stack: DesktopWidgetStacks.info(root.outputName, root.configEntryName)
    readonly property bool stacked: root.stack !== null
    readonly property bool stackShown: root.stack === null || root.stack.shown
    // 0 while this page is shown; a page's length away (+1 below, -1 above) while it waits or leaves.
    property real stackPos: 0
    readonly property bool stackMoving: stackSlide.running
    readonly property bool stackPresent: root.stackShown || (root.stackMoving && root.irisFaced)
    readonly property bool stackLeaving: root.stacked && !root.stackShown && root.stackPresent
    // A stack sits in the layer order as one.
    readonly property string layerKey: root.stacked ? root.outputName + "::stack:" + root.stack.id : root.editInstanceKey
    readonly property int desktopPersistentZ: {
        Config.revision
        const order = Config.getNestedValue("background.widgets.layerOrder", []) ?? []
        const index = order.indexOf(root.layerKey)
        return index >= 0 ? 1000 + index : root.widgetIndex
    }
    // Selection temporarily rises above every widget while editing, but the
    // persisted order remains active both inside and outside edit mode.
    // A page leaving a stack stays above the one arriving until it is gone.
    readonly property int desktopStackZ: root.stackLeaving ? 10001
        : root.editSelected ? 10000 : root.desktopPersistentZ
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
    dragAboveContent: GlobalStates.widgetEditMode

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
    property bool _irisSizing: false
    property bool _irisPreviewing: false
    property var _resizePreviewValues: ({})
    readonly property real scaleFactor: _baseScale
    property bool _geometryReady: false
    readonly property bool animateGeometry: root._geometryReady && root.animationsActive
        && !root._isResizing && !root.containsPress

    Behavior on implicitWidth {
        enabled: root.animateGeometry
        NumberAnimation {
            duration: root.widgetIris ? IrisStyle.morphDuration : Appearance.animation.elementMove.duration
            easing.type: root.widgetIris ? Easing.BezierSpline : Appearance.animation.elementMove.type
            easing.bezierCurve: root.widgetIris ? IrisStyle.morphCurve : Appearance.animation.elementMove.bezierCurve
        }
    }
    Behavior on implicitHeight {
        enabled: root.animateGeometry
        NumberAnimation {
            duration: root.widgetIris ? IrisStyle.morphDuration : Appearance.animation.elementMove.duration
            easing.type: root.widgetIris ? Easing.BezierSpline : Appearance.animation.elementMove.type
            easing.bezierCurve: root.widgetIris ? IrisStyle.morphCurve : Appearance.animation.elementMove.bezierCurve
        }
    }
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
    readonly property bool blurAvailable: !root.widgetIris && Appearance.effectsEnabled
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

    function nudge(dx: real, dy: real): void {
        if (root.locked) return
        root._setOutputValues({placementStrategy: "free",
            x: root._snapToPixel(root._clampX(root.x + dx)),
            y: root._snapToPixel(root._clampY(root.y + dy))})
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

    // The canvas keeps containsPress true through the drop commit. Placement
    // therefore resumes from committed coordinates, without a timed guard.
    readonly property bool _autoPosition: root.placementStrategy !== "free"
        && !root.containsPress && !root.isDragging && !root._isResizing
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
        onTriggered: MascotChaos.report(root.editInstanceKey, root.x, root.y, root.width, root.height, root.outputName, root.configEntryName)
        // widgets born while chaos is already on still need a first report
        Component.onCompleted: if (root._chaosWatch) restart()
    }
    on_ChaosWatchChanged: {
        if (_chaosWatch) _chaosReportDebounce.restart()
        else MascotChaos.unreport(root.editInstanceKey)
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
        function onImpact(widgetKey, vx, vy, mode) {
            if (!MascotChaos.enabled || widgetKey !== root.editInstanceKey) return
            if (MascotChaos.suppressed || !root.visible || root.locked) return
            _chaosFling.stop()
            _chaosReturn.stop()
            root._flingWreck = MascotChaos.allowRearrange && (mode === "wreck" || mode === "vanish")
            root._flingPersist = MascotChaos.allowRearrange && mode === "persist" && root.placementStrategy === "free" && !root.locked
            if (root._flingPersist) MascotChaos.rememberOriginal(root.editInstanceKey, root.x, root.y)
            root._flingX = vx
            if (mode === "vanish" && root._flingWreck) {
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
            root._flingPersist = false
            root._flingWreck = false
            _chaosFling.stop()
            _chaosReturn.stop()
            root._flingWreck = false
            // ease everything back upright instead of teleporting
            _chaosReturn.restart()
        }
    }

    visible: opacity > 0
    // iRiS dims the face only, so its edit toolbar and sheet stay legible over a dimmed widget.
    opacity: ((GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1)
        * (root.irisFaced ? 1 : root.widgetOpacity * root.dimOpacity)
        * (root.stackPresent ? 1 : 0)
        * (1 - root.absorb)
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
    // Continuous decoration holds its frame wherever the wallpaper does (background.videoPause):
    // every frame it draws repaints the whole desktop window and makes Niri recompose the output.
    readonly property bool motionActive: root.powerActive && Wallpapers.videoMotionAllowedOn(root.outputName)

    // Eased transitions follow motionActive: behind windows a value snaps instead. Every animation that starts
    // makes Qt's threaded loop request a frame from every shell window (QSGThreadedRenderLoop::animationStarted).
    readonly property bool animationsActive: (root.widgetIris ? IrisStyle.motionEnabled : Appearance.animationsEnabled) && root.motionActive

    // Visual feedback when paused - desaturation + slight dim
    // Config option to disable visual effect if user only wants GPU savings
    readonly property bool _showPausedEffect: Config.options?.background?.widgets?.powerSaving?.showPausedEffect ?? false
    readonly property real _pausedSaturation: root.powerActive ? 0 : -0.7  // -0.7 = mostly grayscale
    readonly property real _pausedBrightness: root.powerActive ? 0 : -0.15 // slight dim
    
    readonly property bool _pausedLayer: !root.powerActive && root._showPausedEffect
    layer.enabled: root.visible && (root._pausedLayer || root._legibleShadow)
    layer.effect: MultiEffect {
        saturation: root._pausedLayer ? root._pausedSaturation : 0
        brightness: root._pausedLayer ? root._pausedBrightness : 0
        shadowEnabled: root._legibleShadow
        shadowColor: root._legibleShadowColor
        shadowOpacity: root._legibleShadowOpacity
        shadowBlur: 0.5
        blurMax: Math.max(8, Math.round(12 * root.scaleFactor))
        shadowVerticalOffset: root._inkIsLight ? 1 : 0
        shadowHorizontalOffset: 0
        autoPaddingEnabled: true
        
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
    grabCursor: GlobalStates.widgetEditMode
    function syncFreePositionFromConfig(): void {
        if (!Config.ready || root.containsPress || root._isResizing) return;
        if (root.placementStrategy !== "free") return;
        root.x = root.targetX;
        root.y = root.targetY;
    }

    onTargetXChanged: root.syncFreePositionFromConfig()
    onTargetYChanged: root.syncFreePositionFromConfig()

    function applyPlacementFromConfig(): void {
        if (!Config.ready || root.containsPress || root._isResizing) return;
        if (root._isZonePlacement) {
            root.snapToZone(root.placementStrategy);
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
    // Edit chrome keeps clear of the bar and the edit toolbar (the zone work area), even where a free
    // widget itself sits under them.
    readonly property real quickControlsAvailableWidth: Math.max(0,
        root._zoneSafeRight - root._zoneSafeLeft - 2 * root._editScreenMargin)
    readonly property real quickControlsAvailableHeight: Math.max(0,
        root._zoneSafeBottom - root._zoneSafeTop - editToolbar.height
            - root._editPopoverGap)
    readonly property bool quickControlsDense:
        root.quickControlsAvailableHeight < 760
    readonly property bool quickControlsWide: root.quickControlsDense
        && root.quickControlsAvailableWidth >= 480
    // The sheet is placed once and stays there. Its height is animated and its
    // pages differ in size, so resolving the side from the live height made the
    // toolbar and the sheet chase every content change and flip edges mid-frame.
    function _resolveEditControlsGeometry(widgetX: real, widgetY: real, popoverVisible: bool,
            latchedSide: string, reservedHeight: real, reservedWidth: real): var {
        const leftBound = root._zoneSafeLeft + root._editScreenMargin
        const topBound = root._zoneSafeTop + root._editScreenMargin
        const rightBound = root._zoneSafeRight - root._editScreenMargin
        const bottomBound = root._zoneSafeBottom - root._editScreenMargin
        const safeX = root._clampX(widgetX)
        const safeY = root._clampY(widgetY)
        const popoverHeight = popoverVisible
            ? Math.max(reservedHeight, editPopoverPanel.height) : 0
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
        const natural = useSide
            ? (fitsLeft && fitsRight
                ? (spaceRight >= spaceLeft ? "right" : "left")
                : fitsRight ? "right" : "left")
            : (fitsAbove ? "above" : fitsBelow ? "below"
                : spaceBelow > spaceAbove ? "below" : "above")
        const latchUsable = latchedSide.length > 0
            && (latchedSide === "above" ? spaceAbove >= stackHeight
                : latchedSide === "below" ? spaceBelow >= stackHeight
                : latchedSide === "left" ? spaceLeft >= editPopoverPanel.width
                : spaceRight >= editPopoverPanel.width)
        const side = latchUsable ? latchedSide : natural
        const below = side === "below"
        const sideways = side === "left" || side === "right"
        const toolbarMaxX = Math.max(leftBound, rightBound - editToolbar.width)
        const toolbarX = Math.max(leftBound, Math.min(toolbarMaxX,
            safeX + (root.width - editToolbar.width) / 2))
        // The toolbar hugs the widget whatever the sheet does; the sheet then
        // hangs off the toolbar, growing away from it.
        const toolbarTop = Math.max(topBound,
            Math.min(bottomBound - editToolbar.height,
                safeY - root._editToolbarGap - editToolbar.height))
        const toolbarBottom = Math.max(topBound,
            Math.min(bottomBound - editToolbar.height,
                safeY + root.height + root._editToolbarGap))
        const toolbarY = sideways
            ? (safeY - root._editToolbarGap - editToolbar.height >= topBound
                ? toolbarTop : toolbarBottom)
            : below ? toolbarBottom : toolbarTop
        let popoverX
        let popoverY
        if (sideways) {
            popoverX = side === "left"
                ? safeX - root._editToolbarGap - editPopoverPanel.width
                : safeX + root.width + root._editToolbarGap
            popoverY = Math.max(topBound, Math.min(
                bottomBound - editPopoverPanel.height,
                safeY + (root.height - editPopoverPanel.height) / 2))
        } else {
            const slotWidth = Math.max(reservedWidth, editPopoverPanel.width)
            const popoverMaxX = Math.max(leftBound, rightBound - slotWidth)
            popoverX = Math.max(leftBound, Math.min(popoverMaxX,
                toolbarX + (editToolbar.width - slotWidth) / 2))
            popoverY = below
                ? toolbarY + editToolbar.height + root._editPopoverGap
                : toolbarY - root._editPopoverGap - editPopoverPanel.height
            popoverY = Math.max(topBound,
                Math.min(bottomBound - editPopoverPanel.height, popoverY))
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
            naturalSide: natural,
            toolbarX: toolbarX,
            toolbarY: toolbarY,
            popoverX: popoverX,
            popoverY: popoverY,
            inBounds: toolbarInBounds && popoverInBounds
        };
    }

    // Latched while the sheet is open: the edge it grew from, and the tallest
    // page it has shown, so switching pages resizes the sheet without moving it.
    property string _editPlacementSide: ""
    // iRiS: the toolbar and the sheet step out while the widget is carried or resized and come back
    // where it lands, instead of chasing every frame of the gesture.
    readonly property bool _irisGesture: root.irisFaced
        && ((root.containsPress && root.dragMoved) || root._isResizing || root._irisSizing)
    on_IrisGestureChanged: {
        if (root._irisGesture || !editPopoverPanel.open) return
        root._editPlacementSide = ""
        root._popoverReserve = 0
        root._popoverReserveWidth = 0
        root._latchEditPlacement()
    }
    property real _popoverReserve: 0
    property real _popoverReserveWidth: 0
    function _latchEditPlacement(): void {
        const target = editPopoverPanel.targetHeight
        if (target <= 0)
            return
        root._popoverReserve = Math.max(root._popoverReserve, target)
        root._popoverReserveWidth = Math.max(root._popoverReserveWidth, editPopoverPanel.width)
        if (root._editPlacementSide.length === 0)
            root._editPlacementSide = root._editControlsGeometry.naturalSide
    }
    readonly property var _editControlsGeometry: root._resolveEditControlsGeometry(
        root.x, root.y, editPopoverPanel.open, root._editPlacementSide, root._popoverReserve,
        root._popoverReserveWidth)
    readonly property bool _editControlsBelow: root._editControlsGeometry.below

    function containsEditPoint(point: point): bool {
        const inRect = (x, y, width, height) => point.x >= x && point.y >= y
            && point.x < x + width && point.y < y + height
        if (inRect(-12, -12, root.width + 24, root.height + 24))
            return true
        if (!root._editControlsShown || editToolbar.hosted)
            return false
        // Hit testing follows the rendered rectangles, not the animation's
        // destination. Controls remain clickable while the widget reflows.
        return inRect(editToolbar.x, editToolbar.y, editToolbar.width, editToolbar.height)
            || (editPopoverPanel.open && inRect(editToolbar.x + editPopoverPanel.x,
                editToolbar.y + editPopoverPanel.y, editPopoverPanel.width, editPopoverPanel.height))
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
        canvas.promoteDesktopWidget(root.editInstanceKey, root.layerKey)
    }

    readonly property string editControlsGeometryReport: {
        const requestedX = root.debugLayoutProbeActive ? root.debugLayoutProbeX : root.x;
        const requestedY = root.debugLayoutProbeActive ? root.debugLayoutProbeY : root.y;
        const geometry = root._resolveEditControlsGeometry(
            requestedX, requestedY, editPopoverPanel.open,
            root._editPlacementSide, root._popoverReserve, root._popoverReserveWidth);
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
    // Locking keeps the sheet on the page that can unlock it.
    onLockedChanged: if (root.locked && editPopoverPanel.open) root._quickTab = root._arrangeTab
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
            if (GlobalStates.desktopWidgetQuickControls !== root.editInstanceKey || root._effectivePopover === null)
                return
            _editDisengageTimer.stop()
            if (root.locked)
                root._quickTab = root._arrangeTab
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
        visible: root.isDragging && root._snapEnabled && root.draggable
        x: root._snapPreviewX - root.x
        y: root._snapPreviewY - root.y
        width: root.width
        height: root.height
        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 1.5
        border.color: ColorUtils.applyAlpha(root.widgetIrisFamily ? IrisStyle.accent : Appearance.colors.colPrimary, 0.35)
        opacity: 0.7
    }

    // ── Edit engagement ──────────────────────────────────────
    // Heavy controls belong to the explicit selection, never to incidental
    // pointer travel. Hover only previews the outline/name; pressing promotes
    // that widget to the active editing layer.
    readonly property bool _editEngaged: GlobalStates.widgetEditMode
        && (root.editSelected || toolbarEditHover.hovered
            || root.containsPress || root.isDragging || root._isResizing
            || editPopoverPanel.open
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
        if (GlobalStates.widgetEditMode) {
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
            root.forceActiveFocus()
        }
    }

    Connections {
        target: GlobalStates
        function onDesktopWidgetNudge(dx: int, dy: int): void { if (root.editSelected && root.visible) root.nudge(dx, dy) }
    }

    Keys.onPressed: event => {
        if (!root.editSelected || event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const step = event.modifiers & Qt.ShiftModifier ? 10 : 1
        if (event.key === Qt.Key_Escape) {
            if (editPopoverPanel.open) editPopoverPanel.open = false
            else GlobalStates.clearDesktopWidgetSelection()
        } else if (event.key === Qt.Key_Left) root.nudge(-step, 0)
        else if (event.key === Qt.Key_Right) root.nudge(step, 0)
        else if (event.key === Qt.Key_Up) root.nudge(0, -step)
        else if (event.key === Qt.Key_Down) root.nudge(0, step)
        else return
        event.accepted = true
    }

    // Locked widgets intentionally disable AbstractWidget's drag MouseArea.
    // Keep selection available through a separate tap handler so locking a
    // widget never makes it unreachable from the desktop editor.
    TapHandler {
        enabled: GlobalStates.widgetEditMode && root.locked
        acceptedButtons: Qt.LeftButton
        onTapped: {
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
            root.forceActiveFocus()
        }
    }

    TapHandler {
        enabled: GlobalStates.widgetEditMode
        acceptedButtons: Qt.RightButton
        onTapped: {
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
            root.openQuickControls(root._arrangeTab)
        }
    }

    // ── Edit mode toolbar (proper Material action bar) ─────────
    // Toolbar is in screen-pixel space (no Item.scale on widget)
    readonly property Item _chromeHost: root.parent?.parent?.editChromeLayer ?? null
    Item {
        id: editToolbar
        parent: root._chromeHost ?? root
        readonly property bool hosted: editToolbar.parent !== root
        z: root.editSelected ? 2 : 1
        visible: opacity > 0
        opacity: GlobalStates.widgetEditMode && root._editControlsShown && !root._irisGesture ? 1 : 0
        enabled: GlobalStates.widgetEditMode && root._editControlsShown && !root._irisGesture

        HoverHandler {
            id: toolbarEditHover
            enabled: GlobalStates.widgetEditMode
        }
        x: root._editControlsGeometry.toolbarX - (editToolbar.hosted ? 0 : root.x)
        y: root._editControlsGeometry.toolbarY - (editToolbar.hosted ? 0 : root.y)
        width: Math.min(root.quickControlsAvailableWidth, toolbarRow.naturalWidth + 16)
        height: toolbarRow.implicitHeight + 16

        Behavior on x {
            enabled: Appearance.animationsEnabled && !root._irisGesture && editToolbar.opacity > 0
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }
        Behavior on y {
            enabled: Appearance.animationsEnabled && !root._irisGesture && editToolbar.opacity > 0
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
            transparent: root.widgetIrisFamily
            screenX: (editToolbar.hosted ? 0 : root.x) + editToolbar.x
            screenY: (editToolbar.hosted ? 0 : root.y) + editToolbar.y
        }
        Rectangle {
            anchors.fill: parent
            visible: root.widgetIrisFamily
            radius: height / 2
            color: IrisStyle.surface
            border.width: 1
            border.color: IrisStyle.hairlineStrong
        }

        Flow {
            id: toolbarRow
            anchors.centerIn: parent
            readonly property real naturalWidth: lockAction.implicitWidth + moreAction.implicitWidth + 4
                + (root.locked ? 0 : styleAction.implicitWidth + 4)
            width: Math.min(root.quickControlsAvailableWidth - 16, naturalWidth)
            spacing: 4

            WidgetEditAction {
                id: lockAction
                iconName: root.locked ? "lock" : "lock_open"
                label: root.locked ? Translation.tr("Unlock") : Translation.tr("Lock")
                compact: true
                toggled: root.locked
                onClicked: root._setOutputValue("locked", !root.locked)
            }
            WidgetEditAction {
                id: styleAction
                visible: !root.locked
                iconName: "tune"
                label: Translation.tr("Edit")
                compact: root.quickControlsAvailableWidth < 380
                toggled: editPopoverPanel.open && root._quickTab !== root._arrangeTab
                onClicked: {
                    if (toggled)
                        root.closeQuickControls()
                    else
                        root.openQuickControls("widget")
                }
            }
            WidgetEditAction {
                id: moreAction
                iconName: "more_horiz"
                label: Translation.tr("More actions")
                compact: true
                toggled: editPopoverPanel.open && root._quickTab === root._arrangeTab
                onClicked: {
                    if (toggled)
                        root.closeQuickControls()
                    else
                        root.openQuickControls(root._arrangeTab)
                }
            }
        }

        // Inline popover panel follows the toolbar to whichever side has room.
        Item {
            id: editPopoverPanel
            property bool open: false
            readonly property real targetHeight: popoverLoader.item ? popoverLoader.item.implicitHeight + 24 : 0
            // The sheet keeps the tallest page it has shown while open: switching pages or
            // toggling a row never resizes it back and forth.
            property real heldHeight: 0
            // iRiS fits each page: the tallest each has shown (so a toggle never shrinks its own page), and the
            // sheet grows or shrinks to the page in view on the move curve, away from the toolbar.
            property var pageHeights: ({})
            readonly property real pageHeight: Math.max(editPopoverPanel.targetHeight,
                editPopoverPanel.pageHeights[root._quickTab] ?? 0)
            property bool settled: false
            Timer { id: sheetSettle; interval: 240; onTriggered: editPopoverPanel.settled = true }
            onOpenChanged: {
                if (open) {
                    editPopoverPanel.heldHeight = editPopoverPanel.targetHeight
                    editPopoverPanel.pageHeights = ({})
                    editPopoverPanel.settled = false
                    sheetSettle.restart()
                    root._latchEditPlacement()
                } else {
                    editPopoverPanel.settled = false
                    editPopoverPanel.heldHeight = 0
                    root._editPlacementSide = ""
                    root._popoverReserve = 0
                    root._popoverReserveWidth = 0
                }
                if (!open && GlobalStates.desktopWidgetQuickControls === root.editInstanceKey)
                    GlobalStates.desktopWidgetQuickControls = ""
            }
            onTargetHeightChanged: if (open) {
                editPopoverPanel.heldHeight = Math.max(editPopoverPanel.heldHeight, editPopoverPanel.targetHeight)
                const seen = Object.assign({}, editPopoverPanel.pageHeights)
                seen[root._quickTab] = Math.max(seen[root._quickTab] ?? 0, editPopoverPanel.targetHeight)
                editPopoverPanel.pageHeights = seen
                root._latchEditPlacement()
            }
            onWidthChanged: if (open) root._latchEditPlacement()
            visible: opacity > 0
            enabled: open && !root._irisGesture
            opacity: open && !root._irisGesture ? 1 : 0
            x: root._editControlsGeometry.popoverX - root._editControlsGeometry.toolbarX
            y: root._editControlsGeometry.popoverY - root._editControlsGeometry.toolbarY
            width: Math.min(root.quickControlsAvailableWidth,
                popoverLoader.item ? (popoverLoader.item.resolvedWidth ?? popoverLoader.item.implicitWidth) + 24 : 344)
            height: root.irisFaced ? editPopoverPanel.pageHeight
                : Math.max(editPopoverPanel.targetHeight, editPopoverPanel.heldHeight)
            clip: root.irisFaced

            Behavior on height {
                enabled: root.irisFaced && editPopoverPanel.settled && IrisStyle.motionEnabled
                NumberAnimation {
                    duration: IrisStyle.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: IrisStyle.moveCurve
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

            Rectangle {
                anchors.fill: parent
                visible: root.widgetIrisFamily
                radius: Math.round(18 * IrisStyle.density)
                color: IrisStyle.surface
                border.width: 1
                border.color: IrisStyle.hairlineStrong
            }
            PanelSurface {
                id: editPopoverSurface
                anchors.fill: parent
                visible: !root.widgetIrisFamily
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
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 12
                width: editPopoverPanel.width - 24
                sourceComponent: root._effectivePopover
                // `visible` is effective visibility and inherits the parent chain;
                // using it as Loader state can latch this popover unloaded forever.
                active: (editPopoverPanel.open || editPopoverPanel.opacity > 0)
                    && root._effectivePopover !== null
            }
        }
    }

    // ── Edit mode widget name label ─────────────────────────
    // The name sits on the side the toolbar leaves free; where that side runs into a screen edge or
    // the bar, it takes the other one unless the toolbar is there, and otherwise stays hidden.
    Row {
        id: editNameLabel
        readonly property bool toolbarAbove: root._editControlsShown && !root._editControlsBelow
        readonly property bool toolbarBelow: root._editControlsShown && root._editControlsBelow
        readonly property bool roomBelow: root.y + root.height + 6 + height <= root._zoneSafeBottom
        readonly property bool roomAbove: root.y - 6 - height >= root._zoneSafeTop
        readonly property string side: !editNameLabel.toolbarBelow && editNameLabel.roomBelow ? "below"
            : !editNameLabel.toolbarAbove && editNameLabel.roomAbove ? "above" : ""
        z: 200
        visible: GlobalStates.widgetEditMode && (root.editSelected || widgetEditHover.hovered) && side.length > 0
        opacity: root.editSelected ? 1 : 0.78
        x: Math.round((root.width - width) / 2)
        y: editNameLabel.side === "above" ? -height - 6 : root.height + 6
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
            readonly property string name: root.configEntryName.split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase().trim()
            text: root.widgetIrisFamily ? name.charAt(0).toUpperCase() + name.slice(1) : name
            font.family: root.widgetIrisFamily ? IrisStyle.fontMain : Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: root.widgetIrisFamily ? Font.DemiBold : Font.Normal
            font.capitalization: root.widgetIrisFamily ? Font.MixedCase : Font.Capitalize
            color: root.widgetIrisFamily ? IrisStyle.text : Appearance.colors.colOnLayer0
            style: root.widgetIrisFamily ? Text.Raised : Text.Normal
            styleColor: root.widgetIrisFamily ? IrisStyle.plateShadow : "transparent"
        }
    }

    // ── Edit mode selection outline ──────────────────────────
    Rectangle {
        z: 199
        anchors.fill: parent
        anchors.margins: -4
        visible: GlobalStates.widgetEditMode && (root.editSelected || widgetEditHover.hovered)
        color: "transparent"
        radius: root.widgetIris ? Math.round(root.widgetCardRadius * root.scaleFactor) + 4 : Appearance.rounding.small + 4
        border {
            width: root.editSelected || root.locked ? 2 : 1
            color: ColorUtils.applyAlpha(root.locked
                    ? (root.widgetIrisFamily ? IrisStyle.danger : Appearance.colors.colError)
                    : (root.widgetIrisFamily ? IrisStyle.accent : Appearance.colors.colPrimary),
                root.locked ? (root.editSelected ? 0.86 : 0.42)
                    : root.editSelected ? 0.88 : widgetEditHover.hovered ? 0.62 : 0.26)
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    // ── Edit mode resize handles ─────────────────────────────
    readonly property bool _hasResize: !root.irisFaced && Object.keys(root.resizableAxes).length > 0
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
        radius: root.widgetIrisFamily ? 6 : 4
        color: root.widgetIrisFamily ? IrisStyle.accent : Appearance.colors.colPrimary
        border { width: 1; color: root.widgetIrisFamily ? IrisStyle.surface : ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.3) }
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
                // Axis dimensions are logical pixels. Start from the rendered
                // frame, including a presentation's minimum, not a smaller saved
                // card size. Merely switching style must not rewrite that size.
                if (axes.width)
                    vals.width = root.width / root.scaleFactor;
                if (axes.height)
                    vals.height = root.height / root.scaleFactor;
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
                    const widthRatio = rh._startWidth > 0 ? newW / rh._startWidth : 1
                    const heightRatio = rh._startHeight > 0 ? newH / rh._startHeight : 1
                    const ratio = Math.abs(widthRatio - 1) >= Math.abs(heightRatio - 1)
                        ? widthRatio : heightRatio
                    const value = Math.round(rh._startConfigVals.uniform * ratio)
                    preview[axes.uniform] = axes.uniform === "widgetScale"
                        ? Math.max(50, Math.min(200, value)) : value
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
                    root.x = root._clampX(rh._startX + rh._startWidth - root.width)
                if (rh.resizeTop)
                    root.y = root._clampY(rh._startY + rh._startHeight - root.height)
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
                if (root._isZonePlacement)
                    root.snapToZone(root.placementStrategy)
                else if (root._isAutoPlacement)
                    root.refreshPlacementIfNeeded()
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

    IrisSizeGrip {
        z: 202
        widget: root
        visible: GlobalStates.widgetEditMode && root.irisFaced && root.irisSizeChoices.length > 1 && !root.locked
            && (root.editSelected || root._gripHover || root._irisSizing)
    }
    // The grip reads the hover a tick late: hiding it under the pointer re-delivers hover at once and
    // re-entered its own visibility (a binding loop while editing).
    property bool _gripHover: false
    Timer { id: gripHoverSettle; interval: 0; onTriggered: root._gripHover = widgetEditHover.hovered }
    Connections {
        target: root.irisFaced ? widgetEditHover : null
        function onHoveredChanged(): void { gripHoverSettle.restart() }
    }

    function commitIrisSize(size: string): void {
        root._resizePreviewValues = ({})
        root._irisSizing = false
        if (size !== String(root._readConfigKey("iris.size") ?? ""))
            root.setIrisOption("size", size)
        _irisSizeSettle.restart()
    }
    Timer {
        id: _irisSizeSettle
        interval: IrisStyle.morphDuration + 40
        onTriggered: {
            if (root._isZonePlacement)
                root.snapToZone(root.placementStrategy)
            else if (root.placementStrategy === "free"
                    && (Math.round(root._clampX(root.x)) !== Math.round(root.x) || Math.round(root._clampY(root.y)) !== Math.round(root.y)))
                root._setOutputValues({ x: Math.round(root._clampX(root.x)), y: Math.round(root._clampY(root.y)) })
        }
    }

    // Carrying one widget over another lights the other as a drop target; letting go stacks them.
    readonly property bool stackable: root.irisFaced && DesktopWidgetStacks.live && !root.locked
        && !root.outputName.startsWith("lock:")
    readonly property var _canvas: root.parent?.parent ?? null
    readonly property bool stackDropHint: root._canvas !== null && root._canvas.stackHint === root.editInstanceKey
    property string _dropKey: ""
    // 0 at rest, 1 once the widget has glided into the stack it was dropped on.
    property real absorb: 0

    function _probeStackDrop(): void {
        const canvas = root._canvas
        if (!canvas || typeof canvas.stackDropCandidate !== "function")
            return
        const key = root.isDragging && root.stackable ? canvas.stackDropCandidate(root.editInstanceKey) : ""
        if (key === root._dropKey)
            return
        root._dropKey = key
        canvas.stackHint = key
    }
    function _clearStackDrop(): void {
        root._dropKey = ""
        if (root._canvas && root._canvas.stackHint !== undefined)
            root._canvas.stackHint = ""
    }
    Connections {
        target: root
        function onXChanged(): void { if (root.isDragging) root._probeStackDrop() }
        function onYChanged(): void { if (root.isDragging) root._probeStackDrop() }
    }

    // The dropped widget glides onto the target's place and dissolves into it, then joins.
    function _absorb(): void {
        const target = root._canvas?.loadedWidget(root._dropKey) ?? null
        if (!target) {
            root._clearStackDrop()
            return
        }
        stackAbsorb.targetKey = target.configEntryName
        stackAbsorb.toX = Math.round(target.x + (target.width - root.width) / 2)
        stackAbsorb.toY = Math.round(target.y + (target.height - root.height) / 2)
        if (root.animationsActive) {
            stackAbsorb.restart()
        } else {
            root._joinStack(stackAbsorb.targetKey)
        }
    }
    function _joinStack(targetName: string): void {
        const id = DesktopWidgetStacks.merge(targetName, root.configEntryName)
        root._clearStackDrop()
        root.absorb = 0
        // Joined, this widget stands where its stack does; refused, where it stood.
        root.x = root.targetX
        root.y = root.targetY
        if (id.length > 0)
            stackLand.restart()
    }
    ParallelAnimation {
        id: stackAbsorb
        property string targetKey: ""
        property real toX: 0
        property real toY: 0
        NumberAnimation { target: root; property: "x"; to: stackAbsorb.toX; duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
        NumberAnimation { target: root; property: "y"; to: stackAbsorb.toY; duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
        NumberAnimation { target: root; property: "absorb"; from: 0; to: 1; duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
        onFinished: root._joinStack(stackAbsorb.targetKey)
    }
    // Once it has joined, the stack turns to it, so the drop is seen to have landed.
    Timer {
        id: stackLand
        interval: 260
        onTriggered: {
            const id = DesktopWidgetStacks.memberMap[root.configEntryName]
            if (id !== undefined)
                DesktopWidgetStacks.show(root.outputName, id, root.configEntryName)
        }
    }

    // The page shown changes: the one leaving slides out, the one arriving slides in from the side it
    // was turned from. Forming or dissolving a stack never animates.
    property string _stackMemo: ""
    function _stackKey(): string {
        return root.stack === null ? "" : root.stack.id + (root.stack.shown ? "+" : "-")
    }
    onStackChanged: {
        const memo = root._stackKey()
        if (memo === root._stackMemo)
            return
        const before = root._stackMemo
        root._stackMemo = memo
        const turned = before.length > 0 && memo.length > 0 && before.slice(0, -1) === memo.slice(0, -1)
        if (!turned || !root.animationsActive || !root.irisFaced || !root.visible && memo.endsWith("-")) {
            stackSlide.stop()
            root.stackPos = 0
            return
        }
        const arriving = memo.endsWith("+")
        stackSlide.stop()
        root.stackPos = arriving ? root.stack.dir : 0
        stackSlide.to = arriving ? 0 : -root.stack.dir
        stackSlide.restart()
        // Arranging: the page that comes up is the one being arranged.
        if (arriving && GlobalStates.widgetEditMode
                && DesktopWidgetStacks.memberMap[String(GlobalStates.selectedDesktopWidget).split("::")[1]] === root.stack.id)
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
    }
    NumberAnimation {
        id: stackSlide
        target: root
        property: "stackPos"
        duration: IrisStyle.moveDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: IrisStyle.moveCurve
    }

    ShellEditSizeBadge {
        z: 203
        anchors.centerIn: parent
        active: root._isResizing
        valueText: Math.round(root.width) + " × " + Math.round(root.height) + " px"
        accentColor: root.widgetIrisFamily ? IrisStyle.accent : Appearance.colors.colPrimary
        surfaceColor: root.widgetIrisFamily ? IrisStyle.surface : Appearance.colors.colLayer2
        textColor: root.widgetIrisFamily ? IrisStyle.text : Appearance.colors.colOnLayer2
        fontFamily: root.widgetIrisFamily ? IrisStyle.fontNumbers : Appearance.font.family.main
        fontPixelSize: Appearance.font.pixelSize.smaller
    }

    onCanceled: root._clearStackDrop()
    onReleased: {
        if (GlobalStates.screenLocked || !root.dragMoved) return;
        if (root._dropKey.length > 0) {
            root._absorb()
            return
        }
        let newX = root.x;
        let newY = root.y;

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
    property string _quickTab: "widget"
    readonly property string identityGlyph: DesktopWidgetIdentity.glyph(root.configEntryName)
    readonly property color identityTint: root.widgetIrisFamily ? IrisStyle.identityOf(DesktopWidgetIdentity.tint(root.configEntryName))
        : DesktopWidgetIdentity.tint(root.configEntryName)
    // The page that holds position, lock and removal: "arrange" in an iRiS face's sheet, "layout" otherwise.
    readonly property string _arrangeTab: root.irisFaced ? "arrange" : "layout"
    readonly property Component _effectivePopover: root.irisFaced ? _irisPopoverRef : root._semanticPalettePopover

    function openQuickControls(tab: string): void {
        root._quickTab = tab
        _closeQuickControlsLater.stop()
        _editDisengageTimer.stop()
        root._editControlsShown = true
        editPopoverPanel.open = true
    }
    // Closed a tick later: the close button lives in the sheet, and unloading the sheet inside that
    // button's own click (no fade without animations) loses the next click.
    function closeQuickControls(): void {
        _closeQuickControlsLater.restart()
    }
    Timer {
        id: _closeQuickControlsLater
        interval: 0
        onTriggered: editPopoverPanel.open = false
    }

    Component {
        id: _irisPopoverRef
        IrisWidgetControls { widget: root }
    }

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
            availableWidth: root.quickControlsAvailableWidth - 24
            availableHeight: root.quickControlsAvailableHeight - 24
            title: {
                const words = root.configEntryName.split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase().trim()
                return Translation.tr(words.charAt(0).toUpperCase() + words.slice(1))
            }
            glyph: root.identityGlyph
            tint: root.identityTint
            regularWidth: Math.max(Math.round(340 * semanticQuickRoot.d),
                specificQuickLoader.item?.implicitWidth ?? 0)
            onCloseRequested: root.closeQuickControls()

            readonly property var pages: [
                { value: "widget", label: Translation.tr("Widget"), visible: root._widgetSpecificPopover !== null && !root.locked },
                { value: "colors", label: Translation.tr("Look"), visible: (root.semanticPaletteQuickControls
                    || (root.widgetIrisFamily && root.irisFace !== null)) && !root.locked },
                { value: "layout", label: Translation.tr("Arrange") }
            ]
            readonly property string page: {
                const open = semanticQuickRoot.pages.filter(entry => entry.visible !== false).map(entry => entry.value)
                return open.includes(root._quickTab) ? root._quickTab : open[0]
            }

            WidgetQuickChoices {
                visible: !root.widgetIrisFamily && semanticQuickRoot.pages.filter(entry => entry.visible !== false).length > 1
                maxColumns: 3
                current: semanticQuickRoot.page
                model: semanticQuickRoot.pages
                onPicked: value => root._quickTab = value
            }
            IrisSegmented {
                visible: root.widgetIrisFamily && semanticQuickRoot.pages.filter(entry => entry.visible !== false).length > 1
                Layout.fillWidth: true
                options: semanticQuickRoot.pages.filter(entry => entry.visible !== false)
                current: semanticQuickRoot.page
                accessibleName: Translation.tr("Quick controls")
                onPicked: value => root._quickTab = value
            }

            Loader {
                id: specificQuickLoader
                active: root._widgetSpecificPopover !== null && semanticQuickRoot.page === "widget"
                visible: active
                sourceComponent: root._widgetSpecificPopover
                Layout.fillWidth: true
                Layout.preferredHeight: item?.implicitHeight ?? 0
            }

            ColumnLayout {
                visible: semanticQuickRoot.page === "colors"
                Layout.fillWidth: true
                spacing: Math.round(14 * semanticQuickRoot.d)

                WidgetQuickSection {
                    visible: root.designChoices.length > 1
                    title: Translation.tr("Design")
                    detail: root.widgetDesignShared ? Translation.tr("Same as every widget") : Translation.tr("This widget only")
                    WidgetQuickChoices {
                        current: root.widgetDesign
                        model: root.designChoices
                        onPicked: value => root.pickDesign(value)
                    }
                    WidgetEditAction {
                        visible: root.widgetDesignMatchable
                        Layout.fillWidth: true
                        iconName: "select_all"
                        label: Translation.tr("Use on every widget")
                        onClicked: root.useDesignEverywhere()
                    }
                }

                WidgetQuickSection {
                    visible: root.semanticPaletteQuickControls
                    title: Translation.tr("Colors")
                    detail: root.widgetPalettePresetLabel

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 4
                        rowSpacing: 4

                        Repeater {
                            model: root.widgetPalettePresets

                            delegate: WidgetQuickChoice {
                                id: palettePresetButton
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.maximumWidth: Number.POSITIVE_INFINITY
                                label: modelData.label
                                selected: root.widgetPalettePreset === modelData.value
                                sidePadding: Math.round(12 * semanticQuickRoot.d) + swatches.width + 6
                                onClicked: root.applyWidgetPalettePreset(modelData.value)

                                Row {
                                    id: swatches
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.round(10 * semanticQuickRoot.d)
                                    anchors.verticalCenter: parent.verticalCenter
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
                            }
                        }
                    }
                }
            }

            WidgetPlacementControls {
                visible: semanticQuickRoot.page === "layout"
                Layout.fillWidth: true
                widget: root
                wide: semanticQuickRoot.wideDense
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
    readonly property var _designResolved: DesktopWidgetDesign.resolve(root.configEntryName,
        String(root._storedConfigKey("iris.design") ?? "auto"), String(root._storedConfigKey("design") ?? "auto"),
        root.irisFace !== null)
    readonly property string widgetSharedDesign: root._designResolved.design
    readonly property var widgetDesignValues: DesktopWidgetDesign.values(root.configEntryName, root.widgetSharedDesign)
    function _readConfigKey(key: string): var {
        if (Object.prototype.hasOwnProperty.call(root.widgetDesignValues, key))
            return root.widgetDesignValues[key]
        return root._storedConfigKey(key)
    }
    function _storedConfigKey(key: string): var {
        if ((root._isResizing || root._irisSizing || root._irisPreviewing)
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
        Qt.callLater(() => root._geometryReady = true)
        root._applyBackdropSample()
        _seedDefaultsIfNeeded();
        root._syncPlacementStrategy();
        _placementLater.restart();
        if (!root.outputName.startsWith("lock:"))
            DesktopWidgetStacks.report(root.configEntryName, root.irisSizes, root.irisDefaultSize, root.irisFace !== null)
        root._stackMemo = root._stackKey()
    }
    function resetToDefaults(): void {
        const updates = {};
        for (const key in root.defaultConfig) {
            // Reset the selected instance, not its siblings on other outputs.
            // Keep the lifecycle and lock controls intact.
            if (key !== "enable" && key !== "locked")
                updates[key] = root.defaultConfig[key];
        }
        updates["palette.primary"] = "primary"
        updates["palette.secondary"] = "secondary"
        updates["palette.tertiary"] = "tertiary"
        updates["palette.signal"] = "signal"
        updates["palette.surface"] = "surface"
        if (root.widgetIrisFamily && root.irisFace !== null) {
            updates["iris.size"] = root.irisDefaultSize
            updates["iris.material"] = "auto"
            updates["iris.design"] = "auto"
            updates["iris.opacity"] = -1
        }
        root._setOutputValues(updates);
        syncFreePositionFromConfig();
        refreshPlacementIfNeeded();
    }

    property bool needsColText: false
    readonly property bool _regionSampling: (root.needsColText && (root.positionColorAdaptationEnabled
        || (root.widgetIrisFamily && !root.widgetHasSurface))) || root.irisReadsRegion
    readonly property bool positionColorAdaptationEnabled: Boolean(root.widgetIrisFamily
        ? Config.getNestedValue("iris.widgets.brightWallpapers", false)
        : Config.getNestedValue("background.widgets.adaptColorsToWallpaperPosition", true))
    property color dominantColor: Appearance.colors.colPrimary
    // Wallpaper region brightness (0-1, gamma-encoded luma). -1 = not yet analyzed.
    property real regionBrightness: -1
    readonly property bool _hasBrightness: regionBrightness >= 0
    // How uneven the region is (luma std-dev, 0-1): textured regions need legibility for their
    // brightest parts, not their mean.
    property real regionBrightnessSpread: 0
    // Relative luminance of the region's mean colour, -1 until analyzed.
    property real regionLuminance: -1

    // The reading comes from WallpaperLuma's grid of the wallpaper this output shows, summed under
    // the widget's own rect: instant, so it follows the widget live while it is dragged.
    readonly property string _wallpaperOutput: root.outputName.replace(/^lock:/, "")
    readonly property string _lumaPath: Lume.wallpaperOf(root._wallpaperOutput)
    readonly property var _backdropSample: {
        void Lume.revision
        if (!root._regionSampling || root._lumaPath.length === 0)
            return null
        return Lume.read(root._wallpaperOutput, root.x, root.y, root.width, root.height)
    }
    on_BackdropSampleChanged: root._applyBackdropSample()

    // Ink polarity: dark ink once the region is clearly light, light ink once it is clearly dark.
    // The gap between each pair of thresholds keeps a widget dragged along a boundary from flickering.
    // Bare ink turns over at a mid tone; glass carries a veil that keeps light ink legible further up,
    // so it turns only where that veil would have to hide the glass.
    readonly property real _lightEnter: 0.30
    readonly property real _lightLeave: 0.21
    readonly property real _brightEnter: 0.46
    readonly property real _brightLeave: 0.36
    property bool backdropIsLight: false
    property bool backdropIsBright: false
    function _applyBackdropSample(): void {
        const sample = root._backdropSample
        if (!sample) {
            if (!root._regionSampling) {
                root.regionBrightness = -1
                root.regionBrightnessSpread = 0
                root.regionLuminance = -1
                root.backdropIsLight = false
                root.backdropIsBright = false
            }
            return
        }
        root.regionBrightness = sample.level
        root.regionBrightnessSpread = sample.spread
        const lum = sample.luminance
        const light = Lume.lightAfter(lum, root.backdropIsLight, root._lightEnter, root._lightLeave)
        // The colour other choices are measured against moves only on a visible change, so the
        // accent picked from it does not hop while the widget slides over similar pixels.
        if (root.regionLuminance < 0 || light !== root.backdropIsLight
                || Math.abs(lum - root.regionLuminance) > 0.05)
            root.dominantColor = sample.color
        root.regionLuminance = lum
        root.backdropIsLight = light
        root.backdropIsBright = Lume.lightAfter(lum, root.backdropIsBright, root._brightEnter, root._brightLeave)
    }

    readonly property color _regionBg: root._hasBrightness ? root.dominantColor : Appearance.colors.colLayer0
    // Ink is chosen by the backdrop, never by the shell's mode: iRiS speaks its own light and dark ink;
    // elsewhere the generated tone for each polarity, taken toward white or black while keeping its
    // hue, since light mode's inverse tone is a mid grey and dark mode's a mid grey the other way.
    readonly property color _inkLight: root.widgetIrisFamily ? IrisStyle.inkOnDark
        : Appearance.m3colors.darkmode ? Appearance.colors.colOnLayer0
        : ColorUtils.mix(Appearance.m3colors.m3inverseOnSurface, Qt.rgba(1, 1, 1, 1), 0.3)
    readonly property color _inkDark: root.widgetIrisFamily ? IrisStyle.inkOnLight
        : Appearance.m3colors.darkmode
        ? ColorUtils.mix(Appearance.m3colors.m3inverseOnSurface, Qt.rgba(0, 0, 0, 1), 0.55)
        : Appearance.colors.colOnLayer0
    readonly property bool forceLightInk: root.colorMode === "light"
    readonly property bool forceDarkInk: root.colorMode === "dark"
    // Dark ink on this widget's own backdrop: the wallpaper under it reads light.
    readonly property bool inkOnLight: root.forceDarkInk ? true : root.forceLightInk ? false
        : root._onBlurredLock ? false
        : root.positionColorAdaptationEnabled && root._hasBrightness && root.backdropIsLight
    // The same for content on glass (iRiS faces).
    readonly property bool glassInkOnLight: root.forceDarkInk ? true : root.forceLightInk ? false
        : root._onBlurredLock ? false
        : root.positionColorAdaptationEnabled && root._hasBrightness && root.backdropIsBright
    readonly property bool _onBlurredLock: GlobalStates.screenLocked && (Config.options?.lock?.blur?.enable ?? false)
    // With the wallpaper unread, iRiS keeps its light ink (the contract of *On bright wallpapers*
    // off); the shell's light mode says nothing about the wallpaper under a plate-less widget.
    readonly property bool _unreadIsLight: !root.widgetIrisFamily && !Appearance.m3colors.darkmode
    property color colText: {
        if (root.forceLightInk) return root._inkLight
        if (root.forceDarkInk) return root._inkDark
        if (root._onBlurredLock || !root.positionColorAdaptationEnabled)
            return root.widgetIrisFamily ? root._inkLight : Appearance.colors.colOnLayer0
        return root.inkOnLight ? root._inkDark : root._inkLight
    }
    Behavior on colText {
        enabled: root.animationsActive
        ColorAnimation { duration: root.widgetIris ? IrisStyle.revealDuration : Appearance.animation.elementMoveFast.duration }
    }

    // ── Centralized desktop-widget semantic palette ──────────────────────────
    // Every built-in widget selects from the palette already generated by the
    // wallpaper/theme. Local region analysis may choose WHICH generated token is
    // readable, but never synthesizes a new hue/lightness variant.
    readonly property string widgetPrimaryRole: String(root._readConfigKey("palette.primary") ?? "primary")
    readonly property string widgetSecondaryRole: String(root._readConfigKey("palette.secondary") ?? "secondary")
    readonly property string widgetTertiaryRole: String(root._readConfigKey("palette.tertiary") ?? "tertiary")
    readonly property string widgetSignalRole: String(root._readConfigKey("palette.signal") ?? "signal")
    readonly property string widgetSurfaceRole: String(root._readConfigKey("palette.surface") ?? "surface")

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
        root._setOutputValues({
            "palette.primary": spec.primary,
            "palette.secondary": spec.secondary,
            "palette.tertiary": spec.tertiary,
            "palette.signal": spec.signal,
            "palette.surface": spec.surface
        });
    }

    // iRiS widgets keep the black Island material but can borrow the wallpaper:
    // its generated hues are lifted into a range that reads on black, and the
    // plate can carry a trace of the same hue. Greyscale seeds keep iRiS blue.
    readonly property var irisWidgetOptions: Config.options?.iris?.widgets ?? ({})
    readonly property bool irisRim: Boolean(root.irisWidgetOptions.rim ?? false)
    readonly property string irisOutline: {
        const value = String(root.irisWidgetOptions.outline ?? "auto")
        return ["auto", "always", "none"].includes(value) ? value : "auto"
    }
    readonly property real irisSurfaceOpacity: {
        const own = Number(root._readConfigKey("iris.opacity") ?? -1)
        const value = own >= 20 ? own : Number(root.irisWidgetOptions.opacity ?? 100)
        return Math.max(0, Math.min(100, Number.isFinite(value) ? value : 100)) / 100
    }
    readonly property string irisPaletteName: {
        const name = String(root.irisWidgetOptions.tint ?? "wallpaper")
        return IrisStyle.widgetPaletteNames.includes(name) ? name : "wallpaper"
    }
    readonly property bool irisWallpaperTint: root.irisPaletteName === "wallpaper"
    readonly property real irisVibrance: Math.max(0, Math.min(100, Number(root.irisWidgetOptions.vibrance ?? 85))) / 100
    readonly property var irisPalette: IrisStyle.widgetPalette(root.irisPaletteName, root.irisVibrance)
    readonly property color irisAccent: root.irisPalette[0]
    readonly property color irisAccent2: root.irisPalette[1]
    readonly property color irisAccent3: root.irisPalette[2]
    readonly property color irisTintedPlate: ColorUtils.mix(IrisStyle.surface, root.irisAccent, 0.82)
    readonly property color irisPlate: root.irisMaterial === "tinted" ? root.irisTintedPlate : IrisStyle.surface

    property Component irisFace: null
    property bool irisOnly: false
    readonly property var designChoices: {
        const list = []
        const family = Config.options?.panelFamily ?? "ii"
        if (family !== "iris" && family !== "ii") return list
        if (family === "iris" && root.irisFace !== null) list.push({ value: "iris", icon: "auto_awesome", label: Translation.tr("iRiS") })
        if (family === "ii" || !root.irisOnly) list.push({ value: "material", icon: "widgets", label: Translation.tr("Material") })
        if (DesktopWidgetDesign.supports(root.configEntryName)) {
            list.push({ value: "instrument", icon: "avg_pace", label: Translation.tr("iNstrument") })
            list.push({ value: "readout", icon: "view_agenda", label: Translation.tr("Readout") })
        }
        return list
    }
    readonly property string irisDesign: root._designResolved.face
        || (root.irisOnly && root.widgetSharedDesign === "individual") ? "iris" : "material"
    // The design this widget shows, as the global picker names it.
    readonly property string widgetDesign: root.irisDesign === "iris" ? "iris"
        : root.widgetSharedDesign === "individual" ? "material" : root.widgetSharedDesign
    readonly property bool widgetDesignShared: root.widgetDesign === DesktopWidgetDesign.current
    readonly property bool widgetDesignMatchable: !root.widgetDesignShared || DesktopWidgetDesign.exceptionCount > 0
    function useDesignEverywhere(): void { DesktopWidgetDesign.apply(root.widgetDesign) }
    function pickDesign(value: string): void {
        if (root.stacked)
            return
        if (!root.widgetIrisFamily) {
            root._setOutputValue("design", value === DesktopWidgetDesign.current ? "auto"
                : value === "material" ? "individual" : value)
            return
        }
        root._setOutputValue("iris.design", value === DesktopWidgetDesign.current ? "auto" : value)
    }
    property var irisSizes: ["small"]
    property string irisDefaultSize: root.irisSizes[0]
    property var irisOptions: []
    readonly property bool irisFaced: root.widgetIris && root.irisFace !== null
    readonly property var irisMaterials: ["glass", "clear", "solid", "tinted"]
    readonly property string irisMaterial: {
        const own = String(root._readConfigKey("iris.material") ?? "auto")
        const shared = String(root.irisWidgetOptions.material ?? "glass")
        return root.irisMaterials.includes(own) ? own : root.irisMaterials.includes(shared) ? shared : "glass"
    }
    readonly property bool irisReadsRegion: root.irisFaced && (root.irisMaterial === "glass" || root.irisMaterial === "clear")
    // A stack keeps the size classes all its pages have.
    readonly property var irisSizeChoices: root.stacked ? root.stack.sizes : root.irisSizes
    readonly property string irisSize: {
        const chosen = String(root._readConfigKey("iris.size") ?? "")
        if (!root.stacked)
            return root.irisSizes.includes(chosen) ? chosen : root.irisDefaultSize
        const choices = root.stack.sizes
        return choices.includes(chosen) ? chosen : choices.includes(root.stack.size) ? root.stack.size : choices[0]
    }
    readonly property real irisUnit: Math.round(170 * IrisStyle.density * root.scaleFactor)
    readonly property real irisGutter: Math.round(16 * IrisStyle.density * root.scaleFactor)
    readonly property real irisFaceWidth: root.irisSize === "small" ? root.irisUnit : root.irisUnit * 2 + root.irisGutter
    readonly property real irisFaceHeight: root.irisSize === "large" ? root.irisUnit * 2 + root.irisGutter : root.irisUnit
    readonly property var irisSizeLabels: ({ small: Translation.tr("Small"), medium: Translation.tr("Medium"), large: Translation.tr("Large") })
    function irisOption(key: string, fallback: var): var {
        const value = root._readConfigKey("iris." + key)
        return value === undefined || value === null ? fallback : value
    }
    function setIrisOption(key: string, value: var): void {
        root._setOutputValue("iris." + key, value)
    }
    // The sheet's own slider: not a gesture, so the sheet stays under the pointer that drags it.
    function previewIrisScale(percent: int): void {
        root.previewIrisValue("widgetScale", percent)
    }
    function previewIrisValue(key: string, value: var): void {
        const preview = ({})
        preview[key] = value
        root._resizePreviewValues = preview
        root._irisPreviewing = true
    }
    function commitIrisValue(key: string, value: var): void {
        root._setOutputValue(key, value)
        _irisPreviewSettle.restart()
    }
    Timer {
        id: _irisPreviewSettle
        interval: 140
        onTriggered: {
            root._resizePreviewValues = ({})
            root._irisPreviewing = false
        }
    }
    function commitIrisScale(percent: int): void {
        root.commitIrisValue("widgetScale", percent)
        _irisSizeSettle.restart()
    }

    readonly property Item irisFaceView: irisFaceLoader.item
    Loader {
        id: irisFaceLoader
        anchors.fill: parent
        active: root.irisFaced
        opacity: root.widgetOpacity * root.dimOpacity
        sourceComponent: root.irisFace
    }

    function widgetSemanticSet(role: string): var {
        if (root.widgetIris) {
            const lifted = role === "surface" ? IrisStyle.text
                : role === "signal" ? IrisStyle.danger
                : role === "success" ? IrisStyle.success
                : role === "warning" ? IrisStyle.secondaryAccent
                : role === "tertiary" ? root.irisAccent3
                : role === "secondary" ? root.irisAccent2 : root.irisAccent;
            const onLight = root.inkOnLight && !root.widgetHasSurface
            const sample = root.widgetHasSurface || root.regionBrightness < 0 ? null
                : { level: root.regionBrightness, spread: root.regionBrightnessSpread }
            const foreground = role === "surface" ? (onLight ? IrisStyle.inkOnLight : lifted)
                : sample ? IrisStyle.markOn(lifted, sample, onLight, 3)
                : onLight ? IrisStyle.deepAccent(lifted, IrisStyle.inkOnLight) : lifted;
            return { color: foreground, onColor: IrisStyle.surface,
                container: role === "surface" ? root.irisPlate : ColorUtils.mix(root.irisPlate, IrisStyle.text, 0.9),
                onContainer: IrisStyle.text };
        }
        // Bare Material widgets under iRiS (iNstrument, Readout) draw with the same three accents as the faces.
        // Their neutral is the ink itself and their states the Island's, never the Material scheme's
        // tones, which follow the shell's mode rather than the wallpaper. With adaptation off the
        // accents keep their hue and the Lume shadow holds them, instead of fading toward the ink.
        if (root.widgetIrisFamily && !root.widgetHasSurface) {
            const onLight = root.inkOnLight
            if (role === "surface")
                return { color: root.colText, onColor: onLight ? IrisStyle.inkOnDark : IrisStyle.inkOnLight,
                    container: ColorUtils.mix(IrisStyle.surface, root.colText, 0.9), onContainer: IrisStyle.text };
            const seed = role === "signal" ? IrisStyle.dangerOnMedia : role === "warning" ? IrisStyle.highlightOnMedia
                : role === "success" ? (IrisStyle.light ? Lume.mark(IrisStyle.success, 0.35, 0, false, 3) : IrisStyle.success)
                : role === "tertiary" ? root.irisAccent3 : role === "secondary" ? root.irisAccent2 : root.irisAccent
            const sample = root.regionBrightness < 0 || !root.positionColorAdaptationEnabled ? null
                : { level: root.regionBrightness, spread: root.regionBrightnessSpread }
            const shown = sample ? IrisStyle.markOn(seed, sample, onLight, 3)
                : onLight ? IrisStyle.deepAccent(seed, IrisStyle.inkOnLight) : seed
            return { color: shown, onColor: IrisStyle.onTintFor(seed),
                container: ColorUtils.mix(IrisStyle.surface, seed, 0.78), onContainer: IrisStyle.text };
        }
        const c = Appearance.colors;
        // Bare on a light region in a dark theme, an accent takes its container tone: the same
        // generated hue, deep enough to read on the wallpaper instead of the pastel meant for dark.
        const deep = root._accentsOnLight
        switch (role) {
        case "secondary":
            return { color: deep ? c.colSecondaryContainer : c.colSecondary, onColor: c.colOnSecondary,
                container: c.colSecondaryContainer, onContainer: c.colOnSecondaryContainer };
        case "tertiary":
            return { color: deep ? c.colTertiaryContainer : c.colTertiary, onColor: c.colOnTertiary,
                container: c.colTertiaryContainer, onContainer: c.colOnTertiaryContainer };
        case "warning":
            return { color: deep ? c.colWarningContainer : c.colWarning, onColor: c.colOnTertiary,
                container: c.colWarningContainer, onContainer: c.colOnWarningContainer };
        case "signal":
            return {
                color: deep ? c.colErrorContainer : Appearance.zzzEverywhere ? Appearance.zzz.signal
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
            return { color: deep ? c.colPrimaryContainer : c.colPrimary, onColor: c.colOnPrimary,
                container: c.colPrimaryContainer, onContainer: c.colOnPrimaryContainer };
        }
    }
    readonly property bool _accentsOnLight: root.inkOnLight && !root.widgetHasSurface
        && Appearance.m3colors.darkmode

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
    // Presentation owns whether the configured plate is actually rendered.
    // Borderless variants must sample wallpaper, even when the saved card is on.
    property bool widgetSurfaceEnabled: true
    readonly property bool widgetHasSurface: root.widgetSurfaceEnabled
        && (root.backgroundOpacity > 0 || root.effectiveBlur)
    readonly property bool regionIsBright: root.positionColorAdaptationEnabled && root._hasBrightness
        ? root.backdropIsLight : root._unreadIsLight

    // Surfaces use semantic containers directly. This removes the old HSL
    // wallpaper-region re-toning that could turn generated warm palettes muddy.
    readonly property color widgetPlateColor: root.widgetIris && root.forceDarkInk
        ? ColorUtils.mix(IrisStyle.text, IrisStyle.accent, 0.98)
        : root.widgetIris && root.forceLightInk ? IrisStyle.surface
        : root.widgetSemanticContainer(root.widgetSurfaceRole)
    readonly property bool widgetPlateIsDark: ColorUtils.relativeLuminance(root.widgetPlateColor) < 0.38
    readonly property color widgetSurfaceInk: root.forceLightInk ? root._inkLight
        : root.forceDarkInk ? root._inkDark
        : root.widgetSemanticOnContainer(root.widgetSurfaceRole)
    readonly property color widgetInk: root.widgetHasSurface ? root.widgetSurfaceInk : root.colText
    readonly property color widgetInkMuted: root.widgetEditorial && root.widgetHasSurface && !root.forceLightInk && !root.forceDarkInk
        ? ColorUtils.ensureReadable(ColorUtils.mix(root.widgetInk, root.widgetPlateColor, 0.72), root.widgetPlateColor, 4.5)
        : ColorUtils.applyAlpha(root.widgetInk, 0.66)
    readonly property color widgetInkSubtle: ColorUtils.applyAlpha(root.widgetInk, 0.58)
    readonly property bool widgetEditorial: !root.widgetIris && Appearance.editorialEverywhere
    // Family-owned type: iRiS widgets speak the Island's typeface; every other
    // family keeps the shell fonts it always used.
    readonly property string widgetBodyFamily: root.widgetIris ? IrisStyle.fontMain : Appearance.font.family.main
    readonly property string widgetNumbersFamily: root.widgetIrisFamily ? IrisStyle.fontNumbers : Appearance.font.family.numbers
    // Metadata labels: shouting caps are Material/Instrument grammar; iRiS uses
    // sentence case (first letter up, the rest as written by the locale).
    function widgetCase(text): string {
        const value = String(text ?? "")
        return root.widgetIris ? value.charAt(0).toUpperCase() + value.slice(1) : value.toUpperCase()
    }
    readonly property int widgetCapitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
    readonly property string widgetTitleFamily: root.widgetIris ? IrisStyle.fontMain : root.widgetEditorial
        ? Appearance.editorial.displayFamily : Appearance.font.family.main
    // iRiS display type: one chosen weight for titles and figures, with the
    // slight negative tracking large system numerals use.
    readonly property int widgetTitleWeight: root.widgetIris
        ? ({ light: Font.Light, regular: Font.Medium, bold: Font.Bold })[String(root.irisWidgetOptions.weight ?? "regular")] ?? Font.Medium
        : root.widgetEditorial ? Appearance.editorial.titleWeight : Font.DemiBold
    readonly property real widgetTitleTracking: root.widgetIris ? -0.4
        : root.widgetEditorial ? Appearance.editorial.titleTracking : 0
    readonly property real widgetTitleScale: root.widgetEditorial
        ? Appearance.editorial.titleScale : 1
    readonly property real widgetSpacingScale: root.widgetEditorial
        ? Appearance.editorial.spacing : 1
    readonly property int widgetLabelWeight: root.widgetEditorial ? Appearance.editorial.labelWeight : Font.Medium
    readonly property real widgetMetadataTracking: root.widgetEditorial ? Appearance.editorial.metadataTracking : 0
    readonly property real widgetControlRadius: root.widgetIris ? Math.round(12 * IrisStyle.density) : root.widgetEditorial ? Appearance.rounding.small : Appearance.rounding.normal
    readonly property real widgetCardRadius: root.widgetIris ? Math.round(Math.max(0, Math.min(40, Config.options?.iris?.widgets?.radius ?? 22)) * IrisStyle.density) : root.widgetEditorial ? Appearance.editorial.radius : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.cookieEverywhere ? Appearance.cookie.roundLarge
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal

    property color accentBackdrop: root.widgetHasSurface ? root.widgetPlateColor
        : root.positionColorAdaptationEnabled && root._hasBrightness ? root._regionBg
        : root.widgetIrisFamily ? root._inkDark : Appearance.colors.colLayer0

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

    // Legibility shadow behind plate-less text, scaled by how busy the region is. Light ink gets a
    // dark shadow; dark ink on a light region gets only a faint light lift over its darker patches,
    // since a dark shadow under dark text reads as a smear and a strong light one as a glow.
    readonly property bool legibleAlways: root.widgetIrisFamily && Boolean(root.irisWidgetOptions.legibleAlways ?? false)
    readonly property real _haloBusy: root.legibleAlways ? 1 : root.positionColorAdaptationEnabled
        ? Math.min(1, root.regionBrightnessSpread / 0.28) : 0
    // The same held by the whole bare widget (Lume's third step for content with no plate): a soft dark
    // shadow under light ink as the region's brightest part climbs toward the ink, a faint light lift
    // under dark ink over the region's darker patches. Off where the backdrop already holds the ink,
    // so a dark desktop pays for no layer, and in edit mode, where the layer would clip the outline.
    readonly property bool _inkIsLight: ColorUtils.relativeLuminance(root.colText) > 0.35
    readonly property real _legibleShadowOpacity: {
        if (!root._hasBrightness) return root.legibleAlways ? 0.6 : 0
        const busy = root.legibleAlways ? 0.24 : 0
        if (root._inkIsLight) {
            const worst = Math.min(1, root.regionBrightness + Math.max(busy, root.regionBrightnessSpread))
            return Math.max(root.legibleAlways ? 0.6 : 0, Math.min(0.9, (worst - 0.32) / 0.4 * 0.9))
        }
        const darkest = Math.max(0, root.regionBrightness - Math.max(busy, root.regionBrightnessSpread))
        return Math.max(0, Math.min(0.55, (0.62 - darkest) / 0.35 * 0.55))
    }
    readonly property color _legibleShadowColor: root._inkIsLight ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
    // iRiS only: Material widgets keep their own text halo and never carry a shadow under the whole body.
    readonly property bool _legibleShadow: root.widgetIrisFamily && root.needsColText && !root.widgetHasSurface && !root.irisFaced
        && !GlobalStates.widgetEditMode && root._legibleShadowOpacity > 0.06
    readonly property color colHalo: root.inkOnLight && !root.forceDarkInk
        ? Qt.rgba(1, 1, 1, 0.12 + 0.3 * root._haloBusy)
        : Qt.rgba(0, 0, 0, 0.35 + 0.45 * root._haloBusy)

    // Compatibility helper: accent identity is owned by MaterialThemeLoader, not by
    // the later wallpaper-region analysis.
    function ensureVisible(c: color): color {
        return c;
    }

    // Auto placement (quietest or busiest spot) still searches the whole wallpaper in a process.
    readonly property string wallpaperPath: root._lumaPath
    onWallpaperPathChanged: if (root.wallpaperPath.length > 0 && root._isAutoPlacement)
        _placementDebounce.restart()
    onIsDraggingChanged: {
        // A sheet that chases the widget across the screen re-decides its edge
        // on every frame of the drag. Moving the widget puts it away instead.
        if (root.isDragging && editPopoverPanel.open)
            root.closeQuickControls()
    }
    onPlacementStrategyChanged: _placementLater.restart()
    // Deferred placement dies with the widget: a Qt.callLater queued as a config write disables it
    // ran into a destroyed context.
    Timer {
        id: _placementLater
        interval: 0
        onTriggered: root.applyPlacementFromConfig()
    }
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
        onTriggered: {
            if (root._isZonePlacement && !root.containsPress && !root._isResizing && !root._irisSizing)
                root.snapToZone(root.placementStrategy)
        }
    }
    Timer {
        id: _geometryPlacementDebounce
        interval: 120; repeat: false
        onTriggered: {
            if (!Config.ready || root.containsPress || root._isResizing || root._irisSizing)
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
    function refreshPlacementIfNeeded() {
        if (!Config.ready || !root._isAutoPlacement) return;
        if (!root.wallpaperPath || root.wallpaperPath.length === 0) return;
        leastBusyRegionProc.running = false;
        leastBusyRegionProc.running = true;
    }

    Process {
        id: leastBusyRegionProc
        property int contentWidth: Math.max(1, Math.round(root.width / Math.max(root.wallpaperScale, 0.001)))
        property int contentHeight: Math.max(1, Math.round(root.height / Math.max(root.wallpaperScale, 0.001)))
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh")
            , "--screen-width", Math.round(root.scaledScreenWidth)
            , "--screen-height", Math.round(root.scaledScreenHeight)
            , "--width", contentWidth
            , "--height", contentHeight
            , "--horizontal-padding", root._analysisPadding
            , "--vertical-padding", root._analysisPadding
            , root.wallpaperPath
            , ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                if (output.length === 0 || !root._isAutoPlacement) return;
                try {
                    const parsedContent = JSON.parse(output);
                    root._autoPlaceX = root._clampX(parsedContent.center_x * root.wallpaperScale - root.width / 2);
                    root._autoPlaceY = root._clampY(parsedContent.center_y * root.wallpaperScale - root.height / 2);
                } catch (e) {
                    console.warn("[Widgets] Failed to parse placement output:", e);
                }
            }
        }
    }
}
