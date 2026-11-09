pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services.deferred

// The community hub (github.com/snowarch/inir-hub) as every family's Hub page sees it.
// `inir hub` (inir-cli) owns the catalogue, downloads, checksums and installs; this service runs it,
// keeps its last answer, queues actions one at a time and tells the registries that load each
// kind to look again. Nothing here touches the network on its own: a page asks with refresh().
Singleton {
    id: root

    readonly property string launcher: Quickshell.shellPath("scripts/inir")

    property var items: []
    property var sources: []
    property int updates: 0
    property string inirVersion: ""
    property bool loaded: false
    property bool loading: statusProcess.running
    // an install from before the inir command (v2.33.0 not yet updated): the hub can't be read until it is
    readonly property bool cliMissing: root.error.indexOf("needs the inir binary") >= 0
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
    // A shelf someone asked to open on (a family's "More in the Hub" for its Designs), taken the same way.
    property string requestedKind: ""
    function takeKind(): string {
        const kind = root.requestedKind
        root.requestedKind = ""
        return kind
    }
    function takeRequest(): string {
        const id = root.requestedId
        root.requestedId = ""
        return id
    }

    readonly property var kinds: [
        { id: "widget", label: "Widgets", one: "Widget", icon: "widgets" },
        { id: "theme", label: "Colour themes", one: "Colour theme", icon: "palette" },
        { id: "iris-theme", label: "iRiS themes", one: "iRiS theme", icon: "style" },
        { id: "webapp", label: "Web apps", one: "Web app", icon: "language" },
        { id: "component", label: "Components", one: "Component", icon: "extension" },
        { id: "design", label: "Designs", one: "Design", icon: "brush" },
        { id: "family", label: "Families", one: "Family", icon: "dashboard" }
    ]
    readonly property var permissionText: ({
        process: "Runs commands on your computer",
        network: "Talks to the internet",
        files: "Reads or writes files outside its own folder",
        inject: "Injects scripts into the site it opens"
    })
    // How a page orders the catalogue. Popular weighs downloads by how long an item has been out, and its votes.
    readonly property var sorts: [
        { id: "popular", label: "Popular", icon: "local_fire_department" },
        { id: "downloads", label: "Most downloaded", icon: "download" },
        { id: "rating", label: "Top rated", icon: "thumb_up" },
        { id: "newest", label: "Newest", icon: "new_releases" },
        { id: "updated", label: "Recently updated", icon: "update" },
        { id: "name", label: "A to Z", icon: "sort_by_alpha" }
    ]
    readonly property string family: {
        const panel = String(Config.options?.panelFamily ?? "ii")
        return panel === "ii" ? "material" : panel
    }
    readonly property var extraSources: Array.from(Config.options?.hub?.sources ?? [])

    function kindLabel(kind: string): string {
        return root.kinds.find(entry => entry.id === kind)?.label ?? kind
    }
    // One item of a kind ("Widget"), for a card's line; kindLabel names the shelf.
    function kindName(kind: string): string {
        return root.kinds.find(entry => entry.id === kind)?.one ?? kind
    }
    // The item a family's page puts first: one the hub marks as featured, else the newest,
    // among those that work in that family and on this iNiR.
    function featuredFor(family: string): var {
        const usable = root.items.filter(item => root.fits(item, family) && item.compatible !== false)
        if (usable.length === 0)
            return null
        const newest = (a, b) => String(b.updated ?? "").localeCompare(String(a.updated ?? ""))
        const picked = usable.filter(item => item.featured === true).sort(newest)
        return (picked.length > 0 ? picked : usable.slice().sort(newest))[0]
    }
    // What a page says an item can do. An orphan left the catalogue and its audit with it: nothing is claimed.
    function reachTitle(item: var): string {
        if (item?.orphan) return Translation.tr("Not in the catalogue")
        return Array.from(item?.permissions ?? []).length > 0 ? Translation.tr("What it can do") : Translation.tr("Nothing beyond the shell")
    }
    function reachText(item: var): string {
        return item?.orphan ? Translation.tr("It isn't in the catalogue, so nobody checked what it can do.")
            : Translation.tr("It only draws inside the shell: it runs no commands, reaches no websites and reads no files of yours.")
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
        if (installedOnly && !root.owned(item))
            return false
        const terms = String(query ?? "").toLowerCase().split(/\s+/).filter(term => term.length > 0)
        if (terms.length === 0)
            return true
        const text = [item.name, item.summary, item.id].concat(Array.from(item.tags ?? []), Array.from(item.authors ?? []))
            .join(" ").toLowerCase()
        return terms.every(term => text.includes(term))
    }
    // The one state a card shows: "install" | "update" | "remove" while that runs, then
    // "failed", "pulled" (the installed copy was pulled), "active" or "present" (a family the shell has), "conflict",
    // "incompatible", "update", "installed", "blocked" (pulled before it was installed) or "get".
    function stateOf(item: var): string {
        if (!item)
            return "get"
        const running = root.busy[item.id]
        if (running !== undefined)
            return running === "remove" ? "removing" : running === "update" ? "updating" : "installing"
        if (root.failures[item.id] !== undefined)
            return "failed"
        // Pulled from the hub: the copy someone has is flagged, and nothing new installs.
        if (item.installedBlocked)
            return "pulled"
        if (item.blocked && item.installed !== item.version)
            return item.installed ? "installed" : "blocked"
        // A family the shell already has (shipped inside inir, linked, or from the hub) is never a name clash: it is
        // the one in use or one to switch to (10-29: all three read "Name taken", the one in use too).
        if (item.kind === "family" && Plugins.families.includes(item.id))
            return item.installed && item.update && item.compatible ? "update" : Plugins.active === item.id ? "active" : "present"
        if (item.installed)
            return item.update && item.compatible ? "update" : "installed"
        if (item.conflict)
            return "conflict"
        if (!item.compatible)
            return "incompatible"
        return "get"
    }
    // Families an item does something in, by name, for "Works in …".
    // On this machine: installed from the hub, or a family the shell has.
    function owned(item: var): bool {
        return Boolean(item?.installed) || (item?.kind === "family" && Plugins.families.includes(item.id))
    }
    function useFamily(id: string): void {
        Quickshell.execDetached([root.launcher, "panelFamily", "set", id])
    }
    // The line under a card's name, for the family whose page shows it.
    function whereOf(item: var, family: string): string {
        if (item?.kind === "family")
            return Plugins.active === item.id ? Translation.tr("The shell you're using")
                : Plugins.families.includes(item.id) ? Translation.tr("Ready to use") : Translation.tr("A whole shell")
        return root.fits(item, family) ? root.whereText(item, family) : Translation.tr("For %1").arg(root.familyNames(item))
    }
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
        if (item.kind === "iris-theme" || item.kind === "design")
            return family === "iris" ? Translation.tr("Redesigns iRiS") : Translation.tr("Works in iRiS")
        if (item.kind === "webapp")
            return family === "material" ? Translation.tr("Opens in the left sidebar") : Translation.tr("Works in Material")
        if (family === "iris" && surfaces.includes("island"))
            return Translation.tr("Shows on the Island")
        if (family === "waffle")
            return surfaces.includes("waffle-widgets") ? Translation.tr("Shows in the Widgets panel") : Translation.tr("Has no Waffle card yet")
        return Translation.tr("Shows on your desktop")
    }
    function votes(item: var): int {
        return root.voteCount(item, "up") + root.voteCount(item, "down")
    }
    // Share of people who liked it, or -1 before anyone voted.
    function liked(item: var): real {
        const n = root.votes(item)
        return n > 0 ? root.voteCount(item, "up") / n : -1
    }
    // Wilson's lower bound at 95 %: two votes of two don't outrank ninety of a hundred.
    function _confidence(item: var): real {
        const n = root.votes(item)
        if (n === 0)
            return 0
        const p = root.voteCount(item, "up") / n, z = 1.96
        return (p + z * z / (2 * n) - z * Math.sqrt((p * (1 - p) + z * z / (4 * n)) / n)) / (1 + z * z / n)
    }
    function _days(date: string): real {
        const t = Date.parse(String(date ?? "") + "T12:00:00Z")
        return isNaN(t) ? 365 : Math.max(1, (Date.now() - t) / 86400000)
    }
    function _popularity(item: var): real {
        return Number(item?.downloads ?? 0) / Math.pow(root._days(item?.added ?? item?.updated) + 7, 0.6) * (0.5 + root._confidence(item))
    }
    function sorted(items: var, sort: string): var {
        const by = {
            downloads: (a, b) => Number(b.downloads ?? 0) - Number(a.downloads ?? 0),
            rating: (a, b) => root._confidence(b) - root._confidence(a),
            newest: (a, b) => String(b.added ?? b.updated ?? "").localeCompare(String(a.added ?? a.updated ?? "")),
            updated: (a, b) => String(b.updated ?? "").localeCompare(String(a.updated ?? "")),
            name: (a, b) => String(a.name ?? "").localeCompare(String(b.name ?? ""))
        }[sort] ?? ((a, b) => root._popularity(b) - root._popularity(a))
        return Array.from(items ?? []).slice().sort((a, b) => by(a, b) || String(a.name ?? "").localeCompare(String(b.name ?? "")))
    }
    // What changed, newest first: what an update brings while one waits, else the last three versions.
    function changesOf(item: var): var {
        const all = Array.from(item?.update === true && (item?.news ?? []).length > 0 ? item.news : (item?.changes ?? []))
        return item?.update === true ? all : all.slice(0, 3)
    }
    function changesTitle(item: var): string {
        return item?.update === true && (item?.news ?? []).length > 0
            ? Translation.tr("In the update") : Translation.tr("What's new")
    }
    // What the person did with each item (hub.social in config.json) and what everyone else did: read from the relays
    // by `inir hub counts` when a page opens (the command keeps its last read five minutes), else the catalogue's
    // daily counts. Their own act is added to the others', so it shows at once and is never counted twice.
    readonly property var quickReactions: ["❤️", "🔥", "✨", "😂", "🤯", "👏"] // inir-cli hub.Reactions
    readonly property int maxReactions: 12 // inir-cli maxReactions
    // the picker's first row with no search: the quick set and two more, eight across
    readonly property var _pickerFirst: root.quickReactions.concat(["🎉", "💯"])
    readonly property bool sharing: Config.options?.hub?.social?.share ?? true
    // id -> {up, down, reactions}, everyone but this person; null until the first read answers.
    property var liveCounts: null
    function mine(id: string): var {
        void Config.revision
        return Config.options?.hub?.social?.items?.[id] ?? ({})
    }
    // Everyone else's count: the live read, else the catalogue's, which includes this person's own once published.
    function _others(item: var, live: string, catalogue: var, own: bool): int {
        if (root.liveCounts)
            return Number(root.liveCounts[item?.id]?.[live] ?? 0)
        return Math.max(0, Number(catalogue ?? 0) - (own ? 1 : 0))
    }
    function voteCount(item: var, vote: string): int {
        const own = root.mine(item?.id).vote === vote
        return root._others(item, vote, vote === "up" ? item?.votesUp : item?.votesDown, own) + (own ? 1 : 0)
    }
    function _othersReactions(item: var): var {
        return root.liveCounts ? (root.liveCounts[item?.id]?.reactions ?? {}) : (item?.reactions ?? {})
    }
    function reactionCount(item: var, emoji: string): int {
        const own = Array.from(root.mine(item?.id).reactions ?? []).includes(emoji)
        const others = Number(root._othersReactions(item)[emoji] ?? 0)
        return (root.liveCounts ? others : Math.max(0, others - (own ? 1 : 0))) + (own ? 1 : 0)
    }
    // The reactions an item has, most given first ({emoji, count, mine}); the person's own stay even at one.
    function reactionsOf(item: var): var {
        const own = Array.from(root.mine(item?.id).reactions ?? [])
        const emojis = Object.keys(root._othersReactions(item)).concat(own.filter(e => !(e in root._othersReactions(item))))
        return emojis.map(emoji => ({ emoji: emoji, count: root.reactionCount(item, emoji), mine: own.includes(emoji) }))
            .filter(r => r.count > 0)
            .sort((a, b) => b.count - a.count || (b.mine ? 1 : 0) - (a.mine ? 1 : 0))
    }
    function canReact(id: string): bool {
        return Array.from(root.mine(id).reactions ?? []).length < root.maxReactions
    }
    // Emoji for the picker: the quick set and the common ones with no query, else a search by name ("pregnant").
    function emojiSearch(query: string): var {
        const q = String(query ?? "").trim()
        const all = Emojis.list
        const glyph = entry => String(entry).split(" ")[0]
        // a name that holds the words wins ("pregnant" is 🤰 🫃 🫄, not every flag fuzzy-close to it); fuzzy only
        // when no name does
        const words = q.toLowerCase().split(/\s+/).filter(w => w.length > 0)
        const named = all.filter(entry => {
            const name = String(entry).toLowerCase()
            return words.every(w => name.indexOf(" " + w) >= 0)
        })
        const found = q.length === 0 ? all.slice(0, 160) : (named.length > 0 ? named : Emojis.fuzzyQuery(q)).slice(0, 160)
        const list = (q.length === 0 ? root._pickerFirst : []).concat(found.map(glyph))
        return list.filter((e, i) => e.length > 0 && list.indexOf(e) === i)
    }
    function readCounts(): void {
        if (!root.online || countsProcess.running)
            return
        countsProcess.running = true
    }
    function vote(id: string, vote: string): void {
        const act = Object.assign({}, root.mine(id))
        act.vote = act.vote === vote ? undefined : vote
        root._setAct(id, act)
    }
    function react(id: string, emoji: string): void {
        const act = Object.assign({}, root.mine(id))
        const had = Array.from(act.reactions ?? [])
        if (!had.includes(emoji) && had.length >= root.maxReactions)
            return
        act.reactions = had.includes(emoji) ? had.filter(r => r !== emoji) : had.concat([emoji])
        root._setAct(id, act)
    }
    function setSharing(on: bool): void {
        Config.setNestedValue("hub.social.share", on)
        root._publishSoon.restart()
    }
    function _setAct(id: string, act: var): void {
        const items = Object.assign({}, Config.options?.hub?.social?.items ?? {})
        if (!act.vote && (act.reactions ?? []).length === 0)
            delete items[id]
        else
            items[id] = { vote: act.vote, reactions: act.reactions }
        Config.setNestedValue("hub.social.items", items)
        root._publishSoon.restart()
    }
    // Published a few seconds after the last change, after an install or removal, and once the catalogue is read;
    // the command skips it when nothing changed in a week.
    property Timer _publishSoon: Timer {
        interval: 4000
        onTriggered: {
            if (!root.online || socialProcess.running)
                return
            socialProcess.running = true
        }
    }
    Process {
        id: countsProcess
        command: [root.launcher, "hub", "counts", "--json"]
        stdout: StdioCollector {
            id: countsOut
            onStreamFinished: {
                let reply = null
                try {
                    reply = JSON.parse(countsOut.text)
                } catch (e) {
                    reply = null
                }
                // an inir without the verb, or no relay and no last read: the catalogue's counts stay
                if (reply && reply.items && typeof reply.items === "object")
                    root.liveCounts = reply.items
            }
        }
    }
    Process {
        id: socialProcess
        command: [root.launcher, "hub", "social"]
        onExited: code => {
            if (code !== 0)
                console.info("[Hub] votes not published yet, next time:", code)
        }
    }

    // 950, 1.2k, 18k, 2.4M
    function countText(n: real): string {
        n = Number(n ?? 0)
        const brief = (v, unit) => (v < 10 ? v.toFixed(1).replace(/\.0$/, "") : Math.round(v)) + unit
        return n >= 1e6 ? brief(n / 1e6, "M") : n >= 1e3 ? brief(n / 1e3, "k") : String(Math.round(n))
    }
    // Where people talk about an item and where they report it: its hub repo on GitHub.
    function _repo(item: var): string {
        return String(item?.page ?? "").match(/^https:\/\/github\.com\/[^/]+\/[^/]+/)?.[0] ?? ""
    }
    function reportUrl(item: var): string {
        const repo = root._repo(item)
        return repo ? `${repo}/issues/new?template=report.yml&item=${encodeURIComponent(item.id + " " + item.version)}` : ""
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
        statusProcess.command = [root.launcher, "hub", fetchNow ? "sync" : "status", "--json"]
        statusProcess.running = true
    }
    // The first look of a session: cached when fresh, so opening a page costs no download.
    function ensureLoaded(): void {
        if (!root.loaded && !statusProcess.running)
            root.refresh(false)
        root.readCounts()
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
            return Boolean(CustomWidgets.widgets.find(widget => widget.id === id)?.faces?.waffle)
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
        actionProcess.command = [root.launcher, "hub", root._current.verb, root._current.id, "--json"]
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
        statusProcess.command = [root.launcher, "hub", "status", "--cached", "--json"]
        statusProcess.running = true
    }

    // A plugin's own choices (plugin.json `choices`: { title, run }): its script prints them as [{ id, label, on }]
    // (`run list`) and flips one (`run toggle <id>`); every family's Hub page draws them as chips under it.
    property var choices: ({})
    function choicesTitle(item: var): string {
        return item?.installed ? String(Plugins.manifests[item.id]?.choices?.title ?? "") : ""
    }
    function readChoices(id: string): void { root._runChoices(id, ["list"]) }
    function toggleChoice(id: string, choice: string): void { root._runChoices(id, ["toggle", choice]) }
    function _runChoices(id: string, args: var): void {
        const script = Plugins.path(id, String(Plugins.manifests[id]?.choices?.run ?? ""))
        if (script.length === 0 || choicesProcess.running) return
        choicesProcess.plugin = id
        choicesProcess.command = ["bash", script].concat(args)
        choicesProcess.running = true
    }
    Process {
        id: choicesProcess
        property string plugin: ""
        stdout: StdioCollector {
            id: choicesOut
            onStreamFinished: {
                let list = []
                try { list = JSON.parse(choicesOut.text) } catch (e) { list = [] }
                const next = Object.assign({}, root.choices)
                next[choicesProcess.plugin] = Array.isArray(list) ? list : []
                root.choices = next
            }
        }
    }

    property Timer _refreshSoon: Timer {
        interval: 400
        onTriggered: root.refresh(false)
    }

    Process {
        id: statusProcess
        // The shell that asks is the one whose version decides what fits: without it the command looked only in
        // ~/.config/quickshell/inir, read 0.0.0 for a shell run from elsewhere and called every item too new.
        environment: ({ INIR_RUNTIME_DIR: root.launcher.replace(/\/scripts\/inir$/, "") })
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
                    // finished, with nothing: the pages show the error instead of reading forever
                    root.checkedAt = Date.now()
                    root.loaded = true
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
                root._publishSoon.restart()
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
        // It reads the catalogue again itself; no `hub changed` call back into this shell.
        environment: ({ INIR_HUB_FROM_SHELL: "1", INIR_RUNTIME_DIR: root.launcher.replace(/\/scripts\/inir$/, "") })
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

    /// The community hub (widgets, colour themes, iRiS themes, web apps from
    /// [inir-hub](https://github.com/snowarch/inir-hub)) as the running shell sees it. `inir hub
    /// list|search|info|install|update|remove|sync` works with or without the shell running and tells it afterwards;
    /// these functions queue the same actions inside the shell, so its Hub page shows them happening. All families.
    ///
    /// ```sh
    /// inir hub install countdown
    /// inir hub open
    /// ```
    IpcHandler {
        target: "hub"

        /// Read every source again now
        function refresh(): string {
            root.refresh(true)
            return "fetching"
        }
        /// Queue an install
        function install(id: string): string {
            root.install(id)
            return `queued ${id}`
        }
        /// Queue a removal (only things the hub installed)
        function remove(id: string): string {
            root.remove(id)
            return `queued ${id}`
        }
        /// Queue an update; `all` (or nothing) updates everything that has one
        function update(id: string): string {
            if (id.length === 0 || id === "all")
                root.updateAll()
            else
                root.update(id)
            return "queued"
        }
        // Put an installed item to use in the family on screen: a widget on the Island or the
        // desktop, a colour theme applied. iRiS themes apply with `inir iris theme apply:<id>`.
        /// Put an installed item to use here: a widget on the Island (iRiS) or the desktop, a colour theme applied
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
        /// Open that item's page in the Hub page (`inir hub open <id>` also opens Settings there)
        function openItem(id: string): string {
            root.requestedId = id
            root.ensureLoaded()
            return id
        }
        // The shell's view: what it lists, what is installed, what is running.
        /// JSON: loaded, item count, installed ids, updates, what is running, failures, last error
        function status(): string {
            return JSON.stringify({ loaded: root.loaded, items: root.items.length,
                installed: root.items.filter(item => item.installed).map(item => item.id),
                updates: root.updates, busy: root.busy, failures: root.failures, error: root.error })
        }
        // A change made outside the shell (the inir hub command): read the catalogue again and
        // let the registries reload.
        /// Something was installed outside the shell: reload `widget`, `theme`, `iris-theme`, `webapp` or `all`
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
