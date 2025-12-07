import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

BarButton {
    id: root

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

            // Mic indicator (only when in use)
            IconHoverArea {
                id: micHoverArea
                visible: Audio.micBeingAccessed
                iconItem: Item {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 20
                    implicitHeight: 20

                    FluentIcon {
                        anchors.fill: parent
                        icon: (Audio.source?.audio?.muted ?? false) ? "mic-off" : "mic-on"
                    }

                    Rectangle {
                        visible: !(Audio.source?.audio?.muted ?? true)
                        width: 4
                        height: 4
                        radius: 2
                        color: Looks.colors.accent
                        anchors { top: parent.top; right: parent.right; topMargin: -1; rightMargin: -1 }

                        SequentialAnimation on opacity {
                            running: Audio.micBeingAccessed && !(Audio.source?.audio?.muted ?? true)
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 1200 }
                            NumberAnimation { to: 1.0; duration: 1200 }
                        }
                    }
                }
                onClicked: Audio.toggleMicMute()
            }

            IconHoverArea {
                id: internetHoverArea
                iconItem: FluentIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: WIcons.internetIcon
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
                iconItem: FluentIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: WIcons.batteryIcon
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
        extraVisibleCondition: root.shouldShowTooltip && micHoverArea.containsMouse
        text: Translation.tr("Microphone: %1").arg((Audio.source?.audio?.muted ?? false) ? Translation.tr("Muted") : Translation.tr("In use"))
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
