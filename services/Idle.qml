pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool inhibit: false
    readonly property int screenOffTimeout: Config.options?.idle?.screenOffTimeout ?? 300
    readonly property int lockTimeout: Config.options?.idle?.lockTimeout ?? 600
    readonly property int suspendTimeout: Config.options?.idle?.suspendTimeout ?? 0

    onScreenOffTimeoutChanged: _restartSwayidle()
    onLockTimeoutChanged: _restartSwayidle()
    onSuspendTimeoutChanged: _restartSwayidle()
    onInhibitChanged: _restartSwayidle()

    function toggleInhibit(active = null): void {
        if (active !== null) {
            inhibit = active;
        } else {
            inhibit = !inhibit;
        }
        Persistent.states.idle.inhibit = inhibit;
    }

    function _restartSwayidle() {
        _stopSwayidle()
        if (!inhibit) _startSwayidleDelayed.start()
    }

    function _stopSwayidle() {
        Quickshell.execDetached(["/usr/bin/pkill", "-x", "swayidle"])
    }

    function _startSwayidle() {
        if (inhibit) return

        const cmd = ["/usr/bin/swayidle", "-w"]
        const lockBeforeSleep = Config.options?.idle?.lockBeforeSleep !== false

        if (screenOffTimeout > 0) {
            cmd.push("timeout", screenOffTimeout.toString(), "/usr/bin/niri msg action power-off-monitors", "resume", "/usr/bin/niri msg action power-on-monitors")
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
            cmd.push("timeout", effectiveLockTimeout.toString(), "/usr/bin/qs -c inir ipc call lock activate")
        }

        if (suspendTimeout > 0) {
            cmd.push("timeout", suspendTimeout.toString(), "/usr/bin/systemctl suspend -i")
        }

        if (lockBeforeSleep) {
            cmd.push("before-sleep", "/usr/bin/qs -c inir ipc call lock activate")
        }

        console.log("[Idle] Starting swayidle")
        Quickshell.execDetached(cmd)
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

    Component.onDestruction: _stopSwayidle()
}
