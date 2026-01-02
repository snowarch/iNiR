import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property int screenWidth: 1920
    property int screenHeight: 1080
    
    // Delay content loading until after animation completes
    property bool contentReady: false
    
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen) {
                root.contentReady = false
                contentDelayTimer.restart()
            }
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
    property bool wallhavenEnabled: Config.options.sidebar?.wallhaven?.enable !== false
    property bool widgetsEnabled: Config.options?.sidebar?.widgets?.enable ?? true
    property var tabButtonList: [
        ...(root.widgetsEnabled ? [{"icon": "widgets", "name": Translation.tr("Widgets")}] : []),
        ...(root.aiChatEnabled ? [{"icon": "neurology", "name": Translation.tr("Intelligence")}] : []),
        ...(root.translatorEnabled ? [{"icon": "translate", "name": Translation.tr("Translator")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"icon": "bookmark_heart", "name": Translation.tr("Anime")}] : []),
        ...(root.wallhavenEnabled ? [{"icon": "image", "name": Translation.tr("Wallhaven")}] : [])
    ]

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
        property bool cardStyle: Config.options.sidebar?.cardStyle ?? false
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl

        ColorQuantizer {
            id: sidebarLeftWallpaperQuantizer
            source: sidebarLeftBackground.wallpaperUrl
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
        border.width: gameModeMinimal ? 0 : 1
        border.color: Appearance.colors.colLayer0Border
        radius: cardStyle ? Appearance.rounding.normal : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

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
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && !sidebarLeftBackground.gameModeMinimal
            layer.effect: StyledBlurEffect {
                source: sidebarLeftBlurredWallpaper
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize((sidebarLeftBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            anchors.topMargin: Appearance.inirEverywhere ? sidebarPadding + 6 : sidebarPadding
            spacing: Appearance.inirEverywhere ? sidebarPadding + 4 : sidebarPadding

            Toolbar {
                Layout.alignment: Qt.AlignHCenter
                enableShadow: false
                ToolbarTabBar {
                    id: tabBar
                    Layout.alignment: Qt.AlignHCenter
                    maxWidth: Math.max(0, root.width - (root.sidebarPadding * 2) - 16)
                    tabButtonList: root.tabButtonList
                    currentIndex: swipeView.currentIndex
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? "transparent" 
                     : Appearance.colors.colLayer1
                border.width: Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

                SwipeView {
                    id: swipeView
                    anchors.fill: parent
                    spacing: 10
                    currentIndex: tabBar.currentIndex
                    interactive: !(currentItem?.editMode ?? false)

                    onCurrentIndexChanged: {
                        const currentTab = root.tabButtonList[swipeView.currentIndex]
                        if (currentTab?.icon === "neurology") {
                            Ai.ensureInitialized()
                        }
                    }

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
                                    case "image": return wallhavenComp
                                    default: return null
                                }
                            }
                        }
                    }
                }
            }
        }

        Component { id: widgetsComp; WidgetsView {} }
        Component { id: aiChatComp; AiChat {} }
        Component { id: translatorComp; Translator {} }
        Component { id: animeComp; Anime {} }
        Component { id: wallhavenComp; WallhavenView {} }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
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
}
