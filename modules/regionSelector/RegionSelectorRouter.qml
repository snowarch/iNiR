pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

Scope {
    id: root

    function open(action, mode): void {
        GlobalStates.regionSelectorAction = action
        GlobalStates.regionSelectorMode = mode
        GlobalStates.regionSelectorOpen = true
    }
    // Dedicated screenshot calls are always a rectangular capture. The unified
    // menu is the only entry point allowed to restore a previous toolbar choice.
    function screenshot(): void { GlobalStates.openRegionScreenshot() }
    function search(): void {
        open(RegionSelection.SnipAction.Search,
            (Config.options?.search?.imageSearch?.useCircleSelection ?? false)
                ? RegionSelection.SelectionMode.Circle : RegionSelection.SelectionMode.RectCorners)
    }
    function ocr(): void { open(RegionSelection.SnipAction.CharRecognition, RegionSelection.SelectionMode.RectCorners) }
    function record(): void { open(RegionSelection.SnipAction.Record, RegionSelection.SelectionMode.RectCorners) }
    function recordWithSound(): void { open(RegionSelection.SnipAction.RecordWithSound, RegionSelection.SelectionMode.RectCorners) }
    function menu(): void { GlobalStates.openRememberedRegionTool() }

    IpcHandler {
        target: "region"
        function screenshot(): void { root.screenshot() }
        function search(): void { root.search() }
        function googleLens(): void { root.search() }
        function ocr(): void { root.ocr() }
        function record(): void { root.record() }
        function recordWithSound(): void { root.recordWithSound() }
        function menu(): void { root.menu() }
        function dismiss(): void { GlobalStates.regionSelectorOpen = false }
        function current(): string {
            return JSON.stringify({
                open: GlobalStates.regionSelectorOpen,
                action: GlobalStates.regionSelectorAction,
                mode: GlobalStates.regionSelectorMode
            })
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut { name: "regionScreenshot"; description: "Takes a screenshot of the selected region"; onPressed: root.screenshot() }
            GlobalShortcut { name: "regionSearch"; description: "Searches the selected region"; onPressed: root.search() }
            GlobalShortcut { name: "regionOcr"; description: "Recognizes text in the selected region"; onPressed: root.ocr() }
            GlobalShortcut { name: "regionRecord"; description: "Records the selected region"; onPressed: root.record() }
            GlobalShortcut { name: "regionRecordWithSound"; description: "Records the selected region with the configured audio profile"; onPressed: root.recordWithSound() }
            GlobalShortcut { name: "regionMenu"; description: "Opens the unified snip menu"; onPressed: root.menu() }
        }
    }
}
