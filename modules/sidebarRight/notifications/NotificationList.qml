import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    Component.onCompleted: Notifications.ensureInitialized()

    NotificationListView { // Scrollable window
        id: listview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 5

        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: listview.width
                height: listview.height
                radius: 0
            }
        }

        popup: false
    }

    // Placeholder when list is empty
    MaterialPlaceholderMessage {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: statusRow.top
            topMargin: 24
            bottomMargin: 28
        }
        maximumWidth: 280
        compact: true
        shown: Notifications.list.length === 0
        icon: "notifications_active"
        text: Notifications.silent ? Translation.tr("Muted") : Translation.tr("Clear")
        shape: MaterialShape.Shape.Ghostish
    }

    ButtonGroup {
        id: statusRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "notifications_paused"
            toggled: Notifications.silent
            onClicked: () => {
                Notifications.silent = !Notifications.silent;
            }
        }
        NotificationStatusButton {
            enabled: false
            Layout.fillWidth: true
            buttonText: Translation.tr("%1 notifications").arg(Notifications.list.length)
        }
        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "delete_sweep"
            onClicked: () => {
                Notifications.discardAllNotifications()
            }
        }
    }
}
