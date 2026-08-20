pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.mediaControls.components

Item {
    id: root
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
    property real screenX: 0
    property real screenY: 0

    PlayerBase {
        id: playerBase
        player: root.player
    }

    property color themeSourceColor: playerBase.artDominantColor
    property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.themeSourceColor
    }

    readonly property color ink: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? playerBase.inirText : (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
    readonly property color accent: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.inirEverywhere ? playerBase.inirPrimary
        : root.themeSourceColor

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    StyledRectangularShadow {
        target: card
        visible: !Appearance.zzzEverywhere && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.inirEverywhere ? playerBase.inirLayer1 : (root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : "transparent"
        clip: true

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: card.width
                height: card.height
                radius: card.radius
            }
        }

        // No MultiEffect inside this OpacityMask layer: it has crashed the shell.
        Item {
            anchors.fill: parent
            visible: playerBase.displayedArtFilePath !== ""

            StyledImage {
                id: coverImage
                anchors.fill: parent
                source: playerBase.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                smooth: true
                sourceSize.width: 72
                sourceSize.height: 72
                opacity: 0.55
            }

            Rectangle {
                anchors.fill: parent
                color: card.color
                opacity: 0.82
            }
        }

        ZzzGraphicPlate {
            anchors.fill: parent
            accentColor: root.blendedColors?.colPrimary ?? Appearance.zzz.accent
        }

        Item {
            anchors.fill: parent
            anchors.margins: 20
            opacity: lyricSheet.hasLyrics ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            WaveVisualizer {
                anchors.fill: parent
                visible: root.vizType === "wave" && root.vizPosition !== "none"
                live: playerBase.effectiveIsPlaying
                points: root.visualizerPoints
                maxVisualizerValue: 1000
                smoothing: 2
                color: ColorUtils.transparentize(root.accent, 0.35)
            }

            CavaVisualizer {
                anchors.fill: parent
                visible: root.vizType === "bars" && root.vizPosition !== "none"
                live: playerBase.effectiveIsPlaying
                points: root.visualizerPoints
                maxVisualizerValue: 1000
                smoothing: 2
                barCount: 32
                barSpacing: 3
                barRadius: 2
                barMinHeight: 1
                colorLow: ColorUtils.transparentize(root.accent, 0.55)
                colorMed: ColorUtils.transparentize(root.accent, 0.25)
                colorHigh: root.accent
            }

            StyledText {
                anchors.centerIn: parent
                width: parent.width
                visible: root.vizPosition === "none"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.applyAlpha(root.ink, 0.6)
                text: Translation.tr("No synced lyrics")
            }
        }

        PlayerLyrics {
            id: lyricSheet
            showPlaceholder: false
            opacity: lyricSheet.hasLyrics ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 24
            anchors.bottomMargin: 24
            textAlignment: Text.AlignHCenter
            lineSpacing: 12
            baseSize: Appearance.font.pixelSize.large
            activeScale: 1.22
            activeColor: Appearance.zzzEverywhere ? (root.blendedColors?.colPrimary ?? Appearance.zzz.accent) : Appearance.inirEverywhere ? playerBase.inirPrimary : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
            textColor: ColorUtils.applyAlpha(root.ink, 0.75)
            indicatorColor: root.blendedColors?.colPrimaryContainer ?? Appearance.colors.colPrimaryContainer
        }
    }
}
