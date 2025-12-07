pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.notificationCenter

/**
 * Windows 11 style notification item with swipe-to-dismiss
 */
Item {
    id: root
    
    required property var notification
    property bool onlyNotification: false

    readonly property string notifImage: notification?.image ?? ""
    readonly property string notifSummary: notification?.summary ?? ""
    readonly property string notifBody: notification?.body ?? ""
    readonly property string notifAppName: notification?.appName ?? ""
    readonly property var notifActions: notification?.actions ?? []
    readonly property int notifId: notification?.notificationId ?? -1
    readonly property bool hasImage: notifImage !== ""
    readonly property bool hasActions: notifActions.length > 0
    readonly property bool isCritical: notification?.urgency === NotificationUrgency.Critical

    implicitHeight: contentItem.height
    clip: true

    function dismiss() {
        Notifications.discardNotification(notifId)
    }

    // Swipe to dismiss
    DragManager {
        id: dragManager
        anchors.fill: parent
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.dismiss()
        }

        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > 60) {
                root.dismiss()
            } else {
                dragManager.resetDrag()
            }
        }
    }

    Rectangle {
        id: contentItem
        width: parent.width
        height: col.height + 12
        x: dragManager.dragDiffX
        color: "transparent"
        radius: Looks.radius.medium

        Behavior on x {
            enabled: false
            animation: Looks.transition.move.createObject(this)
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 8

            // Summary with urgency indicator
            RowLayout {
                visible: !root.onlyNotification
                Layout.fillWidth: true
                spacing: 6

                // Critical indicator
                Rectangle {
                    visible: root.isCritical
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Looks.colors.danger

                    SequentialAnimation on opacity {
                        running: false
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }

                WText {
                    Layout.fillWidth: true
                    text: root.notifSummary
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.strong
                    color: root.isCritical ? Looks.colors.danger : Looks.colors.fg
                    elide: Text.ElideRight
                }
            }

            // Image - larger and better presented
            Rectangle {
                visible: root.hasImage
                Layout.fillWidth: true
                implicitHeight: imageContent.status === Image.Ready 
                    ? Math.min(imageContent.sourceSize.height, 120) 
                    : 60
                radius: Looks.radius.medium
                color: Looks.colors.bg1Base
                clip: true

                Image {
                    id: imageContent
                    anchors.fill: parent
                    source: root.notifImage
                    sourceSize.width: parent.width
                    sourceSize.height: 120
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true

                    // Loading placeholder
                    Rectangle {
                        anchors.fill: parent
                        visible: imageContent.status === Image.Loading
                        color: Looks.colors.bg1Base

                        WText {
                            anchors.centerIn: parent
                            text: Translation.tr("Loading...")
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                        }
                    }
                }
            }

            // Body
            WText {
                Layout.fillWidth: true
                text: NotificationUtils.processNotificationBody(root.notifBody, root.notifAppName || root.notifSummary).replace(/\n/g, "<br/>")
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                maximumLineCount: 5
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // Actions row - improved layout
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Dismiss button
                WBorderedButton {
                    implicitHeight: 32
                    implicitWidth: 40
                    onClicked: root.dismiss()

                    WToolTip {
                        text: Translation.tr("Dismiss")
                        visible: parent.hovered
                    }

                    contentItem: FluentIcon {
                        anchors.centerIn: parent
                        icon: "dismiss"
                        implicitSize: 14
                        color: Looks.colors.fg
                    }
                }

                // Custom actions from notification
                Repeater {
                    model: root.notifActions

                    delegate: WBorderedButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 32
                        // First action is primary - use accent color
                        colBackground: index === 0 ? Looks.colors.accent : Looks.colors.bg2
                        colBackgroundHover: index === 0 ? Looks.colors.accentHover : Looks.colors.bg2Hover
                        colBackgroundActive: index === 0 ? Looks.colors.accentActive : Looks.colors.bg2Active
                        
                        onClicked: Notifications.attemptInvokeAction(root.notifId, modelData.identifier)

                        contentItem: WText {
                            text: modelData.text
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: index === 0 ? Looks.font.weight.strong : Looks.font.weight.regular
                            color: index === 0 ? Looks.colors.accentFg : Looks.colors.fg
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Copy button
                WBorderedButton {
                    id: copyBtn
                    implicitHeight: 32
                    implicitWidth: 40
                    property bool copied: false

                    onClicked: {
                        copyProcess.running = true
                    }

                    Process {
                        id: copyProcess
                        command: ["wl-copy", root.notifBody]
                        onExited: (code, status) => {
                            if (code === 0) {
                                copyBtn.copied = true
                                copyTimer.restart()
                            }
                        }
                    }

                    Timer {
                        id: copyTimer
                        interval: 1500
                        onTriggered: copyBtn.copied = false
                    }

                    WToolTip {
                        text: copyBtn.copied ? Translation.tr("Copied!") : Translation.tr("Copy")
                        visible: parent.hovered
                    }

                    contentItem: FluentIcon {
                        anchors.centerIn: parent
                        icon: copyBtn.copied ? "checkmark" : "copy"
                        implicitSize: 14
                        color: copyBtn.copied ? Looks.colors.accent : Looks.colors.fg
                    }
                }
            }
        }
    }
}
