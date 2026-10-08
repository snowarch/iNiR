pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * Service to manage "minimized" windows in Niri.
 * Since Niri doesn't have native minimize, stashed windows share an otherwise
 * empty workspace on their original output.
 */
Singleton {
    id: root

    // Map of minimized windows: windowId -> { appId, title, originalWorkspace }
    property var minimizedWindows: ({})
    
    // List of minimized window IDs for easy iteration
    property list<int> minimizedIds: []
    property bool recoveredPersistentState: false
    readonly property bool actionReady: CompositorService.isNiri && Persistent.ready && NiriService.actionReady

    function persistState() {
        if (!Persistent.ready) return;
        Persistent.states.orbit.stashEntries = minimizedIds.map(id => {
            const info = minimizedWindows[id];
            return JSON.stringify({
                windowId: id,
                appId: info?.appId ?? "",
                title: info?.title ?? "",
                originalWorkspace: info?.originalWorkspace ?? 1,
                originalWorkspaceId: info?.originalWorkspaceId ?? -1,
                originalOutput: info?.originalOutput ?? ""
            });
        });
    }

    function recoverPersistentState() {
        if (recoveredPersistentState || !Persistent.ready || !CompositorService.isNiri) return;
        const entries = Persistent.states.orbit.stashEntries ?? [];
        if (entries.length > 0 && (NiriService.windows ?? []).length === 0) return;

        const liveIds = new Set((NiriService.windows ?? []).map(window => window.id));
        const restored = {};
        const ids = [];
        for (const raw of entries) {
            let entry;
            try {
                entry = JSON.parse(raw);
            } catch (error) {
                continue;
            }
            const id = Number(entry?.windowId ?? -1);
            if (id < 0 || !liveIds.has(id) || ids.includes(id)) continue;
            restored[id] = {
                appId: entry.appId ?? "",
                title: entry.title ?? "",
                originalWorkspace: Number(entry.originalWorkspace ?? 1),
                originalWorkspaceId: Number(entry.originalWorkspaceId ?? -1),
                originalOutput: entry.originalOutput ?? ""
            };
            ids.push(id);
        }
        minimizedWindows = restored;
        minimizedIds = ids;
        recoveredPersistentState = true;
        persistState();
    }

    function pruneMissingWindows() {
        if (!recoveredPersistentState) {
            recoverPersistentState();
            return;
        }
        const liveIds = new Set((NiriService.windows ?? []).map(window => window.id));
        const nextIds = minimizedIds.filter(id => liveIds.has(id));
        if (nextIds.length === minimizedIds.length) return;
        const next = {};
        for (const id of nextIds) next[id] = minimizedWindows[id];
        minimizedWindows = next;
        minimizedIds = nextIds;
        persistState();
    }
    
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
    
    // A workspace that holds only stashed windows is the stash, not somewhere a person works.
    function isStashWorkspace(workspaceId) {
        const held = (NiriService.windows ?? []).filter(window => window.workspace_id === workspaceId);
        return held.length > 0 && held.every(window => minimizedIds.includes(window.id));
    }

    // Count minimized windows for an app
    function countMinimizedForApp(appId) {
        return getMinimizedForApp(appId).length;
    }

    function stashWorkspaceForOutput(outputName) {
        const output = String(outputName ?? "");
        const liveWindows = NiriService.windows ?? [];
        for (const id of getMinimizedForOutput(output)) {
            const window = liveWindows.find(w => w.id === id);
            const workspace = window
                ? (NiriService.workspaces?.[window.workspace_id]
                    ?? (NiriService.allWorkspaces ?? []).find(ws => ws.id === window.workspace_id))
                : null;
            if (workspace)
                return workspace;
        }

        const occupied = new Set(liveWindows.map(window => window.workspace_id));
        const workspaces = (NiriService.allWorkspaces ?? [])
            .filter(workspace => workspace.output === output && !occupied.has(workspace.id))
            .sort((a, b) => b.idx - a.idx);
        return workspaces[0] ?? null;
    }

    function restoreWorkspace(info, originalWorkspace) {
        const allWorkspaces = NiriService.allWorkspaces ?? [];
        if (!originalWorkspace) {
            return allWorkspaces.find(workspace => String(workspace.id) === String(NiriService.focusedWorkspaceId)) ?? null;
        }

        const exact = allWorkspaces.find(workspace => workspace.id === info.originalWorkspaceId);
        if (exact)
            return exact;

        const outputWorkspaces = allWorkspaces
            .filter(workspace => workspace.output === (info.originalOutput ?? ""))
            .sort((a, b) => a.idx - b.idx);
        if (outputWorkspaces.length === 0)
            return null;
        return outputWorkspaces.find(workspace => workspace.idx === info.originalWorkspace)
            ?? outputWorkspaces.reduce((best, workspace) =>
                Math.abs(workspace.idx - info.originalWorkspace) < Math.abs(best.idx - info.originalWorkspace)
                    ? workspace : best, outputWorkspaces[0]);
    }
    
    // Minimize the focused window or a specific window
    function minimize(windowId = null) {
        if (!root.actionReady) return false;
        recoverPersistentState();
        
        // Get window info
        let targetWindow;
        if (windowId) {
            targetWindow = NiriService.windows?.find(w => w.id === windowId);
        } else {
            targetWindow = NiriService.activeWindow;
            windowId = targetWindow?.id;
        }
        
        if (!targetWindow || !windowId) return false;
        
        // Don't minimize the main quickshell shell (but allow settings window)
        // Skip this check for now - allow all windows to be minimized
        
        // Already minimized?
        if (isMinimized(windowId)) return false;
        
        const sourceWorkspace = NiriService.workspaces?.[targetWindow.workspace_id]
            ?? (NiriService.allWorkspaces ?? []).find(ws => ws.id === targetWindow.workspace_id);
        if (!sourceWorkspace) return false;

        const stashWorkspace = stashWorkspaceForOutput(sourceWorkspace.output);
        if (!stashWorkspace || stashWorkspace.id === sourceWorkspace.id) return false;

        const info = {
            appId: targetWindow.app_id || "",
            title: targetWindow.title || "",
            originalWorkspace: sourceWorkspace.idx,
            originalWorkspaceId: sourceWorkspace.id,
            originalOutput: sourceWorkspace.output || ""
        };

        if (!NiriService.moveWindowToWorkspaceById(windowId, stashWorkspace.id, false))
            return false;

        minimizedWindows[windowId] = info;
        minimizedIds = [...minimizedIds, windowId];
        persistState();
        return true;
    }
    
    // Restore a minimized window
    function restore(windowId) {
        if (!root.actionReady) return;
        if (!isMinimized(windowId)) return;
        
        const info = minimizedWindows[windowId];
        if (!info) return;
        
        const targetWorkspace = restoreWorkspace(info, false);
        if (!targetWorkspace || !NiriService.moveWindowToWorkspaceById(windowId, targetWorkspace.id, true))
            return;

        delete minimizedWindows[windowId];
        minimizedIds = minimizedIds.filter(id => id !== windowId);
        persistState();
    }

    function restoreOriginal(windowId) {
        if (!root.actionReady) return;
        if (!isMinimized(windowId)) return;

        const info = minimizedWindows[windowId];
        if (!info) return;

        const targetWorkspace = restoreWorkspace(info, true);
        if (!targetWorkspace || !NiriService.moveWindowToWorkspaceById(windowId, targetWorkspace.id, true))
            return;

        delete minimizedWindows[windowId];
        minimizedIds = minimizedIds.filter(id => id !== windowId);
        persistState();
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

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready) root.recoverPersistentState();
        }
    }

    Connections {
        target: NiriService
        function onWindowsChanged() {
            root.pruneMissingWindows();
        }
    }

    Component.onCompleted: recoverPersistentState()
    
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
