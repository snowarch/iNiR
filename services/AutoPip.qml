pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

Singleton {
    id: root

    // Monitor changes to Niri windows and active window
    readonly property var activeWindow: {
        const wins = NiriService.windows || [];
        for (let i = 0; i < wins.length; i++) {
            if (wins[i] && wins[i].is_focused) return wins[i];
        }
        return null;
    }
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

    // Grace period property to smooth out asynchronous D-Bus/MPRIS status lags
    property bool wasFirefoxPlayingRecently: false

    Timer {
        id: playingGraceTimer
        interval: 1000
        repeat: false
        onTriggered: wasFirefoxPlayingRecently = false
    }

    onIsFirefoxPlayingChanged: {
        if (isFirefoxPlaying) {
            playingGraceTimer.stop();
            wasFirefoxPlayingRecently = true;
        } else {
            playingGraceTimer.restart();
        }
    }

    // Keep track of the active window ID
    property string lastActiveWindowId: ""

    // Computed property that dynamically checks if a Firefox PiP window actually exists in Niri
    readonly property bool isPipActive: {
        const wins = windows || [];
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (!w) continue;
            const app = (w.app_id ?? "").toLowerCase();
            const title = (w.title ?? "").toLowerCase();
            if ((app.includes("firefox") || app.includes("zen")) &&
                (title === "picture-in-picture" || title === "incrustation" || title === "bild-in-bild" || title.includes("picture-in-picture"))) {
                return true;
            }
        }
        return false;
    }

    // Timer to debounce PiP triggers and prevent keypress injection spam during rapid scrolling
    Timer {
        id: pipTriggerDebounce
        interval: 150
        repeat: false
        property string targetWinId: ""
        onTriggered: {
            if (targetWinId === "") return;
            const firefoxWin = windows.find(w => String(w.id) === targetWinId);
            if (firefoxWin) {
                if (firefoxWin.is_floating) return;
                const offScreen = isWindowOffScreen(firefoxWin);
                console.log("[AutoPip Debounced] Check. playing:", wasFirefoxPlayingRecently, "offScreen:", offScreen);
                if (wasFirefoxPlayingRecently && offScreen) {
                    console.log("[AutoPip Debounced] Firefox is off-screen. Triggering PiP...");
                    triggerPipToggle();
                }
            }
            targetWinId = "";
        }
    }

    Timer {
        id: debugTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            console.log("[AutoPip Poll] activeWindow:", activeWindow ? activeWindow.title : "null",
                        "app_id:", activeWindow ? activeWindow.app_id : "null",
                        "windows count:", windows ? windows.length : 0);
            if (windows) {
                for (let i = 0; i < windows.length; i++) {
                    const w = windows[i];
                    console.log("  -> Window id:", w.id, "app_id:", w.app_id, "is_focused:", w.is_focused, "title:", w.title);
                }
            }
        }
    }

    onActiveWindowChanged: {
        console.log("[AutoPip] Active window changed:", activeWindow ? activeWindow.title : "null", "app_id:", activeWindow ? activeWindow.app_id : "null");
        
        // Cancel any pending trigger when focus changes (prevents keypress injection while passing by columns)
        pipTriggerDebounce.stop();
        pipTriggerDebounce.targetWinId = "";

        if (!activeWindow) return;

        // If the newly focused window is Firefox, check if we need to dock it back
        const appName = (activeWindow.app_id ?? "").toLowerCase();
        const isFirefox = appName.includes("firefox") || appName.includes("zen");
        console.log("[AutoPip] isFirefox:", isFirefox, "lastActiveWindowId:", lastActiveWindowId, "isPipActive:", isPipActive, "wasFirefoxPlayingRecently:", wasFirefoxPlayingRecently);

        if (isFirefox) {
            // Ignore if the newly focused window is the PiP window itself
            const title = (activeWindow.title ?? "").toLowerCase();
            if (title === "picture-in-picture" || title === "incrustation" || title === "bild-in-bild" || title.includes("picture-in-picture")) {
                console.log("[AutoPip] Focused window is the PiP window itself. Skip docking.");
                return;
            }

            if (isPipActive) {
                // Dock back: send keypress to dock video back
                console.log("[AutoPip] Firefox focused and PiP is active, docking back...");
                triggerPipToggle();
            }
            lastActiveWindowId = String(activeWindow.id);
            return;
        }

        // If focus shifted away from Firefox:
        // Schedule a debounced check to allow focus to settle (prevents collision during fast scroll)
        if (lastActiveWindowId !== "") {
            pipTriggerDebounce.targetWinId = lastActiveWindowId;
            pipTriggerDebounce.start();
        }

        lastActiveWindowId = "";
    }

    function isWindowOffScreen(win): bool {
        // Find the active workspace
        const wsId = win.workspace_id;
        const ws = NiriService.workspaces[wsId];
        if (!ws) {
            console.log("[AutoPip] Workspace not found for window, wsId:", wsId);
            return true;
        }

        // 1. Get the screen geometry dynamically
        const outputName = ws.output || NiriService.currentOutput;
        if (!outputName || !NiriService.outputs[outputName]) {
            console.log("[AutoPip] Output not found for name:", outputName);
            return true;
        }
        const output = NiriService.outputs[outputName];
        const screenWidth = output.logical?.width || 1920;

        // 2. Filter and sort all tiled windows on this workspace
        const wsWindows = windows.filter(w => w.workspace_id === wsId && !w.is_floating);
        wsWindows.sort((a, b) => {
            const colA = a.layout?.pos_in_scrolling_layout?.[0] ?? 0;
            const colB = b.layout?.pos_in_scrolling_layout?.[0] ?? 0;
            return colA - colB;
        });

        if (wsWindows.length === 0) {
            console.log("[AutoPip] No tiled windows found on workspace:", wsId);
            return true;
        }

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
        // Use the newly active window directly to avoid race conditions with the windows list updates.
        const focusedWin = activeWindow;
        if (!focusedWin) {
            console.log("[AutoPip] Focused window not found (activeWindow is null)");
            return true;
        }

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
        // Apply 50px tolerance to ignore margins/gaps at screen edges
        const visible_A = (relX_A + winWidth > 50) && (relX_A < screenWidth - 50);

        // Case B: right-aligned focused column
        const vX_B = focusedAbsX + focusedWidth - screenWidth;
        const relX_B = winAbsX - vX_B;
        const visible_B = (relX_B + winWidth > 50) && (relX_B < screenWidth - 50);

        console.log("[AutoPip] Geometry Details:",
                    "screenWidth:", screenWidth,
                    "focusedCol:", focusedCol, "focusedAbsX:", focusedAbsX, "focusedWidth:", focusedWidth,
                    "winCol:", winCol, "winAbsX:", winAbsX, "winWidth:", winWidth,
                    "relX_A:", relX_A, "visible_A:", visible_A,
                    "relX_B:", relX_B, "visible_B:", visible_B);

        return !visible_A && !visible_B;
    }

    function triggerPipToggle() {
        console.log("[AutoPip] triggerPipToggle called (wtype simulation disabled for stability).");
        // Disabled to prevent sticky modifier keys (Ctrl/Shift) under Wayland Niri transitions
        // Quickshell.execDetached(["wtype", "-M", "ctrl", "-M", "shift", "-k", "bracketright"]);
    }
}
