pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * GameMode service - detects fullscreen windows and disables effects for performance.
 * 
 * Activates automatically when:
 * - autoDetect is enabled AND
 * - The focused window covers the full output (fullscreen)
 * 
 * Can also be toggled manually via toggle()/activate()/deactivate()
 * Manual state persists to file.
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // Public API
    property bool active: _manualActive || _autoActive
    readonly property bool autoDetect: Config.options?.gameMode?.autoDetect ?? true
    property bool manuallyActivated: _manualActive
    readonly property bool autoActivated: _autoActive

    // True when panels should hide (slide-out + mask null + exclusiveZone 0).
    // Only when auto-detected AND the focused window is still fullscreen.
    // When user opens Niri overview (Super+TAB), focused window changes → panels return.
    // Manual GameMode never hides panels — it only applies performance optimizations.
    readonly property bool shouldHidePanels: _autoActive && _focusedIsFullscreen
    
    // When autoDetect is disabled, immediately clear auto state
    onAutoDetectChanged: {
        if (!autoDetect) {
            _autoActive = false
            _fullscreenCount = 0
            root._log("[GameMode] autoDetect disabled, clearing auto state")
        } else {
            // Re-check when enabled
            checkFullscreen()
        }
    }
    
    // True if ANY window in ANY workspace is fullscreen (for toast suppression)
    property bool hasAnyFullscreenWindow: false
    
    // Suppress niri reload toast briefly after GameMode changes
    property bool suppressNiriToast: false

    // Internal state
    property bool _manualActive: false
    property bool _autoActive: false
    property bool _initialized: false
    property bool _focusedIsFullscreen: false

    // Config-driven behavior (reactive bindings - re-evaluated when Config changes)
    readonly property bool disableAnimations: Config.options?.gameMode?.disableAnimations ?? true
    readonly property bool disableEffects: Config.options?.gameMode?.disableEffects ?? true
    readonly property bool disableReloadToasts: Config.options?.gameMode?.disableReloadToasts ?? true
    readonly property bool minimalMode: Config.options?.gameMode?.minimalMode ?? true
    readonly property int checkInterval: Config.options?.gameMode?.checkInterval ?? 5000
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
    readonly property string _discoverOverlayServiceName: "discover-overlay.service"

    // Hysteresis: require multiple consecutive checks to change auto state
    property int _fullscreenCount: 0
    readonly property int _hysteresisThreshold: 2

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
            const detail = root._manualActive ? "manual" : root._autoActive ? "auto" : "off";
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

    // Check if a window is fullscreen using niri's native is_fullscreen flag.
    // The old size-based heuristic (60px margin) caused false positives on maximized
    // windows with small gaps, triggering GameMode and all its side effects unexpectedly.
    function isWindowFullscreen(window) {
        if (!window) return false
        if (!CompositorService.isNiri) return false
        return window.is_fullscreen === true
    }
    
    // Check if ANY window across all workspaces is fullscreen
    function checkAnyFullscreenWindow(): bool {
        if (!CompositorService.isNiri) return false
        const windows = NiriService.windows
        if (!windows || !Array.isArray(windows)) return false
        
        for (let i = 0; i < windows.length; i++) {
            if (isWindowFullscreen(windows[i])) return true
        }
        return false
    }

    // Debounce timer for fullscreen checks
    Timer {
        id: checkDebounce
        interval: 300  // Faster response
        onTriggered: root._doCheckFullscreen()
    }

    // Auto-detection: check focused window (debounced)
    function checkFullscreen() {
        checkDebounce.restart()
    }

    function _doCheckFullscreen() {
        if (!CompositorService.isNiri) {
            _autoActive = false
            _fullscreenCount = 0
            _focusedIsFullscreen = false
            hasAnyFullscreenWindow = false
            return
        }
        
        // Always update hasAnyFullscreenWindow (for toast suppression)
        hasAnyFullscreenWindow = checkAnyFullscreenWindow()

        const focusedWindow = NiriService.activeWindow
        const isFullscreen = isWindowFullscreen(focusedWindow)

        // Always track focused window state (drives shouldHidePanels reactively)
        _focusedIsFullscreen = isFullscreen

        if (!autoDetect) {
            _autoActive = false
            _fullscreenCount = 0
            return
        }
        
        // Hysteresis: require consistent state before changing
        if (isFullscreen) {
            _fullscreenCount = Math.min(_fullscreenCount + 1, _hysteresisThreshold + 1)
        } else {
            _fullscreenCount = Math.max(_fullscreenCount - 1, 0)
        }
        
        const wasActive = _autoActive
        const shouldBeActive = _fullscreenCount >= _hysteresisThreshold
        
        if (shouldBeActive !== wasActive) {
            _autoActive = shouldBeActive
            root._log("[GameMode] Auto-detect:", _autoActive ? "fullscreen detected" : "no fullscreen")
        }
    }

    // State persistence - read
    FileView {
        id: stateReader
        path: Qt.resolvedUrl(root._stateFile)

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

    // React to window changes
    Connections {
        target: NiriService
        enabled: CompositorService.isNiri && root._initialized

        function onActiveWindowChanged() {
            root.checkFullscreen()
        }

        function onWindowsChanged() {
            // Only update hasAnyFullscreenWindow if not already checking
            if (!checkDebounce.running) {
                root.hasAnyFullscreenWindow = root.checkAnyFullscreenWindow()
            }
        }
    }

    // Periodic check as fallback - uses config interval
    Timer {
        id: fallbackTimer
        interval: root.checkInterval
        running: root.autoDetect && CompositorService.isNiri && root._initialized
        repeat: true
        onTriggered: {
            if (!checkDebounce.running) {
                root.checkFullscreen()
            }
        }
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
            if (CompositorService.isNiri) {
                root.checkFullscreen()
                startupNiriSyncTimer.restart()
            }
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
            : "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)\\/\\/off$/\\1off/'"

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

    // React to active changes for Niri animations
    onActiveChanged: {
        root._log("[GameMode] Active:", active, "(manual:", _manualActive, "auto:", _autoActive, ")")
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
