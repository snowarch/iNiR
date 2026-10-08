pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * VPN state from the two places a desktop actually keeps it: NetworkManager
 * connection profiles (OpenVPN, WireGuard, IPSec, anything with an NM plugin)
 * and Tailscale, which runs beside NetworkManager rather than inside it.
 *
 * There is no background polling: refreshes follow nmcli monitor through
 * Network.networkChanged and callers asking; a timer runs only while a surface holds
 * the service alive, because Tailscale changes do not reach NetworkManager.
 */
Singleton {
    id: root

    property var profiles: []
    property bool tailscaleInstalled: false
    property string tailscaleState: ""
    property string tailscaleHost: ""
    property string tailscaleAddress: ""
    property int tailscalePeers: 0
    property string tailscaleExitNode: ""
    property string tailscaleAddress6: ""
    property string tailscaleDns: ""
    property string tailscaleAccount: ""
    property string tailscaleExitName: ""
    property string tailscaleAuthUrl: ""
    readonly property bool tailscaleSignedOut: root.tailscaleState === "NeedsLogin"
    property bool signingIn: false
    // What this machine has, probed once: every path below offers only what exists and names what to install.
    property bool hasEditor: false
    property bool hasNmtui: false
    property bool hasNmcli: false
    property bool hasOpenvpnPlugin: false
    // Any NetworkManager VPN plugin (OpenVPN, L2TP, OpenConnect…); WireGuard is built in and needs none.
    property bool hasVpnPlugins: false
    readonly property bool canCreate: root.hasEditor || (root.hasNmtui && root.hasNmcli)
    readonly property string missingEditorText: Translation.tr("To add or edit a VPN here, install NetworkManager's connection editor (nm-connection-editor).")
    // Devices of the tailnet, Funnel's ingress relays and shared-in nodes left out: { name, address, os, online, exitNode }.
    property var tailscaleDevices: []
    readonly property int tailscaleOnline: root.tailscaleDevices.filter(device => device.online).length
    // Per active NetworkManager profile: { device, address, dns, gateway }, keyed by uuid; read only while details show.
    property var profileDetails: ({})
    // Bytes per second through each interface, keyed by interface name: { down, up }.
    property var rates: ({})
    property var lastBytes: ({})
    readonly property bool details: Config.options?.vpn?.details ?? false
    function setDetails(on: bool): void { Config.setNestedValue("vpn.details", on) }
    property string lastError: ""
    property bool busy: false

    readonly property bool needsTailscaleOperator: /access denied|operator/i.test(root.lastError)
    readonly property bool needsSecrets: /secret|password|no valid.*key/i.test(root.lastError)
    readonly property bool needsPlugin: /plugin/i.test(root.lastError)
    readonly property string errorText: {
        if (root.lastError.length === 0) return ""
        if (root.needsTailscaleOperator)
            return Translation.tr("Tailscale only takes orders from root until your user is its operator.")
        if (root.needsSecrets)
            return Translation.tr("This profile needs its password stored in NetworkManager to connect from here.")
        if (root.needsPlugin)
            return Translation.tr("OpenVPN files need NetworkManager's OpenVPN plugin (networkmanager-openvpn or NetworkManager-openvpn).")
        return root.lastError
    }
    function fixTailscaleOperator(): void {
        root.busy = true
        root.lastError = ""
        actionProc.exec(["pkexec", "tailscale", "set", "--operator=" + Quickshell.env("USER")])
    }

    readonly property bool tailscaleUp: root.tailscaleState === "Running"
    readonly property var activeProfiles: root.profiles.filter(entry => entry.active)
    readonly property bool connected: root.activeProfiles.length > 0 || root.tailscaleUp
    readonly property int activeCount: root.activeProfiles.length + (root.tailscaleUp ? 1 : 0)
    readonly property bool available: root.profiles.length > 0 || root.tailscaleInstalled
    readonly property string activeName: root.activeProfiles[0]?.name
        ?? (root.tailscaleUp ? "Tailscale" : "")

    property int watchers: 0
    function keepAlive(): void { root.watchers += 1; root.refresh() }
    function releaseKeepAlive(): void { root.watchers = Math.max(0, root.watchers - 1) }

    function refresh(): void {
        profilesProc.running = true
        tailscaleProc.running = true
        root.readDetails()
    }
    readonly property var watchedInterfaces: {
        const out = root.activeProfiles.map(entry => root.profileDetails[entry.uuid]?.device ?? "").filter(dev => dev.length > 0)
        if (root.tailscaleUp) out.push("tailscale0")
        return out
    }
    function readDetails(): void {
        if (!root.details || root.watchers === 0) return
        if (root.activeProfiles.length > 0 && !detailsProc.running)
            detailsProc.exec(["bash", "-c", 'for uuid in "$@"; do echo "@$uuid"; '
                + 'nmcli -t -f GENERAL.DEVICES,IP4.ADDRESS,IP4.DNS,IP4.GATEWAY connection show uuid "$uuid"; done',
                "_", ...root.activeProfiles.map(entry => entry.uuid)])
        root.readRates()
    }
    function readRates(): void {
        if (root.watchedInterfaces.length === 0 || ratesProc.running) return
        ratesProc.exec(["bash", "-c", 'for d in "$@"; do [ -r "/sys/class/net/$d/statistics/rx_bytes" ] || continue; '
            + 'echo "$d $(cat /sys/class/net/$d/statistics/rx_bytes) $(cat /sys/class/net/$d/statistics/tx_bytes)"; done',
            "_", ...root.watchedInterfaces])
    }

    function setProfile(uuid: string, up: bool): void {
        if (String(uuid ?? "").length === 0) return
        root.busy = true
        root.lastError = ""
        actionProc.exec(["nmcli", "connection", up ? "up" : "down", "uuid", uuid])
    }
    function toggleProfile(uuid: string): void {
        const entry = root.profiles.find(item => item.uuid === uuid)
        if (!entry) return
        root.setProfile(uuid, !entry.active)
    }
    function setTailscale(up: bool): void {
        if (!root.tailscaleInstalled) return
        root.busy = true
        root.lastError = ""
        actionProc.exec(["tailscale", up ? "up" : "down"])
    }
    function setAutoconnect(uuid: string, on: bool): void {
        if (String(uuid ?? "").length === 0) return
        root.busy = true
        root.lastError = ""
        actionProc.exec(["nmcli", "connection", "modify", "uuid", uuid, "connection.autoconnect", on ? "yes" : "no"])
    }
    // A WireGuard .conf or an OpenVPN .ovpn becomes a NetworkManager profile; its name comes from the file.
    function importProfile(path: string): void {
        const file = String(path ?? "").replace(/^file:\/\//, "")
        if (file.length === 0) return
        root.lastError = ""
        if (/\.ovpn$/i.test(file) && !root.hasOpenvpnPlugin) { root.lastError = "missing plugin"; return }
        root.busy = true
        actionProc.exec(["nmcli", "connection", "import", "type", /\.ovpn$/i.test(file) ? "openvpn" : "wireguard", "file", file])
    }
    // Windows the card hands off to: it closes first, so they never open under it.
    signal handOff()
    function chooseProfileFile(): void { root.handOff(); importDialog.open() }
    // `kind`: "wireguard" or "vpn" (a plugin's own chooser); nmtui asks for the type itself.
    function newProfile(kind: string): void {
        if (!root.canCreate) return
        root.handOff()
        if (root.hasEditor) Quickshell.execDetached(["nm-connection-editor", "--create", "--type=" + (kind === "vpn" ? "vpn" : "wireguard")])
        else root.inTerminal(["nmtui", "edit"])
    }
    function editProfile(uuid: string): void {
        const entry = root.profiles.find(item => item.uuid === uuid)
        if (!entry || !root.canCreate) return
        root.handOff()
        if (root.hasEditor) Quickshell.execDetached(["nm-connection-editor", "--edit=" + uuid])
        else root.inTerminal(["nmtui", "edit", entry.name])
    }
    function inTerminal(command: var): void {
        const configured = String(Config.options?.apps?.terminal ?? "kitty").trim()
        const terminal = /^[A-Za-z0-9._+-]+$/.test(configured) ? configured : "kitty"
        Quickshell.execDetached(terminal === "wezterm" ? [terminal, "start", "--", ...command] : [terminal, "-e", ...command])
    }
    // Tailscale's own login: it prints a URL and waits; the URL reaches `status --json` and the browser opens on it.
    function signInTailscale(): void {
        if (!root.tailscaleInstalled || loginProc.running) return
        root.signingIn = true
        root.lastError = ""
        loginProc.running = true
        signInPoll.restart()
    }
    function setExitNode(address: string): void {
        if (!root.tailscaleUp) return
        root.busy = true
        root.lastError = ""
        actionProc.exec(["tailscale", "set", "--exit-node=" + String(address ?? "")])
    }
    function toggleTailscale(): void { root.setTailscale(!root.tailscaleUp) }
    function toggle(): void {
        if (root.connected) {
            root.busy = true
            root.lastError = ""
            // One process for every profile: a second exec on the same Process would cut the first short.
            actionProc.exec(["bash", "-c", 'status=0; [ "$1" = 1 ] && { tailscale down || status=$?; }; shift; '
                + 'for uuid in "$@"; do nmcli connection down uuid "$uuid" || status=$?; done; exit $status',
                "_", root.tailscaleUp ? "1" : "0", ...root.activeProfiles.map(entry => entry.uuid)])
            return
        }
        if (root.tailscaleInstalled) { root.setTailscale(true); return }
        const first = root.profiles[0]
        if (first) root.setProfile(first.uuid, true)
    }

    Connections {
        target: Network
        function onNetworkChanged(): void { root.refresh() }
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }
    // Live throughput only while someone is looking at the details of a connection that is up.
    Timer {
        interval: 2000
        repeat: true
        running: root.watchers > 0 && root.details && root.connected
        onTriggered: root.readRates()
    }
    onDetailsChanged: root.readDetails()

    Process {
        id: detailsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                let current = null
                for (const line of text.split("\n")) {
                    if (line.startsWith("@")) { current = { device: "", address: "", dns: "", gateway: "" }; out[line.slice(1)] = current; continue }
                    if (!current) continue
                    const at = line.indexOf(":")
                    const key = line.slice(0, at), value = line.slice(at + 1).trim()
                    if (key.startsWith("GENERAL.DEVICES")) current.device = value.split(",")[0]
                    else if (key.startsWith("IP4.ADDRESS") && !current.address) current.address = value
                    else if (key.startsWith("IP4.DNS")) current.dns = current.dns ? current.dns + ", " + value : value
                    else if (key.startsWith("IP4.GATEWAY") && value !== "--") current.gateway = value
                }
                root.profileDetails = out
                root.readRates()
            }
        }
    }
    Process {
        id: ratesProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now()
                const bytes = {}, rates = {}
                for (const line of text.split("\n")) {
                    const [dev, rx, tx] = line.trim().split(" ")
                    if (!dev || rx === undefined) continue
                    bytes[dev] = { rx: Number(rx), tx: Number(tx), at: now }
                    const before = root.lastBytes[dev]
                    const span = before ? (now - before.at) / 1000 : 0
                    rates[dev] = span > 0.2 ? { down: Math.max(0, (bytes[dev].rx - before.rx) / span), up: Math.max(0, (bytes[dev].tx - before.tx) / span) }
                        : (root.rates[dev] ?? { down: 0, up: 0 })
                }
                root.lastBytes = bytes
                root.rates = rates
            }
        }
    }

    Component.onCompleted: { root.refresh(); editorProbe.running = true }
    Process {
        id: editorProbe
        running: false
        command: ["sh", "-c", 'for tool in nm-connection-editor nmtui nmcli; do command -v "$tool" >/dev/null && echo "$tool"; done; '
            + 'for dir in /usr/lib/NetworkManager/VPN /usr/lib64/NetworkManager/VPN /etc/NetworkManager/VPN /run/current-system/sw/lib/NetworkManager/VPN; do '
            + 'ls "$dir" 2>/dev/null | grep -qi openvpn && echo openvpn; ls "$dir"/*.name >/dev/null 2>&1 && echo plugins; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n")
                root.hasEditor = found.includes("nm-connection-editor")
                root.hasNmtui = found.includes("nmtui")
                root.hasNmcli = found.includes("nmcli")
                root.hasOpenvpnPlugin = found.includes("openvpn")
                root.hasVpnPlugins = found.includes("plugins")
            }
        }
    }
    FileDialog {
        id: importDialog
        title: Translation.tr("Import a VPN profile")
        fileMode: FileDialog.OpenFile
        currentFolder: "file://" + Directories.homePath
        nameFilters: [Translation.tr("WireGuard or OpenVPN") + " (*.conf *.ovpn)", Translation.tr("All files") + " (*)"]
        onAccepted: root.importProfile(String(selectedFile))
    }
    Process {
        id: loginProc
        running: false
        command: ["tailscale", "login", "--timeout=120s"]
        stderr: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n").find(entry => /access denied|operator|error/i.test(entry)) ?? ""
                if (line.length > 0) root.lastError = line
            }
        }
        onExited: { root.signingIn = false; signInPoll.stop(); root.refresh() }
    }
    Timer {
        id: signInPoll
        interval: 1200
        repeat: true
        onTriggered: tailscaleProc.running = true
    }
    onTailscaleAuthUrlChanged: if (root.signingIn && root.tailscaleAuthUrl.length > 0) Qt.openUrlExternally(root.tailscaleAuthUrl)

    Process {
        id: profilesProc
        running: false
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                for (const line of text.split("\n")) {
                    if (line.trim().length === 0) continue
                    // nmcli -t escapes colons inside fields as "\:"
                    const parts = line.replace(/\\:/g, "\u0000").split(":").map(part => part.replace(/\u0000/g, ":"))
                    if (parts.length < 4) continue
                    const type = parts[2]
                    if (type !== "vpn" && type !== "wireguard") continue
                    found.push({
                        name: parts[0],
                        uuid: parts[1],
                        type: type === "wireguard" ? "WireGuard" : "VPN",
                        active: parts[3] === "yes",
                        autoconnect: parts[4] === "yes"
                    })
                }
                root.profiles = found
            }
        }
    }

    Process {
        id: tailscaleProc
        running: false
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) return
                try {
                    const data = JSON.parse(text)
                    root.tailscaleInstalled = true
                    root.tailscaleState = String(data.BackendState ?? "")
                    root.tailscaleAuthUrl = String(data.AuthURL ?? "")
                    root.tailscaleHost = String(data.Self?.HostName ?? "")
                    const own = data.Self?.TailscaleIPs ?? data.TailscaleIPs ?? []
                    root.tailscaleAddress = String(own.find(ip => ip.includes(".")) ?? own[0] ?? "")
                    root.tailscaleAddress6 = String(own.find(ip => ip.includes(":")) ?? "")
                    root.tailscaleDns = String(data.Self?.DNSName ?? "").replace(/\.$/, "")
                    root.tailscaleAccount = String(data.User?.[String(data.Self?.UserID ?? "")]?.LoginName ?? data.CurrentTailnet?.Name ?? "")
                    const peers = Object.values(data.Peer ?? {})
                        .filter(peer => !peer.ShareeNode && !(peer.Tags ?? []).includes("tag:ingress"))
                        .map(peer => ({ name: String(peer.HostName ?? peer.DNSName ?? ""), os: String(peer.OS ?? ""),
                            address: String((peer.TailscaleIPs ?? []).find(ip => ip.includes(".")) ?? ""),
                            online: Boolean(peer.Online), exitNode: Boolean(peer.ExitNode), exitOption: Boolean(peer.ExitNodeOption) }))
                        .sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
                    root.tailscaleDevices = peers
                    root.tailscalePeers = peers.length
                    root.tailscaleExitNode = String(data.ExitNodeStatus?.ID ?? "")
                    root.tailscaleExitName = peers.find(peer => peer.exitNode)?.name ?? ""
                } catch (error) {
                    root.tailscaleInstalled = false
                }
            }
        }
        onExited: exitCode => { if (exitCode !== 0 && exitCode !== 1) root.tailscaleInstalled = false }
    }

    IpcHandler {
        target: "vpn"
        function status(): string {
            return JSON.stringify({ connected: root.connected, through: root.activeName, details: root.details,
                tailscale: root.tailscaleInstalled ? root.tailscaleState : "", devices: root.tailscaleDevices.length,
                online: root.tailscaleOnline, profiles: root.profiles.map(entry => entry.name + (entry.active ? " (on)" : "")) })
        }
        function toggle(): string { root.toggle(); return root.connected ? "disconnecting" : "connecting" }
        function details(state: string): string {
            root.setDetails(state === "toggle" ? !root.details : state === "on")
            return state === "toggle" ? (!root.details ? "on" : "off") : state
        }
        function refresh(): void { root.refresh() }
        function importFile(path: string): string {
            if (String(path ?? "").length === 0) { root.chooseProfileFile(); return "choosing" }
            root.importProfile(path)
            return "importing " + path
        }
        function add(kind: string): string {
            if (!root.canCreate) return root.missingEditorText
            root.newProfile(kind)
            return root.hasEditor ? "nm-connection-editor " + (kind === "vpn" ? "vpn" : "wireguard") : "nmtui"
        }
    }

    Process {
        id: actionProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: root.lastError = text.trim().split("\n")[0] ?? ""
        }
        onExited: {
            root.busy = false
            root.refresh()
        }
    }
}
