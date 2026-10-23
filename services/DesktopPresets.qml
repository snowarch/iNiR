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

    function find(id: string): var { return root.presets.find(preset => preset.id === id) ?? null }
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
        Config.setNestedValues(preset.values)
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
        root.presets = root.presets.filter(entry => entry.id !== id)
        root.write()
        DesktopEditHistory.say(Translation.tr("Removed %1").arg(preset.name))
    }
    // The one the desktop wears now, if any: the same snapshot, value for value.
    function wornId(): string {
        const now = JSON.stringify(DesktopEditHistory.snapshot())
        return root.presets.find(preset => JSON.stringify(Object.assign(DesktopEditHistory.snapshot(), preset.values)) === now)?.id ?? ""
    }
    // Where its widgets sit on one screen, as fractions of that screen: [{ key, x, y, size }].
    function placesOn(id: string, outputName: string): var {
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
                out.push({ key: key, x: Number(place.x) / w, y: Number(place.y) / h, size: String(place["iris.size"] ?? "medium") })
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
