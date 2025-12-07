pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt.labs.synchronizer
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

WBarAttachedPanelContent {
    id: root

    readonly property bool barAtBottom: Config.options.waffles.bar.bottom
    revealFromSides: true
    revealFromLeft: false

    property bool collapsed: false
    readonly property int notificationCount: Notifications.list.length
    readonly property bool hasNotifications: notificationCount > 0

    contentItem: ColumnLayout {
        id: contentLayout
        spacing: 12

        // Notification area
        Item {
            id: notificationArea
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(300, notificationPane.implicitHeight)
            implicitWidth: notificationPane.implicitWidth

            WPane {
                id: notificationPane
                anchors.fill: parent
                contentItem: NotificationPaneContent {
                    implicitWidth: calendarColumnLayout.implicitWidth
                }
            }
        }

        // Calendar pane
        WPane {
            id: calendarPane
            Layout.fillWidth: true
            contentItem: WPanelPageColumn {
                id: calendarColumnLayout
                DateHeader {
                    Layout.fillWidth: true
                    Synchronizer on collapsed {
                        property alias source: root.collapsed
                    }
                }

                WPanelSeparator {
                    visible: !root.collapsed
                }

                CalendarWidget {
                    Layout.fillWidth: true
                    Synchronizer on collapsed {
                        property alias source: root.collapsed
                    }
                }

                WPanelSeparator {}

                FocusFooter {
                    Layout.fillWidth: true
                }
            }
        }
    }

    // Keyboard shortcuts
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && root.hasNotifications) {
            // Delete key clears all notifications
            Notifications.discardAllNotifications()
            event.accepted = true
        } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
            // Ctrl+D toggles Do Not Disturb
            Notifications.silent = !Notifications.silent
            event.accepted = true
        }
    }
}
