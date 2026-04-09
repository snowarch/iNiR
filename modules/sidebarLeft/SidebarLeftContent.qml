import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarLeft.animeSchedule
import qs.modules.sidebarLeft.reddit
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

    // Delay content loading until after animation completes
    property bool contentReady: false

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen) {
                root.contentReady = false
                contentDelayTimer.restart()
            }
            // WebApps keep running in background — audio, WebSockets, etc.
            // stay alive even when sidebar is closed. No freeze/resume.
        }
    }

    Timer {
        id: contentDelayTimer
        interval: 200
        onTriggered: root.contentReady = true
    }

    property bool aiChatEnabled: (Config.options?.policies?.ai ?? 0) !== 0
    property bool translatorEnabled: (Config.options?.sidebar?.translator?.enable ?? false)
    property bool animeEnabled: (Config.options?.policies?.weeb ?? 0) !== 0
    property bool animeCloset: (Config.options?.policies?.weeb ?? 0) === 2
    property bool animeScheduleEnabled: Config.options?.sidebar?.animeSchedule?.enable ?? false
    property bool redditEnabled: Config.options?.sidebar?.reddit?.enable ?? false
    property bool wallhavenEnabled: Config.options?.sidebar?.wallhaven?.enable !== false
    property bool widgetsEnabled: Config.options?.sidebar?.widgets?.enable ?? true
    property bool toolsEnabled: Config.options?.sidebar?.tools?.enable ?? false
    property bool softwareEnabled: Config.options?.sidebar?.software?.enable ?? false
    property bool ytMusicEnabled: Config.options?.sidebar?.ytmusic?.enable ?? false
    // DISABLED: webapps — requires quickshell-webengine rebuild
    property bool pluginsEnabled: false // Config.options?.sidebar?.plugins?.enable ?? false

    // ─── WebApp state — DISABLED (requires quickshell-webengine) ─────
    property string _activeWebAppId: ""
    property bool pluginViewActive: false // _activeWebAppId !== ""

    // Persistent cache: pluginId → WebAppView instance
    // These NEVER get destroyed by contentReady or SwipeView lifecycle
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

    // Tab button list - simple static order
    property var tabButtonList: {
        const result = []
        if (root.widgetsEnabled) result.push({ icon: "widgets", name: Translation.tr("Widgets") })
        if (root.aiChatEnabled) result.push({ icon: "neurology", name: Translation.tr("Intelligence") })
        if (root.translatorEnabled) result.push({ icon: "translate", name: Translation.tr("Translator") })
        if (root.animeEnabled && !root.animeCloset) result.push({ icon: "bookmark_heart", name: Translation.tr("Anime") })
        if (root.animeScheduleEnabled) result.push({ icon: "calendar_month", name: Translation.tr("Schedule") })
        if (root.redditEnabled) result.push({ icon: "forum", name: Translation.tr("Reddit") })
        if (root.wallhavenEnabled) result.push({ icon: "collections", name: Translation.tr("Wallhaven") })
        if (root.ytMusicEnabled) result.push({ icon: "library_music", name: Translation.tr("YT Music") })
        if (root.toolsEnabled) result.push({ icon: "build", name: Translation.tr("Tools") })
        if (root.softwareEnabled) result.push({ icon: "store", name: Translation.tr("Software") })
        // DISABLED: webapps — requires quickshell-webengine rebuild
        // if (root.pluginsEnabled) result.push({ icon: "extension", name: Translation.tr("Web Apps") })
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

    implicitHeight: sidebarLeftBackground.implicitHeight
    implicitWidth: sidebarLeftBackground.implicitWidth

    StyledRectangularShadow {
        target: sidebarLeftBackground
        visible: !Appearance.gameModeMinimal
    }
    Rectangle {
        id: sidebarLeftBackground

        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false
        readonly property bool angelEverywhere: Appearance.angelEverywhere
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property string wallpaperUrl: {
            const _dep1 = WallpaperListener.multiMonitorEnabled
            const _dep2 = WallpaperListener.effectivePerMonitor
            const _dep3 = Wallpapers.effectiveWallpaperUrl
            return WallpaperListener.wallpaperUrlForScreen(root.panelScreen)
        }

        ColorQuantizer {
            id: sidebarLeftWallpaperQuantizer
            source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? sidebarLeftBackground.wallpaperUrl : ""
            depth: 0
            rescaleSize: 10
        }

        readonly property color wallpaperDominantColor: (sidebarLeftWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(sidebarLeftBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
        }

        color: gameModeMinimal ? "transparent"
             : auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
        border.width: gameModeMinimal ? 0 : (angelEverywhere ? Appearance.angel.panelBorderWidth : 1)
        border.color: angelEverywhere ? Appearance.angel.colPanelBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
        radius: angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : cardStyle ? Appearance.rounding.normal : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

        clip: true

        layer.enabled: auroraEverywhere && !gameModeMinimal
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
            visible: sidebarLeftBackground.auroraEverywhere && !sidebarLeftBackground.gameModeMinimal
            source: sidebarLeftBackground.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && sidebarLeftBackground.auroraEverywhere && !sidebarLeftBackground.gameModeMinimal
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
            targetRadius: sidebarLeftBackground.radius
            z: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            anchors.topMargin: Appearance.angelEverywhere ? sidebarPadding + 4
                : Appearance.inirEverywhere ? sidebarPadding + 6 : sidebarPadding
            spacing: Appearance.angelEverywhere ? sidebarPadding + 2
                : Appearance.inirEverywhere ? sidebarPadding + 4 : sidebarPadding

            // Tab bar — hidden when webapp is fullscreen in sidebar
            Toolbar {
                id: toolbarContainer
                Layout.alignment: Qt.AlignHCenter
                enableShadow: false
                transparent: Appearance.auroraEverywhere || Appearance.inirEverywhere
                visible: !root.pluginViewActive
                ToolbarTabBar {
                    id: tabBar
                    Layout.alignment: Qt.AlignHCenter
                    maxWidth: Math.max(0, root.width - (root.sidebarPadding * 2) - 16)
                    tabButtonList: root.tabButtonList
                    // Don't bind to swipeView - let tabBar be the source of truth
                    onCurrentIndexChanged: swipeView.currentIndex = currentIndex
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? "transparent"
                     : Appearance.colors.colLayer1
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                    : Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

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
                        if (currentTab?.icon === "neurology") {
                            Ai.ensureInitialized()
                        }
                    }
                    interactive: !(currentItem?.item?.editMode ?? false) && !(currentItem?.item?.dragPending ?? false)

                    clip: true
                    layer.enabled: root.contentReady
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: swipeView.width
                            height: swipeView.height
                            radius: Appearance.rounding.small
                        }
                    }

                    Repeater {
                        model: root.contentReady ? root.tabButtonList : []
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
                                    case "forum": return redditComp
                                    case "collections": return wallhavenComp
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
                // They survive contentReady resets and SwipeView destruction.
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
        Component { id: redditComp; RedditView {} }
        Component { id: wallhavenComp; WallhavenView {} }
        Component { id: ytMusicComp; YtMusicView {} }
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
            }
        }
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
