import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root
    property bool borderless: Config.options?.bar?.borderless ?? false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string popupMode: Config.options?.media?.popupMode ?? "dock"

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
    
    // Bar-anchored media popup
    property bool barMediaPopupVisible: false
    
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
                edges: (Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom
                gravity: (Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom
            }
            implicitWidth: popupContent.width + 16
            implicitHeight: popupContent.height + 16

            Rectangle {
                id: popupContent
                anchors.centerIn: parent
                width: volumeRow.width + 12
                height: volumeRow.height + 8
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                      : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                     : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer3
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                            : (Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                            : Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
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

    // Backdrop for click-outside-to-close (Niri)
    Loader {
        active: root.barMediaPopupVisible && root.popupMode === "bar" && CompositorService.isNiri
        sourceComponent: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:mediaBackdrop"
            
            MouseArea {
                anchors.fill: parent
                onClicked: root.barMediaPopupVisible = false
            }
        }
    }

    // Bar-anchored media controls popup (when popupMode === "bar")
    Loader {
        id: barMediaPopupLoader
        active: root.barMediaPopupVisible && root.popupMode === "bar"
        sourceComponent: PopupWindow {
            id: barMediaPopup
            visible: true
            color: "transparent"
            anchor {
                window: root.QsWindow.window
                item: root
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            implicitWidth: mediaPopupContent.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: mediaPopupContent.height + Appearance.sizes.elevationMargin * 2

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: root.barMediaPopupVisible = false
                z: -1
            }

            BarMediaPopup {
                id: mediaPopupContent
                anchors.centerIn: parent
                onCloseRequested: root.barMediaPopupVisible = false
                
                // Entry animation
                opacity: 0
                scale: 0.9
                transformOrigin: Config.options.bar.bottom ? Item.Bottom : Item.Top
                
                Component.onCompleted: {
                    entryAnim.start()
                }
                
                ParallelAnimation {
                    id: entryAnim
                    NumberAnimation { target: mediaPopupContent; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: mediaPopupContent; property: "scale"; to: 1; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
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
                if (root.popupMode === "bar") {
                    root.barMediaPopupVisible = !root.barMediaPopupVisible
                } else {
                    GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
                }
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
            colPrimary: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                : Appearance.colors.colOnSecondaryContainer
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
                    color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                        : Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        StyledText {
            visible: Config.options?.bar?.verbose ?? true
            width: rowLayout.width - (CircularProgress.size + rowLayout.spacing * 2)
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.rightMargin: rowLayout.spacing
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Appearance.inirEverywhere ? Appearance.inir.colText
                : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                : Appearance.colors.colOnLayer1
            text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
        }

    }

}
