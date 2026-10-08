pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.iris.frame

Variants {
    model: Quickshell.screens

    delegate: Scope {
        id: screenScope
        required property var modelData
        readonly property string outputName: screenScope.modelData?.name ?? ""
        readonly property var leftSidebar: Config.options?.iris?.sidebars?.left ?? ({})
        readonly property var rightSidebar: Config.options?.iris?.sidebars?.right ?? ({})
        readonly property bool chassisPresent: {
            if (!GlobalStates.barOpen || !(Config.options?.enabledPanels ?? []).includes("irisBar")) return false
            const list = Config.options?.iris?.bar?.screenList ?? []
            if (!list || list.length === 0) return true
            const matched = Quickshell.screens.filter(screen => list.includes(screen?.name ?? ""))
            return matched.length === 0 || list.includes(screenScope.outputName)
        }

        function sidebarDepth(edge: string): real {
            const left = edge === "left"
            if (!left && edge !== "right") return 0
            const options = left ? screenScope.leftSidebar : screenScope.rightSidebar
            const open = left ? GlobalStates.sidebarLeftOpen : GlobalStates.sidebarRightOpen
            const output = left ? GlobalStates.sidebarLeftPresentationOutput : GlobalStates.sidebarRightPresentationOutput
            if (GlobalStates.screenLocked || !open || !(options?.enable ?? true)
                    || !(options?.pinned ?? false) || !(options?.reserveSpace ?? true)
                    || output !== screenScope.outputName) return 0
            const width = Math.max(300, Math.min(600, Number(options?.width ?? 380))) * IrisFrame.d
            const held = IrisFrame.clear(edge) - IrisFrame.band
            const air = (options?.notch ?? false) && held <= 0 ? 0 : 12 * IrisFrame.d
            return Math.round(IrisFrame.band + held + width + air)
        }

        component Reservation: PanelWindow {
            id: stub
            required property string edge
            screen: screenScope.modelData
            visible: true
            color: "transparent"
            WlrLayershell.namespace: "quickshell:iris-reserve-" + stub.edge
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Math.max(IrisFrame.reserve(stub.edge, screenScope.chassisPresent), screenScope.sidebarDepth(stub.edge))
            // One edge only: opposite-edge anchors lose the exclusive zone.
            anchors {
                top: stub.edge === "top"
                bottom: stub.edge === "bottom"
                left: stub.edge === "left"
                right: stub.edge === "right"
            }
            implicitWidth: 1
            implicitHeight: 1
            mask: Region {}
        }

        Reservation { edge: "top" }
        Reservation { edge: "bottom" }
        Reservation { edge: "left" }
        Reservation { edge: "right" }
    }
}
