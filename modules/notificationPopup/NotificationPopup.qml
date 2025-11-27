import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        visible: true
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        anchors {
            top: Config.options.notifications.position === "topRight" || Config.options.notifications.position === "topLeft"
            bottom: Config.options.notifications.position === "bottomRight" || Config.options.notifications.position === "bottomLeft"
            left: Config.options.notifications.position === "topLeft" || Config.options.notifications.position === "bottomLeft"
            right: Config.options.notifications.position === "topRight" || Config.options.notifications.position === "bottomRight"
        }

        mask: Region {
            item: listview.contentItem
        }

        color: "transparent"
        implicitWidth: Appearance.sizes.notificationPopupWidth

        Item {
            id: popupContainer
            anchors.fill: parent

            // Fade popup stack in/out depending on whether there are active popups
            opacity: Notifications.popupAppNameList.length > 0 ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            NotificationListView {
                id: listview
                anchors {
                    top: parent.top
                    bottom: parent.bottom

                    right: (Config.options.notifications.position === "topRight" || Config.options.notifications.position === "bottomRight") ? parent.right : undefined
                    left: (Config.options.notifications.position === "topLeft" || Config.options.notifications.position === "bottomLeft") ? parent.left : undefined

                    topMargin: Config.options.notifications.edgeMargin
                    bottomMargin: Config.options.notifications.edgeMargin
                    rightMargin: (Config.options.notifications.position === "topRight" || Config.options.notifications.position === "bottomRight") ? Config.options.notifications.edgeMargin : 0
                    leftMargin: (Config.options.notifications.position === "topLeft" || Config.options.notifications.position === "bottomLeft") ? Config.options.notifications.edgeMargin : 0
                }
                implicitWidth: parent.width - Appearance.sizes.elevationMargin * 2
                popup: true
            }
        }
    }
}
