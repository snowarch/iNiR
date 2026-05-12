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
    readonly property bool instantOpen: Config.options?.sidebar?.instantOpen ?? false
    readonly property string animationType: Config.options?.sidebar?.animationType ?? "slide"
    // Expanded width when a webapp is active
    property bool pluginViewActive: false
    // Track transitions to disable width animation during webapp open/close
    property bool _pluginTransitioning: false
    onPluginViewActiveChanged: {
        root._pluginTransitioning = true
        _pluginTransitionTimer.restart()
    }
    Timer {
        id: _pluginTransitionTimer
        interval: 50
        onTriggered: root._pluginTransitioning = false
    }
    readonly property real effectiveSidebarWidth: pluginViewActive
        ? Appearance.sizes.sidebarWidthExtended
        : sidebarWidth

    // Deferred slide trigger: ensures the Wayland surface is mapped before
    // the Behavior animation starts, so Qt tracks the "from" position correctly.
    property bool _sidebarShown: false

    PanelWindow {
        id: sidebarRoot

        Component.onCompleted: {
            root._sidebarShown = GlobalStates.sidebarLeftOpen
        }

        Connections {
            target: GlobalStates
            function onSidebarLeftOpenChanged() {
                if (GlobalStates.sidebarLeftOpen) {
                    // Let the surface settle for one frame before sliding in
                    Qt.callLater(() => { root._sidebarShown = true })
                } else {
                    root._sidebarShown = false
                }
            }
        }

        function hide() {
            GlobalStates.sidebarLeftOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        WlrLayershell.namespace: "quickshell:sidebarLeft"
        WlrLayershell.keyboardFocus: GlobalStates.sidebarLeftOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        // Keep the surface always mapped to avoid Qt6 physicalDpiChanged infinite
        // recursion (stack overflow) triggered by Hyprland sending a Wayland scale
        // event on remap. Input is controlled via mask instead of visibility.
        mask: Region { item: GlobalStates.sidebarLeftOpen ? backdropClickArea : noInputItem }

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        Item { id: noInputItem; width: 0; height: 0 }

        CompositorFocusGrab {
            id: grab
            windows: [ sidebarRoot ]
            active: CompositorService.isHyprland && GlobalStates.sidebarLeftOpen
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
            width: root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            Behavior on width {
                // Disable animation when webapp toggles — avoids choppy WebEngine re-layout
                enabled: Appearance.animationsEnabled && !root._pluginTransitioning
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(250)
                    easing.type: Easing.OutCubic
                }
            }
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            // Animation properties driven by states/transitions below
            property real animTranslateX: -(root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
            property real animOpacity: 1
            property real animScale: 1
            // Clip wrapper for "reveal" animation
            property bool useClip: root.animationType === "reveal"
            property real clipWidth: root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            // Drop: vertical offset; Swing: horizontal scale from edge
            property real animTranslateY: 0
            property real animScaleX: 1

            property bool animating: false
            transform: [
                Translate { x: sidebarContentLoader.animTranslateX; y: sidebarContentLoader.animTranslateY },
                Scale { xScale: sidebarContentLoader.animScaleX; origin.x: 0; origin.y: sidebarContentLoader.height / 2 }
            ]
            opacity: sidebarContentLoader.animOpacity
            scale: sidebarContentLoader.animScale

            states: [
                State {
                    name: "open"
                    when: root._sidebarShown
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX: 0
                        animOpacity: 1
                        animScale: 1
                        animTranslateY: 0
                        animScaleX: 1
                        clipWidth: root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                    }
                },
                State {
                    name: "closed"
                    when: !root._sidebarShown
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX: root.animationType === "slide" || root.animationType === "reveal"
                            ? -(root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
                            : 0
                        animOpacity: (root.animationType === "slide" || root.animationType === "reveal") ? 1 : 0
                        animScale: root.animationType === "elastic" ? 0.88
                            : root.animationType === "pop" ? 0.94 : 1
                        animTranslateY: root.animationType === "drop"
                            ? -(sidebarContentLoader.height + Appearance.sizes.hyprlandGapsOut * 2) : 0
                        animScaleX: root.animationType === "swing" ? 0 : 1
                        clipWidth: root.animationType === "reveal" ? 0
                            : root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                    }
                }
            ]
            transitions: [
                Transition {
                    to: "open"
                    enabled: Appearance.animationsEnabled && !root._pluginTransitioning && !root.instantOpen
                    ParallelAnimation {
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateX"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateY"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animOpacity"
                            duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardDecel ?? [0, 0, 0, 1, 1, 1]
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: sidebarContentLoader; property: "animScale"
                                from: root.animationType === "elastic" ? 0.88
                                    : root.animationType === "pop" ? 0.94 : 1
                                to: root.animationType === "elastic" ? 1.04
                                    : root.animationType === "pop" ? 1.018 : 1
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.62)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: sidebarContentLoader; property: "animScale"
                                to: 1
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.38)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.expressiveEffects ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
                            }
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animScaleX"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "clipWidth"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                    onRunningChanged: sidebarContentLoader.animating = running
                },
                Transition {
                    to: "closed"
                    enabled: Appearance.animationsEnabled && !root._pluginTransitioning && !root.instantOpen
                    ParallelAnimation {
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateX"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateY"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animOpacity"
                            duration: Math.round((Appearance.animation?.elementMoveExit?.duration ?? 200) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardAccel ?? [0.3, 0, 1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animScale"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animScaleX"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "clipWidth"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                    }
                    onRunningChanged: sidebarContentLoader.animating = running
                }
            ]

            // Clip container for "reveal" animation — wraps the content
            clip: sidebarContentLoader.useClip

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
                onPluginViewActiveChanged: root.pluginViewActive = pluginViewActive
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
