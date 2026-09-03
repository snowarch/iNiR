import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.pill
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

import qs.modules.sidebarRight.quickToggles
import qs.modules.sidebarRight.quickToggles.classicStyle

import qs.modules.sidebarRight.bluetoothDevices
import qs.modules.sidebarRight.events
import qs.modules.sidebarRight.calendar
import qs.modules.sidebarRight.todo
import qs.modules.sidebarRight.hotspot
import qs.modules.sidebarRight.nightLight
import qs.modules.sidebarRight.volumeMixer
import qs.modules.sidebarRight.wifiNetworks

Item {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property string settingsQmlPath: Quickshell.shellPath("settings.qml")
    property int screenWidth: 1920
    property int screenHeight: 1080
    property var panelScreen: null
    property bool panelVisible: false
    property bool geometryPreviewActive: false
    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showEventsDialog: false
    property bool showHotspotDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool editMode: false
    property string expandedWidgetType: ""
    readonly property bool detailOpen: expandedWidgetType.length > 0
    readonly property var detailMeta: ({
        calendar: { title: Translation.tr("Calendar"), icon: "calendar_month" },
        events: { title: Translation.tr("Events"), icon: "event_upcoming" },
        todo: { title: Translation.tr("To Do"), icon: "checklist" }
    })

    function openWidgetDetail(type): void {
        if (root.detailMeta[type]) root.expandedWidgetType = type
    }
    function closeWidgetDetail(): void { root.expandedWidgetType = "" }
    function handleEscape(): bool {
        if (!root.detailOpen) return false
        root.closeWidgetDetail()
        return true
    }

    readonly property bool anyDialogOpen: showAudioOutputDialog || showAudioInputDialog
        || showBluetoothDialog || showEventsDialog || showHotspotDialog
        || showNightLightDialog || showWifiDialog || root.detailOpen
    // Collapse the notification zone (and the panel around it) when there is
    // nothing to show. Dialogs re-expand so they keep their full canvas.
    readonly property bool notifsCollapsed: (Config.options?.sidebar?.collapseEmptyNotifications ?? false)
        && (Notifications.list?.length ?? 0) === 0
        && !anyDialogOpen
    readonly property real preferredContentHeight: SidebarGeometry.rightFitHeight(
        Math.max(0, root.screenHeight - Appearance.sizes.hyprlandGapsOut * 2),
        sidebarRightBackground.naturalCompactHeight,
        root.bottomGroupCollapsed)
    readonly property real minimumUsefulHeight: Math.max(320,
        root.screenHeight * (root.bottomGroupCollapsed
            ? SidebarGeometry.rightFitCollapsedMinRatio
            : SidebarGeometry.rightFitExpandedMinRatio))
    readonly property real minimumUsefulWidth: 320
    readonly property real maximumUsefulWidth: 900

    // Events dialog target: an event object to edit, a Date for a new event
    // prefilled to that day, or null for a blank new event.
    property var eventsDialogEditEvent: null

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) root.closeWidgetDetail()
        }
    }
    
    // Debounce timers to prevent accidental double-clicks
    property bool reloadButtonEnabled: true
    property bool settingsButtonEnabled: true

    // ─── System header actions ───────────────────────────────────────
    // Owned here so both header styles (classic pills, profile card) drive
    // the same debounce state instead of each keeping its own copy.
    function requestReload(): void {
        if (!root.reloadButtonEnabled) {
            _log("[SidebarRight] Reload button still on cooldown, ignoring click");
            return;
        }

        _log("[SidebarRight] Reload button clicked");
        root.reloadButtonEnabled = false;
        reloadButtonCooldown.restart();

        if (CompositorService.isHyprland) {
            Hyprland.dispatch("reload");
        } else if (CompositorService.isNiri) {
            Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "load-config-file"]);
        }
        Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")]);
    }

    function openSettings(): void {
        if (!root.settingsButtonEnabled) {
            _log("[SidebarRight] Settings button still on cooldown, ignoring click");
            return;
        }

        _log("[SidebarRight] Settings button clicked");
        root.settingsButtonEnabled = false;
        settingsButtonCooldown.restart();

        if (CompositorService.isNiri) {
            const wins = NiriService.windows || []
            _log("[SidebarRight] Checking for existing settings window among", wins.length, "windows");
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i]
                if (w.title === "illogical-impulse Settings" && w.app_id === "org.quickshell") {
                    _log("[SidebarRight] Found existing settings window, focusing it");
                    GlobalStates.sidebarRightOpen = false;
                    Qt.callLater(() => {
                        NiriService.focusWindow(w.id)
                    })
                    return
                }
            }
            _log("[SidebarRight] No existing settings window found");
        }

        _log("[SidebarRight] Opening new settings window via IPC");
        GlobalStates.sidebarRightOpen = false;
        Qt.callLater(() => {
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"]);
        })
    }

    Timer {
        id: reloadButtonCooldown
        interval: 500
        onTriggered: {
            root.reloadButtonEnabled = true;
            _log("[SidebarRight] Reload button cooldown finished");
        }
    }

    Timer {
        id: settingsButtonCooldown
        interval: 500
        onTriggered: {
            root.settingsButtonEnabled = true;
            _log("[SidebarRight] Settings button cooldown finished");
        }
    }

    // ─── Modular sections (sidebar.right.sectionOrder) ───────────────
    // Sanitized: unknown ids dropped, missing ids appended in default order,
    // so a stale or hand-edited config can never blank the sidebar.
    readonly property string headerStyle: Config.options?.sidebar?.right?.headerStyle ?? "profile"
    readonly property var _sectionDefaultOrder: ["system", "sliders", "toggles", "notifications", "widgets"]
    readonly property var sectionOrder: {
        const def = root._sectionDefaultOrder
        const saved = Config.options?.sidebar?.right?.sectionOrder ?? def
        const result = []
        for (let i = 0; i < saved.length; i++)
            if (def.includes(saved[i]) && !result.includes(saved[i])) result.push(saved[i])
        for (let i = 0; i < def.length; i++)
            if (!result.includes(def[i])) result.push(def[i])
        return result
    }
    // Loaded BottomWidgetGroup instance (section delegates load lazily).
    // Its collapse state participates in the parent's elastic layout instead
    // of being treated as an isolated visual detail.
    property var bottomWidgetGroupItem: null
    readonly property bool bottomGroupCollapsed: bottomWidgetGroupItem?.collapsed ?? false

    // ─── Section drag-reorder (modular sidebar phase 2) ──────────────
    // Same mechanics as DraggableWidgetContainer: cache heights, displace
    // neighbours live, write the new order once on drop.
    property bool sectionEditMode: false
    property int sectionDragIndex: -1
    property int sectionHoverIndex: -1
    property real sectionDragStartY: 0
    property real sectionDragCurrentY: 0
    property var _sectionHeights: []
    property string sectionResizeId: ""
    property real sectionResizeStartY: 0
    property real sectionResizeStartPrimary: 1
    property real sectionResizeStartOther: 1
    property var _sectionWeightPreview: ({})
    readonly property var _flexSectionIds: ["notifications", "widgets"]

    function _cacheSectionHeights(): void {
        const heights = []
        for (let i = 0; i < sectionRepeater.count; i++) {
            const item = sectionRepeater.itemAt(i)
            heights.push(item && item.visible ? item.height : 0)
        }
        _sectionHeights = heights
    }

    function getSectionDisplacementY(itemIndex: int): real {
        if (sectionDragIndex < 0 || sectionHoverIndex < 0) return 0
        if (itemIndex === sectionDragIndex) return 0
        if (sectionDragIndex < sectionHoverIndex) {
            if (itemIndex > sectionDragIndex && itemIndex <= sectionHoverIndex)
                return -((_sectionHeights[sectionDragIndex] ?? 0) + contentColumn.spacing)
        } else if (sectionDragIndex > sectionHoverIndex) {
            if (itemIndex >= sectionHoverIndex && itemIndex < sectionDragIndex)
                return (_sectionHeights[sectionDragIndex] ?? 0) + contentColumn.spacing
        }
        return 0
    }

    function getSectionDragFollowY(): real {
        if (sectionDragIndex < 0) return 0
        return sectionDragCurrentY - sectionDragStartY
    }

    function moveSection(fromIdx: int, toIdx: int): void {
        if (fromIdx === toIdx || fromIdx < 0 || toIdx < 0) return
        const newOrder = [...root.sectionOrder]
        const moved = newOrder.splice(fromIdx, 1)[0]
        newOrder.splice(toIdx, 0, moved)
        Config.setNestedValue("sidebar.right.sectionOrder", newOrder)
    }

    function startSectionDrag(index: int, mouseY: real): void {
        _cacheSectionHeights()
        sectionDragIndex = index
        sectionHoverIndex = index
        sectionDragStartY = mouseY
        sectionDragCurrentY = mouseY
    }

    function updateSectionDrag(mouseY: real): void {
        if (sectionDragIndex < 0) return
        sectionDragCurrentY = mouseY
        let lastVisibleIndex = sectionDragIndex
        for (let i = 0; i < sectionRepeater.count; i++) {
            const item = sectionRepeater.itemAt(i)
            if (!item || !item.visible) continue
            lastVisibleIndex = i
            if (mouseY < item.y + item.height / 2) {
                sectionHoverIndex = i
                return
            }
        }
        sectionHoverIndex = lastVisibleIndex
    }

    function endSectionDrag(): void {
        if (sectionDragIndex >= 0 && sectionHoverIndex >= 0 && sectionDragIndex !== sectionHoverIndex)
            moveSection(sectionDragIndex, sectionHoverIndex)
        sectionDragIndex = -1
        sectionHoverIndex = -1
        sectionDragStartY = 0
        sectionDragCurrentY = 0
        _sectionHeights = []
    }

    function cancelSectionDrag(): void {
        sectionDragIndex = -1
        sectionHoverIndex = -1
        sectionDragStartY = 0
        sectionDragCurrentY = 0
        _sectionHeights = []
    }

    function sectionWeight(sectionId: string): real {
        const previewValue = root._sectionWeightPreview?.[sectionId]
        if (previewValue !== undefined) return previewValue
        const configured = Number(Config.options?.sidebar?.right?.sectionWeights?.[sectionId] ?? 1)
        return Number.isFinite(configured) ? Math.max(0.35, configured) : 1
    }

    function startSectionResize(sectionId: string, mouseY: real): void {
        if (!root._flexSectionIds.includes(sectionId)) return
        const otherId = sectionId === "notifications" ? "widgets" : "notifications"
        root.cancelSectionDrag()
        sectionResizeId = sectionId
        sectionResizeStartY = mouseY
        sectionResizeStartPrimary = root.sectionWeight(sectionId)
        sectionResizeStartOther = root.sectionWeight(otherId)
        _sectionWeightPreview = ({
            notifications: root.sectionWeight("notifications"),
            widgets: root.sectionWeight("widgets")
        })
    }

    function updateSectionResize(mouseY: real): void {
        if (sectionResizeId.length === 0) return
        const otherId = sectionResizeId === "notifications" ? "widgets" : "notifications"
        const total = Math.max(0.7, sectionResizeStartPrimary + sectionResizeStartOther)
        const delta = (mouseY - sectionResizeStartY) / 140
        const primary = Math.max(0.35, Math.min(total - 0.35, sectionResizeStartPrimary + delta))
        const other = total - primary
        const next = ({})
        next[sectionResizeId] = primary
        next[otherId] = other
        _sectionWeightPreview = next
    }

    function endSectionResize(): void {
        if (sectionResizeId.length === 0) return
        Config.setNestedValues({
            "sidebar.right.sectionWeights.notifications": root.sectionWeight("notifications"),
            "sidebar.right.sectionWeights.widgets": root.sectionWeight("widgets")
        })
        sectionResizeId = ""
        sectionResizeStartY = 0
        _sectionWeightPreview = ({})
    }

    function cancelSectionResize(): void {
        sectionResizeId = ""
        sectionResizeStartY = 0
        _sectionWeightPreview = ({})
    }

    function focusActiveItem() {
        if (bottomWidgetGroupItem && bottomWidgetGroupItem.focusActiveItem) {
            bottomWidgetGroupItem.focusActiveItem()
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.sectionEditMode = false;
                root.cancelSectionDrag();
                root.cancelSectionResize();
                root.showWifiDialog = false;
                root.showBluetoothDialog = false;
                root.showEventsDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
                root.showNightLightDialog = false;
                root.showHotspotDialog = false;
                root.eventsDialogEditEvent = null;
            }
        }
        function onRequestWifiDialogChanged() {
            if (GlobalStates.requestWifiDialog) {
                GlobalStates.requestWifiDialog = false
                if (!GlobalStates.sidebarRightOpen)
                    GlobalStates.openSidebarRight(GlobalStates.sidebarLeftTargetOutput)
                root.showWifiDialog = true
            }
        }
        function onRequestBluetoothDialogChanged() {
            if (GlobalStates.requestBluetoothDialog) {
                GlobalStates.requestBluetoothDialog = false
                if (!GlobalStates.sidebarRightOpen)
                    GlobalStates.openSidebarRight(GlobalStates.sidebarLeftTargetOutput)
                root.showBluetoothDialog = true
            }
        }
    }

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    // ── Staggered section entrance (first instantiation only) ──────────────────
    property int _entranceCascade: -1
    property bool _cascadeCompleted: false

    Timer {
        id: _entranceCascadeTimer
        interval: 50
        repeat: true
        onTriggered: {
            if (root._entranceCascade < 5) root._entranceCascade++
            else { stop(); root._cascadeCompleted = true }
        }
    }

    Component.onCompleted: {
        if (GlobalStates.sidebarRightOpen) {
            _entranceCascadeTimer.start()
        } else {
            // Content pre-loaded while sidebar closed — skip cascade
            root._entranceCascade = 99
            root._cascadeCompleted = true
        }
    }

    Connections {
        id: _cascadeConnections
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen && !root._cascadeCompleted) {
                root._entranceCascade = -1
                _entranceCascadeTimer.start()
            }
        }
    }

    StyledRectangularShadow {
        target: sidebarRightBackground
        visible: sidebarRightBackground.angelEverywhere
            && !Appearance.gameModeMinimal
    }

    IslandPanel {
        anchors.fill: sidebarRightBackground
        visible: sidebarRightBackground.islandStyle
        radius: sidebarRightBackground.radius
        glassEnabled: true
        screen: root.panelScreen ?? root.QsWindow?.window?.screen ?? null
        glassScreenX: root.screenWidth - sidebarRightBackground.width
            - Appearance.sizes.hyprlandGapsOut
        glassScreenY: Appearance.sizes.hyprlandGapsOut
        glassScreenWidth: root.screenWidth
        glassScreenHeight: root.screenHeight
    }

    Rectangle {
        id: sidebarRightBackground

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        readonly property real naturalCompactHeight: contentColumn.implicitHeight
            + root.sidebarPadding * 2
        height: root.notifsCollapsed
            ? SidebarGeometry.rightFitHeight(parent.height,
                naturalCompactHeight, root.bottomGroupCollapsed)
            : parent.height
        Behavior on height {
            enabled: Appearance.animationsEnabled && root.panelVisible
                && !root.geometryPreviewActive
            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        // Clamp >= 0: preload parent.height is 0 here, raw subtraction went negative and froze layout.
        implicitHeight: Math.max(0, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false
        // Resolve one owner for the complete surface. Explicit Ricelin islands
        // override the global worldview; otherwise the selected global style owns it.
        readonly property string surfaceDialect: Appearance.surfaceDialectFor(
            (Config.options?.sidebar?.style ?? "panel") === "island" ? "island" : "")
        readonly property bool islandStyle: surfaceDialect === "island"
        readonly property bool zzzEverywhere: surfaceDialect === "zzz"
        readonly property bool regaliaEverywhere: surfaceDialect === "regalia"
        readonly property bool angelEverywhere: surfaceDialect === "angel"
        readonly property bool auroraEverywhere: surfaceDialect === "aurora" || angelEverywhere
        readonly property bool inirEverywhere: surfaceDialect === "inir"
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property string wallpaperUrl: {
            const _dep1 = WallpaperListener.multiMonitorEnabled
            const _dep2 = WallpaperListener.effectivePerMonitor
            const _dep3 = Wallpapers.effectiveWallpaperUrl
            return WallpaperListener.wallpaperUrlForScreen(root.panelScreen)
        }
        readonly property bool useWallpaperBackdrop: root.panelVisible
            && auroraEverywhere
            && !inirEverywhere
            && !gameModeMinimal
            && wallpaperUrl.length > 0

        ColorQuantizer {
            id: sidebarRightWallpaperQuantizer
            source: sidebarRightBackground.auroraEverywhere ? sidebarRightBackground.wallpaperUrl : ""
            depth: 0
            rescaleSize: 10
        }

        readonly property color wallpaperDominantColor: (sidebarRightWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(sidebarRightBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
        }

        color: (gameModeMinimal || islandStyle) ? "transparent"
            : zzzEverywhere ? Appearance.zzz.chrome
            : regaliaEverywhere ? "transparent"
            : inirEverywhere ? (cardStyle ? Appearance.inir.colLayer1 : Appearance.inir.colLayer0)
            : auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
            : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
        border.width: (gameModeMinimal || islandStyle || regaliaEverywhere) ? 0 : (zzzEverywhere ? 1 : (angelEverywhere ? Appearance.angel.panelBorderWidth : 1))
        border.color: regaliaEverywhere ? "transparent"
            : zzzEverywhere ? Appearance.zzz.hairline
            : angelEverywhere ? Appearance.angel.colPanelBorder
            : inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
        radius: zzzEverywhere ? Appearance.zzz.panelRadius
            : regaliaEverywhere ? Appearance.regalia.panelRadius
            : angelEverywhere ? Appearance.angel.roundingNormal
            : inirEverywhere ? (cardStyle ? Appearance.inir.roundingLarge : Appearance.inir.roundingNormal)
            : cardStyle ? Appearance.rounding.normal : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        RegaliaPlate {
            anchors.fill: parent
            visible: sidebarRightBackground.regaliaEverywhere
            fillColor: sidebarRightBackground.cardStyle ? Appearance.regalia.chassis1 : Appearance.regalia.bg0
            radius: sidebarRightBackground.radius
            inset: Appearance.regalia.panelInset
            elevated: sidebarRightBackground.cardStyle
            deepFrame: !sidebarRightBackground.cardStyle
            glassEnabled: true
        }

        clip: true

        layer.enabled: root.panelVisible && !gameModeMinimal
        layer.smooth: false
        layer.mipmap: false
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: sidebarRightBackground.width
                height: sidebarRightBackground.height
                radius: sidebarRightBackground.radius
            }
        }

        Image {
            id: sidebarRightBlurredWallpaper
            x: -(root.screenWidth - sidebarRightBackground.width - Appearance.sizes.hyprlandGapsOut)
            y: -Appearance.sizes.hyprlandGapsOut
            width: root.screenWidth ?? 1920
            height: root.screenHeight ?? 1080
            visible: sidebarRightBackground.useWallpaperBackdrop
            source: sidebarRightBackground.useWallpaperBackdrop ? sidebarRightBackground.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth ?? 1920
            sourceSize.height: root.screenHeight ?? 1080
            asynchronous: true

            // OPTIMIZATION: Release FBO when sidebar is hidden (saves ~16 MiB VRAM)
            layer.enabled: Appearance.effectsEnabled && sidebarRightBackground.useWallpaperBackdrop && root.panelVisible
            layer.effect: MultiEffect {
                source: sidebarRightBlurredWallpaper
                anchors.fill: source
                saturation: sidebarRightBackground.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled
                    ? (sidebarRightBackground.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }

            Rectangle {
                anchors.fill: parent
                color: sidebarRightBackground.angelEverywhere
                    ? ColorUtils.transparentize((sidebarRightBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((sidebarRightBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: sidebarRightBackground.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        // Angel partial border — elegant half-borders
        AngelPartialBorder {
            visible: sidebarRightBackground.angelEverywhere
            targetRadius: sidebarRightBackground.radius
            z: 10
        }

        ZzzPanelBackdrop {
            anchors.fill: parent
            visible: sidebarRightBackground.zzzEverywhere && opacity > 0
            label: "SYSTEM"
            index: "R"
            ghostText: "RIGHT"
            accentColor: Appearance.zzz.accent
            showTicks: false
            showBurst: false
            showGrid: true
            horizontalBias: 0.18
            verticalBias: 0.04
            ghostWidthFactor: 0.86
            ghostStrength: 0.7
            z: 0
        }

        // ZZZ content wash: stepped tile plate lifts content off the bare chrome
        // so cards/text read cleanly while structural hairlines stay. Low-alpha
        // so chrome + ghost marks still breathe.
        Rectangle {
            anchors.fill: parent
            visible: sidebarRightBackground.zzzEverywhere
            color: ColorUtils.applyAlpha(Appearance.zzz.tile, 0.55)
            z: 0
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            // Sections render in the user-configured order. One delegate owns
            // Layout hints, entrance cascade and dialog-signal routing for all
            // section kinds so reordering never changes wiring.
            Repeater {
                id: sectionRepeater
                model: root.sectionOrder
                delegate: Loader {
                    id: sectionLoader
                    required property string modelData
                    required property int index
                    readonly property bool isCenter: modelData === "notifications"
                    readonly property bool isElastic: modelData === "notifications" || modelData === "widgets"
                    readonly property bool contentCollapsed: modelData === "widgets"
                        && (item?.collapsed ?? false)
                    readonly property bool usesElasticPool: isElastic
                        && !root.notifsCollapsed && !contentCollapsed
                    readonly property bool isBeingDragged: root.sectionDragIndex === index
                    readonly property bool isBeingResized: root.sectionResizeId === modelData
                    readonly property bool isDropTarget: root.sectionHoverIndex === index
                        && root.sectionDragIndex !== index && root.sectionDragIndex >= 0

                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: usesElasticPool
                    Layout.minimumHeight: !isElastic ? -1
                        : contentCollapsed ? implicitHeight
                        : modelData === "widgets" ? 250
                        : root.notifsCollapsed ? implicitHeight : 96
                    Layout.preferredHeight: usesElasticPool
                        ? root.sectionWeight(modelData) * 180 : implicitHeight
                    // The profile card is a full-bleed card that nests into the
                    // panel's corner, so its gap must match the 10px side inset
                    // exactly. The classic pill row keeps its extra breathing
                    // room, which is what that 5 was for.
                    Layout.topMargin: (modelData === "system" && root.headerStyle === "classic") ? 5 : 0
                    visible: active
                    active: {
                        if (modelData !== "sliders") return true
                        const configQuickSliders = Config.options?.sidebar?.quickSliders
                        if (!configQuickSliders?.enable) return false
                        if (!configQuickSliders?.showMic && !configQuickSliders?.showVolume && !configQuickSliders?.showBrightness) return false
                        return true
                    }
                    opacity: root._entranceCascade >= index
                        ? (root.sectionEditMode && !isBeingDragged ? 0.8 : 1) : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    scale: isBeingDragged ? 1.015 : isBeingResized ? 1.008 : 1
                    Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    z: isBeingDragged ? 5 : 0

                    // Live displacement while a sibling section is dragged over
                    transform: Translate {
                        y: sectionLoader.isBeingDragged
                            ? root.getSectionDragFollowY()
                            : root.getSectionDisplacementY(sectionLoader.index)
                        Behavior on y {
                            enabled: Appearance.animationsEnabled && !sectionLoader.isBeingDragged
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                    }

                    // Drop indicator bars (same language as widget reorder)
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.topMargin: -contentColumn.spacing / 2 - height / 2
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        height: 3
                        radius: 1.5
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                        opacity: sectionLoader.isDropTarget && root.sectionHoverIndex < root.sectionDragIndex ? 0.85 : 0
                        visible: opacity > 0
                        z: 10
                        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        anchors.bottomMargin: -contentColumn.spacing / 2 - height / 2
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        height: 3
                        radius: 1.5
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                        opacity: sectionLoader.isDropTarget && root.sectionHoverIndex > root.sectionDragIndex ? 0.85 : 0
                        visible: opacity > 0
                        z: 10
                        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }

                    // Drag grip — only exists in edit mode, top-right of the section
                    Rectangle {
                        visible: root.sectionEditMode
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 4
                        anchors.rightMargin: 4
                        width: 30
                        height: 22
                        z: 20
                        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                        color: sectionHandleArea.containsMouse || sectionLoader.isBeingDragged
                            ? (Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.colors.colLayer1Hover)
                            : (Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1)
                        border.width: Appearance.inirEverywhere ? 1 : 0
                        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "drag_indicator"
                            iconSize: 14
                            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                        }

                        MouseArea {
                            id: sectionHandleArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: sectionLoader.isBeingDragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            acceptedButtons: Qt.LeftButton
                            property bool dragStarted: false
                            onPressed: (mouse) => {
                                dragStarted = true
                                root.startSectionDrag(sectionLoader.index, mapToItem(contentColumn, mouse.x, mouse.y).y)
                            }
                            onPositionChanged: (mouse) => {
                                if (dragStarted)
                                    root.updateSectionDrag(mapToItem(contentColumn, mouse.x, mouse.y).y)
                            }
                            onReleased: {
                                if (dragStarted) root.endSectionDrag()
                                dragStarted = false
                            }
                            onCanceled: {
                                root.cancelSectionDrag()
                                dragStarted = false
                            }
                        }
                    }

                    // Elastic-zone resize handle. Dragging the bottom edge of
                    // either notifications or widgets reallocates the shared
                    // vertical pool and persists both weights atomically.
                    Rectangle {
                        visible: root.sectionEditMode && sectionLoader.usesElasticPool
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -height / 2
                        width: 68
                        height: 18
                        z: 22
                        radius: height / 2
                        color: resizeHandleArea.containsMouse || sectionLoader.isBeingResized
                            ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimaryContainer)
                            : (Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer2)
                        border.width: 1
                        border.color: sectionLoader.isBeingResized
                            ? (Appearance.inirEverywhere ? Appearance.inir.colBorderAccent : Appearance.colors.colPrimary)
                            : (Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colOutlineVariant)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "height"
                                iconSize: 12
                                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(root.sectionWeight(sectionLoader.modelData) * 50) + "%"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                            }
                        }

                        MouseArea {
                            id: resizeHandleArea
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: sectionLoader.isBeingResized ? Qt.ClosedHandCursor : Qt.SizeVerCursor
                            acceptedButtons: Qt.LeftButton
                            property bool resizeStarted: false
                            onPressed: (mouse) => {
                                resizeStarted = true
                                root.startSectionResize(sectionLoader.modelData,
                                    mapToItem(contentColumn, mouse.x, mouse.y).y)
                            }
                            onPositionChanged: (mouse) => {
                                if (resizeStarted)
                                    root.updateSectionResize(mapToItem(contentColumn, mouse.x, mouse.y).y)
                            }
                            onReleased: {
                                if (resizeStarted) root.endSectionResize()
                                resizeStarted = false
                            }
                            onCanceled: {
                                root.cancelSectionResize()
                                resizeStarted = false
                            }
                        }
                    }

                    sourceComponent: {
                        switch (modelData) {
                            case "system":
                                return root.headerStyle === "classic"
                                    ? systemSectionComponent : profileHeaderComponent
                            case "sliders": return slidersSectionComponent
                            case "toggles":
                                return (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                                    ? androidTogglesComponent : classicTogglesComponent
                            case "notifications": return centerSectionComponent
                            case "widgets": return widgetsSectionComponent
                            default: return null
                        }
                    }
                    onLoaded: {
                        if (modelData === "widgets") root.bottomWidgetGroupItem = item
                    }

                    Connections {
                        target: sectionLoader.item
                        ignoreUnknownSignals: true
                        function onOpenAudioOutputDialog() { root.showAudioOutputDialog = true }
                        function onOpenAudioInputDialog() { root.showAudioInputDialog = true }
                        function onOpenBluetoothDialog() { root.showBluetoothDialog = true }
                        function onOpenNightLightDialog() { root.showNightLightDialog = true }
                        function onOpenHotspotDialog() { root.showHotspotDialog = true }
                        function onOpenWifiDialog() { root.showWifiDialog = true }
                        function onOpenEventsDialog(editEvent) {
                            root.eventsDialogEditEvent = editEvent
                            root.showEventsDialog = true
                        }
                        function onRequestExpand(widgetType) {
                            root.openWidgetDetail(widgetType)
                        }
                    }
                }
            }
        }

        Component { id: systemSectionComponent; SystemButtonRow {} }
        Component {
            id: profileHeaderComponent
            SidebarProfileHeader {
                editMode: root.editMode
                sectionEditMode: root.sectionEditMode
                androidToggles: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                reloadEnabled: root.reloadButtonEnabled
                settingsEnabled: root.settingsButtonEnabled
                panelVisible: root.panelVisible
                panelCardStyle: sidebarRightBackground.cardStyle
                panelScreen: root.panelScreen
                surfaceDialect: sidebarRightBackground.surfaceDialect
                panelRadius: sidebarRightBackground.radius
                panelInset: root.sidebarPadding
                atPanelTop: root.sectionOrder[0] === "system"
                onEditModeRequested: root.editMode = !root.editMode
                onSectionEditModeRequested: {
                    root.sectionEditMode = !root.sectionEditMode
                    if (!root.sectionEditMode) {
                        root.cancelSectionDrag()
                        root.cancelSectionResize()
                    }
                }
                onReloadRequested: root.requestReload()
                onSettingsRequested: root.openSettings()
            }
        }
        Component { id: slidersSectionComponent; QuickSliders {} }
        Component { id: classicTogglesComponent; ClassicQuickPanel {} }
        Component { id: androidTogglesComponent; AndroidQuickPanel { editMode: root.editMode } }
        Component { id: centerSectionComponent; CenterWidgetGroup { collapsed: root.notifsCollapsed } }
        Component { id: widgetsSectionComponent; BottomWidgetGroup {} }

    }

    Component {
        id: expandedEventsComponent
        EventsWidget {
            onOpenEventsDialog: editEvent => {
                root.eventsDialogEditEvent = editEvent
                root.showEventsDialog = true
            }
        }
    }
    Component {
        id: expandedCalendarComponent
        CalendarWidget {
            onOpenEventsDialog: editEvent => {
                root.eventsDialogEditEvent = editEvent
                root.showEventsDialog = true
            }
            onDayWithEventsClicked: date => {
                root.eventsDialogEditEvent = date
                root.showEventsDialog = true
            }
        }
    }
    Component { id: expandedTodoComponent; TodoWidget {} }

    MouseArea {
        anchors.fill: parent
        z: 69
        visible: root.detailOpen
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeWidgetDetail()
    }

    Rectangle {
        id: organizerDetail
        anchors.fill: parent
        anchors.margins: root.sidebarPadding
        z: 70
        visible: root.detailOpen
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper
            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1
            : Appearance.colors.colLayer1
        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        clip: true
        focus: visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeWidgetDetail()
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            z: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol {
                    text: root.detailMeta[root.expandedWidgetType]?.icon ?? ""
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.detailMeta[root.expandedWidgetType]?.title ?? ""
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                }
                RippleButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.closeWidgetDetail()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close_fullscreen"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    }
                    StyledToolTip { text: Translation.tr("Back to sidebar") }
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.detailOpen
                sourceComponent: root.expandedWidgetType === "events" ? expandedEventsComponent
                    : root.expandedWidgetType === "calendar" ? expandedCalendarComponent
                    : root.expandedWidgetType === "todo" ? expandedTodoComponent : null
            }
        }
    }

    // With the panel collapsed the window still spans full height; clicks on
    // the vacated strip below the panel should dismiss like the backdrop does.
    MouseArea {
        anchors.top: sidebarRightBackground.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        enabled: sidebarRightBackground.height < root.height - 1
        onClicked: GlobalStates.sidebarRightOpen = false
    }

    ToggleDialog {
        shownPropertyString: "showAudioOutputDialog"
        dialog: VolumeDialog {
            isSink: true
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioInputDialog"
        dialog: VolumeDialog {
            isSink: false
        }
    }

    ToggleDialog {
        shownPropertyString: "showBluetoothDialog"
        dialog: BluetoothDialog {}
        onShownChanged: {
            if (!Bluetooth.defaultAdapter) return
            if (!shown) {
                Bluetooth.defaultAdapter.discovering = false;
            } else {
                Bluetooth.defaultAdapter.enabled = true;
                Bluetooth.defaultAdapter.discovering = true;
            }
        }
    }

    ToggleDialog {
        shownPropertyString: "showNightLightDialog"
        dialog: NightLightDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showHotspotDialog"
        dialog: HotspotDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showWifiDialog"
        dialog: WifiDialog {}
        onShownChanged: {
            if (!shown) return;
            Network.enableWifi();
            Network.rescanWifi();
        }
    }

    ToggleDialog {
        id: eventsToggle
        shownPropertyString: "showEventsDialog"
        dialog: EventsDialog {}
        onShownChanged: {
            if (shown && eventsToggle.item) {
                const arg = root.eventsDialogEditEvent;
                if (arg instanceof Date) {
                    eventsToggle.item.resetForm();
                    eventsToggle.item.eventDate = arg;
                } else if (arg) {
                    eventsToggle.item.loadEvent(arg);
                } else {
                    eventsToggle.item.resetForm();
                }
            }
        }
        onActiveChanged: {
            if (!active) {
                root.eventsDialogEditEvent = null;
            }
        }
    }

    component ToggleDialog: Loader {
        id: toggleDialogLoader
        required property string shownPropertyString
        z: 100
        property alias dialog: toggleDialogLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        property bool _loaded: false
        anchors.fill: parent

        active: _loaded

        onShownChanged: {
            if (shown && !_loaded) _loaded = true
            if (item) {
                item.show = shown
                if (shown) item.forceActiveFocus()
            }
        }

        onItemChanged: {
            if (item && shown) {
                item.show = true;
                item.forceActiveFocus();
            }
        }
        
        Connections {
            target: toggleDialogLoader.item
            function onDismiss() {
                root[toggleDialogLoader.shownPropertyString] = false;
            }
        }
    }

    component SystemButtonRow: Item {
        implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)

        Rectangle {
            id: uptimeContainer
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            color: Appearance.zzzEverywhere ? "transparent"
                : sidebarRightBackground.angelEverywhere ? Appearance.angel.colGlassCard
                : sidebarRightBackground.auroraEverywhere
                ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
                : sidebarRightBackground.angelEverywhere ? Appearance.angel.roundingSmall : height / 2
            Behavior on radius {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            border.width: Appearance.zzzEverywhere ? 0
                : sidebarRightBackground.angelEverywhere ? Appearance.angel.cardBorderWidth : 0
            Behavior on border.width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            border.color: Appearance.zzzEverywhere ? "transparent"
                : sidebarRightBackground.angelEverywhere ? Appearance.angel.colCardBorder : "transparent"
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            implicitWidth: uptimeRow.implicitWidth + 24
            implicitHeight: uptimeRow.implicitHeight + 8
            
            Row {
                id: uptimeRow
                anchors.centerIn: parent
                spacing: 8
                CustomIcon {
                    id: distroIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                        : Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer0
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.zzzEverywhere ? Appearance.font.family.numbers : Appearance.font.family.main
                    font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Normal
                    font.italic: Appearance.zzzEverywhere
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                        : Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer0
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    text: Translation.tr("Up %1").arg(DateTime.uptime)
                    textFormat: Text.MarkdownText
                }
            }
        }

        ButtonGroup {
            id: systemButtonsRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            color: Appearance.zzzEverywhere ? "transparent"
                : sidebarRightBackground.angelEverywhere ? Appearance.angel.colGlassCard
                : sidebarRightBackground.auroraEverywhere
                ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            padding: 4
            spacing: 8

            QuickToggleButton {
                toggled: root.editMode
                visible: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                buttonIcon: "edit"
                onClicked: root.editMode = !root.editMode
                StyledToolTip {
                    position: "left"
                    text: Translation.tr("Edit quick toggles") + (root.editMode ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : "")
                }
            }
            QuickToggleButton {
                toggled: root.sectionEditMode
                buttonIcon: "swap_vert"
                onClicked: {
                    root.sectionEditMode = !root.sectionEditMode
                    if (!root.sectionEditMode) {
                        root.cancelSectionDrag()
                        root.cancelSectionResize()
                    }
                }
                StyledToolTip {
                    position: "left"
                    text: Translation.tr("Reorder sections\nDrag the grips to rearrange the sidebar")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "view_sidebar"
                onClicked: Config.setNestedValue("sidebar.layout", "compact")
                StyledToolTip {
                    position: "left"
                    text: Translation.tr("Switch to compact layout")
                }
            }
            QuickToggleButton {
                id: reloadButton
                toggled: false
                enabled: root.reloadButtonEnabled
                opacity: enabled ? 1.0 : 0.5
                buttonIcon: "restart_alt"
                onClicked: root.requestReload()
                StyledToolTip {
                    position: "left"
                    text: Translation.tr("Reload Quickshell")
                }
            }
            QuickToggleButton {
                id: settingsButton
                toggled: false
                enabled: root.settingsButtonEnabled
                opacity: enabled ? 1.0 : 0.5
                buttonIcon: "settings"
                onClicked: root.openSettings()
                StyledToolTip {
                    position: "left"
                    text: Translation.tr("Settings")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "power_settings_new"
                onClicked: {
                    GlobalStates.sessionOpen = true;
                }
                StyledToolTip {
                    position: "left"
                    text: Translation.tr("Session")
                }
            }
        }
    }
}
