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

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)

    // Material Symbol icon for the currently-active device, or generic bluetooth
    // states when no device is connected. Uses BluetoothDevice.icon (XDG icon
    // name like "audio-headset", "input-keyboard") to pick a device-specific
    // glyph so the bar reflects what's actually connected.
    readonly property string activeIcon: {
        if (!root.enabled) return "bluetooth_disabled";
        if (!root.connected) return "bluetooth";
        return root._materialIconForDevice(root.firstActiveDevice);
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
