import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth

    PanelWindow {
        id: sidebarRoot

        Component.onCompleted: visible = GlobalStates.sidebarLeftOpen

        Connections {
            target: GlobalStates
            function onSidebarLeftOpenChanged() {
                if (GlobalStates.sidebarLeftOpen) {
                    _closeTimer.stop()
                    sidebarRoot.visible = true
                } else {
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _closeTimer
            interval: 300
            onTriggered: sidebarRoot.visible = false
        }

        function hide() {
            GlobalStates.sidebarLeftOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        WlrLayershell.namespace: "quickshell:sidebarLeft"
        WlrLayershell.keyboardFocus: GlobalStates.sidebarLeftOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        CompositorFocusGrab {
            id: grab
            windows: [ sidebarRoot ]
            active: CompositorService.isHyprland && sidebarRoot.visible
            onCleared: () => {
                if (!active) sidebarRoot.hide()
            }
        }

        MouseArea {
            id: backdropClickArea
            anchors.fill: parent
            onClicked: mouse => {
                const localPos = mapToItem(sidebarContentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > sidebarContentLoader.width
                        || localPos.y < 0 || localPos.y > sidebarContentLoader.height) {
                    sidebarRoot.hide()
                }
            }
        }

        Loader {
            id: sidebarContentLoader
            active: GlobalStates.sidebarLeftOpen || (Config?.options?.sidebar?.keepLeftSidebarLoaded ?? true)
            anchors {
                top: parent.top
                left: parent.left
                bottom: parent.bottom
                margins: Appearance.sizes.hyprlandGapsOut
                rightMargin: Appearance.sizes.elevationMargin
            }
            width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            // Full slide-out animation (GPU-accelerated)
            property bool animating: false
            transform: Translate {
                x: GlobalStates.sidebarLeftOpen ? 0 : -(root.sidebarWidth + Appearance.sizes.hyprlandGapsOut)
                Behavior on x {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                        onRunningChanged: sidebarContentLoader.animating = running
                    }
                }
            }

            focus: GlobalStates.sidebarLeftOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    sidebarRoot.hide();
                }
            }

            sourceComponent: SidebarLeftContent {
                screenWidth: sidebarRoot.screen?.width ?? 1920
                screenHeight: sidebarRoot.screen?.height ?? 1080
                panelScreen: sidebarRoot.screen ?? null
            }
        }
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle(): void {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        function close(): void {
            GlobalStates.sidebarLeftOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarLeftOpen = true;
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarLeftToggle"
                description: "Toggles left sidebar on press"
                onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
            }
            GlobalShortcut {
                name: "sidebarLeftOpen"
                description: "Opens left sidebar on press"
                onPressed: GlobalStates.sidebarLeftOpen = true
            }
            GlobalShortcut {
                name: "sidebarLeftClose"
                description: "Closes left sidebar on press"
                onPressed: GlobalStates.sidebarLeftOpen = false
            }
        }
    }
}
