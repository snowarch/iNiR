pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false

    function fetchAvailability() {
        whichProc.running = true
    }

    function fetchActiveState() {
        pidofProc.running = true
    }

    function disable() {
        root.active = false
        pkillProc.running = true
    }

    function enable() {
        root.active = true
        // Use execDetached to avoid process management issues that can crash the shell
        Quickshell.execDetached(["/usr/bin/fish", "-c", "easyeffects --gapplication-service; or flatpak run com.github.wwmm.easyeffects --gapplication-service"])
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Timer {
        id: initTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.fetchAvailability()
            root.fetchActiveState()
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                initTimer.start()
            }
        }
    }

    Process {
        id: whichProc
        running: false
        command: ["/usr/bin/which", "easyeffects"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.available = true
            } else {
                flatpakInfoProc.running = true
            }
        }
    }

    Process {
        id: flatpakInfoProc
        running: false
        command: ["/usr/bin/flatpak", "info", "com.github.wwmm.easyeffects"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0)
        }
    }

    Process {
        id: pidofProc
        running: false
        command: ["/usr/bin/pidof", "easyeffects"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.active = true
            } else {
                flatpakPsProc.running = true
            }
        }
    }

    Process {
        id: flatpakPsProc
        running: false
        command: ["/usr/bin/flatpak", "ps", "--columns=application"]
        stdout: StdioCollector {
            id: flatpakPsCollector
            onStreamFinished: {
                const t = (flatpakPsCollector.text ?? "");
                root.active = t.split("\n").some(l => l.trim() === "com.github.wwmm.easyeffects")
            }
        }
    }

    Process {
        id: pkillProc
        running: false
        command: ["/usr/bin/pkill", "easyeffects"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                flatpakKillProc.running = true
            }
        }
    }

    Process {
        id: flatpakKillProc
        running: false
        command: ["/usr/bin/flatpak", "kill", "com.github.wwmm.easyeffects"]
    }
}
