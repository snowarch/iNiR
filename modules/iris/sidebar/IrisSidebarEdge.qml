pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

Scope {
    id: root
    required property string side
    readonly property bool left: root.side === "left"
    readonly property var options: Config.options?.iris?.sidebars?.[root.side] ?? ({})
    readonly property bool enabled: (root.options.enable ?? true) && (root.options.hoverReveal ?? false)
    readonly property bool panelOpen: root.left ? GlobalStates.sidebarLeftOpen : GlobalStates.sidebarRightOpen

    Variants {
        model: root.enabled ? Quickshell.screens : []
        PanelWindow {
            id: strip
            required property var modelData
            screen: modelData
            visible: !root.panelOpen && !GlobalStates.screenLocked && !GlobalStates.widgetEditMode
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:iris-sidebar-edge-" + root.side
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { left: root.left; right: !root.left; top: true; bottom: true }
            implicitWidth: 1

            HoverHandler { id: edgeHover }
            Timer {
                interval: 140
                running: edgeHover.hovered
                onTriggered: {
                    GlobalStates.irisSidebarPeek = root.side
                    if (root.left) GlobalStates.openSidebarLeft(strip.modelData?.name ?? "")
                    else GlobalStates.openSidebarRight(strip.modelData?.name ?? "")
                }
            }
        }
    }
}
