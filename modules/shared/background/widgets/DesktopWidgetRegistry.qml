pragma Singleton
pragma ComponentBehavior: Bound
import QtQml
import Quickshell
import Quickshell.Io
import qs.services

// Every built-in desktop widget. `widgets.list` holds them in the shelf's order and each `<key>/widget.json` says what
// one is; the edit shelf, the iRiS gallery and lock, Settings, the IPC and the sizes all read this.
//
// Adding a widget:
//   1. Its folder here, named as its key, with a qmldir and `<Name>Widget.qml` (an AbstractBackgroundWidget with
//      `configEntryName: "<key>"`), and its line in `widgets.list`.
//   2. Its `widget.json`. `main` is that file. `defaultConfig`: what a fresh instance starts with. `name` is what people call it (shelf, gallery), `group` its Settings
//      heading; both go to every catalogue in translations/. `lock`: offered on the lock screen and in the iRiS gallery.
//   `palette`: it has the semantic palette roles (`background.widgets.<key>.palette`). `sizes`: default first.
//      `face`: the name of the family faces that draw it (a family's part `widgetFace.<face>`). `faceOnly`: it draws
//      nothing of its own, so only a family with that part offers it.
//      `options`: its rows for Settings and the edit sheet (DesktopWidgetOptions has the `when` language). `bare`: it
//      stands with no plate by default (its `showBackground` and `showBorder` start off). `plate: false`: it draws its own card, so the plate rows leave.
//   3. Its config block in modules/common/Config.qml (`background.widgets.<key>`, `enable` at `defaultOn`).
//   4. A family's own face stays that family's, in its plugin.json parts; with `lock`, its Component in the family's lock.
// The iRiS gallery keeps its own order (IrisFaceData.order, a widget it lacks goes last).
Singleton {
    id: root

    property var entries: []

    // Read at once: the first frame of the desktop already needs each widget's size, and a folder model answers later.
    FileView {
        id: probe
        preload: false
        blockAllReads: true
        printErrors: false
    }
    function _readNow(file: string): string {
        probe.path = Quickshell.shellPath("modules/shared/background/widgets/" + file)
        probe.reload()
        return String(probe.text() ?? "")
    }
    Component.onCompleted: {
        const read = []
        for (const line of root._readNow("widgets.list").split("\n")) {
            const key = line.trim()
            if (key.length === 0) continue
            try {
                const entry = JSON.parse(root._readNow(`${key}/widget.json`))
                entry.key = key
                entry.file = Quickshell.shellPath(`modules/shared/background/widgets/${key}/${entry.main}`)
                read.push(entry)
            } catch (error) {
                console.warn("[DesktopWidgetRegistry] bad widget.json in", key, error)
            }
        }
        probe.path = ""
        root.entries = read
    }

    // Every size class on one grid; the family's density scales it.
    readonly property int unit: 176
    readonly property int gap: 16
    function footprint(size: string): size {
        return Qt.size(size === "small" ? root.unit : root.unit * 2 + root.gap, size === "large" ? root.unit * 2 + root.gap : root.unit)
    }
    // Extra mascots are the mascot; a person's own widget says its sizes in its manifest, or keeps the size it draws.
    function defaultsOf(key: string): var { return root.byKey[root.baseKey(key)]?.defaultConfig ?? ({}) }
    function baseKey(key: string): string { return String(key).startsWith("mascotInstances.") ? "mascot" : key }
    function sizesOf(key: string): var {
        if (String(key).startsWith("custom."))
            return root.customEntry(key)?.sizes ?? []
        return root.byKey[root.baseKey(key)]?.sizes ?? []
    }

    readonly property var keys: root.entries.map(entry => entry.key)
    readonly property var byKey: root.entries.reduce((all, entry) => { all[entry.key] = entry; return all }, ({}))
    readonly property var groups: root.entries.reduce((all, entry) => { all[entry.key] = entry.group; return all }, ({}))
    readonly property var lockKeys: root.entries.filter(entry => entry.lock).map(entry => entry.key)
    readonly property var paletteKeys: root.entries.filter(entry => entry.palette).map(entry => entry.key)
    // The shelf's aisles: what a widget is for, in the order people reach for them.
    readonly property var categoryOrder: ["today", "media", "system", "notes", "decor"]
    readonly property string customTint: "#5e5ce6"
    readonly property string fallbackTint: "#8e8e93"

    function has(key: string): bool { return root.byKey[key] !== undefined }
    // A widget with no face of its own exists only where a family draws it.
    function offered(key: string, family: string): bool {
        return !root.byKey[key]?.faceOnly || root.hasFace(key, family)
    }
    function hasFace(key: string, family: string): bool {
        const face = root.byKey[key]?.face ?? ""
        return face.length > 0 && Plugins.part(family, "widgetFace." + face).length > 0
    }
    function entriesFor(family: string): var { return root.entries.filter(entry => root.offered(entry.key, family)) }
    function entry(key: string): var { return root.byKey[key] ?? null }
    function nameOf(key: string): string { return root.byKey[key]?.name ?? key }
    // What people call it, on every sheet, tag and shelf.
    function customEntry(key: string): var { return CustomWidgets.widgets.find(widget => "custom." + widget.id === key) ?? null }
    function displayName(key: string): string {
        if (key.startsWith("custom."))
            return root.customEntry(key)?.name ?? key.slice(7)
        return Translation.tr(root.nameOf(root.baseKey(key)))
    }
    readonly property var sizeOrder: ["small", "medium", "large"]
    function groupOf(key: string): string { return root.byKey[key]?.group ?? key }
    function defaultOn(key: string): bool { return root.byKey[key]?.defaultOn ?? false }
    function glyph(key: string): string { return root.byKey[key]?.icon ?? "widgets" }
    function keywordsOf(key: string): string { return root.byKey[key]?.keywords ?? "" }
    function categoryOf(key: string): string { return root.byKey[key]?.category ?? "decor" }
    // A hub widget's aisle from its manifest (the hub says "time" where the shelf says "today").
    function customCategory(custom: var): string {
        const said = String(custom?.category ?? "") === "time" ? "today" : String(custom?.category ?? "")
        return root.categoryOrder.includes(said) ? said : "decor"
    }
    function customWords(custom: var): string { return ["hub", custom?.id ?? "", custom?.category ?? "", custom?.description ?? ""].join(" ") }
    function tint(key: string): string { return root.byKey[key]?.tint ?? (key.startsWith("custom.") ? root.customTint : root.fallbackTint) }
}
