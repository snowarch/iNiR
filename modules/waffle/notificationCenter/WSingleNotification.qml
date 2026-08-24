pragma ComponentBehavior: Bound
import qs
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
    property bool expanded: false
    property string groupExpandControlMessage: ""
    readonly property bool isPopup: root.notification
        ? (root.notification.popup ?? false)
        : false
    signal groupExpandToggle
    hoverEnabled: true

    readonly property bool isCritical: root.notification
        ? root.notification.urgency === NotificationUrgency.Critical
        : false
    readonly property bool hasImage: root.notification
        ? (root.notification.image ?? "") !== ""
        : false

    function dismiss() {
        const notificationId = root.notification?.notificationId
        if (notificationId === undefined || notificationId === null)
            return
        Qt.callLater(() => {
            Notifications.discardNotification(notificationId);
        });
        removeAnimation.start();
    }

    WNotificationDismissAnim {
        id: removeAnimation
        target: root
    }

    implicitHeight: contentItem.implicitHeight
    implicitWidth: contentItem.implicitWidth

    property real dragDismissThreshold: 100
    drag {
        axis: Drag.XAxis
        target: contentItem
        minimumX: 0
        onActiveChanged: {
            if (drag.active)
                return;
            if (contentItem.x > root.dragDismissThreshold) {
                root.dismiss();
            } else {
                contentItem.x = 0;
            }
        }
    }

    Rectangle {
        id: contentItem
        width: parent.width
        color: root.isPopup ? Looks.colors.bg0 : Looks.colors.bgPanelBody
        radius: root.isPopup ? Looks.radius.large : Looks.radius.medium
        property real padding: Looks.dp(12)
        implicitHeight: notificationContent.implicitHeight + padding * 2
        implicitWidth: notificationContent.implicitWidth + padding * 2
        border.width: 1
        border.color: ColorUtils.applyAlpha(Looks.colors.ambientShadow, 0.1)

        Behavior on x {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }

        ColumnLayout {
            id: notificationContent
            anchors.fill: parent
            anchors.margins: contentItem.padding
            spacing: Looks.dp(12)

            // Header
            SingleNotificationHeader {
                Layout.fillWidth: true
            }

            // Content
            Item {
                id: actualContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                property real spacing: Looks.dp(16)
                implicitHeight: Math.max(contentColumn.implicitHeight, imageLoader.height)
                implicitWidth: contentColumn.implicitWidth

                Loader {
                    id: imageLoader
                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                    active: root.hasImage
                    sourceComponent: StyledImage {
                        readonly property int size: Looks.dp(48)
                        width: size
                        height: size
                        sourceSize.width: size
                        sourceSize.height: size
                        source: root.notification ? (root.notification.image ?? "") : ""
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
                command: [
                    "wl-copy",
                    root.notification ? (root.notification.body ?? "") : ""
                ]
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
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }

        NotificationHeaderButton {
            id: dismissHeaderBtn
            Layout.rightMargin: 4
            opacity: (root.containsMouse || root.isPopup) ? 1 : 0
            icon.name: "dismiss"
            implicitSize: root.isPopup ? 14 : 12
            onClicked: root.dismiss()

            WToolTip {
                text: Translation.tr("Dismiss")
                visible: dismissHeaderBtn.hovered
            }

            Behavior on opacity {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }
    }

    component ActionsRow: RowLayout {
        id: actionRow
        readonly property var visibleActions: (root.notification?.actions ?? [])
            .filter(action => String(action?.text ?? "").trim().length > 0)
        visible: root.expanded && visibleActions.length > 0
        opacity: visible ? 1 : 0
        spacing: Looks.dp(6)
        
        Behavior on opacity {
            NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }

        Repeater {
            id: actionRepeater
            model: actionRow.visibleActions
            delegate: WBorderedButton {
                id: actionButton
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: Looks.dp(32)
                verticalPadding: 0
                horizontalPadding: Looks.dp(12)
                text: modelData.text
                implicitHeight: actionButtonText.implicitHeight + verticalPadding * 2
                // First action is primary
                colBackground: index === 0
                    ? Looks.colors.accent : Looks.colors.interactiveSurface
                colBackgroundHover: index === 0
                    ? Looks.colors.accentHover : Looks.colors.interactiveSurfaceHover
                colBackgroundActive: index === 0
                    ? Looks.colors.accentActive : Looks.colors.interactiveSurfaceActive
                
                onClicked: {
                    if (root.notification)
                        Notifications.attemptInvokeAction(root.notification.notificationId, modelData.identifier)
                }
                
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
        text: root.notification ? (root.notification.summary ?? "") : ""
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
            if (!root.notification)
                return ""
            const body = root.notification.body ?? ""
            const appName = root.notification.appName ?? root.notification.summary ?? ""
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
                    text: root.notification
                        ? (NotificationUtils.getFriendlyNotifTimeString(root.notification.time) ?? "")
                        : ""
                    font.pixelSize: Looks.font.pixelSize.small
                }
                FluentIcon {
                    Layout.rightMargin: 8
                    icon: "chevron-down"
                    implicitSize: 14
                    rotation: root.expanded ? -180 : 0
                    color: expandButton.colForeground
                    Behavior on rotation {
                        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
            }
        }
    }

    component GroupExpandButton: AcrylicButton {
        id: groupExpandButton
        visible: root.groupExpandControlMessage !== ""
        horizontalPadding: 12
        implicitHeight: 30
        implicitWidth: expandBtnRow.implicitWidth + horizontalPadding * 2
        onClicked: root.groupExpandToggle()
        contentItem: Item {
            RowLayout {
                id: expandBtnRow
                anchors.centerIn: parent
                spacing: 6
                FluentIcon {
                    icon: "chevron-down"
                    implicitSize: 10
                    color: Looks.colors.accent
                }
                WText {
                    text: root.groupExpandControlMessage
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.accent
                }
            }
        }
    }
}
