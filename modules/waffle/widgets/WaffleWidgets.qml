import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.state

Scope {
    id: root

    Connections {
        target: WaffleState
        function onWidgetsOpenChanged() {
            if (WaffleState.widgetsOpen) panelLoader.active = true
        }
    }

    // Click-outside-to-close overlay
    LazyLoader {
        active: WaffleState.widgetsOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:wWidgetsBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: WaffleState.widgetsOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: WaffleState.widgetsOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wWidgets"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                bottom: Config.options?.waffles?.bar?.bottom ?? false
                top: !(Config.options?.waffles?.bar?.bottom ?? false)
                left: true
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Connections {
                target: WaffleState
                function onWidgetsOpenChanged() {
                    if (!WaffleState.widgetsOpen) content.close()
                }
            }

            WidgetsContent {
                id: content
                anchors.fill: parent

                onClosed: {
                    WaffleState.widgetsOpen = false
                    panelLoader.active = false
                }
            }
        }
    }

}
