pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

/**
 * GameMode service - detects fullscreen windows and disables effects for performance.
 * 
 * Two activation modes:
 * - Manual: user toggle via toggle()/activate()/deactivate(). Persists to file.
 * - Auto-detect: activates when focused window is fullscreen, deactivates
 *   immediately when leaving fullscreen. Applies the same performance
 *   optimizations as manual mode (no panel/background hiding).
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // Public API
    // Visible fullscreen state is already maintained reactively by NiriService.
    // Keep one automatic source of truth here; the old debounced _autoActive
    // cache could remain true after Niri had already reported fullscreen exit.
    readonly property bool _reactiveAutoActive: autoDetect && hasVisibleFullscreenWindow
    readonly property bool active: _manualActive || _reactiveAutoActive
    readonly property bool autoDetect: Config.options?.gameMode?.autoDetect ?? true
    property bool manuallyActivated: _manualActive
    readonly property bool autoActivated: !_manualActive && _reactiveAutoActive

    // Surface mapping caused native crash loops; GameMode only suppresses work.
    
    // True if ANY window in ANY workspace is fullscreen (for toast suppression)
    readonly property bool hasAnyFullscreenWindow: checkAnyFullscreenWindow()

    // True only when a fullscreen window actually owns an active viewport.
    // `window.is_focused` is global and therefore insufficient on multi-output
    // sessions: a fullscreen tile can remain the active tile on an unfocused
    // monitor. NiriService tracks `active_window_id` per workspace, which is the
    // correct per-output owner signal.
    readonly property bool hasVisibleFullscreenWindow: {
        if (!CompositorService.isNiri) return hasAnyFullscreenWindow
        return hasFullscreenOnOutput("")
    }
    
    // Suppress niri reload toast briefly after GameMode changes
    property bool suppressNiriToast: false

    // Internal state
    property bool _manualActive: false
    property bool _initialized: false

    // Config-driven behavior (reactive bindings - re-evaluated when Config changes)
    readonly property bool disableAnimations: Config.options?.gameMode?.disableAnimations ?? true
    readonly property bool disableEffects: Config.options?.gameMode?.disableEffects ?? true
    readonly property bool disableVisualizers: Config.options?.gameMode?.disableVisualizers ?? true
    readonly property bool disableReloadToasts: Config.options?.gameMode?.disableReloadToasts ?? true
    readonly property bool minimalMode: Config.options?.gameMode?.minimalMode ?? true
    readonly property bool visualizersSuppressed: active && disableVisualizers
    readonly property bool controlNiriAnimations: Config.options?.gameMode?.disableNiriAnimations ?? true
    
    // React to controlNiriAnimations changes while active
    onControlNiriAnimationsChanged: {
        if (active && CompositorService.isNiri) {
            // When setting enabled AND gamemode active -> disable niri animations
            // When setting disabled -> re-enable niri animations
            setNiriAnimations(!active || !controlNiriAnimations)
        }
    }

    // External process control (optional)
    readonly property bool disableDiscoverOverlay: Config.options?.gameMode?.disableDiscoverOverlay ?? true
    readonly property bool suppressNotifications: Config.options?.gameMode?.suppressNotifications ?? true
    readonly property string _discoverOverlayServiceName: "discover-overlay.service"

    // State file path
    readonly property string _stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/user/gamemode_active"

    // IPC handler for external control
    IpcHandler {
        target: "gamemode"
        function toggle(): void { root.toggle() }
        function activate(): void { root.activate() }
        function deactivate(): void { root.deactivate() }
        function status(): string {
            const state = root.active ? "active" : "inactive";
            const detail = root._manualActive ? "manual" : root.autoActivated ? "auto" : "off";
            return state + " (" + detail + ")";
        }
    }

    function toggle() {
        _manualActive = !_manualActive
        _saveState()
        root._log("[GameMode] Toggled manually:", _manualActive)
    }

    function activate() {
        _manualActive = true
        _saveState()
        root._log("[GameMode] Activated manually")
    }

    function deactivate() {
        _manualActive = false
        _saveState()
        root._log("[GameMode] Deactivated manually")
    }

    function _saveState() {
        saveProcess.running = true
    }

    function _loadState() {
        stateReader.reload()
    }

    // Check if a window is fullscreen. Current Niri snapshots do not expose a
    // dependable is_fullscreen field, so derive it from Niri's own window layout.
    // Do not use foreign-toplevel fullscreen here: those handles can outlive a
    // Niri fullscreen transition and report stale state after the window exited.
    function isWindowFullscreen(window) {
        if (!window) return false
        if (!CompositorService.isNiri) return false

        if (window.is_fullscreen === true) return true

        // Fallback: compare window size to output logical size
        const winSize = window.layout?.window_size
        if (!winSize || winSize.length < 2) return false

        const ws = NiriService.workspaces[window.workspace_id]
        let output = ws ? NiriService.outputs[ws.output] : null
        // Niri can deliver WindowLayoutsChanged before the matching workspace
        // snapshot reaches the service. On a single-output session the target
        // is unambiguous, so do not miss that fullscreen transition.
        if (!output) {
            const availableOutputs = Object.values(NiriService.outputs ?? {})
            if (availableOutputs.length === 1) output = availableOutputs[0]
        }
        if (!output?.logical) return false

        const tolerance = 2
        return Math.abs(winSize[0] - output.logical.width) <= tolerance
            && Math.abs(winSize[1] - output.logical.height) <= tolerance
    }
    
    // True when a fullscreen window covers the given output (empty name = any
    // output). Callers gating a per-monitor surface MUST pass their output
    // name: a game on one monitor must not unmap the wallpaper on the other.
    // Goes through isWindowFullscreen because reading `window.is_fullscreen`
    // directly never fires on current niri (see above) — it silently reports
    // "no fullscreen" forever.
    function hasFullscreenOnOutput(outputName: string): bool {
        if (!CompositorService.isNiri) return false
        const windows = NiriService.liveWindows
        if (!Array.isArray(windows)) return false

        for (let i = 0; i < windows.length; i++) {
            const w = windows[i]
            const ws = NiriService.workspaces?.[w.workspace_id]
            if (!(ws?.is_active ?? false)) continue
            if (outputName.length > 0 && ws.output !== outputName) continue
            // Prefer the workspace-local active tile. Fall back to global focus
            // only while NiriService has not received an active-window event
            // for this workspace yet.
            const activeWindowId = ws.active_window_id
            if (activeWindowId !== undefined && activeWindowId !== null) {
                if (activeWindowId !== w.id) continue
            } else if (!w.is_focused) {
                continue
            }
            if (isWindowFullscreen(w)) return true
        }
        return false
    }

    // Check if ANY window across all workspaces is fullscreen
    function checkAnyFullscreenWindow(): bool {
        if (!CompositorService.isNiri) return false
        const windows = NiriService.liveWindows
        if (!windows || !Array.isArray(windows)) return false
        
        for (let i = 0; i < windows.length; i++) {
            if (isWindowFullscreen(windows[i])) return true
        }
        return false
    }

    // State persistence - read
    FileView {
        id: stateReader
        path: root._stateFile

        onLoaded: {
            const content = stateReader.text()
            root._manualActive = (content.trim() === "1")
            root._initialized = true
            root._log("[GameMode] Initialized, manual:", root._manualActive)
        }

        onLoadFailed: (error) => {
            // File doesn't exist yet, that's fine
            root._manualActive = false
            root._initialized = true
            root._log("[GameMode] Initialized (no saved state)")
        }
    }

    // State persistence - write via process
    Process {
        id: saveProcess
        command: [
            "/usr/bin/bash",
            "-c",
            "mkdir -p ~/.local/state/quickshell/user\n" +
            "echo " + (root._manualActive ? "1" : "0") + " > " + root._stateFile
        ]
        onExited: root._log("[GameMode] State saved:", root._manualActive)
    }

    // Initial setup
    Component.onCompleted: {
        root._log("[GameMode] Service starting...")
        Quickshell.execDetached(["/usr/bin/mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell/user"])
        initTimer.restart()
    }

    Timer {
        id: initTimer
        interval: 200
        onTriggered: {
            root._loadState()
            if (CompositorService.isNiri)
                startupNiriSyncTimer.restart()
        }
    }

    Timer {
        id: startupNiriSyncTimer
        interval: 900
        repeat: false
        onTriggered: {
            if (!CompositorService.isNiri || !root.controlNiriAnimations)
                return
            const shouldEnable = !root.active
            root._lastNiriAnimState = shouldEnable
            root.setNiriAnimations(shouldEnable)
        }
    }

    // Niri animations control — targets the modular animations file
    readonly property string niriAnimationsPath: {
        const configDir = (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        const modularPath = configDir + "/niri/config.d/60-animations.kdl"
        return modularPath
    }
    readonly property string niriConfigPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri/config.kdl"

    function setNiriAnimations(enabled) {
        if (!controlNiriAnimations) return

        // Try modular file first, fall back to root config.kdl
        const targetFile = niriAnimationsPath
        const fallbackFile = niriConfigPath
        const sedExpr = enabled
            ? "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)off$/\\1\\/\\/off/'"
            : "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)\\/\\/[ \\t]*off$/\\1off/'"

        niriAnimProcess.command = [
            "/usr/bin/bash",
            "-c",
            "if [ -f \"" + targetFile + "\" ]; then " + sedExpr + " \"" + targetFile + "\"; " +
            "else " + sedExpr + " \"" + fallbackFile + "\"; fi\n" +
            "/usr/bin/niri msg action reload-config"
        ]
        niriAnimProcess.running = true
    }

    Process {
        id: niriAnimProcess
        onExited: (code, status) => {
            if (code === 0) {
                root._log("[GameMode] Niri animations updated")
            }
            suppressClearTimer.restart()
        }
    }

    Timer {
        id: suppressClearTimer
        interval: 2000
        onTriggered: {
            root._log("[GameMode] Clearing suppressNiriToast")
            root.suppressNiriToast = false
        }
    }

    // Track last niri animation state to avoid redundant updates
    property bool _lastNiriAnimState: true

    // Debounce timer for niri animation changes
    Timer {
        id: niriAnimDebounce
        interval: 500
        onTriggered: {
            const shouldEnable = !root.active
            if (shouldEnable !== root._lastNiriAnimState) {
                root._lastNiriAnimState = shouldEnable
                root.setNiriAnimations(shouldEnable)
            }
        }
    }

    onActiveChanged: {
        root._log("[GameMode] Active:", active, "(manual:", _manualActive, "auto:", _reactiveAutoActive, ")")
        if (CompositorService.isNiri && controlNiriAnimations) {
            root.suppressNiriToast = true
            niriAnimDebounce.restart()
        }

        // External processes control
        if (root.disableDiscoverOverlay) {
            discoverOverlayDebounce.restart()
        }
    }

    // Track last applied state for discover-overlay control
    property bool _lastDiscoverOverlayGameState: false

    Timer {
        id: discoverOverlayDebounce
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.disableDiscoverOverlay)
                return

            const shouldStop = root.active
            if (shouldStop === root._lastDiscoverOverlayGameState)
                return
            root._lastDiscoverOverlayGameState = shouldStop

            if (shouldStop) {
                root._log("[GameMode] Stopping", root._discoverOverlayServiceName)
                discoverOverlayStopProc.running = true
            } else {
                root._log("[GameMode] Starting", root._discoverOverlayServiceName)
                discoverOverlayStartProc.running = true
            }
        }
    }

    Process {
        id: discoverOverlayStopProc
        command: [
            "/usr/bin/bash",
            "-c",
            "systemctl --user stop " + root._discoverOverlayServiceName + " 2>/dev/null; " +
            "pkill -x discover-overlay 2>/dev/null; true"
        ]
        onExited: (code, status) => {
            root._log("[GameMode] discover-overlay stop exited:", code)
        }
    }

    Process {
        id: discoverOverlayStartProc
        command: [
            "/usr/bin/systemctl",
            "--user",
            "start",
            root._discoverOverlayServiceName
        ]
        onExited: (code, status) => {
            root._log("[GameMode] systemctl start exited:", code)
        }
    }
}
