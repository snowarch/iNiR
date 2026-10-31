pragma ComponentBehavior: Bound

import QtQuick
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
    // The family's face, which one of its Designs (AIRISU) may draw its own way (`designFaceKey`); the other widget designs
    // keep drawing themselves under any Design.
    property string designFaceKey: ""
    // Wearing the family's own faces. A family with none (`wearsFamily` alone) still lays its plate under the base drawing.
    readonly property bool familyDesign: DesktopWidgetDesign.faceDesign.length > 0
        && (root._designResolved.face || (root.faceOnly && root.widgetSharedDesign === "individual"))
    readonly property bool wearsFamily: DesktopWidgetDesign.faceDesign.length === 0 || root.familyDesign
    // How this family's widgets read: colours, type, shapes (its part `widgetLook`).
    readonly property var look: DesktopWidgetLook.look
    // The Background it sits on; a host with no desktop behind it (the lock) sets these itself.
    property var desktop: null
    property int screenWidth: root.desktop?.screen?.width ?? 0
    property int screenHeight: root.desktop?.screen?.height ?? 0
    property int scaledScreenWidth: root.screenWidth
    property int scaledScreenHeight: root.screenHeight
    property real wallpaperScale: 1
    property string outputName: root.desktop?.screen?.name ?? ""
    readonly property string _configPath: "background.widgets." + root.configEntryName

    function _setOutputValues(values): void {
        if (!values || typeof values !== "object")
            return
        // A style picked on one widget while a design covers it makes that widget an exception.
        if (root.widgetSharedDesign !== "individual"
                && (values.style !== undefined || values.displayMode !== undefined))
            values = Object.assign({}, values, { [DesktopWidgetDesign.spec.key]: DesktopWidgetDesign.spec.plain })
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
    readonly property bool stackPresent: root.stackShown || (root.stackMoving && root.familyFaced)
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
    property bool _sizing: false
    property bool _previewing: false
    property var _resizePreviewValues: ({})
    readonly property real scaleFactor: root._baseScale * (root.fits ? root._fit : 1)
    property bool _geometryReady: false
    readonly property bool animateGeometry: root._geometryReady && root.animationsActive
        && !root._isResizing && !root.containsPress

    Behavior on implicitWidth {
        enabled: root.animateGeometry
        NumberAnimation { duration: FamilyStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.morphCurve }
    }
    Behavior on implicitHeight {
        enabled: root.animateGeometry
        NumberAnimation { duration: FamilyStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.morphCurve }
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
    readonly property bool blurAvailable: root.look.blurAvailable(root)
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
        Translate { x: root._chaosDX; y: root._chaosDY },
        Scale { xScale: root._shelfScale; yScale: root._shelfScale },
        Translate { x: root._shelfDX + root._glideX * root._glide; y: root._shelfDY + root._glideY * root._glide }
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
        * (root.familyFaced ? 1 : root.widgetOpacity * root.dimOpacity)
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
    readonly property bool animationsActive: FamilyStyle.motionEnabled && root.motionActive

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


    // Sheets keep clear of the bar and the edit toolbar (the zone work area), even where a free widget sits under them.
    readonly property real quickControlsAvailableWidth: Math.max(0, root._zoneSafeRight - root._zoneSafeLeft - 16)
    readonly property real quickControlsAvailableHeight: Math.max(0, root._zoneSafeBottom - root._zoneSafeTop - 64)

    function containsEditPoint(point: point): bool {
        return point.x >= -12 && point.y >= -12 && point.x < root.width + 12 && point.y < root.height + 12
    }

    function _bringToFront(): void {
        const canvas = root.parent?.parent ?? null
        if (!canvas || typeof canvas.promoteDesktopWidget !== "function")
            return
        canvas.promoteDesktopWidget(root.editInstanceKey, root.layerKey)
    }

    // Locking keeps the sheet on the page that can unlock it.
    onLockedChanged: if (root.locked && root.quickControlsOpen) root._quickTab = root._arrangeTab
    onEditSelectedChanged: if (!root.editSelected) root.quickControlsOpen = false

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void {
            if (!GlobalStates.widgetEditMode)
                root.quickControlsOpen = false
            _geometryPlacementDebounce.restart()
        }
        function onDesktopWidgetQuickControlsChanged(): void {
            if (GlobalStates.desktopWidgetQuickControls !== root.editInstanceKey)
                return
            if (root.locked)
                root._quickTab = root._arrangeTab
            root.quickControlsOpen = true
        }
    }

    // ── Arranging (DesktopArrange) ──────────────────────────────
    // Carried, the widget is pulled onto its neighbours' lines, the screen's centre and the grid as it moves (O(n) per
    // move); let go on top of another, it slides beside it. The grid switch only takes the lattice away; Alt carries it
    // freely. Stacking keeps its own drop. Every widget reports where it is while arranging, so a carried one knows its
    // neighbours without reading them.
    readonly property bool _arrangeFree: (root.dragModifiers & Qt.AltModifier) !== 0
    readonly property real _neighbourMagnet: 12
    readonly property bool _arranging: GlobalStates.widgetEditMode && root.configEntryName.length > 0
    readonly property string _stackId: root.stack?.id ?? ""
    function _report(): void {
        if (!root._arranging)
            return
        DesktopArrange.report(root.outputName, root.editInstanceKey, root.x, root.y, root.width, root.height,
            root.visible && root.opacity > 0.01 && !root._shelfMoving && !root._departure, root._stackId)
    }
    on_ArrangingChanged: root._report()
    property bool _snapping: false
    function _arrangeMoved(): void {
        if (!root._arranging)
            return
        if (root.isDragging && root._dropKey.length === 0 && !root._snapping) {
            root._snapping = true
            const p = DesktopArrange.snap(root.outputName, root.editInstanceKey, root.x, root.y, root.width, root.height,
                root._arrangeFree, root._stackId)
            if (p.x !== root.x) root.x = p.x
            if (p.y !== root.y) root.y = p.y
            root._snapping = false
        }
        root._report()
    }
    onXChanged: root._arrangeMoved()
    onYChanged: root._arrangeMoved()
    // Where a widget asked to go to x,y would rest (the IPC probe, a shelf drop without a plan).
    function _planDrop(x: real, y: real): var {
        const plan = DesktopArrange.plan(root.outputName, root.editInstanceKey, x, y, root.width, root.height, root._stackId)
        return { x: Math.round(root._clampX(plan.x)), y: Math.round(root._clampY(plan.y)), guides: plan.guides, neighbours: plan.neighbours }
    }

    // ── The shelf (a family that hosts arranging: DesktopEditStage) ──
    // The widget takes its own picture for the shelf when arranging starts and after it changes size (a grab per second
    // per widget stalled the whole mode); held or carried it keeps the last one. Done leaves it on disk.
    readonly property bool _picturing: GlobalStates.widgetEditMode && DesktopEditStage.hosted(root.outputName)
        && root.visible && root.width > 0 && root.height > 0 && root.configEntryName.length > 0
    property var _picture: null
    function _takePicture(): void {
        if (root._editEngaged || root.isDragging || root._isResizing || root._shelfMoving || !root.Window.window?.visible)
            return
        const w = Math.round(root.width)
        const h = Math.round(root.height)
        root.grabToImage(result => {
            root._picture = result
            // On disk at once: the shelf reads a file at the size it shows it, sharp; a grab's own url can't be.
            const path = DesktopEditStage.savedPicture(root.configEntryName)
            DesktopEditStage.setPicture(root.configEntryName, result.saveToFile(path)
                ? "file://" + path + "?" + (++root._pictureTakes) : result.url, w, h)
        }, Qt.size(w, h))
    }
    property int _pictureTakes: 0
    Timer {
        id: pictureTimer
        interval: 600
        running: root._picturing
        onTriggered: root._takePicture()
    }
    // Taken back to the shelf while arranging, the widget leaves its last look on disk and its live one goes with it.
    Component.onDestruction: {
        DesktopEditStage.inspect(root.outputName, root, false)
        DesktopEditStage.choose(root.outputName, root, false)
        DesktopEditStage.point(root.outputName, root, false)
        if (!root._picture)
            return
        root._picture.saveToFile(DesktopEditStage.savedPicture(root.configEntryName))
        DesktopEditStage.setPicture(root.configEntryName, "", 0, 0)
    }
    on_PicturingChanged: {
        if (root._picturing || !root._picture)
            return
        root._picture.saveToFile(DesktopEditStage.savedPicture(root.configEntryName))
        DesktopEditStage.setPicture(root.configEntryName, "", 0, 0)
        root._picture = null
    }

    // Taken from the shelf, the widget lands where it was dropped (or on a free spot) and grows out of its picture;
    // taken back, it shrinks into it. `_shelf` runs 0 (the picture) to 1 (the widget in place).
    property real _shelf: 1
    property rect _shelfRect: Qt.rect(0, 0, 0, 0)
    readonly property bool _shelfMoving: shelfGrow.running || shelfShrink.running
    on_ShelfMovingChanged: root._report()
    readonly property real _shelfK: root._shelfRect.width > 0 && root.width > 0 && root.height > 0
        ? Math.min(root._shelfRect.width / root.width, root._shelfRect.height / root.height) : 1
    readonly property real _shelfScale: 1 + (root._shelfK - 1) * (1 - root._shelf)
    readonly property real _shelfDX: root._shelfRect.width > 0
        ? (root._shelfRect.x + (root._shelfRect.width - root.width * root._shelfK) / 2 - root.x) * (1 - root._shelf) : 0
    readonly property real _shelfDY: root._shelfRect.width > 0
        ? (root._shelfRect.y + (root._shelfRect.height - root.height * root._shelfK) / 2 - root.y) * (1 - root._shelf) : 0
    // A rect in screen px (the shelf's) seen from the desktop, which is a card while arranging.
    function _fromScreen(rect: var): rect {
        const card = DesktopEditStage.cardFor(root.outputName, root.screenWidth, root.screenHeight)
        return Qt.rect((rect.x - card.x) / card.s, (rect.y - card.y) / card.s, rect.width / card.s, rect.height / card.s)
    }
    property var _landedArrival: null
    function _land(): void {
        const arrival = DesktopEditStage.arrival(root.outputName, root.configEntryName)
        if (!arrival || !root._geometryReady || arrival === root._landedArrival)
            return
        root._landedArrival = arrival
        // A turn later: dropped from inside the handler of `_arrival` it re-read itself (binding loop).
        Qt.callLater(DesktopEditStage.arrived, root.outputName, root.configEntryName)
        let spot = null
        if (arrival.at?.exact) {
            spot = { x: root._clampX(arrival.at.x), y: root._clampY(arrival.at.y) }
        } else if (arrival.at) {
            spot = root._planDrop(arrival.at.x - root.width / 2, arrival.at.y - root.height / 2)
        } else {
            spot = DesktopArrange.plan(root.outputName, root.editInstanceKey, root.x, root.y, root.width, root.height, root._stackId)
        }
        const wasX = root.x
        const wasY = root.y
        if (spot && (Math.abs(spot.x - root.x) > 0.5 || Math.abs(spot.y - root.y) > 0.5)) {
            root.x = spot.x
            root.y = spot.y
            root._setOutputValues({ x: spot.x, y: spot.y, placementStrategy: "free" })
        }
        if (arrival.glide) {
            if (spot && root.animationsActive) {
                root._glideX = wasX - root.x
                root._glideY = wasY - root.y
                root._glide = 1
                glideRun.restart()
            }
            return
        }
        if (!arrival.from || !root.animationsActive)
            return
        root._shelfRect = root._fromScreen(arrival.from)
        root._shelf = 0
        shelfGrow.restart()
    }
    readonly property var _arrival: DesktopEditStage.arrival(root.outputName, root.configEntryName)
    on_ArrivalChanged: root._land()
    on_GeometryReadyChanged: {
        root._land()
        if (root._geometryReady)
            newcomerSettle.restart()
    }
    // Brought out while the desktop is up (a switch in Settings, IPC) onto a place another widget took meanwhile, it
    // steps to the nearest free spot and the others stay. At start every widget keeps its place; from the shelf
    // `_land` places it.
    Timer {
        id: newcomerSettle
        interval: 400
        onTriggered: {
            const canvas = root._canvas
            if (!canvas?.settled || typeof canvas.freeSpot !== "function" || root.placementStrategy !== "free" || root.locked
                    || root.isDragging || DesktopEditStage.arrival(root.outputName, root.configEntryName) || root._landedArrival
                    || root.outputName.startsWith("lock:") || root.width <= 0 || root.height <= 0)
                return
            const spot = canvas.freeSpot(root.editInstanceKey, root.x, root.y, root.width, root.height)
            if (spot.moved)
                root._setOutputValues({ x: Math.round(spot.x), y: Math.round(spot.y), placementStrategy: "free" })
        }
    }
    readonly property var _departure: DesktopEditStage.departure(root.outputName, root.configEntryName)
    on_DepartureChanged: {
        if (!root._departure)
            return
        shelfGrow.stop()
        root._shelfRect = root._fromScreen(root._departure.to)
        shelfShrink.restart()
    }
    // Away from the shelf, or back into it from wherever the drop or the grid moved it.
    NumberAnimation {
        id: shelfGrow
        target: root
        property: "_shelf"
        to: 1
        duration: FamilyStyle.duration(380)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: FamilyStyle.morphCurve
    }
    NumberAnimation {
        id: shelfShrink
        target: root
        property: "_shelf"
        to: 0
        duration: DesktopEditStage.departDuration
        easing.type: Easing.InCubic
    }
    // One already out, pulled off the shelf again, slides from where it was to where it was dropped.
    property real _glide: 0
    property real _glideX: 0
    property real _glideY: 0
    NumberAnimation {
        id: glideRun
        target: root
        property: "_glide"
        to: 0
        duration: FamilyStyle.duration(420)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: FamilyStyle.morphCurve
    }
    // Taking a widget away while a shelf is out sends it into its picture there.
    function takeAway(): void {
        const tile = DesktopEditStage.tiles[root.configEntryName]
        if (tile && DesktopEditStage.hosted(root.outputName) && root.animationsActive)
            DesktopEditStage.depart(root.outputName, root.configEntryName, tile)
        else
            DesktopWidgetLayout.setGloballyEnabled(root.configEntryName, false)
    }

    // Heavy controls belong to the explicit selection, never to incidental pointer travel.
    readonly property bool _editEngaged: GlobalStates.widgetEditMode
        && (root.editSelected || root.containsPress || root.isDragging || root._isResizing || root.quickControlsOpen)
    onVisibleChanged: root._report()

    HoverHandler {
        id: widgetEditHover
        enabled: GlobalStates.widgetEditMode
    }
    readonly property bool editHovered: widgetEditHover.hovered
    // The family's edit desk draws this widget's controls at true size (DesktopEditStage.inspected).
    property bool quickControlsOpen: false
    onQuickControlsOpenChanged: if (!root.quickControlsOpen && GlobalStates.desktopWidgetQuickControls === root.editInstanceKey)
        GlobalStates.desktopWidgetQuickControls = ""
    readonly property bool _handsSheet: root.quickControlsOpen && GlobalStates.widgetEditMode
        && DesktopEditStage.hostsSheet(root.outputName)
    on_HandsSheetChanged: DesktopEditStage.inspect(root.outputName, root, root._handsSheet)
    // Its outfit too: chosen or under the pointer, the host draws it over the card where the card cannot clip it.
    readonly property bool _outfitHosted: root._outfitted && DesktopEditStage.hostsSheet(root.outputName)
    readonly property bool _chosenOut: root._outfitHosted && root.editSelected
    readonly property bool _pointedOut: root._outfitHosted && root.editHovered
    on_ChosenOutChanged: DesktopEditStage.choose(root.outputName, root, root._chosenOut)
    on_PointedOutChanged: DesktopEditStage.point(root.outputName, root, root._pointedOut)
    readonly property string quickTab: root._quickTab

    // What the widget wears while arranging: its family's part `widgetOutfit`.
    readonly property string _outfitPart: Plugins.part(Plugins.active, "widgetOutfit")
    readonly property bool _outfitted: GlobalStates.widgetEditMode && root._outfitPart.length > 0
    Loader {
        z: 200
        anchors.fill: parent
        active: root._outfitted
        source: root._outfitPart
        onLoaded: {
            item.widget = root
            if (item.hostedElsewhere !== undefined) item.hostedElsewhere = Qt.binding(() => root._outfitHosted)
        }
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
            if (root.quickControlsOpen) root.quickControlsOpen = false
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

    // With a shelf out, a right click puts the widget back on it (it shrinks into its picture); without one it opens
    // the widget's controls.
    TapHandler {
        enabled: GlobalStates.widgetEditMode
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (DesktopEditStage.hosted(root.outputName) && DesktopEditStage.tiles[root.configEntryName]) {
                if (GlobalStates.selectedDesktopWidget === root.editInstanceKey)
                    GlobalStates.clearDesktopWidgetSelection()
                root.takeAway()
                return
            }
            GlobalStates.selectDesktopWidget(root.editInstanceKey)
            root.openQuickControls(root._arrangeTab)
        }
    }

    FamilyPart {
        z: 202
        when: GlobalStates.widgetEditMode && root.sizeChoices.length > 1 && !root.locked
        part: "widget.sizeGrip"
        props: ({ widget: root, visible: root.editSelected || root._gripHover || root._sizing })
    }
    // The grip reads the hover a tick late: hiding it under the pointer re-delivers hover at once and
    // re-entered its own visibility (a binding loop while editing).
    property bool _gripHover: false
    Timer { id: gripHoverSettle; interval: 0; onTriggered: root._gripHover = widgetEditHover.hovered }
    Connections {
        target: root.sized ? widgetEditHover : null
        function onHoveredChanged(): void { gripHoverSettle.restart() }
    }

    Timer {
        id: _sizeSettle
        interval: FamilyStyle.morphDuration + 40
        onTriggered: {
            if (root._isZonePlacement)
                root.snapToZone(root.placementStrategy)
            root._makeRoom()
        }
    }
    // A widget that grew moves the neighbours it now covers aside; it runs once the new size has settled, and only while
    // the person arranges. Neither a settle nor a size arriving from another family writes a position: each family has
    // its own safe edges and sizes, and moving or clamping for one of them rewrote where the person put things in the
    // others (his 10-30: widgets out of place after a family switch). The drawn position is clamped, the stored one stays.
    function _makeRoom(): void {
        if (GlobalStates.widgetEditMode && root._canvas && typeof root._canvas.makeRoom === "function")
            root._canvas.makeRoom(root.editInstanceKey)
    }
    Timer {
        id: _makeRoomLater
        interval: 120
        onTriggered: root._makeRoom()
    }

    // Carrying one widget over another lights the other as a drop target; letting go stacks them.
    readonly property bool stackable: root.familyFaced && DesktopWidgetStacks.live && !root.locked
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
        NumberAnimation { target: root; property: "x"; to: stackAbsorb.toX; duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
        NumberAnimation { target: root; property: "y"; to: stackAbsorb.toY; duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
        NumberAnimation { target: root; property: "absorb"; from: 0; to: 1; duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
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
        if (!turned || !root.animationsActive || !root.familyFaced || !root.visible && memo.endsWith("-")) {
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
        duration: FamilyStyle.moveDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: FamilyStyle.moveCurve
    }

    ShellEditSizeBadge {
        z: 203
        anchors.centerIn: parent
        active: root._isResizing
        valueText: Math.round(root.width) + " × " + Math.round(root.height) + " px"
        accentColor: FamilyStyle.accent
        surfaceColor: FamilyStyle.surfaceHigh
        textColor: FamilyStyle.text
        fontFamily: FamilyStyle.fontNumbers
        fontPixelSize: Appearance.font.pixelSize.smaller
    }

    onCanceled: {
        root._clearStackDrop()
        if (root._arranging) DesktopArrange.cancel()
    }
    onReleased: {
        if (GlobalStates.screenLocked || !root.dragMoved) return;
        if (root._dropKey.length > 0) {
            root._absorb()
            return
        }
        const spot = DesktopArrange.end(root.outputName, root.editInstanceKey, root.x, root.y, root.width, root.height,
            root._arrangeFree, root._stackId)
        const finalX = root._clampX(spot.x)
        const finalY = root._clampY(spot.y)
        // Let go on top of another, it slides to where it rests instead of jumping.
        if (spot.moved && root.animationsActive) {
            root._glideX = root.x - finalX
            root._glideY = root.y - finalY
            root._glide = 1
            glideRun.restart()
        }
        root.x = finalX;
        root.y = finalY;
        const updates = { x: finalX, y: finalY }
        if (root.placementStrategy !== "free")
            updates.placementStrategy = "free"
        root._setOutputValues(updates)
    }

    // ── Quick controls ─────────────────────
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
    readonly property Component _widgetSpecificPopover: root.editPopoverContent ?? root._autoPopoverComponent
    readonly property bool hasOptionRows: DesktopWidgetOptions.widgetRows.some(spec => spec.widget === root.configEntryName && !spec.widgetEnable)
    property string _quickTab: "widget"
    readonly property string identityGlyph: DesktopWidgetRegistry.glyph(root.configEntryName)
    readonly property color identityTint: FamilyStyle.identityOf(DesktopWidgetRegistry.tint(root.configEntryName))
    // The page that holds position, lock and removal: "arrange" in an iRiS face's sheet, "layout" otherwise.
    readonly property string _arrangeTab: root.familyFaced ? "arrange" : "layout"

    function openQuickControls(tab: string): void {
        root._quickTab = tab
        _closeQuickControlsLater.stop()
        root.quickControlsOpen = true
    }
    // Closed a tick later: the close button lives in the sheet, and unloading the sheet inside that
    // button's own click (no fade without animations) loses the next click.
    function closeQuickControls(): void {
        _closeQuickControlsLater.restart()
    }
    Timer {
        id: _closeQuickControlsLater
        interval: 0
        onTriggered: root.quickControlsOpen = false
    }

    Component {
        id: _autoPopoverRef
        ManifestPopover {
            configEntryName: root.configEntryName
            manifestKeys: root._manifestKeyList
            readConfigKey: (key) => root._readConfigKey(key)
        }
    }

    readonly property Component sheetPages: Component {
        WidgetSheetPages { widget: root }
    }

    // People's own widgets from before size classes still set these (v2.33's example); nothing reads them.
    property var resizableAxes: ({})
    property int resizeMinWidth: 60
    property int resizeMinHeight: 40
    property int resizeMaxWidth: 1200
    property int resizeMaxHeight: 800

    // Read a possibly-nested key from configEntry (e.g. "cookie.size" → configEntry.cookie.size)
    readonly property var _designResolved: DesktopWidgetDesign.resolve(root.configEntryName,
        String(root._storedConfigKey(DesktopWidgetDesign.spec.key) ?? "auto"), root.hasFamilyFace)
    readonly property string widgetSharedDesign: root._designResolved.design
    readonly property var widgetDesignValues: DesktopWidgetDesign.values(root.configEntryName, root.widgetSharedDesign)
    function _readConfigKey(key: string): var {
        if (Object.prototype.hasOwnProperty.call(root.widgetDesignValues, key))
            return root.widgetDesignValues[key]
        return root._storedConfigKey(key)
    }
    function _storedConfigKey(key: string): var {
        if ((root._isResizing || root._sizing || root._previewing)
                && Object.prototype.hasOwnProperty.call(root._resizePreviewValues, key))
            return root._resizePreviewValues[key]
        return DesktopWidgetLayout.value(root.outputName, root.configEntryName,
            key, Config.getNestedValue(root._configPath + "." + key, undefined))
    }

    // The manifest's defaults; a person's own widget sets them itself.
    property var defaultConfig: DesktopWidgetRegistry.defaultsOf(root.configEntryName)
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
        root._shownSize = root.sizeClass
        if (!root.outputName.startsWith("lock:"))
            DesktopWidgetStacks.report(root.configEntryName, root.sizes, root.sizes[0] ?? "", root.hasFamilyFace)
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
        Object.assign(updates, { sizeClass: root.sizes[0] ?? "", freeWidth: 0, freeHeight: 0 })
        Object.assign(updates, root.look.resetValues(root))
        root._setOutputValues(updates);
        syncFreePositionFromConfig();
        refreshPlacementIfNeeded();
    }

    property bool needsColText: false
    // Text with no plate of its own always reads the wallpaper under it: legibility is the floor, not a setting
    // (his 10-30: light ink vanished on a white wallpaper with adaptation off). The switches keep their colours. A
    // widget with no plate reads it whether it asked or not: the image converter's captions took the scheme's ink and
    // went dark on a dark mountain in light mode.
    readonly property bool _regionSampling: root.needsColText || root.look.readsRegion(root) || (!root.widgetHasSurface && !root.familyFaced)
    readonly property bool positionColorAdaptationEnabled: root.look.adaptsToWallpaper
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
    // Dark ink out-reads light ink above a relative luminance of 0.18 (1.05 / (L + 0.05) = (L + 0.05) / 0.05): the pair
    // sits around it. At 0.30 a sunset sky (~0.25) kept light ink at 3:1 and its captions near 2:1 (10-30 gallery).
    readonly property real _lightEnter: 0.22
    readonly property real _lightLeave: 0.15
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
    // Ink is chosen by the backdrop, never by the shell's mode: the family says its light and dark ink.
    readonly property color _inkLight: root.look.inkLight
    readonly property color _inkDark: root.look.inkDark
    readonly property bool forceLightInk: root.colorMode === "light"
    readonly property bool forceDarkInk: root.colorMode === "dark"
    // Dark ink on this widget's own backdrop: the wallpaper under it reads light, unless the family keeps its scheme's.
    readonly property bool _schemeInk: root.look.schemeInk
    readonly property bool inkOnLight: root.forceDarkInk ? true : root.forceLightInk ? false
        : root._onBlurredLock ? false
        : root._schemeInk ? FamilyStyle.light
        : root._hasBrightness && root.backdropIsLight
    // The same for content on glass (iRiS faces).
    readonly property bool glassInkOnLight: root.forceDarkInk ? true : root.forceLightInk ? false
        : root._onBlurredLock ? false
        : root.positionColorAdaptationEnabled && root._hasBrightness && root.backdropIsBright
    readonly property bool _onBlurredLock: GlobalStates.screenLocked && (Config.family?.lock?.blur?.enable ?? false)
    readonly property bool _unreadIsLight: root.look.unreadIsLight
    property color colText: {
        if (root.forceLightInk) return root._inkLight
        if (root.forceDarkInk) return root._inkDark
        if (root._schemeInk)
            return root.inkOnLight ? root._inkDark : root._inkLight
        if (root._onBlurredLock || !root._hasBrightness)
            return root.look.unreadInk
        return root.inkOnLight ? root._inkDark : root._inkLight
    }
    Behavior on colText {
        enabled: root.animationsActive
        ColorAnimation { duration: FamilyStyle.revealDuration }
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

    // The family's face (`face` in the widget's manifest, a part `widgetFace.<face>`), or the worn Design's print of the
    // widget (`printPart`) when the Design prints one for `printKey`.
    property string facePart: DesktopWidgetRegistry.entry(root.configEntryName)?.face ?? ""
    property string printPart: ""
    property string printKey: ""
    readonly property string faceUrl: root.facePart.length > 0 ? Plugins.part(Plugins.active, "widgetFace." + root.facePart)
        : root.printPart.length > 0 && FamilyStyle.facePrints[root.printKey] ? Plugins.part(Plugins.active, "designFace") : ""
    readonly property bool hasFamilyFace: root.faceUrl.length > 0
    readonly property bool faceOnly: DesktopWidgetRegistry.entry(root.configEntryName)?.faceOnly ?? false
    readonly property var designChoices: {
        const list = []
        const spec = DesktopWidgetDesign.spec
        if (root.hasFamilyFace && spec.face) list.push({ value: spec.face, icon: "auto_awesome", label: Translation.tr(spec.faceLabel) })
        if (!spec.face || !root.faceOnly) list.push({ value: "material", icon: "widgets", label: Translation.tr("Material") })
        if (DesktopWidgetDesign.supports(root.configEntryName)) {
            list.push({ value: "instrument", icon: "avg_pace", label: Translation.tr("iNstrument") })
            list.push({ value: "readout", icon: "view_agenda", label: Translation.tr("Readout") })
        }
        return list
    }
    readonly property string widgetDesign: root.familyDesign ? DesktopWidgetDesign.faceDesign
        : root.widgetSharedDesign === "individual" ? "material" : root.widgetSharedDesign
    readonly property bool widgetDesignShared: root.widgetDesign === DesktopWidgetDesign.current
    readonly property bool widgetDesignMatchable: !root.widgetDesignShared || DesktopWidgetDesign.exceptionCount > 0
    function useDesignEverywhere(): void { DesktopWidgetDesign.apply(root.widgetDesign) }
    function pickDesign(value: string): void {
        if (root.stacked)
            return
        root._setOutputValue(DesktopWidgetDesign.spec.key, value === DesktopWidgetDesign.current ? "auto"
            : value === "material" ? DesktopWidgetDesign.spec.plain : value)
    }
    property var familyOptions: []
    readonly property bool familyFaced: root.familyDesign && root.hasFamilyFace
    // One size per instance (`sizeClass`), from the classes the widget's manifest lists: every family and design draws
    // the same footprint, so changing family leaves the desktop as it was arranged. A stack keeps the classes all its
    // pages have. Where the family's faces take any box (`widgetFreeSize` in its plugin.json) a free width and height lie
    // over the class, which follows to the nearest one; S, M or L clears them.
    readonly property var sizes: DesktopWidgetRegistry.sizesOf(root.configEntryName)
    readonly property var sizeChoices: root.stacked ? root.stack.sizes : root.sizes
    readonly property string sizeClass: {
        const chosen = String(root._readConfigKey("sizeClass") ?? "")
        if (root.sizeChoices.includes(chosen)) return chosen
        if (root.stacked && root.sizeChoices.includes(root.stack.size)) return root.stack.size
        return root.sizeChoices[0] ?? ""
    }
    readonly property bool sized: root.sizeClass.length > 0
    readonly property bool isSmall: root.sizeClass === "small"
    readonly property bool isLarge: root.sizeClass === "large"
    readonly property real sizeGutter: Math.round(DesktopWidgetRegistry.gap * FamilyStyle.density * root._baseScale)
    readonly property var sizeLabels: ({ small: Translation.tr("Small"), medium: Translation.tr("Medium"), large: Translation.tr("Large") })
    function footprintOf(size: string): size {
        const box = DesktopWidgetRegistry.footprint(size)
        const k = FamilyStyle.density * root._baseScale
        return Qt.size(Math.round(box.width * k), Math.round(box.height * k))
    }
    readonly property bool _freeAllowed: Plugins.flag(Plugins.active, "widgetFreeSize")
    readonly property real _freeWidth: root._freeAllowed ? Number(root._readConfigKey("freeWidth") ?? 0) || 0 : 0
    readonly property real _freeHeight: root._freeAllowed ? Number(root._readConfigKey("freeHeight") ?? 0) || 0 : 0
    readonly property bool freeSized: root._freeWidth > 0 || root._freeHeight > 0
    readonly property real footprintWidth: root._freeWidth > 0 ? Math.round(root._freeWidth * root._baseScale)
        : root.sized ? root.footprintOf(root.sizeClass).width : 0
    readonly property real footprintHeight: root._freeHeight > 0 ? Math.round(root._freeHeight * root._baseScale)
        : root.sized ? root.footprintOf(root.sizeClass).height : 0
    implicitWidth: root.footprintWidth
    implicitHeight: root.footprintHeight
    // The family's edit window drives a free size in screen pixels at true size.
    function beginFreeSize(): void {
        root._resizePreviewValues = ({})
        root._isResizing = true
    }
    function previewFreeSize(width: real, height: real): void {
        const w = Math.max(root.resizeMinWidth, Math.min(root.resizeMaxWidth, width))
        const h = Math.max(root.resizeMinHeight, Math.min(root.resizeMaxHeight, height))
        root._resizePreviewValues = { freeWidth: Math.round(w / root._baseScale), freeHeight: Math.round(h / root._baseScale) }
    }
    function commitFreeSize(): void {
        const preview = root._resizePreviewValues
        root._isResizing = false
        root._resizePreviewValues = ({})
        if (preview.freeWidth === undefined) return
        root._setOutputValues({ freeWidth: preview.freeWidth, freeHeight: preview.freeHeight,
            sizeClass: root.nearestSize(preview.freeWidth, preview.freeHeight) })
        _makeRoomLater.restart()
    }
    function cancelFreeSize(): void {
        root._resizePreviewValues = ({})
        root._isResizing = false
    }
    function nearestSize(width: real, height: real): string {
        let best = root.sizeClass
        let gap = Number.POSITIVE_INFINITY
        for (const size of root.sizes) {
            const foot = DesktopWidgetRegistry.footprint(size)
            const d = Math.abs(foot.width - width) + Math.abs(foot.height - height)
            if (d < gap) { gap = d; best = size }
        }
        return best
    }
    function commitSize(size: string): void {
        root._resizePreviewValues = ({})
        root._sizing = false
        if (root.sizeChoices.includes(size) && (root.freeSized || size !== String(root._storedConfigKey("sizeClass") ?? "")))
            root._setOutputValues(Object.assign({ sizeClass: size }, root.freeSized ? { freeWidth: 0, freeHeight: 0 } : {}))
        _sizeSettle.restart()
    }
    // A drawing with its own proportions reports the size it takes (at the current scaleFactor); the fit keeps it inside
    // the footprint with `fitPadding` around it. A face lays itself out for its size and takes no fit.
    property real drawnWidth: 0
    property real drawnHeight: 0
    property real fitPadding: 14
    property real fitMax: 1.6
    property bool fitted: false
    readonly property bool fits: root.fitted && root.sized && !root.familyFaced
    property real _fit: 1
    function _refit(): void {
        if (!root.fits || root.drawnWidth <= 0 || root.drawnHeight <= 0) {
            root._fit = 1
            return
        }
        // The drawing grows with the fit, so its size at fit 1 stays put and the next pass lands on the same value.
        const unitWidth = root.drawnWidth / root._fit
        const unitHeight = root.drawnHeight / root._fit
        const pad = root.fitPadding * root._baseScale * 2
        const fit = Math.max(0.4, Math.min(root.fitMax,
            (root.footprintWidth - pad) / unitWidth, (root.footprintHeight - pad) / unitHeight))
        if (Math.abs(fit - root._fit) > 0.004)
            root._fit = fit
    }
    onDrawnWidthChanged: _refitLater.restart()
    onDrawnHeightChanged: _refitLater.restart()
    onFootprintWidthChanged: _refitLater.restart()
    onFootprintHeightChanged: _refitLater.restart()
    onFitsChanged: _refitLater.restart()
    Timer {
        id: _refitLater
        interval: 0
        onTriggered: root._refit()
    }
    // a size chosen elsewhere (Settings) makes room like one chosen here; the first size it shows is no change
    property string _shownSize: ""
    onSizeClassChanged: {
        const was = root._shownSize
        root._shownSize = root.sizeClass
        if (was.length > 0 && !root._sizing)
            _sizeSettle.restart()
    }
    function familyOption(key: string, fallback: var): var {
        const value = root._readConfigKey(DesktopWidgetDesign.spec.prefix + "." + key)
        return value === undefined || value === null ? fallback : value
    }
    function setFamilyOption(key: string, value: var): void {
        root._setOutputValue(DesktopWidgetDesign.spec.prefix + "." + key, value)
    }
    // The sheet's own slider: not a gesture, so the sheet stays under the pointer that drags it.
    function previewScale(percent: int): void {
        root.previewValue("widgetScale", percent)
    }
    function previewValue(key: string, value: var): void {
        const preview = ({})
        preview[key] = value
        root._resizePreviewValues = preview
        root._previewing = true
    }
    function commitValue(key: string, value: var): void {
        root._setOutputValue(key, value)
        _previewSettle.restart()
    }
    Timer {
        id: _previewSettle
        interval: 140
        onTriggered: {
            root._resizePreviewValues = ({})
            root._previewing = false
        }
    }
    function commitIrisScale(percent: int): void {
        root.commitValue("widgetScale", percent)
        _sizeSettle.restart()
    }

    readonly property Item faceView: faceLoader.item
    Loader {
        id: faceLoader
        anchors.fill: parent
        active: root.familyFaced
        // A face answers to its own rows (Material, Opacity in iRiS Settings); Material's Opacity and Dimming are hidden
        // while a face is drawn, and a value left there from before faded it to a ghost with no row to undo it.
        opacity: 1
        function loadNamed(): void {
            if (root.faceUrl.length > 0)
                setSource(root.faceUrl, root.printPart.length > 0 ? { widget: root, part: root.printPart } : { widget: root })
        }
        Component.onCompleted: loadNamed()
        Connections {
            target: root
            function onFaceUrlChanged(): void { faceLoader.loadNamed() }
        }
    }

    function widgetSemanticSet(role: string): var { return root.look.semanticSet(root, role) }

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
    // A plate shows behind the face: what a lifted widget's shadow belongs under. Bare, the shadow filled the box
    // with a dark square while it was dragged.
    readonly property bool platedNow: root.look.plated(root)
    readonly property bool widgetHasSurface: root.widgetSurfaceEnabled
        && (root.backgroundOpacity > 0 || root.effectiveBlur)
    readonly property bool regionIsBright: root._hasBrightness
        ? root.backdropIsLight : root._unreadIsLight

    // Surfaces use semantic containers directly. This removes the old HSL
    // wallpaper-region re-toning that could turn generated warm palettes muddy.
    readonly property color widgetPlateColor: root.look.plateColor(root)
    readonly property bool widgetPlateIsDark: ColorUtils.relativeLuminance(root.widgetPlateColor) < 0.38
    readonly property color widgetSurfaceInk: root.forceLightInk ? root._inkLight
        : root.forceDarkInk ? root._inkDark
        : root.widgetSemanticOnContainer(root.widgetSurfaceRole)
    readonly property color widgetInk: root.widgetHasSurface ? root.widgetSurfaceInk : root.colText
    readonly property color widgetInkMuted: root.widgetEditorial && root.widgetHasSurface && !root.forceLightInk && !root.forceDarkInk
        ? ColorUtils.ensureReadable(ColorUtils.mix(root.widgetInk, root.widgetPlateColor, 0.72), root.widgetPlateColor, 4.5)
        : root.widgetHasSurface || !root._hasBrightness ? ColorUtils.applyAlpha(root.widgetInk, 0.66)
        // bare, a caption is a solid tone measured on the wallpaper under it: a fixed alpha lost it on mid tones
        : root._quietInk(0.7, 4.5)
    readonly property color widgetInkSubtle: root.widgetHasSurface || !root._hasBrightness ? ColorUtils.applyAlpha(root.widgetInk, 0.58)
        : root._quietInk(0.62, 3)
    // A step back from the ink toward the wallpaper, only as far as `ratio` allows on the worst part; never past the
    // ink's own polarity (ensureReadable flipped a light caption to black over a mostly dark region).
    function _quietInk(weight: real, ratio: real): color {
        for (let w = weight; w < 1; w += 0.05) {
            const c = ColorUtils.mix(root.widgetInk, root._regionBg, w)
            if (ColorUtils.contrastRatio(c, root._worstBackdrop) >= ratio) return c
        }
        return root.widgetInk
    }
    // The part of the region that fights the ink most (its brightest under light ink, darkest under dark): a sky over
    // mountains averaged dark, and captions over the sky went under 2:1.
    readonly property color _worstBackdrop: {
        const v = root._inkIsLight ? Math.min(1, root.regionBrightness + root.regionBrightnessSpread)
            : Math.max(0, root.regionBrightness - root.regionBrightnessSpread)
        return Qt.rgba(v, v, v, 1)
    }
    readonly property bool widgetEditorial: root.look.editorial
    readonly property string widgetBodyFamily: root.look.bodyFamily(root)
    readonly property string widgetNumbersFamily: root.look.numbersFamily(root)
    function widgetCase(text): string { return root.look.caseOf(root, String(text ?? "")) }
    readonly property int widgetCapitalization: root.look.capitalization(root)
    readonly property string widgetTitleFamily: root.look.titleFamily(root)
    readonly property int widgetTitleWeight: root.look.titleWeight(root)
    readonly property real widgetTitleTracking: root.look.titleTracking(root)
    readonly property real widgetTitleScale: root.look.titleScale(root)
    readonly property real widgetSpacingScale: root.look.spacingScale(root)
    readonly property int widgetLabelWeight: root.look.labelWeight(root)
    readonly property real widgetMetadataTracking: root.look.metadataTracking(root)
    readonly property real widgetControlRadius: root.look.controlRadius(root)
    readonly property real widgetCardRadius: root.look.cardRadius(root)

    property color accentBackdrop: root.widgetHasSurface ? root.widgetPlateColor
        : root._hasBrightness ? root._regionBg
        : root.look.restBackdrop

    // Pick only among existing generated semantic tokens. Movement can therefore
    // change polarity when required, but cannot manufacture a brown/gray/red hue.
    function widgetSemanticForeground(role: string, backdrop = root.accentBackdrop,
            targetContrast = 3.0): color {
        const set = root.widgetSemanticSet(role);
        const candidates = [set.color, set.onContainer, set.onColor, set.container, root.widgetInk];
        // Bare on the wallpaper a colour has to read on the region's worst part too, or the ink takes its place: against
        // the mean alone a light accent passed on a sky half cloud and vanished on the bright half (month's weekend).
        const bare = !root.widgetHasSurface && root._hasBrightness && Qt.colorEqual(backdrop, root.accentBackdrop);
        const ratioOf = c => bare ? Math.min(ColorUtils.contrastRatio(c, backdrop), ColorUtils.contrastRatio(c, root._worstBackdrop))
            : ColorUtils.contrastRatio(c, backdrop);
        let best = candidates[0];
        let bestRatio = ratioOf(best);
        for (let i = 0; i < candidates.length; i++) {
            const candidate = Qt.color(candidates[i]);
            if (!candidate.valid) continue;
            const ratio = ratioOf(candidate);
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

    // A filled mark straight on the wallpaper (today, a chip, an icon's shape) stands 3:1 off the region under it: the
    // role's container when it does, else the role's colour, each with its own ink. Dark mode's container is a deep tone
    // and today's pentagon sank into a dark cloud (10-30).
    function widgetMark(role: string): var {
        const set = root.widgetSemanticSet(role);
        if (root.widgetHasSurface || !root._hasBrightness)
            return { fill: set.container, ink: set.onContainer };
        const off = c => Math.min(ColorUtils.contrastRatio(c, root._regionBg), ColorUtils.contrastRatio(c, root._worstBackdrop));
        const container = off(set.container);
        return container >= 3 || container >= off(set.color)
            ? { fill: set.container, ink: set.onContainer } : { fill: set.color, ink: set.onColor };
    }
    readonly property var widgetPrimaryMark: root.widgetMark(root.widgetPrimaryRole)

    readonly property color widgetAccentVisible: root.widgetSemanticForeground(root.widgetPrimaryRole)
    readonly property color widgetAccent2Visible: root.widgetSemanticForeground(root.widgetSecondaryRole)
    readonly property color widgetAccent3Visible: root.widgetSemanticForeground(root.widgetTertiaryRole)

    // Legibility shadow behind plate-less text, scaled by how busy the region is. Light ink gets a
    // dark shadow; dark ink on a light region gets only a faint light lift over its darker patches,
    // since a dark shadow under dark text reads as a smear and a strong light one as a glow.
    readonly property bool legibleAlways: root.look.legibleAlways
    readonly property real _haloBusy: root.legibleAlways ? 1 : Math.min(1, root.regionBrightnessSpread / 0.28)
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
    // Where the family shadows bare widgets, and one bare by design (bareShadow, Day's dial): the rest keep their own text halo.
    property bool bareShadow: false
    readonly property bool _legibleShadow: (root.look.shadowsBare || root.bareShadow) && root.needsColText && !root.widgetHasSurface && !root.familyFaced
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
        if (root.isDragging && root.quickControlsOpen)
            root.closeQuickControls()
        if (root.isDragging && root._arranging)
            DesktopArrange.begin(root.outputName, root.editInstanceKey)
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
    onWidthChanged: { _geometryPlacementDebounce.restart(); root._report(); if (root._picturing) pictureTimer.restart() }
    onHeightChanged: { _geometryPlacementDebounce.restart(); root._report(); if (root._picturing) pictureTimer.restart() }
    Timer {
        id: _zoneResnapDebounce
        interval: 100; repeat: false
        onTriggered: {
            if (root._isZonePlacement && !root.containsPress && !root._isResizing && !root._sizing)
                root.snapToZone(root.placementStrategy)
        }
    }
    Timer {
        id: _geometryPlacementDebounce
        interval: 120; repeat: false
        onTriggered: {
            if (!Config.ready || root.containsPress || root._isResizing || root._sizing)
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
            , "--horizontal-padding", 48
            , "--vertical-padding", 48
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
