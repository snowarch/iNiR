pragma ComponentBehavior: Bound

import qs
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

/**
 * QuickToggleModel for WiFi Hotspot via NetworkManager (nmcli).
 *
 * Creates/activates a connection named "Hotspot" using the user's configured
 * SSID, password, and band. Deactivating brings the connection down.
 *
 * Before starting, any stale "Hotspot" connection is deleted to avoid
 * phantom-active profiles that NM thinks are active but aren't broadcasting.
 *
 * Status is verified by parsing the active connection list, not just exit codes.
 *
 * Config keys read:
 *   hotspot.ssid     — broadcast network name (default: "iNiR Hotspot")
 *   hotspot.password — WPA2 passphrase        (default: "inirhotspot")
 *   hotspot.band     — "bg" (2.4GHz) or "a" (5GHz) (default: "bg")
 */
QuickToggleModel {
    id: root

    name: Translation.tr("Hotspot")
    icon: "wifi_tethering"
    toggled: false
    available: true
    hasMenu: true
    hasStatusText: true
    statusText: root.toggled
        ? (Config.options?.hotspot?.ssid ?? "iNiR Hotspot")
        : Translation.tr("Off")

    tooltipText: Translation.tr("Personal Wi-Fi Hotspot")

    function refreshStatus(): void {
        checkStatus.running = false
        checkStatus.running = true
    }

    mainAction: () => {
        if (root.toggled) {
            stopProc.running = true
        } else {
            const ssid = Config.options?.hotspot?.ssid ?? "iNiR Hotspot"
            const password = Config.options?.hotspot?.password ?? "inirhotspot"
            const band = Config.options?.hotspot?.band ?? "bg"
            // Delete any stale "Hotspot" profile first, then create fresh.
            // Uses sh positional params to safely pass user-configured values.
            startProc.exec(["/bin/sh", "-c",
                'nmcli connection delete id Hotspot 2>/dev/null; exec nmcli dev wifi hotspot con-name Hotspot ssid "$1" band "$2" password "$3"',
                "sh", ssid, band, password])
        }
    }

    // Parse active connection list to determine if "Hotspot" is truly active.
    // More reliable than `nmcli c show --active Hotspot` which can give
    // false positives from stale profiles on some NM versions.
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

    // Start hotspot — cleanup stale connection then create fresh
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

    // Stop hotspot
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

    // Periodic poll — NM may change state externally (e.g. another NM client)
    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: GlobalStates.sidebarRightOpen || GlobalStates.waffleActionCenterOpen
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
}
