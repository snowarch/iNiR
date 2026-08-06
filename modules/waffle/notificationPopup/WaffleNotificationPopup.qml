pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root

    Component.onCompleted: Notifications.ensureInitialized()
    
    // Position from shared notifications config
    readonly property string position: Config.options?.notifications?.position ?? "bottomRight"
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isLeft: position.endsWith("Left")
    readonly property var targetScreens: {
        const screens = Quickshell.screens
        const list = Config.options?.notifications?.screenList ?? []
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        return matched.length > 0 ? matched : screens
    }

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
            model: root.targetScreens

            PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData
                visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked && !GlobalStates.waffleNotificationCenterOpen && !(GameMode.active && GameMode.suppressNotifications)

                WlrLayershell.namespace: "quickshell:wNotificationPopup"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusiveZone: 0

                // Only capture input on actual notification area
                mask: Region {
                    item: listview
                }

                anchors {
                    top: root.isTop
                    bottom: !root.isTop
                    left: root.isLeft
                    right: !root.isLeft
                }

                color: "transparent"

                implicitWidth: 380
                implicitHeight: Math.min(listview.contentHeight + 16, (screen?.height ?? 800) * 0.7)

                WNotificationListView {
                    id: listview
                    anchors {
                        fill: parent
                        margins: 8
                    }
                }
            }
        }
    }
}
