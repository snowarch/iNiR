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
        anchors.leftMargin: Looks.dp(12)

        contentItem: Row {
            spacing: Looks.dp(4)

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
        anchors.rightMargin: Looks.dp(12)

        onClicked: {
            GlobalStates.waffleActionCenterOpen = false;
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"]);
        }

        contentItem: FluentIcon {
            icon: "settings"
        }
    }
}
