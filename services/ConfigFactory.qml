pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// What a fresh install has: defaults/config.json over the schema's own values (ConfigOptions and each plugin's part),
// so Settings can keep factory values quiet, make changed ones loud and put one back. Read once something asks.
Singleton {
    id: root

    property var _defaults: null
    property var _schema: null
    property var _slots: ({})
    readonly property bool ready: root._defaults !== null

    // What the shell remembers in config.json on its own (recent picks, notice stamps, model lists): never a choice.
    readonly property var _memory: /(^|\.)(recent[A-Z]\w*|lastNotified\w*|designUndo|extraModels)$/

    // blockLoading makes text() wait for the read, so the first ask already has an answer.
    function load(): void {
        if (root._defaults !== null) return
        if (factoryFile.path.length === 0) factoryFile.path = Quickshell.shellPath("defaults/config.json")
        root._parse(factoryFile.text())
    }

    function _parse(text: string): void {
        if (root._defaults !== null || (text ?? "").length === 0) return
        try {
            root._defaults = JSON.parse(text)
        } catch (e) {
            console.warn("[ConfigFactory] defaults/config.json:", e)
            root._defaults = ({})
        }
    }

    // A JsonObject is a group of settings, never one value.
    function _isGroup(v: var): bool {
        return v !== null && typeof v === "object" && typeof v.objectNameChanged === "function"
    }

    function _at(node: var, path: string): var {
        for (const key of String(path).split(".")) {
            if (node === null || node === undefined || typeof node !== "object" || !(key in node)) return undefined
            node = node[key]
        }
        return node
    }

    // Keys defaults/config.json leaves out take the schema's value, read from an untouched copy of it.
    function _schemaValue(path: string): var {
        if (!root._schema) root._schema = schemaComponent.createObject(root)
        const keys = String(path).split(".")
        let node = root._schema ? root._schema[keys[0]] : undefined
        if ((node === null || node === undefined) && Config._pluginSlots.includes(keys[0])) node = root._slot(keys[0])
        const v = keys.length > 1 ? root._at(node, keys.slice(1).join(".")) : node
        return v === undefined || root._isGroup(v) ? undefined : JSON.parse(JSON.stringify(v))
    }

    function _slot(key: string): var {
        if (root._slots[key] !== undefined) return root._slots[key]
        const owner = Object.keys(Plugins.manifests).find(id => Plugins.manifests[id].configKey === key)
        if (!owner) return null
        const component = Qt.createComponent(Plugins.part(owner, "config"), Component.PreferSynchronous)
        root._slots[key] = component.status === Component.Ready ? component.createObject(root) : null
        return root._slots[key]
    }

    function value(path: string): var {
        if (!root._defaults) return undefined
        const given = root._at(root._defaults, path)
        return given !== undefined ? given : root._schemaValue(path)
    }

    // Only what the person's file holds counts: a key an old install never wrote reads the schema's value, and that
    // was never their choice even where the fresh-install profile picks another.
    function isChanged(path: string): bool {
        if (root._at(Config._jsonMirror, path) === undefined) return false
        const factory = root.value(path)
        const current = root._at(Config.options, path)
        if (factory === undefined || current === undefined || root._isGroup(current)) return false
        return JSON.stringify(current) !== JSON.stringify(factory)
    }

    function reset(path: string): bool {
        const factory = root.value(path)
        if (factory === undefined) return false
        Config.setNestedValue(path, JSON.parse(JSON.stringify(factory)))
        return true
    }

    // A key in Settings: back to factory at once, with the way back on the Undo notice.
    function resetWithUndo(path: string, label: string): void {
        const before = JSON.parse(JSON.stringify(root._at(Config.options, path) ?? null))
        if (!root.reset(path)) return
        Undo.offer(label.length > 0 ? Translation.tr("Reset %1").arg(label) : Translation.tr("Reset to default"),
            () => Config.setNestedValue(path, before))
    }

    // Every value in the person's file that differs from a fresh install, as dotted paths.
    function changed(): var {
        const seen = new Set()
        const out = []
        const walk = (node, prefix) => {
            for (const key of Object.keys(node)) {
                const path = prefix.length > 0 ? prefix + "." + key : key
                const v = node[key]
                if (v !== null && typeof v === "object" && !Array.isArray(v) && Object.keys(v).length > 0) walk(v, path)
                else if (!seen.has(path)) {
                    seen.add(path)
                    if (!root._memory.test(path) && root.isChanged(path)) out.push(path)
                }
            }
        }
        if (!root._defaults) return out
        walk(Config._jsonMirror ?? {}, "")
        return out
    }

    Component {
        id: schemaComponent
        ConfigOptions {}
    }

    FileView {
        id: factoryFile
        path: ""
        blockLoading: true
        onLoaded: root._parse(factoryFile.text())
    }

    /// What differs from a fresh install, and putting one value back (what support asks first).
    IpcHandler {
        target: "factory"

        /// Every setting that differs from a fresh install, one `path = value` per line.
        function changed(): string {
            root.load()
            if (!root.ready) return "no defaults/config.json in " + Quickshell.shellPath("")
            return root.changed().map(path => path + " = " + JSON.stringify(root._at(Config.options, path))).join("\n")
        }

        /// Put one setting back to what a fresh install has; returns the value it took.
        function reset(path: string): string {
            root.load()
            return root.reset(path) ? JSON.stringify(root.value(path)) : "no factory value for " + path
        }
    }
}
