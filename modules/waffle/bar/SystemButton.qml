import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks
import Quickshell.Services.Pipewire

BarButton {
    id: root

    // Screen share detection: niri in any link
    readonly property bool screenShareActive: (Pipewire.links?.values ?? []).some(link => {
        const src = link?.source?.name ?? "";
        const tgt = link?.target?.name ?? "";
        return src === "niri" || tgt === "niri";
    })

    checked: GlobalStates.waffleActionCenterOpen
    onClicked: {
        GlobalStates.waffleActionCenterOpen = !GlobalStates.waffleActionCenterOpen;
    }

    contentItem: Item {
        anchors.fill: parent
        implicitHeight: column.implicitHeight
        implicitWidth: column.implicitWidth
        Row {
            id: column
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 4

            IconHoverArea {
                id: recordingHoverArea
                visible: RecorderStatus.isRecording
                iconItem: Item {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 20
                    implicitHeight: 20

                    FluentIcon {
                        anchors.fill: parent
                        icon: "record"
                        color: Looks.colors.danger
                    }

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: Looks.colors.danger
                        anchors { top: parent.top; right: parent.right; topMargin: -1; rightMargin: -1 }

                        SequentialAnimation on opacity {
                            running: RecorderStatus.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 1200 }
                            NumberAnimation { to: 1.0; duration: 1200 }
                        }
                    }
                }
                onClicked: GlobalActions.runById("screen-record", "")
            }

            // Mic indicator (only when in use)
            IconHoverArea {
                id: micHoverArea
                readonly property bool micInUse: Privacy.micActive || (Audio?.micBeingAccessed ?? false)
                visible: micInUse
                iconItem: Item {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 20
                    implicitHeight: 20

                    FluentIcon {
                        anchors.fill: parent
                        icon: Audio.micMuted ? "mic-off" : "mic-on"
                    }

                    Rectangle {
                        visible: !Audio.micMuted
                        width: 4
                        height: 4
                        radius: 2
                        color: Looks.colors.accent
                        anchors { top: parent.top; right: parent.right; topMargin: -1; rightMargin: -1 }

                        SequentialAnimation on opacity {
                            running: micHoverArea.micInUse && !Audio.micMuted
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 1200 }
                            NumberAnimation { to: 1.0; duration: 1200 }
                        }
                    }
                }
                onClicked: Audio.toggleMicMute()
            }

            // Screen sharing indicator (only when active)
            IconHoverArea {
                id: screenShareHoverArea
                visible: root.screenShareActive
                iconItem: FluentIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "eye-filled"
                }
            }

            IconHoverArea {
                id: internetHoverArea
                iconItem: FluentIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: WIcons.internetIcon
                    filled: true
                }
            }

            IconHoverArea {
                id: volumeHoverArea
                iconItem: FluentIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: WIcons.volumeIcon
                }
                onScrollDown: Audio.decrementVolume();
                onScrollUp: Audio.incrementVolume();
            }

            IconHoverArea {
                id: batteryHoverArea
                visible: Battery?.available ?? false
                iconItem: Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: WIcons.batteryIcon
                    }
                    WText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round((Battery?.percentage ?? 0) * 100)}%`
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.fg
                    }
                }
            }
        }
    }

    component IconHoverArea: FocusedScrollMouseArea {
        id: hoverArea
        required property var iconItem
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        hoverEnabled: true
        implicitHeight: hoverArea.iconItem.implicitHeight
        implicitWidth: hoverArea.iconItem.implicitWidth

        onPressed: (event) => event.accepted = false; // Don't consume clicks

        children: [iconItem]
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && recordingHoverArea.containsMouse
        text: Translation.tr("Screen recording: Active")
    }
    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && micHoverArea.containsMouse
        text: Translation.tr("Microphone: %1").arg(Audio.micMuted ? Translation.tr("Muted") : Translation.tr("In use"))
    }
    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && screenShareHoverArea.containsMouse
        text: Translation.tr("Screen sharing: Active")
    }
    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && internetHoverArea.containsMouse
        text: Translation.tr("%1\nInternet access").arg(Network.ethernet ? Translation.tr("Network") : Network.networkName)
    }
    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && volumeHoverArea.containsMouse
        text: Translation.tr("Speakers (%1): %2") //
            .arg(Audio.sink?.nickname || Audio.sink?.description || Translation.tr("Unknown")) //
            .arg(Audio.sink?.audio.muted ? Translation.tr("Muted") : `${Math.round(Audio.sink?.audio.volume * 100) || 0}%`) //
    }
    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && batteryHoverArea.containsMouse
        text: Translation.tr("Battery: %1%2") //
            .arg(`${Math.round(Battery.percentage * 100) || 0}%`) //
            .arg(Battery.isPluggedIn ? (" " + Translation.tr("(Plugged in)")) : "")
    }
}
