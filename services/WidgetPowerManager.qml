pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

/**
 * WidgetPowerManager - Controls power/performance state of desktop widgets.
 *
 * Uses the same logic as Background.qml's focusWindowsPresent to detect when
 * windows are present. When windows cover the desktop, expensive widget
 * operations (blur FBOs, FrameAnimations, high-precision clocks) are paused
 * to save GPU/CPU.
 *
 * This complements dynamicOpacity (visual fade) with actual resource savings.
 */
Singleton {
    id: root

    // ══════════════════════════════════════════════════════════════════════
    // PUBLIC API - Widgets bind to these
    // ══════════════════════════════════════════════════════════════════════

    // Master switch: false = pause expensive operations (blur layers, 
    // FrameAnimations, Cava, high-frequency timers)
    readonly property bool widgetsActive: !_shouldPause

    // True when widgets should reduce activity (lower precision clocks, etc)
    readonly property bool reducedMode: _shouldPause

    // ══════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ══════════════════════════════════════════════════════════════════════

    // Enable/disable the power manager entirely
    readonly property bool enabled: Config.options?.background?.widgets?.powerSaving?.enable ?? true
    
    // Pause when GameMode is active
    readonly property bool pauseOnGameMode: Config.options?.background?.widgets?.powerSaving?.pauseOnGameMode ?? true
    
    // Pause when fullscreen window is present
    readonly property bool pauseOnFullscreen: Config.options?.background?.widgets?.powerSaving?.pauseOnFullscreen ?? true
    
    // Pause when any window is on the current workspace. Default false: stacked with dynamicOpacity
    // on the same trigger and made widgets feel broken (paused + dimmed) on any window open.
    readonly property bool pauseWhenWindowsPresent: Config.options?.background?.widgets?.powerSaving?.pauseWhenWindowsPresent ?? false

    // ══════════════════════════════════════════════════════════════════════
    // INTERNAL STATE
    // ══════════════════════════════════════════════════════════════════════

    property bool _shouldPause: false

    // Same logic as Background.qml's hasWindowsOnCurrentWorkspace
    readonly property bool _hasWindowsOnWorkspace: {
        try {
            if (CompositorService.isNiri && NiriService.windows && NiriService.workspaces) {
                const allWs = Object.values(NiriService.workspaces);
                if (!allWs || allWs.length === 0) return false;
                const currentNumber = NiriService.getCurrentWorkspaceNumber();
                const currentWs = allWs.find(ws => ws.idx === currentNumber);
                if (!currentWs) return false;
                return NiriService.windows.some(w => w.workspace_id === currentWs.id && !w.is_minimized);
            }
            return false;
        } catch (e) { return false; }
    }

    // React to NiriService changes (windows/workspaces)
    Connections {
        target: NiriService
        enabled: CompositorService.isNiri
        function onWindowsChanged(): void { root._updateState() }
        function onWorkspacesChanged(): void { root._updateState() }
    }

    function _updateState(): void {
        if (!root.enabled) {
            root._shouldPause = false
            return
        }

        // Don't pause in widget edit mode
        if (GlobalStates.widgetEditMode) {
            root._shouldPause = false
            return
        }

        const gameModeActive = root.pauseOnGameMode && GameMode.active
        const fullscreenActive = root.pauseOnFullscreen && GameMode.hasAnyFullscreenWindow
        const windowsPresent = root.pauseWhenWindowsPresent && root._hasWindowsOnWorkspace

        root._shouldPause = gameModeActive || fullscreenActive || windowsPresent
    }

    // ══════════════════════════════════════════════════════════════════════
    // REACTIVE CONNECTIONS
    // ══════════════════════════════════════════════════════════════════════

    Connections {
        target: GameMode
        function onActiveChanged(): void { root._updateState() }
        function onHasAnyFullscreenWindowChanged(): void { root._updateState() }
    }

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void { root._updateState() }
    }

    // ══════════════════════════════════════════════════════════════════════
    // IPC HANDLER
    // ══════════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "widgetpower"

        function status(): string {
            return JSON.stringify({
                enabled: root.enabled,
                widgetsActive: root.widgetsActive,
                triggers: {
                    gameMode: root.pauseOnGameMode && GameMode.active,
                    fullscreen: root.pauseOnFullscreen && GameMode.hasAnyFullscreenWindow,
                    windowsPresent: root.pauseWhenWindowsPresent && root._hasWindowsOnWorkspace,
                    editMode: GlobalStates.widgetEditMode
                }
            }, null, 2)
        }
    }

    Component.onCompleted: Qt.callLater(root._updateState)
}
