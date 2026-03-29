pragma Singleton
import Quickshell
import QtQuick
import qs.services
import qs.modules.common

Singleton {
    id: root

    Timer {
        id: _hibernateMonitorsOffTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (CompositorService.isNiri) {
                Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "power-off-monitors"])
            } else if (CompositorService.isHyprland) {
                Quickshell.execDetached(["/usr/bin/hyprctl", "dispatch", "dpms", "off"])
            }
        }
    }

    Timer {
        id: _hibernateTimer
        interval: 900
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["/usr/bin/systemctl", "hibernate", "-i"])
            Quickshell.execDetached(["/usr/bin/loginctl", "hibernate"])
        }
    }

    Timer {
        id: _suspendTimer
        interval: 600
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["/usr/bin/systemctl", "suspend", "-i"])
        }
    }

    function closeAllWindows() {
        // Sólo tiene sentido en sesiones Hyprland; en Niri no hay HyprlandData
        if (!CompositorService.isHyprland)
            return;

        HyprlandData.windowList.map(w => w.pid).forEach(pid => {
            Quickshell.execDetached(["/usr/bin/kill", pid]);
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
            Quickshell.execDetached(["/usr/bin/systemctl", "suspend", "-i"])
        }
    }

    function logout() {
        if (CompositorService.isNiri) {
            NiriService.quit();
            return;
        }

        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/pkill", "-i", "Hyprland"]);
    }

    function launchTaskManager() {
        AppLauncher.launch("taskManager")
    }

    function hibernate() {
        lock();
        _hibernateMonitorsOffTimer.restart()
        _hibernateTimer.restart()
    }

    function poweroff() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/systemctl", "poweroff", "-i"])
        Quickshell.execDetached(["/usr/bin/loginctl", "poweroff"])
    }

    function reboot() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/systemctl", "reboot", "-i"])
        Quickshell.execDetached(["/usr/bin/loginctl", "reboot"])
    }

    function rebootToFirmware() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/systemctl", "reboot", "--firmware-setup"])
        Quickshell.execDetached(["/usr/bin/loginctl", "reboot", "--firmware-setup"])
    }
}
