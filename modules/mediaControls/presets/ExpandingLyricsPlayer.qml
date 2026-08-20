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
    property real radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.verylarge
    property real screenX: 0
    property real screenY: 0

    readonly property bool lyricsExpanded: Config.getNestedValue("background.widgets.mediaControls.lyricsExpanded", false)
    readonly property real headerHeight: root.lyricsExpanded
        ? Math.round(card.height * 0.34)
        : card.height
    readonly property real buttonSize: 34
    readonly property real buttonIconSize: 18

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    PlayerBase {
        id: playerBase
        player: root.player
    }

    property color themeSourceColor: playerBase.artDominantColor
    property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.themeSourceColor
    }

    readonly property color surfaceColor: Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.inirEverywhere ? playerBase.inirLayer1 : (root.blendedColors?.colPrimaryContainer ?? Appearance.colors.colPrimaryContainer)
    readonly property color ink: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? playerBase.inirText : (root.blendedColors?.colOnPrimaryContainer ?? Appearance.colors.colOnPrimaryContainer)
    readonly property color accent: Appearance.zzzEverywhere ? Appearance.zzz.accent : Appearance.inirEverywhere ? playerBase.inirPrimary : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
    readonly property color onAccent: root.blendedColors?.colOnPrimary ?? Appearance.colors.colOnPrimary

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
        color: root.surfaceColor
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

        ZzzGraphicPlate {
            anchors.fill: parent
            accentColor: root.accent
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: root.headerHeight

                Item {
                    id: artRect
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: height

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt : Appearance.inirEverywhere ? playerBase.inirLayer2 : (root.blendedColors?.colSurfaceContainerLow ?? Appearance.colors.colLayer1)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "music_note"
                            fill: 1
                            iconSize: Math.round(root.headerHeight / 3)
                            color: ColorUtils.applyAlpha(root.ink, 0.6)
                            visible: playerBase.displayedArtFilePath === ""
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: playerBase.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        sourceSize.width: artRect.width * 2
                        sourceSize.height: artRect.height * 2
                        visible: playerBase.displayedArtFilePath !== ""
                    }
                }

                ColumnLayout {
                    anchors {
                        left: artRect.right
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: 16
                        rightMargin: 14
                    }
                    spacing: 4

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: playerBase.effectiveArtist || Translation.tr("Play")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: root.ink
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: StringUtils.cleanMusicTitle(playerBase.effectiveTitle) || Translation.tr("Something")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: ColorUtils.applyAlpha(root.ink, 0.65)
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Rectangle {
                        id: controlsPill
                        Layout.alignment: Qt.AlignRight
                        Layout.bottomMargin: 8
                        implicitWidth: controlsRow.implicitWidth + 10
                        implicitHeight: root.buttonSize + 8
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(root.ink, 0.9)

                        RowLayout {
                            id: controlsRow
                            anchors.centerIn: parent
                            spacing: 2

                            RippleButton {
                                implicitWidth: root.buttonSize
                                implicitHeight: root.buttonSize
                                buttonRadius: Appearance.rounding.full
                                colBackground: root.lyricsExpanded ? root.accent : "transparent"
                                colBackgroundHover: root.blendedColors?.colPrimaryContainerHover ?? Appearance.colors.colPrimaryContainerHover
                                colRipple: root.blendedColors?.colPrimaryContainerActive ?? Appearance.colors.colPrimaryContainerActive
                                onClicked: Config.setNestedValue("background.widgets.mediaControls.lyricsExpanded", !root.lyricsExpanded)

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "lyrics"
                                    iconSize: root.buttonIconSize
                                    fill: root.lyricsExpanded ? 1 : 0
                                    color: root.lyricsExpanded ? root.onAccent : root.ink
                                }
                            }

                            MaterialShapeWrappedMaterialSymbol {
                                id: playShape
                                shape: (Appearance.zzzEverywhere || Appearance.inirEverywhere)
                                    ? MaterialShape.Shape.Square
                                    : MaterialShape.Shape.Cookie12Sided
                                color: root.accent
                                colSymbol: root.onAccent
                                text: playerBase.effectiveIsPlaying ? "pause" : "play_arrow"
                                iconSize: root.buttonIconSize + 6
                                fill: 1
                                padding: 8

                                scale: playArea.pressed ? 0.92 : 1.0
                                Behavior on scale {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }

                                MouseArea {
                                    id: playArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: playerBase.togglePlaying()
                                }
                            }

                            RippleButton {
                                implicitWidth: root.buttonSize
                                implicitHeight: root.buttonSize
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: root.blendedColors?.colPrimaryContainerHover ?? Appearance.colors.colPrimaryContainerHover
                                colRipple: root.blendedColors?.colPrimaryContainerActive ?? Appearance.colors.colPrimaryContainerActive
                                onClicked: playerBase.next()

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    iconSize: root.buttonIconSize
                                    fill: 1
                                    color: root.ink
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.lyricsExpanded ? 2 : 0
                visible: root.lyricsExpanded

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    height: 1
                    opacity: 0.15
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.2; color: root.ink }
                        GradientStop { position: 0.8; color: root.ink }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.lyricsExpanded ? Math.max(0, card.height - root.headerHeight - 2) : 0
                visible: root.lyricsExpanded

                PlayerLyrics {
                    id: lyricSheet
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 10
                    anchors.bottomMargin: 14
                    showPlaceholder: false
                    opacity: lyricSheet.hasLyrics ? 1 : 0
                    textAlignment: Text.AlignHCenter
                    baseSize: Appearance.font.pixelSize.normal
                    activeScale: 1.16
                    lineSpacing: 8
                    activeColor: root.accent
                    textColor: ColorUtils.applyAlpha(root.ink, 0.8)
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
                    anchors.fill: parent
                    anchors.margins: 18
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
                        barCount: 30
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
            }
        }
    }
}
