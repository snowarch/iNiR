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

    function ensure(): void {
        if (!root.available) return
        root.reload(["input", "layout", "animations", "window-rules", "outputs", "cursors"])
        if (!devices.running) devices.running = true
    }
    function reload(parts: var): void {
        for (const part of parts) {
            const reader = ({ input: inputReader, layout: layoutReader, animations: animationsReader, "window-rules": rulesReader, outputs: outputsReader, cursors: cursorReader })[part]
            if (reader && !reader.running) reader.running = true
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
    function parse(text: string, onValue: var): void {
        try {
            const parsed = JSON.parse(text)
            if (parsed && parsed.error) { root.error = String(parsed.error); return }
            onValue(parsed)
            root.revision++
        } catch (e) {
            root.error = String(e)
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
    function displayValue(key: string): var {
        const out = root.output
        if (key === "screen") return out?.name ?? ""
        if (!out) return ""
        if (key === "resolution") return out.current_resolution
        if (key === "rate") return out.current_rate_string
        if (key === "scale") return Number(out.scale)
        if (key === "transform") return String(out.transform ?? "Normal").toLowerCase()
        if (key === "vrr") return out.vrr_enabled ? String(out.vrr_mode ?? "on") : "off"
        return ""
    }
    function displayChoices(key: string): var {
        root.revision
        const out = root.output
        if (key === "screen") return root.outputs.map(entry => ({ label: `${entry.make ?? ""} ${entry.model ?? ""}`.trim() || entry.name, value: entry.name }))
        if (!out) return []
        if (key === "resolution") return (out.resolutions ?? []).map(entry => ({ label: `${entry.width} × ${entry.height}`, value: `${entry.width}x${entry.height}` }))
        if (key === "rate") {
            const res = (out.resolutions ?? []).find(entry => `${entry.width}x${entry.height}` === out.current_resolution)
            return (res?.rates ?? []).slice().sort((a, b) => b.rate - a.rate).map(entry => ({ label: `${Math.round(entry.rate * 100) / 100} Hz`, value: entry.rate_string }))
        }
        if (key === "scale") {
            const base = [1, 1.25, 1.5, 1.75, 2]
            if (!base.includes(Number(out.scale))) base.push(Number(out.scale))
            return base.sort((a, b) => a - b).map(scale => ({ label: `${Math.round(scale * 100)} %`, value: scale }))
        }
        if (key === "transform") return [{ label: "Normal", value: "normal" }, { label: "90°", value: "90" }, { label: "180°", value: "180" }, { label: "270°", value: "270" }]
        if (key === "vrr") return [{ label: "Off", value: "off" }, { label: "In games", value: "on-demand" }, { label: "Always", value: "on" }]
        return []
    }
    function applyDisplay(key: string, next: var): void {
        if (key === "screen") { root.selectedOutput = String(next); root.revision++; return }
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
        else if (key === "transform") previous = String(out.transform ?? "Normal").toLowerCase()
        else if (key === "vrr") previous = out.vrr_enabled ? String(out.vrr_mode ?? "on") : "off"
        if (wanted === previous) return
        root.pending = { output: out.name, key: setting, value: wanted, previous: previous }
        root.secondsLeft = 15
        applier.command = ["python3", root.script, "apply-output", out.name, `${setting}=${wanted}`]
        applier.running = true
        countdown.restart()
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
            onStreamFinished: root.parse(text, value => root.store(reader.section, value))
        }
    }
    Reader { id: inputReader; section: "input" }
    Reader { id: layoutReader; section: "layout" }
    Reader { id: animationsReader; section: "animations" }
    Reader { id: rulesReader; section: "window-rules" }
    Process {
        id: outputsReader
        command: ["python3", root.script, "outputs"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text, value => { root.outputs = Array.isArray(value) ? value : [] })
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
