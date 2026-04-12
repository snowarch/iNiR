pragma ComponentBehavior: Bound

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
            startProc.exec(["nmcli", "dev", "wifi", "hotspot",
                "con-name", "Hotspot",
                "ssid", ssid,
                "band", band,
                "password", password])
        }
    }

    // Check if the "Hotspot" NM connection is currently active
    Process {
        id: checkStatus
        running: false
        command: ["nmcli", "c", "show", "--active", "Hotspot"]
        onExited: (exitCode, exitStatus) => {
            root.toggled = (exitCode === 0)
        }
    }

    // Start hotspot — command built dynamically via exec()
    Process {
        id: startProc
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([
                    "/usr/bin/notify-send",
                    Translation.tr("Hotspot"),
                    Translation.tr("Failed to start hotspot. Ensure your Wi-Fi adapter supports AP mode."),
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
        onExited: (exitCode, exitStatus) => {
            root.refreshStatus()
        }
    }

    // Periodic poll — NM may change state externally (e.g. another NM client)
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
}
