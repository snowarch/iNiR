pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

MouseArea {
    id: root

    required property var notification
    property bool expanded: notification.actions.length > 0
    property string groupExpandControlMessage: ""
    signal groupExpandToggle
    hoverEnabled: true

    readonly property bool isCritical: notification?.urgency === NotificationUrgency.Critical
    readonly property bool hasImage: notification?.image !== ""

    implicitHeight: contentItem.implicitHeight
    implicitWidth: contentItem.implicitWidth

    Behavior on implicitHeight {
        animation: Looks.transition.enter.createObject(this)
    }

    Rectangle {
        id: contentItem
        anchors.fill: parent
        color: Looks.colors.bgPanelBody
        radius: Looks.radius.medium
        property real padding: 12
        implicitHeight: notificationContent.implicitHeight + padding * 2
        implicitWidth: notificationContent.implicitWidth + padding * 2
        border.width: 1
        border.color: ColorUtils.applyAlpha(Looks.colors.ambientShadow, 0.1)

        ColumnLayout {
            id: notificationContent
            anchors.fill: parent
            anchors.margins: contentItem.padding
            spacing: 12

            // Header
            SingleNotificationHeader {
                Layout.fillWidth: true
            }

            // Content
            Item {
                id: actualContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                property real spacing: 16
                implicitHeight: Math.max(contentColumn.implicitHeight, imageLoader.height)
                implicitWidth: contentColumn.implicitWidth

                Loader {
                    id: imageLoader
                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                    active: root.notification?.image != ""
                    sourceComponent: StyledImage {
                        readonly property int size: 48
                        width: size
                        height: size
                        sourceSize.width: size
                        sourceSize.height: size
                        source: root.notification?.image ?? ""
                        fillMode: Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    id: contentColumn
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 3

                    SummaryText {
                        id: summaryText
                        Layout.leftMargin: imageLoader.active ? imageLoader.width + actualContent.spacing : 0
                    }
                    BodyText {
                        Layout.leftMargin: imageLoader.active ? imageLoader.width + actualContent.spacing : 0
                    }
                }
            }

            // Actions
            ActionsRow {
                Layout.fillWidth: true
            }

            // "+1 notifications" button
            GroupExpandButton {
                Layout.bottomMargin: 2
            }
        }
    }

    component SingleNotificationHeader: RowLayout {
        spacing: 8

        ExpandButton {
            Layout.topMargin: -2
        }

        Item {
            Layout.fillWidth: true
        }

        // Copy button
        NotificationHeaderButton {
            id: copyHeaderBtn
            Layout.rightMargin: 2
            opacity: root.containsMouse ? 1 : 0
            icon.name: copyHeaderBtn.copied ? "checkmark" : "copy"
            implicitSize: 12
            property bool copied: false

            onClicked: {
                copyHeaderProcess.running = true
            }

            Process {
                id: copyHeaderProcess
                command: ["wl-copy", root.notification?.body ?? ""]
                onExited: (code, status) => {
                    if (code === 0) {
                        copyHeaderBtn.copied = true
                        copyHeaderTimer.restart()
                    }
                }
            }

            Timer {
                id: copyHeaderTimer
                interval: 1500
                onTriggered: copyHeaderBtn.copied = false
            }

            WToolTip {
                text: copyHeaderBtn.copied ? Translation.tr("Copied!") : Translation.tr("Copy")
                visible: parent.hovered
            }

            Behavior on opacity {
                animation: Looks.transition.opacity.createObject(this)
            }
        }

        NotificationHeaderButton {
            id: dismissHeaderBtn
            Layout.rightMargin: 4
            opacity: root.containsMouse ? 1 : 0
            icon.name: "dismiss"
            implicitSize: 12
            onClicked: {
                Qt.callLater(() => {
                    Notifications.discardNotification(root.notification?.notificationId);
                });
            }

            WToolTip {
                text: Translation.tr("Dismiss")
                visible: dismissHeaderBtn.hovered
            }

            Behavior on opacity {
                animation: Looks.transition.opacity.createObject(this)
            }
        }
    }

    component ActionsRow: RowLayout {
        visible: root.expanded && root.notification.actions.length > 0
        opacity: visible ? 1 : 0
        spacing: 6
        
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Repeater {
            id: actionRepeater
            model: root.notification.actions
            delegate: WBorderedButton {
                id: actionButton
                Layout.fillHeight: true
                required property var modelData
                required property int index
                Layout.fillWidth: true
                verticalPadding: 10
                horizontalPadding: 12
                text: modelData.text
                implicitHeight: actionButtonText.implicitHeight + verticalPadding * 2
                // First action is primary
                colBackground: index === 0 ? Looks.colors.accent : Looks.colors.bg2
                colBackgroundHover: index === 0 ? Looks.colors.accentHover : Looks.colors.bg2Hover
                colBackgroundActive: index === 0 ? Looks.colors.accentActive : Looks.colors.bg2Active
                
                onClicked: Notifications.attemptInvokeAction(root.notification?.notificationId, modelData.identifier)
                
                contentItem: WText {
                    id: actionButtonText
                    text: actionButton.text
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: index === 0 ? Looks.font.weight.strong : Looks.font.weight.regular
                    color: index === 0 ? Looks.colors.accentFg : Looks.colors.fg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    component SummaryText: WText {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: root.notification?.summary ?? ""
        font.pixelSize: Looks.font.pixelSize.large
        font.weight: Looks.font.weight.strong
        color: root.isCritical ? Looks.colors.danger : Looks.colors.fg
    }

    component BodyText: WText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        elide: Text.ElideRight
        verticalAlignment: Text.AlignTop
        wrapMode: Text.Wrap
        maximumLineCount: root.expanded ? 100 : 2
        text: {
            const body = root.notification?.body ?? ""
            const appName = root.notification?.appName ?? root.notification?.summary ?? ""
            if (root.expanded)
                return `<style>img{max-width:${summaryText.width}px; align: right}</style>` + `${NotificationUtils.processNotificationBody(body, appName).replace(/\n/g, "<br/>")}`;
            return NotificationUtils.processNotificationBody(body, appName).replace(/\n/g, "<br/>");
        }
        color: Looks.colors.subfg
        textFormat: root.expanded ? Text.RichText : Text.StyledText
        onLinkActivated: link => {
            Qt.openUrlExternally(link);
            GlobalStates.waffleNotificationCenterOpen = false;
        }
    }

    component ExpandButton: NotificationHeaderButton {
        id: expandButton
        implicitWidth: expandButtonContent.implicitWidth
        onClicked: root.expanded = !root.expanded

        contentItem: Item {
            id: expandButtonContent
            implicitWidth: expandButtonRow.implicitWidth
            implicitHeight: expandButtonRow.implicitHeight
            RowLayout {
                id: expandButtonRow
                anchors.centerIn: parent
                spacing: 8
                
                // Critical indicator
                Rectangle {
                    visible: root.isCritical
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Looks.colors.danger

                    SequentialAnimation on opacity {
                        running: root.isCritical
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }

                WText {
                    color: expandButton.colForeground
                    text: NotificationUtils.getFriendlyNotifTimeString(root.notification?.time)
                    font.pixelSize: Looks.font.pixelSize.small
                }
                FluentIcon {
                    Layout.rightMargin: 8
                    icon: "chevron-down"
                    implicitSize: 14
                    rotation: root.expanded ? -180 : 0
                    color: expandButton.colForeground
                    Behavior on rotation {
                        animation: Looks.transition.rotate.createObject(this)
                    }
                }
            }
        }
    }

    component GroupExpandButton: AcrylicButton {
        id: groupExpandButton
        visible: root.groupExpandControlMessage !== ""
        horizontalPadding: 12
        implicitHeight: 28
        implicitWidth: expandButtonText.implicitWidth + horizontalPadding * 2
        onClicked: root.groupExpandToggle()
        contentItem: Item {
            WText {
                id: expandButtonText
                anchors.centerIn: parent
                text: root.groupExpandControlMessage
                font.pixelSize: Looks.font.pixelSize.small
            }
        }
    }
}
