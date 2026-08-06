pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Scope {
    id: root

    Connections {
        target: GlobalStates
        function onWaffleClipboardOpenChanged() {
            if (GlobalStates.waffleClipboardOpen) panelLoader.active = true
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.waffleClipboardOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wClipboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Connections {
                target: GlobalStates
                function onWaffleClipboardOpenChanged() {
                    if (!GlobalStates.waffleClipboardOpen) content.close()
                }
            }

            // Click-outside detection
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    const localPos = mapToItem(content, mouse.x, mouse.y)
                    const outside = (localPos.x < 0 || localPos.x > content.width
                            || localPos.y < 0 || localPos.y > content.height)
                    if (outside) {
                        GlobalStates.waffleClipboardOpen = false
                    }
                }
            }

            WaffleClipboardContent {
                id: content
                anchors.centerIn: parent
                anchors.verticalCenterOffset: (Config.options.waffles?.bar?.bottom ?? true) ? -30 : 30
                onClosed: {
                    GlobalStates.waffleClipboardOpen = false
                    panelLoader.active = false
                }
            }
        }
    }

    // IPC handler - only active when waffle family is active
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

}
