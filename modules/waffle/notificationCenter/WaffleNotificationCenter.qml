import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    readonly property bool allowMultiplePanels: Config.options?.waffles?.behavior?.allowMultiplePanels ?? false

    Component.onCompleted: Notifications.ensureInitialized()

    Connections {
        target: GlobalStates
        function onWaffleNotificationCenterOpenChanged() {
            if (GlobalStates.waffleNotificationCenterOpen) {
                if (!root.allowMultiplePanels) {
                    GlobalStates.searchOpen = false
                    GlobalStates.waffleActionCenterOpen = false
                }
                panelLoader.active = true
            }
        }
    }

    // Click-outside-to-close overlay
    LazyLoader {
        active: GlobalStates.waffleNotificationCenterOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:wNotificationCenterBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.waffleNotificationCenterOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.waffleNotificationCenterOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wNotificationCenter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                bottom: Config.options?.waffles?.bar?.bottom ?? false
                top: !(Config.options?.waffles?.bar?.bottom ?? false)
                right: true
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Connections {
                target: GlobalStates
                function onWaffleNotificationCenterOpenChanged() {
                    if (!GlobalStates.waffleNotificationCenterOpen) content.close()
                }
            }

            NotificationCenterContent {
                id: content
                anchors.fill: parent
                onClosed: {
                    GlobalStates.waffleNotificationCenterOpen = false
                    panelLoader.active = false
                }
            }
        }
    }

    function toggleOpen() {
        GlobalStates.waffleNotificationCenterOpen = !GlobalStates.waffleNotificationCenterOpen
    }

    IpcHandler {
        target: "wnotificationCenter"
        function toggle(): void { root.toggleOpen() }
    }
}
