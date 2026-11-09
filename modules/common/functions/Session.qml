pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import qs.modules.common

Singleton {
    id: root

    property string _hibernateCapability: ""
    readonly property bool hibernateCapabilityKnown: _hibernateCapability.length > 0
    readonly property bool canHibernate: _hibernateCapability === "yes"
    readonly property bool showHibernateAction: !hibernateCapabilityKnown || canHibernate

    Timer {
        id: _hibernateMonitorsOffTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (CompositorService.isNiri) {
                Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "off"])
            }
        }
    }

    Timer {
        id: _hibernateTimer
        interval: 900
        repeat: false
        onTriggered: {
            root.powerAction(["hibernate"])
        }
    }

    Timer {
        id: _suspendTimer
        interval: 600
        repeat: false
        onTriggered: {
            root.powerAction(["suspend"])
        }
    }

    // systemd's loginctl has no power verbs; elogind's (Void) has them and spells -i as --ignore-inhibitors.
    // /run/systemd/system exists only when systemd is init (sd_booted).
    readonly property string powerActionScript:
        'if [ -d /run/systemd/system ]; then exec systemctl "$@" -i; fi; exec loginctl --ignore-inhibitors "$@"'

    function powerAction(args: var): void {
        Quickshell.execDetached(["/bin/sh", "-c", root.powerActionScript, "sh"].concat(args))
    }

    function _parseLogin1Capability(text: string): string {
        const trimmed = (text ?? "").trim()
        const match = trimmed.match(/^s\s+"([^"]+)"$/)
        return (match ? match[1] : trimmed).toLowerCase()
    }

    function refreshSleepCapabilities(): void {
        detectHibernateCapability.running = false
        detectHibernateCapability.running = true
    }

    function _notifyHibernateUnavailable(): void {
        Quickshell.execDetached([
            "notify-send",
            Translation.tr("Hibernate unavailable"),
            Translation.tr("This system does not report hibernation support. Configure persistent swap and resume first."),
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ])
    }

    function closeAllWindows() {
        // Sólo tiene sentido en sesiones Hyprland; en Niri no hay HyprlandData
        if (!CompositorService.isHyprland)
            return;

        HyprlandData.windowList.map(w => w.pid).forEach(pid => {
            Quickshell.execDetached(["kill", pid]);
        });
    }

    function lock() {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"]);
    }

    function suspend() {
        if (Config.options?.idle?.lockBeforeSleep !== false) {
            lock()
            _suspendTimer.restart()
        } else {
            powerAction(["suspend"])
        }
    }

    function logout() {
        if (CompositorService.isNiri) {
            NiriService.quit();
            return;
        }

        closeAllWindows();
        Quickshell.execDetached(["pkill", "-i", "Hyprland"]);
    }

    function launchTaskManager() {
        AppLauncher.launch("taskManager")
    }

    function hibernate() {
        if (hibernateCapabilityKnown && !canHibernate) {
            root.refreshSleepCapabilities()
            root._notifyHibernateUnavailable()
            return
        }

        lock();
        _hibernateMonitorsOffTimer.restart()
        _hibernateTimer.restart()
    }

    function poweroff() {
        closeAllWindows();
        powerAction(["poweroff"])
    }

    function reboot() {
        closeAllWindows();
        powerAction(["reboot"])
    }

    function rebootToFirmware() {
        closeAllWindows();
        powerAction(["reboot", "--firmware-setup"])
    }

    Connections {
        target: GlobalStates

        function onSessionOpenChanged() {
            if (GlobalStates.sessionOpen) {
                root.refreshSleepCapabilities()
            }
        }
    }

    Process {
        id: detectHibernateCapability
        command: [
            "busctl", "--system", "call",
            "org.freedesktop.login1",
            "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager",
            "CanHibernate",
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const capability = root._parseLogin1Capability(text)
                if (capability.length > 0) {
                    root._hibernateCapability = capability
                }
            }
        }
    }
}
