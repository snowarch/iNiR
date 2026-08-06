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

    // ── Staggered section entrance on panel open ──────────────────
    property int _entranceCascade: GlobalStates.controlPanelOpen ? 99 : -1

    Timer {
        id: _entranceCascadeTimer
        interval: 45
        repeat: true
        onTriggered: {
            if (root._entranceCascade < 7) root._entranceCascade++
            else stop()
        }
    }

    Connections {
        id: _cascadeConnections
        target: GlobalStates
        function onControlPanelOpenChanged() {
            if (GlobalStates.controlPanelOpen) {
                root._entranceCascade = -1
                _entranceCascadeTimer.start()
            }
        }
    }
    
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere
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
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
    }

    // Shadow
    StyledRectangularShadow {
        target: background
        visible: !root.zzzEverywhere && (Appearance.angelEverywhere || (!root.inirEverywhere && !root.auroraEverywhere)) && !Appearance.gameModeMinimal
    }

    Rectangle {
        id: background
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: flickable.contentHeight + (root.compactMode ? 20 : 24)

        color: root.zzzEverywhere ? Appearance.zzz.bg0
             : root.inirEverywhere ? Appearance.inir.colLayer0
             : root.auroraEverywhere ? ColorUtils.applyAlpha((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : Appearance.colors.colLayer0
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        radius: root.zzzEverywhere ? 0
            : root.angelEverywhere ? Appearance.angel.roundingLarge
            : root.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large

        border.width: root.zzzEverywhere ? 0 : (root.inirEverywhere ? 1 : (root.auroraEverywhere ? 1 : 1))
        border.color: root.zzzEverywhere ? "transparent"
                    : root.angelEverywhere ? Appearance.angel.colBorder
                    : root.inirEverywhere ? Appearance.inir.colBorder
                    : root.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer0Border

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
        
        clip: true

        // ZZZ: mask to chamfered shape so children never escape the cut-corner.
        layer.enabled: root.useWallpaperBackdrop || (root.zzzEverywhere && !Appearance.gameModeMinimal)
        layer.effect: GE.OpacityMask {
            maskSource: Item {
                width: background.width
                height: background.height
                visible: false
                Rectangle {
                    anchors.fill: parent
                    visible: !root.zzzEverywhere
                    radius: background.radius
                    color: "white"
                }
                ZzzPlate {
                    anchors.fill: parent
                    visible: root.zzzEverywhere
                    chamfer: Appearance.zzz.cutCorner
                    chamferBottomRight: !Appearance.zzz.round
                    fillColor: "white"
                }
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

        ZzzPanelBackdrop {
            anchors.fill: parent
            label: "CONTROL"
            index: "CP"
            ghostText: "CTRL"
            accentColor: Appearance.zzz.accent
            burstTriad: true
            showTicks: false
            horizontalBias: 0.05
            verticalBias: 0.02
            ghostWidthFactor: 0.82
            z: 0
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

            Behavior on contentY {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.scroll.duration; easing.type: Appearance.animation.scroll.type; easing.bezierCurve: Appearance.animation.scroll.bezierCurve }
            }

            ColumnLayout {
                id: contentLayout
                width: flickable.width
                spacing: root.compactMode ? 4 : 6

                // Header with User Profile
                ProfileHeader {
                    opacity: root._entranceCascade >= 0 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                }

                // Date/Time header
                DateTimeHeader {
                    opacity: root._entranceCascade >= 1 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                }

                // Media Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showMediaSection
                    opacity: root._entranceCascade >= 2 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    sourceComponent: Component { MediaSection {} }
                }

                // Wallpaper Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showWallpaperSection
                    opacity: root._entranceCascade >= 3 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    sourceComponent: Component { WallpaperSection {} }
                }

                // Weather Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showWeatherSection
                    opacity: root._entranceCascade >= 4 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    sourceComponent: Component { WeatherSection {} }
                }

                // System Info Section
                Loader {
                    Layout.fillWidth: true
                    active: root.showSystemSection
                    opacity: root._entranceCascade >= 5 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    sourceComponent: Component { SystemSection {} }
                }

                // Volume & Brightness Sliders
                Loader {
                    Layout.fillWidth: true
                    active: root.showSlidersSection
                    opacity: root._entranceCascade >= 6 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    sourceComponent: Component { SlidersSection {} }
                }

                // Quick actions
                Loader {
                    Layout.fillWidth: true
                    active: root.showQuickActionsSection
                    opacity: root._entranceCascade >= 7 ? 1 : 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                    sourceComponent: Component { QuickActionsSection {} }
                }

                Item { Layout.preferredHeight: 2 }
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

    // ZZZ: hairline stroke following the chamfered outline. Sibling of background,
    // not child — if it lives inside the layer.enabled Rectangle, the OpacityMask
    // clips the stroke's outer half and it renders as broken dots.
    ZzzPlate {
        anchors.fill: background
        visible: root.zzzEverywhere
        fillColor: "transparent"
        strokeColor: Appearance.zzz.hairline
        strokeWidth: 1
        chamfer: Appearance.zzz.cutCorner
        chamferBottomRight: !Appearance.zzz.round
    }
}
