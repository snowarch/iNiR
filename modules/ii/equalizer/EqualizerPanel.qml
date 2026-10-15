pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    property bool _presentedOpen: false

    function presentWhenReady(): void {
        if (!GlobalStates.equalizerOpen || contentLoader.status !== Loader.Ready)
            return
        Qt.callLater(() => {
            if (GlobalStates.equalizerOpen && contentLoader.status === Loader.Ready)
                root._presentedOpen = true
        })
    }

    readonly property var targetScreen: {
        const requested = String(GlobalStates.equalizerTargetOutput ?? "")
        const matched = requested.length > 0
            ? Quickshell.screens.find(screen => String(screen?.name ?? "") === requested)
            : null
        return matched ?? GlobalStates.focusedScreen ?? Quickshell.screens[0]
    }
    readonly property real screenWidth: root.targetScreen?.width ?? 1920
    readonly property real screenHeight: root.targetScreen?.height ?? 1080
    readonly property var dockConfig: Config.options?.dock ?? ({})
    readonly property bool dockEnabled: dockConfig?.enable ?? false
    readonly property real safePadding: Math.max(
        Appearance.sizes.hyprlandGapsOut * 2,
        Math.round(Math.min(root.screenWidth, root.screenHeight) * 0.02)
    )
    readonly property real topReservedSpace: root.safePadding
        + (!(Config.options?.bar?.bottom ?? false) ? Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2 : 0)
        + ((root.dockEnabled && root.dockConfig?.position === "top") ? ((root.dockConfig?.height ?? 60) + root.safePadding) : 0)
    readonly property real bottomReservedSpace: root.safePadding
        + ((Config.options?.bar?.bottom ?? false) ? Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2 : 0)
        + ((root.dockEnabled && root.dockConfig?.position === "bottom") ? ((root.dockConfig?.height ?? 60) + root.safePadding) : 0)
    readonly property real leftReservedSpace: root.safePadding
        + ((root.dockEnabled && root.dockConfig?.position === "left") ? ((root.dockConfig?.width ?? root.dockConfig?.height ?? 60) + root.safePadding) : 0)
    readonly property real rightReservedSpace: root.safePadding
        + ((root.dockEnabled && root.dockConfig?.position === "right") ? ((root.dockConfig?.width ?? root.dockConfig?.height ?? 60) + root.safePadding) : 0)
    readonly property real availableWidth: Math.max(340, root.screenWidth - root.leftReservedSpace - root.rightReservedSpace)
    readonly property real availableHeight: Math.max(360, root.screenHeight - root.topReservedSpace - root.bottomReservedSpace)
    readonly property real panelWidth: Math.round(Math.min(596, Math.max(380, root.availableWidth * 0.74)))
    readonly property real maxPanelHeight: Math.round(Math.min(760, root.availableHeight))

    PanelWindow {
        id: panelRoot

        screen: root.targetScreen
        visible: false
        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        color: "transparent"
        WlrLayershell.namespace: "quickshell:equalizer"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.equalizerOpen
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        Component.onCompleted: {
            panelRoot.visible = GlobalStates.equalizerOpen
            if (GlobalStates.equalizerOpen)
                root.presentWhenReady()
        }

        Connections {
            target: GlobalStates
            function onEqualizerOpenChanged(): void {
                if (GlobalStates.equalizerOpen) {
                    closeTimer.stop()
                    panelRoot.visible = true
                    root.presentWhenReady()
                } else {
                    root._presentedOpen = false
                    closeTimer.restart()
                }
            }
        }

        Timer {
            id: closeTimer
            interval: Appearance.animationsEnabled ? 240 : 0
            onTriggered: panelRoot.visible = false
        }

        CompositorFocusGrab {
            windows: [panelRoot]
            active: CompositorService.isHyprland && panelRoot.visible
            onCleared: () => {
                if (!active) GlobalStates.closeEqualizer()
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                const local = mapToItem(contentLoader, mouse.x, mouse.y)
                if (local.x < 0 || local.x > contentLoader.width
                        || local.y < 0 || local.y > contentLoader.height)
                    GlobalStates.closeEqualizer()
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
            active: GlobalStates.equalizerOpen || closeTimer.running
            width: root.panelWidth
            height: item?.implicitHeight
                ? Math.min(item.implicitHeight, root.maxPanelHeight)
                : Math.min(520, root.maxPanelHeight)
            anchors {
                left: safeBounds.left
                verticalCenter: safeBounds.verticalCenter
            }
            focus: GlobalStates.equalizerOpen
            opacity: 0
            scale: 0.985
            property real panelTranslateX: -28

            onStatusChanged: {
                if (status === Loader.Ready)
                    root.presentWhenReady()
            }

            layer.enabled: Appearance.shouldDesaturate("overlays") && contentLoader.visible
            layer.effect: ShellDesaturationEffect {}

            states: [
                State {
                    name: "open"
                    when: root._presentedOpen
                    PropertyChanges {
                        target: contentLoader
                        opacity: 1
                        scale: 1
                        panelTranslateX: 0
                    }
                },
                State {
                    name: "closed"
                    when: !root._presentedOpen
                    PropertyChanges {
                        target: contentLoader
                        opacity: 0
                        scale: 0.985
                        panelTranslateX: -28
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
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "scale"
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "panelTranslateX"
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
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
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "scale"
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                        }
                        NumberAnimation {
                            target: contentLoader
                            property: "panelTranslateX"
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                        }
                    }
                }
            ]

            transform: Translate { x: contentLoader.panelTranslateX }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.closeEqualizer()
                    event.accepted = true
                }
            }

            sourceComponent: EqualizerContent {}
        }
    }
}
