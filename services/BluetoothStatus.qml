pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

/**
 * Bluetooth status service.
 */
Singleton {
    id: root

    // `inir bluetooth simulate 2` stands in for the adapter (`off`, `on`, a count of connected devices, `none` for no
    // adapter) until `clear` or a restart, so every Bluetooth surface can be seen without the hardware.
    property string simulated: ""
    readonly property int _simulatedCount: /^\d+$/.test(root.simulated) ? parseInt(root.simulated) : 0
    readonly property bool available: root.simulated.length > 0 ? root.simulated !== "none" : Bluetooth.adapters.values.length > 0
    readonly property bool enabled: root.simulated.length > 0 ? (root.simulated === "on" || /^\d+$/.test(root.simulated))
        : Bluetooth.defaultAdapter?.enabled ?? false
    readonly property BluetoothDevice firstActiveDevice: root.simulated.length > 0 ? null
        : Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: root.simulated.length > 0 ? root._simulatedCount
        : Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: root.simulated.length > 0 ? root._simulatedCount > 0 : Bluetooth.devices.values.some(d => d.connected)

    /// The Bluetooth adapter as every family shows it. `simulate` lets you see the Bluetooth surfaces without the
    /// hardware.
    IpcHandler {
        target: "bluetooth"

        /// Print `on`, `off`, `no adapter` or how many devices are connected, marked `(simulated)` while simulating
        function status(): string {
            const state = !root.available ? "no adapter" : !root.enabled ? "off"
                : root.activeDeviceCount > 0 ? `${root.activeDeviceCount} connected` : "on"
            return state + (root.simulated.length > 0 ? " (simulated)" : "")
        }
        // "off", "on", a count of connected devices ("2"), "none" (no adapter) or "clear".
        /// Pretend the adapter is `off`, `on`, has a number of connected devices (`2`) or is missing (`none`) until
        /// `clear` or a restart. For testing
        function simulate(state: string): string {
            const s = String(state ?? "").trim().toLowerCase()
            root.simulated = ["off", "on", "none"].includes(s) || /^\d+$/.test(s) ? s : ""
            return status()
        }
    }

    // Material Symbol icon for the currently-active device, or generic bluetooth
    // states when no device is connected. Uses BluetoothDevice.icon (XDG icon
    // name like "audio-headset", "input-keyboard") to pick a device-specific
    // glyph so the bar reflects what's actually connected.
    readonly property string activeIcon: {
        if (!root.enabled) return "bluetooth_disabled";
        if (!root.connected) return "bluetooth";
        return root._materialIconForDevice(root.firstActiveDevice);
    }

    function activeDeviceSummary(includeAdditionalCount = false): string {
        const device = root.firstActiveDevice;
        if (!device) return "";
        let summary = device.name || Translation.tr("Unknown device");
        if (device.batteryAvailable)
            summary += ` (${Math.round(device.battery * 100)}%)`;
        if (includeAdditionalCount && root.activeDeviceCount > 1)
            summary += ` +${root.activeDeviceCount - 1}`;
        return summary;
    }

    function connectionTooltip(): string {
        if (!root.enabled) return Translation.tr("Bluetooth is disabled");
        if (!root.connected) return Translation.tr("Bluetooth disconnected");
        return root.activeDeviceSummary() || Translation.tr("Bluetooth connected");
    }

    function iconForDevice(device: BluetoothDevice): string {
        return root._materialIconForDevice(device);
    }

    function _materialIconForDevice(device: BluetoothDevice): string {
        const xdg = (device?.icon ?? "").toLowerCase();
        if (xdg.length === 0) return "bluetooth_connected";
        if (xdg.includes("headset") || xdg.includes("headphone")) return "headphones";
        if (xdg.includes("audio-card") || xdg.includes("speaker")) return "speaker";
        if (xdg.includes("audio")) return "speaker";
        if (xdg.includes("keyboard")) return "keyboard";
        if (xdg.includes("mouse") || xdg.includes("pointer")) return "mouse";
        if (xdg.includes("phone")) return "smartphone";
        if (xdg.includes("watch")) return "watch";
        if (xdg.includes("camera")) return "photo_camera";
        if (xdg.includes("printer")) return "print";
        if (xdg.includes("scanner")) return "scanner";
        if (xdg.includes("gamepad") || xdg.includes("joystick") || xdg.includes("input-gaming")) return "sports_esports";
        if (xdg.includes("computer") || xdg.includes("laptop")) return "laptop";
        if (xdg.includes("tablet")) return "tablet";
        if (xdg.includes("tv") || xdg.includes("video")) return "tv";
        return "bluetooth_connected";
    }
}
