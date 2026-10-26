import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common
import qs.modules.waffle.state

Scope {
    id: root

    property bool panelMapped: false
    readonly property bool allowMultiplePanels:
        Config.options?.waffles?.behavior?.allowMultiplePanels ?? false

    function enforceExclusivity(): void {
        if (!root.allowMultiplePanels && WaffleState.actionCenterOpen) {
            GlobalStates.searchOpen = false
            WaffleState.notificationCenterOpen = false
        }
    }

    Component.onCompleted: {
        root.panelMapped = WaffleState.actionCenterOpen
        root.enforceExclusivity()
    }

    Connections {
        target: WaffleState
        function onActionCenterOpenChanged() {
            if (WaffleState.actionCenterOpen)
                root.panelMapped = true
            root.enforceExclusivity()
        }
    }

    PanelWindow {
        visible: root.panelMapped
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "quickshell:wActionCenterBg"
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: WaffleState.actionCenterOpen = false
        }
    }

    PanelWindow {
        id: panelWindow
        visible: root.panelMapped
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wactionCenter"
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

        ActionCenterContent {
            id: content
            anchors.fill: parent
            presented: WaffleState.actionCenterOpen
            panelRightAligned: true
            onClosed: {
                if (!WaffleState.actionCenterOpen)
                    root.panelMapped = false
            }
        }
    }
}
