import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int panelWidth: 380
    property int maxPanelHeight: (panelRoot.screen?.height ?? 1080) - Appearance.sizes.hyprlandGapsOut * 4 - Appearance.sizes.baseBarHeight - 40

    PanelWindow {
        id: panelRoot

        Component.onCompleted: visible = GlobalStates.controlPanelOpen

        Connections {
            target: GlobalStates
            function onControlPanelOpenChanged() {
                if (GlobalStates.controlPanelOpen) {
                    _closeTimer.stop()
                    panelRoot.visible = true
                } else {
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _closeTimer
            interval: 250
            onTriggered: panelRoot.visible = false
        }

        function hide() {
            GlobalStates.controlPanelOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        WlrLayershell.namespace: "quickshell:controlPanel"
        WlrLayershell.layer: WlrLayer.Overlay
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
            windows: [ panelRoot ]
            active: CompositorService.isHyprland && panelRoot.visible
            onCleared: () => {
                if (!active) panelRoot.hide()
            }
        }

        // Backdrop click to close
        MouseArea {
            id: backdropClickArea
            anchors.fill: parent
            onClicked: mouse => {
                const localPos = mapToItem(contentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > contentLoader.width
                        || localPos.y < 0 || localPos.y > contentLoader.height) {
                    panelRoot.hide()
                }
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.controlPanelOpen || (Config?.options?.controlPanel?.keepLoaded ?? false)
            
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: Config.options?.bar?.bottom ? -Appearance.sizes.baseBarHeight / 2 : Appearance.sizes.baseBarHeight / 2
            }
            
            width: root.panelWidth
            height: item?.implicitHeight ? Math.min(item.implicitHeight, root.maxPanelHeight) : root.maxPanelHeight

            // Smooth scale + slide + fade animation (GPU-accelerated)
            opacity: GlobalStates.controlPanelOpen ? 1 : 0
            scale: GlobalStates.controlPanelOpen ? 1.0 : 0.92
            transform: Translate {
                y: GlobalStates.controlPanelOpen ? 0 : -40
                Behavior on y {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: GlobalStates.controlPanelOpen ?
                            (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                            (Appearance.animation?.elementMoveExit?.duration ?? 200)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: GlobalStates.controlPanelOpen ?
                            (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                            (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                    }
                }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: GlobalStates.controlPanelOpen ?
                        (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                        (Appearance.animation?.elementMoveExit?.duration ?? 200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: GlobalStates.controlPanelOpen ?
                        (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                        (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: GlobalStates.controlPanelOpen ?
                        (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                        (Appearance.animation?.elementMoveExit?.duration ?? 200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: GlobalStates.controlPanelOpen ?
                        (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                        (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                }
            }

            focus: GlobalStates.controlPanelOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide()
                }
            }

            sourceComponent: ControlPanelContent {
                screenWidth: panelRoot.screen?.width ?? 1920
                screenHeight: panelRoot.screen?.height ?? 1080
            }
        }
    }

    IpcHandler {
        target: "controlPanel"

        function toggle(): void {
            GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
        }

        function close(): void {
            GlobalStates.controlPanelOpen = false
        }

        function open(): void {
            GlobalStates.controlPanelOpen = true
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "controlPanelToggle"
            description: "Toggles control panel on press"

            onPressed: {
                GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
            }
        }
    }
}
