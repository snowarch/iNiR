pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.mediaControls.components

/**
 * FullPlayer - Full-featured player with large artwork and visualizer
 * Default preset, similar to original PlayerControl
 */
Item {
    id: root
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.large
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    property real screenX: 0
    property real screenY: 0

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    // Player logic
    PlayerBase {
        id: playerBase
        player: root.player
    }

    // Adaptive colors from artwork
    // Theme seed for the whole player. Defaults to the album-art colour (floating popup
    // keeps that). Desktop host overrides it with the wallpaper seed for cohesion.
    property color themeSourceColor: playerBase.artDominantColor
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.themeSourceColor }

    StyledRectangularShadow {
        target: card
        visible: !Appearance.zzzEverywhere
            && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper
             : Appearance.inirEverywhere ? playerBase.inirLayer1
             : Appearance.auroraEverywhere ? "transparent"
             : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick : Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : "transparent"
        // Organic morph on style/shape switch (organic-transitions)
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        clip: true

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        ZzzGraphicPlate {
            anchors.fill: parent
            accentColor: blendedColors?.colPrimary ?? Appearance.zzz.accent
        }

        // Aurora glass wallpaper blur
        Image {
            id: auroraWallpaper
            x: -root.screenX - (card.x + (root.width - card.width) / 2)
            y: -root.screenY - (card.y + (root.height - card.height) / 2)
            width: Quickshell.screens[0]?.width ?? 1920
            height: Quickshell.screens[0]?.height ?? 1080
            visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere && !Appearance.zzzEverywhere
            source: visible ? Wallpapers.effectiveWallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: Quickshell.screens[0]?.width ?? 1920
            sourceSize.height: Quickshell.screens[0]?.height ?? 1080
            smooth: true
            mipmap: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && Appearance.auroraEverywhere && !Appearance.inirEverywhere
            layer.effect: MultiEffect {
                source: auroraWallpaper
                anchors.fill: source
                saturation: Appearance.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1 : 0
            }
        }

        // Aurora tint overlay
        Rectangle {
            anchors.fill: parent
            visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere && !Appearance.zzzEverywhere
            color: Appearance.angelEverywhere
                ? ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
                : ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.aurora.popupTransparentize)
        }

        // Cover art background
        Image {
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            opacity: Appearance.zzzEverywhere ? 0.24 : Appearance.inirEverywhere ? 0.15 : (Appearance.auroraEverywhere ? 0.2 : 0.5)
            visible: playerBase.displayedArtFilePath !== ""

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.inirEverywhere ? 0.3 : 0.15
                blurMax: 16
                saturation: Appearance.inirEverywhere ? 0.1 : 0.3
            }
        }

        // Gradient overlay for Material
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.zzzEverywhere && !Appearance.inirEverywhere && !Appearance.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop {
                    position: 0.35
                    color: ColorUtils.transparentize(
                        blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3
                    )
                }
                GradientStop {
                    position: 1.0
                    color: ColorUtils.transparentize(
                        blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15
                    )
                }
            }
        }

        // Visualizer overlay
        WaveVisualizer {
            visible: root.vizType === "wave" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 35
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000; smoothing: 2
            color: ColorUtils.transparentize(root.themeSourceColor, 0.4)
        }
        CavaVisualizer {
            visible: root.vizType === "bars" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 35
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000; smoothing: 2
            barCount: 32; barSpacing: 2; barRadius: 2; barMinHeight: 1
            colorLow: ColorUtils.transparentize(root.themeSourceColor, 0.3)
            colorMed: ColorUtils.transparentize(root.themeSourceColor, 0.1)
            colorHigh: root.themeSourceColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Cover art
            PlayerArtwork {
                Layout.preferredWidth: card.height - 24
                Layout.preferredHeight: card.height - 24
                artSource: playerBase.displayedArtFilePath
                transitionKey: playerBase.mediaTransitionKey
                downloaded: playerBase.downloaded
                slideDirection: playerBase.slideDirection
                artRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                    : Appearance.inirEverywhere
                    ? Appearance.inir.roundingSmall
                    : Appearance.rounding.small
                placeholderColor: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                    : Appearance.inirEverywhere
                    ? playerBase.inirLayer2
                    : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                iconColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                    : Appearance.inirEverywhere
                    ? playerBase.inirTextSecondary
                    : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
            }

            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(playerBase.effectiveTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Medium
                    font.italic: Appearance.zzzEverywhere
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                        : Appearance.inirEverywhere
                        ? playerBase.inirText
                        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: 6
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: playerBase.effectiveArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                        : Appearance.inirEverywhere
                        ? playerBase.inirTextSecondary
                        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Item { Layout.fillHeight: true }

                // Progress bar
                PlayerProgress {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    position: playerBase.effectivePosition
                    length: playerBase.effectiveLength
                    canSeek: playerBase.effectiveCanSeek
                    isPlaying: playerBase.effectiveIsPlaying
                    highlightColor: Appearance.zzzEverywhere ? (blendedColors?.colPrimary ?? Appearance.zzz.accent)
                        : Appearance.inirEverywhere
                        ? playerBase.inirPrimary
                        : Appearance.auroraEverywhere
                            ? Appearance.colors.colPrimary
                            : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                    trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
                        : Appearance.inirEverywhere
                        ? playerBase.inirLayer2
                        : Appearance.auroraEverywhere
                            ? Appearance.aurora.colElevatedSurface
                            : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }

                // Time + controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere
                            ? playerBase.inirText
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    PlayerControls {
                        canGoPrevious: playerBase.effectiveCanGoPrevious
                        canGoNext: playerBase.effectiveCanGoNext
                        isPlaying: playerBase.effectiveIsPlaying
                        buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                            : Appearance.inirEverywhere
                            ? Appearance.inir.roundingSmall
                            : Appearance.rounding.full
                        buttonHoverColor: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere
                                ? Appearance.aurora.colSubSurface
                                : ColorUtils.transparentize(
                                    blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5
                                )
                        buttonRippleColor: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28)
                            : Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere
                                ? Appearance.aurora.colSubSurfaceActive
                                : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        iconColor: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere
                            ? playerBase.inirText
                            : Appearance.auroraEverywhere
                                ? Appearance.colors.colOnLayer0
                                : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        playIconColor: Appearance.zzzEverywhere ? (blendedColors?.colPrimary ?? Appearance.zzz.accent)
                            : Appearance.inirEverywhere
                            ? playerBase.inirPrimary
                            : Appearance.auroraEverywhere
                                ? Appearance.colors.colOnLayer0
                                : Appearance.colors.colOnLayer1
                        onPreviousClicked: playerBase.previous()
                        onPlayPauseClicked: playerBase.togglePlaying()
                        onNextClicked: playerBase.next()
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere
                            ? playerBase.inirText
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }
    }
}
