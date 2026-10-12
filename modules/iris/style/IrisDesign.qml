pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

// The registry of iRiS Designs (modules/iris/DESIGNS.md). A Design is a folder under modules/iris/designs with a
// Design.qml manifest; its `parts` name the skins it draws. A primitive asks `skin(part)` and, when it gets a url,
// loads it with `host` set to itself; otherwise it draws its own anatomy. Behaviour always stays in the primitive.
Singleton {
    id: root

    // One line per Design shipped with iNiR; D3 replaces this with a folder scan (and user Designs).
    readonly property var known: ["iris", "airisu"]
    readonly property string requested: String(Config.options?.iris?.appearance?.design ?? "iris")
    readonly property string current: root.known.includes(root.requested) ? root.requested : "iris"
    readonly property bool custom: root.current !== "iris"

    property QtObject manifest: null
    readonly property var parts: root.manifest?.parts ?? ({})
    readonly property string name: String(root.manifest?.name ?? "iRiS")
    // The solver language the Design paints with (scripts/colors/washi), or "" to keep the person's Style.
    readonly property string palette: String(root.manifest?.palette ?? "")

    function folder(id: string): url {
        return Qt.resolvedUrl(`../designs/${id}/`)
    }
    // The skin a Design draws for `part`, or "" when the part keeps the primitive's own anatomy.
    function skin(part: string): string {
        const relative = String(root.parts?.[part] ?? "")
        return relative.length > 0 ? `${root.folder(root.current)}${relative}` : ""
    }
    function has(part: string): bool {
        return String(root.parts?.[part] ?? "").length > 0
    }

    function load(): void {
        const component = Qt.createComponent(`${root.folder(root.current)}Design.qml`)
        if (component.status !== Component.Ready) {
            console.warn(`[IrisDesign] ${root.current}: ${component.errorString()}`)
            if (root.manifest) root.manifest.destroy()
            root.manifest = null
            return
        }
        const next = component.createObject(root)
        const previous = root.manifest
        root.manifest = next
        if (previous) previous.destroy()
    }
    onCurrentChanged: root.load()
    Component.onCompleted: root.load()
}
