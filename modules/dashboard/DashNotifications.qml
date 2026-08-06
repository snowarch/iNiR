import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notifications

/**
 * Notification center card. Reuses the sidebar notification list (controls,
 * grouping and clear actions included). Fills the column height.
 */
DashCard {
    id: root
    title: Translation.tr("Notifications")
    icon: "notifications"
    Layout.fillHeight: true

    NotificationList {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 180
    }
}
