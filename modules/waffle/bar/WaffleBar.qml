import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root
    
    readonly property bool isBottom: Config.options?.waffles?.bar?.bottom ?? false
    
    LazyLoader {
        id: barLoader
        active: GlobalStates.barOpen
        component: Variants {
            model: Quickshell.screens
            delegate: PanelWindow { // Bar window
                id: barRoot
                required property var modelData
                screen: modelData
                visible: !GameMode.shouldHidePanels
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: GameMode.shouldHidePanels ? 0 : implicitHeight
                WlrLayershell.namespace: "quickshell:bar"
                mask: Region {
                    item: GameMode.shouldHidePanels ? null : content
                }

                anchors {
                    left: true
                    right: true
                    bottom: root.isBottom
                    top: !root.isBottom
                }

                color: "transparent"
                implicitHeight: content.implicitHeight
                implicitWidth: content.implicitWidth

                WaffleBarContent {
                    id: content
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: !root.isBottom ? parent.top : undefined
                        bottom: root.isBottom ? parent.bottom : undefined
                    }
                    anchors.topMargin: !root.isBottom && GameMode.shouldHidePanels ? -implicitHeight : 0
                    anchors.bottomMargin: root.isBottom && GameMode.shouldHidePanels ? -implicitHeight : 0

                    Behavior on anchors.topMargin {
                        animation: NumberAnimation {
                            duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                        }
                    }
                    Behavior on anchors.bottomMargin {
                        animation: NumberAnimation {
                            duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "wbar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }
    // Note: GlobalShortcut removed - use Niri keybinds with IPC instead
}
