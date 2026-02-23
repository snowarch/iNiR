pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.lock
import qs.modules.waffle.lock
import qs.modules.waffle.looks
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property bool _lockActivating: lockActivateDelay.running

    Timer {
        id: lockActivateDelay
        interval: 150
        repeat: false
        onTriggered: {
            GlobalStates.screenLocked = true;
        }
    }

    Process {
        id: unlockKeyringProc
        onExited: (exitCode, exitStatus) => {
            KeyringStorage.fetchKeyringData();
        }
    }
    function unlockKeyring() {
        // Note: unlock.sh is a bash script, so we run it directly
        unlockKeyringProc.exec({
            environment: ({
                "UNLOCK_PASSWORD": lockContext.currentText
            }),
            command: ["/usr/bin/bash", Quickshell.shellPath("scripts/keyring/unlock.sh")]
        })
    }

    property var windowData: []
    
    // Fallback lock screen when QS lock fails
    function useFallbackLock(): void {
        console.warn("[Lock] Activating fallback lock screen")
        // Release QS lock first
        GlobalStates.screenLocked = false
        // Try swaylock first (works on both Niri and Hyprland), then hyprlock
        // Using shell to check existence and run
        Quickshell.execDetached(["/usr/bin/bash", "-c", 
            "command -v swaylock && exec swaylock -f -c 1a1a2e || " +
            "command -v hyprlock && exec hyprlock || " +
            "notify-send -u critical 'Lock Failed' 'Install swaylock or hyprlock as fallback'"
        ])
    }
    
    function saveWindowPositionAndTile() {
        if (!CompositorService.isHyprland) return;
        Quickshell.execDetached(["/usr/bin/hyprctl", "keyword", "dwindle:pseudotile", "true"])
        root.windowData = HyprlandData.windowList.filter(w => (w.floating && w.workspace.id === HyprlandData.activeWorkspace.id))
        root.windowData.forEach(w => {
			Hyprland.dispatch(`pseudo address:${w.address}`)
            Hyprland.dispatch(`settiled address:${w.address}`)
			Hyprland.dispatch(`movetoworkspacesilent ${w.workspace.id},address:${w.address}`)
        })
    }
    function restoreWindowPositionAndTile() {
        if (!CompositorService.isHyprland) return;
        root.windowData.forEach(w => {
            Hyprland.dispatch(`setfloating address:${w.address}`)
            Hyprland.dispatch(`movewindowpixel exact ${w.at[0]} ${w.at[1]}, address:${w.address}`)
			Hyprland.dispatch(`pseudo address:${w.address}`)
        })
		Quickshell.execDetached(["/usr/bin/hyprctl", "keyword", "dwindle:pseudotile", "false"])
    }

    // This stores all the information shared between the lock surfaces on each screen.
    // https://github.com/quickshell-mirror/quickshell-examples/tree/master/lockscreen
    LockContext {
        id: lockContext

        Connections {
            target: GlobalStates
            function onScreenLockedChanged() {
                if (GlobalStates.screenLocked) {
                    lockContext.reset();
                    lockContext.tryFingerUnlock();
                }
            }
        }

        onUnlocked: (targetAction) => {
            // Perform the target action if it's not just unlocking
            if (targetAction == LockContext.ActionEnum.Poweroff) {
                Session.poweroff();
                return;
            } else if (targetAction == LockContext.ActionEnum.Reboot) {
                Session.reboot();
                return;
            }

            // Unlock the keyring if configured to do so
            if (Config.options?.lock?.security?.unlockKeyring ?? true) root.unlockKeyring(); // Async

            // Unlock the screen before exiting, or the compositor will display a
            // fallback lock you can't interact with.
            GlobalStates.screenLocked = false;
            
            // Refocus last focused window on unlock (hack)
            if (CompositorService.isHyprland) {
                Quickshell.execDetached(["/usr/bin/bash", "-lc", "/usr/bin/sleep 0.2; /usr/bin/hyprctl --batch 'dispatch togglespecialworkspace; dispatch togglespecialworkspace'"])
            }

            // Reset
            lockContext.reset();

            // Post-unlock actions: activate idle inhibitor if requested
            if (lockContext.alsoInhibitIdle) {
                lockContext.alsoInhibitIdle = false;
                Idle.toggleInhibit(true);
            }
        }
    }

    // Lock surface component - switches between Material (inir) and Windows 11 (waffle) styles
    // Reactive binding - updates automatically when panelFamily changes (but only when unlocked)
    readonly property bool useWaffleLock: Config.ready && !GlobalStates.screenLocked 
        ? (Config.options?.panelFamily === "waffle")
        : root._cachedUseWaffleLock
    
    // Cache the last known value to prevent switching during lock
    property bool _cachedUseWaffleLock: false
    
    onUseWaffleLockChanged: {
        if (!GlobalStates.screenLocked) {
            root._cachedUseWaffleLock = root.useWaffleLock
        }
    }
    
    Component.onCompleted: {
        // Initialize cache
        if (Config.ready) {
            root._cachedUseWaffleLock = Config.options?.panelFamily === "waffle"
        }
    }
    
    Component {
        id: inirLockComponent
        LockSurface {
            context: lockContext
        }
    }
    
    Component {
        id: waffleLockComponent
        WaffleLockSurface {
            context: lockContext
        }
    }
    
    Component {
        id: waffleLockSafeComponent
        WaffleLockSurfaceSafe {
            context: lockContext
        }
    }
    
    WlSessionLock {
        id: lock
        locked: GlobalStates.screenLocked

        WlSessionLockSurface {
            id: lockSurface
            color: root._cachedUseWaffleLock ? Looks.colors.bg0 : Appearance.colors.colLayer0
            
            // Fallback timer - if lock surface doesn't load properly, use swaylock
            Timer {
                id: fallbackTimer
                interval: 2000
                running: GlobalStates.screenLocked && !lockSurfaceLoader.item
                onTriggered: {
                    console.warn("[Lock] Lock surface failed to load, using swaylock fallback")
                    root.useFallbackLock()
                }
            }
            
            Loader {
                id: lockSurfaceLoader
                active: GlobalStates.screenLocked && Config.ready
                anchors.fill: parent
                // Don't animate opacity - causes issues during hot-reload
                opacity: active ? 1 : 0
                sourceComponent: root._cachedUseWaffleLock
                    ? (CompositorService.isNiri ? waffleLockSafeComponent : waffleLockComponent)
                    : inirLockComponent
                
                // Detect load errors
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("[Lock] Lock surface failed to load: " + sourceComponent.errorString())
                        root.useFallbackLock()
                    }
                }
                
                // Force focus to loaded item
                onLoaded: {
                    if (item) {
                        item.forceActiveFocus()
                        fallbackTimer.stop()
                    }
                }
                
                // Re-focus when becoming active
                onActiveChanged: {
                    if (active && item) {
                        Qt.callLater(() => {
                            if (item) item.forceActiveFocus()
                        })
                    }
                }
            }
            
            // Ensure focus is given to lock surface when screen locks
            Connections {
                target: GlobalStates
                function onScreenLockedChanged() {
                    if (GlobalStates.screenLocked && lockSurfaceLoader.item) {
                        Qt.callLater(() => {
                            if (lockSurfaceLoader.item) {
                                lockSurfaceLoader.item.forceActiveFocus()
                            }
                        })
                    }
                }
            }
        }
    }

    // Blur layer hack (Hyprland only)
    // This pushes windows off-screen to create a blur effect behind the lock screen.
    // On Niri, use layer-rule { blur; } in config.kdl for the "quickshell:lock" namespace instead.
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            required property ShellScreen modelData
            property bool shouldPush: GlobalStates.screenLocked && CompositorService.isHyprland
            property string targetMonitorName: modelData.name
            property int verticalMovementDistance: modelData.height
            property int horizontalSqueeze: modelData.width * 0.2
            onShouldPushChanged: {
                if (shouldPush) {
                    root.saveWindowPositionAndTile();
                    Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${targetMonitorName}, addreserved, ${verticalMovementDistance}, ${-verticalMovementDistance}, ${horizontalSqueeze}, ${horizontalSqueeze}`])
                } else {
                    Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${targetMonitorName}, addreserved, 0, 0, 0, 0`])
                    root.restoreWindowPositionAndTile();
                }
            }
        }
    }

    IpcHandler {
        target: "lock"

        function activate(): void {
            if (GlobalStates.screenLocked || root._lockActivating)
                return;
            lockActivateDelay.restart();
        }

        function deactivate(): void {
            lockActivateDelay.stop();
            GlobalStates.screenLocked = false;
        }

        function status(): string {
            if (GlobalStates.screenLocked)
                return "locked";
            if (root._lockActivating)
                return "activating";
            return "unlocked";
        }

        function focus(): void {
            lockContext.shouldReFocus();
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "lock"
                description: "Locks the screen"

                onPressed: {
                    if (Config.options?.lock?.useHyprlock ?? false) {
                        Quickshell.execDetached(["/usr/bin/bash", "-lc", "/usr/bin/pidof hyprlock || /usr/bin/hyprlock"]);
                        return;
                    }
                    if (!GlobalStates.screenLocked && !root._lockActivating)
                        lockActivateDelay.restart();
                }
            }

            GlobalShortcut {
                name: "lockFocus"
                description: "Re-focuses the lock screen."

                onPressed: {
                    lockContext.shouldReFocus();
                }
            }
        }
    }

    function initIfReady() {
        if (!Config.ready || !Persistent.ready) return;
        if ((Config.options?.lock?.launchOnStartup ?? false) && Persistent.isNewHyprlandInstance) {
            // Launch lock screen on startup
            if (CompositorService.isHyprland) {
                Hyprland.dispatch("global quickshell:lock")
            } else {
                if (!GlobalStates.screenLocked && !root._lockActivating)
                    lockActivateDelay.restart();
            }
        } else {
            KeyringStorage.fetchKeyringData();
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            root.initIfReady();
        }
    }
    Connections {
        target: Persistent
        function onReadyChanged() {
            root.initIfReady();
        }
    }
}
