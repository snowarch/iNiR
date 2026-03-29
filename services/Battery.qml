pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.modules.common
import qs.services

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

    // ─── Charge limit ───
    readonly property bool chargeLimitEnabled: Config.options?.battery?.chargeLimit?.enable ?? false
    readonly property int chargeLimitThreshold: Config.options?.battery?.chargeLimit?.threshold ?? 80
    property string _chargeLimitBackend: ""
    property string _chargeLimitSysfsPath: ""
    property int _currentChargeLimit: -1
    property bool _chargeLimitActive: false
    readonly property bool chargeLimitSupported: _chargeLimitBackend.length > 0 && _chargeLimitSysfsPath.length > 0
    readonly property bool chargeLimitAdjustable: _chargeLimitBackend === "threshold"
        || _chargeLimitBackend === "smapi"
        || _chargeLimitBackend === "sony"
        || _chargeLimitBackend === "huawei"
    readonly property bool chargeLimitActive: _chargeLimitActive
    readonly property int currentChargeLimit: _currentChargeLimit

    Component.onCompleted: {
        if (root.available) {
            _detectChargeLimitPath()
        }
    }

    onAvailableChanged: {
        if (available && _chargeLimitSysfsPath.length === 0) {
            _detectChargeLimitPath()
        }
    }

    function _detectChargeLimitPath(): void {
        if (!chargeLimitDetector.running) {
            chargeLimitDetector.running = true
        }
    }

    Process {
        id: chargeLimitDetector
        command: ["/bin/sh", "-c",
            "for dir in /sys/class/power_supply/*; do " +
            "[ -d \"$dir\" ] || continue; " +
            "[ \"$(cat \"$dir/type\" 2>/dev/null)\" = \"Battery\" ] || continue; " +
            "if [ -f \"$dir/present\" ] && [ \"$(cat \"$dir/present\" 2>/dev/null)\" = \"0\" ]; then continue; fi; " +
            "for attr in charge_control_end_threshold charge_stop_threshold; do " +
            "[ -f \"$dir/$attr\" ] && printf 'threshold|%s\\n' \"$dir/$attr\" && exit 0; " +
            "done; " +
            "done; " +
            "for p in /sys/devices/platform/smapi/BAT*/stop_charge_thresh; do [ -f \"$p\" ] && printf 'smapi|%s\\n' \"$p\" && exit 0; done; " +
            "for p in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do [ -f \"$p\" ] && printf 'ideapad|%s\\n' \"$p\" && exit 0; done; " +
            "[ -f /sys/devices/platform/lg-laptop/battery_care_limit ] && printf 'lg-legacy|%s\\n' /sys/devices/platform/lg-laptop/battery_care_limit && exit 0; " +
            "[ -f /sys/devices/platform/samsung/battery_life_extender ] && printf 'samsung|%s\\n' /sys/devices/platform/samsung/battery_life_extender && exit 0; " +
            "[ -f /sys/devices/platform/sony-laptop/battery_care_limiter ] && printf 'sony|%s\\n' /sys/devices/platform/sony-laptop/battery_care_limiter && exit 0; " +
            "[ -f /sys/devices/platform/huawei-wmi/charge_control_thresholds ] && printf 'huawei|%s\\n' /sys/devices/platform/huawei-wmi/charge_control_thresholds && exit 0; " +
            "printf '\\n'"
        ]
        stdout: SplitParser {
            onRead: data => {
                const result = data.trim()
                if (result.length > 0) {
                    const parts = result.split("|")
                    root._chargeLimitBackend = parts[0] ?? ""
                    root._chargeLimitSysfsPath = parts[1] ?? ""
                    console.log("[Battery] Charge limit backend: " + root._chargeLimitBackend + " (" + root._chargeLimitSysfsPath + ")")
                    root._readChargeLimit()
                    if (root.chargeLimitEnabled) {
                        chargeLimitApplyDelay.restart()
                    }
                }
            }
        }
    }

    // Small delay before applying on startup so the shell is settled
    Timer {
        id: chargeLimitApplyDelay
        interval: 2000
        repeat: false
        onTriggered: root._applyChargeLimit()
    }

    function _readChargeLimit(): void {
        if (_chargeLimitSysfsPath.length === 0 || chargeLimitReader.running) return
        chargeLimitReader.command = ["/bin/cat", _chargeLimitSysfsPath]
        chargeLimitReader.running = true
    }

    function _updateChargeLimitState(rawValue: int): void {
        switch (_chargeLimitBackend) {
        case "ideapad":
            _chargeLimitActive = rawValue === 1
            _currentChargeLimit = rawValue === 0 ? 100 : -1
            break
        case "samsung":
            _chargeLimitActive = rawValue === 1
            _currentChargeLimit = rawValue === 1 ? 80 : 100
            break
        default:
            _chargeLimitActive = rawValue > 0 && rawValue < 100
            _currentChargeLimit = rawValue
            break
        }
    }

    function _normalizedChargeLimitThreshold(): int {
        if (_chargeLimitBackend === "sony") {
            if (chargeLimitThreshold <= 65) return 50
            if (chargeLimitThreshold <= 90) return 80
            return 100
        }

        return chargeLimitThreshold
    }

    function _buildChargeLimitWriteCommand(enable: bool) {
        switch (_chargeLimitBackend) {
        case "ideapad":
        case "samsung":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                enable ? "1" : "0",
                _chargeLimitSysfsPath,
            ]
        case "lg-legacy":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                enable ? "80" : "100",
                _chargeLimitSysfsPath,
            ]
        case "huawei":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s %s' \"$1\" \"$2\" > \"$3\"",
                "battery-charge-limit",
                "0",
                enable ? String(_normalizedChargeLimitThreshold()) : "100",
                _chargeLimitSysfsPath,
            ]
        case "threshold":
        case "smapi":
        case "sony":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                enable ? String(_normalizedChargeLimitThreshold()) : "100",
                _chargeLimitSysfsPath,
            ]
        default:
            return []
        }
    }

    Process {
        id: chargeLimitReader
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                const val = _chargeLimitBackend === "huawei"
                    ? parseInt(trimmed.split(/\s+/).slice(-1)[0])
                    : parseInt(trimmed)

                if (!isNaN(val)) {
                    root._updateChargeLimitState(val)
                }
            }
        }
    }

    // Periodically re-read the threshold so the UI stays in sync
    Timer {
        id: chargeLimitPoll
        interval: 30000
        repeat: true
        running: root.chargeLimitSupported
        onTriggered: root._readChargeLimit()
    }

    function _applyChargeLimit(): void {
        if (!chargeLimitSupported || chargeLimitWriter.running) return
        const command = _buildChargeLimitWriteCommand(true)
        if (command.length === 0) return
        chargeLimitWriter.command = command
        chargeLimitWriter.running = true
    }

    function _resetChargeLimit(): void {
        if (!chargeLimitSupported || chargeLimitResetter.running) return
        const command = _buildChargeLimitWriteCommand(false)
        if (command.length === 0) return
        chargeLimitResetter.command = command
        chargeLimitResetter.running = true
    }

    Process {
        id: chargeLimitWriter
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._readChargeLimit()
                console.log("[Battery] Charge limit applied")
            } else {
                console.warn("[Battery] Failed to set charge limit (exit code " + exitCode + ")")
            }
        }
    }

    Process {
        id: chargeLimitResetter
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._readChargeLimit()
                console.log("[Battery] Charge limit removed")
            } else {
                console.warn("[Battery] Failed to reset charge limit (exit code " + exitCode + ")")
            }
        }
    }

    onChargeLimitEnabledChanged: {
        if (!chargeLimitSupported) return
        if (chargeLimitEnabled) {
            _applyChargeLimit()
        } else {
            _resetChargeLimit()
        }
    }

    onChargeLimitThresholdChanged: {
        if (!chargeLimitSupported || !chargeLimitEnabled || !chargeLimitAdjustable) return
        _applyChargeLimit()
    }

    // ─── Battery warnings ───
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
