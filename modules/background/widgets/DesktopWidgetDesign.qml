pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

QtObject {
    id: root

    // A design overlays only presentation keys; stored sizes, content and each widget's own styles
    // stay in the config. Choosing a design moves every widget onto it and keeps the exceptions it
    // cleared in `background.widgets.designUndo`, so the change can be taken back.
    readonly property string family: Config.options?.panelFamily ?? "ii"
    readonly property string shared: Config.options?.background?.widgets?.design ?? "individual"
    readonly property var irisDesigns: ["iris", "material", "instrument", "readout"]
    readonly property string irisGlobal: {
        const own = String(Config.options?.iris?.widgets?.design ?? "iris")
        if (own === "material" && ["instrument", "readout"].includes(root.shared)) return root.shared
        return root.irisDesigns.includes(own) ? own : "iris"
    }
    readonly property string current: root.family === "iris" ? root.irisGlobal
        : root.shared === "individual" ? "material" : root.shared
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

    function supports(widget: string): bool { return root.instruments[widget] !== undefined }
    function values(widget: string, design: string): var {
        if (design === "instrument") return root.instruments[widget] ?? ({})
        if (design === "readout") return root.readouts[widget] ?? root.instruments[widget] ?? ({})
        return ({})
    }

    // What one widget draws: `face` is the iRiS face, `design` the overlay on the Material widget.
    function resolve(widget: string, ownIris: string, ownShared: string, hasFace: bool): var {
        if (root.family === "iris") {
            const design = root.irisDesigns.includes(ownIris) ? ownIris : root.irisGlobal
            const overlaid = ["instrument", "readout"].includes(design)
            if (overlaid && !root.supports(widget) && hasFace) return { face: true, design: "individual" }
            return { face: design === "iris", design: overlaid ? design : "individual" }
        }
        if (!["ii"].includes(root.family)) return { face: false, design: "individual" }
        return { face: false, design: ["individual", "instrument", "readout"].includes(ownShared) ? ownShared : root.shared }
    }

    // Per-widget exceptions: the look one widget chose for itself, which a design change clears.
    readonly property var exceptionKeys: root.family === "iris" ? ["iris.design"] : ["design"]
    function _own(value): bool {
        return value !== undefined && value !== null && String(value) !== "auto" && String(value) !== ""
    }
    readonly property var exceptions: {
        void Config.revision
        const found = []
        const base = Config.options?.background?.widgets ?? {}
        for (const widget of Object.keys(root.instruments)) {
            for (const key of root.exceptionKeys) {
                const value = Config.getNestedValue("background.widgets." + widget + "." + key, undefined)
                if (root._own(value)) found.push({ output: "", widget: widget, key: key, value: value })
            }
        }
        for (const record of (base.outputOverrides ?? [])) {
            const widgets = record?.widgets ?? {}
            for (const widget of Object.keys(widgets)) {
                for (const key of root.exceptionKeys) {
                    const value = widgets[widget]?.[key]
                    if (root._own(value)) found.push({ output: String(record.output), widget: widget, key: key, value: value })
                }
            }
        }
        return found
    }
    readonly property int exceptionCount: root.exceptions.length
    readonly property var undoList: Config.options?.background?.widgets?.designUndo ?? []
    readonly property bool canUndo: root.undoList.length > 0

    function _clearExceptions(list): var {
        const records = JSON.parse(JSON.stringify(Config.options?.background?.widgets?.outputOverrides ?? []))
        const updates = ({})
        for (const entry of list) {
            if (entry.output === "") {
                updates["background.widgets." + entry.widget + "." + entry.key] = "auto"
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

    function apply(design: string): string {
        const name = design === "individual" && root.family === "iris" ? "material" : design
        if (!["iris", "material", "individual", "instrument", "readout"].includes(name))
            return "Choose iris, material, individual, instrument or readout"
        if (name === "iris" && root.family !== "iris") return "iRiS faces need the iRiS family"
        const cleared = root.exceptions
        const updates = root._clearExceptions(cleared)
        const undo = cleared.slice()
        undo.push({ output: "", widget: "", key: "background.widgets.design", value: root.shared })
        undo.push({ output: "", widget: "", key: "iris.widgets.design", value: String(Config.options?.iris?.widgets?.design ?? "iris") })
        updates["background.widgets.design"] = ["instrument", "readout"].includes(name) ? name : "individual"
        if (root.family === "iris") updates["iris.widgets.design"] = name === "individual" ? "material" : name
        const changed = cleared.length > 0 || updates["background.widgets.design"] !== root.shared
            || (root.family === "iris" && updates["iris.widgets.design"] !== String(Config.options?.iris?.widgets?.design ?? "iris"))
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
