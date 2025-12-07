pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.notificationCenter

/**
 * Windows 11 style notification group with swipe-to-dismiss
 */
Item {
    id: root
    
    required property var notificationGroup
    property int index: 0
    property var qmlParent: root?.parent?.parent
    
    readonly property var notifications: notificationGroup?.notifications ?? []
    readonly property int notificationCount: notifications.length
    readonly property bool multipleNotifications: notificationCount > 1
    readonly property bool hasCritical: notifications.some(n => n.urgency === NotificationUrgency.Critical)
    property bool expanded: false
    
    implicitHeight: background.height
    
    // Smooth height changes - disabled for performance
    Behavior on implicitHeight {
        enabled: false
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    function dismissAll() {
        for (let i = 0; i < notifications.length; i++) {
            Notifications.discardNotification(notifications[i].notificationId)
        }
    }

    // Swipe to dismiss (when collapsed)
    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.dismissAll()
            } else if (mouse.button === Qt.LeftButton && !dragging) {
                root.expanded = !root.expanded
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

    // Cancel timeout on hover
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        
        onContainsMouseChanged: {
            if (containsMouse) {
                const notifs = root.notifications
                for (let i = 0; i < notifs.length; i++) {
                    Notifications.cancelTimeout(notifs[i].notificationId)
                }
            }
        }
    }

    // Swipe progress indicator - hidden for cleaner look
    Rectangle {
        visible: false
        anchors.right: dragManager.dragDiffX < 0 ? parent.right : undefined
        anchors.left: dragManager.dragDiffX > 0 ? parent.left : undefined
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: 20
        color: Looks.colors.danger
        opacity: Math.min(Math.abs(dragManager.dragDiffX) / 80, 1) * 0.8

        FluentIcon {
            anchors.centerIn: parent
            icon: "dismiss"
            implicitSize: 16
            color: Looks.colors.fg
        }
    }

    // Shadow behind the card
    WRectangularShadow {
        visible: Appearance.effectsEnabled
        target: background
    }

    Rectangle {
        id: background
        width: parent.width
        height: content.height + 24
        x: root.expanded ? 0 : dragManager.dragDiffX
        color: root.hasCritical 
            ? ColorUtils.mix(Looks.colors.bgPanelFooterBase, Looks.colors.danger, 0.92)
            : Looks.colors.bgPanelFooterBase
        radius: Looks.radius.large
        border.color: root.hasCritical ? Looks.colors.danger : Looks.colors.bg2Border
        border.width: 1
        
        Behavior on x {
            enabled: false
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: false
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on color {
            enabled: false
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                WNotificationAppIcon {
                    icon: root.notificationGroup?.appIcon ?? ""
                    implicitSize: 20
                }

                WText {
                    Layout.fillWidth: true
                    text: root.multipleNotifications 
                        ? (root.notificationGroup?.appName ?? "")
                        : (root.notifications[0]?.summary ?? "")
                    font.pixelSize: root.multipleNotifications 
                        ? Looks.font.pixelSize.small 
                        : Looks.font.pixelSize.large
                    font.weight: root.multipleNotifications 
                        ? Looks.font.weight.regular 
                        : Looks.font.weight.strong
                    color: root.multipleNotifications ? Looks.colors.subfg : Looks.colors.fg
                    elide: Text.ElideRight
                }

                WText {
                    text: NotificationUtils.getFriendlyNotifTimeString(root.notificationGroup?.time)
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                }

                // Count badge
                Rectangle {
                    visible: root.multipleNotifications
                    implicitWidth: Math.max(countText.implicitWidth + 10, 20)
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

                // Expand/collapse indicator
                Rectangle {
                    visible: root.multipleNotifications || root.notifications[0]?.actions?.length > 0
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: Looks.radius.medium
                    color: "transparent"

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "chevron-down"
                        implicitSize: 12
                        color: Looks.colors.subfg
                        rotation: root.expanded ? 180 : 0

                        Behavior on rotation {
                            animation: Looks.transition.rotate.createObject(this)
                        }
                    }
                }

                // Close all button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: Looks.radius.medium
                    color: closeMA.containsMouse ? Looks.colors.bg1Hover : "transparent"

                    Behavior on color {
                        animation: Looks.transition.color.createObject(this)
                    }

                    MouseArea {
                        id: closeMA
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.dismissAll()
                    }

                    WToolTip {
                        text: root.multipleNotifications ? Translation.tr("Dismiss all") : Translation.tr("Dismiss")
                        visible: closeMA.containsMouse
                    }

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "dismiss"
                        implicitSize: 12
                        color: closeMA.containsMouse ? Looks.colors.fg : Looks.colors.subfg
                    }
                }
            }

            // Collapsed: show first notification body
            WText {
                visible: !root.expanded && !root.multipleNotifications
                opacity: visible ? 1 : 0
                Layout.fillWidth: true
                text: {
                    const body = root.notifications[0]?.body ?? ""
                    const appName = root.notifications[0]?.appName ?? root.notifications[0]?.summary ?? ""
                    return NotificationUtils.processNotificationBody(body, appName).replace(/\n/g, " ")
                }
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            // Collapsed multi: show summaries
            Column {
                visible: !root.expanded && root.multipleNotifications
                opacity: visible ? 1 : 0
                Layout.fillWidth: true
                spacing: 2
                
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: Math.min(root.notificationCount, 3)

                    WText {
                        required property int index
                        width: parent.width
                        text: root.notifications[index]?.summary ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.subfg
                        elide: Text.ElideRight
                        opacity: index === 2 ? 0.5 : 1
                    }
                }
            }

            // Expanded: show full items with staggered animation
            Column {
                id: expandedColumn
                visible: root.expanded
                opacity: root.expanded ? 1 : 0
                Layout.fillWidth: true
                spacing: 10

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    model: root.expanded ? root.notifications : []

                    WNotificationItem {
                        id: notifItem
                        required property int index
                        required property var modelData
                        width: parent.width
                        notification: modelData
                        onlyNotification: root.notificationCount === 1
                        
                        // Staggered entrance animation
                        opacity: 0
                        transform: Translate { id: itemTranslate; y: 10 }
                        
                        Component.onCompleted: {
                            // Stagger based on index
                            entranceTimer.interval = 30 * index
                            entranceTimer.start()
                        }
                        
                        Timer {
                            id: entranceTimer
                            onTriggered: entranceAnim.start()
                        }
                        
                        ParallelAnimation {
                            id: entranceAnim
                            NumberAnimation {
                                target: notifItem
                                property: "opacity"
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: itemTranslate
                                property: "y"
                                to: 0
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
