pragma Singleton
pragma ComponentBehavior: Bound
import QtQml

// Every built-in desktop widget, once. The edit shelf, the iRiS gallery and lock, Settings, the IPC and the Material
// size classes all read this list; dev/tests/test-desktop-widget-registry.py fails when a widget is missing anywhere
// it must be.
//
// Adding a widget:
//   1. Its folder here (`<key>/<Name>Widget.qml`, an AbstractBackgroundWidget with `configEntryName: "<key>"`).
//   2. One entry below. `name` is what people call it (shelf, gallery), `group` its Settings heading; both go to
//      every catalogue in translations/. `lock`: offered on the lock screen and in the iRiS gallery. `palette`: it
//      has the semantic palette roles (`background.widgets.<key>.palette`). `sizes`: Material's size classes,
//      default first (`box` takes the footprint as content size; a size can carry its own values).
//   3. Its config block in modules/common/Config.qml (`background.widgets.<key>`, `enable` at `defaultOn`).
//   4. Its FadeLoader in Background.qml; with `lock`, its Component in modules/iris/lock/IrisLockWidgets.qml.
//   5. A family's own face stays that family's: an iRiS face is `widgetFace.<part>` in modules/iris/parts.json and
//      `irisFacePart: "<part>"` on the widget.
// Entry order is the shelf's; the iRiS gallery keeps its own (IrisFaceData.order, a widget it lacks goes last).
QtObject {
    id: root

    readonly property var entries: [
        { key: "weather", name: "Weather", group: "Weather", component: "WeatherWidget", glyph: "cloud", tint: "#0a84ff", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["small", "medium", "large"],
            keywords: "forecast temperature rain sun wind climate" },
        { key: "clock", name: "Clock", group: "Clock", component: "ClockWidget", glyph: "schedule", tint: "#ff9f0a", category: "today", defaultOn: true, lock: true, palette: true, sizes: ["medium", "small", "large"],
            keywords: "time hour watch" },
        { key: "worldClock", name: "World clock", group: "World clock", component: "WorldClockWidget", glyph: "public", tint: "#ff9f0a", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["medium", "large"], box: true,
            keywords: "time zones cities timezone" },
        { key: "dayProgress", name: "Day", group: "Day progress", component: "DayProgressWidget", glyph: "timelapse", tint: "#ff9f0a", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["small", "large"], box: true,
            keywords: "day sun hours" },
        { key: "uptime", name: "Uptime", group: "System uptime", component: "UptimeWidget", glyph: "avg_pace", tint: "#5e5ce6", category: "system", defaultOn: false, lock: true, palette: true, sizes: ["small", "medium"], box: true,
            keywords: "boot session running" },
        { key: "mediaControls", name: "Now Playing", group: "Media Controls", component: "MediaControlsWidget", glyph: "album", tint: "#ff375f", category: "media", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small", "large"],
            keywords: "music player now playing song spotify cover" },
        { key: "visualizer", name: "Visualizer", group: "Visualizer", component: "VisualizerWidget", glyph: "graphic_eq", tint: "#bf5af2", category: "media", defaultOn: false, lock: false, palette: true, sizes: ["medium", "small", "large"], box: true,
            keywords: "audio cava spectrum equalizer sound" },
        { key: "systemMonitor", name: "Vitals", group: "System Monitor", component: "SystemMonitorWidget", glyph: "monitor_heart", tint: "#34c759", category: "system", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small", "large"], box: true,
            keywords: "vitals cpu gpu ram memory temperature performance" },
        { key: "battery", name: "Batteries", group: "Battery", component: "BatteryWidget", glyph: "battery_full", tint: "#34c759", category: "system", defaultOn: false, lock: true, palette: true, sizes: ["small", "medium", "large"],
            keywords: "power charge" },
        { key: "notes", name: "Notes", group: "Notes", component: "NotesWidget", glyph: "sticky_note_2", tint: "#ffcc00", category: "notes", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small", "large"], box: true,
            keywords: "sticky memo text write" },
        { key: "calendarUpcoming", name: "Up next", group: "Upcoming Events", component: "CalendarUpcomingWidget", glyph: "event", tint: "#ff3b30", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small", "large"], box: true,
            keywords: "agenda events next up" },
        { key: "monthCalendar", name: "Calendar", group: "Month Calendar", component: "MonthCalendarWidget", glyph: "calendar_month", tint: "#ff3b30", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["large", "small", "medium"], box: true,
            keywords: "calendar month date days" },
        { key: "dateBadge", name: "Date", group: "Date badge", component: "DateBadgeWidget", glyph: "today", tint: "#ff3b30", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["small", "medium", "large"], box: true,
            keywords: "date day today" },
        { key: "todo", name: "Tasks", group: "Todo", component: "TodoWidget", glyph: "checklist", tint: "#ff9f0a", category: "notes", defaultOn: false, lock: true, palette: true, sizes: ["large", "small", "medium"], box: true,
            keywords: "tasks checklist list" },
        { key: "timers", name: "Timers", group: "Timers", component: "TimerWidget", glyph: "timer", tint: "#ff9f0a", category: "today", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small", "large"],
            keywords: "timer stopwatch countdown alarm pomodoro" },
        { key: "newsTicker", name: "News", group: "News", component: "NewsTickerWidget", glyph: "newspaper", tint: "#30b0c7", category: "media", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small", "large"], box: true,
            keywords: "news feed rss headlines" },
        { key: "userCard", name: "Profile", group: "User card", component: "UserCardWidget", glyph: "account_circle", tint: "#0a84ff", category: "system", defaultOn: false, lock: true, palette: true, sizes: ["medium", "small"], box: true,
            keywords: "profile avatar account you" },
        { key: "customImage", name: "Image", group: "Custom image", component: "CustomImageWidget", glyph: "add_photo_alternate", tint: "#30b0c7", category: "decor", defaultOn: false, lock: false, palette: true, sizes: ["medium", "small", "large"], box: true,
            keywords: "picture photo image" },
        { key: "imageConverter", name: "Image converter", group: "Image converter", component: "ImageConverterWidget", glyph: "transform", tint: "#30b0c7", category: "decor", defaultOn: false, lock: false, palette: true, sizes: ["large", "medium"], box: true,
            keywords: "picture convert image" },
        { key: "japaneseTypography", name: "Japanese Typography", group: "Japanese Typography", component: "JapaneseTypographyWidget", glyph: "translate", tint: "#bf5af2", category: "decor", defaultOn: false, lock: false, palette: true, sizes: ["large"], box: true,
            keywords: "japanese kanji text" },
        { key: "editorial", name: "Editorial", group: "Editorial", component: "EditorialWidget", glyph: "text_fields", tint: "#5e5ce6", category: "decor", defaultOn: false, lock: false, palette: true, sizes: ["large", "medium"], box: true,
            keywords: "text typography quote" },
        { key: "shape", name: "Shape", group: "Decorative shape", component: "ShapeWidget", glyph: "category", tint: "#bf5af2", category: "decor", defaultOn: false, lock: false, palette: true, sizes: ["small", "medium", "large"], box: true,
            keywords: "decoration decorative" },
        { key: "mascot", name: "Mascot", group: "Mascot", component: "MascotWidget", glyph: "pets", tint: "#ff375f", category: "decor", defaultOn: false, lock: false, palette: true, sizes: ["large", "small"], small: { contentWidth: 176 }, large: { contentWidth: 368 },
            keywords: "pet character companion" },
        { key: "controls", name: "Controls", group: "Controls", component: "ControlsWidget", glyph: "toggle_on", tint: "#0a84ff", category: "system", defaultOn: false, lock: true, palette: false, sizes: [],
            keywords: "toggles wifi bluetooth volume brightness quick settings" },
        { key: "screenTime", name: "Screen Time", group: "Screen time", component: "ScreenTimeWidget", glyph: "hourglass_bottom", tint: "#5e5ce6", category: "system", defaultOn: false, lock: true, palette: false, sizes: [],
            keywords: "usage apps time tracker" },
        { key: "palette", name: "Palette", group: "Palette", component: "PaletteWidget", glyph: "palette", tint: "#ff375f", category: "decor", defaultOn: false, lock: true, palette: false, sizes: [],
            keywords: "colours colors swatches hex wallpaper cover accent theme" },
        { key: "lyrics", name: "Lyrics", group: "Lyrics", component: "LyricsWidget", glyph: "lyrics", tint: "#ff375f", category: "media", defaultOn: false, lock: true, palette: false, sizes: [],
            keywords: "lyrics words song sing karaoke music lines" }
    ]

    readonly property var keys: root.entries.map(entry => entry.key)
    readonly property var byKey: root.entries.reduce((all, entry) => { all[entry.key] = entry; return all }, ({}))
    readonly property var groups: root.entries.reduce((all, entry) => { all[entry.key] = entry.group; return all }, ({}))
    readonly property var lockKeys: root.entries.filter(entry => entry.lock).map(entry => entry.key)
    readonly property var paletteKeys: root.entries.filter(entry => entry.palette).map(entry => entry.key)
    // The shelf's aisles: what a widget is for, in the order people reach for them.
    readonly property var categoryOrder: ["today", "media", "system", "notes", "decor"]
    readonly property string customTint: "#5e5ce6"
    readonly property string fallbackTint: "#8e8e93"

    function has(key: string): bool { return root.byKey[key] !== undefined }
    function entry(key: string): var { return root.byKey[key] ?? null }
    function nameOf(key: string): string { return root.byKey[key]?.name ?? key }
    function groupOf(key: string): string { return root.byKey[key]?.group ?? key }
    function defaultOn(key: string): bool { return root.byKey[key]?.defaultOn ?? false }
    function glyph(key: string): string { return root.byKey[key]?.glyph ?? "widgets" }
    function keywordsOf(key: string): string { return root.byKey[key]?.keywords ?? "" }
    function categoryOf(key: string): string { return root.byKey[key]?.category ?? "decor" }
    function tint(key: string): string { return root.byKey[key]?.tint ?? (key.startsWith("custom.") ? root.customTint : root.fallbackTint) }
}
