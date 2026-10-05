pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.iris.style

QtObject {
    id: root

    readonly property var options: Config.options?.iris?.controlCenter ?? ({})

    // shapes: "<columns>x<rows>", "F" = full width, first = resting.
    readonly property var catalogue: [
        { id: "platter", label: "Connections", glyph: "hub", category: "connect", description: "Four round controls on one plate; pick them on the Panel page.", kind: "platter", shapes: ["2x2", "Fx1"] },
        { id: "network", label: "Network", glyph: "wifi", category: "connect", description: "Wi-Fi and Ethernet.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "bluetooth", label: "Bluetooth", glyph: "bluetooth", category: "connect", description: "The adapter and what is connected.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "vpn", label: "VPN", glyph: "vpn_key", category: "connect", description: "NetworkManager profiles and Tailscale.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "hotspot", label: "Hotspot", glyph: "wifi_tethering", category: "connect", description: "Share this connection.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "warp", label: "WARP", glyph: "cloud", category: "connect", description: "Cloudflare's tunnel.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "focus", label: "Focus", glyph: "do_not_disturb_on", category: "system", description: "Silence notifications.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "gameMode", label: "Game", glyph: "sports_esports", category: "system", description: "Stands the shell down while you play.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "profiles", label: "Profile", glyph: "bolt", category: "system", description: "Power saver, balanced or performance.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "idle", label: "Awake", glyph: "coffee", category: "system", description: "Keeps the screen from sleeping.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "darkMode", label: "Dark", glyph: "contrast", category: "display", description: "Dark or light across the shell.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "nightLight", label: "Night light", glyph: "nightlight", category: "display", description: "Warms the screen after dark.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "antiFlashbang", label: "Flashbang", glyph: "flare", category: "display", description: "Dims a screen that turns white on you.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "levels", label: "Levels", glyph: "tune", category: "sound", description: "Slim sliders side by side; pick them on the Panel page.", kind: "levels", shapes: ["2x2", "2x3", "Fx1", "Fx2"] },
        { id: "brightness", label: "Brightness", glyph: "light_mode", category: "display", description: "This screen's backlight.", kind: "level", shapes: ["1x2", "2x1", "Fx1"] },
        { id: "volume", label: "Volume", glyph: "volume_up", category: "sound", description: "The output level; its glyph mutes.", kind: "level", shapes: ["1x2", "2x1", "Fx1"] },
        { id: "microphone", label: "Microphone", glyph: "mic", category: "sound", description: "The input level; its glyph mutes.", kind: "level", shapes: ["1x2", "2x1", "Fx1"] },
        { id: "audio", label: "Output", glyph: "volume_off", category: "sound", description: "Mute the speakers.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "mic", label: "Mic", glyph: "mic_off", category: "sound", description: "Mute the input.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "devices", label: "Devices", glyph: "speaker", category: "sound", description: "The output and input list.", kind: "action", shapes: ["1x1", "2x1"] },
        { id: "easyEffects", label: "Effects", glyph: "graphic_eq", category: "sound", description: "The audio effects chain.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "equalizer", label: "Equalizer", glyph: "equalizer", category: "sound", description: "Shape the sound: bands, colour and control.", kind: "action", shapes: ["1x1", "2x1"] },
        { id: "musicRecognition", label: "Name song", glyph: "music_cast", category: "sound", description: "Listens and tells you what is playing.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "media", label: "Now playing", glyph: "play_circle", category: "sound", description: "Cover, title and transport.", kind: "media", shapes: ["2x2", "Fx1", "Fx2"] },
        { id: "snip", label: "Capture", glyph: "screenshot_region", category: "tools", description: "Pick a region to screenshot.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "record", label: "Record screen", glyph: "radio_button_checked", category: "tools", description: "Start and stop a full-screen recording.", kind: "action", shapes: ["1x1", "2x1"] },
        { id: "colorPicker", label: "Colour", glyph: "colorize", category: "tools", description: "Pick a colour off the screen.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "osk", label: "Keyboard", glyph: "keyboard", category: "tools", description: "The on-screen keyboard.", kind: "toggle", shapes: ["1x1", "2x1"] },
        { id: "notifications", label: "Notifications", glyph: "notifications", category: "tools", description: "The latest, under the grid.", kind: "list", shapes: [] }
    ]
    readonly property var categories: [
        { id: "connect", label: "Connections" },
        { id: "system", label: "System" },
        { id: "display", label: "Display" },
        { id: "sound", label: "Sound" },
        { id: "tools", label: "Tools" }
    ]
    readonly property var catalogueIds: root.catalogue.map(entry => entry.id)
    readonly property var aliases: ({ connectivity: ["platter"] })

    readonly property var legacySeed: ({
        connectivity: ["platter"],
        media: ["media"],
        shortcuts: ["darkMode", "nightLight", "idle", "snip", "record", "devices"],
        levels: ["levels"],
        notifications: ["notifications"]
    })

    function expand(list: var): var {
        const out = []
        for (const raw of Array.from(list ?? [])) {
            const id = String(raw)
            for (const each of (root.aliases[id] ?? [id]))
                if (root.catalogueIds.includes(each) && !out.includes(each)) out.push(each)
        }
        return out
    }

    readonly property var shippedModules: ["platter", "media", "darkMode", "nightLight", "levels", "idle", "snip",
        "devices", "record", "notifications"]
    readonly property var shippedSizes: ["devices:2x1", "record:2x1"]
    readonly property var shippedSections: ["connectivity", "media", "shortcuts", "levels", "notifications"]
    // 2.31 configs that changed `sections` but never wrote `modules` keep that composition.
    readonly property var modules: {
        Config.revision
        const raw = Array.from(root.options?.modules ?? []).map(entry => String(entry))
        const sections = Array.from(root.options?.sections ?? root.shippedSections).map(entry => String(entry))
        if (raw.join() === root.shippedModules.join() && sections.join() !== root.shippedSections.join()) {
            const out = []
            for (const section of sections) out.push(...(root.legacySeed[section] ?? []))
            return root.expand(out)
        }
        return root.expand(raw)
    }
    readonly property var gridModules: root.modules.filter(id => root.kindOf(id) !== "list")
    readonly property var spare: root.catalogueIds.filter(id => !root.modules.includes(id))

    readonly property int columns: Math.max(3, Math.min(6, Number(root.options?.columns ?? 4)))
    readonly property bool labelled: Boolean(root.options?.labels ?? false)
    readonly property bool roundControls: String(root.options?.controls ?? "tiles") === "round"
    readonly property var toggleIds: root.catalogue.filter(entry => entry.kind === "toggle" || entry.kind === "action").map(entry => entry.id)
    readonly property var levelKinds: ["brightness", "volume", "microphone"]
    readonly property var platterIds: {
        Config.revision
        const chosen = Array.from(root.options?.platter ?? []).map(entry => String(entry)).filter(id => root.toggleIds.includes(id))
        return chosen.slice(0, 4)
    }
    readonly property var levelIds: {
        Config.revision
        return Array.from(root.options?.levels ?? []).map(entry => String(entry)).filter(id => root.levelKinds.includes(id))
    }
    readonly property string accentMode: String(root.options?.accent ?? "system")
    readonly property bool accentSliders: String(root.options?.sliders ?? "neutral") === "accent"

    // Colourful gives each control the hue it means; mono lights everything in the ink colour.
    readonly property var identities: ({
        network: "blue", bluetooth: "blue", vpn: "green", hotspot: "teal", warp: "orange",
        focus: "indigo", gameMode: "green", profiles: "yellow", idle: "orange",
        darkMode: "gray", nightLight: "orange", antiFlashbang: "yellow",
        audio: "pink", mic: "orange", devices: "blue", easyEffects: "purple", equalizer: "purple", musicRecognition: "pink",
        snip: "teal", record: "red", colorPicker: "purple", osk: "gray"
    })
    function tintFor(id: string): color {
        if (id === "record") return IrisStyle.danger
        if (root.accentMode === "mono") return IrisStyle.text
        if (root.accentMode === "accent") return IrisStyle.accent
        if (root.accentMode === "colourful") {
            const hue = root.identities[id] ?? ""
            return hue === "gray" ? IrisStyle.textSecondary : IrisStyle.identityColor(hue)
        }
        return id === "gameMode" || id === "vpn" ? IrisStyle.identity.green
            : id === "focus" ? IrisStyle.identity.indigo : IrisStyle.accent
    }
    readonly property real libraryWidth: 312
    readonly property real editorExtra: root.libraryWidth + 21

    function entryOf(id: string): var { return root.catalogue.find(entry => entry.id === id) ?? null }
    function labelOf(id: string): string { return root.entryOf(id)?.label ?? id }
    function glyphOf(id: string): string { return root.entryOf(id)?.glyph ?? "toggle_on" }
    function kindOf(id: string): string { return root.entryOf(id)?.kind ?? "toggle" }
    function categoryOf(id: string): string { return root.entryOf(id)?.category ?? "" }

    function parseShape(shape: string, columns: int): var {
        const parts = String(shape).split("x")
        const w = parts[0] === "F" ? columns : Number(parts[0])
        return { w: Math.max(1, Math.min(columns, w)), h: Math.max(1, Number(parts[1] ?? 1)), full: parts[0] === "F", name: String(shape) }
    }
    function shapesFor(id: string, columns: int): var {
        const cols = columns > 0 ? columns : root.columns
        return (root.entryOf(id)?.shapes ?? []).filter(shape => shape.startsWith("F") || Number(shape.split("x")[0]) <= cols)
    }
    function chosenShapes(list: var): var {
        const out = ({})
        for (const entry of Array.from(list ?? [])) {
            const parts = String(entry).split(":")
            if (parts.length !== 2) continue
            const shape = parts[1].includes("x") ? parts[1] : parts[1] + "x1"
            for (const id of (root.aliases[parts[0]] ?? [parts[0]])) out[id] = shape
        }
        return out
    }
    readonly property var chosen: {
        Config.revision
        return root.chosenShapes(root.options?.sizes ?? [])
    }
    function resolveShape(id: string, wanted: string, columns: int): var {
        const allowed = root.shapesFor(id, columns)
        if (allowed.length === 0) return { w: columns, h: 1, full: true, name: "Fx1" }
        const name = allowed.includes(wanted) ? wanted : allowed[0]
        return root.parseShape(name, columns)
    }
    function shapeOf(id: string): var { return root.resolveShape(id, root.chosen[id] ?? "", root.columns) }

    function pack(ids: var, shapes: var, columns: int): var {
        const taken = []
        const placed = ({})
        let rows = 0
        const free = (c, r, w, h) => {
            for (let y = r; y < r + h; y++)
                for (let x = c; x < c + w; x++)
                    if (taken[y] && taken[y][x]) return false
            return true
        }
        for (const id of ids) {
            const shape = shapes[id]
            let spot = null
            for (let r = 0; spot === null; r++)
                for (let c = 0; c + shape.w <= columns && spot === null; c++)
                    if (free(c, r, shape.w, shape.h)) spot = { col: c, row: r }
            for (let y = spot.row; y < spot.row + shape.h; y++) {
                taken[y] = taken[y] ?? []
                for (let x = spot.col; x < spot.col + shape.w; x++) taken[y][x] = true
            }
            placed[id] = { col: spot.col, row: spot.row, w: shape.w, h: shape.h, shape: shape.name }
            rows = Math.max(rows, spot.row + shape.h)
        }
        return { placed: placed, rows: rows }
    }

    function write(values: var): void {
        const updates = ({})
        for (const key of Object.keys(values)) updates["iris.controlCenter." + key] = values[key]
        Config.setNestedValues(updates)
    }
    function snapshot(): var {
        return {
            modules: Array.from(root.modules), sizes: Array.from(root.options?.sizes ?? []).map(entry => String(entry)),
            columns: root.columns, labels: root.labelled, controls: root.roundControls ? "round" : "tiles",
            preset: String(root.options?.preset ?? ""), platter: Array.from(root.platterIds), levels: Array.from(root.levelIds),
            accent: root.accentMode, sliders: root.accentSliders ? "accent" : "neutral"
        }
    }
    property var history: []
    readonly property bool canUndo: root.history.length > 0
    function change(values: var): void {
        root.history = root.history.concat([root.snapshot()]).slice(-60)
        root.write(values)
    }
    function undo(): bool {
        if (root.history.length === 0) return false
        const last = root.history[root.history.length - 1]
        root.history = root.history.slice(0, -1)
        root.write(last)
        return true
    }
    function forget(): void { root.history = [] }

    function setModules(list: var): void {
        const next = Array.from(list)
        root.change({ modules: next.length > 0 ? next : [""], preset: "custom" })
    }
    function setShape(id: string, shape: string): void {
        const kept = Array.from(root.options?.sizes ?? []).map(entry => String(entry))
            .filter(entry => !(root.aliases[entry.split(":")[0]] ?? [entry.split(":")[0]]).includes(id))
        if (shape !== (root.entryOf(id)?.shapes ?? [])[0]) kept.push(id + ":" + shape)
        root.change({ sizes: kept, preset: "custom" })
    }
    function nextShape(id: string): void {
        const allowed = root.shapesFor(id, root.columns)
        if (allowed.length < 2) return
        const index = allowed.indexOf(root.shapeOf(id).name)
        root.setShape(id, allowed[(index + 1) % allowed.length])
    }
    function remove(id: string): void { root.setModules(root.modules.filter(entry => entry !== id)) }
    function add(id: string, at: int): void {
        if (root.modules.includes(id)) return
        const list = Array.from(root.modules)
        const index = at >= 0 ? Math.min(at, list.length) : list.length
        list.splice(index, 0, id)
        root.setModules(list)
    }
    function move(id: string, to: int): void {
        const list = root.modules.filter(entry => entry !== id)
        list.splice(Math.max(0, Math.min(list.length, to)), 0, id)
        if (list.join() !== root.modules.join()) root.setModules(list)
    }
    function toggleIn(key: string, id: string, limit: int): void {
        const current = key === "platter" ? root.platterIds : root.levelIds
        let next = current.includes(id) ? current.filter(entry => entry !== id) : current.concat([id])
        if (limit > 0 && next.length > limit) next = next.slice(next.length - limit)
        root.setPanel(key, next)
    }
    function setPanel(key: string, value: var): void {
        const values = ({})
        values[key] = value
        root.change(values)
    }

    readonly property var presets: [
        { id: "iris", label: "iRiS", description: "Connections beside the player, quiet tiles beside slim sliders.",
            columns: 4, labels: false, controls: "tiles",
            modules: root.shippedModules, sizes: root.shippedSizes,
            platter: ["network", "bluetooth", "focus", "gameMode"], levels: ["brightness", "volume", "microphone"] },
        { id: "discs", label: "Discs", description: "The same, every switch a disc with its name under it.",
            columns: 4, labels: true, controls: "round",
            modules: ["platter", "media", "darkMode", "nightLight", "levels", "idle", "snip", "devices", "record", "notifications"],
            sizes: ["devices:2x1", "record:2x1"], platter: ["network", "bluetooth", "focus", "gameMode"], levels: ["brightness", "volume", "microphone"] },
        { id: "compact", label: "Compact", description: "Two rows of round switches and the sliders across. No names.",
            columns: 5, labels: false, controls: "round",
            modules: ["network", "bluetooth", "vpn", "focus", "gameMode", "darkMode", "nightLight", "idle", "snip", "record", "levels"],
            sizes: ["levels:Fx1"], platter: ["network", "bluetooth", "focus", "gameMode"], levels: ["brightness", "volume"] },
        { id: "glance", label: "Glance", description: "What is playing, how loud and how bright, and what came in.",
            columns: 4, labels: true, controls: "round",
            modules: ["media", "levels", "notifications"],
            sizes: ["media:Fx2", "levels:Fx2"], platter: ["network", "bluetooth", "focus", "gameMode"], levels: ["volume", "brightness"] },
        { id: "studio", label: "Studio", description: "Sound first: the player, levels, devices and effects.",
            columns: 4, labels: true, controls: "round",
            modules: ["media", "levels", "devices", "easyEffects", "audio", "mic", "musicRecognition", "focus"],
            sizes: ["media:Fx1", "levels:2x2", "devices:2x1", "easyEffects:2x1"],
            platter: ["network", "bluetooth", "focus", "gameMode"], levels: ["volume", "microphone"] },
        { id: "everything", label: "Everything", description: "Every control iNiR has, in one long panel.",
            columns: 4, labels: true, controls: "round",
            modules: root.catalogueIds.filter(id => !["brightness", "volume", "microphone"].includes(id)), sizes: [],
            platter: ["network", "bluetooth", "vpn", "hotspot"], levels: ["brightness", "volume", "microphone"] }
    ]
    function presetOf(id: string): var { return root.presets.find(entry => entry.id === id) ?? null }
    readonly property string presetId: String(root.options?.preset ?? "")
    function applyPreset(id: string): bool {
        const preset = root.presetOf(id)
        if (!preset) return false
        root.change({ preset: preset.id, columns: preset.columns, labels: preset.labels,
            controls: preset.controls, modules: preset.modules, sizes: preset.sizes,
            platter: preset.platter, levels: preset.levels })
        return true
    }
}
