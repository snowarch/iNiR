import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common

Scope {
    id: root

    property bool panelMapped: false
    readonly property bool allowMultiplePanels:
        Config.options?.waffles?.behavior?.allowMultiplePanels ?? false

    function enforceExclusivity(): void {
        if (!root.allowMultiplePanels && GlobalStates.waffleNotificationCenterOpen) {
            GlobalStates.searchOpen = false
            GlobalStates.waffleActionCenterOpen = false
        }
    }

    Component.onCompleted: {
        root.panelMapped = GlobalStates.waffleNotificationCenterOpen
        Notifications.ensureInitialized()
        root.enforceExclusivity()
    }

    Connections {
        target: GlobalStates
        function onWaffleNotificationCenterOpenChanged() {
            if (GlobalStates.waffleNotificationCenterOpen)
                root.panelMapped = true
            root.enforceExclusivity()
        }
    }

    PanelWindow {
        visible: root.panelMapped
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "quickshell:wNotificationCenterBg"
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.waffleNotificationCenterOpen = false
        }
    }

    PanelWindow {
        id: panelWindow
        visible: root.panelMapped
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wNotificationCenter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            bottom: Config.options?.waffles?.bar?.bottom ?? false
            top: !(Config.options?.waffles?.bar?.bottom ?? false)
            right: true
        }

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        NotificationCenterContent {
            id: content
            anchors.fill: parent
            presented: GlobalStates.waffleNotificationCenterOpen
            panelRightAligned: true
            onClosed: {
                if (!GlobalStates.waffleNotificationCenterOpen)
                    root.panelMapped = false
            }
        }
    }
}
