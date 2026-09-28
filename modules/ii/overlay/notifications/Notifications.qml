pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.overlay
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
                        visible: !OverlayLook.iris
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 28
                        implicitHeight: 28

                        MaterialSymbol {
                            id: bellIcon
                            anchors.centerIn: parent
                            text: Notifications.silent ? "notifications_paused" : "notifications"
                            iconSize: Appearance.font.pixelSize.larger
                            color: OverlayLook.colOnLayer1
                        }

                        Rectangle {
                            id: notifBadge
                            scale: !Notifications.silent && Notifications.unread > 0 ? 1 : 0
                            visible: scale > 0
                            anchors {
                                right: bellIcon.right
                                top: bellIcon.top
                                rightMargin: 0
                                topMargin: 0
                            }
                            radius: Math.min(width, height) / 2
                            color: OverlayLook.colOnLayer0
                            z: 1

                            implicitHeight: 16
                            implicitWidth: implicitHeight

                            Behavior on scale {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: OverlayLook.colLayer0
                                text: Notifications.unread
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        StyledText {
                            visible: !OverlayLook.iris
                            text: Translation.tr("Notifications")
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: OverlayLook.colOnLayer1
                        }
                        StyledText {
                            text: Notifications.silent
                                  ? Translation.tr("Silent · %1 total").arg(Notifications.list.length)
                                  : Translation.tr("%1 unread · %2 total").arg(Notifications.unread).arg(Notifications.list.length)
                            font.pixelSize: OverlayLook.iris ? Appearance.font.pixelSize.smallie : Appearance.font.pixelSize.smallest
                            color: OverlayLook.colSubtext
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
                            buttonRadius: OverlayLook.roundingSmall
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
                                           ? ColorUtils.transparentize(OverlayLook.colLayer1Hover, 0.25)
                                           : "transparent"
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: "check"
                                    color: OverlayLook.colOnLayer1
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
                            buttonRadius: OverlayLook.roundingSmall
                            // Icon button plano: sin background de Button por defecto
                            background: Item {}
                            colBackground: "transparent"
                            colBackgroundHover: "transparent"
                            colRipple: "transparent"

                            onClicked: {
                                GlobalStates.openSidebarRight("");
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
                                           ? ColorUtils.transparentize(OverlayLook.colLayer1Hover, 0.25)
                                           : "transparent"
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: "right_panel_open"
                                    color: OverlayLook.colOnLayer1
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
                        radius: OverlayLook.roundingNormal
                    }
                }

                popup: false
            }

            MaterialPlaceholderMessage {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: header.bottom
                    bottom: statusRow.top
                    topMargin: 24
                    bottomMargin: 28
                }
                maximumWidth: 280
                compact: true
                shown: Notifications.list.length === 0
                icon: "notifications_active"
                text: Notifications.silent ? Translation.tr("Muted") : Translation.tr("All caught up")
                shape: MaterialShape.Shape.Ghostish
            }

            ButtonGroup {
                id: statusRow
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                StatusButton {
                    Layout.fillWidth: false
                    buttonIcon: "notifications_paused"
                    toggled: Notifications.silent
                    onClicked: {
                        Notifications.silent = !Notifications.silent;
                    }
                }
                StatusButton {
                    enabled: false
                    Layout.fillWidth: true
                    buttonText: Translation.tr("%1 notifications").arg(Notifications.list.length)
                }
                StatusButton {
                    Layout.fillWidth: false
                    buttonIcon: "delete_sweep"
                    onClicked: {
                        Notifications.discardAllNotifications();
                    }
                }
            }
        }
    }

    component StatusButton: NotificationStatusButton {
        id: statusButton
        Binding on colBackground { when: OverlayLook.iris; value: statusButton.toggled ? OverlayLook.colPrimaryContainer : OverlayLook.colLayer2 }
        Binding on colBackgroundHover { when: OverlayLook.iris; value: statusButton.toggled ? OverlayLook.colPrimaryContainerHover : OverlayLook.colLayer2Hover }
        Binding on colBackgroundActive { when: OverlayLook.iris; value: OverlayLook.colLayer2Active }
        Binding on colText { when: OverlayLook.iris; value: statusButton.toggled ? OverlayLook.colOnPrimaryContainer : OverlayLook.colOnLayer1 }
    }
}
