import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root

    required property var notificationGroup
    readonly property var notifications: notificationGroup?.notifications ?? []
    readonly property int notificationCount: notifications.length
    readonly property bool hasCritical: notificationGroup?.hasCritical ?? false
    property bool expanded: false

    implicitWidth: contentLayout.implicitWidth
    implicitHeight: contentLayout.implicitHeight

    function dismissAll() {
        notifications.forEach(notif => {
            Qt.callLater(() => {
                Notifications.discardNotification(notif.notificationId);
            });
        });
    }

    // Swipe to dismiss
    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.dismissAll()
            }
        }

        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > 80) {
                root.dismissAll()
            } else {
                dragManager.resetDrag()
            }
        }
    }

    // Swipe progress indicator
    Rectangle {
        visible: Math.abs(dragManager.dragDiffX) > 20 && !root.expanded
        anchors.right: dragManager.dragDiffX < 0 ? parent.right : undefined
        anchors.left: dragManager.dragDiffX > 0 ? parent.left : undefined
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: Looks.colors.danger
        opacity: Math.min(Math.abs(dragManager.dragDiffX) / 80, 1) * 0.8

        FluentIcon {
            anchors.centerIn: parent
            icon: "dismiss"
            implicitSize: 14
            color: Looks.colors.fg
        }
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        x: root.expanded ? 0 : dragManager.dragDiffX
        spacing: 4

        Behavior on x {
            enabled: !dragManager.dragging
            animation: Looks.transition.move.createObject(this)
        }

        GroupHeader {
            id: notifHeader
            Layout.fillWidth: true
            Layout.margins: 11
        }

        ListView {
            Layout.fillWidth: true
            implicitWidth: notifHeader.implicitWidth
            implicitHeight: contentHeight
            interactive: false
            spacing: 4

            // Smooth transitions
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 200; easing.type: Easing.OutCubic }
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

            Behavior on implicitHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            model: ScriptModel {
                // Limit to 5 expanded items for performance
                values: root.expanded ? root.notifications.slice(-5).reverse() : root.notifications.slice(-1)
                objectProp: "notificationId"
            }
            delegate: WSingleNotification {
                required property int index
                required property var modelData
                width: ListView.view.width
                notification: modelData
                groupExpandControlMessage: {
                    if (root.notificationCount <= 1) return "";
                    const displayedCount = Math.min(root.notificationCount, 5);
                    if (!root.expanded) return Translation.tr("+%1 notifications").arg(root.notificationCount - 1);
                    // Show "See fewer" on last displayed item, or show remaining count if more than 5
                    if (index === displayedCount - 1) {
                        if (root.notificationCount > 5) {
                            return Translation.tr("See fewer (+%1 more)").arg(root.notificationCount - 5);
                        }
                        return Translation.tr("See fewer");
                    }
                    return "";
                }
                onGroupExpandToggle: {
                    root.expanded = !root.expanded;
                }
            }
        }
    }

    component GroupHeader: MouseArea {
        id: headerMouseArea
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        implicitWidth: appHeader.implicitWidth
        implicitHeight: appHeader.implicitHeight

        RowLayout {
            id: appHeader
            anchors.fill: parent
            spacing: 8

            WNotificationAppIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: root.notificationGroup?.appIcon ?? ""
            }

            // Critical indicator
            Rectangle {
                visible: root.hasCritical
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Looks.colors.danger

                SequentialAnimation on opacity {
                    running: root.hasCritical
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }

            WText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                text: root.notificationGroup?.appName ?? ""
                font.weight: root.hasCritical ? Looks.font.weight.strong : Looks.font.weight.regular
                color: root.hasCritical ? Looks.colors.danger : Looks.colors.fg
            }

            // Notification count badge
            Rectangle {
                visible: root.notificationCount > 1
                implicitWidth: Math.max(countText.implicitWidth + 8, 18)
                implicitHeight: 18
                radius: 9
                color: Looks.colors.bg1Base

                WText {
                    id: countText
                    anchors.centerIn: parent
                    text: root.notificationCount.toString()
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.fg
                }
            }

            NotificationHeaderButton {
                opacity: headerMouseArea.containsMouse ? 1 : 0
                Layout.rightMargin: 3
                icon.name: "dismiss"
                onClicked: root.dismissAll()

                WToolTip {
                    text: root.notificationCount > 1 
                        ? Translation.tr("Dismiss all from %1").arg(root.notificationGroup?.appName ?? "")
                        : Translation.tr("Dismiss")
                    visible: parent.hovered
                }

                Behavior on opacity {
                    animation: Looks.transition.opacity.createObject(this)
                }
            }
        }
    }
}
