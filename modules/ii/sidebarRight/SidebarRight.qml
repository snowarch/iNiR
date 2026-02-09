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
        id: panelWindow
        visible: GlobalStates.sidebarRightOpen

        function hide() {
            GlobalStates.sidebarRightOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        CompositorFocusGrab {
            id: grab
            windows: [ panelWindow ]
            active: CompositorService.isHyprland && panelWindow.visible
            onCleared: () => {
                if (!active) panelWindow.hide()
            }
        }

        MouseArea {
            id: backdropClickArea
            anchors.fill: parent
            onClicked: mouse => {
                const localPos = mapToItem(sidebarContentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > sidebarContentLoader.width
                        || localPos.y < 0 || localPos.y > sidebarContentLoader.height) {
                    panelWindow.hide()
                }
            }
        }

        Loader {
            id: sidebarContentLoader
            active: GlobalStates.sidebarRightOpen || (Config?.options?.sidebar?.keepRightSidebarLoaded ?? true)
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
                margins: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.elevationMargin
            }
            width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            // Simple slide animation using transform (GPU-accelerated)
            property bool animating: false
            transform: Translate {
                x: GlobalStates.sidebarRightOpen ? 0 : 30
                Behavior on x {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                        onRunningChanged: sidebarContentLoader.animating = running
                    }
                }
            }
            opacity: GlobalStates.sidebarRightOpen ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                }
            }

            sourceComponent: SidebarRightContent {}
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarRightToggle"
                description: "Toggles right sidebar on press"

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }
            }
            GlobalShortcut {
                name: "sidebarRightOpen"
                description: "Opens right sidebar on press"

                onPressed: {
                    GlobalStates.sidebarRightOpen = true;
                }
            }
            GlobalShortcut {
                name: "sidebarRightClose"
                description: "Closes right sidebar on press"

                onPressed: {
                    GlobalStates.sidebarRightOpen = false;
                }
            }
        }
    }

}
