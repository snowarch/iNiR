pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    function updateWindowList() {
        if (!CompositorService.isHyprland)
            return;
        getClients.running = true;
    }

    function updateLayers() {
        if (!CompositorService.isHyprland)
            return;
        getLayers.running = true;
    }

    function updateMonitors() {
        if (!CompositorService.isHyprland)
            return;
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        if (!CompositorService.isHyprland)
            return;
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        if (!CompositorService.isHyprland)
            return;
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        if (!CompositorService.isHyprland)
            return;
        updateAll();
    }

    Connections {
        target: Hyprland
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            // console.log("Hyprland raw event:", event.name);
            updateAll()
        }
    }

    Process {
        id: getClients
        command: ["/usr/bin/hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(clientsCollector.text)
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse clients JSON:", e);
                    root.windowList = [];
                }
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    Process {
        id: getMonitors
        command: ["/usr/bin/hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(monitorsCollector.text);
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse monitors JSON:", e);
                    root.monitors = [];
                }
            }
        }
    }

    Process {
        id: getLayers
        command: ["/usr/bin/hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                try {
                    root.layers = JSON.parse(layersCollector.text);
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse layers JSON:", e);
                    root.layers = {};
                }
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["/usr/bin/hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(workspacesCollector.text);
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse workspaces JSON:", e);
                    root.workspaces = [];
                }
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["/usr/bin/hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                try {
                    root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse active workspace JSON:", e);
                    root.activeWorkspace = null;
                }
            }
        }
    }
}
