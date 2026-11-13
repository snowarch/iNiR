pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
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
    // That look is the family's (or it has none): what the family draws over this widget may load.
    readonly property bool lookIn: DesktopWidgetLook.holds(root.look)
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
    // Pages turning and the drop that makes a stack: only a widget that can stack builds them.
    Loader {
        id: stacking
        active: root.stacked || root.stackable
        sourceComponent: WidgetStackMotion { widget: root }
    }
    readonly property real stackPos: stacking.item?.pos ?? 0
    readonly property bool stackMoving: stacking.item?.moving ?? false
    readonly property real absorb: stacking.item?.absorb ?? 0
    readonly property string _dropKey: stacking.item?.dropKey ?? ""
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
    // Disable base class x/y behaviors: ours only run while the placement drives x and y.
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
    readonly property real scaleFactor: root._baseScale * (root.fits ? root._fit : root._freeFit)
    // A shared drawing is laid out in pixels times scaleFactor, so a box resized by hand carries its drawing with it.
    readonly property real _freeFit: !root.freeSized || root.familyFaced || !root.sized || root.freeShape ? 1 : root.freeScale
    // A free size is its class drawn at another scale, the box keeping the class's proportions: a box of any other shape
    // left air beside a drawing made for S, M or L, or cut it (his 11-02: "se redimensionan mal"). A stored size of
    // another shape (older files) reads as the largest class box inside it.
    readonly property real freeScale: {
        if (!root.freeSized || !root.sized)
            return 1
        const box = DesktopWidgetRegistry.footprint(root.sizeClass)
        const k = FamilyStyle.density
        const ratios = []
        if (root._freeWidth > 0) ratios.push(root._freeWidth / (box.width * k))
        if (root._freeHeight > 0) ratios.push(root._freeHeight / (box.height * k))
        return Math.max(root.freeScaleMin, Math.min(root.freeScaleMax, Math.min(...ratios)))
    }
    readonly property real freeScaleMin: 0.6
    // A widget whose Material face lays itself out in any box (a month, a list, notes, a picture: v2.33's `resizableAxes`
    // width and height, his 11-07 "algunos sí necesitan redimensionarse de forma libre, como sus viejos comportamientos")
    // says `"freeShape": true` in its widget.json: under Material its box takes any width and height and the drawing
    // reflows. Every other widget scales its class; a family's own face keeps its sizes.
    readonly property bool freeShape: !root.familyFaced && root.sized
        && (DesktopWidgetRegistry.entry(root.configEntryName)?.freeShape ?? false)
    readonly property real freeScaleMax: 1.8
    property real _freeStartScale: 1
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
    // The plate: one switch, the same in every family and design; the manifest says who stands bare by default.
    readonly property bool bare: DesktopWidgetRegistry.entry(root.configEntryName)?.bare ?? false
    readonly property bool showBackground: root._readConfigKey("showBackground") ?? root.look.plateByDefault(root)
    readonly property bool useBlur: root._readConfigKey("useBlur") ?? false
    // How much the glass frosts, 0-1 of what the family's style blurs by (100 % = the style's own).
    readonly property real blurStrength: Math.max(0, Math.min(150, Number(root._readConfigKey("blurStrength") ?? 100))) / 100
    readonly property bool blurAvailable: root.look.blurAvailable(root)
    readonly property bool effectiveBlur: root.showBackground && root.useBlur && root.blurAvailable
    readonly property bool showBorder: root._readConfigKey("showBorder") ?? (!root.bare || root.familyFaced)
    // Granular card controls — override booleans when present
    // Whether a plate can show at all: a widget that draws its own card in the base design has none to take away.
    readonly property bool plateOffered: root.familyFaced || DesktopWidgetRegistry.entry(root.configEntryName)?.plate !== false
    function setPlate(on: bool): void {
        root._setOutputValues(DesktopWidgetOptions.plateValues(on, root._readConfigKey("backgroundOpacity") ?? 0.16))
    }
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
    // Written by the placement: a direct binding makes a resize/config revision cycle.
    property string placementStrategy: "free"
    readonly property WidgetPlacement placement: WidgetPlacement { widget: root }

    Behavior on x {
        enabled: Appearance.animationsEnabled && root.placement.following
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
    Behavior on y {
        enabled: Appearance.animationsEnabled && root.placement.following
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }

    transform: [
        Rotation { origin.x: root.width / 2; origin.y: root.height / 2; angle: chaos.item?.angle ?? 0 },
        Translate { x: chaos.item?.dx ?? 0; y: chaos.item?.dy ?? 0 },
        Scale { xScale: shelf.item?.shrink ?? 1; yScale: shelf.item?.shrink ?? 1 },
        Translate { x: (shelf.item?.dx ?? 0) + root._glideX * root._glide; y: (shelf.item?.dy ?? 0) + root._glideY * root._glide }
    ]

    // Only while the mascot can romp: a dozen objects per widget otherwise, for nobody.
    Loader {
        id: chaos
        active: MascotChaos.enabled
        sourceComponent: WidgetChaos { widget: root }
    }

    visible: opacity > 0
    // A family face dims itself, so its edit toolbar and sheet stay legible over a dimmed widget.
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
    draggable: (placementStrategy === "free" || GlobalStates.widgetEditMode) && !GlobalStates.screenLocked && !root.locked
    grabCursor: GlobalStates.widgetEditMode
    // Sheets keep clear of the bar and the edit toolbar (the zone work area), even where a free widget sits under them.
    readonly property real quickControlsAvailableWidth: Math.max(0, root.placement.zoneRight - root.placement.zoneLeft - 16)
    readonly property real quickControlsAvailableHeight: Math.max(0, root.placement.zoneBottom - root.placement.zoneTop - 64)

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
            root.placement.settle()
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
        if (root.isDragging)
            stacking.item?.probe()
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
        return { x: Math.round(root.placement.clampX(plan.x)), y: Math.round(root.placement.clampY(plan.y)), guides: plan.guides, neighbours: plan.neighbours }
    }

    // ── The shelf (a family that hosts arranging: DesktopEditStage) ──
    // Only while arranging: everything about the shelf is in here.
    Loader {
        id: shelf
        active: GlobalStates.widgetEditMode
        sourceComponent: WidgetShelfMotion { widget: root }
    }
    readonly property bool _shelfMoving: shelf.item?.moving ?? false
    on_ShelfMovingChanged: root._report()
    readonly property var _departure: shelf.item?.departure ?? null
    Component.onDestruction: {
        DesktopEditStage.inspect(root.outputName, root, false)
        DesktopEditStage.choose(root.outputName, root, false)
        DesktopEditStage.point(root.outputName, root, false)
    }
    on_GeometryReadyChanged: if (root._geometryReady) newcomerSettle.restart()
    // Brought out while the desktop is up (a switch in Settings, IPC) onto a place another widget took meanwhile, it
    // steps to the nearest free spot and the others stay. At start every widget keeps its place; from the shelf
    // the shelf places it.
    Timer {
        id: newcomerSettle
        interval: 400
        onTriggered: {
            const canvas = root._canvas
            if (!canvas?.settled || typeof canvas.freeSpot !== "function" || root.placementStrategy !== "free" || root.locked
                    || root.isDragging || DesktopEditStage.arrival(root.outputName, root.configEntryName) || shelf.item?.landed
                    || root.outputName.startsWith("lock:") || root.width <= 0 || root.height <= 0)
                return
            const spot = canvas.freeSpot(root.editInstanceKey, root.x, root.y, root.width, root.height)
            if (spot.moved)
                root._setOutputValues({ x: Math.round(spot.x), y: Math.round(spot.y), placementStrategy: "free" })
        }
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
    function glideFrom(x: real, y: real): void {
        root._glideX = x - root.x
        root._glideY = y - root.y
        root._glide = 1
        glideRun.restart()
    }
    // Taking a widget away while a shelf is out sends it into its picture there.
    function takeAway(): void {
        const tile = DesktopEditStage.tiles[root.configEntryName]
        if (tile && DesktopEditStage.hosted(root.outputName) && root.animationsActive)
            DesktopEditStage.depart(root.outputName, root.configEntryName, tile)
        else
            DesktopWidgetLayout.setEnabledOn(root.outputName, root.configEntryName, false)
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
        function onDesktopWidgetNudge(dx: int, dy: int): void { if (root.editSelected && root.visible) root.placement.nudge(dx, dy) }
    }

    Keys.onPressed: event => {
        if (!root.editSelected || event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const step = event.modifiers & Qt.ShiftModifier ? 10 : 1
        if (event.key === Qt.Key_Escape) {
            if (root.quickControlsOpen) root.quickControlsOpen = false
            else GlobalStates.clearDesktopWidgetSelection()
        } else if (event.key === Qt.Key_Left) root.placement.nudge(-step, 0)
        else if (event.key === Qt.Key_Right) root.placement.nudge(step, 0)
        else if (event.key === Qt.Key_Up) root.placement.nudge(0, -step)
        else if (event.key === Qt.Key_Down) root.placement.nudge(0, step)
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
        when: GlobalStates.widgetEditMode && (root.sizeChoices.length > 1 || root.freeAllowed) && root.sized && !root.locked
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
            if (root.placement.onZone)
                root.placement.snapToZone(root.placementStrategy)
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
        stacking.item?.clearDrop()
        if (root._arranging) DesktopArrange.cancel()
    }
    onReleased: {
        if (GlobalStates.screenLocked || !root.dragMoved) return;
        if (root._dropKey.length > 0) {
            stacking.item?.drop()
            return
        }
        const spot = DesktopArrange.end(root.outputName, root.editInstanceKey, root.x, root.y, root.width, root.height,
            root._arrangeFree, root._stackId)
        const finalX = root.placement.clampX(spot.x)
        const finalY = root.placement.clampY(spot.y)
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
    // A widget's options are rows in its manifest (`DesktopWidgetOptions`); both families' sheets draw them. `ownControls`
    // is for what a row can't draw, and `ownControlKeys` are the keys it answers for.
    property Component ownControls: null
    // The name a person's widget from v2.33 knows it by.
    property alias editPopoverContent: root.ownControls
    property var ownControlKeys: root.ownControls ? Object.keys(DesktopWidgetRegistry.customEntry(root.configEntryName)?.configKeys ?? {}) : []
    property bool semanticPaletteControls: !root.configEntryName.startsWith("custom.")
    property bool semanticPaletteQuickControls: semanticPaletteControls
    property string _quickTab: "widget"
    readonly property string identityGlyph: DesktopWidgetRegistry.glyph(root.configEntryName)
    readonly property string displayName: DesktopWidgetRegistry.displayName(root.configEntryName)
    readonly property color identityTint: FamilyStyle.identityOf(DesktopWidgetRegistry.tint(root.configEntryName))
    // The page that holds position, lock and removal: "arrange" in an iRiS face's sheet, "layout" otherwise.
    readonly property string _arrangeTab: "arrange"

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
            key, Config.getNestedValue(root._configPath + "." + key, root.defaultConfig[key]))
    }

    // The manifest's defaults, read and never copied into a person's config; a person's own widget sets them itself.
    property var defaultConfig: DesktopWidgetRegistry.defaultsOf(root.configEntryName)
    Component.onCompleted: {
        Qt.callLater(() => root._geometryReady = true)
        root._applyBackdropSample()
        root.placement.syncStrategy();
        root.placement.applyLater();
        root._shownSize = root.sizeClass
        if (!root.outputName.startsWith("lock:"))
            DesktopWidgetStacks.report(root.configEntryName, root.sizes, root.sizes[0] ?? "", root.hasFamilyFace)
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
        // A person's widget: every option of its manifest too.
        const custom = DesktopWidgetRegistry.customEntry(root.configEntryName)
        for (const key in custom?.configKeys ?? {})
            if (custom.configKeys[key].default !== undefined) updates[key] = custom.configKeys[key].default
        for (const option of custom?.options ?? [])
            if (option.key && option.default !== undefined && !option.shell) updates[option.key] = option.default
        Object.assign(updates, { sizeClass: root.sizes[0] ?? "", freeWidth: 0, freeHeight: 0 })
        Object.assign(updates, root.look.resetValues(root))
        root._setOutputValues(updates);
        root.placement.syncFree();
        root.placement.refresh();
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

    // The family's face (`face` in the widget's manifest, a part `widgetFace.<face>`), a hub widget's own drawing for
    // the family's face design (`desktop` in its manifest), or the worn Design's print of the widget (`printPart`) when
    // the Design prints one for `printKey`.
    property string facePart: DesktopWidgetRegistry.entry(root.configEntryName)?.face ?? ""
    property string printPart: ""
    property string printKey: ""
    readonly property string familyFaceUrl: root.facePart.length > 0 ? Plugins.part(Plugins.active, "widgetFace." + root.facePart)
        : root.printPart.length > 0 && FamilyStyle.facePrints[root.printKey] ? Plugins.part(Plugins.active, "designFace")
        : DesktopWidgetRegistry.customFace(root.configEntryName, DesktopWidgetDesign.faceDesign)
    readonly property bool hasFamilyFace: root.familyFaceUrl.length > 0
    // Which of the family's face designs draws it (its own, or one of `faces`: Prism in iRiS), and that design's face.
    readonly property string familyFaceDesign: root.familyDesign ? (root._designResolved.wear || DesktopWidgetDesign.faceDesign) : ""
    readonly property string wornFaceUrl: root.familyFaceDesign.length > 0 && root.familyFaceDesign !== DesktopWidgetDesign.faceDesign
        ? DesktopWidgetDesign.partOf(root.configEntryName, root.familyFaceDesign) : ""
    readonly property string faceUrl: root.wornFaceUrl.length > 0 ? root.wornFaceUrl : root.familyFaceUrl
    readonly property bool faceOnly: DesktopWidgetRegistry.entry(root.configEntryName)?.faceOnly ?? false
    readonly property var designChoices: {
        const list = []
        const spec = DesktopWidgetDesign.spec
        if (root.hasFamilyFace && spec.face) list.push({ value: spec.face, icon: "auto_awesome", label: Translation.tr(spec.faceLabel) })
        for (const entry of DesktopWidgetDesign.faceDesigns) {
            if (root.hasFamilyFace && DesktopWidgetDesign.drawsIn(root.configEntryName, entry.value))
                list.push({ value: entry.value, icon: entry.glyph ?? "auto_awesome", label: Translation.tr(entry.label) })
        }
        if (!spec.face || !root.faceOnly) list.push({ value: "material", icon: "widgets", label: Translation.tr("Material") })
        if (DesktopWidgetDesign.supports(root.configEntryName)) {
            list.push({ value: "instrument", icon: "avg_pace", label: Translation.tr("iNstrument") })
            list.push({ value: "readout", icon: "view_agenda", label: Translation.tr("Readout") })
        }
        return list
    }
    readonly property string widgetDesign: root.familyDesign ? root.familyFaceDesign
        : root.widgetSharedDesign === "individual" ? "material" : root.widgetSharedDesign
    // A widget the shared design has nothing for follows it all the same (it keeps the family's face meanwhile).
    readonly property bool widgetDesignShared: root.widgetDesign === DesktopWidgetDesign.current || root._designResolved.fallback === true
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
    // pages have. A drawing that takes any box carries a free width and height over the class, which follows to the
    // nearest one; S, M or L clears them. The shared (Material) drawings always do, under any family; a family's own
    // faces do where its plugin.json says `widgetFreeSize`. The drawing decides, never the family around it: a Material
    // widget under iRiS was held to S/M/L it was never drawn for (his 11-02).
    readonly property var sizes: DesktopWidgetRegistry.sizesOf(root.configEntryName)
    // Always small to large; the manifest's first is only the default.
    readonly property var sizeChoices: DesktopWidgetRegistry.sizeOrder.filter(size => (root.stacked ? root.stack.sizes : root.sizes).includes(size))
    readonly property string sizeClass: {
        const chosen = String(root._readConfigKey("sizeClass") ?? "")
        if (root.sizeChoices.includes(chosen)) return chosen
        if (root.stacked && root.sizeChoices.includes(root.stack.size)) return root.stack.size
        return root.sizeChoices.includes(root.sizes[0]) ? root.sizes[0] : root.sizeChoices[0] ?? ""
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
    readonly property bool freeAllowed: !root.familyFaced || Plugins.flag(Plugins.active, "widgetFreeSize")
    readonly property real _freeWidth: root.freeAllowed ? Number(root._readConfigKey("freeWidth") ?? 0) || 0 : 0
    readonly property real _freeHeight: root.freeAllowed ? Number(root._readConfigKey("freeHeight") ?? 0) || 0 : 0
    readonly property bool freeSized: root._freeWidth > 0 || root._freeHeight > 0
    readonly property real footprintWidth: root.freeShape && root._freeWidth > 0 ? Math.round(root._freeWidth * root._baseScale)
        : root.sized ? Math.round(root.footprintOf(root.sizeClass).width * (root.freeShape ? 1 : root.freeScale))
        : root._freeWidth > 0 ? Math.round(root._freeWidth * root._baseScale) : 0
    readonly property real footprintHeight: root.freeShape && root._freeHeight > 0 ? Math.round(root._freeHeight * root._baseScale)
        : root.sized ? Math.round(root.footprintOf(root.sizeClass).height * (root.freeShape ? 1 : root.freeScale))
        : root._freeHeight > 0 ? Math.round(root._freeHeight * root._baseScale) : 0
    implicitWidth: root.footprintWidth
    implicitHeight: root.footprintHeight
    // The family's edit window drives a free size in screen pixels at true size.
    function beginFreeSize(): void {
        root._freeStartScale = root.freeScale
        root._resizePreviewValues = ({})
        root._isResizing = true
    }
    // The pointer's box becomes one scale of the class: the side that moved farther from where the drag began leads, so
    // an edge grip follows its edge and a corner grip its stronger axis. The class stays: S, M or L are their own keys.
    function previewFreeSize(width: real, height: real): void {
        if (!root.sized || root.freeShape) {
            // A free shape keeps at least six tenths of a small box on each side, so its face always has room to read.
            const floor = root.freeShape ? root.footprintOf("small") : Qt.size(0, 0)
            const minWidth = Math.max(root.resizeMinWidth, Math.round(floor.width * 0.6))
            const minHeight = Math.max(root.resizeMinHeight, Math.round(floor.height * 0.6))
            root._resizePreviewValues = { freeWidth: Math.round(Math.max(minWidth, Math.min(root.resizeMaxWidth, width)) / root._baseScale),
                freeHeight: Math.round(Math.max(minHeight, Math.min(root.resizeMaxHeight, height)) / root._baseScale) }
            return
        }
        const box = root.footprintOf(root.sizeClass)
        const across = width / box.width
        const down = height / box.height
        const lead = Math.abs(across - root._freeStartScale) >= Math.abs(down - root._freeStartScale) ? across : down
        const scale = Math.max(root.freeScaleMin, Math.min(root.freeScaleMax, lead))
        const unit = DesktopWidgetRegistry.footprint(root.sizeClass)
        const k = FamilyStyle.density
        root._resizePreviewValues = { freeWidth: Math.round(unit.width * k * scale), freeHeight: Math.round(unit.height * k * scale) }
    }
    function commitFreeSize(): void {
        const preview = root._resizePreviewValues
        root._isResizing = false
        root._resizePreviewValues = ({})
        if (preview.freeWidth === undefined) return
        const unit = DesktopWidgetRegistry.footprint(root.sizeClass)
        // Back at the class's own size, it is the class again, not a free size of 100 %.
        const near = (value, unitSide) => Math.abs(value / (unitSide * FamilyStyle.density) - 1) < 0.03
        const plain = root.sized && near(preview.freeWidth, unit.width) && (!root.freeShape || near(preview.freeHeight, unit.height))
        const values = plain ? { freeWidth: 0, freeHeight: 0 } : { freeWidth: preview.freeWidth, freeHeight: preview.freeHeight }
        // A free shape lays out as the class nearest its box, so a wide short box reads as a small one stretched, not a
        // large one cut.
        if (root.freeShape && !plain)
            values.sizeClass = root.nearestSize(preview.freeWidth, preview.freeHeight)
        root._setOutputValues(values)
        _makeRoomLater.restart()
    }
    function nearestSize(width: real, height: real): string {
        let best = root.sizeClass
        let gap = Number.POSITIVE_INFINITY
        for (const size of root.sizeChoices) {
            const foot = DesktopWidgetRegistry.footprint(size)
            const k = FamilyStyle.density
            // Fits inside first: a class larger than the box on either side would cut its face.
            const over = Math.max(0, foot.width * k - width) + Math.max(0, foot.height * k - height)
            const d = over * 4 + Math.abs(foot.width * k - width) + Math.abs(foot.height * k - height)
            if (d < gap) { gap = d; best = size }
        }
        return best
    }
    function cancelFreeSize(): void {
        root._resizePreviewValues = ({})
        root._isResizing = false
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
        // A drawing rounds its size, so the fit it answers with can hop between two values for ever, at a timer of 0,
        // and the shell stops answering: a few passes per box, and a step too small to see is no step.
        if (Math.abs(fit - root._fit) < 0.02 * root._fit || root._fitPasses >= 4)
            return
        root._fitPasses++
        root._fit = fit
    }
    property int _fitPasses: 0
    function _refitBox(): void {
        root._fitPasses = 0
        _refitLater.restart()
    }
    onDrawnWidthChanged: _refitLater.restart()
    onDrawnHeightChanged: _refitLater.restart()
    onFootprintWidthChanged: root._refitBox()
    onFootprintHeightChanged: root._refitBox()
    onFitsChanged: root._refitBox()
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
        root._refitBox()
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
    function setFamilyOptions(values: var): void {
        const stored = {}
        for (const key of Object.keys(values))
            stored[DesktopWidgetDesign.spec.prefix + "." + key] = values[key]
        root._setOutputValues(stored)
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
    // A preview someone else committed (a sheet row written through DesktopWidgetOptions): let it go once the write lands.
    function settlePreview(): void {
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
        active: root.familyFaced && root.lookIn
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

    readonly property string wallpaperPath: root._lumaPath
    onIsDraggingChanged: {
        // A sheet that chases the widget across the screen re-decides its edge
        // on every frame of the drag. Moving the widget puts it away instead.
        if (root.isDragging && root.quickControlsOpen)
            root.closeQuickControls()
        if (root.isDragging && root._arranging)
            DesktopArrange.begin(root.outputName, root.editInstanceKey)
    }
    onWidthChanged: { root._report(); shelf.item?.retake() }
    onHeightChanged: { root._report(); shelf.item?.retake() }
    Connections {
        target: Config
        function onReadyChanged() {
            root.placement.apply();
        }
    }
}
