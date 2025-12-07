import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

BodyRectangle {
    id: root
    anchors.fill: parent
    implicitHeight: 230

    readonly property int notificationCount: Notifications.list.length
    readonly property bool hasNotifications: notificationCount > 0

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        // Header with count and actions
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 8
            spacing: 8

            WText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                text: root.hasNotifications 
                    ? Translation.tr("Notifications") + ` (${root.notificationCount})`
                    : Translation.tr("Notifications")
                font.pixelSize: Looks.font.pixelSize.large
                font.weight: Looks.font.weight.strong
            }

            // Do Not Disturb toggle
            SmallBorderedIconButton {
                icon.name: Notifications.silent ? "alert-off" : "alert-snooze"
                checked: Notifications.silent
                onClicked: Notifications.silent = !Notifications.silent

                WToolTip {
                    text: Notifications.silent 
                        ? Translation.tr("Do Not Disturb is on") 
                        : Translation.tr("Enable Do Not Disturb")
                    visible: parent.hovered
                }
            }

            // Mark all as read / Clear all
            SmallBorderedIconAndTextButton {
                visible: root.hasNotifications
                iconVisible: false
                text: Translation.tr("Clear all")
                onClicked: Notifications.discardAllNotifications()
            }
        }

        // DND status banner
        Rectangle {
            id: dndBanner
            visible: Notifications.silent
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            implicitHeight: visible ? dndRow.implicitHeight + 12 : 0
            radius: Looks.radius.medium
            color: ColorUtils.applyAlpha(Looks.colors.warning, 0.15)
            border.color: ColorUtils.applyAlpha(Looks.colors.warning, 0.3)
            border.width: 1

            RowLayout {
                id: dndRow
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                FluentIcon {
                    icon: "alert-off"
                    implicitSize: 14
                    color: Looks.colors.warning
                }

                WText {
                    Layout.fillWidth: true
                    text: Translation.tr("Do Not Disturb is enabled")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.warning
                }

                WBorderlessButton {
                    implicitWidth: turnOffText.implicitWidth + 16
                    implicitHeight: 24
                    onClicked: Notifications.silent = false

                    contentItem: WText {
                        id: turnOffText
                        anchors.centerIn: parent
                        text: Translation.tr("Turn off")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.accent
                    }
                }
            }
        }

        // Notification list
        ListView {
            id: notificationListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            cacheBuffer: 200

            // Smooth transitions
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: 30; to: 0; duration: 200; easing.type: Easing.OutCubic }
                }
            }
            
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "x"; to: 50; duration: 150; easing.type: Easing.InCubic }
                }
            }
            
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
            }

            model: Notifications.appNameList
            delegate: WNotificationGroup {
                required property int index
                required property var modelData
                width: ListView.view.width
                notificationGroup: Notifications.groupsByAppName[modelData]
            }

            // Empty state
            Item {
                visible: !root.hasNotifications
                anchors.fill: parent

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    FluentIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "alert"
                        implicitSize: 48
                        color: Looks.colors.inactiveIcon
                    }

                    WText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No new notifications")
                        font.pixelSize: Looks.font.pixelSize.large
                        color: Looks.colors.subfg
                    }

                    WText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("You're all caught up!")
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.inactiveIcon
                    }
                }
            }
        }
    }
}
