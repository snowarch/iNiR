pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The community hub (github.com/snowarch/inir-hub) as every family's Hub page sees it.
// scripts/inir-hub.py owns the catalogue, downloads, checksums and installs; this service runs it,
// keeps its last answer, queues actions one at a time and tells the registries that load each
// kind to look again. Nothing here touches the network on its own: a page asks with refresh().
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/inir-hub.py")

    property var items: []
    property var sources: []
    property int updates: 0
    property string inirVersion: ""
    property bool loaded: false
    property bool loading: statusProcess.running
    property string error: ""
    property real checkedAt: 0
    // Offline the pages keep the last list they had and say so; back online they read it again.
    readonly property bool online: Network.online
    // id -> "install" | "update" | "remove" while queued or running; id -> message after a failure.
    property var busy: ({})
    property var failures: ({})
    property var _queue: []
    property var _current: null

    signal changed(string kind, string id)
    // An item someone asked to see (`inir hub open <id>`); the Hub page that is showing takes it and clears it.
    property string requestedId: ""
    function takeRequest(): string {
        const id = root.requestedId
        root.requestedId = ""
        return id
    }

    readonly property var kinds: [
        { id: "widget", label: "Widgets", icon: "widgets" },
        { id: "theme", label: "Colour themes", icon: "palette" },
        { id: "iris-theme", label: "iRiS themes", icon: "style" },
        { id: "webapp", label: "Web apps", icon: "language" }
    ]
    readonly property var permissionText: ({
        process: "Runs commands on your computer",
        network: "Talks to the internet",
        files: "Reads or writes files outside its own folder",
        inject: "Injects scripts into the site it opens"
    })
    readonly property string family: {
        const panel = String(Config.options?.panelFamily ?? "ii")
        return panel === "ii" ? "material" : panel
    }
    readonly property var extraSources: Array.from(Config.options?.hub?.sources ?? [])

    function kindLabel(kind: string): string {
        return root.kinds.find(entry => entry.id === kind)?.label ?? kind
    }
    function find(id: string): var {
        return root.items.find(item => item.id === id) ?? null
    }
    // Whether an item does something in the family that is showing it.
    function fits(item: var, family: string): bool {
        return Array.from(item?.families ?? []).includes(family)
    }

    // What a page lists: one kind or all ("" ), a search over name, summary, tags and authors,
    // and optionally only what is installed. Every family's page filters through here.
    function matches(item: var, kind: string, query: string, installedOnly: bool): bool {
        if (kind.length > 0 && item.kind !== kind)
            return false
        if (installedOnly && !item.installed)
            return false
        const terms = String(query ?? "").toLowerCase().split(/\s+/).filter(term => term.length > 0)
        if (terms.length === 0)
            return true
        const text = [item.name, item.summary, item.id].concat(Array.from(item.tags ?? []), Array.from(item.authors ?? []))
            .join(" ").toLowerCase()
        return terms.every(term => text.includes(term))
    }
    // The one state a card shows: "install" | "update" | "remove" while that runs, then
    // "failed", "conflict", "incompatible", "update" (one is waiting), "installed" or "get".
    function stateOf(item: var): string {
        if (!item)
            return "get"
        const running = root.busy[item.id]
        if (running !== undefined)
            return running === "remove" ? "removing" : running === "update" ? "updating" : "installing"
        if (root.failures[item.id] !== undefined)
            return "failed"
        if (item.installed)
            return item.update && item.compatible ? "update" : "installed"
        if (item.conflict)
            return "conflict"
        if (!item.compatible)
            return "incompatible"
        return "get"
    }
    // Families an item does something in, by name, for "Works in …".
    function familyNames(item: var): string {
        const names = { material: "Material", iris: "iRiS", waffle: "Waffle" }
        return Array.from(item?.families ?? []).map(family => names[family] ?? family).join(" · ")
    }
    // Where it shows once installed, in the family that is looking.
    function whereText(item: var, family: string): string {
        if (!item)
            return ""
        const surfaces = Array.from(item.surfaces ?? [])
        if (item.kind === "theme")
            return family === "iris" ? Translation.tr("Works in Material and Waffle") : Translation.tr("Colours the shell and your apps")
        if (item.kind === "iris-theme")
            return family === "iris" ? Translation.tr("Redesigns iRiS") : Translation.tr("Works in iRiS")
        if (item.kind === "webapp")
            return family === "material" ? Translation.tr("Opens in the left sidebar") : Translation.tr("Works in Material")
        if (family === "iris" && surfaces.includes("island"))
            return Translation.tr("Shows on the Island")
        if (family === "waffle")
            return surfaces.includes("waffle-widgets") ? Translation.tr("Shows in the Widgets panel") : Translation.tr("Has no Waffle card yet")
        return Translation.tr("Shows on your desktop")
    }
    function sizeText(bytes: real): string {
        return bytes >= 1048576 ? `${(bytes / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`
    }

    // Read the catalogue: from the cache unless it is older than six hours, or from every source now.
    function refresh(fetchNow: bool): void {
        if (statusProcess.running)
            return
        if (fetchNow && !root.online) {
            root.refreshCached()
            return
        }
        statusProcess.command = ["python3", root.script, fetchNow ? "sync" : "status", "--json"]
        statusProcess.running = true
    }
    // The first look of a session: cached when fresh, so opening a page costs no download.
    function ensureLoaded(): void {
        if (!root.loaded && !statusProcess.running)
            root.refresh(false)
    }

    function install(id: string): void { root._enqueue("install", id) }
    function update(id: string): void { root._enqueue("update", id) }
    function remove(id: string): void { root._enqueue("remove", id) }
    function updateAll(): void {
        for (const item of root.items)
            if (item.update && item.compatible)
                root._enqueue("update", item.id)
    }

    function addSource(url: string): void {
        const clean = String(url ?? "").trim()
        if (clean.length === 0 || root.extraSources.includes(clean))
            return
        Config.setNestedValue("hub.sources", root.extraSources.concat([clean]))
        root._refreshSoon.restart()
    }
    function removeSource(url: string): void {
        Config.setNestedValue("hub.sources", root.extraSources.filter(source => source !== url))
        root._refreshSoon.restart()
    }

    // What "use it" means for a widget in each family: Material and iRiS show it on the desktop
    // (iRiS prefers the Island when the widget has a module for it); Waffle's Widgets panel shows
    // every widget with a Waffle face by itself.
    function useWidget(id: string, family: string): void {
        const item = root.find(id)
        if (!item)
            return
        const surfaces = Array.from(item.surfaces ?? [])
        if (family === "iris" && surfaces.includes("island")) {
            const modules = Array.from(Config.options?.iris?.bar?.rightModules ?? [])
            if (!modules.includes("custom:" + id))
                Config.setNestedValue("iris.bar.rightModules", modules.concat(["custom:" + id]))
            return
        }
        if (surfaces.includes("desktop"))
            CustomWidgets.setConfigValue(id, "enable", true)
    }
    // A colour theme from the Hub becomes the custom theme, the same way Settings applies a saved one.
    function useTheme(id: string): void {
        themeReader.command = ["cat", `${Directories.shellConfig}/themes/${id}.json`]
        themeReader.running = true
    }
    function widgetInUse(id: string, family: string): bool {
        void Config.revision
        if (family === "iris" && Array.from(Config.options?.iris?.bar?.rightModules ?? []).includes("custom:" + id))
            return true
        if (family === "waffle")
            return Boolean(CustomWidgets.widgets.find(widget => widget.id === id)?.waffleQmlPath)
        return Boolean(CustomWidgets.getConfigValue(id, "enable", false))
    }

    function _enqueue(verb: string, id: string): void {
        if (root.busy[id] !== undefined)
            return
        const busy = Object.assign({}, root.busy)
        busy[id] = verb
        root.busy = busy
        const failures = Object.assign({}, root.failures)
        delete failures[id]
        root.failures = failures
        root._queue = root._queue.concat([{ verb: verb, id: id }])
        root._next()
    }
    function _next(): void {
        if (actionProcess.running || root._queue.length === 0)
            return
        root._current = root._queue[0]
        root._queue = root._queue.slice(1)
        actionProcess.command = ["python3", root.script, root._current.verb, root._current.id, "--json"]
        actionProcess.running = true
    }
    function _finish(job: var, reply: var): void {
        const busy = Object.assign({}, root.busy)
        delete busy[job.id]
        root.busy = busy
        if (!reply || reply.ok !== true) {
            const failures = Object.assign({}, root.failures)
            failures[job.id] = String(reply?.error ?? "The hub tool did not answer")
            root.failures = failures
        } else {
            for (const result of Array.from(reply.results ?? [])) {
                if (result.kind === "widget")
                    CustomWidgets.reload()
                root.changed(String(result.kind), String(result.id))
            }
        }
        root.refreshCached()
        root._next()
    }
    // A widget the Hub removed leaves no module behind on the Island. Its settings stay in config, so
    // installing it again brings it back as it was. Only Hub widgets that are gone from disk qualify:
    // your own widgets are never touched.
    function _forgetRemovedWidgets(): void {
        if (!root.loaded || !CustomWidgets.ready)
            return
        const present = CustomWidgets.widgets.map(widget => String(widget.id))
        const gone = id => {
            const item = root.find(id)
            return item !== null && item.kind === "widget" && !item.installed && !present.includes(id)
        }
        for (const key of ["leftModules", "centerModules", "rightModules"]) {
            const modules = Array.from(Config.options?.iris?.bar?.[key] ?? [])
            const kept = modules.filter(module => !(String(module).startsWith("custom:") && gone(String(module).slice(7))))
            if (kept.length !== modules.length)
                Config.setNestedValue(`iris.bar.${key}`, kept)
        }
    }
    Connections {
        target: CustomWidgets
        function onReadyChanged(): void {
            root._forgetRemovedWidgets()
        }
    }

    // After an action: the same catalogue, only the installed state changed.
    function refreshCached(): void {
        if (statusProcess.running) {
            root._refreshSoon.restart()
            return
        }
        statusProcess.command = ["python3", root.script, "status", "--cached", "--json"]
        statusProcess.running = true
    }

    property Timer _refreshSoon: Timer {
        interval: 400
        onTriggered: root.refresh(false)
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            id: statusOut
            onStreamFinished: {
                let reply = null
                try {
                    reply = JSON.parse(statusOut.text)
                } catch (e) {
                    reply = null
                }
                if (!reply || reply.ok !== true) {
                    root.error = String(reply?.error ?? "Couldn't read the hub")
                    return
                }
                root.items = Array.from(reply.items ?? [])
                root.sources = Array.from(reply.sources ?? [])
                root.updates = Number(reply.updates ?? 0)
                root.inirVersion = String(reply.inir ?? "")
                const reachable = root.sources.some(source => Number(source.count ?? 0) > 0)
                root.error = reachable ? "" : String(root.sources[0]?.error ?? "")
                root.checkedAt = Date.now()
                root.loaded = true
                root._forgetRemovedWidgets()
            }
        }
    }

    Process {
        id: themeReader
        stdout: StdioCollector {
            id: themeText
            onStreamFinished: {
                try {
                    ThemeService.applyCustomColors(JSON.parse(themeText.text))
                } catch (e) {
                    console.warn("[Hub] could not read the theme:", e)
                }
            }
        }
    }

    Connections {
        target: Network
        function onOnlineChanged(): void {
            if (Network.online && root.loaded)
                root.refresh(false)
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector {
            id: actionOut
            onStreamFinished: {
                let reply = null
                try {
                    reply = JSON.parse(actionOut.text)
                } catch (e) {
                    reply = null
                }
                const job = root._current
                root._current = null
                if (job)
                    root._finish(job, reply)
            }
        }
    }

    IpcHandler {
        target: "hub"

        function refresh(): string {
            root.refresh(true)
            return "fetching"
        }
        function install(id: string): string {
            root.install(id)
            return `queued ${id}`
        }
        function remove(id: string): string {
            root.remove(id)
            return `queued ${id}`
        }
        function update(id: string): string {
            if (id.length === 0 || id === "all")
                root.updateAll()
            else
                root.update(id)
            return "queued"
        }
        // Put an installed item to use in the family on screen: a widget on the Island or the
        // desktop, a colour theme applied. iRiS themes apply with `inir iris theme apply:<id>`.
        function use(id: string): string {
            const item = root.find(id)
            if (!item || !item.installed)
                return `not installed: ${id}`
            if (item.kind === "widget") {
                root.useWidget(id, root.family)
                return `${id} in use`
            }
            if (item.kind === "theme") {
                root.useTheme(id)
                return `${id} applied`
            }
            if (item.kind === "iris-theme")
                return `inir iris theme apply:${id}`
            return `${id} is in the left sidebar`
        }
        // Open one item's page in the Hub page that shows next (or is showing).
        function openItem(id: string): string {
            root.requestedId = id
            root.ensureLoaded()
            return id
        }
        // The shell's view: what it lists, what is installed, what is running.
        function status(): string {
            return JSON.stringify({ loaded: root.loaded, items: root.items.length,
                installed: root.items.filter(item => item.installed).map(item => item.id),
                updates: root.updates, busy: root.busy, failures: root.failures, error: root.error })
        }
        // A change made outside the shell (the inir hub command): read the catalogue again and
        // let the registries reload.
        function changed(kind: string): string {
            const every = kind.length === 0 || kind === "all"
            if (every || kind === "widget")
                CustomWidgets.reload()
            for (const entry of root.kinds)
                if (every || entry.id === kind)
                    root.changed(entry.id, "")
            root.refreshCached()
            return every ? "all" : kind
        }
    }
}
