pragma Singleton

import QtQuick
import Quickshell

// The last cover each track published, so a player created later shows it at once, with the same
// URL, instead of resolving it again behind a placeholder.
Singleton {
    id: root

    property var entries: ({})
    readonly property int limit: 64

    function lookup(key: string): var {
        return root.entries[key] ?? null
    }

    function remember(key: string, base: string, source: string): void {
        if (!key.length || !source.length) return
        const next = Object.assign({}, root.entries)
        delete next[key]
        next[key] = { base: base, source: source }
        const keys = Object.keys(next)
        if (keys.length > root.limit) delete next[keys[0]]
        root.entries = next
    }
}
