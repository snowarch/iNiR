pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.functions

// Undo and redo while arranging the desktop, for every family: which widgets are out, where they sit, their order and
// stacks. One snapshot per settled change (320 ms after the last write), sixty deep; the head says back what it did.
// Cancel puts back the desktop as it was when the mode opened.
Singleton {
    id: root

    readonly property bool active: GlobalStates.widgetEditMode
    // A family's own settings that arranging can change (where its bar or its popups sit): tracked with the widgets,
    // so Undo and Cancel take them back too. Leaf paths; one the config does not hold is left out.
    property var familyPaths: []
    onFamilyPathsChanged: if (root.active) root.adopt()
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
    // The widgets alone, as a saved desktop holds them.
    function widgetSnapshot(): var {
        const values = {}
        for (const path of root.trackedPaths())
            values[path] = root.plain(Config.getNestedValue(path, path.endsWith(".enable") ? false : path.startsWith("iris.") ? "" : []))
        return values
    }
    function snapshot(): var {
        const values = root.widgetSnapshot()
        for (const path of root.familyPaths) {
            const value = Config.getNestedValue(path, undefined)
            if (value !== undefined) values[path] = root.plain(value)
        }
        return values
    }

    property var undoStack: []
    property var redoStack: []
    property var lastSnapshot: null
    property string lastKey: ""
    property var entry: null
    property string entryKey: ""
    // Something differs from how the desktop was when the mode opened.
    readonly property bool changed: root.lastKey !== root.entryKey
    property bool restoring: false
    property string notice: ""
    function say(text: string): void { root.notice = text; noticeTimer.restart() }
    function reset(): void {
        root.lastSnapshot = root.snapshot()
        root.lastKey = JSON.stringify(root.lastSnapshot)
        root.entry = root.lastSnapshot
        root.entryKey = root.lastKey
        root.undoStack = []
        root.redoStack = []
    }
    // Paths a family names once the mode is open start from what they hold now, in the entry as in the last snapshot.
    function adopt(): void {
        const now = root.snapshot()
        for (const snap of [root.entry, root.lastSnapshot])
            if (snap)
                for (const path of Object.keys(now))
                    if (!(path in snap)) snap[path] = now[path]
        root.entryKey = JSON.stringify(root.entry)
        root.lastKey = JSON.stringify(root.lastSnapshot)
    }
    // A wallpaper picked while arranging is a draft: the desktop shows it at once, Done applies it, and any other way out
    // (Escape, Cancel, another mode) puts back the one that was there. Previewed on the output it will land on, so
    // applying adopts the frame on screen instead of painting it again.
    property string wallpaperDraft: ""
    property string wallpaperDraftOutput: ""
    function draftOutput(outputName: string): string {
        return (Config.options?.background?.multiMonitor?.enable ?? false) ? String(outputName ?? "") : ""
    }
    function draftWallpaper(path: string, outputName: string): void {
        const clean = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!root.active || clean.length === 0) return
        const output = root.draftOutput(outputName)
        const target = Wallpapers.resolveSelectionTarget("", output)
        if (clean === FileUtils.trimFileProtocol(Wallpapers.currentWallpaperPathForTarget(target, output))) {
            root.dropWallpaperDraft()
            return
        }
        root.wallpaperDraft = clean
        root.wallpaperDraftOutput = output
        Wallpapers.previewWallpaper(clean, output)
    }
    function dropWallpaperDraft(): void {
        if (root.wallpaperDraft.length === 0) return
        root.wallpaperDraft = ""
        root.wallpaperDraftOutput = ""
        Wallpapers.cancelWallpaperPreview()
    }
    function applyWallpaperDraft(): void {
        const path = root.wallpaperDraft
        const output = root.wallpaperDraftOutput
        if (path.length === 0) return
        root.wallpaperDraft = ""
        root.wallpaperDraftOutput = ""
        const target = Wallpapers.resolveSelectionTarget("", output)
        if (target === "main") Wallpapers.apply(path, Appearance.m3colors.darkmode, output)
        else Wallpapers.applySelectionTarget(path, target, Appearance.m3colors.darkmode, output)
        if (Wallpapers.isBackdropTarget(target)) Wallpapers.cancelWallpaperPreview()
        else Wallpapers.clearWallpaperPreview()
    }
    // Done: keeps the arrangement and applies the drafted wallpaper.
    // A fullscreen window taking an output (a game) ends arranging, as Escape does: the mode covers what it shows.
    Connections {
        target: GameMode
        enabled: root.active
        function onHasVisibleFullscreenWindowChanged(): void {
            if (GameMode.hasVisibleFullscreenWindow) GlobalStates.setWidgetEditMode(false)
        }
    }
    function finish(): void {
        root.applyWallpaperDraft()
        GlobalStates.setWidgetEditMode(false)
    }
    // Leaves the mode with everything as it was when it opened.
    function cancel(): void {
        root.dropWallpaperDraft()
        if (root.entry && JSON.stringify(root.snapshot()) !== root.entryKey) {
            root.restoring = true
            Config.setNestedValues(root.entry)
        }
        GlobalStates.setWidgetEditMode(false)
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
    onActiveChanged: {
        if (root.active) root.reset()
        else root.dropWallpaperDraft()
    }
}
