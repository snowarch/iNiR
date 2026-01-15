import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleModel {
    id: root
    name: Translation.tr("Cloudflare WARP")

    readonly property string warpCliPath: "/usr/bin/warp-cli"
    readonly property string notifySendPath: "/usr/bin/notify-send"

    available: false
    toggled: false
    icon: "cloud_lock"
    statusText: root._daemonRunning ? "" : Translation.tr("Daemon not running")
    hasStatusText: true

    property bool _daemonRunning: true

    function refreshStatus() {
        fetchActiveState.running = false;
        fetchActiveState.running = true;
    }

    mainAction: () => {
        if (!root._daemonRunning) {
            startServiceProc.running = true;
            return;
        }
        if (toggled) disconnectProc.running = true;
        else connectProc.running = true;
    }

    altAction: () => {
        startServiceProc.running = true;
    }

    Process {
        id: disconnectProc
        command: [root.warpCliPath, "disconnect"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([root.notifySendPath,
                    Translation.tr("Cloudflare WARP"),
                    Translation.tr("Disconnect failed. Please inspect manually with the <tt>warp-cli</tt> command"),
                    "-a", "Shell"
                ])
            }
            root.refreshStatus();
        }
    }

    Process {
        id: connectProc
        command: [root.warpCliPath, "connect"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([root.notifySendPath,
                    Translation.tr("Cloudflare WARP"),
                    Translation.tr("Connection failed. Please inspect manually with the <tt>warp-cli</tt> command")
                    , "-a", "Shell"
                ])
            }
            root.refreshStatus();
        }
    }

    Process {
        id: registrationProc
        command: [root.warpCliPath, "registration", "new"]
        onExited: (exitCode, exitStatus) => {
            console.log("Warp registration exited with code and status:", exitCode, exitStatus)
            if (exitCode === 0) {
                connectProc.running = true
            } else {
                Quickshell.execDetached([root.notifySendPath,
                    Translation.tr("Cloudflare WARP"),
                    Translation.tr("Registration failed. Please inspect manually with the <tt>warp-cli</tt> command"),
                    "-a", "Shell"
                ])
            }
        }
    }

    Process {
        id: fetchActiveState
        running: false
        command: [root.warpCliPath, "status"]

        stdout: StdioCollector {
            id: warpStatusCollector
            onStreamFinished: {
                const out = warpStatusCollector.text
                if (out.length > 0 || out.includes("Unable")) {
                    root.available = true
                }

                if (out.includes("Unable to connect")) {
                    root._daemonRunning = false
                    root.toggled = false
                    return;
                }

                root._daemonRunning = true
                if (out.includes("Unable")) {
                    registrationProc.running = true
                } else if (out.includes("Connected")) {
                    root.toggled = true
                } else if (out.includes("Disconnected")) {
                    root.toggled = false
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            // If warp-cli doesn't exist, process fails silently
            // Disable toggle in that case
            if (exitCode !== 0) {
                root.available = false
                root._daemonRunning = false
            }
        }
    }

    Process {
        id: startServiceProc
        command: ["/usr/bin/systemctl", "start", "warp-svc.service"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([root.notifySendPath,
                    Translation.tr("Cloudflare WARP"),
                    Translation.tr("Failed to start warp-svc. You may need to run: <tt>sudo systemctl start warp-svc</tt>"),
                    "-a", "Shell"
                ])
            }
            root.refreshStatus();
        }
    }
    tooltipText: Translation.tr("Cloudflare WARP (1.1.1.1)")

    Component.onCompleted: root.refreshStatus()
}
