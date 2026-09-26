pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services
import "idlePolicy.js" as IdlePolicy
import "root:modules/common/functions/idleProfile.js" as IdleProfile

Singleton {
    id: root

    signal resumed()

    property bool inhibit: false

    readonly property var _resolvedIdle: IdleProfile.resolveTimeouts(
        Config.options?.idle,
        {
            available: Battery.available,
            onBattery: Battery.onBattery,
            percentage: Battery.percentage,
        }
    )

    readonly property bool batteryProfileActive: _resolvedIdle.isBatteryProfile
    readonly property int screenOffTimeout: _resolvedIdle.screenOffTimeout
    readonly property int lockTimeout: _resolvedIdle.lockTimeout
    readonly property int suspendTimeout: _resolvedIdle.suspendTimeout
    readonly property string launcherPath: Quickshell.shellPath("scripts/inir")

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

        const cmd = ["/usr/bin/swayidle", "-w"]
        const lockBeforeSleep = Config.options?.idle?.lockBeforeSleep !== false

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
            cmd.push("timeout", suspendTimeout.toString(), "/usr/bin/systemctl suspend -i")
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
