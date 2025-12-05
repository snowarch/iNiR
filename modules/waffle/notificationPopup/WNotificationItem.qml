pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root
    required property var notification
    property bool expanded: false
    property bool onlyNotification: false

    implicitHeight: contentLayout.implicitHeight

    RowLayout {
        id: contentLayout
        anchors.fill: parent
        spacing: 12

        Loader {
            active: (root.notification?.image ?? "") !== ""
            Layout.alignment: Qt.AlignTop
            sourceComponent: Rectangle {
                width: 48; height: 48
                radius: Looks.radius.medium
                color: "transparent"
                clip: true
                StyledImage {
                    anchors.fill: parent
                    sourceSize.width: 48; sourceSize.height: 48
                    source: root.notification?.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            WText {
                visible: !root.onlyNotification
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                font.pixelSize: Looks.font.pixelSize.large
                font.weight: Looks.font.weight.strong
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            WText {
                Layout.fillWidth: true
                text: NotificationUtils.processNotificationBody(
                    root.notification?.body ?? "",
                    root.notification?.appName ?? root.notification?.summary ?? ""
                ).replace(/\n/g, root.expanded ? "<br>" : " ")
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                elide: Text.ElideRight
                maximumLineCount: root.expanded ? 10 : 2
                wrapMode: Text.Wrap
                textFormat: root.expanded ? Text.StyledText : Text.PlainText
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: root.expanded && (root.notification?.actions?.length ?? 0) > 0
                spacing: 8
                Repeater {
                    model: root.notification?.actions ?? []
                    delegate: WBorderedButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.text
                        horizontalPadding: 12
                        verticalPadding: 6
                        onClicked: Notifications.attemptInvokeAction(root.notification.notificationId, modelData.identifier)
                        contentItem: WText { text: parent.text; font.pixelSize: Looks.font.pixelSize.normal; horizontalAlignment: Text.AlignHCenter }
                    }
                }
            }
        }
    }
}
