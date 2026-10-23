pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common

// Undo and redo while arranging the desktop, for every family: which widgets are out, where they sit, their order and
// stacks. One snapshot per settled change (320 ms after the last write), sixty deep; the head says back what it did.
Singleton {
    id: root

    readonly property bool active: GlobalStates.widgetEditMode
    function trackedPaths(): var {
        // The widgets' look travels with them: a saved or factory desktop wears its material and accents too.
        const out = ["background.widgets.outputOverrides", "background.widgets.layerOrder", "background.widgets.stacks",
            "iris.widgets.material", "iris.widgets.tint"]
        const widgets = Config.options?.background?.widgets ?? {}
        for (const key of Object.keys(widgets)) {
            const value = widgets[key]
            if (value && typeof value === "object" && value.enable !== undefined)
                out.push("background.widgets." + key + ".enable")
        }
        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : []))
            out.push("background.widgets.custom." + custom.id + ".enable")
        return out
    }
    function plain(value: var): var {
        if (value === null || value === undefined || typeof value !== "object") return value
        if (value.length !== undefined && typeof value !== "string") return Array.from(value, item => root.plain(item))
        const out = {}
        for (const key of Object.keys(value)) out[key] = root.plain(value[key])
        return out
    }
    function snapshot(): var {
        const values = {}
        for (const path of root.trackedPaths())
            values[path] = root.plain(Config.getNestedValue(path, path.endsWith(".enable") ? false : path.startsWith("iris.") ? "" : []))
        return values
    }

    property var undoStack: []
    property var redoStack: []
    property var lastSnapshot: null
    property string lastKey: ""
    property bool restoring: false
    property string notice: ""
    function say(text: string): void { root.notice = text; noticeTimer.restart() }
    function reset(): void {
        root.lastSnapshot = root.snapshot()
        root.lastKey = JSON.stringify(root.lastSnapshot)
        root.undoStack = []
        root.redoStack = []
    }
    function record(): void {
        const snap = root.snapshot()
        const key = JSON.stringify(snap)
        if (key === root.lastKey) return
        if (root.lastSnapshot && !root.restoring) {
            root.undoStack = root.undoStack.concat([root.lastSnapshot]).slice(-60)
            root.redoStack = []
        }
        root.restoring = false
        root.lastSnapshot = snap
        root.lastKey = key
    }
    function undo(): void {
        if (root.undoStack.length === 0) return
        const previous = root.undoStack[root.undoStack.length - 1]
        root.undoStack = root.undoStack.slice(0, -1)
        root.redoStack = root.redoStack.concat([root.snapshot()])
        root.restoring = true
        Config.setNestedValues(previous)
        root.say(Translation.tr("Undone"))
    }
    function redo(): void {
        if (root.redoStack.length === 0) return
        const next = root.redoStack[root.redoStack.length - 1]
        root.redoStack = root.redoStack.slice(0, -1)
        root.undoStack = root.undoStack.concat([root.snapshot()])
        root.restoring = true
        Config.setNestedValues(next)
        root.say(Translation.tr("Redone"))
    }
    Timer { id: noticeTimer; interval: 2400; onTriggered: root.notice = "" }
    Timer { id: recordTimer; interval: 320; onTriggered: root.record() }
    Connections {
        target: Config
        enabled: root.active
        function onRevisionChanged(): void { recordTimer.restart() }
    }
    onActiveChanged: if (root.active) root.reset()
}
