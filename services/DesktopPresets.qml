pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

// Named desktops: which widgets are out, where they sit, their order and stacks (the snapshot undo keeps), in the state
// dir, never config.json. Wearing one is an ordinary change while arranging, so Undo takes it back.
Singleton {
    id: root

    // [{ id, name, at, values }], newest first.
    property var presets: []
    readonly property int most: 24

    // Factory desktops: placed on a grid of widget cells from a corner of each screen, so they sit right on any size,
    // clear of the Island above and the Dock below. Each also wears a widget material and accents.
    readonly property var factory: [
        { id: "factory:glance", name: Translation.tr("Glance"), material: "glass", tint: "wallpaper", widgets: [
            { key: "clock", size: "small", at: "tl", col: 0, row: 0 },
            { key: "weather", size: "small", at: "tl", col: 1, row: 0 },
            { key: "calendarUpcoming", size: "medium", at: "tl", col: 0, row: 1 } ] },
        { id: "factory:dashboard", name: Translation.tr("Dashboard"), material: "glass", tint: "spectrum", widgets: [
            { key: "clock", size: "medium", at: "tl", col: 0, row: 0 },
            { key: "weather", size: "medium", at: "tl", col: 0, row: 1 },
            { key: "monthCalendar", size: "medium", at: "tl", col: 0, row: 2 },
            { key: "systemMonitor", size: "medium", at: "tr", col: 0, row: 0 },
            { key: "mediaControls", size: "medium", at: "tr", col: 0, row: 1 },
            { key: "controls", size: "medium", at: "tr", col: 0, row: 2 } ] },
        { id: "factory:focus", name: Translation.tr("Focus"), material: "solid", tint: "mono", widgets: [
            { key: "clock", size: "small", at: "tr", col: 1, row: 0 },
            { key: "timers", size: "small", at: "tr", col: 0, row: 0 },
            { key: "todo", size: "large", at: "tr", col: 0, row: 1 } ] },
        { id: "factory:listening", name: Translation.tr("Listening"), material: "glass", tint: "wallpaper", widgets: [
            { key: "mediaControls", size: "large", at: "bl", col: 0, row: 0 },
            { key: "weather", size: "small", at: "bl", col: 2, row: 0 },
            { key: "clock", size: "small", at: "bl", col: 2, row: 1 } ] },
        { id: "factory:bare", name: Translation.tr("Bare"), material: "clear", tint: "system", widgets: [
            { key: "clock", size: "medium", at: "bl", col: 0, row: 0 } ] }
    ]
    function isFactory(id: string): bool { return String(id).startsWith("factory:") }
    function cellOf(): var {
        const d = Number(Config.options?.iris?.appearance?.density ?? 1)
        return { u: Math.round(170 * d), g: Math.round(16 * d), side: Math.round(36 * d), top: Math.round(72 * d), bottom: Math.round(104 * d) }
    }
    function spanOf(size: string, c: var): var {
        return { w: size === "small" ? c.u : c.u * 2 + c.g, h: size === "large" ? c.u * 2 + c.g : c.u }
    }
    // Where a factory widget sits on a screen of w x h, in its pixels.
    function factorySpot(entry: var, w: real, h: real): var {
        const c = root.cellOf()
        const span = root.spanOf(entry.size, c)
        const right = entry.at === "tr" || entry.at === "br"
        const bottom = entry.at === "bl" || entry.at === "br"
        const x = right ? w - c.side - entry.col * (c.u + c.g) - span.w : c.side + entry.col * (c.u + c.g)
        const y = bottom ? h - c.bottom - entry.row * (c.u + c.g) - span.h : c.top + entry.row * (c.u + c.g)
        return { x: Math.max(0, Math.round(x)), y: Math.max(0, Math.round(y)) }
    }
    // The snapshot a factory desktop means here: its widgets on every screen, the rest put away, its look.
    function factoryValues(preset: var): var {
        const values = ({})
        const keys = preset.widgets.map(entry => entry.key)
        for (const path of DesktopEditHistory.trackedPaths())
            if (path.endsWith(".enable"))
                values[path] = keys.includes(path.split(".")[2]) && !path.includes(".custom.")
        const records = DesktopEditHistory.plain(Config.options?.background?.widgets?.outputOverrides ?? [])
        const out = (Array.isArray(records) ? records : []).filter(record => !Quickshell.screens.some(screen => screen.name === record?.output))
        for (const screen of Quickshell.screens) {
            const old = (Array.isArray(records) ? records : []).find(record => record?.output === screen.name) ?? {}
            const widgets = ({})
            for (const entry of preset.widgets) {
                const spot = root.factorySpot(entry, screen.width, screen.height)
                widgets[entry.key] = Object.assign({}, old.widgets?.[entry.key] ?? {}, { x: spot.x, y: spot.y,
                    placementStrategy: "free", "sizeClass": entry.size, sizeClass: entry.size, enable: true })
            }
            // This size's remembered places would win over the new ones; other sizes keep theirs.
            const layouts = Object.assign({}, old.layouts ?? {})
            delete layouts[screen.width + "x" + screen.height]
            out.push(Object.assign({}, old, { output: screen.name, width: screen.width, height: screen.height,
                layoutVersion: old.layoutVersion ?? 1, widgets: widgets, layouts: layouts }))
        }
        values["background.widgets.outputOverrides"] = out
        values["background.widgets.stacks"] = []
        values["iris.widgets.material"] = preset.material
        values["iris.widgets.tint"] = preset.tint
        return values
    }
    function find(id: string): var { return root.presets.find(preset => preset.id === id) ?? root.factory.find(preset => preset.id === id) ?? null }
    function nextName(): string {
        let n = root.presets.length + 1
        while (root.presets.some(preset => preset.name === Translation.tr("Desktop %1").arg(n))) n++
        return Translation.tr("Desktop %1").arg(n)
    }
    function save(name: string): string {
        const clean = String(name ?? "").trim() || root.nextName()
        const id = String(Date.now())
        root.presets = [{ id: id, name: clean, at: Date.now(), values: DesktopEditHistory.snapshot() }]
            .concat(root.presets).slice(0, root.most)
        root.write()
        DesktopEditHistory.say(Translation.tr("Saved as %1").arg(clean))
        return id
    }
    function wear(id: string): void {
        const preset = root.find(id)
        if (!preset) return
        Config.setNestedValues(root.isFactory(id) ? root.factoryValues(preset) : preset.values)
        DesktopEditHistory.say(Translation.tr("Wearing %1").arg(preset.name))
    }
    function rename(id: string, name: string): void {
        const clean = String(name ?? "").trim()
        if (!clean) return
        root.presets = root.presets.map(preset => preset.id === id ? Object.assign({}, preset, { name: clean }) : preset)
        root.write()
    }
    function remove(id: string): void {
        const preset = root.find(id)
        if (!preset) return
        const at = root.presets.indexOf(preset)
        root.presets = root.presets.filter(entry => entry.id !== id)
        root.write()
        Undo.offer(Translation.tr("Removed %1").arg(preset.name), () => {
            if (root.find(id)) return
            const back = root.presets.slice()
            back.splice(Math.min(at, back.length), 0, preset)
            root.presets = back
            root.write()
        })
    }
    // The one the desktop wears now, if any: the same snapshot, value for value.
    function wornId(): string {
        const snap = DesktopEditHistory.snapshot()
        const now = JSON.stringify(snap)
        const saved = root.presets.find(preset => JSON.stringify(Object.assign(DesktopEditHistory.snapshot(), preset.values)) === now)?.id ?? ""
        if (saved.length > 0) return saved
        // A factory desktop is worn while exactly its widgets are out in its look; where they settled is theirs.
        const out = Object.keys(snap).filter(path => path.endsWith(".enable") && snap[path] === true).map(path => path.split(".")[2]).sort()
        return root.factory.find(preset => JSON.stringify(preset.widgets.map(entry => entry.key).sort()) === JSON.stringify(out)
            && snap["iris.widgets.material"] === preset.material && snap["iris.widgets.tint"] === preset.tint)?.id ?? ""
    }
    // Where its widgets sit on one screen, as fractions of that screen: [{ key, x, y, size }].
    function placesOn(id: string, outputName: string): var {
        if (root.isFactory(id)) {
            const screen = Quickshell.screens.find(entry => entry.name === outputName) ?? Quickshell.screens[0]
            const w = screen?.width ?? 1920
            const h = screen?.height ?? 1080
            return root.find(id).widgets.map(entry => {
                const spot = root.factorySpot(entry, w, h)
                return { key: entry.key, x: spot.x / w, y: spot.y / h, size: entry.size }
            })
        }
        const values = root.find(id)?.values ?? {}
        const records = values["background.widgets.outputOverrides"] ?? []
        // Saved on another screen (or one renamed since): that screen's layout, scaled to this one.
        const list = (Array.isArray(records) ? records : []).filter(entry => !String(entry?.output ?? "").startsWith("lock:"))
        const record = list.find(entry => String(entry?.output ?? "") === outputName) ?? list[0] ?? null
        const w = Number(record?.width ?? 0)
        const h = Number(record?.height ?? 0)
        const out = []
        if (!(w > 0 && h > 0)) return out
        const widgets = record.widgets ?? {}
        for (const key of Object.keys(widgets)) {
            const place = widgets[key] ?? {}
            const on = place.enable ?? values["background.widgets." + key + ".enable"] ?? false
            if (on && Number.isFinite(Number(place.x)) && Number.isFinite(Number(place.y)))
                out.push({ key: key, x: Number(place.x) / w, y: Number(place.y) / h, size: String(place["sizeClass"] ?? place.sizeClass ?? "medium") })
        }
        return out
    }

    function write(): void { presetFile.setText(JSON.stringify(root.presets)) }
    readonly property FileView presetFile: FileView {
        path: Directories.statePath + "/user/desktop-presets.json"
        printErrors: false
        onLoaded: { try { const list = JSON.parse(text()); if (Array.isArray(list)) root.presets = list } catch (e) {} }
    }
}
