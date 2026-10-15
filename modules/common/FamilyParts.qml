pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// What a family draws on a surface several families share: its lock screen, its close confirmation, a desktop widget's
// face. Each family lists its parts in modules/<family>/parts.json (part name -> file relative to that folder), so
// shared code asks for a part by name and never names a family's file; the folder boundaries stay checkable.
Singleton {
    id: root

    readonly property string active: String(Config.options?.panelFamily ?? "ii")
    // Read in the same frame the singleton is made: a desktop widget sizes itself from whether it has a face, and a
    // list that arrived a frame later sized every widget as faceless and moved them on the desktop.
    property int _revision: 0
    readonly property var manifests: root._revision, ({ ii: root.read(iiFile).parts ?? ({}), waffle: root.read(waffleFile).parts ?? ({}), iris: root.read(irisFile).parts ?? ({}) })
    readonly property var flags: root._revision, ({ ii: root.read(iiFile).flags ?? ({}), waffle: root.read(waffleFile).flags ?? ({}), iris: root.read(irisFile).flags ?? ({}) })

    function read(file: FileView): var {
        const text = file.text()
        if (!text) return ({})
        try { return JSON.parse(text) } catch (error) { console.warn(`[FamilyParts] ${file.path}: ${error}`); return ({}) }
    }

    // The file a family draws a part with, or "" when that family has none (the shared surface keeps its own).
    function url(family: string, part: string): string {
        const relative = root.manifests[family]?.[part]
        return relative ? Quickshell.shellPath(`modules/${family}/${relative}`) : ""
    }
    // A yes/no a family states about a part (parts.json "flags"), e.g. that its lock surface loads in one go.
    function flag(family: string, name: string): bool {
        return Boolean(root.flags[family]?.[name])
    }
    function has(family: string, part: string): bool {
        return root.url(family, part).length > 0
    }

    component PartsFile: FileView {
        blockLoading: true
        watchChanges: true
        // Loading blocks, so the list is new by the time the revision moves (bumping from onLoaded looped the binding).
        onFileChanged: { reload(); root._revision++ }
    }
    PartsFile { id: iiFile; path: Quickshell.shellPath("modules/ii/parts.json") }
    PartsFile { id: waffleFile; path: Quickshell.shellPath("modules/waffle/parts.json") }
    PartsFile { id: irisFile; path: Quickshell.shellPath("modules/iris/parts.json") }
}
