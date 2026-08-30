pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.pill
import qs.modules.sidebarLeft.animeSchedule
import qs.modules.sidebarLeft.innertune
import qs.modules.sidebarLeft.news
// DISABLED: webapps — requires quickshell-webengine rebuild, re-enable when ready
// import qs.modules.sidebarLeft.plugins
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property int screenWidth: 1920
    property int screenHeight: 1080
    property var panelScreen: null
    property bool panelVisible: false
    property bool geometryPreviewActive: false
    property string outerSizeMode: "full"

    property bool aiChatEnabled: (Config.options?.policies?.ai ?? 0) !== 0
    property bool translatorEnabled: (Config.options?.sidebar?.translator?.enable ?? false)
    property bool animeEnabled: (Config.options?.policies?.weeb ?? 0) !== 0
    property bool animeCloset: (Config.options?.policies?.weeb ?? 0) === 2
    property bool animeScheduleEnabled: Config.options?.sidebar?.animeSchedule?.enable ?? false
    property bool wallhavenEnabled: Config.options?.sidebar?.wallhaven?.enable !== false
    property bool newsEnabled: Config.options?.sidebar?.news?.enable ?? true
    property bool widgetsEnabled: Config.options?.sidebar?.widgets?.enable ?? true
    property bool toolsEnabled: Config.options?.sidebar?.tools?.enable ?? false
    property bool softwareEnabled: Config.options?.sidebar?.software?.enable ?? false
    property bool ytMusicEnabled: Config.options?.sidebar?.ytmusic?.enable ?? false
    // DISABLED: webapps — requires quickshell-webengine
    property bool pluginsEnabled: false // Config.options?.sidebar?.plugins?.enable ?? false

    // Tabs exposing contentPreferredHeight (Widgets) can let the panel hug
    // their content instead of reserving the full output height.
    readonly property real activeTabContentHeight: swipeView.currentItem?.item?.contentPreferredHeight ?? -1
    readonly property bool activeTabEditing: swipeView.currentItem?.item?.editMode ?? false
    readonly property bool fitToContent:
        ((Config.options?.sidebar?.collapseWidgetsTab ?? false)
            || root.outerSizeMode === "fit")
        && !pluginViewActive && !activeTabEditing && activeTabContentHeight > 0
    readonly property real availableContentHeight: Math.max(0,
        root.screenHeight - Appearance.sizes.hyprlandGapsOut * 2)
    readonly property real preferredContentHeight: root.fitToContent
        ? SidebarGeometry.leftFitHeight(root.availableContentHeight,
            sidebarLeftBackground.naturalFitHeight)
        : root.availableContentHeight
    readonly property real minimumUsefulHeight: Math.max(320,
        root.screenHeight * SidebarGeometry.leftFitMinRatio)
    readonly property real minimumUsefulWidth: 320
    readonly property real maximumUsefulWidth: 900

    // ─── WebApp state — DISABLED (requires quickshell-webengine) ─────
    property string _activeWebAppId: ""
    property bool pluginViewActive: false // _activeWebAppId !== ""

    // Persistent cache: pluginId → WebAppView instance
    property var _webViewCache: ({})
    property int _webViewCount: 0  // for reactivity

    // DISABLED: webapps — all functions below are stubs until quickshell-webengine is available
    property var _profileCache: ({})

    function _getOrCreateProfile(id: string): QtObject { return null }

    // ─── WebApp management functions (DISABLED) ──────────────────────

    function openWebApp(id: string, url: string, name: string, icon: string, userscriptSources): void {}
    function closeWebApp(): void {}
    function removeWebApp(id: string): void {}
    function _freezeAllWebApps(): void {}
    function _resumeActiveWebApp(): void {}

    // ─── Restore last active plugin (DISABLED) ──────────────────────
    property bool _restoredLastPlugin: false
    function _tryRestoreLastPlugin(): void {}
    function _doRestoreLastPlugin(): void {}

    readonly property var _tabDefaultOrder: [
        "widgets", "ai", "translator", "anime", "animeSchedule",
        "wallhaven", "news", "ytmusic", "tools", "software"
    ]
    readonly property var resolvedTabOrder: {
        const result = []
        const saved = Config.options?.sidebar?.left?.tabOrder ?? root._tabDefaultOrder
        for (let i = 0; i < saved.length; i++) {
            const id = saved[i]
            if (root._tabDefaultOrder.includes(id) && !result.includes(id)) result.push(id)
        }
        for (let i = 0; i < root._tabDefaultOrder.length; i++) {
            const id = root._tabDefaultOrder[i]
            if (!result.includes(id)) result.push(id)
        }
        return result
    }
    property string selectedTabId: ""
    property bool tabEditMode: false

    // Enabled tabs rendered in the user's stable-id order.
    property var tabButtonList: {
        const result = []
        if (root.widgetsEnabled) result.push({ id: "widgets", icon: "widgets", name: Translation.tr("Widgets") })
        if (root.aiChatEnabled) result.push({ id: "ai", icon: "neurology", name: Translation.tr("Intelligence") })
        if (root.translatorEnabled) result.push({ id: "translator", icon: "translate", name: Translation.tr("Translator") })
        if (root.animeEnabled && !root.animeCloset) result.push({ id: "anime", icon: "bookmark_heart", name: Translation.tr("Anime") })
        if (root.animeScheduleEnabled) result.push({ id: "animeSchedule", icon: "calendar_month", name: Translation.tr("Schedule") })
        if (root.wallhavenEnabled) result.push({ id: "wallhaven", icon: "collections", name: Translation.tr("Wallpapers") })
        if (root.newsEnabled) result.push({ id: "news", icon: "newspaper", name: Translation.tr("News") })
        if (root.ytMusicEnabled) result.push({ id: "ytmusic", icon: "library_music", name: Translation.tr("YT Music") })
        if (root.toolsEnabled) result.push({ id: "tools", icon: "build", name: Translation.tr("Tools") })
        if (root.softwareEnabled) result.push({ id: "software", icon: "store", name: Translation.tr("Software") })
        // DISABLED: webapps — requires quickshell-webengine rebuild
        // if (root.pluginsEnabled) result.push({ id: "plugins", icon: "extension", name: Translation.tr("Web Apps") })
        result.sort((a, b) => root.resolvedTabOrder.indexOf(a.id) - root.resolvedTabOrder.indexOf(b.id))
        return result
    }

    // Find the index of the plugins tab
    readonly property int _pluginsTabIndex: {
        for (let i = 0; i < tabButtonList.length; i++) {
            if (tabButtonList[i].icon === "extension") return i
        }
        return -1
    }

    function focusActiveItem() {
        swipeView.currentItem?.forceActiveFocus()
    }

    function persistTabMove(fromIndex: int, toIndex: int): void {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return
        const movedTab = root.tabButtonList[fromIndex]
        const targetTab = root.tabButtonList[toIndex]
        if (!movedTab || !targetTab) return

        const order = [...root.resolvedTabOrder]
        const fromOrderIndex = order.indexOf(movedTab.id)
        const toOrderIndex = order.indexOf(targetTab.id)
        if (fromOrderIndex < 0 || toOrderIndex < 0) return

        const movedId = order.splice(fromOrderIndex, 1)[0]
        order.splice(toOrderIndex, 0, movedId)
        Config.setNestedValue("sidebar.left.tabOrder", order)
    }

    function syncSelectedTabIndex(): void {
        if (!root.selectedTabId) return
        const index = root.tabButtonList.findIndex(tab => tab.id === root.selectedTabId)
        if (index >= 0 && swipeView.currentIndex !== index) swipeView.currentIndex = index
    }

    function ensureActiveTabReady(): void {
        if (!GlobalStates.sidebarLeftOpen) return
        const currentTab = root.tabButtonList[swipeView.currentIndex]
        if (currentTab?.id === "ai") Ai.ensureInitialized()
    }

    function applyDevDestination(): void {
        if (!DevNavigation.currentDestination.startsWith("sidebar-left/")) return
        const view = DevNavigation.currentDestination.substring("sidebar-left/".length)
        const iconByView = {
            "widgets": "widgets", "ai": "neurology", "translator": "translate",
            "anime": "bookmark_heart", "anime-schedule": "calendar_month",
            "wallhaven": "collections", "news": "newspaper", "ytmusic": "library_music",
            "tools": "build", "software": "store"
        }
        const icon = iconByView[view] ?? ""
        const index = root.tabButtonList.findIndex(tab => tab.icon === icon)
        if (index >= 0) swipeView.currentIndex = index
    }

    onTabButtonListChanged: Qt.callLater(root.syncSelectedTabIndex)

    Component.onCompleted: {
        root.applyDevDestination()
        Qt.callLater(() => {
            root.selectedTabId = root.tabButtonList[swipeView.currentIndex]?.id ?? ""
        })
    }
    Connections {
        target: DevNavigation
        function onCurrentDestinationChanged(): void { root.applyDevDestination() }
    }
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged(): void {
            if (GlobalStates.sidebarLeftOpen) root.ensureActiveTabReady()
            else root.tabEditMode = false
        }
    }

    StyledRectangularShadow {
        target: sidebarLeftBackground
        visible: sidebarLeftBackground.angelEverywhere
            && !Appearance.gameModeMinimal
    }

    IslandPanel {
        anchors.fill: sidebarLeftBackground
        visible: sidebarLeftBackground.islandStyle
        radius: sidebarLeftBackground.radius
        glassEnabled: true
        screen: root.panelScreen ?? root.QsWindow?.window?.screen ?? null
        glassScreenX: Appearance.sizes.hyprlandGapsOut
        glassScreenY: Appearance.sizes.hyprlandGapsOut
        glassScreenWidth: root.screenWidth
        glassScreenHeight: root.screenHeight
    }

    Rectangle {
        id: sidebarLeftBackground

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        readonly property real naturalFitHeight: contentColumn.implicitHeight
            + contentColumn.anchors.topMargin + root.sidebarPadding
        height: root.fitToContent
            ? SidebarGeometry.leftFitHeight(parent.height, naturalFitHeight)
            : parent.height
        Behavior on height {
            enabled: Appearance.animationsEnabled && root.panelVisible
                && !root.geometryPreviewActive
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
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
            && !gameModeMinimal
            && wallpaperUrl.length > 0

        ColorQuantizer {
            id: sidebarLeftWallpaperQuantizer
            source: sidebarLeftBackground.auroraEverywhere ? sidebarLeftBackground.wallpaperUrl : ""
            depth: 0
            rescaleSize: 10
        }

        readonly property color wallpaperDominantColor: (sidebarLeftWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(sidebarLeftBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
        }

        color: (gameModeMinimal || islandStyle) ? "transparent"
             : zzzEverywhere ? Appearance.zzz.chrome
             : regaliaEverywhere ? "transparent"
             : inirEverywhere ? (cardStyle ? Appearance.inir.colLayer1 : Appearance.inir.colLayer0)
             : auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
        border.width: (gameModeMinimal || islandStyle || regaliaEverywhere) ? 0 : zzzEverywhere ? 1 : (angelEverywhere ? Appearance.angel.panelBorderWidth : 1)
        border.color: regaliaEverywhere ? "transparent"
            : zzzEverywhere ? Appearance.zzz.hairline
            : angelEverywhere ? Appearance.angel.colPanelBorder
            : inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
        radius: zzzEverywhere ? Appearance.zzz.panelRadius
            : regaliaEverywhere ? Appearance.regalia.panelRadius
            : angelEverywhere ? Appearance.angel.roundingNormal
            : inirEverywhere ? Appearance.inir.roundingNormal
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
            visible: sidebarLeftBackground.regaliaEverywhere
            fillColor: sidebarLeftBackground.cardStyle ? Appearance.regalia.chassis1 : Appearance.regalia.bg0
            radius: sidebarLeftBackground.radius
            inset: Appearance.regalia.panelInset
            elevated: sidebarLeftBackground.cardStyle
            deepFrame: !sidebarLeftBackground.cardStyle
            glassEnabled: true
        }

        clip: true

        // Mask to the rounded panel shape in ZZZ so NO child (backdrop grid,
        // corner ticks, cards) can re-square the corners — surfaces must never break.
        layer.enabled: root.panelVisible
            && (useWallpaperBackdrop || (zzzEverywhere && !gameModeMinimal))
        layer.smooth: false
        layer.mipmap: false
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: sidebarLeftBackground.width
                height: sidebarLeftBackground.height
                radius: sidebarLeftBackground.radius
            }
        }

        Image {
            id: sidebarLeftBlurredWallpaper
            x: -Appearance.sizes.hyprlandGapsOut
            y: -Appearance.sizes.hyprlandGapsOut
            width: root.screenWidth
            height: root.screenHeight
            visible: sidebarLeftBackground.useWallpaperBackdrop
            source: sidebarLeftBackground.useWallpaperBackdrop ? sidebarLeftBackground.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true

            // OPTIMIZATION: Release FBO when sidebar is hidden (saves ~16 MiB VRAM)
            layer.enabled: Appearance.effectsEnabled && sidebarLeftBackground.useWallpaperBackdrop && root.panelVisible
            layer.effect: MultiEffect {
                source: sidebarLeftBlurredWallpaper
                anchors.fill: source
                saturation: sidebarLeftBackground.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled
                    ? (sidebarLeftBackground.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }

            Rectangle {
                anchors.fill: parent
                color: sidebarLeftBackground.angelEverywhere
                    ? ColorUtils.transparentize((sidebarLeftBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((sidebarLeftBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: sidebarLeftBackground.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        // Angel partial border — elegant half-borders
        AngelPartialBorder {
            visible: sidebarLeftBackground.angelEverywhere
            targetRadius: sidebarLeftBackground.radius
            z: 10
        }

        ZzzPanelBackdrop {
            anchors.fill: parent
            visible: sidebarLeftBackground.zzzEverywhere && opacity > 0
            label: "INTELLIGENCE"
            index: "L"
            ghostText: "LEFT"
            accentColor: Appearance.zzz.chromeStroke
            showTicks: false
            showBurst: false
            showGrid: true
            horizontalBias: 0.18
            verticalBias: 0.04
            ghostWidthFactor: 0.86
            ghostStrength: 0.7
            z: 0
        }

        // ZZZ content wash: a subtle stepped tile plate lifts the content area
        // off the bare chrome so cards/text read cleanly while the structural
        // hairlines stay. Kept low-alpha so chrome + ghost marks still breathe.
        Rectangle {
            anchors.fill: parent
            visible: sidebarLeftBackground.zzzEverywhere
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
            anchors.topMargin: sidebarLeftBackground.angelEverywhere ? sidebarPadding + 4
                : sidebarLeftBackground.inirEverywhere ? sidebarPadding + 6 : sidebarPadding - 4
            spacing: sidebarLeftBackground.angelEverywhere ? sidebarPadding + 2
                : sidebarLeftBackground.inirEverywhere ? sidebarPadding + 4 : sidebarPadding

            // Tab bar — hidden when webapp is fullscreen in sidebar
            Toolbar {
                id: toolbarContainer
                Layout.alignment: Qt.AlignHCenter
                enableShadow: false
                padding: 6
                implicitHeight: tabBar.implicitHeight + padding * 2
                transparent: Appearance.zzzEverywhere || Appearance.auroraEverywhere || Appearance.inirEverywhere
                visible: !root.pluginViewActive

                ToolbarTabBar {
                    id: tabBar
                    Layout.alignment: Qt.AlignHCenter
                    maxWidth: Math.max(0, root.width - (root.sidebarPadding * 2) - 64)
                    tabButtonList: root.tabButtonList
                    reorderEnabled: root.tabEditMode
                    onReorderRequested: (fromIndex, toIndex) => root.persistTabMove(fromIndex, toIndex)
                    // Don't bind to swipeView - let tabBar be the source of truth
                    onCurrentIndexChanged: swipeView.currentIndex = currentIndex
                }

                ToolbarButton {
                    id: tabEditButton
                    Layout.preferredWidth: 38
                    visible: root.tabButtonList.length > 1
                    toggled: root.tabEditMode
                    downAction: () => root.tabEditMode = !root.tabEditMode
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.tabEditMode ? "done" : "edit"
                        iconSize: 19
                        color: tabEditButton.toggled
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer2
                    }
                    StyledToolTip {
                        text: root.tabEditMode
                            ? Translation.tr("Finish arranging tabs")
                            : Translation.tr("Arrange sidebar tabs")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: !root.fitToContent
                implicitHeight: {
                    if (root.activeTabContentHeight <= 0) return 0
                    if (root.fitToContent)
                        return Math.round(root.activeTabContentHeight)
                    const chromeHeight = contentColumn.anchors.topMargin + root.sidebarPadding
                        + (toolbarContainer.visible ? toolbarContainer.implicitHeight + contentColumn.spacing : 0)
                    return Math.round(Math.max(0,
                        Math.min(root.activeTabContentHeight,
                            root.height - chromeHeight)))
                }
                radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                color: Appearance.zzzEverywhere ? "transparent"
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? "transparent"
                     : Appearance.colors.colLayer1
                border.width: Appearance.zzzEverywhere ? 0
                    : Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                    : Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.zzzEverywhere ? "transparent"
                    : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
                // Organic morph on style/shape switch (organic-transitions)
                Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                // SwipeView with normal tab content
                SwipeView {
                    id: swipeView
                    anchors.fill: parent
                    spacing: 10
                    visible: !root.pluginViewActive
                    // Sync back to tabBar when swiping
                    onCurrentIndexChanged: {
                        tabBar.setCurrentIndex(currentIndex)
                        const currentTab = root.tabButtonList[currentIndex]
                        root.selectedTabId = currentTab?.id ?? ""
                        root.ensureActiveTabReady()
                    }
                    interactive: !root.tabEditMode
                        && !(currentItem?.item?.editMode ?? false)
                        && !(currentItem?.item?.dragPending ?? false)

                    clip: true
                    layer.enabled: root.panelVisible && !Appearance.gameModeMinimal
                    layer.smooth: false
                    layer.mipmap: false
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: swipeView.width
                            height: swipeView.height
                            radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                            Behavior on radius {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }

                    Repeater {
                        model: root.tabButtonList
                        delegate: Loader {
                            required property var modelData
                            required property int index
                            active: SwipeView.isCurrentItem || SwipeView.isNextItem || SwipeView.isPreviousItem
                            sourceComponent: {
                                switch (modelData.icon) {
                                    case "widgets": return widgetsComp
                                    case "neurology": return aiChatComp
                                    case "translate": return translatorComp
                                    case "bookmark_heart": return animeComp
                                    case "calendar_month": return animeScheduleComp
                                    case "collections": return wallhavenComp
                                    case "newspaper": return newsComp
                                    case "library_music": return ytMusicComp
                                    case "build": return toolsComp
                                    case "store": return softwareComp
                                    // DISABLED: webapps
                                    // case "extension": return pluginsComp
                                    default: return null
                                }
                            }
                        }
                    }
                }

                // ── WebApp overlay ───────────────────────────────────
                // WebAppViews live HERE, above the SwipeView.
                // Visibility controlled by: active webapp + sidebar open state.
                Item {
                    id: webAppOverlay
                    anchors.fill: parent
                    visible: root.pluginViewActive && GlobalStates.sidebarLeftOpen
                    z: 5
                }
            }
        }

        Component { id: widgetsComp; WidgetsView {} }
        Component { id: aiChatComp; AiChat {} }
        Component { id: translatorComp; Translator {} }
        Component { id: animeComp; Anime {} }
        Component { id: animeScheduleComp; AnimeScheduleView {} }
        Component {
            id: wallhavenComp
            WallhavenView {
                screenWidth: root.screenWidth
                screenHeight: root.screenHeight
                panelScreen: root.panelScreen
            }
        }
        Component { id: newsComp; NewsView {} }
        Component { id: ytMusicComp; InnerTuneView {} }
        Component { id: toolsComp; ToolsView {} }
        Component { id: softwareComp; SoftwareView {} }
        // DISABLED: webapps — requires quickshell-webengine rebuild
        // Component {
        //     id: pluginsComp
        //     PluginsTab {
        //         activePluginId: root._activeWebAppId
        //         onPluginRequested: (id, url, name, icon, userscriptSources) => root.openWebApp(id, url, name, icon, userscriptSources)
        //         onPluginCloseRequested: root.closeWebApp()
        //         onPluginRemoved: (id) => root.removeWebApp(id)
        //     }
        // }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.tabEditMode) {
                    root.tabEditMode = false
                    event.accepted = true
                    return
                }
                // If webapp is open, close it first (go back to list)
                if (root.pluginViewActive) {
                    root.closeWebApp()
                    event.accepted = true
                    return
                }
                GlobalStates.sidebarLeftOpen = false
            }
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    swipeView.incrementCurrentIndex()
                    event.accepted = true
                }
                else if (event.key === Qt.Key_PageUp) {
                    swipeView.decrementCurrentIndex()
                    event.accepted = true
                }
                else if (event.key === Qt.Key_O) {
                    GlobalStates.sidebarLeftExpanded = !GlobalStates.sidebarLeftExpanded
                    event.accepted = true
                }
                else if (event.key === Qt.Key_P) {
                    GlobalStates.sidebarLeftOpen = false
                    GlobalStates.sidebarLeftExpanded = false
                    GlobalStates.aiChatDetached = true
                    event.accepted = true
                }
            }
        }
    }

    // The panel window remains output-height while fit-to-content is active.
    // Treat the vacated strip as backdrop so clicks there still dismiss it.
    MouseArea {
        anchors.top: sidebarLeftBackground.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        enabled: sidebarLeftBackground.height < root.height - 1
        onClicked: GlobalStates.sidebarLeftOpen = false
    }

    // ── Restore last active plugin (DISABLED — webapps) ────────────
    // Connections {
    //     target: Config
    //     function onReadyChanged() {
    //         if (Config.ready && root.pluginsEnabled) {
    //             root._tryRestoreLastPlugin()
    //         }
    //     }
    // }

    // Component.onCompleted: {
    //     if (Config.ready && root.pluginsEnabled) {
    //         root._tryRestoreLastPlugin()
    //     }
    // }
}
