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
    property bool _presentedOpen: false
    readonly property real screenWidth: panelRoot.screen?.width ?? 1920
    readonly property real screenHeight: panelRoot.screen?.height ?? 1080
    readonly property real safePadding: Math.max(
        Appearance.sizes.hyprlandGapsOut * 2,
        Math.round(Math.min(screenWidth, screenHeight) * 0.02)
    )
    readonly property real barReservedSpace: Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2
    readonly property real topReservedSpace: safePadding
        + (!(Config.options?.bar?.bottom ?? false) ? barReservedSpace : 0)
    readonly property real bottomReservedSpace: safePadding
        + ((Config.options?.bar?.bottom ?? false) ? barReservedSpace : 0)
    readonly property real availablePanelHeight: Math.max(360, screenHeight - topReservedSpace - bottomReservedSpace)
    readonly property real availablePanelWidth: Math.max(480, screenWidth - safePadding * 2)
    readonly property real widthRatio: Math.min(0.9, Math.max(0.4, Config.options?.dashboard?.widthRatio ?? 0.62))
    readonly property real panelWidth: Math.round(Math.min(availablePanelWidth, screenWidth * widthRatio))
    readonly property real panelHeight: Math.round(Math.min(availablePanelHeight, 860))

    PanelWindow {
        id: panelRoot

        Component.onCompleted: {
            visible = GlobalStates.dashboardOpen
            if (GlobalStates.dashboardOpen)
                Qt.callLater(() => { root._presentedOpen = GlobalStates.dashboardOpen })
        }

        Connections {
            target: GlobalStates
            function onDashboardOpenChanged() {
                if (GlobalStates.dashboardOpen) {
                    _closeTimer.stop()
                    panelRoot.visible = true
                    Qt.callLater(() => { root._presentedOpen = GlobalStates.dashboardOpen })
                } else {
                    root._presentedOpen = false
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
            GlobalStates.dashboardOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        WlrLayershell.namespace: "quickshell:dashboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.dashboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
            active: GlobalStates.dashboardOpen || (Config.options?.dashboard?.keepLoaded ?? false)

            // Shell desaturation effect
            layer.enabled: Appearance.shouldDesaturate("overlays") && contentLoader.visible
            layer.effect: ShellDesaturationEffect {}

            property real panelTranslateY: 18
            states: [
                State {
                    name: "open"
                    when: root._presentedOpen
                    PropertyChanges {
                        target: contentLoader
                        opacity: 1
                        scale: 1
                        panelTranslateY: 0
                    }
                },
                State {
                    name: "closed"
                    when: !root._presentedOpen
                    PropertyChanges {
                        target: contentLoader
                        opacity: 0
                        scale: 0.96
                        panelTranslateY: 18
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
                            duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardDecel ?? [0, 0, 0, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "scale"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "panelTranslateY"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
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
                            duration: Math.round((Appearance.animation?.elementMoveExit?.duration ?? 200) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardAccel ?? [0.3, 0, 1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "scale"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "panelTranslateY"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                    }
                }
            ]

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round((root.topReservedSpace - root.bottomReservedSpace) / 2)

            width: root.panelWidth
            height: root.panelHeight

            opacity: 0
            scale: 0.96
            transform: Translate { y: contentLoader.panelTranslateY }

            focus: GlobalStates.dashboardOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide()
                }
            }

            sourceComponent: DashboardContent {
                screenWidth: panelRoot.screen?.width ?? 1920
                screenHeight: panelRoot.screen?.height ?? 1080
            }
        }
    }

}
