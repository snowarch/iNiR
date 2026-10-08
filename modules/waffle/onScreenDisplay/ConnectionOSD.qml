pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

WBarAttachedPanelContent {
    id: root

    readonly property var event: DeviceEvents.last

    property Timer timer: Timer {
        id: autoCloseTimer
        running: true
        interval: (Config.options?.osd?.timeout ?? 3000) + 1500
        repeat: false
        onTriggered: root.close()
    }

    Connections {
        target: DeviceEvents
        function onHappened() {
            autoCloseTimer.restart()
        }
    }

    contentItem: WPane {
        screenX: root.panelScreenX + root.visualMargin
        screenY: root.panelScreenY + root.visualMargin
        screenWidth: root._screenW
        screenHeight: root._screenH
        contentItem: Item {
            implicitWidth: Math.min(380, contentRow.implicitWidth + 28)
            implicitHeight: 56

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                FluentIcon {
                    Layout.alignment: Qt.AlignVCenter
                    icon: root.event?.fluentIcon ?? "checkmark"
                    implicitSize: 22
                    color: root.event?.tone === "warn" ? Looks.colors.danger : root.event?.tone === "on" ? Looks.colors.accent : Looks.colors.fg
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    WText {
                        Layout.fillWidth: true
                        text: root.event?.title ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    WText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root.event?.detail ?? ""
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.small
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                WText {
                    visible: (root.event?.value ?? -1) >= 0
                    text: (root.event?.value ?? 0) + "%"
                    color: Looks.colors.subfg
                    font.pixelSize: Looks.font.pixelSize.small
                }
            }
        }
    }
}
