pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// What is installed: every folder under modules/ that carries a plugin.json (the families today, components and
// the person's plugin folder next). The shell finds a plugin's entry files here and never names one in code.
Singleton {
    id: root

    property var manifests: ({})
    property int _read: 0
    readonly property bool ready: folders.status === FolderListModel.Ready && root._read >= folders.count
    readonly property var families: Object.keys(root.manifests).filter(id => root.manifests[id].kind === "family").sort()

    function has(id: string): bool { return !!root.manifests[id] }
    // The shell-relative path of a plugin's entry ("" when the plugin or the entry is missing).
    function entry(id: string, key: string): string {
        const manifest = root.manifests[id]
        const file = String(manifest?.entries?.[key] ?? "")
        return file.length > 0 ? `${manifest.provides}/${file}` : ""
    }

    function _take(folder: string, raw: string): void {
        let manifest = null
        try { manifest = JSON.parse(raw) } catch (e) { console.warn(`[Plugins] modules/${folder}/plugin.json: ${e}`) }
        if (manifest?.id === folder && typeof manifest.kind === "string") {
            const next = Object.assign({}, root.manifests)
            next[folder] = Object.assign({ provides: `modules/${folder}`, entries: {} }, manifest)
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
