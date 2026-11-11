pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

QtObject {
    id: root

    // A design overlays only presentation keys; stored sizes, content and each widget's own styles
    // stay in the config. Choosing a design moves every widget onto it and keeps the exceptions it
    // cleared in `background.widgets.designUndo`, so the change can be taken back.
    // The active family's designs (`widgetDesign` in its plugin.json): the key one widget picks with, the key they all
    // share, the design that is its own faces if it has them, and what it calls the base drawing.
    readonly property var spec: Plugins.manifests[Plugins.active]?.widgetDesign
        ?? ({ key: "design", shared: "background.widgets.design", plain: "individual", choices: ["individual"] })
    readonly property string faceDesign: root.spec.face ?? ""
    // A design the active family wears over the person's shared pick while something of its own decides it (an iRiS
    // Design that brings its widgets' faces): `{ family, design }`, set by that family. It counts only while that family
    // is the active one, so nothing clears it on the way out (a write while a reload tore the shell down redrew every
    // face over a look already gone). Their key is never written: taking the Design off gives their pick back.
    property var worn: null
    readonly property string wornDesign: root.worn?.family === Plugins.active ? String(root.worn?.design ?? "") : ""
    readonly property string shared: {
        if (root.spec.choices.includes(root.wornDesign)) return root.wornDesign
        void Config.revision
        const own = String(Config.getNestedValue(root.spec.shared, ""))
        return root.spec.choices.includes(own) ? own : root.faceDesign || root.spec.plain
    }
    readonly property string current: root.shared === "individual" ? "material" : root.shared
    readonly property var choices: [
        { label: "Individual", value: "individual", icon: "widgets" },
        { label: "iNstrument", value: "instrument", icon: "avg_pace" },
        { label: "Readout", value: "readout", icon: "view_agenda" }
    ]
    readonly property var instruments: ({
        clock: { style: "instrument" }, weather: { style: "dial" },
        systemMonitor: { displayMode: "instrument" }, battery: { displayMode: "instrument" },
        dayProgress: { style: "ring" }, notes: { style: "instrument" },
        calendarUpcoming: { style: "instrument" }, monthCalendar: { style: "instrument" },
        todo: { style: "instrument" }, timers: { style: "instrument" },
        dateBadge: { style: "instrument" }, uptime: { style: "instrument" },
        worldClock: { style: "instrument" }, userCard: { style: "instrument" },
        newsTicker: { style: "instrument" }, mediaControls: { style: "instrument" },
        screenTime: { style: "instrument" }, controls: { style: "instrument" }
    })
    readonly property var readouts: ({
        clock: { style: "digital" }, systemMonitor: { displayMode: "text", showBackground: false, showBorder: false },
        dayProgress: { style: "arc", comet: false, hourLabels: false },
        dateBadge: { style: "instrument", instrumentMarks: false },
        worldClock: { style: "instrument", instrumentLayout: "rows" },
        monthCalendar: { style: "instrument", instrumentRule: false },
        todo: { style: "instrument", instrumentRules: false }
    })

    // Other designs the family's own faces draw (`faces` in `widgetDesign`: value, label, glyph, part, ignores): each
    // lists its faces as parts `<part>.<face>`; a widget it has no face for keeps the family's face. `ignores` names
    // the widget keys it draws its own way, whose rows hide while it draws.
    readonly property var faceDesigns: Array.from(root.spec.faces ?? [])
    function faceDesignOf(design: string): var { return root.faceDesigns.find(entry => entry.value === design) ?? null }
    function partOf(widget: string, design: string): string {
        const entry = root.faceDesignOf(design)
        const face = DesktopWidgetRegistry.entry(widget)?.face ?? ""
        return entry && face.length > 0 ? Plugins.part(Plugins.active, entry.part + "." + face) : ""
    }
    function drawsIn(widget: string, design: string): bool { return root.partOf(widget, design).length > 0 }

    function supports(widget: string): bool { return root.instruments[widget] !== undefined }
    function values(widget: string, design: string): var {
        if (design === "instrument") return root.instruments[widget] ?? ({})
        if (design === "readout") return root.readouts[widget] ?? root.instruments[widget] ?? ({})
        return ({})
    }

    // What one widget draws: `face` is the family's face, `design` the overlay on the base drawing, `wear` which of the
    // family's face designs draws it, `fallback` when the chosen design has nothing for this widget.
    function resolve(widget: string, own: string, hasFace: bool): var {
        const design = root.spec.choices.includes(own) ? own : root.shared
        const overlaid = ["instrument", "readout"].includes(design)
        if (overlaid && !root.supports(widget) && hasFace) return { face: true, design: "individual", wear: root.faceDesign, fallback: true }
        const faced = root.faceDesign.length > 0 && (design === root.faceDesign || root.faceDesignOf(design) !== null)
        const wear = !faced ? "" : design === root.faceDesign || root.drawsIn(widget, design) ? design : root.faceDesign
        return { face: faced, design: overlaid ? design : "individual", wear: wear, fallback: faced && wear !== design }
    }

    // Every place a widget keeps its own value for these keys: its entry, and each screen's.
    function scan(keys: var, isOwn: var): var {
        void Config.revision
        const found = []
        const base = Config.options?.background?.widgets ?? {}
        for (const widget of Object.keys(base)) {
            if (widget === "outputOverrides" || !base[widget] || typeof base[widget] !== "object" || Array.isArray(base[widget])) continue
            for (const key of keys) {
                const value = Config.getNestedValue("background.widgets." + widget + "." + key, undefined)
                if (isOwn(key, value)) found.push({ output: "", widget: widget, key: key, value: value })
            }
        }
        for (const record of (base.outputOverrides ?? [])) {
            const widgets = record?.widgets ?? {}
            for (const widget of Object.keys(widgets)) {
                for (const key of keys) {
                    const value = widgets[widget]?.[key]
                    if (isOwn(key, value)) found.push({ output: String(record.output), widget: widget, key: key, value: value })
                }
            }
        }
        return found
    }
    // The config writes that drop what `scan` found.
    function cleared(list: var, reset: var): var {
        const records = JSON.parse(JSON.stringify(Config.options?.background?.widgets?.outputOverrides ?? []))
        const updates = ({})
        for (const entry of list) {
            if (entry.output === "") {
                updates["background.widgets." + entry.widget + "." + entry.key] = reset(entry.key)
                continue
            }
            for (const record of records) {
                if (String(record?.output) === entry.output && record.widgets?.[entry.widget])
                    delete record.widgets[entry.widget][entry.key]
            }
        }
        if (list.some(entry => entry.output !== ""))
            updates["background.widgets.outputOverrides"] = records
        return updates
    }

    // Per-widget exceptions: the look one widget chose for itself, which a design change clears.
    readonly property var exceptions: root.scan([root.spec.key],
        (key, value) => value !== undefined && value !== null && String(value) !== "auto" && String(value) !== "")
        .filter(entry => entry.output !== "" || root.supports(entry.widget))
    readonly property int exceptionCount: root.exceptions.length
    readonly property var undoList: Config.options?.background?.widgets?.designUndo ?? []
    readonly property bool canUndo: root.undoList.length > 0

    function apply(design: string): string {
        const name = design === "individual" || design === "material" ? root.spec.plain : design
        if (!root.spec.choices.includes(name))
            return "Choose " + root.spec.choices.join(", ")
        const cleared = root.exceptions
        const updates = root.cleared(cleared, () => "auto")
        const undo = cleared.slice()
        const key = root.spec.shared
        const before = String(Config.getNestedValue(key, root.faceDesign || root.spec.plain))
        undo.push({ output: "", widget: "", key: key, value: before })
        updates[key] = name
        const changed = cleared.length > 0 || updates[key] !== before
        // Trying designs one after another keeps the first snapshot: undo returns to the looks from
        // before the first change, not to the previous try.
        if (changed && (cleared.length > 0 || !root.canUndo)) updates["background.widgets.designUndo"] = undo
        Config.setNestedValues(updates)
        return name
    }

    // Puts back the design and every widget's own look from before the designs were tried.
    function undo(): string {
        const list = root.undoList
        if (list.length === 0) return "Nothing to undo"
        const records = JSON.parse(JSON.stringify(Config.options?.background?.widgets?.outputOverrides ?? []))
        const updates = ({})
        let touchedRecords = false
        for (const entry of list) {
            if (entry.widget === "") { updates[entry.key] = entry.value; continue }
            if (entry.output === "") { updates["background.widgets." + entry.widget + "." + entry.key] = entry.value; continue }
            let record = records.find(item => String(item?.output) === entry.output)
            if (!record) { record = { output: entry.output, widgets: ({}) }; records.push(record) }
            record.widgets = record.widgets ?? ({})
            record.widgets[entry.widget] = Object.assign({}, record.widgets[entry.widget] ?? {})
            record.widgets[entry.widget][entry.key] = entry.value
            touchedRecords = true
        }
        if (touchedRecords) updates["background.widgets.outputOverrides"] = records
        updates["background.widgets.designUndo"] = []
        Config.setNestedValues(updates)
        return "undone"
    }
}
