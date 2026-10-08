pragma Singleton
pragma ComponentBehavior: Bound
import QtQml

// What each desktop widget is called by glyph and category tint, wherever it is shown as itself:
// the edit toolbar's rail and the head of its quick controls.
QtObject {
    id: root
    readonly property var glyphs: ({
        weather: "cloud", clock: "schedule", worldClock: "public", dayProgress: "timelapse", uptime: "avg_pace",
        mediaControls: "album", visualizer: "graphic_eq", systemMonitor: "monitor_heart", battery: "battery_full",
        notes: "sticky_note_2", calendarUpcoming: "event", monthCalendar: "calendar_month", dateBadge: "today",
        todo: "checklist", timers: "timer", newsTicker: "newspaper", userCard: "account_circle",
        customImage: "add_photo_alternate", imageConverter: "transform", japaneseTypography: "translate",
        editorial: "text_fields", shape: "category", mascot: "pets", controls: "toggle_on", screenTime: "hourglass_bottom"
    })
    // The fixed category palette notification tiles use.
    readonly property var tints: ({
        weather: "#0a84ff", clock: "#ff9f0a", worldClock: "#ff9f0a", dayProgress: "#ff9f0a", uptime: "#5e5ce6",
        mediaControls: "#ff375f", visualizer: "#bf5af2", systemMonitor: "#34c759", battery: "#34c759",
        notes: "#ffcc00", calendarUpcoming: "#ff3b30", monthCalendar: "#ff3b30", dateBadge: "#ff3b30",
        todo: "#ff9f0a", timers: "#ff9f0a", newsTicker: "#30b0c7", userCard: "#0a84ff",
        customImage: "#30b0c7", imageConverter: "#30b0c7", japaneseTypography: "#bf5af2",
        editorial: "#5e5ce6", shape: "#bf5af2", mascot: "#ff375f", controls: "#0a84ff", screenTime: "#5e5ce6"
    })
    // What people call them besides their name, for searching while arranging.
    readonly property var keywords: ({
        weather: "forecast temperature rain sun wind climate", clock: "time hour watch", worldClock: "time zones cities timezone",
        dayProgress: "day sun hours", uptime: "boot session running", mediaControls: "music player now playing song spotify cover",
        visualizer: "audio cava spectrum equalizer sound", systemMonitor: "vitals cpu gpu ram memory temperature performance",
        battery: "power charge", notes: "sticky memo text write", calendarUpcoming: "agenda events next up",
        monthCalendar: "calendar month date days", dateBadge: "date day today", todo: "tasks checklist list",
        timers: "timer stopwatch countdown alarm pomodoro", newsTicker: "news feed rss headlines", userCard: "profile avatar account you",
        customImage: "picture photo image", imageConverter: "picture convert image", japaneseTypography: "japanese kanji text",
        editorial: "text typography quote", shape: "decoration decorative", mascot: "pet character companion",
        controls: "toggles wifi bluetooth volume brightness quick settings", screenTime: "usage apps time tracker"
    })
    readonly property string customTint: "#5e5ce6"
    readonly property string fallbackTint: "#8e8e93"

    function glyph(key: string): string { return root.glyphs[key] ?? "widgets" }
    function keywordsOf(key: string): string { return root.keywords[key] ?? "" }
    function tint(key: string): string { return root.tints[key] ?? (key.startsWith("custom.") ? root.customTint : root.fallbackTint) }
}
