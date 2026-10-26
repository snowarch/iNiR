import qs
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

    readonly property string warpCliPath: "warp-cli"
    readonly property string notifySendPath: "notify-send"

    available: false
    toggled: false
    icon: "cloud_lock"
    statusText: root._daemonRunning ? "" : Translation.tr("Daemon not running")
    hasStatusText: true

    property bool _daemonRunning: true
    property int _transitionPollsRemaining: 0
    property bool _transitionExpectedConnected: false

    function refreshStatus() {
        fetchActiveState.running = false;
        fetchActiveState.running = true;
    }

    function beginTransitionPoll(expectedConnected: bool): void {
        root._transitionExpectedConnected = expectedConnected
        root._transitionPollsRemaining = 10
        root.refreshStatus()
        transitionPollTimer.restart()
    }

    function noteObservedState(connected: bool): void {
        root.toggled = connected
        if (root._transitionPollsRemaining > 0 && connected === root._transitionExpectedConnected) {
            root._transitionPollsRemaining = 0
            transitionPollTimer.stop()
        }
    }

    function showServiceInstructions() {
        Quickshell.execDetached([root.notifySendPath, Translation.tr("Cloudflare WARP"), Translation.tr("The WARP daemon is stopped. Start warp-svc with your system service manager, then retry."), "-a", "Shell"])
    }

    mainAction: () => {
        if (!root._daemonRunning) {
            root.showServiceInstructions();
            return;
        }
        if (toggled) disconnectProc.running = true;
        else connectProc.running = true;
    }

    altAction: () => {
        root.showServiceInstructions();
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
                root.refreshStatus();
                return;
            }
            root.beginTransitionPoll(false)
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
                root.refreshStatus();
                return;
            }
            root.beginTransitionPoll(true)
        }
    }

    Process {
        id: fetchActiveState
        running: false
        command: ["/bin/sh", "-c", root.warpCliPath + " status"]

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
                    root._transitionPollsRemaining = 0
                    transitionPollTimer.stop()
                    return;
                }

                root._daemonRunning = true
                if (out.includes("Connected")) {
                    root.noteObservedState(true)
                } else if (out.includes("Disconnected")) {
                    root.noteObservedState(false)
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            // If warp-cli doesn't exist, process fails silently
            // Disable toggle in that case
            if (exitCode !== 0) {
                root.available = false
                root._daemonRunning = false
                root._transitionPollsRemaining = 0
                transitionPollTimer.stop()
            }
        }
    }

    tooltipText: Translation.tr("Cloudflare WARP (1.1.1.1)")

    Timer {
        id: warpPollTimer
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.available && (GlobalStates.sidebarRightOpen || GlobalStates.familyQuickSettingsOpen)
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: transitionPollTimer
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            if (root._transitionPollsRemaining <= 1) {
                root._transitionPollsRemaining = 0
                transitionPollTimer.stop()
                root.refreshStatus()
                return
            }
            root._transitionPollsRemaining -= 1
            root.refreshStatus()
        }
    }

    Component.onCompleted: root.refreshStatus()
}
