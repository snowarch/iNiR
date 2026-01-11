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
import Quickshell.Wayland

import qs.modules.bar as Bar

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string popupMode: Config.options?.media?.popupMode ?? "dock"
    property bool volumePopupVisible: false
    property bool barMediaPopupVisible: false

    Layout.fillHeight: true
    implicitHeight: mediaCircProg.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options?.resources?.updateInterval ?? 3000
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }

    Timer {
        id: volumeHideTimer
        interval: 1000
        onTriggered: root.volumePopupVisible = false
    }

    acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
    hoverEnabled: true
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
        if (event.angleDelta.y > 0) activePlayer.volume = Math.min(1, activePlayer.volume + step)
        else if (event.angleDelta.y < 0) activePlayer.volume = Math.max(0, activePlayer.volume - step)
        root.volumePopupVisible = true
        volumeHideTimer.restart()
    }

    ClippedFilledCircularProgress {
        id: mediaCircProg
        anchors.centerIn: parent
        implicitSize: 20

        lineWidth: Appearance.rounding.unsharpen
        value: activePlayer?.position / activePlayer?.length
        colPrimary: Appearance.colors.colOnSecondaryContainer
        enableAnimation: false

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

    // Volume popup (shows on hover or scroll)
    Bar.StyledPopup {
        hoverTarget: root
        active: (root.volumePopupVisible || root.containsMouse) && !GlobalStates.mediaControlsOpen && !root.barMediaPopupVisible

        Row {
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                text: (activePlayer?.volume ?? 0) === 0 ? "volume_off" : "volume_up"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.m3colors.m3onSurface
            }
            StyledText {
                text: Math.round((activePlayer?.volume ?? 0) * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3onSurface
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
                // For vertical bar: popup appears to the right (left bar) or left (right bar)
                edges: (Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right
                gravity: (Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right
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
            }
        }
    }
}
