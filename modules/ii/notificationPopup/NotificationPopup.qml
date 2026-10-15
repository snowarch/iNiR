import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Scope {
    id: notificationPopup

    property var excludedScreenNames: []

    // Position from config: topRight, topLeft, bottomRight, bottomLeft
    readonly property string position: Config.options?.notifications?.position ?? "topRight"
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isLeft: position.endsWith("Left")
    readonly property var targetScreens: {
        const screens = Quickshell.screens
        const list = Config.options?.notifications?.screenList ?? []
        let selected = screens
        if (list && list.length > 0) {
            const matched = screens.filter(screen => {
                const screenName = screen?.name ?? ""
                return screenName.length > 0 && list.includes(screenName)
            })
            selected = matched.length > 0 ? matched : screens
        }
        return selected.filter(screen => !notificationPopup.excludedScreenNames.includes(screen?.name ?? ""))
    }

    Component.onCompleted: Notifications.ensureInitialized()

    Loader {
        id: popupLoader
        property bool resident: Notifications.popupList.length > 0
        active: resident

        Connections {
            target: Notifications
            function onPopupListChanged() {
                if (Notifications.popupList.length > 0) {
                    popupCloseGrace.stop()
                    popupLoader.resident = true
                } else {
                    popupCloseGrace.restart()
                }
            }
        }

        Timer {
            id: popupCloseGrace
            interval: 450
            onTriggered: popupLoader.resident = Notifications.popupList.length > 0
        }

        sourceComponent: Variants {
            model: notificationPopup.targetScreens

            PanelWindow {
                id: popupWindow
                required property var modelData
                screen: modelData
                visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked && !(GameMode.active && GameMode.suppressNotifications)

                WlrLayershell.namespace: "quickshell:notificationPopup"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusiveZone: 0

                // Only capture input on actual notification area
                mask: Region {
                    item: listview
                }

                anchors {
                    top: notificationPopup.isTop
                    bottom: !notificationPopup.isTop
                    left: notificationPopup.isLeft
                    right: !notificationPopup.isLeft
                }

                color: "transparent"

                implicitWidth: Appearance.sizes.notificationPopupWidth
                // Add height buffer to account for Wayland compositor resize delay
                // This prevents content clipping while the window catches up to new content size
                implicitHeight: Math.min(listview.contentHeight + edgeMargin * 2 + heightBuffer, screen?.height * 0.8 ?? 600)

                readonly property int edgeMargin: Config.options?.notifications?.edgeMargin ?? 4
                // Extra buffer so content isn't clipped during async Wayland resize
                readonly property int heightBuffer: 16

                NotificationListView {
                    id: listview
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: popupWindow.edgeMargin
                        leftMargin: popupWindow.edgeMargin
                        rightMargin: popupWindow.edgeMargin
                    }
                    // Size to content — don't stretch to fill PanelWindow
                    // The heightBuffer only enlarges the window (prevents Wayland clipping)
                    // but the listview stays content-sized so no empty space is visible
                    implicitHeight: contentHeight
                    // Clip content to prevent overflow while PanelWindow resizes asynchronously
                    clip: true
                    popup: true
                }
            }
        }
    }
}
