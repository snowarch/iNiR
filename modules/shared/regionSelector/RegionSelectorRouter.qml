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
    function pin(): void { LivePins.frame() }

    /// Region selection tools. Screenshots, OCR, recording. Draw a box, get stuff done.
    ///
    /// ```kdl
    /// Super+Shift+S { spawn "inir" "region" "screenshot"; }
    /// Super+Shift+X { spawn "inir" "region" "ocr"; }
    /// Super+Shift+A { spawn "inir" "region" "search"; }
    /// Ctrl+Shift+S { spawn "inir" "region" "menu"; }
    /// ```
    IpcHandler {
        target: "region"
        /// Take a rectangular region screenshot
        function screenshot(): void { root.screenshot() }
        /// Image search (Google Lens)
        function search(): void { root.search() }
        /// Start a region capture for Google Lens
        function googleLens(): void { root.search() }
        /// OCR text recognition
        function ocr(): void { root.ocr() }
        /// Record region (no audio)
        function record(): void { root.record() }
        /// Record region with audio
        function recordWithSound(): void { root.recordWithSound() }
        /// Open the unified snip menu, optionally restoring its last toolbar choice
        function menu(): void { root.menu() }
        /// Pin part of a window live: pick the window, drag over the part to keep (qs-rs on niri)
        function pin(): void { root.pin() }
        /// Close the selector overlay
        function dismiss(): void { GlobalStates.regionSelectorOpen = false }
        /// Return the selector state (open/action/mode) as JSON
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
