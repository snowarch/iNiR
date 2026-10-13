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
    // How the field cuts a body's corners (IrisField.frag bodyBox): "round" or "chamfer".
    readonly property string fieldCorner: String(root.manifest?.field?.corner ?? "round")
    // The solver language the Design paints with (scripts/colors/washi), or "" to keep the person's Style.
    readonly property string palette: String(root.manifest?.palette ?? "")
    // What the Design wears whatever the person's rows say: its preset, its type, its camera.
    readonly property string preset: String(root.manifest?.preset ?? "")
    readonly property var fonts: root.manifest?.fonts ?? ({})
    function font(role: string): string { return String(root.fonts?.[role] ?? "") }
    readonly property string morph: String(root.manifest?.motion?.morph ?? "")
    // How the Design reads, as traits any surface can honour (DESIGNS.md › rasgos): marks "glyph" (no tinted squircles),
    // selection "plate" (the chosen row is a solid plate, not an accent wash), index (lists numbered 01, 02…),
    // captions "mono" (labels in mono capitals), titles "lower" (page titles in lower case).
    readonly property var traits: root.manifest?.traits ?? ({})
    function trait(name: string): var { return root.traits?.[name] }
    readonly property int motionDuration: Number(root.manifest?.motion?.duration ?? 0)
    // Every Design shipped, with its name and its own picture for the Settings row (parts/Preview.qml in its folder).
    readonly property var catalogue: root.known.map(id => ({ value: id, label: ({ iris: "iRiS", airisu: "AIRISU" })[id] ?? id,
        preview: `${root.folder(id)}parts/Preview.qml` }))

    function folder(id: string): url {
        return Qt.resolvedUrl(`../designs/${id}/`)
    }
    // The skin a Design draws for `part`, or "" when the part keeps the primitive's own anatomy.
    function skin(part: string): string {
        const relative = String(root.parts?.[part] ?? "")
        return relative.length > 0 ? `${root.folder(root.current)}${relative}` : ""
    }
    // What a surface's body needs to hold this Design's scene (its width, its padding), or `fallback`.
    function surface(id: string, key: string, fallback: var): var {
        const value = root.manifest?.surfaces?.[id]?.[key]
        return value === undefined ? fallback : value
    }
    function has(part: string): bool {
        return String(root.parts?.[part] ?? "").length > 0
    }
    // The options the Design decides for itself (IrisStyle and IrisWashi read the Design first): Settings leaves their
    // rows out while it is worn, and they apply again under another Design.
    function owns(path: string): bool {
        switch (path) {
        case "iris.appearance.language": case "iris.appearance.variant": return root.palette.length > 0
        case "iris.appearance.preset": return root.preset.length > 0
        case "iris.appearance.fontFamily": return root.font("text").length > 0
        case "iris.appearance.titleFontFamily": return root.font("title").length > 0
        case "iris.appearance.numbersFontFamily": return root.font("numbers").length > 0
        case "iris.appearance.morph": return root.morph.length > 0
        case "iris.appearance.settingsLayout": return root.has("settingsPage")
        }
        return false
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
