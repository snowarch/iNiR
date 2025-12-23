pragma Singleton

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io

Singleton {
    id: root
    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: Config.options?.battery?.automaticSuspend ?? false
    readonly property bool soundEnabled: Config.options?.sounds?.battery ?? true

    property bool isLow: available && (percentage <= ((Config.options?.battery?.low ?? 20) / 100))
    property bool isCritical: available && (percentage <= ((Config.options?.battery?.critical ?? 10) / 100))
    property bool isSuspending: available && (percentage <= ((Config.options?.battery?.suspend ?? 5) / 100))
    property bool isFull: available && (percentage >= ((Config.options?.battery?.full ?? 95) / 100))

    property bool isLowAndNotCharging: isLow && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging
    property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && !isCharging
    property bool isFullAndCharging: isFull && isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    onIsLowAndNotChargingChanged: {
        if (!root.available || !isLowAndNotCharging) return;
        Quickshell.execDetached([
            "/usr/bin/notify-send", 
            Translation.tr("Low battery"), 
            Translation.tr("Consider plugging in your device"), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ])

        if (root.soundEnabled) Audio.playSystemSound("dialog-warning");
    }

    onIsCriticalAndNotChargingChanged: {
        if (!root.available || !isCriticalAndNotCharging) return;
        Quickshell.execDetached([
            "/usr/bin/notify-send", 
            Translation.tr("Critically low battery"), 
            Translation.tr("Please charge!\nAutomatic suspend triggers at %1%").arg(Config.options?.battery?.suspend ?? 5), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playSystemSound("suspend-error");
    }

    onIsSuspendingAndNotChargingChanged: {
        if (root.available && isSuspendingAndNotCharging) {
            if (!suspendSystemctl.running && !suspendLoginctl.running) {
                suspendSystemctl.running = true
            }
        }
    }

    Process {
        id: suspendSystemctl
        command: ["/usr/bin/systemctl", "suspend"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                suspendLoginctl.running = true
            }
        }
    }

    Process {
        id: suspendLoginctl
        command: ["/usr/bin/loginctl", "suspend"]
    }

    onIsFullAndChargingChanged: {
        if (!root.available || !isFullAndCharging) return;
        Quickshell.execDetached([
            "/usr/bin/notify-send",
            Translation.tr("Battery full"),
            Translation.tr("Please unplug the charger"),
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playSystemSound("complete");
    }

    onIsPluggedInChanged: {
        if (!root.available || !root.soundEnabled) return;
        if (isPluggedIn) {
            Audio.playSystemSound("power-plug")
        } else {
            Audio.playSystemSound("power-unplug")
        }
    }
}
