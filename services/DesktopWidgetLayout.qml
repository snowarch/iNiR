pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    readonly property int layoutVersion: 1
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

    function widgetOverride(outputName, widgetKey): var {
        const record = root.outputRecord(outputName)
        const key = root._widgetKey(widgetKey)
        if (!record || !key || !record.widgets || typeof record.widgets !== "object")
            return null
        const value = record.widgets[key]
        return value && typeof value === "object" ? value : null
    }

    function hasValue(outputName, widgetKey, key): bool {
        const override = root.widgetOverride(outputName, widgetKey)
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
        const override = root.widgetOverride(outputName, widgetKey)
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
        const next = Object.assign({}, record.widgets[widget] ?? {})
        let changed = false
        for (const key of keys) {
            if (values[key] !== undefined && next[key] !== values[key]) {
                next[key] = values[key]
                changed = true
            }
        }
        if (!changed)
            return false
        record.widgets[widget] = next
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

    function initializeOutputLayout(outputName, width, height, widgetValues): bool {
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
        for (const widgetKey of Object.keys(widgetValues)) {
            const values = widgetValues[widgetKey]
            if (!values || typeof values !== "object")
                continue
            record.widgets[widgetKey] = Object.assign(
                {}, record.widgets[widgetKey] ?? {}, values)
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

    function savedOutputNames(): list<string> {
        return root._normalizedRecords().map(record => record.output)
    }

    function diagnostics(): string {
        return JSON.stringify({
            layoutVersion: root.layoutVersion,
            records: root._normalizedRecords(),
            connectedOutputs: Quickshell.screens.map(screen => String(screen?.name ?? ""))
        })
    }
}
