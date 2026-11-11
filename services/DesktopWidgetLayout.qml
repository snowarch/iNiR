pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    readonly property int layoutVersion: 1
    readonly property int rememberedSizes: 6
    readonly property var records: Config.options?.background?.widgets?.outputOverrides ?? []

    function _clone(value): var {
        try {
            return JSON.parse(JSON.stringify(value ?? null))
        } catch (error) {
            return null
        }
    }

    function _outputName(value): string {
        return String(value ?? "").trim()
    }

    // The lock screen keeps its own widget layout as a scope in the same store: "lock:<output>".
    // It inherits every look and option from the desktop widget but not whether it is shown.
    function isLockScope(value): bool {
        return root._outputName(value).startsWith("lock:")
    }
    function lockScope(outputName): string {
        return "lock:" + root._outputName(outputName)
    }

    function _widgetKey(value): string {
        return String(value ?? "").trim()
    }

    function _basePath(widgetKey): string {
        const key = root._widgetKey(widgetKey)
        if (key === "waffle.clock")
            return "waffles.background.widgets.clock"
        return key ? "background.widgets." + key : ""
    }

    function outputRecord(outputName): var {
        const name = root._outputName(outputName)
        if (!name)
            return null
        const list = root.records
        for (let i = 0; i < list.length; ++i) {
            const record = list[i]
            if (root._outputName(record?.output) === name)
                return record
        }
        return null
    }

    function outputLayoutMatches(outputName, width, height): bool {
        const record = root.outputRecord(outputName)
        return record !== null
            && Number(record.layoutVersion ?? 0) >= root.layoutVersion
            && Math.round(Number(record.width ?? 0)) === Math.round(Number(width ?? 0))
            && Math.round(Number(record.height ?? 0)) === Math.round(Number(height ?? 0))
    }

    function _geometryKey(width, height): string {
        return Math.round(Number(width) || 0) + "x" + Math.round(Number(height) || 0)
    }

    function outputGeometry(outputName): var {
        const record = root.outputRecord(outputName)
        const width = Math.round(Number(record?.width ?? 0))
        const height = Math.round(Number(record?.height ?? 0))
        return width > 0 && height > 0 ? { width: width, height: height } : null
    }

    function rememberedPosition(outputName, widgetKey, width, height): var {
        const record = root.outputRecord(outputName)
        const layout = record?.layouts?.[root._geometryKey(width, height)]
        const holder = root._holder(outputName, widgetKey, "x")
        const spot = layout && typeof layout === "object" ? layout[holder] : null
        if (!spot || typeof spot !== "object")
            return null
        const result = ({})
        if (spot.placementStrategy)
            result.placementStrategy = String(spot.placementStrategy)
        if (result.placementStrategy === "free" && Number.isFinite(Number(spot.x))
                && Number.isFinite(Number(spot.y))) {
            result.x = Number(spot.x)
            result.y = Number(spot.y)
        }
        return result
    }

    function widgetOverride(outputName, widgetKey): var {
        const record = root.outputRecord(outputName)
        const key = root._widgetKey(widgetKey)
        if (!record || !key || !record.widgets || typeof record.widgets !== "object")
            return null
        const value = record.widgets[key]
        return value && typeof value === "object" ? value : null
    }

    // A widget in an iRiS stack shares its place and look with the stack: those values live in the
    // stack's record, everything else in the widget's own.
    function _holder(outputName, widgetKey, key): string {
        return DesktopWidgetStacks.owner(root._outputName(outputName), root._widgetKey(widgetKey), String(key ?? ""))
    }

    function hasValue(outputName, widgetKey, key): bool {
        const override = root.widgetOverride(outputName, root._holder(outputName, widgetKey, key))
        return override !== null
            && Object.prototype.hasOwnProperty.call(override, String(key ?? ""))
    }

    function baseValue(widgetKey, key, fallback): var {
        const path = root._basePath(widgetKey)
        const valueKey = String(key ?? "")
        if (!path || !valueKey)
            return fallback
        return Config.getNestedValue(path + "." + valueKey, fallback)
    }

    function value(outputName, widgetKey, key, fallback): var {
        const valueKey = String(key ?? "")
        const holder = root._holder(outputName, widgetKey, valueKey)
        const override = root.widgetOverride(outputName, holder)
        if (override !== null
                && Object.prototype.hasOwnProperty.call(override, valueKey))
            return override[valueKey]
        return root.baseValue(widgetKey, valueKey, fallback)
    }

    function outputAllowed(outputName): bool {
        void Config.revision
        const name = root._outputName(outputName)
        if (!name)
            return false
        if (root.isLockScope(name))
            return true
        const rawConfigured = Config.options?.background?.widgets?.screenList ?? []
        const configured = []
        for (let i = 0; i < (rawConfigured?.length ?? 0); ++i) {
            const configuredName = String(rawConfigured[i] ?? "")
            if (configuredName.length > 0)
                configured.push(configuredName)
        }
        if (configured.length === 0)
            return true
        if (configured.includes(name))
            return true
        const screens = Quickshell.screens
        void screens.length
        const connected = []
        for (let i = 0; i < screens.length; ++i) {
            const connectedName = String(screens[i]?.name ?? "")
            if (connectedName.length > 0)
                connected.push(connectedName)
        }
        return !configured.some(saved => connected.includes(String(saved ?? "")))
    }

    function enabled(outputName, widgetKey, fallback = false): bool {
        if (root.isLockScope(outputName))
            return Boolean(root.widgetOverride(outputName, widgetKey)?.enable ?? false)
        if (!root.outputAllowed(outputName))
            return false
        return Boolean(root.value(outputName, widgetKey, "enable", fallback))
    }

    function _normalizedRecords(): var {
        const result = []
        const byOutput = ({})
        for (const rawRecord of root.records) {
            const output = root._outputName(rawRecord?.output)
            if (!output)
                continue
            let record = byOutput[output]
            if (!record) {
                record = Object.assign({}, root._clone(rawRecord) ?? {}, {
                    output: output,
                    widgets: ({})
                })
                byOutput[output] = record
                result.push(record)
            }
            const widgets = rawRecord?.widgets
            if (!widgets || typeof widgets !== "object")
                continue
            for (const widgetKey of Object.keys(widgets)) {
                const value = widgets[widgetKey]
                if (!value || typeof value !== "object")
                    continue
                record.widgets[widgetKey] = Object.assign(
                    {}, record.widgets[widgetKey] ?? {}, root._clone(value) ?? {})
            }
        }
        return result
    }

    function setValues(outputName, widgetKey, values): bool {
        const output = root._outputName(outputName)
        const widget = root._widgetKey(widgetKey)
        const keys = values && typeof values === "object"
            ? Object.keys(values) : []
        if (!output || !widget || keys.length === 0)
            return false

        const list = root._normalizedRecords()
        let record = list.find(item => item.output === output)
        if (!record) {
            record = { output: output, widgets: ({}) }
            list.push(record)
        }
        let changed = false
        const holders = ({})
        for (const key of keys) {
            const holder = root._holder(output, widget, key)
            if (holders[holder] === undefined)
                holders[holder] = Object.assign({}, record.widgets[holder] ?? {})
            if (values[key] !== undefined && holders[holder][key] !== values[key]) {
                holders[holder][key] = values[key]
                changed = true
            }
        }
        if (!changed)
            return false
        for (const holder of Object.keys(holders))
            record.widgets[holder] = holders[holder]
        Config.setNestedValue("background.widgets.outputOverrides", list)
        return true
    }

    function setValue(outputName, widgetKey, key, value): bool {
        const valueKey = String(key ?? "").trim()
        if (!valueKey)
            return false
        const values = ({})
        values[valueKey] = value
        return root.setValues(outputName, widgetKey, values)
    }

    function setEnabled(outputName, widgetKey, enabled): bool {
        return root.setValue(outputName, widgetKey, "enable", Boolean(enabled))
    }

    function initializeOutputLayout(outputName, width, height, widgetValues, leaving): bool {
        const output = root._outputName(outputName)
        const outputWidth = Math.max(0, Math.round(Number(width) || 0))
        const outputHeight = Math.max(0, Math.round(Number(height) || 0))
        if (!output || outputWidth <= 0 || outputHeight <= 0
                || !widgetValues || typeof widgetValues !== "object")
            return false

        const list = root._normalizedRecords()
        let record = list.find(item => item.output === output)
        if (!record) {
            record = { output: output, widgets: ({}) }
            list.push(record)
        }
        const leftWidth = Math.round(Number(record.width ?? 0))
        const leftHeight = Math.round(Number(record.height ?? 0))
        if (leftWidth > 0 && leftHeight > 0
                && (leftWidth !== outputWidth || leftHeight !== outputHeight)) {
            const spots = ({})
            // What the widgets say they were on the size being left wins over what the record
            // holds: a widget on its default strategy has none there, and a zone one has already
            // rewritten its own x and y for the new size.
            const known = Object.assign({}, record.widgets)
            for (const widgetKey of Object.keys(leaving ?? ({})))
                known[root._holder(output, widgetKey, "x")] = Object.assign(
                    {}, known[root._holder(output, widgetKey, "x")] ?? {}, leaving[widgetKey])
            for (const holder of Object.keys(known)) {
                const values = known[holder]
                const strategy = String(values?.placementStrategy ?? "")
                if (!strategy)
                    continue
                const spot = { placementStrategy: strategy }
                if (strategy === "free" && Number.isFinite(Number(values.x))
                        && Number.isFinite(Number(values.y))) {
                    spot.x = Number(values.x)
                    spot.y = Number(values.y)
                }
                spots[holder] = spot
            }
            const layouts = Object.assign({}, record.layouts ?? {})
            delete layouts[root._geometryKey(leftWidth, leftHeight)]
            layouts[root._geometryKey(leftWidth, leftHeight)] = spots
            const keys = Object.keys(layouts)
            for (let i = 0; i < keys.length - root.rememberedSizes; ++i)
                delete layouts[keys[i]]
            record.layouts = layouts
        }
        for (const widgetKey of Object.keys(widgetValues)) {
            const values = widgetValues[widgetKey]
            if (!values || typeof values !== "object")
                continue
            const parts = ({})
            for (const key of Object.keys(values)) {
                const holder = root._holder(output, widgetKey, key)
                if (parts[holder] === undefined)
                    parts[holder] = ({})
                parts[holder][key] = values[key]
            }
            for (const holder of Object.keys(parts))
                record.widgets[holder] = Object.assign({}, record.widgets[holder] ?? {}, parts[holder])
        }
        record.layoutVersion = root.layoutVersion
        record.width = outputWidth
        record.height = outputHeight
        Config.setNestedValue("background.widgets.outputOverrides", list)
        return true
    }

    function clearWidget(outputName, widgetKey): bool {
        const output = root._outputName(outputName)
        const widget = root._widgetKey(widgetKey)
        if (!output || !widget)
            return false
        const list = root._normalizedRecords()
        const index = list.findIndex(item => item.output === output)
        if (index < 0 || !list[index].widgets[widget])
            return false
        delete list[index].widgets[widget]
        if (Object.keys(list[index].widgets).length === 0
                && Number(list[index].layoutVersion ?? 0) === 0)
            list.splice(index, 1)
        Config.setNestedValue("background.widgets.outputOverrides", list)
        return true
    }

    function clearValues(outputName, widgetKey, keys): bool {
        const output = root._outputName(outputName)
        const widget = root._widgetKey(widgetKey)
        if (!output || !widget || !Array.isArray(keys) || keys.length === 0)
            return false
        const list = root._normalizedRecords()
        const index = list.findIndex(item => item.output === output)
        if (index < 0 || !list[index].widgets[widget])
            return false
        const next = Object.assign({}, list[index].widgets[widget])
        let changed = false
        for (const rawKey of keys) {
            const key = String(rawKey ?? "")
            if (key && Object.prototype.hasOwnProperty.call(next, key)) {
                delete next[key]
                changed = true
            }
        }
        if (!changed)
            return false
        if (Object.keys(next).length > 0)
            list[index].widgets[widget] = next
        else
            delete list[index].widgets[widget]
        if (Object.keys(list[index].widgets).length === 0
                && Number(list[index].layoutVersion ?? 0) === 0)
            list.splice(index, 1)
        Config.setNestedValue("background.widgets.outputOverrides", list)
        return true
    }

    function setGloballyEnabled(widgetKey, enabled): bool {
        const path = root._basePath(widgetKey)
        if (!path)
            return false
        if (!enabled)
            DesktopWidgetStacks.leave(root._widgetKey(widgetKey))
        Config.setNestedValue(path + ".enable", Boolean(enabled))
        root.clearEnableOverrides()
        return true
    }

    // Settings' truth for a widget option: the base value, with those keys cleared from every screen's own record, so
    // a value once set from the widget's quick controls cannot silently beat the Settings row. `values` maps key → value.
    function setEverywhere(widgetKey, values): bool {
        return root.setEverywhereMany([[widgetKey, values]])
    }

    // [[widget, values], ...] in one write: every widget's plate off at once was a config write per widget.
    function setEverywhereMany(entries): bool {
        const updates = ({})
        const list = root._normalizedRecords()
        let cleared = false
        let wrote = false
        for (const entry of entries ?? []) {
            const widgetKey = entry[0]
            const values = entry[1]
            const path = root._basePath(widgetKey)
            const widget = root._widgetKey(widgetKey)
            const keys = values && typeof values === "object" ? Object.keys(values) : []
            if (!path || keys.length === 0)
                continue
            wrote = true
            // A key the schema doesn't declare (iris.face, iris.tile.wifi...) has no base to live in: the write was dropped
            // and its switch did nothing. Those go to every screen's record, where the widget reads them first.
            // A Hub widget's base (`background.widgets.custom.<id>`) holds any key: its options live there, where
            // every face reads them (the Island's and Waffle's have no screen); copied per screen, those faces never
            // saw a change.
            const declared = key => {
                if (widget.startsWith("custom."))
                    return true
                let node = Config.options?.background?.widgets?.[widget]
                const parts = String(key).split(".")
                for (let i = 0; i < parts.length; ++i) {
                    if (node === null || node === undefined || typeof node !== "object" || !(parts[i] in node))
                        return false
                    node = node[parts[i]]
                }
                return true
            }
            const free = keys.filter(key => !declared(key))
            for (const key of keys)
                if (!free.includes(key))
                    updates[path + "." + key] = values[key]
            for (const record of list) {
                if (root.isLockScope(record.output) || !record.widgets[widget])
                    continue
                for (const key of keys) {
                    if (!free.includes(key) && Object.prototype.hasOwnProperty.call(record.widgets[widget], key)) {
                        delete record.widgets[widget][key]
                        cleared = true
                    }
                }
                if (Object.keys(record.widgets[widget]).length === 0)
                    delete record.widgets[widget]
            }
            if (free.length > 0) {
                const outputs = Quickshell.screens.map(screen => root._outputName(screen?.name)).filter(name => name && !root.isLockScope(name))
                for (const record of list)
                    if (!root.isLockScope(record.output) && !outputs.includes(record.output))
                        outputs.push(record.output)
                for (const output of outputs) {
                    let record = list.find(item => item.output === output)
                    if (!record) {
                        record = { output: output, widgets: ({}) }
                        list.push(record)
                    }
                    for (const key of free) {
                        const holder = root._holder(output, widget, key)
                        record.widgets[holder] = Object.assign({}, record.widgets[holder] ?? {}, { [key]: values[key] })
                    }
                }
                cleared = true
            }
        }
        if (!wrote)
            return false
        if (cleared)
            updates["background.widgets.outputOverrides"] = list.filter(record => Object.keys(record.widgets).length > 0
                || Number(record.layoutVersion ?? 0) > 0)
        Config.setNestedValues(updates)
        return true
    }

    function clearEnableOverrides(): bool {
        const list = root._normalizedRecords()
        let changed = false
        for (let i = 0; i < list.length; ++i) {
            if (root.isLockScope(list[i].output))
                continue
            const widgets = list[i].widgets
            for (const widgetKey of Object.keys(widgets)) {
                const override = widgets[widgetKey]
                if (!Object.prototype.hasOwnProperty.call(override, "enable"))
                    continue
                delete override.enable
                changed = true
                if (Object.keys(override).length === 0)
                    delete widgets[widgetKey]
            }
        }
        if (!changed)
            return false
        const next = list.filter(record => Object.keys(record.widgets).length > 0
            || Number(record.layoutVersion ?? 0) > 0)
        Config.setNestedValue("background.widgets.outputOverrides", next)
        return true
    }

    function clearOutput(outputName): bool {
        const output = root._outputName(outputName)
        if (!output)
            return false
        const list = root._normalizedRecords()
        const next = list.filter(item => item.output !== output)
        if (next.length === list.length)
            return false
        Config.setNestedValue("background.widgets.outputOverrides", next)
        return true
    }

    // Effective enable state across outputs: on if enabled on any saved output,
    // otherwise resolved against the first connected output (or base when none saved).
    function effectiveEnabled(widgetKey, fallback = false): bool {
        const saved = root.savedOutputNames()
        if (saved.length > 0) {
            for (let i = 0; i < saved.length; ++i)
                if (root.enabled(saved[i], widgetKey, fallback))
                    return true
            return false
        }
        const screens = Quickshell.screens
        const name = String(screens[0]?.name ?? "")
        return root.enabled(name, widgetKey, fallback)
    }

    // Read on every widget row's visibility (Settings › Widgets asks per row): computed once per change of the
    // records instead of deep-cloning every record on each call.
    readonly property var savedOutputs: {
        const seen = new Set()
        const out = []
        for (const record of root.records) {
            const output = root._outputName(record?.output)
            if (!output || seen.has(output) || root.isLockScope(output))
                continue
            seen.add(output)
            out.push(output)
        }
        return out
    }

    function savedOutputNames(): list<string> {
        return root.savedOutputs.slice()
    }

    function diagnostics(): string {
        return JSON.stringify({
            layoutVersion: root.layoutVersion,
            records: root._normalizedRecords(),
            connectedOutputs: Quickshell.screens.map(screen => String(screen?.name ?? ""))
        })
    }
}
