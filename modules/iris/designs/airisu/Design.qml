import QtQuick

// AIRISU (designs/airisu/SYSTEM.md): coloured lacquer (色漆). Every surface is a panel cut by one die (45° off two
// opposite corners) and lacquered in the pigment of its subject; what it measures is a second coat whose edge runs at the
// same 45°, a change of subject repaints it along that cut. Its
// values are the curated Theme `airisu` and the solver's `airisu` palette; its anatomy is the parts below, which draw
// the engine's own state and keep every Settings row's meaning.
QtObject {
    readonly property string id: "airisu"
    readonly property string name: "AIRISU"
    readonly property string theme: "airisu"
    // The solver's language for this Design (scripts/colors/washi/airisu.go): urushi, its pigments, the vermilion seal.
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
        // Settings as a lacquered catalogue: the thumb index down the fore-edge, the spread, its head and foot; the
        // engine's search field sits in it as a slot cut into the body.
        settingsPage: "scenes/Settings.qml",
        settingsSearch: "skins/SettingsSearch.qml",
        // General's head: the desktop printed as the frontispiece beside the person's name.
        welcomeCard: "skins/WelcomeCard.qml",
        banner: "scenes/Banner.qml",
        osd: "scenes/Osd.qml",
        session: "scenes/Session.qml",
        // The lock: iRiS's stage and its blocks, editing and zones, drawn with these parts.
        lockPlate: "skins/LockPlate.qml",
        lockClock: "skins/LockClock.qml",
        lockSignIn: "skins/LockSignIn.qml",
        lockChip: "skins/LockChip.qml",
        lockActivity: "skins/LockActivity.qml",
        lockReading: "skins/LockReading.qml",
        lockChrome: "skins/LockChrome.qml",
        lockSeat: "skins/LockSeat.qml",
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
        widgetNowPlaying: "widgets/NowPlaying.qml",
        controlTile: "skins/ControlTile.qml",
        controlHeader: "skins/ControlHeader.qml",
        controlPreset: "skins/ControlPreset.qml",
        controlPlate: "skins/ControlPlate.qml",
        mediaBackdrop: "skins/MediaBackdrop.qml",
        mediaCard: "skins/MediaCard.qml",
        noticeRow: "skins/NoticeRow.qml",
        noticeCard: "skins/NoticeCard.qml",
        menuRow: "skins/MenuRow.qml",
        listMark: "skins/ListMark.qml",
        oskKey: "skins/OskKey.qml",
        // Desktop widgets, each a print of its own: drawn whatever widget design is chosen (DesktopWidgetDesign).
        widgetClock: "widgets/Clock.qml",
        widgetWeather: "widgets/Forecast.qml",
        widgetDate: "widgets/Leaf.qml",
        widgetUptime: "widgets/Uptime.qml",
        widgetDay: "widgets/DayRule.qml",
        widgetWorldClock: "widgets/WorldClock.qml",
        widgetCalendar: "widgets/Calendar.qml",
        widgetAgenda: "widgets/Agenda.qml",
        widgetTimers: "widgets/Timers.qml",
        widgetNotes: "widgets/Notes.qml",
        widgetNews: "widgets/News.qml",
        widgetProfile: "widgets/Profile.qml",
        widgetScreenTime: "widgets/DayLog.qml",
        widgetBattery: "widgets/Charge.qml",
        widgetTodo: "widgets/Tasks.qml",
        widgetVisualizer: "widgets/Spectrum.qml",
        widgetEditorial: "widgets/Poster.qml",
        widgetJapanese: "widgets/Hanko.qml",
        widgetVitals: "widgets/Vitals.qml",
        // Every other widget: iRiS's face set on AIRISU's lacquer.
        widgetStock: "widgets/Stock.qml"
    })
    // What a primitive needs to hold this Design's skin, and how a surface's body holds a scene.
    readonly property var surfaces: ({ switch: { width: 48, height: 26 }, banners: { width: 380, margin: 24 } })
    // Every body is cut with a blade (IrisField.frag bodyBox): 45° off two opposite corners, gussets where bodies meet.
    readonly property var field: ({ corner: "chamfer" })
    readonly property string preset: "night"
    readonly property var fonts: ({ text: "Archivo", title: "Archivo SemiExpanded", numbers: "Archivo SemiExpanded",
        mono: "JetBrainsMono Nerd Font" })
    readonly property var motion: ({ morph: "tuned", duration: 220 })
    // How it reads: glyphs without tinted plates; the chosen row lacquered in the accent; lists that can be typed
    // numbered; Island pages hang under the strip as a panel of their own; a level runs along a piece's cut edge; the
    // pointer lays an opaque coat where a surface has no key of its own.
    readonly property var traits: ({ marks: "glyph", selection: "plate", index: true,
        pages: "hang", rings: "edge", hover: "plate" })
}
