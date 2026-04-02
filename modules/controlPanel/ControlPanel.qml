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
    readonly property real screenWidth: panelRoot.screen?.width ?? 1920
    readonly property real screenHeight: panelRoot.screen?.height ?? 1080
    readonly property var dockConfig: Config.options?.dock ?? ({})
    readonly property bool dockEnabled: dockConfig?.enable ?? false
    readonly property real safePadding: Math.max(
        Appearance.sizes.hyprlandGapsOut * 2,
        Math.round(Math.min(screenWidth, screenHeight) * 0.02)
    )
    readonly property real topReservedSpace: safePadding
        + (!(Config.options?.bar?.bottom ?? false) ? Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2 : 0)
        + ((dockEnabled && dockConfig?.position === "top") ? ((dockConfig?.height ?? 60) + safePadding) : 0)
    readonly property real bottomReservedSpace: safePadding
        + ((Config.options?.bar?.bottom ?? false) ? Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2 : 0)
        + ((dockEnabled && dockConfig?.position === "bottom") ? ((dockConfig?.height ?? 60) + safePadding) : 0)
    readonly property real leftReservedSpace: safePadding
        + ((dockEnabled && dockConfig?.position === "left") ? ((dockConfig?.width ?? dockConfig?.height ?? 60) + safePadding) : 0)
    readonly property real rightReservedSpace: safePadding
        + ((dockEnabled && dockConfig?.position === "right") ? ((dockConfig?.width ?? dockConfig?.height ?? 60) + safePadding) : 0)
    readonly property real availablePanelHeight: Math.max(260, screenHeight - topReservedSpace - bottomReservedSpace)
    readonly property real availablePanelWidth: Math.max(280, screenWidth - leftReservedSpace - rightReservedSpace)
    readonly property real panelWidth: Math.round(Math.min(availablePanelWidth, 380))
    readonly property real panelVerticalOffset: Math.round(Math.min(
        Appearance.sizes.baseBarHeight / 2,
        Math.max(0, availablePanelHeight * 0.08)
    ))
    readonly property real maxPanelHeight: Math.max(
        260,
        root.availablePanelHeight - Math.max(root.panelVerticalOffset * 2, Math.round(root.safePadding * 0.5))
    )

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
        WlrLayershell.keyboardFocus: GlobalStates.controlPanelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

        Item {
            id: safeBounds
            anchors {
                fill: parent
                leftMargin: root.leftReservedSpace
                rightMargin: root.rightReservedSpace
                topMargin: root.topReservedSpace
                bottomMargin: root.bottomReservedSpace
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.controlPanelOpen || (Config?.options?.controlPanel?.keepLoaded ?? false)
            property real panelTranslateY: -24
            states: [
                State {
                    name: "open"
                    when: GlobalStates.controlPanelOpen
                    PropertyChanges {
                        target: contentLoader
                        opacity: 1
                        scale: 1
                        panelTranslateY: 0
                    }
                },
                State {
                    name: "closed"
                    when: !GlobalStates.controlPanelOpen
                    PropertyChanges {
                        target: contentLoader
                        opacity: 0
                        scale: 0.94
                        panelTranslateY: -24
                    }
                }
            ]
            transitions: [
                Transition {
                    to: "open"
                    enabled: Appearance.animationsEnabled
                    ParallelAnimation {
                        NumberAnimation {
                            target: contentLoader
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardDecel ?? [0, 0, 0, 1, 1, 1]
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: contentLoader
                                property: "scale"
                                from: 0.94
                                to: 1.018
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.62)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: contentLoader
                                property: "scale"
                                to: 1
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.38)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.expressiveEffects ?? [0.2, 0, 0, 1, 1, 1]
                            }
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: contentLoader
                                property: "panelTranslateY"
                                from: -24
                                to: 6
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.62)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: contentLoader
                                property: "panelTranslateY"
                                to: 0
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.38)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.expressiveEffects ?? [0.2, 0, 0, 1, 1, 1]
                            }
                        }
                    }
                },
                Transition {
                    to: "closed"
                    enabled: Appearance.animationsEnabled
                    ParallelAnimation {
                        NumberAnimation {
                            target: contentLoader
                            property: "opacity"
                            to: 0
                            duration: Math.round((Appearance.animation?.elementMoveExit?.duration ?? 200) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardAccel ?? [0.3, 0, 1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "scale"
                            to: 0.94
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "panelTranslateY"
                            to: -24
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                    }
                }
            ]
            
            anchors {
                horizontalCenter: safeBounds.horizontalCenter
                verticalCenter: safeBounds.verticalCenter
                verticalCenterOffset: (Config.options?.bar?.bottom ?? false) ? -root.panelVerticalOffset : root.panelVerticalOffset
            }
            
            width: root.panelWidth
            height: item?.implicitHeight ? Math.min(item.implicitHeight, root.maxPanelHeight) : root.maxPanelHeight

            // Animation driven entirely by states/transitions above
            opacity: 0
            scale: 0.94
            transform: Translate {
                y: contentLoader.panelTranslateY
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
