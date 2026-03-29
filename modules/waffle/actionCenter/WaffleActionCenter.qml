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

    Connections {
        target: GlobalStates
        function onWaffleActionCenterOpenChanged() {
            if (GlobalStates.waffleActionCenterOpen) {
                if (!root.allowMultiplePanels) {
                    GlobalStates.searchOpen = false
                    GlobalStates.waffleNotificationCenterOpen = false
                }
                panelLoader.active = true
            }
        }
    }

    // Click-outside-to-close overlay
    LazyLoader {
        active: GlobalStates.waffleActionCenterOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:wActionCenterBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.waffleActionCenterOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.waffleActionCenterOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wactionCenter"
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
                function onWaffleActionCenterOpenChanged() {
                    if (!GlobalStates.waffleActionCenterOpen) content.close()
                }
            }

            ActionCenterContent {
                id: content
                anchors.fill: parent
                onClosed: {
                    GlobalStates.waffleActionCenterOpen = false
                    panelLoader.active = false
                }
            }
        }
    }

    function toggleOpen() {
        GlobalStates.waffleActionCenterOpen = !GlobalStates.waffleActionCenterOpen
    }

    IpcHandler {
        target: "wactionCenter"
        function toggle(): void { root.toggleOpen() }
    }
}
