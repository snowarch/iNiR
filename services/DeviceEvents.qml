pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.modules.common
import qs.services

/**
 * Things that were just plugged in, connected, unplugged or lost: networks, the internet,
 * Bluetooth and USB devices, the charger, the audio output, displays and removable drives.
 * One event at a time; every family presents it in its own OSD.
 */
Singleton {
    id: root

    readonly property var prefs: Config.options?.osd?.connections
    readonly property bool enabled: root.prefs?.enable ?? true
    readonly property var kinds: ["network", "internet", "bluetooth", "usb", "power", "audio", "displays", "drives"]

    // { kind, tone: "on" | "off" | "warn", icon, fluentIcon, title, detail, value }
    property var last: null
    property int sequence: 0
    signal happened(var event)

    function allows(kind: string): bool {
        return root.enabled && (root.prefs?.[kind] ?? true)
    }

    function publish(event: var): void {
        if (!root.allows(event.kind)) return
        root.last = event
        root.sequence += 1
        root.happened(event)
    }

    // Plugging one thing in fires several subsystems (a headset is Bluetooth and then an audio
    // output; a cable is a link and then the internet). The first one speaks for all of them.
    property var _quietUntil: ({})
    function _hush(kinds: var, ms: int): void {
        const until = Object.assign({}, root._quietUntil)
        kinds.forEach(kind => until[kind] = Date.now() + ms)
        root._quietUntil = until
    }
    function _quiet(kind: string): bool {
        return Date.now() < (root._quietUntil[kind] ?? 0)
    }

    // Startup, resume and a shell restart report every device as new.
    property bool warm: false
    Timer { interval: 6000; running: true; onTriggered: root.warm = true }

    // ── Network link ──
    readonly property string link: Network.ethernet ? "ethernet"
        : (Network.wifiStatus === "connected" || Network.wifiStatus === "limited") ? "wifi" : ""
    property string _shownLink: ""
    property string _shownLinkName: ""
    onLinkChanged: linkSettle.restart()
    Timer {
        id: linkSettle
        interval: 1500
        onTriggered: {
            const link = root.link
            const name = Network.networkName
            if (link === root._shownLink) return
            const previous = root._shownLink
            const previousName = root._shownLinkName
            root._shownLink = link
            root._shownLinkName = name
            if (!root.warm) return
            root._hush(["internet"], 6000)
            if (link.length > 0)
                root.publish({ kind: "network", tone: "on",
                    icon: link === "ethernet" ? "lan" : "wifi", fluentIcon: link === "ethernet" ? "ethernet" : "wifi-1",
                    title: link === "ethernet" ? Translation.tr("Ethernet connected") : Translation.tr("Wi-Fi connected"),
                    detail: name, value: -1 })
            else
                root.publish({ kind: "network", tone: "off",
                    icon: previous === "ethernet" ? "lan" : "wifi_off", fluentIcon: previous === "ethernet" ? "ethernet" : "wifi-off",
                    title: previous === "ethernet" ? Translation.tr("Ethernet disconnected") : Translation.tr("Wi-Fi disconnected"),
                    detail: previousName, value: -1 })
        }
    }

    // ── Internet ──
    property bool _shownOnline: true
    Connections {
        target: Network
        function onOnlineChanged() { internetSettle.restart() }
    }
    Timer {
        id: internetSettle
        interval: 2500
        onTriggered: {
            if (Network.online === root._shownOnline) return
            root._shownOnline = Network.online
            if (!root.warm || root._quiet("internet") || root.link.length === 0) return
            root.publish(Network.online
                ? { kind: "internet", tone: "on", icon: "cloud_done", fluentIcon: "globe-search",
                    title: Translation.tr("Back online"), detail: Network.networkName, value: -1 }
                : { kind: "internet", tone: "warn", icon: "cloud_off", fluentIcon: "wifi-warning",
                    title: Network.offlineReason, detail: Network.networkName, value: -1 })
        }
    }

    // ── Bluetooth devices ──
    Instantiator {
        model: Bluetooth.devices
        delegate: QtObject {
            required property BluetoothDevice modelData
            readonly property bool connected: modelData?.connected ?? false
            onConnectedChanged: root._bluetooth(modelData, connected)
        }
    }
    function _bluetooth(device: BluetoothDevice, connected: bool): void {
        if (!root.warm || !device) return
        root._hush(["audio"], 4000)
        root.publish({ kind: "bluetooth", tone: connected ? "on" : "off",
            icon: connected ? BluetoothStatus.iconForDevice(device) : "bluetooth_disabled",
            fluentIcon: connected ? "bluetooth-connected" : "bluetooth-disabled",
            title: String(device.name || Translation.tr("Bluetooth device")),
            detail: connected ? Translation.tr("Connected") : Translation.tr("Disconnected"),
            value: connected && device.batteryAvailable ? Math.round(device.battery * 100) : -1 })
    }

    // ── Charger ──
    Connections {
        target: Battery.available ? Battery : null
        function onIsPluggedInChanged() {
            if (!root.warm) return
            const plugged = Battery.isPluggedIn
            const percent = Math.round(Battery.percentage * 100)
            root.publish({ kind: "power", tone: plugged ? "on" : "off",
                icon: plugged ? "battery_charging_full" : "battery_6_bar",
                fluentIcon: plugged ? "battery-charge" : "battery-" + Math.max(0, Math.min(9, Math.floor(percent / 10))),
                title: plugged ? Translation.tr("Charging") : Translation.tr("On battery"),
                detail: plugged && Battery.timeToFull > 0 ? Translation.tr("Full in %1").arg(root.duration(Battery.timeToFull))
                    : !plugged && Battery.timeToEmpty > 0 ? Translation.tr("%1 left").arg(root.duration(Battery.timeToEmpty)) : "",
                value: percent })
        }
    }
    function duration(seconds: real): string {
        const m = Math.round(seconds / 60)
        return m >= 60 ? Translation.tr("%1 h %2 min").arg(Math.floor(m / 60)).arg(m % 60) : Translation.tr("%1 min").arg(m)
    }

    // ── Audio output ──
    readonly property string sinkName: Audio.rawSink ? String(Audio.rawSink.description || Audio.rawSink.nickname || Audio.rawSink.name || "") : ""
    property string _shownSink: ""
    onSinkNameChanged: sinkSettle.restart()
    Timer {
        id: sinkSettle
        interval: 900
        onTriggered: {
            const name = root.sinkName
            if (name.length === 0 || name === root._shownSink) return
            const first = root._shownSink.length === 0
            root._shownSink = name
            if (first || !root.warm || root._quiet("audio")) return
            const wearable = /head(phone|set)|buds|airpods|earphone/i.test(name)
            const screen = /hdmi|displayport/i.test(name)
            root.publish({ kind: "audio", tone: "on",
                icon: wearable ? "headphones" : screen ? "tv" : "speaker",
                fluentIcon: wearable ? "headphones" : screen ? "desktop-speaker" : "speaker",
                title: Translation.tr("Sound output"), detail: name, value: -1 })
        }
    }

    // ── Displays ──
    readonly property var outputNames: CompositorService.isNiri ? Object.keys(NiriService.outputs ?? {}).sort() : []
    property var _shownOutputs: null
    onOutputNamesChanged: outputSettle.restart()
    Timer {
        id: outputSettle
        interval: 1200
        onTriggered: {
            const now = root.outputNames
            const before = root._shownOutputs
            root._shownOutputs = now
            if (before === null || !root.warm) return
            const added = now.filter(name => !before.includes(name))
            const removed = before.filter(name => !now.includes(name))
            if (added.length > 0) {
                const output = NiriService.outputs[added[0]]
                root.publish({ kind: "displays", tone: "on", icon: "desktop_windows", fluentIcon: "desktop",
                    title: Translation.tr("Display connected"),
                    detail: [output?.make, output?.model].filter(part => part && part !== "Unknown").join(" ") || added[0], value: -1 })
            } else if (removed.length > 0) {
                root.publish({ kind: "displays", tone: "off", icon: "desktop_access_disabled", fluentIcon: "desktop",
                    title: Translation.tr("Display disconnected"), detail: removed[0], value: -1 })
            }
        }
    }

    // ── USB devices and removable drives (udev) ──
    readonly property var usbKinds: ({
        mouse: { label: Translation.tr("Mouse"), icon: "mouse", fluentIcon: "input-mouse-symbolic" },
        keyboard: { label: Translation.tr("Keyboard"), icon: "keyboard", fluentIcon: "keyboard" },
        controller: { label: Translation.tr("Controller"), icon: "sports_esports", fluentIcon: "games" },
        webcam: { label: Translation.tr("Camera"), icon: "videocam", fluentIcon: "video" },
        headset: { label: Translation.tr("Headset"), icon: "headset_mic", fluentIcon: "headphones" },
        audio: { label: Translation.tr("Audio device"), icon: "speaker", fluentIcon: "speaker" },
        phone: { label: Translation.tr("Phone"), icon: "smartphone", fluentIcon: "phone" },
        bluetooth: { label: Translation.tr("Bluetooth adapter"), icon: "bluetooth", fluentIcon: "bluetooth" },
        printer: { label: Translation.tr("Printer"), icon: "print", fluentIcon: "printer-symbolic" },
        smartcard: { label: Translation.tr("Card reader"), icon: "credit_card", fluentIcon: "media-flash-symbolic" },
        serial: { label: Translation.tr("Serial device"), icon: "developer_board", fluentIcon: "drive-removable-media-symbolic" },
        input: { label: Translation.tr("Input device"), icon: "keyboard_alt", fluentIcon: "keyboard" },
        device: { label: Translation.tr("USB device"), icon: "usb", fluentIcon: "drive-removable-media-symbolic" }
    })
    property bool udevAvailable: false
    property var _shownUsb: null
    property var _shownDrives: null
    // A monitor left by a previous shell instance or a reload keeps running on its own.
    Process {
        id: udevCleanup
        running: root.allows("usb") || root.allows("drives")
        command: ["pkill", "-f", "^(/usr/bin/)?udevadm monitor --udev --subsystem-match=usb/usb_device --subsystem-match=block$"]
        onExited: udevProbe.running = true
    }
    Component.onDestruction: udevMonitor.running = false
    Process {
        id: udevProbe
        command: ["sh", "-c", "command -v udevadm >/dev/null && command -v lsblk >/dev/null"]
        onExited: code => {
            root.udevAvailable = code === 0
            if (!root.udevAvailable) return
            usbRead.running = true
            drivesRead.running = true
        }
    }
    Process {
        id: udevMonitor
        running: root.udevAvailable && (root.allows("usb") || root.allows("drives"))
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: line => {
                if (!/\s(add|remove)\s/.test(line)) return
                if (/\(usb\)\s*$/.test(line)) usbSettle.restart()
                else if (/\(block\)\s*$/.test(line)) drivesSettle.restart()
            }
        }
    }
    Timer { id: usbSettle; interval: 700; onTriggered: usbRead.running = true }
    Process {
        id: usbRead
        command: ["python3", Directories.scriptsPath + "/devices/usb-snapshot.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(text).devices ?? [] } catch (e) { return }
                const now = {}
                list.forEach(device => now[device.id] = device)
                const before = root._shownUsb
                root._shownUsb = now
                if (before === null || !root.warm) return
                const added = Object.keys(now).filter(id => !(id in before)).map(id => now[id])
                const removed = Object.keys(before).filter(id => !(id in now)).map(id => before[id])
                root._announceUsb(added, true)
                root._announceUsb(removed, false)
            }
        }
    }
    function _announceUsb(devices: var, connected: bool): void {
        if (devices.length === 0) return
        // A dock, a hub or waking from sleep brings several at once: one notice for all of them.
        if (devices.length > 2) {
            root.publish({ kind: "usb", tone: connected ? "on" : "off", icon: connected ? "usb" : "usb_off", fluentIcon: "drive-removable-media-symbolic",
                title: connected ? Translation.tr("%1 USB devices connected").arg(devices.length) : Translation.tr("%1 USB devices disconnected").arg(devices.length),
                detail: devices.map(device => device.name).join(", "), value: -1 })
            return
        }
        devices.forEach(device => {
            const kind = root.usbKinds[device.kind] ?? root.usbKinds.device
            if (device.kind === "headset" || device.kind === "audio") root._hush(["audio"], 4000)
            root.publish({ kind: "usb", tone: connected ? "on" : "off",
                icon: connected ? kind.icon : (device.kind === "device" ? "usb_off" : kind.icon), fluentIcon: kind.fluentIcon,
                title: device.name || kind.label,
                detail: (connected ? Translation.tr("%1 connected") : Translation.tr("%1 disconnected")).arg(kind.label),
                value: -1 })
        })
    }

    Timer { id: drivesSettle; interval: 900; onTriggered: drivesRead.running = true }
    Process {
        id: drivesRead
        command: ["lsblk", "-J", "-b", "-o", "PATH,PKNAME,LABEL,SIZE,RM,HOTPLUG,TYPE,VENDOR,MODEL,TRAN"]
        stdout: StdioCollector {
            onStreamFinished: {
                let devices = []
                try { devices = JSON.parse(text).blockdevices ?? [] } catch (e) { return }
                const disks = {}
                devices.filter(dev => dev.type === "disk" && (dev.hotplug || dev.rm) && Number(dev.size) > 0).forEach(dev => {
                    disks[dev.path] = { size: Number(dev.size), label: "", tran: String(dev.tran ?? ""),
                        model: [String(dev.vendor ?? "").trim(), String(dev.model ?? "").trim()].filter(part => part).join(" ") }
                })
                devices.filter(dev => dev.type === "part" && dev.label).forEach(dev => {
                    const disk = disks["/dev/" + dev.pkname]
                    if (disk && disk.label.length === 0) disk.label = dev.label
                })
                const before = root._shownDrives
                root._shownDrives = disks
                if (before === null || !root.warm) return
                const added = Object.keys(disks).find(path => !(path in before))
                const removed = Object.keys(before).find(path => !(path in disks))
                const path = added ?? removed
                if (!path) return
                const disk = added ? disks[added] : before[removed]
                const card = /mmc|sd/i.test(disk.tran)
                const what = card ? Translation.tr("Memory card") : Translation.tr("USB drive")
                root.publish({ kind: "drives", tone: added ? "on" : "off",
                    icon: card ? "sd_card" : added ? "usb" : "usb_off", fluentIcon: card ? "media-flash-symbolic" : "drive-removable-media-symbolic",
                    title: disk.label || disk.model || what,
                    detail: [what, root.sizeText(disk.size), added ? Translation.tr("Connected") : Translation.tr("Removed")].filter(part => part).join(" · "),
                    value: -1 })
            }
        }
    }
    function sizeText(bytes: real): string {
        if (!(bytes > 0)) return ""
        const units = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        let n = bytes
        while (n >= 1000 && i < units.length - 1) { n /= 1000; i++ }
        return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + units[i]
    }

    // A sample of each kind, to see how the notice looks without unplugging anything.
    function sample(kind: string): void {
        const samples = {
            network: { kind: "network", tone: "on", icon: "wifi", fluentIcon: "wifi-1", title: Translation.tr("Wi-Fi connected"), detail: Network.networkName || "Home", value: -1 },
            internet: { kind: "internet", tone: "warn", icon: "cloud_off", fluentIcon: "wifi-warning", title: Translation.tr("No internet connection"), detail: Network.networkName, value: -1 },
            bluetooth: { kind: "bluetooth", tone: "on", icon: "headphones", fluentIcon: "bluetooth-connected", title: "WH-1000XM4", detail: Translation.tr("Connected"), value: 80 },
            power: { kind: "power", tone: "on", icon: "battery_charging_full", fluentIcon: "battery-charge", title: Translation.tr("Charging"), detail: Translation.tr("Full in %1").arg(root.duration(2700)), value: 64 },
            audio: { kind: "audio", tone: "on", icon: "headphones", fluentIcon: "headphones", title: Translation.tr("Sound output"), detail: "USB Headset", value: -1 },
            displays: { kind: "displays", tone: "on", icon: "desktop_windows", fluentIcon: "desktop", title: Translation.tr("Display connected"), detail: "DELL U2723QE", value: -1 },
            usb: { kind: "usb", tone: "on", icon: "mouse", fluentIcon: "input-mouse-symbolic", title: "XPG PRIMER", detail: Translation.tr("%1 connected").arg(Translation.tr("Mouse")), value: -1 },
            drives: { kind: "drives", tone: "on", icon: "usb", fluentIcon: "drive-removable-media-symbolic", title: "SanDisk Ultra", detail: [Translation.tr("USB drive"), "32 GB", Translation.tr("Connected")].join(" · "), value: -1 }
        }
        const event = samples[kind]
        if (!event) return
        root.last = event
        root.sequence += 1
        root.happened(event)
    }

    IpcHandler {
        target: "connections"

        function sample(kind: string): string {
            if (!root.kinds.includes(kind)) return "unknown kind: " + root.kinds.join(", ")
            root.sample(kind)
            return kind
        }
        function status(): string {
            const state = { enabled: root.enabled, udev: root.udevAvailable }
            root.kinds.forEach(kind => state[kind] = root.allows(kind))
            return JSON.stringify(state)
        }
        function enable(): void { Config.setNestedValue("osd.connections.enable", true) }
        function disable(): void { Config.setNestedValue("osd.connections.enable", false) }
        function toggle(): void { Config.setNestedValue("osd.connections.enable", !root.enabled) }
    }
}
