pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.shared.mediaControls.components

/**
 * DiscPlayer - Spinning Cookie12Sided vinyl record inside a circular progress ring.
 * Click the disc to toggle play/pause; wheel to seek; hover reveals previous/next controls.
 */
Item {
    id: root
    property bool motion: true
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.rounding.large
    property real screenX: 0
    property real screenY: 0

    PlayerBase {
        id: playerBase
        player: root.player
    }

    property color themeSourceColor: playerBase.artDominantColor
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.themeSourceColor }
    readonly property QtObject effectiveColors: Appearance.editorialEverywhere && Appearance.colors
        ? Appearance.colors : root.blendedColors

    readonly property real side: Math.max(96, Math.min(root.width, root.height) - Appearance.sizes.elevationMargin)
    readonly property real ringDiameter: root.side - 18
    readonly property real discDiameter: root.ringDiameter - 24
    readonly property real progress: playerBase.effectiveIsLive ? 1 : playerBase.effectiveLength > 0
        ? Math.max(0, Math.min(1, playerBase.effectivePosition / playerBase.effectiveLength)) : 0

    property real discAngle: 0
    FrameAnimation {
        running: root.visible && root.motion && playerBase.effectiveIsPlaying && Appearance.animationsEnabled
        onTriggered: root.discAngle = (root.discAngle + frameTime * 28) % 360
    }

    Item {
        id: discContainer
        anchors.centerIn: parent
        width: root.side
        height: root.side

        CircularProgress {
            anchors.centerIn: parent
            implicitSize: Math.round(root.ringDiameter)
            lineWidth: 6
            value: root.progress
            enableAnimation: false
            colPrimary: root.themeSourceColor
            colSecondary: ColorUtils.applyAlpha(effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0, 0.16)
        }

        // Spinning cookie12 vinyl record
        Item {
            id: vinyl
            anchors.centerIn: parent
            width: root.discDiameter
            height: root.discDiameter
            rotation: root.discAngle
            scale: discTap.pressed ? 0.94 : 1.0

            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            MaterialShape {
                id: vinylMask
                anchors.fill: parent
                implicitSize: vinyl.width
                shape: MaterialShape.Shape.Cookie12Sided
                color: effectiveColors?.colLayer1 ?? Appearance.colors.colLayer1
                visible: false
            }

            MaterialShape {
                anchors.fill: parent
                implicitSize: vinyl.width
                shape: MaterialShape.Shape.Cookie12Sided
                color: effectiveColors?.colLayer1 ?? Appearance.colors.colLayer1
                visible: !playerBase.downloaded
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "album"
                    iconSize: Math.round(vinyl.width * 0.36)
                    color: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
                }
            }

            Image {
                anchors.fill: parent
                source: playerBase.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                visible: playerBase.downloaded
                layer.enabled: playerBase.downloaded
                layer.effect: GE.OpacityMask {
                    maskSource: vinylMask
                }
            }

            // Vinyl spindle hole & label ring
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(vinyl.width * 0.32)
                height: width
                radius: width / 2
                color: ColorUtils.applyAlpha(Appearance.colors.colLayer0, 0.72)
                border.width: 2
                border.color: root.themeSourceColor

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.32)
                    height: width
                    radius: width / 2
                    color: root.themeSourceColor
                }
            }
        }

        // Hover overlay with title and transport buttons
        Rectangle {
            anchors.centerIn: vinyl
            width: vinyl.width
            height: vinyl.height
            radius: width / 2
            color: ColorUtils.applyAlpha("#000000", discHover.hovered ? 0.46 : 0.0)
            visible: opacity > 0
            opacity: discHover.hovered ? 1 : 0

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.76
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: playerBase.effectiveTitle
                    color: "#ffffff"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: playerBase.effectiveArtist
                    color: ColorUtils.applyAlpha("#ffffff", 0.78)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                PlayerControls {
                    Layout.alignment: Qt.AlignHCenter
                    isPlaying: playerBase.effectiveIsPlaying
                    canGoPrevious: playerBase.effectiveCanGoPrevious
                    canGoNext: playerBase.effectiveCanGoNext
                    buttonSize: 28
                    playButtonSize: 36
                    iconSize: 18
                    playIconSize: 22
                    iconColor: "#ffffff"
                    playIconColor: "#ffffff"
                    playButtonColor: root.themeSourceColor
                    onPreviousClicked: playerBase.previous()
                    onPlayPauseClicked: playerBase.togglePlaying()
                    onNextClicked: playerBase.next()
                }
            }
        }

        HoverHandler { id: discHover }

        MouseArea {
            id: discTap
            anchors.fill: vinyl
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: playerBase.togglePlaying()
            onWheel: event => {
                if (!playerBase.effectiveCanSeek) return
                const delta = event.angleDelta.y > 0 ? 5 : -5
                playerBase.seek(Math.max(0, Math.min(playerBase.effectiveLength, playerBase.effectivePosition + delta)))
            }
        }
    }
}
