pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.quickToggles
import QtQuick
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root

    toggled: false
    buttonIcon: "wifi_tethering"

    function refreshStatus(): void {
        checkStatus.running = false
        checkStatus.running = true
    }

    onClicked: {
        if (root.toggled) {
            stopProc.running = true
        } else {
            const ssid = Config.options?.hotspot?.ssid ?? "iNiR Hotspot"
            const password = Config.options?.hotspot?.password ?? "inirhotspot"
            const band = Config.options?.hotspot?.band ?? "bg"
            startProc.exec(["/bin/sh", "-c",
                'nmcli connection delete id Hotspot 2>/dev/null; exec nmcli dev wifi hotspot con-name Hotspot ssid "$1" band "$2" password "$3"',
                "sh", ssid, band, password])
        }
    }

    Process {
        id: checkStatus
        running: false
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"]

        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: {
                const out = statusCollector.text?.trim() ?? ""
                if (out.length === 0) {
                    root.toggled = false
                    return
                }
                const lines = out.split("\n")
                root.toggled = lines.some(line => line.trim() === "Hotspot")
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.toggled = false
        }
    }

    Process {
        id: startProc
        running: false

        stderr: StdioCollector {
            id: startErrCollector
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const errMsg = (startErrCollector.text?.trim() ?? "")
                Quickshell.execDetached([
                    "/usr/bin/notify-send",
                    Translation.tr("Hotspot"),
                    errMsg.length > 0
                        ? errMsg
                        : Translation.tr("Failed to start hotspot. Ensure your Wi-Fi adapter supports AP mode."),
                    "-a", "iNiR"
                ])
            }
            root.refreshStatus()
        }
    }

    Process {
        id: stopProc
        running: false
        command: ["nmcli", "connection", "down", "Hotspot"]

        stderr: StdioCollector {
            id: stopErrCollector
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const errMsg = (stopErrCollector.text?.trim() ?? "")
                Quickshell.execDetached([
                    "/usr/bin/notify-send",
                    Translation.tr("Hotspot"),
                    errMsg.length > 0
                        ? errMsg
                        : Translation.tr("Failed to stop hotspot."),
                    "-a", "iNiR"
                ])
            }
            root.refreshStatus()
        }
    }

    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: GlobalStates.sidebarRightOpen
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()

    StyledToolTip {
        text: Translation.tr("Hotspot: %1").arg(Config.options?.hotspot?.ssid ?? "iNiR Hotspot")
    }
}
