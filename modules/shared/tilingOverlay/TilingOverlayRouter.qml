pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs
import qs.services

QtObject {
    id: root

    property var osdTimer: Timer {
        interval: 1500
        onTriggered: GlobalStates.tilingOverlayOsdOpen = false
    }

    property var pickerTimer: Timer {
        interval: 2500
        onTriggered: GlobalStates.tilingOverlayPickerOpen = false
    }

    property var layoutConnections: Connections {
        target: NiriService
        function onLayoutApplied(layout, count): void {
            GlobalStates.tilingOverlayOsdOpen = true
            root.osdTimer.restart()
        }
    }

    /// Tiling layout overlay. Pick or cycle through tiling presets for the current workspace.
    property var ipc: IpcHandler {
        target: "tiling"

        /// Open/close tiling picker
        function toggle(): void {
            GlobalStates.tilingOverlayPickerOpen = !GlobalStates.tilingOverlayPickerOpen
            if (GlobalStates.tilingOverlayPickerOpen)
                root.pickerTimer.stop()
        }

        /// Open tiling picker
        function open(): void {
            GlobalStates.tilingOverlayPickerOpen = true
            root.pickerTimer.stop()
        }

        /// Close picker and OSD
        function hide(): void {
            GlobalStates.tilingOverlayPickerOpen = false
            GlobalStates.tilingOverlayOsdOpen = false
        }

        /// Cycle to next tiling preset (shows OSD)
        function cycle(): void {
            NiriService.cycleLayout()
            GlobalStates.tilingOverlayOsdOpen = true
            GlobalStates.tilingOverlayPickerOpen = false
            root.osdTimer.restart()
        }

        /// Flash the current tiling preset OSD
        function showOsd(): void {
            GlobalStates.tilingOverlayOsdOpen = true
            GlobalStates.tilingOverlayPickerOpen = false
            root.osdTimer.restart()
        }

        /// Promote focused window to master position
        function promote(): void {
            NiriService.promoteToMaster()
        }
    }
}
