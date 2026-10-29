pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// What a fresh install has (defaults/config.json), so Settings can keep factory values quiet, make changed ones
// loud and put one back. Read once something asks; a key the profile doesn't carry is never called changed.
Singleton {
    id: root

    property var _factory: null
    readonly property bool ready: root._factory !== null

    function load(): void {
        if (factoryFile.path.length === 0) factoryFile.path = Quickshell.shellPath("defaults/config.json")
    }

    function _at(node: var, path: string): var {
        for (const key of String(path).split(".")) {
            if (node === null || node === undefined || typeof node !== "object" || !(key in node)) return undefined
            node = node[key]
        }
        return node
    }

    function value(path: string): var {
        return root._factory ? root._at(root._factory, path) : undefined
    }

    function isChanged(path: string): bool {
        const factory = root.value(path)
        return factory !== undefined && JSON.stringify(root._at(Config.options, path)) !== JSON.stringify(factory)
    }

    function reset(path: string): bool {
        const factory = root.value(path)
        if (factory === undefined) return false
        Config.setNestedValue(path, JSON.parse(JSON.stringify(factory)))
        return true
    }

    // Every leaf that differs from a fresh install, as dotted paths.
    function changed(): var {
        const out = []
        const walk = (node, prefix) => {
            for (const key of Object.keys(node)) {
                const path = prefix.length > 0 ? prefix + "." + key : key
                const v = node[key]
                if (v !== null && typeof v === "object" && !Array.isArray(v) && Object.keys(v).length > 0) walk(v, path)
                else if (root.isChanged(path)) out.push(path)
            }
        }
        if (root._factory) walk(root._factory, "")
        return out
    }

    FileView {
        id: factoryFile
        path: ""
        blockLoading: true
        onLoaded: {
            try {
                root._factory = JSON.parse(factoryFile.text())
            } catch (e) {
                console.warn("[ConfigFactory] defaults/config.json:", e)
                root._factory = ({})
            }
        }
    }

    /// What differs from a fresh install, and putting one value back (what support asks first).
    IpcHandler {
        target: "factory"

        /// Every setting that differs from a fresh install, one `path = value` per line.
        function changed(): string {
            root.load()
            if (!root.ready) return "reading defaults, ask again"
            return root.changed().map(path => path + " = " + JSON.stringify(root._at(Config.options, path))).join("\n")
        }

        /// Put one setting back to what a fresh install has; returns the value it took.
        function reset(path: string): string {
            root.load()
            return root.reset(path) ? JSON.stringify(root.value(path)) : "no factory value for " + path
        }
    }
}
