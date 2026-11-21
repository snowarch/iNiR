pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services
import "idlePolicy.js" as IdlePolicy

Singleton {
    id: root

    signal resumed()

    property bool inhibit: false

    // Battery profile: only meaningful on a laptop that is actually unplugged.
    readonly property bool batteryProfileActive: (Config.options?.idle?.onBattery?.enable ?? false)
        && Battery.onBattery

    readonly property int screenOffTimeout: batteryProfileActive
        ? (Config.options?.idle?.onBattery?.screenOffTimeout ?? 120)
        : (Config.options?.idle?.screenOffTimeout ?? 300)
    readonly property int lockTimeout: batteryProfileActive
        ? (Config.options?.idle?.onBattery?.lockTimeout ?? 300)
        : (Config.options?.idle?.lockTimeout ?? 600)
    readonly property int suspendTimeout: batteryProfileActive
        ? (Config.options?.idle?.onBattery?.suspendTimeout ?? 600)
        : (Config.options?.idle?.suspendTimeout ?? 0)
    // The rest screen is the same on battery: it costs nothing the screen-off timeout would save.
    readonly property int restTimeout: Config.options?.idle?.restTimeout ?? 0
    readonly property string launcherPath: Quickshell.shellPath("scripts/inir")

    onRestTimeoutChanged: _restartSwayidle()
    onScreenOffTimeoutChanged: _restartSwayidle()
    onLockTimeoutChanged: _restartSwayidle()
    onSuspendTimeoutChanged: _restartSwayidle()
    onInhibitChanged: _restartSwayidle()
    // Plugging in with identical timeouts on both profiles changes no timeout
    // property, so swayidle would keep the old command line without this.
    onBatteryProfileActiveChanged: _restartSwayidle()

    function toggleInhibit(active = null): void {
        if (active !== null) {
            inhibit = active;
        } else {
            inhibit = !inhibit;
        }
        Persistent.states.idle.inhibit = inhibit;
    }

    function notifyResumed(): void {
        root.resumed()
    }

    // The rest screen never shows over the lock or the session screen; whatever shows it, any input sends it away.
    function showRest(): void {
        if (GlobalStates.screenLocked || GlobalStates.sessionOpen)
            return
        // An open panel that holds the keyboard keeps it (Niri gives it to the oldest exclusive surface), and a key
        // would then go to the panel under the rest screen instead of sending the rest screen away. So panels close.
        DevNavigation.closeAll()
        GlobalStates.restOpen = true
    }

    function hideRest(): void {
        GlobalStates.restOpen = false
    }

    function _restartSwayidle() {
        _stopSwayidle()
        if (!inhibit) _startSwayidleDelayed.start()
    }

    function _stopSwayidle() {
        _startSwayidleDelayed.stop()
        swayidleProcess.running = false
    }

    function _startSwayidle() {
        if (inhibit) return

        const cmd = ["swayidle", "-w"]
        const lockBeforeSleep = Config.options?.idle?.lockBeforeSleep !== false

        if (restTimeout > 0) {
            const inir = StringUtils.shellSingleQuoteEscape(root.launcherPath);
            cmd.push("timeout", restTimeout.toString(), `'${inir}' rest show`, "resume", `'${inir}' rest hide`)
        }

        if (screenOffTimeout > 0 && CompositorService.isNiri) {
            const inir = StringUtils.shellSingleQuoteEscape(root.launcherPath);
            cmd.push("timeout", screenOffTimeout.toString(), IdlePolicy.niriOffCommand(inir), "resume", IdlePolicy.niriResumeCommand(inir))
        }

        // Determine effective lock timeout
        // If suspend is configured and lockBeforeSleep is enabled, ensure lock happens before suspend
        let effectiveLockTimeout = lockTimeout
        if (suspendTimeout > 0 && lockBeforeSleep) {
            // Lock should happen before suspend - use 5 seconds before suspend if lockTimeout is 0 or > suspendTimeout
            const lockBeforeSuspendTime = Math.max(1, suspendTimeout - 5)
            if (lockTimeout <= 0 || lockTimeout > lockBeforeSuspendTime) {
                effectiveLockTimeout = lockBeforeSuspendTime
            }
        }

        if (effectiveLockTimeout > 0) {
            cmd.push("timeout", effectiveLockTimeout.toString(), `'${StringUtils.shellSingleQuoteEscape(root.launcherPath)}' lock activate`)
        }

        if (suspendTimeout > 0) {
            cmd.push("timeout", suspendTimeout.toString(), `/bin/sh -c '${StringUtils.shellSingleQuoteEscape(Session.powerActionScript)}' sh suspend`)
        }

        if (lockBeforeSleep) {
            cmd.push("before-sleep", `'${StringUtils.shellSingleQuoteEscape(root.launcherPath)}' lock prepareSleep`)
        }

        // Re-focus the lock surface and broadcast a shell-wide resume event.
        // The latter lets persistent layer-shell hosts renegotiate native state
        // after logind resumes without restarting the whole shell.
        cmd.push("after-resume", `'${StringUtils.shellSingleQuoteEscape(root.launcherPath)}' lock focus`)

        if (Quickshell.env("QS_DEBUG") === "1") console.log("[Idle] Starting swayidle")
        swayidleProcess.command = cmd
        swayidleProcess.running = true
    }

    Process {
        id: swayidleProcess
    }

    Timer {
        id: _startSwayidleDelayed
        interval: 200
        onTriggered: root._startSwayidle()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root._restartSwayidle()
        }
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) root.hideRest()
        }
        function onSessionOpenChanged() {
            if (GlobalStates.sessionOpen) root.hideRest()
        }
    }

    /// The rest screen: the active family's calm clock over every screen, sent away by a key, a click or a moved pointer.
    /// `idle.restTimeout` shows it after that many idle seconds (0 = never); it never shows over the lock.
    IpcHandler {
        target: "rest"
        /// Show the rest screen
        function show(): void { root.showRest() }
        /// Send the rest screen away
        function hide(): void { root.hideRest() }
        /// Show or hide the rest screen
        function toggle(): void { if (GlobalStates.restOpen) root.hideRest(); else root.showRest() }
        /// "shown" or "hidden"
        function status(): string { return GlobalStates.restOpen ? "shown" : "hidden" }
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready && Persistent.states?.idle?.inhibit)
                root.inhibit = true
        }
    }

    Component.onCompleted: {
        if (Persistent.ready && (Persistent.states?.idle?.inhibit ?? false))
            root.inhibit = true
        else if (Config.ready)
            root._restartSwayidle()
    }

    Component.onDestruction: _stopSwayidle()
}
