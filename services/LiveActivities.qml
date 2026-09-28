pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int staleMinutes: 60
    readonly property int retireMs: 4000
    readonly property var tints: ["blue", "sky", "teal", "green", "yellow", "orange", "red", "pink", "indigo", "purple", "lavender", "gray"]

    property var list: []
    readonly property var active: root.list.filter(activity => !activity.ended)
    readonly property var latest: {
        let best = null
        for (const activity of root.active) if (!best || activity.updated > best.updated) best = activity
        return best
    }

    signal finished(var activity)

    function find(id: string): var {
        return root.list.find(activity => activity.id === id) ?? null
    }
    function write(id: string, fields: var): var {
        const key = String(id ?? "").trim()
        if (key.length === 0) return null
        const now = Date.now()
        const previous = root.find(key)
        const next = Object.assign({ id: key, title: key, detail: "", progress: -1, glyph: "bolt", tint: "lavender",
            started: now, ended: false }, previous ?? {}, fields, { updated: now })
        root.list = root.list.filter(activity => activity.id !== key).concat([next])
        return next
    }
    function parseProgress(value: string): real {
        const text = String(value ?? "").trim()
        if (text.length === 0 || text === "-" || text === "-1") return -1
        const number = parseFloat(text.replace("%", ""))
        if (isNaN(number)) return -1
        const fraction = text.endsWith("%") || number > 1 ? number / 100 : number
        return Math.max(0, Math.min(1, fraction))
    }

    function start(id: string, title: string): var {
        return root.write(id, { title: String(title ?? "").length > 0 ? String(title) : String(id), ended: false,
            started: Date.now(), progress: -1, detail: "" })
    }
    function setProgress(id: string, value: string): var { return root.write(id, { progress: root.parseProgress(value), ended: false }) }
    function setDetail(id: string, text: string): var { return root.write(id, { detail: String(text ?? ""), ended: false }) }
    function setTitle(id: string, text: string): var { return root.write(id, { title: String(text ?? ""), ended: false }) }
    function setGlyph(id: string, glyph: string): var { return root.write(id, { glyph: String(glyph ?? "bolt"), ended: false }) }
    function setTint(id: string, tint: string): var {
        return root.write(id, { tint: root.tints.includes(tint) ? tint : "lavender", ended: false })
    }
    function end(id: string, detail: string): var {
        if (!root.find(id)) return null
        const done = root.write(id, { ended: true, progress: 1, detail: String(detail ?? "").length > 0 ? String(detail) : root.find(id).detail })
        root.finished(done)
        retire.restart()
        return done
    }
    function dismiss(id: string): void {
        root.list = root.list.filter(activity => activity.id !== id)
    }
    function clear(): void { root.list = [] }

    Timer {
        id: retire
        interval: root.retireMs
        onTriggered: {
            const cutoff = Date.now() - root.retireMs + 50
            root.list = root.list.filter(activity => !activity.ended || activity.updated > cutoff)
            if (root.list.some(activity => activity.ended)) retire.restart()
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.list.length > 0
        onTriggered: {
            const cutoff = Date.now() - root.staleMinutes * 60000
            root.list = root.list.filter(activity => activity.updated > cutoff)
        }
    }
}
