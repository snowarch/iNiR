pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.iris.style

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/niri-config.py")
    readonly property bool available: CompositorService.isNiri
    property int revision: 0
    property var data: ({ input: {}, layout: {}, animations: {}, "window-rules": {} })
    property var outputs: []
    property var cursorThemes: []
    property var local: ({})
    property var queue: []
    property string error: ""
    property string selectedOutput: ""
    readonly property var output: root.outputs.find(entry => entry.name === root.selectedOutput) ?? root.outputs[0] ?? null
    property var pending: null
    property bool hasTouchpad: false
    property bool hasTrackpoint: false
    property int secondsLeft: 0
    // How long a display change waits for Keep before it goes back.
    readonly property int revertAfter: 15

    // The config is read again only once niri reloads it (it watches the file itself) or the outputs change: every open
    // started six python3 to read what had not moved. Cursor themes and devices come and go outside it.
    property var stale: ({ input: true, layout: true, animations: true, "window-rules": true, outputs: true })
    function ensure(): void {
        if (!root.available) return
        root.reload(Object.keys(root.stale).filter(part => root.stale[part]).concat(["cursors"]))
        if (!devices.running) devices.running = true
    }
    Connections {
        target: NiriService
        function onConfigLoadFinished(ok: bool): void {
            if (ok) for (const part of ["input", "layout", "animations", "window-rules", "outputs"]) root.stale[part] = true
        }
        function onOutputsChanged(): void { root.stale.outputs = true }
    }
    function reload(parts: var): void {
        for (const part of parts) {
            const reader = ({ input: inputReader, layout: layoutReader, animations: animationsReader, "window-rules": rulesReader, outputs: outputsReader, cursors: cursorReader })[part]
            if (reader && !reader.running) { reader.running = true; if (part in root.stale) root.stale[part] = false }
        }
    }
    function readPath(spec: var): string {
        return String(spec.read ?? String(spec.key).replace(/-/g, "_"))
    }
    function lookup(section: string, path: string): var {
        let at = root.data[section] ?? {}
        for (const part of path.split(".")) {
            if (at === undefined || at === null) return undefined
            at = at[part]
        }
        return at
    }
    function value(spec: var): var {
        root.revision
        if (spec.niri === "display") return root.displayValue(spec.key)
        if (spec.niri === "blur") return IrisCompositorBlur[spec.read ?? spec.key]
        const id = spec.niri + ":" + spec.key
        if (id in root.local) return root.local[id]
        const found = root.lookup(spec.niri, root.readPath(spec))
        return found === undefined ? spec.fallback : found
    }
    function set(spec: var, next: var): void {
        if (spec.niri === "display") { root.applyDisplay(spec.key, next); return }
        if (spec.niri === "blur") IrisCompositorBlur[spec.read ?? spec.key] = next
        const local = Object.assign({}, root.local)
        local[spec.niri + ":" + spec.key] = next
        root.local = local
        root.revision++
        const written = spec.write ? spec.write(next) : typeof next === "boolean" ? (next ? "on" : "off") : String(next)
        root.queue = root.queue.filter(item => !(item.section === spec.niri && item.key === spec.key)).concat([{ section: spec.niri, key: spec.key, value: written }])
        root.next()
    }
    function next(): void {
        if (writer.running || root.queue.length === 0) return
        const item = root.queue[0]
        root.queue = root.queue.slice(1)
        writer.section = item.section
        writer.command = ["python3", root.script, "set", item.section, item.key, item.value]
        writer.running = true
    }
    function parse(text: string, onValue: var): bool {
        try {
            const parsed = JSON.parse(text)
            if (parsed && parsed.error) { root.error = String(parsed.error); return false }
            onValue(parsed)
            root.revision++
            return true
        } catch (e) {
            root.error = String(e)
            return false
        }
    }
    function store(section: string, value: var): void {
        const next = Object.assign({}, root.data)
        next[section] = value ?? {}
        root.data = next
        const local = {}
        for (const id of Object.keys(root.local)) if (!id.startsWith(section + ":")) local[id] = root.local[id]
        root.local = local
    }

    function modeOf(output: var): string {
        return output ? `${output.current_resolution}@${output.current_rate_string}` : ""
    }
    // Niri says "60.000" and "74.973"; people read "60 Hz" and "74.97 Hz". Two decimals at most, never rounded to a
    // whole number the screen does not run at.
    function rateLabel(rate: var): string {
        const hz = Number(rate)
        return hz > 0 ? `${Math.round(hz * 100) / 100} Hz` : ""
    }
    function resolutionLabel(output: var): string {
        return String(output?.current_resolution ?? "").replace("x", " × ")
    }
    // The name on the box: "LG Electronics" sells as LG. The connector stands in when the EDID names nothing.
    function screenName(output: var): string {
        const make = String(output?.make ?? "").replace(/\s+(Electronics|Electronic|Electric Company|Display|Displays|Technology|Corporation|Corp\.?|Co\.?,? Ltd\.?|Inc\.?)$/i, "").trim()
        return `${make} ${String(output?.model ?? "").trim()}`.trim() || String(output?.name ?? "")
    }
    // The diagonal from the EDID's millimetres; 0 when the screen does not say (projectors, some TVs, nested outputs).
    function inchesOf(output: var): real {
        const size = output?.physical_size ?? [0, 0]
        const mm = Math.hypot(Number(size?.[0] ?? 0), Number(size?.[1] ?? 0))
        return mm > 0 ? mm / 25.4 : 0
    }
    // Width over height as the screen shows it now, rotation included.
    function aspectOf(output: var): real {
        const rect = root.logicalRect(output)
        return rect.width > 0 && rect.height > 0 ? rect.width / rect.height : 16 / 9
    }
    // Niri reports "Flipped90" and reads "flipped-90" in its config: one spelling, the config's.
    function transformOf(out: var): string {
        return String(out?.transform ?? "Normal").toLowerCase().replace(/^flipped(\d)/, "flipped-$1")
    }
    function displayValue(key: string): var {
        const out = root.output
        if (key === "screen") return out?.name ?? ""
        if (!out) return ""
        if (key === "resolution") return out.current_resolution
        if (key === "rate") return out.current_rate_string
        if (key === "scale") return Number(out.scale)
        if (key === "transform") return root.transformOf(out)
        if (key === "vrr") return out.vrr_enabled ? String(out.vrr_mode ?? "on") : "off"
        if (key === "place") return root.placeOf(out, root.neighbour(out))
        return ""
    }
    // Where a screen sits, read against the first other screen: the side it touches, in logical pixels.
    function neighbour(out: var): var {
        return root.outputs.find(entry => entry.name !== out?.name) ?? null
    }
    function logicalRect(out: var): var {
        const size = String(out?.current_resolution ?? "0x0").split("x").map(Number)
        const turned = ["90", "270", "flipped-90", "flipped-270"].includes(root.transformOf(out))
        const scale = Number(out?.scale ?? 1) || 1
        return { x: Number(out?.position?.x ?? 0), y: Number(out?.position?.y ?? 0),
            width: Math.round((turned ? size[1] : size[0]) / scale), height: Math.round((turned ? size[0] : size[1]) / scale) }
    }
    function placeOf(out: var, other: var): string {
        if (!out || !other) return ""
        const a = root.logicalRect(out), b = root.logicalRect(other)
        if (a.x >= b.x + b.width) return "right"
        if (a.x + a.width <= b.x) return "left"
        if (a.y >= b.y + b.height) return "below"
        return "above"
    }
    function displayChoices(key: string): var {
        root.revision
        const out = root.output
        if (key === "screen") return root.outputs.map(entry => ({ label: `${entry.make ?? ""} ${entry.model ?? ""}`.trim() || entry.name, value: entry.name }))
        if (!out) return []
        if (key === "resolution") return (out.resolutions ?? []).map(entry => ({ label: `${entry.width} × ${entry.height}`, value: `${entry.width}x${entry.height}` }))
        if (key === "rate") {
            const res = (out.resolutions ?? []).find(entry => `${entry.width}x${entry.height}` === out.current_resolution)
            return (res?.rates ?? []).slice().sort((a, b) => b.rate - a.rate).map(entry => ({ label: root.rateLabel(entry.rate), value: entry.rate_string }))
        }
        if (key === "scale") {
            const base = [1, 1.25, 1.5, 1.75, 2]
            if (!base.includes(Number(out.scale))) base.push(Number(out.scale))
            return base.sort((a, b) => a - b).map(scale => ({ label: `${Math.round(scale * 100)} %`, value: scale }))
        }
        if (key === "transform") {
            const turns = [{ label: "Normal", value: "normal" }, { label: "90°", value: "90" }, { label: "180°", value: "180" }, { label: "270°", value: "270" }]
            // A mirrored screen names its own turn instead of reading Custom.
            const current = root.transformOf(out)
            if (current.startsWith("flipped")) turns.push({ label: "Mirrored" + (current === "flipped" ? "" : " " + current.slice(8) + "°"), value: current })
            return turns
        }
        if (key === "vrr") return [{ label: "Off", value: "off" }, { label: "In games", value: "on-demand" }, { label: "Always", value: "on" }]
        if (key === "place") return [{ label: "Left", value: "left", glyph: "west" }, { label: "Right", value: "right", glyph: "east" }, { label: "Above", value: "above", glyph: "north" }, { label: "Below", value: "below", glyph: "south" }]
        return []
    }
    function applyDisplay(key: string, next: var): void {
        if (key === "screen") { root.selectedOutput = String(next); root.revision++; return }
        if (key === "place") { root.place(String(next)); return }
        const out = root.output
        if (!out || root.pending) return
        let setting = key
        let wanted = String(next)
        let previous = ""
        if (key === "resolution") {
            const res = (out.resolutions ?? []).find(entry => `${entry.width}x${entry.height}` === wanted)
            const best = (res?.rates ?? []).slice().sort((a, b) => (b.preferred - a.preferred) || (b.rate - a.rate))[0]
            if (!best) return
            setting = "mode"
            wanted = `${wanted}@${best.rate_string}`
            previous = root.modeOf(out)
        } else if (key === "rate") {
            setting = "mode"
            wanted = `${out.current_resolution}@${wanted}`
            previous = root.modeOf(out)
        } else if (key === "scale") previous = String(out.scale)
        else if (key === "transform") previous = root.transformOf(out)
        else if (key === "vrr") previous = out.vrr_enabled ? String(out.vrr_mode ?? "on") : "off"
        if (wanted === previous) return
        root.pending = { output: out.name, key: setting, value: wanted, previous: previous }
        root.secondsLeft = root.revertAfter
        applier.command = ["python3", root.script, "apply-output", out.name, `${setting}=${wanted}`]
        applier.running = true
        countdown.restart()
    }
    // Moves the chosen screen to one side of the other, edges aligned, and saves every position at once (Niri reloads it).
    function place(side: string): void {
        const out = root.output, other = root.neighbour(out)
        if (!out || !other || layoutWriter.running || side === root.placeOf(out, other)) return
        const a = root.logicalRect(out), b = root.logicalRect(other)
        const at = side === "right" ? { x: b.x + b.width, y: b.y } : side === "left" ? { x: b.x - a.width, y: b.y }
            : side === "below" ? { x: b.x, y: b.y + b.height } : { x: b.x, y: b.y - a.height }
        const layout = {}
        for (const entry of root.outputs) {
            const rect = root.logicalRect(entry)
            layout[entry.name] = entry.name === out.name ? at : { x: rect.x, y: rect.y }
        }
        layoutWriter.command = ["python3", root.script, "persist-layout", JSON.stringify(layout)]
        layoutWriter.running = true
    }
    function keepDisplay(): void {
        const change = root.pending
        if (!change) return
        countdown.stop()
        persister.command = ["python3", root.script, "persist-output", change.output, `${change.key}=${change.value}`]
        persister.running = true
        root.pending = null
    }
    function revertDisplay(): void {
        const change = root.pending
        if (!change) return
        countdown.stop()
        root.pending = null
        applier.command = ["python3", root.script, "apply-output", change.output, `${change.key}=${change.previous}`]
        applier.running = true
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft--
            if (root.secondsLeft <= 0) root.revertDisplay()
        }
    }

    component Reader: Process {
        id: reader
        required property string section
        command: ["python3", root.script, "get-" + reader.section]
        stdout: StdioCollector {
            // A read that failed is read again on the next open.
            onStreamFinished: if (!root.parse(text, value => root.store(reader.section, value))) root.stale[reader.section] = true
        }
    }
    Reader { id: inputReader; section: "input" }
    Reader { id: layoutReader; section: "layout" }
    Reader { id: animationsReader; section: "animations" }
    Reader { id: rulesReader; section: "window-rules" }
    Process {
        id: layoutWriter
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.error = JSON.parse(text)?.error ? String(JSON.parse(text).error) : "" } catch (e) {}
            }
        }
        onExited: layoutSettle.restart()
    }
    // Niri reloads its config on its own; read the outputs back once it has.
    Timer { id: layoutSettle; interval: 600; onTriggered: root.reload(["outputs"]) }
    Process {
        id: outputsReader
        command: ["python3", root.script, "outputs"]
        stdout: StdioCollector {
            onStreamFinished: if (!root.parse(text, value => { root.outputs = Array.isArray(value) ? value : [] })) root.stale.outputs = true
        }
    }
    Process {
        id: cursorReader
        command: ["python3", root.script, "list-cursor-themes"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text, value => { root.cursorThemes = Array.isArray(value) ? value : [] })
        }
    }
    Process {
        id: devices
        command: ["grep", "-i", "^N: Name=", "/proc/bus/input/devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.toLowerCase()
                root.hasTouchpad = names.includes("touchpad")
                root.hasTrackpoint = names.includes("trackpoint")
            }
        }
    }
    Process {
        id: writer
        property string section: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.error = parsed?.error ? String(parsed.error) : ""
                } catch (e) {}
            }
        }
        onExited: {
            if (writer.section === "blur") IrisCompositorBlur.reload()
            else if (root.queue.every(item => item.section !== writer.section)) root.reload([writer.section])
            root.next()
        }
    }
    Process {
        id: applier
        onExited: root.reload(["outputs"])
    }
    Process {
        id: persister
        onExited: root.reload(["outputs"])
    }
}
