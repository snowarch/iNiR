import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Io
import Quickshell

QuickToggleButton {
    id: root

    readonly property string warpCliPath: "/usr/bin/warp-cli"
    readonly property string notifySendPath: "/usr/bin/notify-send"

    property bool _daemonRunning: true

    toggled: false
    visible: false

    function refreshStatus() {
        fetchActiveState.running = false;
        fetchActiveState.running = true;
    }

    altAction: () => {
        startServiceProc.running = true;
    }
    
    contentItem: Item {
        CustomIcon {
            id: distroIcon
            source: 'cloudflare-dns-symbolic'
            anchors.centerIn: parent
            width: 16
            height: 16
            colorize: true
            color: root.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1

            Behavior on color {
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }

    onClicked: {
        if (!root._daemonRunning) {
            startServiceProc.running = true;
            return;
        }
        if (toggled) disconnectProc.running = true;
        else connectProc.running = true;
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
        command: ["/bin/sh", "-c", root.warpCliPath + " status"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.visible = true
            }
        }
        stdout: StdioCollector {
            id: warpStatusCollector
            onStreamFinished: {
                const out = warpStatusCollector.text

                if (out.length > 0 || out.includes("Unable")) {
                    root.visible = true
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
    Timer {
        id: warpPollTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
    StyledToolTip {
        text: Translation.tr("Cloudflare WARP (1.1.1.1)")
    }
}
