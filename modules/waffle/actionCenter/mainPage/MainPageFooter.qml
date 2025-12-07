import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

FooterRectangle {

    // Battery button
    WBorderlessButton {
        visible: Battery.available
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12

        contentItem: Row {
            spacing: 4

            FluentIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: WIcons.batteryLevelIcon ?? "battery-0"
                FluentIcon {
                    anchors.fill: parent
                    icon: WIcons.batteryIcon ?? "battery-0"
                }
            }
            WText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round((Battery?.percentage ?? 0) * 100)}%`
            }
        }
    }

    // Settings button
    WBorderlessButton {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12

        onClicked: {
            GlobalStates.waffleActionCenterOpen = false;
            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "settings", "open"]);
        }

        contentItem: FluentIcon {
            icon: "settings"
        }
    }
}
