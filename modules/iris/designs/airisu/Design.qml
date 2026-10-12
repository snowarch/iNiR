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
        spotlight: "scenes/Spotlight.qml",
        osd: "scenes/Osd.qml",
        banner: "scenes/Banner.qml",
        lock: "scenes/Lock.qml",
        session: "scenes/Session.qml",
        clockFace: "parts/ClockFace.qml",
        // Skins of iRiS's primitives: every surface that uses them (Settings, the dock, menus, the sidebars) wears them.
        switch: "skins/Switch.qml",
        segmented: "skins/Segmented.qml",
        button: "skins/Button.qml",
        meter: "skins/Meter.qml",
        ring: "skins/Ring.qml",
        groupHeader: "skins/GroupHeader.qml",
        cardHeader: "skins/CardHeader.qml",
        slider: "skins/Slider.qml",
        scrubber: "skins/Scrubber.qml"
    })
    // How a surface's body holds this Design's scene: its width and its inner padding (0: laid edge to edge).
    readonly property var surfaces: ({ controlCenter: { width: 440, padding: 0, gap: 12 },
        banners: { width: 400, corner: "bottomLeft", margin: 24 } })
    readonly property var field: ({ corner: "chamfer" }) // a sticker cut with a blade (IrisField.frag bodyBox)
    readonly property string preset: "night"
    readonly property var fonts: ({ text: "Archivo", title: "Archivo SemiExpanded", numbers: "Archivo SemiExpanded",
        mono: "JetBrainsMono Nerd Font" })
    readonly property var motion: ({ morph: "tuned", duration: 220 })
    // A parts catalogue, not an app grid: glyphs without tinted plates, the chosen row on the gofun plate, lists numbered,
    // labels in mono capitals, titles in lower case.
    readonly property var traits: ({ marks: "glyph", selection: "plate", index: true, captions: "mono", titles: "lower" })
}
