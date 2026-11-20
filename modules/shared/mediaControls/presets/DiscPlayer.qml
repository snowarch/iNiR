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
 * DiscPlayer - Spinning Cookie12Sided vinyl record. Click the disc to toggle play/pause; wheel to seek.
 * Small: the disc alone inside its progress ring, with a play key. Medium: the disc, title and artist, play key.
 * Large: Medium plus the progress bar and previous / next.
 */
Item {
    id: root
    property bool motion: true
    property string sizeClass: "medium"
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

    readonly property bool small: root.sizeClass === "small"
    readonly property bool large: root.sizeClass === "large"
    readonly property real inset: Math.max(8, Appearance.sizes.elevationMargin)
    // the disc's square: the whole box when small, the box's height when medium, the upper part when large
    readonly property real side: root.small ? Math.max(96, Math.min(root.width, root.height) - Appearance.sizes.elevationMargin)
        : root.large ? Math.max(64, Math.min(root.width - root.inset * 2, root.height * 0.52))
        : Math.max(64, root.height - root.inset * 2)
    readonly property real ringDiameter: root.side - 18
    readonly property real discDiameter: root.small ? root.ringDiameter - 24 : Math.round(root.side * 0.94)
    readonly property real progress: playerBase.effectiveIsLive ? 1 : playerBase.effectiveLength > 0
        ? Math.max(0, Math.min(1, playerBase.effectivePosition / playerBase.effectiveLength)) : 0
    readonly property bool spinning: root.visible && root.motion && playerBase.effectiveIsPlaying && Appearance.animationsEnabled

    Item {
        id: discContainer
        width: root.side
        height: root.side
        x: root.sizeClass === "medium" ? root.inset : Math.round((root.width - width) / 2)
        y: root.large ? root.inset : Math.round((root.height - height) / 2)

        CircularProgress {
            anchors.centerIn: parent
            visible: root.small
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
            scale: discTap.pressed ? 0.94 : 1.0

            // On the render thread; pausing keeps the angle and play goes on from it.
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 12860
                loops: Animation.Infinite
                running: true
                paused: !root.spinning
            }

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

        PlayKey {
            visible: root.small
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            size: 34
            isPlaying: playerBase.effectiveIsPlaying
            color: root.themeSourceColor
            onClicked: playerBase.togglePlaying()
        }
    }

    // Medium: beside the disc
    ColumnLayout {
        visible: root.sizeClass === "medium"
        x: discContainer.x + discContainer.width + 14
        y: root.inset
        width: Math.max(0, root.width - x - root.inset)
        height: Math.max(0, root.height - root.inset * 2)
        spacing: 6

        PlayerInfo {
            Layout.fillWidth: true
            title: playerBase.effectiveTitle
            artist: playerBase.effectiveArtist
            titleColor: effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
            artistColor: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
            titleSize: Appearance.font.pixelSize.normal
            artistSize: Appearance.font.pixelSize.smaller
            slideDirection: playerBase.slideDirection
        }
        Item { Layout.fillHeight: true }
        PlayKey {
            Layout.alignment: Qt.AlignLeft
            size: 40
            isPlaying: playerBase.effectiveIsPlaying
            color: root.themeSourceColor
            onClicked: playerBase.togglePlaying()
        }
    }

    // Large: under the disc
    ColumnLayout {
        visible: root.large
        x: root.inset
        y: discContainer.y + discContainer.height + 8
        width: Math.max(0, root.width - root.inset * 2)
        height: Math.max(0, root.height - y - root.inset)
        spacing: 6

        PlayerInfo {
            Layout.fillWidth: true
            title: playerBase.effectiveTitle
            artist: playerBase.effectiveArtist
            titleColor: effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
            artistColor: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
            titleSize: Appearance.font.pixelSize.normal
            artistSize: Appearance.font.pixelSize.smaller
            slideDirection: playerBase.slideDirection
        }
        Item { Layout.fillHeight: true }
        PlayerProgress {
            motion: root.motion
            Layout.fillWidth: true
            implicitHeight: 16
            position: playerBase.effectivePosition
            length: playerBase.effectiveLength
            live: playerBase.effectiveIsLive
            canSeek: playerBase.effectiveCanSeek
            isPlaying: playerBase.effectiveIsPlaying
            highlightColor: root.themeSourceColor
            trackColor: ColorUtils.applyAlpha(root.themeSourceColor, 0.24)
            onSeekRequested: seconds => playerBase.seek(seconds)
        }
        PlayerControls {
            Layout.alignment: Qt.AlignHCenter
            isPlaying: playerBase.effectiveIsPlaying
            canGoPrevious: playerBase.effectiveCanGoPrevious
            canGoNext: playerBase.effectiveCanGoNext
            buttonSize: 32
            playButtonSize: 40
            iconSize: 20
            playIconSize: 22
            playButtonColor: root.themeSourceColor
            playIconColor: ColorUtils.contrastColor(root.themeSourceColor)
            onPreviousClicked: playerBase.previous()
            onPlayPauseClicked: playerBase.togglePlaying()
            onNextClicked: playerBase.next()
        }
    }
}
