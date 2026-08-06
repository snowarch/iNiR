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
 * VisualizerPlayer - Visualizer-focused design
 * Prominent audio visualizer with compact layout
 * Supports wave (default) and bars (VU meter) modes
 */
Item {
    id: root
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    property real screenX: 0
    property real screenY: 0

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    PlayerBase {
        id: playerBase
        player: root.player
    }

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
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper : "transparent"
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : "transparent"
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

        // Wave visualizer
        WaveVisualizer {
            visible: root.vizType === "wave" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right; margins: root.vizPosition === "fill" ? 8 : 0 }
            y: root.vizPosition === "top" ? 0 : (root.vizPosition === "fill" ? 8 : (parent.height - height))
            height: root.vizPosition === "fill" ? (parent.height - 16) : parent.height * 0.4
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000; smoothing: 2
            color: ColorUtils.transparentize(root.themeSourceColor, 0.2)
        }

        // Bar visualizer (VU meter)
        CavaVisualizer {
            visible: root.vizType === "bars" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right; margins: root.vizPosition === "fill" ? 8 : 0 }
            y: root.vizPosition === "top" ? 0 : (root.vizPosition === "fill" ? 8 : (parent.height - height))
            height: root.vizPosition === "fill" ? (parent.height - 16) : parent.height * 0.4
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000; smoothing: 2
            barCount: 32; barSpacing: 2; barRadius: 2; barMinHeight: 1
            colorLow: ColorUtils.transparentize(root.themeSourceColor, 0.3)
            colorMed: ColorUtils.transparentize(root.themeSourceColor, 0.1)
            colorHigh: root.themeSourceColor
        }

        // Gradient overlay for readability
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop {
                    position: 0.7
                    color: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.bg0, 0.54) : ColorUtils.transparentize("black", 0.5)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
                GradientStop {
                    position: 1.0
                    color: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.bg0, 0.22) : ColorUtils.transparentize("black", 0.3)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Compact artwork
            PlayerArtwork {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                Layout.alignment: Qt.AlignVCenter
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
                iconSize: 28
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
