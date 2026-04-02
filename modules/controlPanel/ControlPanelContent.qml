pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

Item {
    id: root
    property int screenWidth: 1920
    property int screenHeight: 1080
    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true
    readonly property bool showMediaSection: Config.options?.controlPanel?.showMediaSection ?? true
    readonly property bool showWeatherSection: Config.options?.controlPanel?.showWeatherSection ?? true
    readonly property bool showWallpaperSection: Config.options?.controlPanel?.showWallpaperSection ?? true
    readonly property bool showSystemSection: Config.options?.controlPanel?.showSystemSection ?? true
    readonly property bool showSlidersSection: Config.options?.controlPanel?.showSlidersSection ?? true
    readonly property bool showQuickActionsSection: Config.options?.controlPanel?.showQuickActionsSection ?? true
    
    implicitHeight: background.implicitHeight
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    
    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl
    readonly property bool useWallpaperBackdrop: root.auroraEverywhere && !root.inirEverywhere && !Appearance.gameModeMinimal && root.wallpaperUrl.length > 0
    
    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? root.wallpaperUrl : ""
        depth: 0
        rescaleSize: 10
    }
    
    readonly property color wallpaperDominantColor: (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    }

    // Shadow
    StyledRectangularShadow {
        target: background
        visible: (Appearance.angelEverywhere || (!root.inirEverywhere && !root.auroraEverywhere)) && !Appearance.gameModeMinimal
    }

    Rectangle {
        id: background
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: flickable.contentHeight + 24
        
        color: root.inirEverywhere ? Appearance.inir.colLayer0
             : root.auroraEverywhere ? ColorUtils.applyAlpha((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : Appearance.colors.colLayer0
        
        radius: root.angelEverywhere ? Appearance.angel.roundingLarge
            : root.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large
        
        border.width: root.inirEverywhere ? 1 : (root.auroraEverywhere ? 1 : 1)
        border.color: root.angelEverywhere ? Appearance.angel.colBorder
                    : root.inirEverywhere ? Appearance.inir.colBorder 
                    : root.auroraEverywhere ? Appearance.aurora.colTooltipBorder 
                    : Appearance.colors.colLayer0Border
        
        clip: true

        layer.enabled: root.useWallpaperBackdrop
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // Aurora blurred wallpaper
        Image {
            id: blurredWallpaper
            anchors.centerIn: parent
            width: root.screenWidth
            height: root.screenHeight
            visible: root.useWallpaperBackdrop
            source: root.useWallpaperBackdrop ? root.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && root.auroraEverywhere && !root.inirEverywhere
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1 : 0
            }

            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity)
                    : ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: root.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        // Content
        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: root.compactMode ? 10 : 12
            clip: true
            contentWidth: width
            contentHeight: contentLayout.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000

            ColumnLayout {
                id: contentLayout
                width: flickable.width
                spacing: root.compactMode ? 8 : 10

                // Header with User Profile
                ProfileHeader {}

                // Date/Time header
                DateTimeHeader {}

                // Media Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showMediaSection
                    sourceComponent: Component { MediaSection {} }
                }

                // Wallpaper Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showWallpaperSection
                    sourceComponent: Component { WallpaperSection {} }
                }

                // Weather Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showWeatherSection
                    sourceComponent: Component { WeatherSection {} }
                }

                // System Info Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showSystemSection
                    sourceComponent: Component { SystemSection {} }
                }

                // Volume & Brightness Sliders
                Loader {
                    Layout.fillWidth: true
                    active: root.showSlidersSection
                    sourceComponent: Component { SlidersSection {} }
                }

                // Quick actions
                Loader {
                    Layout.fillWidth: true
                    active: root.showQuickActionsSection
                    sourceComponent: Component { QuickActionsSection {} }
                }

                Item { Layout.preferredHeight: 8 }
            }

            WheelHandler {
                onWheel: (event) => {
                    const delta = event.angleDelta.y / 3
                    flickable.contentY = Math.max(0, Math.min(
                        flickable.contentHeight - flickable.height,
                        flickable.contentY - delta
                    ))
                }
            }
        }
    }
}
