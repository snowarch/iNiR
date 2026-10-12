import QtQuick

// AIRISU (designs/airisu/SYSTEM.md): printed, not painted. The shell as the work of a night print shop: die-cut stickers,
// seals, tickets, spec labels and parts catalogues, each surface a printed object with its own technique. Its values
// are the curated Theme `airisu` and the solver's `airisu` palette; its anatomy is the parts below, which draw the
// engine's own state and keep every Settings row's meaning.
QtObject {
    readonly property string id: "airisu"
    readonly property string name: "AIRISU"
    readonly property string theme: "airisu"
    // The solver's language for this Design (scripts/colors/washi/airisu.go): lacquer, gofun, the vermilion seal.
    readonly property string palette: "airisu"
    readonly property var parts: ({
        insignia: "parts/Insignia.qml",
        islandFace: "island/Face.qml",
        islandNav: "island/Nav.qml",
        islandMedia: "island/Media.qml",
        islandDesktop: "island/Desktop.qml",
        islandActivity: "island/Activity.qml",
        islandArtBackdrop: "island/ArtBackdrop.qml",
        spotlightHead: "skins/SpotlightHead.qml",
        sectionTab: "skins/SectionTab.qml",
        banner: "scenes/Banner.qml",
        osd: "scenes/Osd.qml",
        session: "scenes/Session.qml",
        // Skins of iRiS's primitives: every surface that uses them (Settings, the dock, menus, the sidebars) wears them.
        switch: "skins/Switch.qml",
        segmented: "skins/Segmented.qml",
        button: "skins/Button.qml",
        meter: "skins/Meter.qml",
        ring: "skins/Ring.qml",
        groupHeader: "skins/GroupHeader.qml",
        cardHeader: "skins/CardHeader.qml",
        slider: "skins/Slider.qml",
        scrubber: "skins/Scrubber.qml",
        notificationIcon: "skins/NotificationIcon.qml",
        badge: "skins/Badge.qml",
        dockSlot: "skins/DockSlot.qml",
        toolDial: "skins/ToolDial.qml",
        controlTile: "skins/ControlTile.qml",
        controlHeader: "skins/ControlHeader.qml",
        controlPreset: "skins/ControlPreset.qml",
        mediaBackdrop: "skins/MediaBackdrop.qml"
    })
    // What a primitive needs to hold this Design's skin, and how a surface's body holds a scene.
    readonly property var surfaces: ({ switch: { width: 52, height: 24 }, banners: { width: 380, margin: 24 } })
    readonly property var field: ({ corner: "chamfer" }) // a sticker cut with a blade (IrisField.frag bodyBox)
    readonly property string preset: "night"
    readonly property var fonts: ({ text: "Archivo", title: "Archivo SemiExpanded", numbers: "Archivo SemiExpanded",
        mono: "JetBrainsMono Nerd Font" })
    readonly property var motion: ({ morph: "tuned", duration: 220 })
    // How it reads: glyphs without tinted plates; the chosen row a solid ink plate; lists that can be typed numbered;
    // Island pages hang under the strip as a plate of their own; a level runs along a piece's cut edge; the pointer
    // lights an opaque plate where a surface has no crop marks of its own yet.
    readonly property var traits: ({ marks: "glyph", selection: "plate", index: true,
        pages: "hang", rings: "edge", hover: "plate" })
}
