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

    property var ipc: IpcHandler {
        target: "tiling"

        function toggle(): void {
            GlobalStates.tilingOverlayPickerOpen = !GlobalStates.tilingOverlayPickerOpen
            if (GlobalStates.tilingOverlayPickerOpen)
                root.pickerTimer.stop()
        }

        function open(): void {
            GlobalStates.tilingOverlayPickerOpen = true
            root.pickerTimer.stop()
        }

        function hide(): void {
            GlobalStates.tilingOverlayPickerOpen = false
            GlobalStates.tilingOverlayOsdOpen = false
        }

        function cycle(): void {
            NiriService.cycleLayout()
            GlobalStates.tilingOverlayOsdOpen = true
            GlobalStates.tilingOverlayPickerOpen = false
            root.osdTimer.restart()
        }

        function showOsd(): void {
            GlobalStates.tilingOverlayOsdOpen = true
            GlobalStates.tilingOverlayPickerOpen = false
            root.osdTimer.restart()
        }

        function promote(): void {
            NiriService.promoteToMaster()
        }
    }
}
