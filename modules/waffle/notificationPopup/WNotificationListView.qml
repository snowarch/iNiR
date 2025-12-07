pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.waffle.looks
import qs.services

/**
 * Windows 11 style notification list with smooth transitions
 */
ListView {
    id: root

    spacing: 8
    cacheBuffer: 300

    property int dragIndex: -1
    property real dragDistance: 0

    function resetDrag() {
        dragIndex = -1
        dragDistance = 0
    }

    // Smooth add transition - disabled for performance
    add: Transition {
        enabled: false
        ParallelAnimation {
            NumberAnimation { 
                property: "opacity"
                from: 0; to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation { 
                property: "x"
                from: 50; to: 0
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95; to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // Smooth remove transition - disabled for performance
    remove: Transition {
        enabled: false
        ParallelAnimation {
            NumberAnimation { 
                property: "opacity"
                from: 1; to: 0
                duration: 150
                easing.type: Easing.InCubic
            }
            NumberAnimation { 
                property: "x"
                from: 0; to: 80
                duration: 200
                easing.type: Easing.InCubic
            }
        }
    }

    // Smooth reposition - disabled for performance
    displaced: Transition {
        enabled: false
        NumberAnimation { 
            properties: "x,y"
            duration: 200
            easing.type: Easing.OutCubic
        }
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
}
