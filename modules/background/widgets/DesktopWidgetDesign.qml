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
        const iris = root.family === "iris"
        const key = iris ? "iris.widgets.design" : "background.widgets.design"
        const before = iris ? String(Config.options?.iris?.widgets?.design ?? "iris") : root.shared
        undo.push({ output: "", widget: "", key: key, value: before })
        updates[key] = iris ? (name === "individual" ? "material" : name)
            : ["instrument", "readout"].includes(name) ? name : "individual"
        const changed = cleared.length > 0 || updates[key] !== before
        // Trying designs one after another keeps the first snapshot: undo returns to the looks from
        // before the first change, not to the previous try.
        if (changed && (cleared.length > 0 || !root.canUndo)) updates["background.widgets.designUndo"] = undo
        Config.setNestedValues(updates)
        return name
    }

    readonly property var surfaceKeys: ["iris.material", "iris.opacity"]
    function _ownSurface(key: string, value): bool {
        if (key === "iris.opacity") return Number(value) >= 20
        return ["glass", "clear", "solid", "tinted"].includes(String(value))
    }
    readonly property var ownSurfaces: {
        void Config.revision
        const found = []
        const base = Config.options?.background?.widgets ?? {}
        for (const widget of Object.keys(base)) {
            const entry = base[widget]
            if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue
            for (const key of root.surfaceKeys)
                if (root._ownSurface(key, entry[key])) found.push({ output: "", widget: widget, key: key })
        }
        for (const record of (base.outputOverrides ?? [])) {
            const widgets = record?.widgets ?? {}
            for (const widget of Object.keys(widgets))
                for (const key of root.surfaceKeys)
                    if (root._ownSurface(key, widgets[widget]?.[key]))
                        found.push({ output: String(record.output), widget: widget, key: key })
        }
        return found
    }
    readonly property int ownSurfaceCount: new Set(root.ownSurfaces.map(entry => entry.output + "::" + entry.widget)).size
    function matchSurfaces(): string {
        const list = root.ownSurfaces
        const count = root.ownSurfaceCount
        if (list.length === 0) return "Every widget already follows the shared material"
        const records = JSON.parse(JSON.stringify(Config.options?.background?.widgets?.outputOverrides ?? []))
        const updates = ({})
        for (const entry of list) {
            if (entry.output === "") {
                updates["background.widgets." + entry.widget + "." + entry.key] = entry.key === "iris.opacity" ? -1 : "auto"
                continue
            }
            for (const record of records)
                if (String(record?.output) === entry.output && record.widgets?.[entry.widget])
                    delete record.widgets[entry.widget][entry.key]
        }
        if (list.some(entry => entry.output !== ""))
            updates["background.widgets.outputOverrides"] = records
        Config.setNestedValues(updates)
        return "matched " + count
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
