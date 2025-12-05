pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.notificationCenter

MouseArea {
    id: root
    property var notificationGroup
    property var notifications: notificationGroup?.notifications ?? []
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    property bool expanded: false
    property real padding: 12
    property var qmlParent
    implicitHeight: background.implicitHeight
    property real dragConfirmThreshold: 40
    property real dismissOvershoot: 20
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - (index ?? 0))
    property real xOffset: {
        if (dragIndexDiff == 0) return parentDragDistance
        if (Math.abs(parentDragDistance) > dragConfirmThreshold) return 0
        if (dragIndexDiff == 1) return parentDragDistance * 0.3
        if (dragIndexDiff == 2) return parentDragDistance * 0.1
        return 0
    }
    function destroyWithAnimation(left: bool): void {
        qmlParent?.resetDrag()
        background.anchors.leftMargin = background.anchors.leftMargin
        destroyAnimation.left = left
        destroyAnimation.running = true
    }
    function toggleExpanded(): void { root.expanded = !root.expanded }
    hoverEnabled: true
    onContainsMouseChanged: {
        if (containsMouse) notifications.forEach(n => Notifications.cancelTimeout(n.notificationId))
    }

    SequentialAnimation {
        id: destroyAnimation
        property bool left: true
        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: (root.width + root.dismissOvershoot) * (destroyAnimation.left ? -1 : 1)
            duration: 250
            easing.type: Easing.OutCubic
        }
        onFinished: root.notifications.forEach(n => Qt.callLater(() => Notifications.discardNotification(n.notificationId)))
    }

    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => { if (mouse.button === Qt.RightButton) root.toggleExpanded() }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !dragging) root.toggleExpanded()
            else if (mouse.button === Qt.MiddleButton) root.destroyWithAnimation(true)
        }
        onDraggingChanged: { if (dragging && root.qmlParent) root.qmlParent.dragIndex = root.index ?? 0 }
        onDragDiffXChanged: { if (root.qmlParent) root.qmlParent.dragDistance = dragDiffX }
        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > root.dragConfirmThreshold) root.destroyWithAnimation(diffX < 0)
            else dragManager.resetDrag()
        }
    }

    WRectangularShadow { target: background }
    WAmbientShadow { target: background }

    Rectangle {
        id: background
        anchors.left: parent.left
        width: parent.width
        color: Looks.colors.bgPanelFooter
        radius: Looks.radius.large
        anchors.leftMargin: root.xOffset
        clip: true
        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        implicitHeight: root.expanded ? col.implicitHeight + root.padding * 2 : Math.min(110, col.implicitHeight + root.padding * 2)
        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.padding }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                WNotificationAppIcon { icon: root.notificationGroup?.appIcon ?? ""; implicitSize: 16 }
                WText {
                    Layout.fillWidth: true
                    text: root.multipleNotifications ? (root.notificationGroup?.appName ?? "") : (root.notifications[0]?.summary ?? "")
                    font.pixelSize: root.multipleNotifications ? Looks.font.pixelSize.small : Looks.font.pixelSize.large
                    font.weight: root.multipleNotifications ? Looks.font.weight.regular : Looks.font.weight.strong
                    color: root.multipleNotifications ? Looks.colors.subfg : Looks.colors.fg
                    elide: Text.ElideRight
                }
                WText {
                    text: NotificationUtils.getFriendlyNotifTimeString(root.notificationGroup?.time)
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                }
                Item {
                    visible: root.multipleNotifications
                    implicitWidth: er.implicitWidth
                    implicitHeight: er.implicitHeight
                    RowLayout {
                        id: er
                        spacing: 4
                        WText { text: root.notificationCount.toString(); font.pixelSize: Looks.font.pixelSize.small; color: Looks.colors.subfg }
                        FluentIcon {
                            icon: "chevron-down"
                            implicitSize: 12
                            color: Looks.colors.subfg
                            rotation: root.expanded ? -180 : 0
                            Behavior on rotation { NumberAnimation { duration: 200 } }
                        }
                    }
                }
                WBorderlessButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    opacity: root.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    onClicked: root.destroyWithAnimation(true)
                    contentItem: FluentIcon { icon: "dismiss"; implicitSize: 14; color: Looks.colors.subfg }
                }
            }

            ListView {
                id: nl
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                spacing: root.expanded ? 8 : 4
                Behavior on spacing { NumberAnimation { duration: 150 } }
                model: ScriptModel {
                    values: root.expanded ? root.notifications.slice().reverse() : root.notifications.slice().reverse().slice(0, 2)
                }
                delegate: WNotificationItem {
                    required property int index
                    required property var modelData
                    width: nl.width
                    notification: modelData
                    expanded: root.expanded
                    onlyNotification: root.notificationCount === 1
                    opacity: (!root.expanded && index == 1 && root.notificationCount > 2) ? 0.5 : 1
                    visible: root.expanded || index < 2
                }
            }
        }
    }
}
