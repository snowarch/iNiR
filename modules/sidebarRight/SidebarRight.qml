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

        Component {
            id: defaultContentComponent
            SidebarRightContent {
                screenWidth: sidebarRoot.screen?.width ?? 1920
                screenHeight: sidebarRoot.screen?.height ?? 1080
                panelScreen: sidebarRoot.screen ?? null
            }
        }

        Component {
            id: compactContentComponent
            CompactSidebarRightContent {
                screenWidth: sidebarRoot.screen?.width ?? 1920
                screenHeight: sidebarRoot.screen?.height ?? 1080
                panelScreen: sidebarRoot.screen ?? null
            }
        }

        Component {
            id: contentStackComponent
            Item {
                anchors.fill: parent

                FadeLoader {
                    anchors.fill: parent
                    shown: (Config?.options?.sidebar?.layout ?? "default") === "default"
                    sourceComponent: defaultContentComponent
                }

                FadeLoader {
                    anchors.fill: parent
                    shown: (Config?.options?.sidebar?.layout ?? "default") === "compact"
                    sourceComponent: compactContentComponent
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
                    sidebarRoot.hide();
                }
            }

            sourceComponent: contentStackComponent
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
