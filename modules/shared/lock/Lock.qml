pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.shared.lock
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property bool _lockActivating: lockActivateDelay.running
    // The compositor session the lock belongs to: a lock survives a shell restart only inside the same one.
    readonly property string _sessionSocket: CompositorService.niriNative ? Quickshell.env("NIRI_SOCKET") : CompositorService.umbrielSocket
    readonly property string _lockRecoveryPath: {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        return runtimeDir.length > 0 ? runtimeDir + "/inir-session-lock.state" : ""
    }
    property bool _recoveryStateLoaded: false

    function writeRecoveryState(locked: bool): void {
        if (_sessionSocket.length === 0 || !_recoveryStateLoaded || _lockRecoveryPath.length === 0)
            return
        lockRecoveryFile.setText((locked ? "locked" : "unlocked") + "\n" + _sessionSocket + "\n")
    }

    function loadRecoveryState(): void {
        if (_recoveryStateLoaded)
            return

        const lines = lockRecoveryFile.text().split("\n")
        const wasLocked = lines[0] === "locked"
        const previousSocket = lines[1] ?? ""
        _recoveryStateLoaded = true

        if (_sessionSocket.length === 0)
            return

        if (wasLocked && previousSocket === _sessionSocket) {
            console.warn("[Lock] Recovering interrupted compositor session lock")
            GlobalStates.screenLocked = true
            return
        }

        writeRecoveryState(GlobalStates.screenLocked)
    }

    FileView {
        id: lockRecoveryFile
        path: root._lockRecoveryPath
        blockLoading: true
        atomicWrites: true
        printErrors: false

        onLoaded: root.loadRecoveryState()
        onLoadFailed: {
            root._recoveryStateLoaded = true
            // later: stock Quickshell forgets a write started inside its own load signal
            Qt.callLater(() => root.writeRecoveryState(GlobalStates.screenLocked))
        }
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged(): void {
            root.writeRecoveryState(GlobalStates.screenLocked)
        }
    }

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
            command: ["bash", Quickshell.shellPath("scripts/keyring/unlock.sh")]
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
        Quickshell.execDetached(["bash", "-c", 
            "command -v swaylock && exec swaylock -f -c 1a1a2e || " +
            "command -v hyprlock && exec hyprlock || " +
            "notify-send -u critical 'Lock Failed' 'Install swaylock or hyprlock as fallback'"
        ])
    }
    
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
                    SystemInfo.refreshIdentity();
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

            // A family's surface that recedes on unlock (iRiS) says how long it takes; the session stays locked until then.
            if (root.recedeDuration > 0) {
                root.receding = true
                recedeRelease.restart()
                return
            }
            root.finishUnlock()
        }
    }

    property bool receding: false
    property int recedeDuration: 0
    Timer {
        id: recedeRelease
        interval: root.recedeDuration + 40
        onTriggered: root.finishUnlock()
    }
    Connections {
        target: GlobalStates
        function onScreenLockedChanged(): void {
            if (GlobalStates.screenLocked) return
            recedeRelease.stop()
            root.receding = false
        }
    }

    function finishUnlock(): void {
        // Unlock the screen before exiting, or the compositor will display a
        // fallback lock you can't interact with.
        GlobalStates.screenLocked = false;
        
        // Refocus last focused window on unlock (hack)
        if (CompositorService.isHyprland) {
            Quickshell.execDetached(["bash", "-lc", "sleep 0.2; hyprctl --batch 'dispatch togglespecialworkspace; dispatch togglespecialworkspace'"])
        }

        // Reset
        lockContext.reset();

        // Post-unlock actions: activate idle inhibitor if requested
        if (lockContext.alsoInhibitIdle) {
            lockContext.alsoInhibitIdle = false;
            Idle.toggleInhibit(true);
        }
    }

    // The lock surface is the active family's (Plugins part "lockSurface", "lockSurface.hyprland" where it differs);
    // Material's is the shared one. The family is read while unlocked and kept while locked, so a family switch never
    // swaps the surface under a locked session.
    readonly property string family: Config.ready && !GlobalStates.screenLocked ? Plugins.active : root._cachedFamily
    property string _cachedFamily: "ii"
    onFamilyChanged: if (!GlobalStates.screenLocked) root._cachedFamily = root.family
    readonly property string familySurface: (!CompositorService.isNiri && Plugins.part(root._cachedFamily, "lockSurface.hyprland"))
        || Plugins.part(root._cachedFamily, "lockSurface")

    Component.onCompleted: {
        if (Config.ready) root._cachedFamily = Plugins.active
        root.initIfReady()
    }
    
    Component {
        id: iiLockComponent
        LockSurface {
            context: lockContext
        }
    }
    
    
    WlSessionLock {
        id: lock
        locked: GlobalStates.screenLocked

        WlSessionLockSurface {
            id: lockSurface
            color: Appearance.colors.colLayer0

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
            }

            Loader {
                id: lockSurfaceLoader
                active: GlobalStates.screenLocked && Config.ready
                // A surface that arrives from the wallpaper (iRiS) loads in one go: an async first frame is a bare colour flash.
                asynchronous: !Plugins.flag(root._cachedFamily, "lockSurfaceSync")
                anchors.fill: parent
                // Don't animate opacity - causes issues during hot-reload
                opacity: active ? 1 : 0
                // context is required: a family's file loads through setSource with it as an initial property.
                function pick(): void {
                    if (root.familySurface.length > 0) setSource(root.familySurface, { context: lockContext })
                    else sourceComponent = iiLockComponent
                }
                Component.onCompleted: pick()
                Connections {
                    target: root
                    function onFamilySurfaceChanged(): void { lockSurfaceLoader.pick() }
                }
                
                // Detect load errors
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("[Lock] Lock surface failed to load:", sourceComponent.errorString())
                        root.useFallbackLock()
                    } else if (status === Loader.Loading) {
                        console.info("[Lock] Lock surface loading...")
                    } else if (status === Loader.Ready) {
                        console.info("[Lock] Lock surface loaded successfully")
                    }
                }
                
                Binding {
                    target: lockSurfaceLoader.item
                    when: lockSurfaceLoader.item !== null && "screenName" in lockSurfaceLoader.item
                    property: "screenName"
                    value: lockSurface.screen?.name ?? ""
                }
                Binding {
                    target: lockSurfaceLoader.item
                    when: lockSurfaceLoader.item !== null && "leaving" in lockSurfaceLoader.item
                    property: "leaving"
                    value: root.receding
                }
                Binding {
                    target: root
                    when: lockSurfaceLoader.item !== null && "recedeDuration" in lockSurfaceLoader.item
                    property: "recedeDuration"
                    value: lockSurfaceLoader.item?.recedeDuration ?? 0
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

            Timer {
                id: fallbackTimer
                interval: 2000
                running: GlobalStates.screenLocked && !lockSurfaceLoader.item && lockSurfaceLoader.status !== Loader.Loading
                onTriggered: {
                    console.warn("[Lock] Lock surface failed to load after 2s — status:",
                                 lockSurfaceLoader.status, "active:", lockSurfaceLoader.active,
                                 "Config.ready:", Config.ready, "family:", root._cachedFamily,
                                 "isNiri:", CompositorService.isNiri)
                    root.useFallbackLock()
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
            property string targetMonitorName: modelData ? modelData.name : ""
            property int verticalMovementDistance: modelData ? modelData.height : 0
            property int horizontalSqueeze: modelData ? modelData.width * 0.2 : 0
            onShouldPushChanged: {
                if (!modelData) return;
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

    // Heartbeat re-focus while locked. Niri sometimes drops keyboard focus on the
    // ext-session-lock surface after suspend/resume — the surface stays visible but
    // input goes nowhere until something forces a re-grab. We just nudge it back.
    // 2s cadence is cheap and only runs while locked.
    Timer {
        id: lockFocusHeartbeat
        interval: 2000
        repeat: true
        running: GlobalStates.screenLocked
        onTriggered: lockContext.shouldReFocus()
    }

    // Re-focus immediately when monitor topology changes (a common signal of wake-up).
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (GlobalStates.screenLocked) {
                Qt.callLater(() => lockContext.shouldReFocus())
            }
        }
    }

    /// Lock screen. For when you need to pretend you're working.
    ///
    /// ```kdl
    /// Super+Alt+L allow-when-locked=true { spawn "inir" "lock" "activate"; }
    /// ```
    IpcHandler {
        target: "lock"

        /// Lock the screen
        function activate(): void {
            if (Config.options?.lock?.useHyprlock ?? false) {
                Quickshell.execDetached(["bash", "-lc", "pidof hyprlock || hyprlock"]);
                return;
            }
            if (GlobalStates.screenLocked || root._lockActivating)
                return;
            lockActivateDelay.restart();
        }

        /// Suspend handshake: activate immediately and wait until the compositor confirms the session lock is secure
        function prepareSleep(): string {
            if (CompositorService.isHyprland && (Config.options?.lock?.useHyprlock ?? false)) {
                Quickshell.execDetached(["bash", "-lc", "pidof hyprlock || hyprlock"]);
                return "external";
            }

            // before-sleep must not return while the interactive debounce is still
            // pending. The launcher waits for lock.secure before swayidle releases
            // logind's delay inhibitor.
            lockActivateDelay.stop();
            if (!GlobalStates.screenLocked)
                GlobalStates.screenLocked = true;
            return lock.secure ? "secure" : "locking";
        }

        /// Cancel lock and mark screen unlocked
        function deactivate(): void {
            lockActivateDelay.stop();
            GlobalStates.screenLocked = false;
        }

        /// Return lock state (`secure`, `locked`, `activating`, or `unlocked`)
        function status(): string {
            if (lock.secure)
                return "secure";
            if (GlobalStates.screenLocked)
                return "locked";
            if (root._lockActivating)
                return "activating";
            return "unlocked";
        }

        /// Refocus the lock screen input
        function focus(): void {
            // swayidle calls this after logind resumes. Besides restoring lock
            // focus, broadcast the lifecycle event so persistent layer-shell
            // hosts can renegotiate native focus/input state.
            Idle.notifyResumed();
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
                        Quickshell.execDetached(["bash", "-lc", "pidof hyprlock || hyprlock"]);
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
        if (!Config.ready || !Persistent.ready || GlobalStates.startupLockDone)
            return;

        // This is session startup state, not compositor-instance state. The Lock
        // component is loaded asynchronously, so Config/Persistent may already
        // be ready before its Connections exist; Component.onCompleted below
        // mirrors the current state and this singleton guard prevents hot-reload
        // from locking again.
        GlobalStates.startupLockDone = true;

        if (Config.options?.lock?.launchOnStartup ?? false) {
            if (Config.options?.lock?.useHyprlock ?? false) {
                Quickshell.execDetached(["bash", "-lc", "pidof hyprlock || hyprlock"]);
            } else if (!GlobalStates.screenLocked && !root._lockActivating) {
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
