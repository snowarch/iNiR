pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The chassis field's wallpaper backdrop, listed per window so other fields and panes in the same
// window sample it instead of decoding the wallpaper again. Only declared sources are listed: an item
// created here and parented into a window that later unloads crashed Quickshell on teardown.
Singleton {
    id: root

    property var providers: []

    function register(host: Item, source: Item): void {
        if (!host || !source) return
        root.providers = root.providers.filter(p => p.host && p.source && p.source !== source).concat([{ host: host, source: source }])
    }

    function unregister(source: Item): void {
        root.providers = root.providers.filter(p => p.host && p.source && p.source !== source)
    }

    function find(host: Item, except: Item): Item {
        if (!host) return null
        const entry = root.providers.find(p => p.host === host && p.source && p.source !== except)
        return entry ? entry.source : null
    }
}
