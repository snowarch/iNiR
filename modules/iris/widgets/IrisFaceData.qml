pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.iris.style
import qs.modules.shared.background.widgets

Singleton {
    id: root

    // The gallery's order (DesktopWidgetRegistry holds the widgets; one missing here goes last) and the glyphs iRiS
    // draws its own way.
    readonly property var order: ["clock", "weather", "mediaControls", "controls", "monthCalendar", "calendarUpcoming", "todo",
        "notes", "timers", "screenTime", "systemMonitor", "battery", "worldClock", "dayProgress", "dateBadge", "userCard",
        "uptime", "newsTicker", "palette", "lyrics", "visualizer", "editorial", "mascot", "japaneseTypography", "customImage",
        "imageConverter", "shape"]
    readonly property var ordered: root.order.filter(key => DesktopWidgetRegistry.has(key))
        .concat(DesktopWidgetRegistry.keys.filter(key => !root.order.includes(key)))
    readonly property var glyphs: ({ weather: "partly_cloudy_day", mediaControls: "music_note", calendarUpcoming: "event_upcoming",
        dayProgress: "wb_twilight", uptime: "timelapse" })
    function entryOf(key: string, ownTint: bool): var {
        const name = DesktopWidgetRegistry.nameOf(key)
        const tint = DesktopWidgetRegistry.tint(key)
        return { key: key, glyph: root.glyphs[key] ?? DesktopWidgetRegistry.glyph(key), english: name, label: Translation.tr(name),
            tint: ownTint ? IrisStyle.identityOf(tint) : tint }
    }

    // What the lock and the gallery offer, in identity colours.
    readonly property var galleryEntries: root.ordered.filter(key => DesktopWidgetRegistry.entry(key).lock).map(key => root.entryOf(key, true))

    // Widgets without an iRiS face that the active Design prints all the same (IrisDesignFace): they take that print as
    // their face under iRiS and keep drawing themselves everywhere else.
    readonly property var prints: ({ visualizer: IrisDesign.has("widgetVisualizer"), editorial: IrisDesign.has("widgetEditorial"),
        japaneseTypography: IrisDesign.has("widgetJapanese") })

    // The rest, listed wherever the set is: they count on the desktop and can be taken away.
    readonly property var otherEntries: root.ordered.filter(key => !DesktopWidgetRegistry.entry(key).lock)
        .map(key => root.entryOf(key, false))

    // The last two words travel together, so a wrapped line never ends on a lone word ("...shows / here").
    function unwidowed(text: string): string {
        const value = String(text ?? "")
        return value.replace(/ (\S{1,12})$/, "\u00a0$1")
    }

    function capitalized(text: string): string {
        const value = String(text ?? "")
        return value.length > 0 ? value.charAt(0).toUpperCase() + value.slice(1) : value
    }

    function eventDate(event: var): var {
        return new Date(event?.dateTime ?? event?.startDate ?? 0)
    }

    function upcomingEvents(from: var, days: int): var {
        const now = new Date(from)
        const local = Array.from(Events.getUpcomingEvents(days) ?? [])
        const external = Array.from(CalendarSync.getUpcomingEvents(days) ?? [])
        const today = new Date(now)
        today.setHours(0, 0, 0, 0)
        const allDay = Array.from(CalendarSync.getEventsForDate(today) ?? []).filter(event => event.allDay)
        return local.concat(external, allDay.filter(event => !external.includes(event)))
            .sort((a, b) => root.eventDate(a) - root.eventDate(b))
    }

    function hasEvents(date: var): bool {
        return (Events.getEventsForDate(date) ?? []).length > 0
            || (CalendarSync.getEventsForDate(date) ?? []).length > 0
    }

    function eventTitle(event: var): string {
        return String(event?.title || event?.summary || Translation.tr("Event"))
    }

    function eventTint(event: var, fallback: color): color {
        const tint = String(event?.sourceColor ?? "")
        return tint.length > 0 ? tint : fallback
    }

    function eventWhen(event: var, now: var): string {
        if (!event)
            return ""
        const when = root.eventDate(event)
        const today = new Date(now)
        today.setHours(0, 0, 0, 0)
        const day = new Date(when)
        day.setHours(0, 0, 0, 0)
        const days = Math.round((day.getTime() - today.getTime()) / 86400000)
        const time = event.allDay ? Translation.tr("All day")
            : Qt.locale().toString(when, Qt.locale().timeFormat(Locale.ShortFormat))
        const minutes = Math.round((when.getTime() - new Date(now).getTime()) / 60000)
        if (!event.allDay && minutes >= 0 && minutes < 60)
            return minutes < 1 ? Translation.tr("Now") : Translation.tr("In %1 min").arg(minutes)
        if (days === 0)
            return time
        if (days === 1)
            return Translation.tr("Tomorrow · %1").arg(time)
        return root.capitalized(Translation.locale.toString(when, "dddd")) + " · " + time
    }
}
