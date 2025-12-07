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

    // Public API
    property bool active: _manualActive || _autoActive
    property bool autoDetect: Config.options?.gameMode?.autoDetect ?? true
    property bool manuallyActivated: _manualActive

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

    // State file path
    readonly property string _stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/user/gamemode_active"

    // IPC handler for external control
    IpcHandler {
        target: "gamemode"
        function toggle(): void { root.toggle() }
        function activate(): void { root.activate() }
        function deactivate(): void { root.deactivate() }
        function status(): void { 
            console.log("[GameMode] Status - active:", root.active, "manual:", root._manualActive, "auto:", root._autoActive)
        }
    }

    function toggle() {
        _manualActive = !_manualActive
        _saveState()
        console.log("[GameMode] Toggled manually:", _manualActive)
    }

    function activate() {
        _manualActive = true
        _saveState()
        console.log("[GameMode] Activated manually")
    }

    function deactivate() {
        _manualActive = false
        _saveState()
        console.log("[GameMode] Deactivated manually")
    }

    function _saveState() {
        saveProcess.running = true
    }

    function _loadState() {
        stateReader.reload()
    }

    // Check if a window is fullscreen by comparing to output size
    function isWindowFullscreen(window) {
        if (!window || !window.layout) return false
        if (!CompositorService.isNiri) return false

        const windowSize = window.layout.window_size
        if (!windowSize || windowSize.length < 2) return false

        // Get output for this window's workspace
        const workspaceId = window.workspace_id
        const workspace = NiriService.allWorkspaces.find(ws => ws.id === workspaceId)
        if (!workspace || !workspace.output) return false

        const output = NiriService.outputs[workspace.output]
        if (!output || !output.logical) return false

        const outputWidth = output.logical.width
        const outputHeight = output.logical.height

        // Window is fullscreen if it covers most of the output
        const widthMatch = windowSize[0] >= (outputWidth - _marginThreshold)
        const heightMatch = windowSize[1] >= (outputHeight - _marginThreshold)

        return widthMatch && heightMatch
    }

    // Debounce timer for fullscreen checks
    Timer {
        id: checkDebounce
        interval: 300
        onTriggered: root._doCheckFullscreen()
    }

    // Auto-detection: check focused window (debounced)
    function checkFullscreen() {
        checkDebounce.restart()
    }

    function _doCheckFullscreen() {
        if (!autoDetect || !CompositorService.isNiri) {
            _autoActive = false
            return
        }

        const focusedWindow = NiriService.activeWindow
        const wasActive = _autoActive
        _autoActive = isWindowFullscreen(focusedWindow)
        
        if (_autoActive !== wasActive) {
            console.log("[GameMode] Auto-detect:", _autoActive ? "fullscreen detected" : "no fullscreen")
        }
    }

    // State persistence - read
    FileView {
        id: stateReader
        path: Qt.resolvedUrl(root._stateFile)

        onLoaded: {
            const content = stateReader.text()
            if (content.trim() === "1") {
                root._manualActive = true
                console.log("[GameMode] Restored manual state: active")
            } else {
                root._manualActive = false
            }
            root._initialized = true
            console.log("[GameMode] Initialized, manual:", root._manualActive)
        }

        onLoadFailed: (error) => {
            // File doesn't exist yet, that's fine
            root._manualActive = false
            root._initialized = true
            console.log("[GameMode] Initialized (no saved state)")
        }
    }

    // State persistence - write via process
    Process {
        id: saveProcess
        command: ["bash", "-c", "mkdir -p ~/.local/state/quickshell/user && echo " + (root._manualActive ? "1" : "0") + " > " + root._stateFile]
        onExited: console.log("[GameMode] State saved:", root._manualActive)
    }

    // React to window changes
    Connections {
        target: NiriService
        enabled: root.autoDetect && CompositorService.isNiri && root._initialized

        function onActiveWindowChanged() {
            root.checkFullscreen()
        }

        function onWindowsChanged() {
            root.checkFullscreen()
        }
    }

    // Periodic check as fallback
    Timer {
        interval: root.checkInterval
        running: root.autoDetect && CompositorService.isNiri && root._initialized
        repeat: true
        onTriggered: root.checkFullscreen()
    }

    // Initial setup
    Component.onCompleted: {
        console.log("[GameMode] Service starting...")
        // Ensure state directory exists and load state
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell/user"])
        
        // Load saved state after short delay
        initTimer.start()
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
        // Use sed to toggle "off" line in animations block
        // If enabling (gamemode off): comment out "off" -> "//off"  
        // If disabling (gamemode on): uncomment "off" -> "off"
        // The pattern matches indented off///off after "animations {"
        
        niriAnimProcess.command = enabled
            ? ["bash", "-c", "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)off$/\\1\\/\\/off/' " + niriConfigPath + " && niri msg action reload-config"]
            : ["bash", "-c", "sed -i '/^animations {/,/^}/ s/^\\([ \\t]*\\)\\/\\/off$/\\1off/' " + niriConfigPath + " && niri msg action reload-config"]
        niriAnimProcess.running = true
    }

    Process {
        id: niriAnimProcess
        onExited: (code, status) => {
            if (code === 0) {
                console.log("[GameMode] Niri animations updated")
            }
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
        console.log("[GameMode] Active:", active, "(manual:", _manualActive, "auto:", _autoActive, ")")
        if (CompositorService.isNiri && controlNiriAnimations) {
            niriAnimDebounce.restart()
        }
        // Note: Appearance.animationsEnabled reacts to GameMode.active automatically via binding
    }
}
