import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

BarButton {
    id: root

    rightInset: 6
    leftPadding: 12
    rightPadding: 12

    checked: GlobalStates.waffleNotificationCenterOpen
    onClicked: {
        GlobalStates.waffleNotificationCenterOpen = !GlobalStates.waffleNotificationCenterOpen;
    }

    contentItem: Item {
        implicitHeight: contentLayout.implicitHeight
        implicitWidth: contentLayout.implicitWidth
        Row {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 7
            
            Column {
                anchors.verticalCenter: parent.verticalCenter
                WText {
                    anchors.right: parent.right
                    text: DateTime.time
                }
                WText {
                    anchors.right: parent.right
                    text: DateTime.date
                }
            }

            // Notification indicators
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Silent mode indicator
                FluentIcon {
                    visible: Notifications.silent
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "alert-snooze"
                    implicitSize: 18
                    filled: true
                }

                // Unread notification badge
                Rectangle {
                    visible: !Notifications.silent && Notifications.list.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: notifCount.implicitWidth + 8
                    height: 18
                    radius: 9
                    color: Looks.colors.accent

                    WText {
                        id: notifCount
                        anchors.centerIn: parent
                        text: Notifications.list.length > 99 ? "99+" : String(Notifications.list.length)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Looks.colors.bg0
                    }
                }
            }
        }
    }

    BarToolTip {
        id: tooltip
        extraVisibleCondition: root.shouldShowTooltip
        text: {
            const dateStr = Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d, yyyy")
            const timeStr = Qt.locale().toString(DateTime.clock.date, "ddd hh:mm AP")
            const notifStr = Notifications.list.length > 0 
                ? "\n" + Translation.tr("%1 notification(s)").arg(Notifications.list.length)
                : ""
            return dateStr + "\n\n" + timeStr + notifStr
        }
    }
}
