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
    property bool autoDetect: Config.options?.gameMode?.autoDetect ?? true
    property bool manuallyActivated: _manualActive
    
    // True if ANY window in ANY workspace is fullscreen (for toast suppression)
    property bool hasAnyFullscreenWindow: false
    
    // Suppress niri reload toast briefly after GameMode changes
    property bool suppressNiriToast: false

    // Internal state
    property bool _manualActive: false
    property bool _autoActive: false
    property bool _initialized: false

    // Config-driven behavior
    readonly property bool disableAnimations: Config.options?.gameMode?.disableAnimations ?? true
    readonly property bool disableEffects: Config.options?.gameMode?.disableEffects ?? true
    readonly property int checkInterval: Config.options?.gameMode?.checkInterval ?? 2000

    // Fullscreen detection threshold (allow small margin for bar/gaps)
    readonly property int _marginThreshold: 60
    
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
        function status(): void { 
            root._log("[GameMode] Status - active:", root.active, "manual:", root._manualActive, "auto:", root._autoActive)
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

    // Check if a window is fullscreen by comparing to output size
    function isWindowFullscreen(window) {
        if (!window) return false
        if (!CompositorService.isNiri) return false

        // Get window size from layout
        const layout = window.layout
        if (!layout) return false
        
        const windowSize = layout.window_size
        if (!windowSize || windowSize.length < 2) return false
        
        const windowWidth = windowSize[0]
        const windowHeight = windowSize[1]

        // Get output for this window's workspace
        const workspaceId = window.workspace_id
        const workspace = NiriService.allWorkspaces.find(ws => ws.id === workspaceId)
        if (!workspace || !workspace.output) return false

        const output = NiriService.outputs[workspace.output]
        if (!output) return false
        
        // Try logical first, then mode
        let outputWidth, outputHeight
        if (output.logical) {
            outputWidth = output.logical.width
            outputHeight = output.logical.height
        } else if (output.current_mode !== undefined && output.modes) {
            const mode = output.modes[output.current_mode]
            outputWidth = mode?.width
            outputHeight = mode?.height
        }
        
        if (!outputWidth || !outputHeight) return false

        // Window is fullscreen if it covers most of the output
        const widthMatch = windowWidth >= (outputWidth - _marginThreshold)
        const heightMatch = windowHeight >= (outputHeight - _marginThreshold)

        return widthMatch && heightMatch
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
        interval: 500
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
            hasAnyFullscreenWindow = false
            return
        }
        
        // Always update hasAnyFullscreenWindow (for toast suppression)
        hasAnyFullscreenWindow = checkAnyFullscreenWindow()

        if (!autoDetect) {
            _autoActive = false
            _fullscreenCount = 0
            return
        }

        const focusedWindow = NiriService.activeWindow
        const isFullscreen = isWindowFullscreen(focusedWindow)
        
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
            root.hasAnyFullscreenWindow = root.checkAnyFullscreenWindow()
        }
    }

    // Periodic check as fallback (less frequent)
    Timer {
        id: fallbackTimer
        interval: root.checkInterval
        running: root.autoDetect && CompositorService.isNiri && root._initialized
        repeat: true
        onTriggered: root.checkFullscreen()
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
            }
        }
    }

    // Niri animations control
    readonly property bool controlNiriAnimations: Config.options?.gameMode?.disableNiriAnimations ?? true
    readonly property string niriConfigPath: Quickshell.env("HOME") + "/.config/niri/config.kdl"

    function setNiriAnimations(enabled) {
        if (!controlNiriAnimations) return

        const sedExpr = enabled
            ? "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)off$/\\1\\/\\/off/' \"" + niriConfigPath + "\"\n"
            : "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)\\/\\/off$/\\1off/' \"" + niriConfigPath + "\"\n"

        niriAnimProcess.command = [
            "/usr/bin/bash",
            "-c",
            sedExpr + "/usr/bin/niri msg action reload-config"
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
    }
}
