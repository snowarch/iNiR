pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * Service to manage "minimized" windows in Niri.
 * Since Niri doesn't have native minimize, we move windows to a hidden workspace (index 99).
 */
Singleton {
    id: root

    // Workspace index used for minimized windows (high number to stay out of the way)
    readonly property int minimizedWorkspaceIndex: 99
    
    // Map of minimized windows: windowId -> { appId, title, originalWorkspace }
    property var minimizedWindows: ({})
    
    // List of minimized window IDs for easy iteration
    property list<int> minimizedIds: []
    
    // Check if a window is minimized
    function isMinimized(windowId) {
        return minimizedIds.includes(windowId);
    }
    
    // Get minimized windows for a specific app
    function getMinimizedForApp(appId) {
        const pattern = appId.toLowerCase();
        return minimizedIds.filter(id => {
            const info = minimizedWindows[id];
            return info && info.appId.toLowerCase().includes(pattern);
        });
    }
    
    // Count minimized windows for an app
    function countMinimizedForApp(appId) {
        return getMinimizedForApp(appId).length;
    }
    
    // Minimize the focused window or a specific window
    function minimize(windowId = null) {
        if (!CompositorService.isNiri) return;
        
        // Get window info
        let targetWindow;
        if (windowId) {
            targetWindow = NiriService.windows?.find(w => w.id === windowId);
        } else {
            targetWindow = NiriService.activeWindow;
            windowId = targetWindow?.id;
        }
        
        if (!targetWindow || !windowId) return;
        
        // Don't minimize the main quickshell shell (but allow settings window)
        // Skip this check for now - allow all windows to be minimized
        
        // Already minimized?
        if (isMinimized(windowId)) return;
        
        // Store window info
        const info = {
            appId: targetWindow.app_id || "",
            title: targetWindow.title || "",
            originalWorkspace: NiriService.workspaces?.[targetWindow.workspace_id]?.idx
                ?? NiriService.focusedWorkspaceIndex,
            originalOutput: NiriService.workspaces?.[targetWindow.workspace_id]?.output ?? ""
        };
        
        minimizedWindows[windowId] = info;
        minimizedIds = [...minimizedIds, windowId];
        
        // Move to a workspace far to the right (Niri will create it)
        const allWorkspaces = NiriService.allWorkspaces ?? [];
        const maxWsIndex = allWorkspaces.length > 0 
            ? Math.max(...allWorkspaces.map(ws => ws.idx), 1) 
            : 1;
        const targetWs = maxWsIndex + 10;
        
        moveToWorkspaceProc.command = [
            "niri", "msg", "action", "move-window-to-workspace",
            "--window-id", windowId.toString(),
            "--focus", "false",
            targetWs.toString()
        ];
        moveToWorkspaceProc.running = true;
    }
    
    // Restore a minimized window
    function restore(windowId) {
        if (!CompositorService.isNiri) return;
        if (!isMinimized(windowId)) return;
        
        const info = minimizedWindows[windowId];
        if (!info) return;
        
        // Remove from minimized list
        delete minimizedWindows[windowId];
        minimizedIds = minimizedIds.filter(id => id !== windowId);
        
        // Move back to current workspace and focus
        const targetWorkspace = NiriService.focusedWorkspaceIndex;
        
        restoreProc.command = [
            "niri", "msg", "action", "move-window-to-workspace",
            "--window-id", windowId.toString(),
            targetWorkspace.toString()
        ];
        restoreProc.running = true;
    }

    function restoreOriginal(windowId) {
        if (!CompositorService.isNiri) return;
        if (!isMinimized(windowId)) return;

        const info = minimizedWindows[windowId];
        if (!info) return;

        const targetWorkspace = info.originalWorkspace ?? NiriService.focusedWorkspaceIndex;
        delete minimizedWindows[windowId];
        minimizedIds = minimizedIds.filter(id => id !== windowId);

        restoreProc.command = [
            "niri", "msg", "action", "move-window-to-workspace",
            "--window-id", windowId.toString(),
            targetWorkspace.toString()
        ];
        restoreProc.running = true;
    }
    
    // Restore all minimized windows for an app
    function restoreApp(appId) {
        const windowIds = getMinimizedForApp(appId);
        for (const id of windowIds) {
            restore(id);
        }
    }
    
    // Restore the most recently minimized window for an app
    function restoreLatestForApp(appId) {
        const windowIds = getMinimizedForApp(appId);
        if (windowIds.length > 0) {
            restore(windowIds[windowIds.length - 1]);
        }
    }

    function restoreLatest() {
        if (minimizedIds.length === 0) return;
        restore(minimizedIds[minimizedIds.length - 1]);
    }

    function restoreLatestOriginal() {
        if (minimizedIds.length === 0) return;
        restoreOriginal(minimizedIds[minimizedIds.length - 1]);
    }

    function getMinimizedForOutput(outputName) {
        const output = String(outputName ?? "");
        return minimizedIds.filter(id => {
            const info = minimizedWindows[id];
            return info && (info.originalOutput || "") === output;
        });
    }

    function restoreLatestForOutput(outputName, originalWorkspace = true) {
        const ids = getMinimizedForOutput(outputName);
        if (ids.length === 0) return;
        const windowId = ids[ids.length - 1];
        if (originalWorkspace)
            restoreOriginal(windowId);
        else
            restore(windowId);
    }
    
    Process {
        id: moveToWorkspaceProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[MinimizedWindows] Failed to move window");
            }
        }
    }
    
    Process {
        id: restoreProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // Focus the window after moving
                Qt.callLater(() => {
                    const windowId = parseInt(restoreProc.command[5]);
                    NiriService.focusWindow(windowId);
                });
            }
        }
    }
    
    // IPC handler for external control
    IpcHandler {
        target: "minimize"
        
        function minimize(): void {
            root.minimize();
        }

        function minimizeId(windowId: int): void {
            root.minimize(windowId);
        }
        
        function restore(windowId: int): void {
            root.restore(windowId);
        }

        function restoreOriginal(windowId: int): void {
            root.restoreOriginal(windowId);
        }
    }
}
