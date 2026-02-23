pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.inir.overlay
import qs.modules.sidebarRight.notifications

StyledOverlayWidget {
    id: root

    Component.onCompleted: Notifications.ensureInitialized()

    // Evitar que arrastrar una notificación mueva todo el widget
    draggable: GlobalStates.overlayOpen && !notificationsHoverArea.containsMouse

    minimumWidth: 360
    minimumHeight: 260

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8

        Item {
            id: notificationsRoot
            anchors {
                fill: parent
                margins: contentItem.padding
            }

            MouseArea {
                id: notificationsHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Item {
                id: header
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: headerRow.implicitHeight

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    spacing: 6

                    Item {
                        id: iconContainer
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 28
                        implicitHeight: 28

                        MaterialSymbol {
                            id: bellIcon
                            anchors.centerIn: parent
                            text: Notifications.silent ? "notifications_paused" : "notifications"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer1
                        }

                        Rectangle {
                            id: notifBadge
                            visible: !Notifications.silent && Notifications.unread > 0
                            anchors {
                                right: bellIcon.right
                                top: bellIcon.top
                                rightMargin: 0
                                topMargin: 0
                            }
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colOnLayer0
                            z: 1

                            implicitHeight: 16
                            implicitWidth: implicitHeight

                            StyledText {
                                anchors.centerIn: parent
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colLayer0
                                text: Notifications.unread
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        StyledText {
                            text: Translation.tr("Notifications")
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: Notifications.silent
                                  ? Translation.tr("Silent · %1 total").arg(Notifications.list.length)
                                  : Translation.tr("%1 unread · %2 total").arg(Notifications.unread).arg(Notifications.list.length)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        RippleButton {
                            id: markReadButton
                            implicitHeight: 22
                            implicitWidth: 22
                            Layout.alignment: Qt.AlignVCenter
                            buttonRadius: Appearance.rounding.small
                            // Icon button plano: sin background de Button por defecto
                            background: Item {}
                            colBackground: "transparent"
                            colBackgroundHover: "transparent"
                            colRipple: "transparent"

                            onClicked: {
                                Notifications.markAllRead();
                            }

                            contentItem: Item {
                                anchors.centerIn: parent
                                width: 22
                                height: 22

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: markReadButton.hovered
                                           ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.25)
                                           : "transparent"
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: "check"
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                            StyledToolTip {
                                text: Translation.tr("Mark all as read")
                            }
                        }

                        RippleButton {
                            id: openCenterButton
                            implicitHeight: 22
                            implicitWidth: 22
                            Layout.alignment: Qt.AlignVCenter
                            buttonRadius: Appearance.rounding.small
                            // Icon button plano: sin background de Button por defecto
                            background: Item {}
                            colBackground: "transparent"
                            colBackgroundHover: "transparent"
                            colRipple: "transparent"

                            onClicked: {
                                GlobalStates.sidebarRightOpen = true;
                                GlobalStates.overlayOpen = false;
                            }

                            contentItem: Item {
                                anchors.centerIn: parent
                                width: 22
                                height: 22

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: openCenterButton.hovered
                                           ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.25)
                                           : "transparent"
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: "right_panel_open"
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                            StyledToolTip {
                                text: Translation.tr("Open notification center")
                            }
                        }
                    }
                }
            }

            NotificationListView {
                id: listview
                anchors {
                    left: parent.left
                    right: parent.right
                    top: header.bottom
                    bottom: statusRow.top
                    bottomMargin: 5
                }

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: listview.width
                        height: listview.height
                        radius: Appearance.rounding.normal
                    }
                }

                popup: false
            }

            PagePlaceholder {
                shown: Notifications.list.length === 0
                icon: "notifications_active"
                description: Translation.tr("Nothing")
                shape: MaterialShape.Shape.Ghostish
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            ButtonGroup {
                id: statusRow
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                NotificationStatusButton {
                    Layout.fillWidth: false
                    buttonIcon: "notifications_paused"
                    toggled: Notifications.silent
                    onClicked: {
                        Notifications.silent = !Notifications.silent;
                    }
                }
                NotificationStatusButton {
                    enabled: false
                    Layout.fillWidth: true
                    buttonText: Translation.tr("%1 notifications").arg(Notifications.list.length)
                }
                NotificationStatusButton {
                    Layout.fillWidth: false
                    buttonIcon: "delete_sweep"
                    onClicked: {
                        Notifications.discardAllNotifications();
                    }
                }
            }
        }
    }
}
