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

    // Global summary for settings and callers without an output context.
    readonly property bool widgetsActive: !root.shouldPauseForOutput("")
    readonly property bool reducedMode: root.shouldPauseForOutput("")
    readonly property string pauseReason: root.pauseReasonForOutput("")

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

    function _hasWindowsOnActiveWorkspace(outputName: string): bool {
        return CompositorService.isNiri && NiriService.hasWindowsOnActiveWorkspace(outputName);
    }

    function _fullscreenForOutput(outputName: string): bool {
        const scopedOutput = String(outputName ?? "");
        if (scopedOutput.length === 0 || !CompositorService.isNiri)
            return GameMode.hasVisibleFullscreenWindow;
        return GameMode.hasFullscreenOnOutput(scopedOutput);
    }

    function _triggersForOutput(outputName: string): var {
        const scopedOutput = String(outputName ?? "");
        return {
            outputDisabled: scopedOutput.length > 0
                && !DesktopWidgetLayout.outputAllowed(scopedOutput),
            gameMode: root.pauseOnGameMode && GameMode.manuallyActivated,
            fullscreen: root.pauseOnFullscreen && root._fullscreenForOutput(scopedOutput),
            windowsPresent: root.pauseWhenWindowsPresent
                && root._hasWindowsOnActiveWorkspace(scopedOutput),
            editMode: GlobalStates.widgetEditMode
        };
    }

    function shouldPauseForOutput(outputName: string): bool {
        const scopedOutput = String(outputName ?? "");
        if (scopedOutput.length > 0
                && !DesktopWidgetLayout.outputAllowed(scopedOutput))
            return true;
        if (!root.enabled || GlobalStates.widgetEditMode)
            return false;
        const triggers = root._triggersForOutput(outputName);
        return triggers.outputDisabled || triggers.gameMode
            || triggers.fullscreen || triggers.windowsPresent;
    }

    function widgetsActiveForOutput(outputName: string): bool {
        return !root.shouldPauseForOutput(outputName);
    }

    function reducedModeForOutput(outputName: string): bool {
        return root.shouldPauseForOutput(outputName);
    }

    function pauseReasonForOutput(outputName: string): string {
        const scopedOutput = String(outputName ?? "");
        if (scopedOutput.length > 0
                && !DesktopWidgetLayout.outputAllowed(scopedOutput))
            return "outputDisabled";
        if (!root.enabled || GlobalStates.widgetEditMode)
            return "";
        const triggers = root._triggersForOutput(scopedOutput);
        if (triggers.gameMode) return "gameMode";
        if (triggers.fullscreen) return "fullscreen";
        if (triggers.windowsPresent) return "windowsPresent";
        return "";
    }

    // ══════════════════════════════════════════════════════════════════════
    // IPC HANDLER
    // ══════════════════════════════════════════════════════════════════════

    IpcHandler {
        target: "widgetpower"

        function status(): string {
            const outputs = {};
            const screens = Quickshell.screens ?? [];
            for (let i = 0; i < screens.length; i++) {
                const outputName = String(screens[i]?.name ?? "");
                if (outputName.length === 0)
                    continue;
                outputs[outputName] = {
                    widgetsActive: root.widgetsActiveForOutput(outputName),
                    triggers: root._triggersForOutput(outputName)
                };
            }
            return JSON.stringify({
                enabled: root.enabled,
                widgetsActive: root.widgetsActive,
                pauseReason: root.pauseReason,
                triggers: root._triggersForOutput(""),
                outputs: outputs
            }, null, 2)
        }
    }
}
