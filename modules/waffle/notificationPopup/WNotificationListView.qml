pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.common.widgets

ListView {
    id: root

    spacing: 8
    clip: true

    // Drag state for swipe-to-dismiss (same as ii)
    property int dragIndex: -1
    property real dragDistance: 0

    function resetDrag() {
        dragIndex = -1
        dragDistance = 0
    }

    model: ScriptModel {
        values: Notifications.popupAppNameList
    }

    delegate: WNotificationGroup {
        required property int index
        required property var modelData

        width: root.width
        notificationGroup: Notifications.popupGroupsByAppName[modelData]
        qmlParent: root
    }

    // Same animations as ii NotificationGroup
    add: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "x"
            from: 80
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: 150
        }
    }

    displaced: Transition {
        NumberAnimation {
            properties: "y"
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
}
