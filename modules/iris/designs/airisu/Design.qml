import QtQuick

// AIRISU (modules/iris/AIRISU.md): the Japanese look around tuning, stickers and seals. Its values are the curated
// Theme `airisu`; its anatomy is the skins below. Coverage is tracked part by part in AIRISU.md.
QtObject {
    readonly property string id: "airisu"
    readonly property string name: "AIRISU"
    readonly property string theme: "airisu"
    // The solver's language for this Design (scripts/colors/washi/airisu.go): lacquer, gofun, the vermilion seal.
    readonly property string palette: "airisu"
    readonly property var parts: ({
        insignia: "parts/Insignia.qml",
        controlCenter: "scenes/ControlCenter.qml",
        bar: "scenes/Bar.qml",
        spotlight: "scenes/Spotlight.qml"
    })
    // How a surface's body holds this Design's scene: its width and its inner padding (0: laid edge to edge).
    readonly property var surfaces: ({ controlCenter: { width: 440, padding: 0, gap: 12 } })
    readonly property var field: ({ corner: "chamfer" }) // a sticker cut with a blade (IrisField.frag bodyBox)
}
