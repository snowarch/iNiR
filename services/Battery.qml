pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // `inir battery simulate "14 charging"` stands in for UPower until `off` or a restart, so every family's battery
    // surface can be seen on a machine without one. It never suspends the real machine.
    property real simulatedPercentage: -1 // 0..1 while simulating
    property string simulatedState: "discharging" // charging, discharging, full
    readonly property bool simulating: simulatedPercentage >= 0

    property bool available: simulating || UPower.displayDevice.isLaptopBattery
    // UPower fills the display device after the shell starts; until then it reads 0 % in an unknown state.
    readonly property bool ready: simulating || (UPower.displayDevice?.ready ?? false)
    property var chargeState: !simulating ? UPower.displayDevice.state
        : simulatedState === "charging" ? UPowerDeviceState.Charging
        : simulatedState === "full" ? UPowerDeviceState.FullyCharged
        : UPowerDeviceState.Discharging
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    // On battery is UPower's own answer: a battery draining with no line power online. The pack's state alone misread a
    // charge limit: on AC a pack above its limit drains to it ("Discharging"), at it reads Full or Pending, and the shell
    // played the unplug sound, paused the wallpaper and flipped the idle profile with the charger in (11-03).
    readonly property bool onBattery: simulating ? chargeState == UPowerDeviceState.Discharging
        : available && ready && UPower.onBattery
    readonly property bool isPluggedIn: available && ready && !onBattery
    // A driver can say 0 % in an unknown state for a moment, at boot or when the charger moves (Lenovo ACPI): that
    // is no reading, and it must not raise a critical notice or suspend the machine. The last real one stands.
    property real _lastReading: 1
    readonly property real _reading: {
        const device = UPower.displayDevice
        const unread = !device || !root.ready || (device.percentage <= 0 && device.state === UPowerDeviceState.Unknown)
        return unread ? root._lastReading : device.percentage
    }
    on_ReadingChanged: root._lastReading = root._reading
    property real percentage: simulating ? simulatedPercentage : root._reading
    readonly property bool allowAutomaticSuspend: Config.options?.battery?.automaticSuspend ?? false
    readonly property bool soundEnabled: Config.options?.sounds?.battery ?? true

    property bool isLow: available && (percentage <= ((Config.options?.battery?.low ?? 20) / 100))
    property bool isCritical: available && (percentage <= ((Config.options?.battery?.critical ?? 10) / 100))
    property bool isSuspending: available && (percentage <= ((Config.options?.battery?.suspend ?? 5) / 100))
    property bool isFull: available && (percentage >= ((Config.options?.battery?.full ?? 95) / 100))

    // "Not charging" meant on battery: Unknown, Full and Pending with the charger in are not a draining pack.
    property bool isLowAndNotCharging: isLow && onBattery
    property bool isCriticalAndNotCharging: isCritical && onBattery
    property bool isSuspendingAndNotCharging: !simulating && allowAutomaticSuspend && isSuspending && onBattery
    property bool isFullAndCharging: isFull && isCharging

    // A simulated pack: 12 W over five hours, refilled at 30 W in two.
    property real energyRate: !simulating ? UPower.displayDevice.changeRate : isCharging ? 30 : onBattery ? 12 : 0
    property real timeToEmpty: !simulating ? UPower.displayDevice.timeToEmpty : onBattery ? Math.round(percentage * 18000) : 0
    property real timeToFull: !simulating ? UPower.displayDevice.timeToFull : isCharging ? Math.round((1 - percentage) * 7200) : 0

    /// The laptop battery as every family shows it. `simulate` lets you see the battery surfaces on a machine without
    /// one.
    IpcHandler {
        target: "battery"

        /// Print the level and whether it is charging, discharging or plugged in, marked `(simulated)` while
        /// simulating
        function status(): string {
            if (!root.available)
                return "no battery"
            const state = root.isCharging ? "charging" : root.onBattery ? "discharging" : "plugged in"
            return `${Math.round(root.percentage * 100)}% ${state}${root.simulating ? " (simulated)" : ""}`
        }

        // "14", "14 charging", "full" or "off"; a level alone is discharging.
        /// Pretend the battery is at a level and state until the shell restarts: `14`, `"14 charging"`, `full` or
        /// `off`. Never suspends the machine. For testing
        function simulate(spec: string): string {
            const words = String(spec ?? "").trim().toLowerCase().split(/[\s:]+/).filter(w => w.length > 0)
            if (words.length === 0 || words[0] === "off") {
                root.simulatedPercentage = -1
                return status()
            }
            const level = words.find(w => /^\d+(\.\d+)?%?$/.test(w))
            const state = words.find(w => w === "charging" || w === "discharging" || w === "full") ?? "discharging"
            // The level first: a notice raised by the state change reads the new level.
            root.simulatedPercentage = state === "full" && level === undefined ? 1
                : Math.max(0, Math.min(100, parseFloat(level ?? "50"))) / 100
            root.simulatedState = state
            return status()
        }
    }

    // ─── Charge limit ───
    readonly property bool chargeLimitEnabled: Config.options?.battery?.chargeLimit?.enable ?? false
    readonly property int chargeLimitThreshold: Config.options?.battery?.chargeLimit?.threshold ?? 80
    property string _chargeLimitBackend: ""
    property string _chargeLimitSysfsPath: ""
    property int _rawChargeLimitValue: -1
    property int _pendingChargeLimitAction: -1 // -1 none, 0 disable, 1 enable
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
                    _log("[Battery] Charge limit backend: " + root._chargeLimitBackend + " (" + root._chargeLimitSysfsPath + ")")
                    root._readChargeLimit()
                }
            }
        }
    }

    // Reconcile only after the initial sysfs read. This avoids asking polkit to
    // write a value the firmware already has.
    Timer {
        id: chargeLimitApplyDelay
        interval: 250
        repeat: false
        onTriggered: {
            if (root.chargeLimitEnabled)
                root._applyChargeLimit()
        }
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

    function _desiredChargeLimitValue(enable: bool): int {
        switch (_chargeLimitBackend) {
        case "ideapad":
        case "samsung":
            return enable ? 1 : 0
        case "lg-legacy":
            return enable ? 80 : 100
        default:
            return enable ? _normalizedChargeLimitThreshold() : 100
        }
    }

    function _chargeLimitMatches(enable: bool): bool {
        return _rawChargeLimitValue >= 0
            && _rawChargeLimitValue === _desiredChargeLimitValue(enable)
    }

    function _buildChargeLimitWriteCommand(enable: bool) {
        switch (_chargeLimitBackend) {
        case "ideapad":
        case "samsung":
            return [
                "pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "lg-legacy":
            return [
                "pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "huawei":
            return [
                "pkexec", "/bin/sh", "-c",
                "printf '%s %s' \"$1\" \"$2\" > \"$3\"",
                "battery-charge-limit",
                "0",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "threshold":
        case "smapi":
        case "sony":
            return [
                "pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
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
                    const initialRead = root._rawChargeLimitValue < 0
                    root._rawChargeLimitValue = val
                    root._updateChargeLimitState(val)
                    const pendingAction = root._pendingChargeLimitAction
                    if (pendingAction >= 0) {
                        root._pendingChargeLimitAction = -1
                        Qt.callLater(() => {
                            if (pendingAction === 1)
                                root._applyChargeLimit()
                            else
                                root._resetChargeLimit()
                        })
                    } else if (initialRead && root.chargeLimitEnabled) {
                        chargeLimitApplyDelay.restart()
                    }
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
        if (!chargeLimitSupported) return
        if (chargeLimitWriter.running || chargeLimitResetter.running) {
            _pendingChargeLimitAction = 1
            return
        }
        if (_rawChargeLimitValue < 0) {
            _pendingChargeLimitAction = 1
            _readChargeLimit()
            return
        }
        if (_chargeLimitMatches(true)) {
            _pendingChargeLimitAction = -1
            _log("[Battery] Charge limit already applied")
            return
        }
        _pendingChargeLimitAction = -1
        const command = _buildChargeLimitWriteCommand(true)
        if (command.length === 0) return
        chargeLimitWriter.command = command
        chargeLimitWriter.running = true
    }

    function _resetChargeLimit(): void {
        if (!chargeLimitSupported) return
        if (chargeLimitWriter.running || chargeLimitResetter.running) {
            _pendingChargeLimitAction = 0
            return
        }
        if (_rawChargeLimitValue < 0) {
            _pendingChargeLimitAction = 0
            _readChargeLimit()
            return
        }
        if (_chargeLimitMatches(false)) {
            _pendingChargeLimitAction = -1
            _log("[Battery] Charge limit already removed")
            return
        }
        _pendingChargeLimitAction = -1
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
                _log("[Battery] Charge limit applied")
            } else {
                root._pendingChargeLimitAction = -1
                console.warn("[Battery] Failed to set charge limit (exit code " + exitCode + ")")
            }
        }
    }

    Process {
        id: chargeLimitResetter
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._readChargeLimit()
                _log("[Battery] Charge limit removed")
            } else {
                root._pendingChargeLimitAction = -1
                console.warn("[Battery] Failed to reset charge limit (exit code " + exitCode + ")")
            }
        }
    }

    onChargeLimitEnabledChanged: {
        if (!chargeLimitSupported) return
        chargeLimitApplyDelay.stop()
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
    // UPower sends level and state apart, and a charger moving can read low for a moment: a notice waits until the
    // reading has held, suspend longer, and the plug sounds only start once the first real state is in
    // (cam's #321, 11-03).
    Timer {
        id: lowSettle
        interval: 2000
        onTriggered: {
            if (!root.isLowAndNotCharging || root.isCriticalAndNotCharging) return
            Quickshell.execDetached([
                "notify-send",
                Translation.tr("Low battery"),
                Translation.tr("Consider plugging in your device"),
                "-u", "critical",
                "-a", "Shell",
                "--hint=int:transient:1",
            ])
            if (root.soundEnabled) Audio.playEvent("batteryLow")
        }
    }
    onIsLowAndNotChargingChanged: isLowAndNotCharging ? lowSettle.restart() : lowSettle.stop()

    Timer {
        id: criticalSettle
        interval: 2000
        onTriggered: {
            if (!root.isCriticalAndNotCharging) return
            Quickshell.execDetached([
                "notify-send",
                Translation.tr("Critically low battery"),
                Translation.tr("Please charge!\nAutomatic suspend triggers at %1%").arg(Config.options?.battery?.suspend ?? 5),
                "-u", "critical",
                "-a", "Shell",
                "--hint=int:transient:1",
            ])
            if (root.soundEnabled) Audio.playEvent("batteryCritical")
        }
    }
    onIsCriticalAndNotChargingChanged: isCriticalAndNotCharging ? criticalSettle.restart() : criticalSettle.stop()

    Timer {
        id: suspendSettle
        interval: 5000
        onTriggered: if (root.isSuspendingAndNotCharging) Session.suspend()
    }
    onIsSuspendingAndNotChargingChanged: isSuspendingAndNotCharging ? suspendSettle.restart() : suspendSettle.stop()

    // The first state UPower delivers is no plug or unplug.
    property bool _powerSoundsArmed: false
    Timer {
        id: powerSoundsArm
        interval: 1500
        running: root.ready
        onTriggered: root._powerSoundsArmed = true
    }

    onIsFullAndChargingChanged: {
        if (!root.available || !root._powerSoundsArmed || !isFullAndCharging) return;
        Quickshell.execDetached([
            "notify-send",
            Translation.tr("Battery full"),
            Translation.tr("Please unplug the charger"),
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playEvent("batteryFull");
    }

    onIsPluggedInChanged: {
        if (!root.available || !root._powerSoundsArmed || !root.soundEnabled) return;
        if (isPluggedIn) {
            Audio.playEvent("powerPlug")
        } else {
            Audio.playEvent("powerUnplug")
        }
    }
}
