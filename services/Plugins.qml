pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.modules.common

// What is installed: every folder under modules/ that carries a plugin.json (the families today, components and
// the person's plugin folder next). A plugin lists the files it hands the base by name (`parts`: its panels, what it
// draws on shared surfaces) and yes/no facts about them (`flags`); the base asks here and never names its files.
Singleton {
    id: root

    property var manifests: ({})
    property int _read: 0
    readonly property bool ready: folders.status === FolderListModel.Ready && root._read >= folders.count
    readonly property var families: Object.keys(root.manifests).filter(id => root.manifests[id].kind === "family").sort()
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
    function flag(id: string, name: string): bool { return Boolean(root.manifests[id]?.flags?.[name]) }

    function _take(folder: string, raw: string): void {
        let manifest = null
        try { manifest = JSON.parse(raw) } catch (e) { console.warn(`[Plugins] modules/${folder}/plugin.json: ${e}`) }
        if (manifest?.id === folder && typeof manifest.kind === "string") {
            const next = Object.assign({}, root.manifests)
            next[folder] = Object.assign({ provides: `modules/${folder}`, parts: {}, flags: {} }, manifest)
            root.manifests = next
        }
        root._read++
    }

    FolderListModel {
        id: folders
        folder: Qt.resolvedUrl(Quickshell.shellPath("modules"))
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
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
