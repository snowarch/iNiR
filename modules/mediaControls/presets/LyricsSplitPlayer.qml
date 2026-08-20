pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
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
    readonly property color subInk: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? playerBase.inirTextSecondary : (root.blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
    readonly property color accent: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.inirEverywhere ? playerBase.inirPrimary
        : root.themeSourceColor

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    readonly property real topRowHeight: Math.max(0, card.height - 28
        - infoRow.implicitHeight - seekRow.implicitHeight - 16)
    readonly property real artSize: Math.min(card.width * 0.32, root.topRowHeight)
    readonly property bool sheetFits: root.topRowHeight >= 72
    readonly property bool showSheet: lyricSheet.hasLyrics && root.sheetFits

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
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper
            : Appearance.inirEverywhere ? playerBase.inirLayer1
            : ColorUtils.mix(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0,
                root.accent, 0.94)
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : "transparent"
        clip: true

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
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
            visible: !Appearance.zzzEverywhere && playerBase.displayedArtFilePath !== ""

            StyledImage {
                anchors.fill: parent
                source: playerBase.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                smooth: true
                sourceSize.width: 48
                sourceSize.height: 48
                opacity: 0.6
            }

            Rectangle {
                anchors.fill: parent
                color: card.color
                opacity: 0.8
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(card.color, 0.0) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(card.color, 0.45) }
                }
            }
        }

        ZzzGraphicPlate {
            anchors.fill: parent
            accentColor: root.blendedColors?.colPrimary ?? Appearance.zzz.accent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                id: artRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                spacing: 14

                PlayerArtwork {
                    Layout.preferredWidth: root.artSize
                    Layout.preferredHeight: root.artSize
                    Layout.alignment: Qt.AlignVCenter
                    artSource: playerBase.displayedArtFilePath
                    transitionKey: playerBase.mediaTransitionKey
                    downloaded: playerBase.downloaded
                    slideDirection: playerBase.slideDirection
                    artRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.normal
                    placeholderColor: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt : Appearance.inirEverywhere ? playerBase.inirLayer2 : (root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                    iconColor: root.subInk
                    iconSize: 32
                }

                Item {
                    id: rightSlot
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    PlayerLyrics {
                        id: lyricSheet
                        anchors.fill: parent
                        opacity: root.showSheet ? 1 : 0
                        showPlaceholder: false
                        baseSize: Appearance.font.pixelSize.normal
                        activeScale: 1.14
                        lineSpacing: 6
                        textAlignment: Text.AlignLeft
                        activeColor: root.accent
                        textColor: root.subInk
                        indicatorColor: root.blendedColors?.colPrimaryContainer ?? Appearance.colors.colPrimaryContainer

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                            }
                        }
                    }

                    Item {
                        id: sheetFallback
                        anchors.fill: parent
                        opacity: root.showSheet ? 0 : 1
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
                            barCount: 28
                            barSpacing: 2
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
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: ColorUtils.applyAlpha(root.subInk, 0.7)
                            text: lyricSheet.hasLyrics ? "" : Translation.tr("No synced lyrics")
                        }
                    }
                }
            }

            RowLayout {
                id: infoRow
                Layout.fillWidth: true
                Layout.minimumHeight: implicitHeight
                spacing: 10

                PlayerInfo {
                    Layout.fillWidth: true
                    title: playerBase.effectiveTitle
                    artist: playerBase.effectiveArtist
                    titleSize: Appearance.font.pixelSize.large
                    titleWeight: Font.DemiBold
                    artistSize: Appearance.font.pixelSize.smaller
                    slideDirection: playerBase.slideDirection
                    titleColor: root.ink
                    artistColor: root.subInk
                }

                StyledText {
                    Layout.alignment: Qt.AlignBottom
                    text: `${StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition)} / ${StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)}`
                    color: root.subInk
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            RowLayout {
                id: seekRow
                Layout.fillWidth: true
                Layout.minimumHeight: implicitHeight
                spacing: 10

                PlayerProgress {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    position: playerBase.effectivePosition
                    length: playerBase.effectiveLength
                    canSeek: playerBase.effectiveCanSeek
                    isPlaying: playerBase.effectiveIsPlaying
                    highlightColor: root.accent
                    trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack : Appearance.inirEverywhere ? playerBase.inirLayer2 : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : (root.blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }

                PlayerControls {
                    Layout.alignment: Qt.AlignVCenter
                    buttonSize: 28
                    playButtonSize: 36
                    iconSize: 18
                    playIconSize: 20
                    canGoPrevious: playerBase.effectiveCanGoPrevious
                    canGoNext: playerBase.effectiveCanGoNext
                    isPlaying: playerBase.effectiveIsPlaying
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    buttonHoverColor: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : ColorUtils.transparentize(root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                    buttonRippleColor: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28) : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : (root.blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                    iconColor: root.ink
                    playButtonColor: root.accent
                    playIconColor: ColorUtils.ensureReadable(
                        root.blendedColors?.colOnPrimary ?? Appearance.colors.colOnPrimary,
                        root.accent, 4.5)
                    onPreviousClicked: playerBase.previous()
                    onPlayPauseClicked: playerBase.togglePlaying()
                    onNextClicked: playerBase.next()
                }
            }
        }
    }
}
