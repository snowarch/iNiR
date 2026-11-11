pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import Quickshell
import qs
import qs.modules.common
import qs.services
import "japaneseTypography/JapaneseTypographyPresets.js" as JapanesePresets
import "root:modules/common/widgets/GlyphArt.js" as Glyphs

// Every desktop widget's options as rows: Settings and the edit sheets draw them. A widget lists its own in `options` of
// its widget.json and a family its rows in `widgetOptions` of its plugin.json; this file adds what every widget carries
// (being on the desktop, size, design, plate, position) and answers the conditions. A row names its widget and key: it
// reads what the screen in front shows and writes the base value with every screen's own copy cleared
// (`DesktopWidgetLayout.setEverywhere`), so a value set from the quick controls never silently beats the row.
QtObject {
    id: root

    readonly property string output: String((GlobalStates.focusedScreen ?? Quickshell.screens[0])?.name ?? "")
    // Widgets the active family draws a face for, and the ones on by default.
    readonly property var faced: DesktopWidgetRegistry.entries.filter(entry => DesktopWidgetRegistry.hasFace(entry.key, Plugins.active))
        .map(entry => entry.key)
    readonly property var onByDefault: DesktopWidgetRegistry.entries.filter(entry => entry.defaultOn).map(entry => entry.key)

    function value(widget: string, key: string, fallback: var): var {
        Config.revision
        return DesktopWidgetLayout.value(root.output, widget, key, fallback)
    }
    function on(widget: string): bool {
        Config.revision
        return DesktopWidgetLayout.effectiveEnabled(widget, root.onByDefault.includes(widget))
    }
    function resolved(widget: string): var {
        Config.revision
        return DesktopWidgetDesign.resolve(widget, String(root.value(widget, DesktopWidgetDesign.spec.key, "auto")), root.faced.includes(widget))
    }
    // The family's face draws it.
    function face(widget: string): bool { return root.on(widget) && root.resolved(widget).face }
    // The widget's own Material drawing, with no design laid over it: its style rows mean something.
    function material(widget: string): bool {
        const design = root.resolved(widget)
        return root.on(widget) && !design.face && design.design === "individual"
    }
    // Not the face (Material, iNstrument or Readout): the shared card and its plate.
    function plain(widget: string): bool { return root.on(widget) && !root.resolved(widget).face }
    // What iNstrument or Readout lays over the widget's own keys, or the keys a face design draws its own way
    // (`ignores` in its `faces` entry): those rows have nothing to change while it does.
    function overlay(widget: string): var {
        const design = root.resolved(widget)
        if (!design.face)
            return DesktopWidgetDesign.values(widget, design.design)
        const own = ({})
        if (!root.faced.includes(widget))
            return own
        for (const key of DesktopWidgetDesign.faceDesignOf(design.wear)?.ignores ?? [])
            own[key] = null
        return own
    }
    function effective(widget: string, key: string, fallback: var): var {
        const over = root.overlay(widget)
        return over[key] !== undefined ? over[key] : root.value(widget, key, fallback)
    }
    function is(widget: string, key: string, fallback: var, wanted: var): bool {
        return String(root.effective(widget, key, fallback)) === String(wanted)
    }

    readonly property var groups: DesktopWidgetRegistry.groups
    // Clusters of the section's column, in the order people look for them.
    readonly property var clusters: [
        { caption: "Every widget", groups: ["Arranging", "Power saving"] },
        { caption: "Time", groups: ["Clock", "World clock", "Month Calendar", "Upcoming Events", "Date badge", "Day progress", "Timers", "System uptime"] },
        { caption: "Music", groups: ["Media Controls", "Lyrics", "Visualizer"] },
        { caption: "System", groups: ["System Monitor", "Battery", "Controls", "Screen time", "Weather", "News"] },
        { caption: "Yours", groups: ["Notes", "Todo", "User card", "Palette", "Custom image", "Image converter"] },
        { caption: "Art", groups: ["Decorative shape", "Japanese Typography", "Editorial", "Mascot"] }
    ]
    readonly property var order: root.clusters.reduce((all, cluster) => all.concat(cluster.groups), [])

    function row(widget: string, key: string, label: string, kind: string, fallback: var, extra: var): var {
        const spec = Object.assign({ section: "widgets", group: root.groups[widget], page: "widget", widget: widget, key: key,
            path: "background.widgets." + widget + "." + key, label: label, kind: kind, fallback: fallback }, extra ?? {})
        // A run of switches is the wall the page must not be: a widget's switches refine it, so they wait behind its
        // Fine-tune unless a row says `tune: false` (the plate, which people come to turn off).
        if (spec.tune === undefined && kind === "switch") spec.tune = true
        // `shell`: the row shows a shell key every surface reads (the weather's place), not one of the widget's own.
        if (spec.shell) spec.path = spec.shell
        const when = spec.when
        spec.showIf = () => root.on(widget) && root.overlay(widget)[key] === undefined && (when === undefined || when())
        delete spec.when
        return spec
    }
    function choices(list: var): var {
        return list.map(entry => ({ label: entry[1], value: entry[0], glyph: entry[2] }))
    }
    // The colours a `colour` row offers when its manifest lists none: nobody types a hex code.
    readonly property var inks: Glyphs.INKS
    // A `file` or `folder` row opens the system's chooser: nobody types a path.
    property var _picking: null
    readonly property FileDialog filePicker: FileDialog {
        title: Translation.tr(String(root._picking?.label ?? ""))
        fileMode: FileDialog.OpenFile
        currentFolder: Directories.pictures
        nameFilters: root._picking?.filters ?? [Translation.tr("Images and animations") + " (*.png *.jpg *.jpeg *.webp *.gif *.apng *.svg)",
            Translation.tr("All files") + " (*)"]
        onAccepted: if (root._picking) root.write(root._picking, root._path(selectedFile))
    }
    readonly property FolderDialog folderPicker: FolderDialog {
        title: Translation.tr(String(root._picking?.label ?? ""))
        currentFolder: Directories.pictures
        onAccepted: if (root._picking) root.write(root._picking, root._path(selectedFolder))
    }
    function _path(url: var): string { return decodeURIComponent(String(url).replace(/^file:\/\//, "")) }
    function pick(spec: var): void {
        root._picking = spec
        if (spec.picks === "folder") root.folderPicker.open()
        else root.filePicker.open()
    }
    // What a row says under its name: a chooser's row names what was chosen.
    function captionOf(spec: var): string {
        if (!spec.picks) return String(spec.caption ?? "")
        const chosen = String(root.read(spec) ?? "")
        return chosen.length > 0 ? chosen.replace(/\/+$/, "").split("/").pop() : Translation.tr("Nothing chosen")
    }

    // What every widget carries: being on the desktop, its design, its plate and where it sits.
    function opening(widget: string): var {
        return [{ section: "widgets", group: root.groups[widget], widget: widget, widgetEnable: true, path: "background.widgets." + widget + ".enable",
            label: "On the desktop", kind: "switch", fallback: root.onByDefault.includes(widget),
            keywords: ["show", "add", "remove", "enable", "widget", "desktop", "mostrar"] }]
    }
    function closing(widget: string, plate: bool): var {
        const designs = [["auto", "Same as every widget"]]
        if (root.faced.includes(widget)) {
            designs.push([DesktopWidgetDesign.faceDesign, DesktopWidgetDesign.spec.faceLabel])
            for (const entry of DesktopWidgetDesign.faceDesigns) {
                if (DesktopWidgetDesign.drawsIn(widget, entry.value))
                    designs.push([entry.value, entry.label, entry.glyph])
            }
        }
        designs.push(["material", "Material"])
        if (DesktopWidgetDesign.supports(widget)) designs.push(["instrument", "iNstrument"], ["readout", "Readout"])
        const out = [
            root.row(widget, DesktopWidgetDesign.spec.key, "Design", "choice", "auto", { page: "look", tune: true, choices: root.choices(designs),
                when: () => designs.length > 2, keywords: ["design", "look", "style", "material", "instrument", "readout"] })
        ]
        out.push(...(root.familyOptions["*"] ?? []).map(option => root._row(widget, option)))
        const look = { page: "look" }
        // A widget that draws its own card in Material (plate false) still wears the family's plate under its face; one
        // with no face of the family keeps drawing its own, and has no plate to set.
        const plated = () => root.on(widget) && (plate || root.face(widget) && root.faced.includes(widget))
        out.push(
            root.row(widget, "showBackground", "Background", "switch", root.bareDefault(widget), { page: "look", tune: false, when: plated,
                apply: next => root.plateValues(next, root.value(widget, "backgroundOpacity", 0.16)),
                description: "The plate behind the widget.", keywords: ["background", "plate", "card", "surface", "fondo", "superficie"] }),
            root.row(widget, "showBorder", "Outline", "switch", root.bareDefault(widget), { page: "look", when: plated,
                apply: next => Object.assign({ showBorder: next }, next && Number(root.value(widget, "borderOpacity", 0.08)) <= 0 ? { borderOpacity: 0.2 } : {},
                    next && Number(root.value(widget, "borderWidth", 1)) <= 0 ? { borderWidth: 1 } : {}),
                keywords: ["outline", "border", "line", "borde"] }),
            root.row(widget, "borderOpacity", "Outline strength", "range", 0.08, { page: "look", tune: true, min: 0, max: 1, step: 0.02, scale: 100, unit: " %",
                when: () => plated() && Boolean(root.value(widget, "showBorder", root.plateDefault(widget))) }),
            root.row(widget, "borderWidth", "Outline width", "range", 1, { page: "look", tune: true, min: 0, max: 8, step: 1, unit: " px",
                when: () => plated() && Boolean(root.value(widget, "showBorder", root.plateDefault(widget))) }))
        if (plate) out.push(
            root.row(widget, "backgroundOpacity", "Background strength", "range", root.bareDefault(widget) ? 0.16 : 0, { page: "look", min: 0, max: 1, step: 0.02, scale: 100, unit: " %",
                when: () => root.plain(widget) && Boolean(root.value(widget, "showBackground", root.plateDefault(widget))) }),
            // Settings kept these two; the edit sheet lost them when it took over the widget manager (his 10-30)
            root.row(widget, "useBlur", "Blur background", "switch", false, { page: "look", tune: true,
                when: () => root.plain(widget) && Boolean(root.value(widget, "showBackground", root.plateDefault(widget))),
                keywords: ["blur", "frosted", "glass", "desenfoque"] }),
            root.row(widget, "blurStrength", "Blur strength", "range", 100, { page: "look", tune: true, min: 0, max: 150, step: 5, unit: " %",
                when: () => root.plain(widget) && Boolean(root.value(widget, "showBackground", root.plateDefault(widget)))
                    && Boolean(root.value(widget, "useBlur", false)),
                keywords: ["blur", "frost", "glass", "strength", "desenfoque"] }),
            root.row(widget, "cornerRadius", "Corners", "range", -1, { page: "look", tune: true, min: -1, max: 48, step: 1, unit: " px", lowLabel: "Theme",
                when: () => root.plain(widget) && (Boolean(root.value(widget, "showBackground", root.plateDefault(widget)))
                    || Boolean(root.value(widget, "showBorder", root.plateDefault(widget)))),
                keywords: ["corner", "radius", "round", "esquinas", "redondeo"] }))
        out.push(
            root.row(widget, "colorMode", "Ink", "choice", "auto", { page: "look", tune: true, when: () => root.plain(widget),
                choices: root.choices([["auto", "Auto"], ["light", "Light ink"], ["dark", "Dark ink"]]), keywords: ["ink", "text", "colour", "color", "contrast"] }),
            root.row(widget, "widgetScale", "Scale", "range", 100, { page: "arrange", min: 50, max: 200, step: 10, unit: " %", keywords: ["size", "scale", "zoom", "tamaño"] }),
            root.row(widget, "widgetOpacity", "Opacity", "range", 100, { page: "look", min: 10, max: 100, step: 5, unit: " %", when: () => root.plain(widget) }),
            root.row(widget, "dim", "Dimming", "range", 0, { page: "look", min: 0, max: 100, step: 5, unit: " %", zeroLabel: "Off", when: () => root.plain(widget) }),
            root.row(widget, "placementStrategy", "Position", "choice", "free", { page: "arrange", tune: true,
                choices: root.choices([["free", "Free position"], ["leastBusy", "Quietest spot"], ["mostBusy", "Busiest spot"]]),
                keywords: ["position", "place", "auto", "quiet", "busy", "posición"] }),
            root.row(widget, "locked", "Lock position", "switch", false, { page: "arrange", tune: true, keywords: ["lock", "pin", "fixed", "bloquear"] }))
        return out
    }
    // Material's medium and large weather is the forecast face: the pill's own sizes and parts mean nothing there.
    function weatherForecast(): bool { return root.holds("weather", "forecast") }
    // Switched on over a strength of 0 (a bare widget's default) the plate stayed invisible: it comes with one.
    function plateValues(on: bool, strength: var): var {
        return on && Number(strength) <= 0 ? { showBackground: true, backgroundOpacity: 0.16 } : { showBackground: on }
    }
    // The rows are built once per registry: a fallback read there made every Settings row rebuild when the shared
    // material changed (1.5 s frozen). Built with the bare default; `read` asks the material when it reads.
    function bareDefault(widget: string): bool { return !(DesktopWidgetRegistry.byKey[widget]?.bare ?? false) }
    function plateDefault(widget: string): bool {
        return DesktopWidgetLook.look.plateByDefault({ bare: DesktopWidgetRegistry.byKey[widget]?.bare ?? false, familyFaced: root.face(widget) })
    }
    // Every widget at once, from its own row (so the plate still comes on with a visible strength). The state reads the
    // widgets on the desktop: one shared value, or "mixed". Background and outline mean one thing on every design.
    function _everyRows(key: string): var {
        const shared = ["showBackground", "showBorder"].includes(key)
        return root.widgetRows.concat(root.customRows).filter(spec => spec.key === key && spec.widget
            && (shared || !root.resolved(spec.widget).face) && spec.showIf() && !root._bare(spec.widget, key))
    }
    // A widget drawn bare by default (the clock, the art) counts for its plate only while it shows one: showing every
    // background put a card behind the mascot, and the factory desktop read as mixed. Drawn by the family's face it is a
    // card like every other one (his 11-07: showing every background left the clock and the day bare under Prism).
    function _bare(widget: string, key: string): bool {
        const plate = key === "showBorder" ? "showBorder" : ["showBackground", "backgroundOpacity"].includes(key) ? "showBackground" : ""
        return plate !== "" && Boolean(DesktopWidgetRegistry.byKey[widget]?.bare) && !root.face(widget)
            && !Boolean(root.value(widget, plate, false))
    }
    function everyState(key: string): string {
        Config.revision
        const seen = root._everyRows(key).filter(spec => root.on(spec.widget)).map(spec => String(root.read(spec)))
        if (seen.length === 0)
            return ""
        return seen.every(v => v === seen[0]) ? seen[0] : "mixed"
    }
    function setEvery(key: string, next: var): int {
        const entries = root._everyRows(key).map(spec => [spec.widget, spec.apply ? spec.apply(next) : ({ [key]: next })])
        if (entries.length > 0)
            DesktopWidgetLayout.setEverywhereMany(entries)
        return entries.length
    }
    function size(widget: string): var {
        const sizes = DesktopWidgetRegistry.sizesOf(widget)
        const labels = { small: "Small", medium: "Medium", large: "Large" }
        return root.row(widget, "sizeClass", "Size", "choice", sizes[0] ?? "medium", { when: () => sizes.length > 1,
            choices: root.choices(["small", "medium", "large"].filter(size => sizes.includes(size)).map(size => [size, labels[size]])),
            keywords: ["size", "small", "medium", "large", "tamaño"] })
    }
    // A family's own rows for a widget (`widgetOptions` in its plugin.json; "*": for every widget it wears).
    readonly property var familyOptions: Plugins.manifests[Plugins.active]?.widgetOptions ?? ({})
    readonly property var widgetRows: DesktopWidgetRegistry.entries.reduce((all, entry) => all.concat(root._rowsOf(entry)), [])
    function _rowsOf(entry: var): var {
        const widget = entry.key
        const rows = list => (list ?? []).map(option => root._row(widget, option))
        return root.opening(widget).concat([root.size(widget)], rows(root.familyOptions[widget]), rows(entry.options),
            root.closing(widget, entry.plate !== false))
    }
    // A person's own widget: the `options` of its widget.json, the same rows a built-in widget lists (order, pages,
    // conditions, choices, colours, choosers). One from before that only has `configKeys` gets a row per key.
    readonly property var customRows: CustomWidgets.widgets.reduce((all, entry) => all.concat(
        root._customRows(entry), root.closing("custom." + entry.id, true)), [])
    function _customRows(entry: var): var {
        const widget = "custom." + entry.id
        if ((entry.options ?? []).length > 0)
            return [root.size(widget)].concat(entry.options.map(option => root._row(widget, Object.assign({ restorable: true }, option))), [
                root.row(widget, "restoreDefaults", "Restore defaults", "action", undefined, { button: "Restore", page: "look",
                    run: () => root.restore(widget), when: () => root.changed(widget),
                    keywords: ["reset", "default", "restore", "restaurar", "predeterminado"] })])
        return Object.keys(entry.configKeys ?? {}).map(key => root._customRow(widget, key, entry.configKeys[key]))
    }
    function _customRow(widget: string, key: string, option: var): var {
        const number = option.type === "int" || option.type === "real"
        const ranged = number && option.min !== undefined && option.max !== undefined
        const listed = option.type === "string" && Array.isArray(option.options) && option.options.length > 0
        return root.row(widget, key, option.label ?? key, option.type === "bool" ? "switch" : ranged ? "range" : listed ? "choice" : "text", option.default,
            Object.assign({ restorable: true }, ranged ? { min: option.min, max: option.max, step: option.step ?? (option.type === "int" ? 1 : 0.1) } : {},
                listed ? { choices: option.options.map(one => typeof one === "object" ? { label: String(one.label ?? one.displayName ?? one.value), value: one.value ?? one.label }
                    : { label: String(one), value: one }) } : {}))
    }
    // A person's widget back to what its manifest says, every option at once.
    function _restorable(widget: string): var {
        return root.customRows.filter(spec => spec.widget === widget && spec.restorable && spec.fallback !== undefined && !spec.shell)
    }
    function changed(widget: string): bool {
        Config.revision
        return root._restorable(widget).some(spec => String(root.read(spec)) !== String(spec.fallback))
    }
    function restore(widget: string): void {
        const values = ({})
        for (const spec of root._restorable(widget)) values[spec.key] = spec.fallback
        DesktopWidgetLayout.setEverywhere(widget, values)
    }
    // A sheet's page of a widget's rows, minus the keys it draws itself.
    function sheetRows(widget: string, page: string, exclude: var): var {
        Config.revision
        return root.widgetRows.concat(root.customRows).filter(spec => spec.widget === widget && spec.page === page && !spec.widgetEnable
            && !(exclude ?? []).includes(spec.key))
    }
    function _row(widget: string, option: var): var {
        const extra = Object.assign({}, option)
        for (const field of ["key", "label", "type", "default", "when", "sets", "write"])
            delete extra[field]
        if (option.choices)
            extra.choices = root.choices(option.choices)
        // A colour is picked from swatches; a file or a folder from the system's chooser.
        let kind = option.type
        if (kind === "colour") {
            kind = "choice"
            extra.choices = (option.choices ?? root.inks).map(entry => ({ label: entry[1], value: entry[0], colour: entry[0], swatch: entry[0] }))
        } else if (kind === "file" || kind === "folder") {
            extra.picks = kind
            extra.button = "Choose"
            kind = "action"
        }
        if (option.when !== undefined)
            extra.when = () => root.holds(widget, option.when)
        const writer = root.writers[option.write]
        if (writer)
            extra.apply = next => writer(widget, option.key, next)
        else if (option.sets)
            extra.apply = next => root._sets(widget, option, next)
        const spec = root.row(widget, option.key, option.label, kind, option.default, extra)
        if (spec.picks) spec.run = () => root.pick(spec)
        return spec
    }
    // A manifest's `when`: "face", "material", "plain", a name from its `conditions`, { key: value or values }, { key:
    // { above: n } }, { key: { is: value, otherwise: value while unset } }, a list (all of them), { any: [...] }, { not: ... },
    // { wears: design or designs } (which of the family's face designs draws it), { widget: key or keys } (which widget).
    function holds(widget: string, when: var): bool {
        if (when === undefined)
            return true
        if (Array.isArray(when))
            return when.every(part => root.holds(widget, part))
        if (typeof when === "string") {
            if (when === "face") return root.face(widget)
            if (when === "material") return root.material(widget)
            if (when === "plain") return root.plain(widget)
            return root.holds(widget, (DesktopWidgetRegistry.byKey[widget] ?? DesktopWidgetRegistry.customEntry(widget))?.conditions?.[when])
        }
        if (when.any)
            return when.any.some(part => root.holds(widget, part))
        if (when.not !== undefined)
            return !root.holds(widget, when.not)
        if (when.wears !== undefined)
            return root.face(widget) && root.faced.includes(widget) && [].concat(when.wears).includes(root.resolved(widget).wear)
        if (when.widget !== undefined)
            return [].concat(when.widget).includes(widget)
        return Object.keys(when).every(key => {
            const wanted = when[key]
            const seen = root.effective(widget, key, wanted?.otherwise !== undefined ? wanted.otherwise : root._default(widget, key))
            return root._matches(seen, wanted?.is !== undefined ? wanted.is : wanted)
        })
    }
    function _matches(seen: var, wanted: var): bool {
        if (Array.isArray(wanted))
            return wanted.some(one => root._matches(seen, one))
        if (typeof wanted === "boolean")
            return Boolean(seen) === wanted
        if (wanted?.above !== undefined)
            return Number(seen) > wanted.above
        return String(seen) === String(wanted)
    }
    function _default(widget: string, key: string): var {
        if (key === "sizeClass")
            return DesktopWidgetRegistry.sizesOf(widget)[0]
        if (key === "showBackground" || key === "showBorder")
            return root.plateDefault(widget)
        const custom = widget.startsWith("custom.") ? DesktopWidgetRegistry.customEntry(widget) : null
        if (custom)
            return (custom.options ?? []).find(row => row.key === key)?.default ?? custom.configKeys?.[key]?.default ?? custom.defaultConfig?.[key]
        const entry = DesktopWidgetRegistry.byKey[widget]
        const option = (entry?.options ?? []).concat(root.familyOptions[widget] ?? []).find(row => row.key === key)
        return option ? option.default : entry?.defaultConfig?.[key]
    }
    // A choice that writes more: `sets` by value; { if, to } changes a key only while it holds that value.
    function _sets(widget: string, option: var, next: var): var {
        const out = { [option.key]: next }
        const also = option.sets[String(next)] ?? {}
        for (const key of Object.keys(also)) {
            const entry = also[key]
            if (entry?.to === undefined)
                out[key] = entry
            else if (String(root.value(widget, key, root._default(widget, key))) === String(entry.if))
                out[key] = entry.to
        }
        return out
    }
    // Japanese typography keeps a preset's values together, so its rows write through it (`write` in the manifest).
    readonly property string _japanese: "background.widgets.japaneseTypography"
    readonly property var writers: ({
        "japanese.layout": (widget, key, next) => root.relative(widget, JapanesePresets.composition(root._japanese, next)),
        "japanese.type": (widget, key, next) => root.relative(widget, JapanesePresets.font(root._japanese, next)),
        "japanese.colours": (widget, key, next) => next === "custom" ? { palettePreset: "custom", paletteMode: "manual" }
            : root.relative(widget, JapanesePresets.palette(root._japanese, next)),
        "japanese.composition": (widget, key, next) => root.relative(widget, JapanesePresets.setValue(root._japanese, key, next, "composition")),
        "japanese.font": (widget, key, next) => root.relative(widget, JapanesePresets.setValue(root._japanese, key, next, "font")),
        "japanese.palette": (widget, key, next) => root.relative(widget, JapanesePresets.setValue(root._japanese, key, next, "palette"))
    })
    // What a row shows and what it writes (IrisOptions.currentValue / commit route `spec.widget` rows here).
    function read(spec: var): var {
        if (spec.widgetEnable) return root.on(spec.widget)
        if (spec.shell) return Config.getNestedValue(spec.shell, spec.fallback)
        if (spec.key === "sizeClass")
            return root.value(spec.widget, "sizeClass", undefined) ?? DesktopWidgetStacks.reported[spec.widget]?.size ?? spec.fallback
        const plate = ["showBackground", "showBorder"].includes(spec.key) ? root.plateDefault(spec.widget)
            : spec.key === "backgroundOpacity" ? (root.plateDefault(spec.widget) ? 0.16 : 0) : spec.fallback
        return root.value(spec.widget, spec.key, plate)
    }
    function write(spec: var, next: var): void {
        if (spec.widgetEnable) { DesktopWidgetLayout.setGloballyEnabled(spec.widget, Boolean(next)); return }
        if (spec.shell) { Config.setNestedValue(spec.shell, next); return }
        let value = next
        if (spec.key === "timezones") value = Array.from(next ?? []).slice(0, WorldClock.maxTimezones)
        const values = spec.apply ? spec.apply(value) : ({})
        if (!spec.apply) values[spec.key] = value
        DesktopWidgetLayout.setEverywhere(spec.widget, values)
    }
    function choicesFor(source: string): var {
        if (source === "timezones") return WorldClock.comboModel.map(entry => ({ label: entry.label, value: entry.tz }))
        if (source === "shapes") return DesktopWidgetShapes.choices.map(entry => ({ label: entry.label, value: entry.value }))
        if (source === "mascotPoses") return MascotCatalog.desktopWidgetPosesForGroup(String(root.value("mascot", "poseFilter", "all")))
            .map(pose => ({ label: String(pose).replace(/[-_]/g, " ").replace(/^./, first => first.toUpperCase()), value: pose }))
        if (source === "screens") return Quickshell.screens.map(screen => ({ label: String(screen.name), value: String(screen.name) }))
        return []
    }
    // A preset's updates come as full paths; rows write keys relative to their widget.
    function relative(widget: string, updates: var): var {
        const prefix = "background.widgets." + widget + "."
        const out = ({})
        for (const path of Object.keys(updates)) out[path.startsWith(prefix) ? path.slice(prefix.length) : path] = updates[path]
        return out
    }

    // Arranging and power: what every widget shares.
    readonly property var sharedRows: [
        { section: "widgets", group: "Arranging", label: "Edit desktop widgets", description: "Carry a widget near another and it lines up; drop it on one that is taken and it finds the nearest free spot. Hold Alt to place it freely.",
            kind: "action", button: "Edit", run: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.setWidgetEditMode(true) },
            keywords: ["arrange", "move", "edit", "drag", "editar", "mover"] },
        { section: "widgets", group: "Arranging", label: "Snap", description: "To the grid, the screen's edges and centre, and the widgets around.", path: "background.widgets.editGrid.snap", kind: "switch", fallback: true,
            keywords: ["snap", "magnet", "grid", "align", "guides", "imán", "alinear"] },
        { section: "widgets", group: "Arranging", label: "Grid", path: "background.widgets.editGrid.size", visibleWhen: "background.widgets.editGrid.snap", kind: "range", fallback: 32, min: 8, max: 128, step: 8, unit: " px" },
        { section: "widgets", group: "Arranging", label: "Fade with windows", description: "Widgets fade when windows are open on the workspace.", path: "background.widgets.dynamicOpacity", kind: "range", fallback: 0, min: 0, max: 100, step: 10, unit: " %", zeroLabel: "Off",
            keywords: ["fade", "windows", "opacity", "hide"] },
        { section: "widgets", group: "Power saving", label: "Enable power saving", path: "background.widgets.powerSaving.enable", kind: "switch", fallback: true, keywords: ["power", "battery", "pause", "energía"] },
        { section: "widgets", group: "Power saving", label: "Pause on GameMode", tune: true, path: "background.widgets.powerSaving.pauseOnGameMode", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: true },
        { section: "widgets", group: "Power saving", label: "Pause on fullscreen", tune: true, path: "background.widgets.powerSaving.pauseOnFullscreen", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: true },
        { section: "widgets", group: "Power saving", label: "Pause when windows present", tune: true, path: "background.widgets.powerSaving.pauseWhenWindowsPresent", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: false },
        { section: "widgets", group: "Power saving", label: "Show paused effect", path: "background.widgets.powerSaving.showPausedEffect", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: false, tune: true }
    ]
    readonly property var rows: root.sharedRows.concat(root.widgetRows)

}
