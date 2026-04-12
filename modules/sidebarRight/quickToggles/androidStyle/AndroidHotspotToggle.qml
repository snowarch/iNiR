pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Hotspot")
    statusText: root.toggled
        ? (Config.options?.hotspot?.ssid ?? "iNiR Hotspot")
        : Translation.tr("Off")

    toggled: false
    buttonIcon: "wifi_tethering"

    function refreshStatus(): void {
        checkStatus.running = false
        checkStatus.running = true
    }

    altAction: () => root.openMenu()

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

    Process {
        id: checkStatus
        running: false
        command: ["nmcli", "c", "show", "--active", "Hotspot"]
        onExited: (exitCode, exitStatus) => {
            root.toggled = (exitCode === 0)
        }
    }

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

    Process {
        id: stopProc
        running: false
        command: ["nmcli", "connection", "down", "Hotspot"]
        onExited: (exitCode, exitStatus) => {
            root.refreshStatus()
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()

    StyledToolTip {
        text: Translation.tr("Personal Wi-Fi Hotspot")
    }
}
