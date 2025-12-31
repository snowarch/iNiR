import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.fillHeight: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options?.resources?.updateInterval ?? 3000
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }

    // Volume popup
    property bool volumePopupVisible: false
    
    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.volumePopupVisible = false
    }

    Loader {
        id: volumePopupLoader
        active: root.volumePopupVisible
        sourceComponent: PopupWindow {
            visible: true
            color: "transparent"
            anchor {
                window: root.QsWindow.window
                item: root
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            implicitWidth: popupContent.width + 16
            implicitHeight: popupContent.height + 16

            Rectangle {
                id: popupContent
                anchors.centerIn: parent
                width: volumeRow.width + 12
                height: volumeRow.height + 8
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                     : Appearance.colors.colLayer3
                border.width: 1
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.colors.colLayer3Hover

                Row {
                    id: volumeRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.activePlayer?.volume ?? 0) === 0 ? "volume_off" : "volume_up"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer3
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round((root.activePlayer?.volume ?? 0) * 100) + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer3
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer?.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer?.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer?.next();
            } else if (event.button === Qt.LeftButton) {
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            }
        }
        onWheel: (event) => {
            if (!activePlayer?.volumeSupported) return
            const step = 0.05
            if (event.angleDelta.y > 0) activePlayer.volume = Math.min(1, activePlayer?.volume + step)
            else if (event.angleDelta.y < 0) activePlayer.volume = Math.max(0, activePlayer?.volume - step)
            volumePopupVisible = true
            hideTimer.restart()
        }
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: 4
        anchors.fill: parent

        ClippedFilledCircularProgress {
            id: mediaCircProg
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: (activePlayer && activePlayer.length > 0) ? (activePlayer.position / activePlayer.length) : 0
            implicitSize: 22
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: activePlayer?.playbackState === MprisPlaybackState.Playing

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        StyledText {
            visible: Config.options.bar.verbose
            width: rowLayout.width - (CircularProgress.size + rowLayout.spacing * 2)
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true // Ensures the text takes up available space
            Layout.rightMargin: rowLayout.spacing
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight // Truncates the text on the right
            color: Appearance.colors.colOnLayer1
            text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
        }

    }

}
