pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.lock
import qs.modules.waffle.lock
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

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
            command: [Quickshell.shellPath("scripts/keyring/unlock.sh")]
        })
    }

    property var windowData: []
    function saveWindowPositionAndTile() {
        if (!CompositorService.isHyprland) return;
        Quickshell.execDetached(["hyprctl", "keyword", "dwindle:pseudotile", "true"])
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
		Quickshell.execDetached(["hyprctl", "keyword", "dwindle:pseudotile", "false"])
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
                Quickshell.execDetached(["fish", "-c", "sleep 0.2; hyprctl --batch 'dispatch togglespecialworkspace; dispatch togglespecialworkspace'"])
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

    // Lock surface component - switches between Material (ii) and Windows 11 (waffle) styles
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
        id: iiLockComponent
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
    
    WlSessionLock {
        id: lock
        locked: GlobalStates.screenLocked

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"
            
            Loader {
                id: lockSurfaceLoader
                active: GlobalStates.screenLocked && Config.ready
                anchors.fill: parent
                // Don't animate opacity - causes issues during hot-reload
                opacity: active ? 1 : 0
                sourceComponent: root._cachedUseWaffleLock ? waffleLockComponent : iiLockComponent
                
                // Force focus to loaded item
                onLoaded: {
                    if (item) {
                        item.forceActiveFocus()
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
            GlobalStates.screenLocked = true;
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
                        Quickshell.execDetached(["fish", "-c", "pidof hyprlock; or hyprlock"]);
                        return;
                    }
                    GlobalStates.screenLocked = true;
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
                GlobalStates.screenLocked = true
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
