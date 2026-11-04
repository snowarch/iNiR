pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

// What is installed: every folder under modules/ that carries a plugin.json (the families today, components and
// the person's plugin folder next). A plugin lists the files it hands the base by name (`parts`: its panels, what it
// draws on shared surfaces) and yes/no facts about them (`flags`); the base asks here and never names its files.
Singleton {
    id: root

    property var manifests: ({})
    property int _read: 0
    property bool _seeded: false
    readonly property bool ready: root._seeded || (folders.status === FolderListModel.Ready && root._read >= folders.count)
    readonly property var families: Object.keys(root.manifests).filter(id => root.manifests[id].kind === "family").sort()
    // Components that bring a surface of their own (`parts.panel`). A component adds to the desktop without editing a
    // family: its panel holds its windows and its IpcHandler, and loads while the active family is one it names in
    // `families` (every family when it names none).
    readonly property var components: Object.keys(root.manifests)
        .filter(id => root.manifests[id].kind === "component" && String(root.manifests[id].parts?.panel ?? "").length > 0).sort()
    function wornWith(id: string, family: string): bool {
        const families = root.manifests[id]?.families
        return !Array.isArray(families) || families.length === 0 || families.includes(family)
    }
    readonly property string active: String(Config.options?.panelFamily ?? "ii")

    // The family whose Settings opens: the active one, or the one it wears instead while a key of its own says so
    // (`settingsFrom`: { family, when }).
    readonly property string settingsFamily: {
        const from = root.manifests[root.active]?.settingsFrom
        return from && root.has(from.family) && Config.getNestedValue(String(from.when), false) === true ? from.family : root.active
    }

    function has(id: string): bool { return !!root.manifests[id] }
    // The file a plugin draws a part with, or "" when it has none (the base keeps its own).
    function part(id: string, name: string): string {
        const manifest = root.manifests[id]
        const file = String(manifest?.parts?.[name] ?? "")
        // Resolved beside this file, so a part keeps the scheme the shell's own files load with: a file:// twin of a
        // root: folder breaks that folder's qmldir for every later import of it.
        return file.length > 0 ? Qt.resolvedUrl(`../${manifest.provides}/${file}`).toString() : ""
    }
    // A file of the base for a plugin to load by URL: a plugin's own `../` climbs out of wherever it is installed.
    function baseUrl(file: string): string { return Qt.resolvedUrl(`../${file}`).toString() }
    function flag(id: string, name: string): bool { return Boolean(root.manifests[id]?.flags?.[name]) }
    // A setting the base honours for a plugin, read where the plugin keeps it (`settings`: { slot: { key, fallback } }):
    // its fallback when unset or empty, `otherwise` when the plugin keeps none.
    function setting(id: string, slot: string, otherwise: var): var {
        const spec = root.manifests[id]?.settings?.[slot]
        if (!spec?.key) return otherwise
        // `when`: a key of the family's own that switches the slot off (Waffle's "Take style from Material")
        if (spec.when && !Config.getNestedValue(String(spec.when), false)) return spec.fallback ?? otherwise
        const value = Config.getNestedValue(String(spec.key), undefined)
        return value === undefined || value === null || value === "" ? (spec.fallback ?? otherwise) : value
    }
    function settingKey(id: string, slot: string): string { return String(root.manifests[id]?.settings?.[slot]?.key ?? "") }
    // The login look a family wears when the person leaves it on auto (`loginScreen`: { look, reads }), and the keys
    // that look is drawn from, so a change to them re-syncs it.
    function loginScreen(id: string): string { return String(root.manifests[id]?.loginScreen?.look ?? "") }
    readonly property var loginScreens: Object.keys(root.manifests).map(id => root.loginScreen(id)).filter(look => look.length > 0)
    readonly property var loginReads: Object.keys(root.manifests).sort().reduce((all, id) => all.concat(Array.from(root.manifests[id].loginScreen?.reads ?? [])), [])
    // Where the dev tools can open a family's own surfaces (`devDestinations`), each tagged with its family.
    readonly property var devDestinations: Object.keys(root.manifests).sort().reduce((all, id) => all.concat(
        Array.from(root.manifests[id].devDestinations ?? []).map(entry => Object.assign({ family: id, view: "", safe: true }, entry))), [])
    // The panels a family turns on when it first runs (`enabledPanels`).
    function panels(id: string): var { return Array.from(root.manifests[id]?.enabledPanels ?? []) }
    // A file of a plugin on disk, for what is copied rather than loaded (a template).
    function path(id: string, file: string): string {
        const manifest = root.manifests[id]
        return manifest && file.length > 0 ? Quickshell.shellPath(`${manifest.provides}/${file}`) : ""
    }

    function _take(folder: string, raw: string): void {
        let manifest = null
        try { manifest = JSON.parse(raw) } catch (e) { console.warn(`[Plugins] modules/${folder}/plugin.json: ${e}`) }
        if (manifest?.id === folder && typeof manifest.kind === "string") {
            const next = Object.assign({}, root.manifests)
            next[folder] = Object.assign({ provides: `modules/${folder}`, parts: {}, flags: {} }, manifest)
            root.manifests = next
            if (root._loadable !== null && !root._loadable.includes(folder))
                arrived.restart()
        }
        root._read++
    }

    // The folder model answers only once the shell is up, and Config waits on this before its first read (1.3 s at
    // login): plugins.list, which `inir hub` rewrites on every link, names every plugin folder already, so their
    // plugin.json are read here at once; the model below follows later installs.
    FileView {
        id: probe
        preload: false
        blockAllReads: true
        printErrors: false
    }
    function _readNow(file: string): string {
        probe.path = Quickshell.shellPath(file)
        probe.reload()
        return String(probe.text() ?? "")
    }
    Component.onCompleted: {
        const found = new Set()
        for (const line of root._readNow("plugins.list").split("\n"))
            if (/^[A-Za-z0-9_]+$/.test(line.trim())) found.add(line.trim())
        for (const folder of found) {
            const raw = root._readNow(`modules/${folder}/plugin.json`)
            if (raw.length > 0) root._take(folder, raw)
        }
        probe.path = ""
        root._read = 0
        root._seeded = Object.keys(root.manifests).length > 0
    }

    FolderListModel {
        id: folders
        folder: Qt.resolvedUrl(Quickshell.shellPath("modules"))
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        onStatusChanged: {
            if (folders.status !== FolderListModel.Ready || root._loadable !== null) return
            const names = []
            for (let i = 0; i < folders.count; i++) names.push(String(folders.get(i, "fileName")))
            root._loadable = names
        }
    }

    // The shell loads its files from the copy of its folder that each (re)load makes: a plugin installed while it runs
    // is listed at once, but its parts (a Design's face, a component's panel) load only after the next reload. One
    // soft reload once it lands; never while the screen is locked.
    property var _loadable: null
    Timer {
        id: arrived
        interval: 1500
        onTriggered: {
            if (GlobalStates.screenLocked) {
                arrived.interval = 5000
                arrived.restart()
                return
            }
            Quickshell.reload(false)
        }
    }

    Instantiator {
        model: folders
        delegate: FileView {
            required property string fileName
            path: Quickshell.shellPath(`modules/${fileName}/plugin.json`)
            blockLoading: true
            printErrors: false
            onLoaded: root._take(fileName, text())
            onLoadFailed: root._read++
        }
    }
}
