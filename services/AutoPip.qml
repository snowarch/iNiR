pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

Singleton {
    id: root

    // Monitor changes to Niri windows and active window
    readonly property var activeWindow: NiriService.activeWindow
    readonly property var windows: NiriService.windows

    // Check if Firefox/Zen is playing media via MprisController
    readonly property bool isFirefoxPlaying: {
        const players = MprisController.players || [];
        for (let i = 0; i < players.length; i++) {
            const player = players[i];
            if (!player) continue;
            const identity = (player.identity ?? "").toLowerCase();
            if ((identity.includes("firefox") || identity.includes("zen")) && player.isPlaying) {
                return true;
            }
        }
        return false;
    }

    // Keep track of the active window ID and state
    property string lastActiveWindowId: ""
    property bool isPipActive: false

    onActiveWindowChanged: {
        if (!activeWindow) return;

        // If the newly focused window is Firefox, check if we need to dock it back
        const appName = (activeWindow.app_id ?? "").toLowerCase();
        const isFirefox = appName.includes("firefox") || appName.includes("zen");

        if (isFirefox) {
            if (isPipActive) {
                // Dock back: send keypress to dock video back
                triggerPipToggle();
                isPipActive = false;
            }
            lastActiveWindowId = String(activeWindow.id);
            return;
        }

        // If focus shifted away from Firefox to another window:
        // We check if Firefox is still playing media, and if it has gone off-screen.
        if (lastActiveWindowId !== "") {
            const firefoxWin = windows.find(w => String(w.id) === lastActiveWindowId);
            if (firefoxWin) {
                // If it is floating, it's not off-screen on the ribbon
                if (firefoxWin.is_floating) return;

                if (isFirefoxPlaying && isWindowOffScreen(firefoxWin)) {
                    // Trigger PiP: send keypress
                    triggerPipToggle();
                    isPipActive = true;
                }
            }
        }

        lastActiveWindowId = "";
    }

    // Function to calculate if a tiled window is completely off-screen on the ribbon
    function isWindowOffScreen(win): bool {
        // Find the active workspace
        const wsId = win.workspace_id;
        const ws = NiriService.workspaces[wsId];
        if (!ws) return true;

        // 1. Get the screen geometry dynamically
        const outputName = ws.output || NiriService.currentOutput;
        if (!outputName || !NiriService.outputs[outputName]) return true;
        const output = NiriService.outputs[outputName];
        const screenWidth = output.logical?.width || 1920;

        // 2. Filter and sort all tiled windows on this workspace
        const wsWindows = windows.filter(w => w.workspace_id === wsId && !w.is_floating);
        wsWindows.sort((a, b) => {
            const colA = a.layout?.pos_in_scrolling_layout?.[0] ?? 0;
            const colB = b.layout?.pos_in_scrolling_layout?.[0] ?? 0;
            return colA - colB;
        });

        if (wsWindows.length === 0) return true;

        // 3. Compute absolute positions of all columns on the ribbon
        const gaps = 10; // Niri gaps size config
        const colWidths = {};
        const colAbsX = {};
        
        for (let i = 0; i < wsWindows.length; i++) {
            const w = wsWindows[i];
            const colIdx = w.layout?.pos_in_scrolling_layout?.[0] ?? 0;
            if (colWidths[colIdx] === undefined) {
                colWidths[colIdx] = w.layout?.tile_size?.[0] ?? 945;
            }
        }

        const uniqueCols = Object.keys(colWidths).map(Number).sort((a, b) => a - b);
        let currentX = 0;
        for (let i = 0; i < uniqueCols.length; i++) {
            const col = uniqueCols[i];
            colAbsX[col] = currentX;
            currentX += colWidths[col] + gaps;
        }

        // 4. Find the focused window on the active workspace
        const focusedWin = wsWindows.find(w => w.is_focused) || activeWindow;
        if (!focusedWin) return true;

        const focusedCol = focusedWin.layout?.pos_in_scrolling_layout?.[0] ?? 0;
        const focusedWidth = colWidths[focusedCol] ?? 945;
        const focusedAbsX = colAbsX[focusedCol] ?? 0;

        // Check window visibility in the two potential alignment viewports
        const winCol = win.layout?.pos_in_scrolling_layout?.[0] ?? 0;
        const winWidth = colWidths[winCol] ?? 945;
        const winAbsX = colAbsX[winCol] ?? 0;

        // Case A: left-aligned focused column
        const vX_A = focusedAbsX;
        const relX_A = winAbsX - vX_A;
        const visible_A = (relX_A + winWidth > 0) && (relX_A < screenWidth);

        // Case B: right-aligned focused column
        const vX_B = focusedAbsX + focusedWidth - screenWidth;
        const relX_B = winAbsX - vX_B;
        const visible_B = (relX_B + winWidth > 0) && (relX_B < screenWidth);

        return !visible_A && !visible_B;
    }

    function triggerPipToggle() {
        Quickshell.execDetached(["wtype", "-M", "ctrl", "-M", "shift", "-k", "bracketright"]);
    }
}
