pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

StyledListView { // Scrollable window
    id: root
    property bool popup: false
    // History-only filter; popups are never filtered.
    property string filterQuery: ""

    spacing: 3

    // Sidebar: full transitions with pop-in; Popup: lightweight entrance only
    popin: !popup
    animateAppearance: !popup

    // Popup entrance: opacity fade + horizontal slide (no height change to avoid Wayland stair-stepping)
    add: Transition {
        enabled: root.popup || root.animateAppearance
        NumberAnimation {
            property: "opacity"
            from: 0; to: 1
            duration: root.popup ? Appearance.animation.elementMoveFast.duration : Appearance.animation.elementMove.duration
            easing.type: root.popup ? Appearance.animation.elementMoveFast.type : Appearance.animation.elementMove.type
            easing.bezierCurve: root.popup ? Appearance.animation.elementMoveFast.bezierCurve : Appearance.animation.elementMove.bezierCurve
        }
        NumberAnimation {
            property: root.popup ? "x" : "scale"
            from: root.popup ? 24 : 0; to: root.popup ? 0 : 1
            duration: root.popup ? Appearance.animation.elementMoveFast.duration : Appearance.animation.elementMove.duration
            easing.type: root.popup ? Appearance.animation.elementMoveFast.type : Appearance.animation.elementMove.type
            easing.bezierCurve: root.popup ? Appearance.animation.elementMoveFast.bezierCurve : Appearance.animation.elementMove.bezierCurve
        }
    }

    // Custom removeDisplaced for popup mode: smooth gap-filling when a group is dismissed.
    // Uses elementMoveFast for snappy feel without Wayland stair-stepping.
    removeDisplaced: Transition {
        enabled: root.popup
        NumberAnimation {
            property: "y"
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            property: "opacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    model: ScriptModel {
        values: root.popup
            ? Notifications.popupAppNameList
            : Notifications.appNamesMatching(root.filterQuery)
    }
    delegate: NotificationGroup {
        required property int index
        required property var modelData
        popup: root.popup
        anchors.left: parent?.left
        anchors.right: parent?.right
        notificationGroup: popup ?
            Notifications.popupGroupsByAppName[modelData] :
            Notifications.groupsByAppName[modelData]
    }
}
