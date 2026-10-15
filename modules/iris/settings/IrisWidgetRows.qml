pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.services
import qs.modules.shared.background.widgets
import "../../shared/background/widgets/OrganicEdgeConfig.js" as EdgeConfig
import "../../shared/background/widgets/japaneseTypography/JapaneseTypographyPresets.js" as JapanesePresets

// Settings › Widgets: every desktop widget's own options as iRiS rows, one group per widget. A row names its widget and
// key (`widget`, `key`) instead of a path: it reads what the screen in front shows and writes the base value with every
// screen's own copy cleared (`DesktopWidgetLayout.setEverywhere`), so a value once set from the quick controls never
// silently beats the row. Rows for what only the Material drawing reads show only while that widget draws Material;
// the face's own choices only while it draws its iRiS face. Every group opens on "On the desktop"; the rest shows
// while the widget is there.
QtObject {
    id: root

    readonly property string output: String((GlobalStates.focusedScreen ?? Quickshell.screens[0])?.name ?? "")
    // Widgets that have an iRiS face (`irisFace`), and the ones on by default.
    readonly property var faced: ["clock", "weather", "battery", "monthCalendar", "calendarUpcoming", "controls", "dateBadge",
        "dayProgress", "newsTicker", "notes", "mediaControls", "userCard", "screenTime", "timers", "todo", "uptime",
        "systemMonitor", "worldClock"]
    readonly property var onByDefault: ["clock"]

    function value(widget: string, key: string, fallback: var): var {
        Config.revision
        return DesktopWidgetLayout.value(root.output, widget, key, fallback)
    }
    function on(widget: string): bool {
        Config.revision
        return DesktopWidgetLayout.effectiveEnabled(widget, root.onByDefault.includes(widget))
    }
    function resolved(widget: string): var {
        Config.revision
        return DesktopWidgetDesign.resolve(widget, String(root.value(widget, "iris.design", "auto")), "", root.faced.includes(widget))
    }
    // The iRiS face draws it.
    function face(widget: string): bool { return root.on(widget) && root.resolved(widget).face }
    // The widget's own Material drawing, with no design laid over it: its style rows mean something.
    function material(widget: string): bool {
        const design = root.resolved(widget)
        return root.on(widget) && !design.face && design.design === "individual"
    }
    // Not the face (Material, iNstrument or Readout): the shared card and its plate.
    function plain(widget: string): bool { return root.on(widget) && !root.resolved(widget).face }
    // What iNstrument or Readout lays over the widget's own keys: those rows have nothing to change while it does.
    function overlay(widget: string): var {
        const design = root.resolved(widget)
        return design.face ? ({}) : DesktopWidgetDesign.values(widget, design.design)
    }
    function effective(widget: string, key: string, fallback: var): var {
        const over = root.overlay(widget)
        return over[key] !== undefined ? over[key] : root.value(widget, key, fallback)
    }
    function is(widget: string, key: string, fallback: var, wanted: var): bool {
        return String(root.effective(widget, key, fallback)) === String(wanted)
    }

    readonly property var groups: ({
        clock: "Clock", weather: "Weather", monthCalendar: "Month Calendar", calendarUpcoming: "Upcoming Events",
        worldClock: "World clock", dateBadge: "Date badge", dayProgress: "Day progress", timers: "Timers",
        uptime: "System uptime", mediaControls: "Media Controls", visualizer: "Visualizer", systemMonitor: "System Monitor",
        battery: "Battery", notes: "Notes", todo: "Todo", userCard: "User card", newsTicker: "News",
        customImage: "Custom image", imageConverter: "Image converter", shape: "Decorative shape",
        japaneseTypography: "Japanese Typography", editorial: "Editorial", mascot: "Mascot", controls: "Controls",
        screenTime: "Screen time"
    })
    // Clusters of the section's column, in the order people look for them.
    readonly property var clusters: [
        { caption: "Every widget", groups: ["Arranging", "Power saving"] },
        { caption: "Time", groups: ["Clock", "World clock", "Month Calendar", "Upcoming Events", "Date badge", "Day progress", "Timers", "System uptime"] },
        { caption: "Music", groups: ["Media Controls", "Visualizer"] },
        { caption: "System", groups: ["System Monitor", "Battery", "Controls", "Screen time", "Weather", "News"] },
        { caption: "Yours", groups: ["Notes", "Todo", "User card", "Custom image", "Image converter"] },
        { caption: "Art", groups: ["Decorative shape", "Japanese Typography", "Editorial", "Mascot"] }
    ]
    readonly property var order: root.clusters.reduce((all, cluster) => all.concat(cluster.groups), [])

    function row(widget: string, key: string, label: string, kind: string, fallback: var, extra: var): var {
        const spec = Object.assign({ section: "widgets", group: root.groups[widget], widget: widget, key: key,
            path: "background.widgets." + widget + "." + key, label: label, kind: kind, fallback: fallback }, extra ?? {})
        // A run of switches is the wall the page must not be: a widget's switches refine it, so they wait behind its
        // Fine-tune unless a row says `tune: false` (the plate, which people come to turn off).
        if (spec.tune === undefined && kind === "switch") spec.tune = true
        const when = spec.when
        spec.showIf = () => root.on(widget) && root.overlay(widget)[key] === undefined && (when === undefined || when())
        delete spec.when
        return spec
    }
    function choices(list: var): var {
        return list.map(entry => ({ label: entry[1], value: entry[0], glyph: entry[2] }))
    }

    // What every widget carries: being on the desktop, its design, its plate and where it sits.
    function opening(widget: string): var {
        return [{ section: "widgets", group: root.groups[widget], widget: widget, widgetEnable: true, path: "background.widgets." + widget + ".enable",
            label: "On the desktop", kind: "switch", fallback: root.onByDefault.includes(widget),
            keywords: ["show", "add", "remove", "enable", "widget", "desktop", "mostrar"] }]
    }
    function closing(widget: string, plate: bool): var {
        const designs = [["auto", "Same as every widget"]]
        if (root.faced.includes(widget)) designs.push(["iris", "iRiS"])
        designs.push(["material", "Material"])
        if (DesktopWidgetDesign.supports(widget)) designs.push(["instrument", "iNstrument"], ["readout", "Readout"])
        const out = [
            root.row(widget, "iris.design", "Design", "choice", "auto", { tune: true, choices: root.choices(designs),
                when: () => designs.length > 2, keywords: ["design", "look", "style", "material", "instrument", "readout"] }),
            root.row(widget, "iris.material", "Material", "choice", "auto", { tune: true, when: () => root.face(widget),
                choices: root.choices([["auto", "Same as every widget"], ["glass", "Glass"], ["clear", "Transparent"], ["solid", "Solid"], ["tinted", "Tinted"]]),
                keywords: ["glass", "transparent", "background", "plate", "fondo", "vidrio"] })
        ]
        if (plate) out.push(
            root.row(widget, "showBackground", "Background", "switch", root.plateDefault(widget), { tune: false, when: () => root.plain(widget),
                description: "The plate behind the widget.", keywords: ["background", "plate", "card", "surface", "fondo", "superficie"] }),
            root.row(widget, "showBorder", "Outline", "switch", root.plateDefault(widget), { when: () => root.plain(widget),
                keywords: ["outline", "border", "line", "borde"] }),
            root.row(widget, "backgroundOpacity", "Background strength", "range", root.plateDefault(widget) ? 0.16 : 0, { min: 0, max: 1, step: 0.02, scale: 100, unit: " %",
                when: () => root.plain(widget) && Boolean(root.value(widget, "showBackground", root.plateDefault(widget))) }))
        out.push(
            root.row(widget, "colorMode", "Ink", "choice", "auto", { tune: true, when: () => root.plain(widget),
                choices: root.choices([["auto", "Auto"], ["light", "Light ink"], ["dark", "Dark ink"]]), keywords: ["ink", "text", "colour", "color", "contrast"] }),
            root.row(widget, "widgetScale", "Scale", "range", 100, { min: 50, max: 200, step: 10, unit: " %", keywords: ["size", "scale", "zoom", "tamaño"] }),
            root.row(widget, "widgetOpacity", "Opacity", "range", 100, { min: 10, max: 100, step: 5, unit: " %", when: () => root.plain(widget) }),
            root.row(widget, "dim", "Dimming", "range", 0, { min: 0, max: 100, step: 5, unit: " %", zeroLabel: "Off", when: () => root.plain(widget) }),
            root.row(widget, "placementStrategy", "Position", "choice", "free", { tune: true,
                choices: root.choices([["free", "Free position"], ["leastBusy", "Quietest spot"], ["mostBusy", "Busiest spot"]]),
                keywords: ["position", "place", "auto", "quiet", "busy", "posición"] }),
            root.row(widget, "locked", "Lock position", "switch", false, { tune: true, keywords: ["lock", "pin", "fixed", "bloquear"] }))
        return out
    }
    function plateDefault(widget: string): bool {
        return !["clock", "visualizer", "japaneseTypography", "shape", "editorial", "dayProgress", "mascot"].includes(widget)
    }
    function size(widget: string, sizes: var): var {
        const labels = { small: "Small", medium: "Medium", large: "Large" }
        return root.row(widget, "iris.size", "Size", "choice", sizes.includes("medium") && sizes.length === 3 || widget === "userCard" || widget === "timers" ? "medium" : sizes[0], {
            when: () => root.face(widget), choices: sizes.map(size => ({ label: labels[size], value: size })), keywords: ["size", "small", "medium", "large", "tamaño"] })
    }
    // A preset that writes several keys at once reads as its name until one of them is changed by hand.
    function preset(widget: string, label: string, fallback: string, list: var, when: var): var {
        return root.row(widget, "preset", label, "choice", fallback, { when: when,
            choices: list.map(entry => ({ label: entry[1], value: entry[0] })),
            apply: next => Object.assign({ preset: next }, (list.find(entry => entry[0] === next) ?? [])[2] ?? {}) })
    }

    readonly property var widgetRows: [
        // ── Clock ──
        ...root.opening("clock"),
        root.size("clock", ["small", "medium"]),
        root.row("clock", "iris.face", "Face", "choice", "analog", { when: () => root.face("clock"), choices: root.choices([["analog", "Analog", "schedule"], ["digital", "Digital", "timer_10"]]) }),
        root.row("clock", "iris.seconds", "Second hand", "switch", true, { when: () => root.face("clock") && root.is("clock", "iris.face", "analog", "analog") }),
        root.row("clock", "style", "Clock style", "choice", "digital", { when: () => root.material("clock"),
            choices: root.choices([["digital", "Digital"], ["androidStacked", "Android stacked"], ["cookie", "Cookie"], ["pixel", "Pixel"], ["instrument", "Instrument"]]) }),
        root.row("clock", "pixel.orientation", "Orientation", "choice", "horizontal", { when: () => root.material("clock") && root.is("clock", "style", "digital", "pixel"),
            choices: root.choices([["horizontal", "Horizontal"], ["vertical", "Vertical"]]) }),
        root.row("clock", "timeFormat", "Time format", "choice", "system", { when: () => root.material("clock") && ["digital", "androidStacked"].includes(String(root.effective("clock", "style", "digital"))),
            choices: root.choices([["system", "System"], ["24h", "24h"], ["12h", "12h"]]) }),
        root.row("clock", "dateStyle", "Date style", "choice", "long", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "digital"),
            choices: root.choices([["long", "Long"], ["minimal", "Minimal"], ["weekday", "Weekday"], ["numeric", "Numeric"]]) }),
        root.row("clock", "digital.preset", "Digital preset", "choice", "default", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "digital"),
            choices: root.choices([["default", "Default"], ["light", "Light"], ["bold", "Bold"], ["mono", "Mono"]]),
            apply: next => ({ "digital.preset": next, "digital.fontWeight": { default: 600, light: 300, bold: 800, mono: 500 }[next], "digital.spacing": { default: 6, light: 8, bold: 4, mono: 2 }[next] }) }),
        root.row("clock", "showSeconds", "Seconds", "switch", false, { when: () => root.plain("clock") && ["digital", "androidStacked", "instrument"].includes(String(root.effective("clock", "style", "digital"))) }),
        root.row("clock", "showDate", "Date", "switch", true, { when: () => root.plain("clock") && ["digital", "androidStacked", "instrument"].includes(String(root.effective("clock", "style", "digital"))) }),
        root.row("clock", "showShadow", "Shadow", "switch", true, { tune: true, when: () => root.material("clock") && ["digital", "androidStacked"].includes(String(root.effective("clock", "style", "digital"))) }),
        root.row("clock", "digital.animateChange", "Animate", "switch", true, { tune: true, when: () => root.material("clock") && ["digital", "androidStacked"].includes(String(root.effective("clock", "style", "digital"))) }),
        root.row("clock", "digital.adaptToWallpaper", "Adapt digital clock locally", "switch", true, { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "digital") }),
        root.row("clock", "digital.fontWeight", "Font weight", "range", 600, { min: 100, max: 900, step: 100, when: () => root.material("clock") && root.is("clock", "style", "digital", "digital") }),
        root.row("clock", "digital.spacing", "Spacing", "range", 6, { min: 0, max: 20, unit: " px", when: () => root.material("clock") && root.is("clock", "style", "digital", "digital") }),
        root.row("clock", "timeScale", "Time scale", "range", 100, { min: 50, max: 200, step: 5, unit: " %", when: () => root.plain("clock") }),
        root.row("clock", "dateScale", "Date scale", "range", 100, { min: 50, max: 200, step: 5, unit: " %", when: () => root.material("clock") }),
        root.row("clock", "fontFamily", "Clock font", "text", "Space Grotesk", { tune: true, placeholder: "Space Grotesk", when: () => root.material("clock") && ["digital", "androidStacked"].includes(String(root.effective("clock", "style", "digital"))) }),
        root.row("clock", "cookie.preset", "Preset", "choice", "default", { when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie"),
            choices: root.choices([["default", "Default"], ["compact", "Compact"], ["large", "Large"], ["minimal", "Minimal"]]),
            apply: next => ({ "cookie.preset": next,
                "cookie.size": { default: 230, compact: 160, large: 300, minimal: 200 }[next], "cookie.sides": { default: 15, compact: 12, large: 18, minimal: 6 }[next],
                "cookie.dialNumberStyle": { default: "full", compact: "dots", large: "numbers", minimal: "none" }[next],
                "cookie.hourHandStyle": { default: "hollow", compact: "fill", large: "classic", minimal: "fill" }[next] }) }),
        root.row("clock", "cookie.size", "Size", "range", 230, { min: 100, max: 400, step: 10, unit: " px", when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "cookie.sides", "Sides", "range", 15, { min: 3, max: 30, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "cookie.useSineCookie", "Sine wave shape", "switch", false, { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "cookie.constantlyRotate", "Constant rotation", "switch", false, { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "cookie.dialNumberStyle", "Dial style", "choice", "full", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie"),
            choices: root.choices([["full", "Lines"], ["dots", "Dots"], ["numbers", "Numbers"], ["none", "None"]]) }),
        root.row("clock", "cookie.hourMarks", "Hour marks", "switch", false, { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "cookie.timeIndicators", "Time column", "switch", false, { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "cookie.hourHandStyle", "Hour hand", "choice", "hollow", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie"),
            choices: root.choices([["fill", "Fill"], ["hollow", "Hollow"], ["classic", "Classic"], ["hide", "Hide"]]) }),
        root.row("clock", "cookie.minuteHandStyle", "Minute hand", "choice", "hide", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie"),
            choices: root.choices([["bold", "Bold"], ["medium", "Medium"], ["thin", "Thin"], ["hide", "Hide"]]) }),
        root.row("clock", "cookie.secondHandStyle", "Second hand", "choice", "hide", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie"),
            choices: root.choices([["classic", "Classic"], ["dot", "Dot"], ["line", "Line"], ["hide", "Hide"]]) }),
        root.row("clock", "cookie.dateStyle", "Date indicator", "choice", "bubble", { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie"),
            choices: root.choices([["bubble", "Bubble"], ["rect", "Rectangle"], ["border", "Border"], ["hide", "Hide"]]) }),
        root.row("clock", "cookie.aiStyling", "Auto-style from wallpaper", "switch", false, { tune: true, when: () => root.material("clock") && root.is("clock", "style", "digital", "cookie") }),
        root.row("clock", "instrumentTrail", "Minute trail", "switch", true, { when: () => root.plain("clock") && root.is("clock", "style", "digital", "instrument") }),
        root.row("clock", "instrumentNumerals", "Numerals", "switch", true, { when: () => root.plain("clock") && root.is("clock", "style", "digital", "instrument") }),
        root.row("clock", "instrumentTrailLength", "Trail length", "range", 6, { min: 2, max: 15, when: () => root.plain("clock") && root.is("clock", "style", "digital", "instrument") && Boolean(root.value("clock", "instrumentTrail", true)) }),
        root.row("clock", "quote.enable", "Show quote", "switch", false, { tune: true, when: () => root.material("clock") && ["digital", "cookie"].includes(String(root.effective("clock", "style", "digital"))) }),
        root.row("clock", "quote.text", "Quote", "text", "", { placeholder: "Enter a quote or message...", when: () => root.material("clock") && Boolean(root.value("clock", "quote.enable", false)) }),
        ...root.closing("clock", true),

        // ── World clock ──
        ...root.opening("worldClock"),
        root.size("worldClock", ["small", "medium", "large"]),
        root.row("worldClock", "timezones", "Cities", "pieces", ["Asia/Tokyo", "Europe/London", "America/New_York"], { choicesFrom: "timezones",
            description: "Up to four, in the order you switch them on.", keywords: ["city", "cities", "timezone", "time zone", "zona horaria", "ciudad"] }),
        root.row("worldClock", "showNames", "City names", "switch", true, { when: () => root.face("worldClock") }),
        root.row("worldClock", "showOffsets", "Time difference", "switch", true, {}),
        root.row("worldClock", "style", "Style", "choice", "cards", { when: () => root.material("worldClock"), choices: root.choices([["cards", "List"], ["instrument", "Instrument"]]) }),
        root.row("worldClock", "instrumentLayout", "Instrument layout", "choice", "grid", { when: () => root.plain("worldClock") && root.is("worldClock", "style", "cards", "instrument"), choices: root.choices([["grid", "Atlas"], ["rows", "Strip"]]) }),
        root.row("worldClock", "showDate", "Date", "switch", true, { tune: true, when: () => root.plain("worldClock") && root.is("worldClock", "style", "cards", "instrument") }),
        root.row("worldClock", "showDayState", "Day/Night", "switch", true, { tune: true, when: () => root.plain("worldClock") && root.is("worldClock", "style", "cards", "instrument") }),
        root.row("worldClock", "contentWidth", "Width", "range", 300, { min: 240, max: 700, step: 10, unit: " px", when: () => root.plain("worldClock") }),
        root.row("worldClock", "contentHeight", "Height", "range", 210, { min: 190, max: 480, step: 4, unit: " px", when: () => root.plain("worldClock") }),
        ...root.closing("worldClock", true),

        // ── Month calendar ──
        ...root.opening("monthCalendar"),
        root.size("monthCalendar", ["small", "medium", "large"]),
        root.row("monthCalendar", "weekStart", "Week starts on", "choice", 1, { choices: root.choices([[1, "Monday"], [0, "Sunday"]]) }),
        root.row("monthCalendar", "showAdjacentDays", "Show adjacent month days", "switch", true, { when: () => root.plain("monthCalendar") }),
        root.row("monthCalendar", "style", "Style", "choice", "card", { when: () => root.material("monthCalendar"), choices: root.choices([["card", "Card"], ["instrument", "Instrument"]]) }),
        root.row("monthCalendar", "instrumentRule", "Header rule", "switch", true, { tune: true, when: () => root.plain("monthCalendar") && root.is("monthCalendar", "style", "card", "instrument") }),
        root.row("monthCalendar", "contentWidth", "Width", "range", 300, { min: 252, max: 520, step: 4, unit: " px", when: () => root.plain("monthCalendar") }),
        root.row("monthCalendar", "contentHeight", "Height", "range", 340, { min: 290, max: 620, step: 4, unit: " px", when: () => root.plain("monthCalendar") }),
        ...root.closing("monthCalendar", true),

        // ── Upcoming events ──
        ...root.opening("calendarUpcoming"),
        root.size("calendarUpcoming", ["small", "medium", "large"]),
        root.row("calendarUpcoming", "groupByDay", "Group by day", "switch", true, {}),
        root.row("calendarUpcoming", "showLocation", "Location", "switch", false, {}),
        root.row("calendarUpcoming", "showDate", "Show date", "switch", true, { when: () => root.plain("calendarUpcoming") }),
        root.row("calendarUpcoming", "showTime", "Show time", "switch", true, { when: () => root.plain("calendarUpcoming") }),
        root.row("calendarUpcoming", "maxEvents", "Maximum events", "range", 5, { min: 1, max: 12, when: () => root.plain("calendarUpcoming") }),
        root.row("calendarUpcoming", "style", "Presentation", "choice", "card", { when: () => root.material("calendarUpcoming"), choices: root.choices([["card", "Card"], ["instrument", "Instrument"]]) }),
        root.row("calendarUpcoming", "contentWidth", "Width", "range", 280, { min: 200, max: 720, step: 10, unit: " px", when: () => root.plain("calendarUpcoming") }),
        root.row("calendarUpcoming", "contentHeight", "Height", "range", 220, { min: 140, max: 720, step: 10, unit: " px", when: () => root.plain("calendarUpcoming") }),
        ...root.closing("calendarUpcoming", true),

        // ── Date badge ──
        ...root.opening("dateBadge"),
        root.row("dateBadge", "showWeekday", "Weekday", "switch", true, {}),
        root.row("dateBadge", "showYear", "Year", "switch", true, {}),
        root.row("dateBadge", "showOrdinal", "Day of the year", "switch", true, {}),
        root.row("dateBadge", "style", "Style", "choice", "ticket", { when: () => root.material("dateBadge"),
            choices: root.choices([["ticket", "Ticket"], ["stacked", "Stacked"], ["seal", "Seal"], ["instrument", "Instrument"]]) }),
        root.row("dateBadge", "instrumentMarks", "Marks", "switch", true, { tune: true, when: () => root.plain("dateBadge") && root.is("dateBadge", "style", "ticket", "instrument") }),
        root.row("dateBadge", "contentWidth", "Width", "range", 220, { min: 140, max: 600, step: 10, unit: " px", when: () => root.plain("dateBadge") }),
        root.row("dateBadge", "contentHeight", "Height", "range", 140, { min: 120, max: 240, step: 4, unit: " px", when: () => root.plain("dateBadge") }),
        ...root.closing("dateBadge", true),

        // ── Day progress ──
        ...root.opening("dayProgress"),
        root.size("dayProgress", ["small", "medium"]),
        root.row("dayProgress", "style", "Style", "choice", "ring", { when: () => root.material("dayProgress"), choices: root.choices([["ring", "Ring"], ["arc", "Arc"], ["ticks", "Ticks"]]) }),
        root.row("dayProgress", "comet", "Comet tail", "switch", true, { when: () => root.plain("dayProgress") }),
        root.row("dayProgress", "showIcon", "Sun icon", "switch", true, { when: () => root.plain("dayProgress") }),
        root.row("dayProgress", "showDate", "Show date", "switch", true, { when: () => root.plain("dayProgress") }),
        root.row("dayProgress", "hourLabels", "Hour labels", "switch", true, { tune: true, when: () => root.plain("dayProgress") }),
        root.row("dayProgress", "fontScale", "Text size", "range", 100, { min: 60, max: 180, step: 10, unit: " %", when: () => root.plain("dayProgress") }),
        root.row("dayProgress", "contentWidth", "Width", "range", 240, { min: 190, max: 500, step: 10, unit: " px", when: () => root.plain("dayProgress") }),
        root.row("dayProgress", "contentHeight", "Height", "range", 240, { min: 190, max: 500, step: 10, unit: " px", when: () => root.plain("dayProgress") }),
        ...root.closing("dayProgress", true),

        // ── Timers ──
        ...root.opening("timers"),
        root.size("timers", ["small", "medium"]),
        root.row("timers", "style", "Style", "choice", "cards", { when: () => root.material("timers"), choices: root.choices([["cards", "Cards"], ["instrument", "Instrument"]]) }),
        root.row("timers", "vertical", "Orientation", "choice", false, { when: () => root.plain("timers"), choices: root.choices([[false, "Horizontal"], [true, "Vertical"]]) }),
        root.row("timers", "glow", "Active pulse", "switch", true, { tune: true, when: () => root.plain("timers") && root.is("timers", "style", "cards", "instrument") }),
        root.row("timers", "showProgress", "Progress", "switch", true, { tune: true, when: () => root.plain("timers") && root.is("timers", "style", "cards", "instrument") }),
        root.row("timers", "showState", "Details", "switch", true, { tune: true, when: () => root.plain("timers") && root.is("timers", "style", "cards", "instrument") }),
        root.row("timers", "showHundredths", "Hundredths", "switch", true, { tune: true, when: () => root.plain("timers") && root.is("timers", "style", "cards", "instrument") }),
        ...root.closing("timers", true),

        // ── Uptime ──
        ...root.opening("uptime"),
        root.row("uptime", "showSince", "Start time", "switch", true, {}),
        root.row("uptime", "style", "Style", "choice", "row", { when: () => root.material("uptime"), choices: root.choices([["row", "Row"], ["instrument", "Instrument"]]) }),
        root.row("uptime", "showBreakdown", "Breakdown", "switch", true, { tune: true, when: () => root.plain("uptime") && root.is("uptime", "style", "row", "instrument") }),
        root.row("uptime", "contentWidth", "Width", "range", 250, { min: 180, max: 600, step: 10, unit: " px", when: () => root.plain("uptime") }),
        root.row("uptime", "contentHeight", "Height", "range", 96, { min: 72, max: 240, step: 4, unit: " px", when: () => root.plain("uptime") }),
        ...root.closing("uptime", true),

        // ── Media controls ──
        ...root.opening("mediaControls"),
        root.size("mediaControls", ["small", "medium", "large"]),
        root.row("mediaControls", "iris.lyrics", "Synced lyrics", "switch", true, { when: () => root.face("mediaControls") }),
        root.row("mediaControls", "iris.rest", "Rest when paused", "switch", true, { when: () => root.face("mediaControls") }),
        root.row("mediaControls", "playerPreset", "Player style", "choice", "full", { when: () => root.material("mediaControls"),
            choices: root.choices([["full", "Full"], ["compact", "Compact"], ["minimal", "Minimal"], ["albumart", "Album Art"], ["visualizer", "Visualizer"], ["classic", "Classic"], ["lyrics", "Lyrics"], ["lyricsSplit", "Lyrics wide"], ["expandingLyrics", "Cover"]]) }),
        root.row("mediaControls", "visualizerType", "Visualizer", "choice", "wave", { when: () => root.material("mediaControls"),
            choices: root.choices([["wave", "Wave"], ["bars", "Bars"], ["organic", "Organic"]]),
            apply: next => next === "organic" && String(root.value("mediaControls", "visualizerPosition", "bottom")) === "none" ? { visualizerType: next, visualizerPosition: "fill" } : { visualizerType: next } }),
        root.row("mediaControls", "visualizerPosition", "Placement", "choice", "bottom", { when: () => root.material("mediaControls"),
            choices: root.choices([["bottom", "Bottom"], ["top", "Top"], ["fill", "Fill"], ["none", "Off"]]) }),
        root.row("mediaControls", "visualizerPaletteMode", "Colors", "choice", "cava", { tune: true, when: () => root.material("mediaControls"),
            choices: root.choices([["cava", "Cava palette"], ["accent", "Accent"], ["player", "Album"]]) }),
        root.row("mediaControls", "visualizerFrequencyProfile", "Response", "choice", "flat", { tune: true, when: () => root.material("mediaControls"),
            choices: root.choices([["flat", "Flat"], ["bass", "Bass"], ["warm", "Warm"], ["vocal", "Vocal"], ["treble", "Treble"], ["smile", "Smile"]]) }),
        root.row("mediaControls", "visualizerAccentStrength", "Accent strength", "range", 70, { min: 0, max: 100, step: 5, unit: " %", when: () => root.material("mediaControls") && !root.is("mediaControls", "visualizerFrequencyProfile", "flat", "flat") }),
        root.row("mediaControls", "visualizerSmoothing", "Smoothing", "range", 2, { min: 0, max: 8, when: () => root.material("mediaControls") }),
        root.row("mediaControls", "visualizerOpacity", "Visualizer opacity", "range", 55, { min: 5, max: 100, step: 5, unit: " %", when: () => root.material("mediaControls") && !root.is("mediaControls", "visualizerType", "wave", "organic") }),
        root.row("mediaControls", "visualizerRange", "Motion range", "range", 88, { min: 10, max: 100, step: 5, unit: " %", when: () => root.material("mediaControls") && !root.is("mediaControls", "visualizerType", "wave", "organic") }),
        root.row("mediaControls", "visualizerBarCount", "Bar count", "range", 32, { min: 8, max: 128, step: 4, when: () => root.material("mediaControls") && root.is("mediaControls", "visualizerType", "wave", "bars") }),
        ...[["organicSensitivity", "Sensitivity", 35, 25, 200], ["organicPulse", "Pulse", 150, 0, 150], ["organicCompression", "Compression", 0, 0, 100],
            ["organicMotionSpeed", "Motion speed", 250, 20, 250], ["organicGlow", "Glow", 100, 0, 100], ["organicReach", "Reach", 35, 20, 140],
            ["organicIdleMotion", "Idle motion", 40, 0, 100], ["organicOpacity", "Presence", 100, 10, 100], ["organicRange", "Range", 20, 20, 100]]
            .map(entry => root.row("mediaControls", entry[0], entry[1], "range", entry[2], { min: entry[3], max: entry[4], step: 5, unit: " %",
                when: () => root.material("mediaControls") && root.is("mediaControls", "visualizerType", "wave", "organic") })),
        ...root.closing("mediaControls", true),

        // ── Visualizer ──
        ...root.opening("visualizer"),
        root.preset("visualizer", "Preset", "default", [["default", "Default", { barRadius: 2, barMinHeight: 1, contentWidth: 304, contentHeight: 104, barCount: 48, barSpacing: 2 }],
            ["dense", "Dense", { barRadius: 1, barMinHeight: 2, contentWidth: 304, contentHeight: 80, barCount: 64, barSpacing: 1 }],
            ["minimal", "Minimal", { barRadius: 4, barMinHeight: 1, contentWidth: 200, contentHeight: 80, barCount: 24, barSpacing: 3 }],
            ["wide", "Wide", { barRadius: 2, barMinHeight: 1, contentWidth: 480, contentHeight: 120, barCount: 80, barSpacing: 2 }]], () => !root.is("visualizer", "vizType", "bars", "organic")),
        root.row("visualizer", "vizType", "Type", "choice", "bars", { choices: root.choices([["bars", "Bars", "bar_chart"], ["wave", "Wave", "waves"], ["organic", "Organic", "bubble_chart"]]) }),
        root.row("visualizer", "paletteMode", "Colors", "choice", "cava", { choices: root.choices([["cava", "Cava"], ["accent", "Accent"], ["primary", "Primary"], ["album", "Album"]]) }),
        root.row("visualizer", "barsOrigin", "Bars rise from", "choice", "bottom", { when: () => root.is("visualizer", "vizType", "bars", "bars"),
            choices: root.choices([["bottom", "Bottom"], ["top", "Top"], ["center", "Center rise"], ["mirror", "Mirrored"]]) }),
        root.row("visualizer", "waveMode", "Wave", "choice", "fill", { when: () => root.is("visualizer", "vizType", "bars", "wave"), choices: root.choices([["fill", "Fill"], ["line", "Line"], ["ribbon", "Ribbon"]]) }),
        root.row("visualizer", "barCount", "Bar count", "range", 48, { min: 8, max: 128, step: 4, when: () => root.is("visualizer", "vizType", "bars", "bars") }),
        root.row("visualizer", "barSpacing", "Bar spacing", "range", 2, { min: 0, max: 8, unit: " px", when: () => root.is("visualizer", "vizType", "bars", "bars") }),
        root.row("visualizer", "barRadius", "Bar radius", "range", 2, { min: 0, max: 16, unit: " px", when: () => root.is("visualizer", "vizType", "bars", "bars") }),
        root.row("visualizer", "barMinHeight", "Min height", "range", 1, { min: 0, max: 16, unit: " px", when: () => root.is("visualizer", "vizType", "bars", "bars") }),
        root.row("visualizer", "barOpacity", "Bar opacity", "range", 100, { min: 5, max: 100, step: 5, unit: " %", when: () => root.is("visualizer", "vizType", "bars", "bars") }),
        root.row("visualizer", "waveOpacity", "Wave opacity", "range", 30, { min: 5, max: 100, step: 5, unit: " %", when: () => root.is("visualizer", "vizType", "bars", "wave") }),
        root.row("visualizer", "lineWidth", "Line width", "range", 2, { min: 1, max: 8, unit: " px", when: () => root.is("visualizer", "vizType", "bars", "wave") }),
        root.row("visualizer", "frequencyProfile", "Response", "choice", "flat", { tune: true,
            choices: root.choices([["flat", "Flat"], ["bass", "Bass"], ["warm", "Warm"], ["vocal", "Vocal"], ["treble", "Treble"], ["smile", "Smile"]]) }),
        root.row("visualizer", "accentStrength", "Frequency accent strength", "range", 70, { min: 0, max: 100, step: 5, unit: " %", when: () => !root.is("visualizer", "frequencyProfile", "flat", "flat") }),
        root.row("visualizer", "smoothing", "Smoothing", "range", 2, { min: 0, max: 8 }),
        ...[["organicSensitivity", "Sensitivity", 25, 25, 200, 5], ["organicPulse", "Pulse", 150, 0, 150, 5], ["organicCompression", "Compression", 0, 0, 100, 5],
            ["organicMotionSpeed", "Motion speed", 250, 20, 250, 5], ["organicIdleMotion", "Idle motion", 18, 0, 100, 5], ["organicOpacity", "Halo opacity", 100, 10, 100, 5],
            ["organicGlow", "Glow", 100, 0, 100, 5], ["organicCoverSize", "Cover size", 51, 30, 90, 1], ["organicRange", "Motion range", 20, 20, 100, 5]]
            .map(entry => root.row("visualizer", entry[0], entry[1], "range", entry[2], { min: entry[3], max: entry[4], step: entry[5], unit: " %",
                when: () => root.is("visualizer", "vizType", "bars", "organic") })),
        root.row("visualizer", "fillRatio", "Spectrum height", "range", 90, { min: 10, max: 100, step: 5, unit: " %", when: () => !root.is("visualizer", "vizType", "bars", "organic") }),
        root.row("visualizer", "edgeInset", "Edge inset", "range", 0, { min: 0, max: 32, unit: " px", when: () => !root.is("visualizer", "vizType", "bars", "organic") }),
        root.row("visualizer", "edgeSoftness", "Curve headroom", "range", 28, { min: 0, max: 100, step: 5, unit: " %", when: () => !root.is("visualizer", "vizType", "bars", "organic") }),
        root.row("visualizer", "contentWidth", "Width", "range", 304, { min: 100, max: 800, step: 20, unit: " px" }),
        root.row("visualizer", "contentHeight", "Height", "range", 104, { min: 40, max: 400, step: 10, unit: " px" }),
        ...root.closing("visualizer", true),

        // ── System monitor ──
        ...root.opening("systemMonitor"),
        root.size("systemMonitor", ["small", "medium", "large"]),
        ...[["showCpu", "CPU", true], ["showMemory", "Memory", true], ["showGpu", "GPU", true], ["showTemp", "CPU heat", false], ["showGpuTemp", "GPU heat", false], ["showDisk", "Disk", false]]
            .map(entry => root.row("systemMonitor", entry[0], entry[1], "switch", entry[2], { keywords: ["monitor", "usage", "temperature", "temp"] })),
        root.row("systemMonitor", "showLabels", "Labels and percentages", "switch", true, { when: () => root.plain("systemMonitor") }),
        root.preset("systemMonitor", "Layout", "default", [["default", "Default", { contentWidth: 320, contentHeight: 120 }], ["compact", "Compact", { contentWidth: 240, contentHeight: 80 }],
            ["wide", "Wide", { contentWidth: 480, contentHeight: 120 }], ["tall", "Tall", { contentWidth: 320, contentHeight: 180 }]], () => root.plain("systemMonitor")),
        root.row("systemMonitor", "displayMode", "Display mode", "choice", "bars", { when: () => root.material("systemMonitor"),
            choices: root.choices([["bars", "Bars"], ["graph", "Graph"], ["rings", "Rings"], ["text", "Text"], ["tiles", "Tiles"], ["instrument", "Instrument"]]) }),
        root.row("systemMonitor", "trackAlpha", "Track opacity", "range", 0.08, { min: 0, max: 0.5, step: 0.02, scale: 100, unit: " %", when: () => root.material("systemMonitor") }),
        root.row("systemMonitor", "fillOpacity", "Fill opacity", "range", 0.7, { min: 0.1, max: 1, step: 0.05, scale: 100, unit: " %", when: () => root.material("systemMonitor") }),
        root.row("systemMonitor", "graphFillOpacity", "Graph fill opacity", "range", 0.3, { min: 0, max: 1, step: 0.05, scale: 100, unit: " %", when: () => root.material("systemMonitor") && root.is("systemMonitor", "displayMode", "bars", "graph") }),
        root.row("systemMonitor", "contentWidth", "Width", "range", 320, { min: 120, max: 800, step: 20, unit: " px", when: () => root.plain("systemMonitor") }),
        root.row("systemMonitor", "contentHeight", "Height", "range", 120, { min: 40, max: 400, step: 10, unit: " px", when: () => root.plain("systemMonitor") }),
        ...root.closing("systemMonitor", true),

        // ── Battery ──
        ...root.opening("battery"),
        root.size("battery", ["small", "medium"]),
        root.row("battery", "showTime", "Time remaining", "switch", true, {}),
        root.row("battery", "displayMode", "Display", "choice", "ring", { when: () => root.material("battery"), choices: root.choices([["ring", "Ring"], ["bars", "Bars"], ["pill", "Pill"], ["instrument", "Instrument"]]) }),
        root.preset("battery", "Preset", "default", [["default", "Default", { ringLineWidth: 6, barCount: 20, pillHeight: 12 }], ["thin", "Thin", { ringLineWidth: 3, barCount: 20, pillHeight: 8 }],
            ["thick", "Thick", { ringLineWidth: 10, barCount: 12, pillHeight: 16 }], ["dense", "Dense", { ringLineWidth: 6, barCount: 32, pillHeight: 12 }]], () => root.material("battery")),
        root.row("battery", "showRate", "Show power draw", "switch", true, { when: () => root.plain("battery") && root.is("battery", "displayMode", "ring", "instrument") }),
        root.row("battery", "ringSize", "Ring size", "range", 72, { min: 40, max: 120, step: 4, unit: " px", when: () => root.material("battery") && root.is("battery", "displayMode", "ring", "ring") }),
        root.row("battery", "ringLineWidth", "Line width", "range", 6, { min: 1, max: 16, unit: " px", when: () => root.material("battery") && root.is("battery", "displayMode", "ring", "ring") }),
        root.row("battery", "barCount", "Bar count", "range", 20, { min: 4, max: 48, step: 2, when: () => root.material("battery") && root.is("battery", "displayMode", "ring", "bars") }),
        root.row("battery", "barSpacing", "Bar spacing", "range", 2, { min: 0, max: 8, unit: " px", when: () => root.material("battery") && root.is("battery", "displayMode", "ring", "bars") }),
        root.row("battery", "barRadius", "Bar radius", "range", 2, { min: 0, max: 12, unit: " px", when: () => root.material("battery") && root.is("battery", "displayMode", "ring", "bars") }),
        root.row("battery", "pillHeight", "Pill height", "range", 12, { min: 4, max: 32, step: 2, unit: " px", when: () => root.material("battery") && root.is("battery", "displayMode", "ring", "pill") }),
        ...root.closing("battery", true),

        // ── Controls and Screen time (iRiS widgets) ──
        ...root.opening("controls"),
        root.size("controls", ["small", "medium", "large"]),
        ...root.closing("controls", false),
        ...root.opening("screenTime"),
        root.size("screenTime", ["small", "medium", "large"]),
        ...root.closing("screenTime", false),

        // ── Weather ──
        ...root.opening("weather"),
        root.size("weather", ["small", "medium", "large"]),
        root.row("weather", "showLocation", "Location", "switch", true, {}),
        root.row("weather", "style", "Style", "choice", "pill", { when: () => root.material("weather"),
            choices: root.choices([["pill", "Shape"], ["card", "Card"], ["detail", "Detail"], ["dial", "Instrument"]]) }),
        root.row("weather", "shape", "Shape", "choice", "pill", { when: () => root.material("weather") && root.is("weather", "style", "pill", "pill"),
            choices: root.choices([["pill", "Pill"], ["circle", "Circle"], ["oval", "Oval"], ["diamond", "Diamond"], ["heart", "Heart"], ["flower", "Flower"], ["cookie4", "Cookie"],
                ["sunny", "Sunny"], ["clover", "Clover"], ["softBurst", "Burst"], ["gem", "Gem"], ["puffy", "Puffy"]]) }),
        root.preset("weather", "Preset", "default", [["default", "Default", { size: 200, tempSize: 80, iconSize: 80, showTemp: true, showIcon: true, showCondition: false }],
            ["compact", "Compact", { size: 140, tempSize: 50, iconSize: 50, showTemp: true, showIcon: true, showCondition: false }],
            ["iconOnly", "Icon only", { size: 120, showTemp: false, showIcon: true, showCondition: false }],
            ["textOnly", "Text only", { size: 160, showTemp: true, showIcon: false, showCondition: true }]], () => root.material("weather")),
        root.row("weather", "showTemp", "Temperature", "switch", true, { when: () => root.plain("weather") }),
        root.row("weather", "showIcon", "Icon", "switch", true, { when: () => root.plain("weather") }),
        root.row("weather", "showCondition", "Condition text", "switch", false, { when: () => root.plain("weather") && !root.is("weather", "style", "pill", "detail") }),
        root.row("weather", "showMetrics", "Metric chips", "switch", true, { when: () => root.plain("weather") && root.is("weather", "style", "pill", "detail") }),
        root.row("weather", "showSunPath", "Sun path", "switch", true, { when: () => root.plain("weather") && root.is("weather", "style", "pill", "dial") }),
        root.row("weather", "showSunTimes", "Sun times", "switch", true, { when: () => root.plain("weather") && root.is("weather", "style", "pill", "dial") && Boolean(root.value("weather", "showSunPath", true)) }),
        root.row("weather", "size", "Widget size", "range", 200, { min: 80, max: 400, step: 10, unit: " px", when: () => root.material("weather") }),
        root.row("weather", "tempSize", "Temp size", "range", 80, { min: 20, max: 200, step: 5, unit: " px", when: () => root.material("weather") }),
        root.row("weather", "iconSize", "Icon size", "range", 80, { min: 20, max: 200, step: 5, unit: " px", when: () => root.material("weather") }),
        root.row("weather", "padding", "Padding", "range", 20, { min: 0, max: 60, step: 2, unit: " px", when: () => root.material("weather") }),
        root.row("weather", "tempFontWeight", "Temp font weight", "range", 500, { min: 100, max: 900, step: 100, when: () => root.material("weather") }),
        root.row("weather", "conditionOpacity", "Condition opacity", "range", 0.7, { min: 0, max: 1, step: 0.05, scale: 100, unit: " %", when: () => root.material("weather") && Boolean(root.value("weather", "showCondition", false)) }),
        ...root.closing("weather", true),

        // ── News ──
        ...root.opening("newsTicker"),
        root.size("newsTicker", ["small", "medium", "large"]),
        root.row("newsTicker", "showMeta", "Source and time", "switch", true, {}),
        root.row("newsTicker", "rotateSeconds", "Change every", "choice", 45, { when: () => root.face("newsTicker"),
            choices: root.choices([[15, "15 s"], [45, "45 s"], [120, "2 min"], [300, "5 min"]]) }),
        root.row("newsTicker", "style", "Presentation", "choice", "card", { when: () => root.material("newsTicker"), choices: root.choices([["card", "Card"], ["instrument", "Instrument"]]) }),
        root.row("newsTicker", "contentWidth", "Width", "range", 320, { min: 200, max: 600, step: 10, unit: " px", when: () => root.plain("newsTicker") }),
        root.row("newsTicker", "contentHeight", "Height", "range", 92, { min: 60, max: 300, step: 4, unit: " px", when: () => root.plain("newsTicker") }),
        ...root.closing("newsTicker", true),

        // ── Notes ──
        ...root.opening("notes"),
        root.size("notes", ["small", "medium", "large"]),
        root.row("notes", "style", "Presentation", "choice", "card", { when: () => root.material("notes"), choices: root.choices([["card", "Card"], ["instrument", "Instrument"]]) }),
        root.row("notes", "showRules", "Writing guides", "switch", true, { when: () => root.plain("notes") && root.is("notes", "style", "card", "instrument") }),
        root.row("notes", "fontFamily", "Font", "choice", "sans", { when: () => root.plain("notes"), choices: root.choices([["sans", "Sans"], ["mono", "Mono"]]) }),
        root.row("notes", "textAlign", "Alignment", "choice", "left", { tune: true, when: () => root.plain("notes"),
            choices: root.choices([["left", "Left", "format_align_left"], ["center", "Center", "format_align_center"], ["right", "Right", "format_align_right"]]) }),
        root.row("notes", "fontSize", "Font size", "range", 14, { min: 10, max: 48, unit: " px", when: () => root.plain("notes") }),
        root.row("notes", "contentWidth", "Width", "range", 240, { min: 160, max: 720, step: 10, unit: " px", when: () => root.plain("notes") }),
        root.row("notes", "contentHeight", "Height", "range", 160, { min: 100, max: 720, step: 10, unit: " px", when: () => root.plain("notes") }),
        ...root.closing("notes", true),

        // ── Todo ──
        ...root.opening("todo"),
        root.size("todo", ["small", "medium", "large"]),
        root.row("todo", "showCompleted", "Show completed tasks", "switch", true, {}),
        root.row("todo", "style", "Presentation", "choice", "card", { when: () => root.material("todo"), choices: root.choices([["card", "Card"], ["instrument", "Instrument"]]) }),
        root.row("todo", "instrumentRules", "Row rules", "switch", true, { tune: true, when: () => root.plain("todo") && root.is("todo", "style", "card", "instrument") }),
        root.row("todo", "contentWidth", "Width", "range", 300, { min: 240, max: 560, step: 4, unit: " px", when: () => root.plain("todo") }),
        root.row("todo", "contentHeight", "Height", "range", 276, { min: 220, max: 720, step: 4, unit: " px", when: () => root.plain("todo") }),
        ...root.closing("todo", true),

        // ── User card ──
        ...root.opening("userCard"),
        root.size("userCard", ["small", "medium"]),
        root.row("userCard", "showAvatar", "Picture", "switch", true, {}),
        root.row("userCard", "showWeather", "Weather", "switch", true, {}),
        root.row("userCard", "showHostname", "Computer name", "switch", true, {}),
        root.row("userCard", "style", "Presentation", "choice", "card", { when: () => root.material("userCard"), choices: root.choices([["card", "Card"], ["instrument", "Instrument"]]) }),
        root.row("userCard", "contentWidth", "Width", "range", 280, { min: 240, max: 600, step: 10, unit: " px", when: () => root.plain("userCard") }),
        root.row("userCard", "contentHeight", "Height", "range", 176, { min: 176, max: 320, step: 2, unit: " px", when: () => root.plain("userCard") }),
        ...root.closing("userCard", true),

        // ── Custom image ──
        ...root.opening("customImage"),
        root.row("customImage", "sourceMode", "Source type", "choice", "file", { choices: root.choices([["file", "Single file", "image"], ["folder", "Folder gallery", "photo_library"]]) }),
        root.row("customImage", "path", "Media file", "text", "", { placeholder: "Image, GIF, or video", when: () => root.is("customImage", "sourceMode", "file", "file"),
            keywords: ["image", "picture", "photo", "gif", "video", "path", "file", "imagen"] }),
        root.row("customImage", "folder", "Media folder", "text", "", { placeholder: "Folder containing images or videos", when: () => root.is("customImage", "sourceMode", "file", "folder") }),
        root.row("customImage", "mediaFilter", "Media type", "choice", "all", { when: () => root.is("customImage", "sourceMode", "file", "folder"),
            choices: root.choices([["all", "All media"], ["images", "Images only"], ["gifs", "GIF"], ["videos", "Videos only"]]) }),
        root.row("customImage", "order", "Order", "choice", "sequential", { when: () => root.is("customImage", "sourceMode", "file", "folder"), choices: root.choices([["sequential", "Sequential"], ["random", "Random"]]) }),
        root.row("customImage", "intervalSeconds", "Change every", "range", 30, { min: 3, max: 3600, step: 1, unit: " s", when: () => root.is("customImage", "sourceMode", "file", "folder") }),
        root.row("customImage", "shape", "Shape", "choice", "Cookie4Sided", { choicesFrom: "shapes", keywords: ["shape", "mask", "cookie", "circle", "forma"] }),
        root.row("customImage", "fitMode", "Fit", "choice", "cover", { choices: root.choices([["cover", "Crop to fill"], ["contain", "Show full media"]]) }),
        root.row("customImage", "size", "Size", "range", 220, { min: 80, max: 1200, step: 10, unit: " px" }),
        root.row("customImage", "transitionDuration", "Transition", "range", 450, { min: 0, max: 2000, step: 50, unit: " ms", zeroLabel: "Off" }),
        ...root.closing("customImage", false),

        // ── Image converter ──
        ...root.opening("imageConverter"),
        root.row("imageConverter", "selectedFormat", "Convert to", "choice", "webp", {
            choices: root.choices([["png", "PNG"], ["jpg", "JPG"], ["webp", "WEBP"], ["avif", "AVIF"], ["bmp", "BMP"], ["tiff", "TIFF"], ["pdf", "PDF"]]) }),
        ...root.closing("imageConverter", true),

        // ── Decorative shape ──
        ...root.opening("shape"),
        root.row("shape", "shape", "Shape", "choice", "Flower", { choicesFrom: "shapes" }),
        root.row("shape", "outline", "Fill", "choice", false, { choices: root.choices([[false, "Filled"], [true, "Outline"]]) }),
        root.row("shape", "treatment", "Treatment", "choice", "flat", { when: () => !Boolean(root.value("shape", "outline", false)),
            choices: root.choices([["flat", "Solid"], ["inset", "Inset"], ["duotone", "Duotone"]]) }),
        root.row("shape", "angle", "Rotation", "range", 0, { min: 0, max: 360, step: 15, unit: "°" }),
        root.row("shape", "contentWidth", "Width", "range", 160, { min: 64, max: 600, step: 10, unit: " px" }),
        root.row("shape", "contentHeight", "Height", "range", 160, { min: 64, max: 240, step: 4, unit: " px" }),
        ...root.closing("shape", false),

        // ── Japanese typography ──
        ...root.opening("japaneseTypography"),
        root.row("japaneseTypography", "preset", "Layout presets", "choice", "exhibition", {
            choices: root.choices([["exhibition", "Exhibition"], ["magazine", "Magazine"], ["minimal", "Minimal"], ["traditional", "Traditional"]]),
            apply: next => root.relative("japaneseTypography", JapanesePresets.composition("background.widgets.japaneseTypography", next)) }),
        ...[["primaryText", "Lead title", "夏の記憶"], ["secondaryText", "Secondary vertical copy", "潮風と、あの子と、終わらない夏"], ["sealText", "Seal text", "特別展"],
            ["footerText", "Footer label", "PACIFIC DRIVE-IN"], ["dateText", "Date or edition line", "7.12 — 8.31"]]
            .map(entry => root.row("japaneseTypography", entry[0], entry[1], "text", entry[2], { placeholder: entry[2] })),
        ...[["showSecondary", "Show secondary vertical copy", true], ["showSeal", "Show exhibition seal", true], ["showFooter", "Show footer and date", true],
            ["showRule", "Show editorial rule", true], ["mirrorLayout", "Mirror composition", false], ["rotateLatin", "Rotate Latin characters vertically", false]]
            .map(entry => root.row("japaneseTypography", entry[0], entry[1], "switch", entry[2], { tune: entry[0] === "rotateLatin" || entry[0] === "mirrorLayout",
                when: entry[0] === "showRule" ? () => Boolean(root.value("japaneseTypography", "showFooter", true)) : undefined,
                apply: next => root.relative("japaneseTypography", JapanesePresets.setValue("background.widgets.japaneseTypography", entry[0], next, "composition")) })),
        root.row("japaneseTypography", "fontPreset", "Type direction", "choice", "mincho", { choices: root.choices([["mincho", "Mincho"], ["mixed", "Mixed"], ["gothic", "Gothic"]]),
            apply: next => root.relative("japaneseTypography", JapanesePresets.font("background.widgets.japaneseTypography", next)) }),
        root.row("japaneseTypography", "palettePreset", "Color source", "choice", "adaptive", {
            choices: root.choices([["adaptive", "Wallpaper adaptive"], ["sumi", "Sumi"], ["ivory", "Ivory"], ["sunset", "Sunset"], ["cinema", "Cinema"], ["custom", "Manual roles"]]),
            apply: next => next === "custom" ? { palettePreset: "custom", paletteMode: "manual" }
                : root.relative("japaneseTypography", JapanesePresets.palette("background.widgets.japaneseTypography", next)) }),
        ...[["primaryColor", "Lead title", "#E7D4B2"], ["secondaryColor", "Secondary copy", "#CDB48D"], ["sealColor", "Seal", "#A64B39"], ["detailColor", "Footer and date", "#D0B996"], ["ruleColor", "Editorial rule", "#C18A53"]]  // iris-literal: the widget's stored default colours, shown as placeholders
            .map(entry => root.row("japaneseTypography", entry[0], entry[1], "text", entry[2], { placeholder: entry[2], part: "Colours", tune: true,
                when: () => root.is("japaneseTypography", "paletteMode", "adaptive", "manual"),
                apply: next => root.relative("japaneseTypography", JapanesePresets.setValue("background.widgets.japaneseTypography", entry[0], next, "palette")) })),
        root.row("japaneseTypography", "fontFamily", "Lead title font", "text", "serif", { placeholder: "serif", tune: true, part: "Type",
            apply: next => root.relative("japaneseTypography", JapanesePresets.setValue("background.widgets.japaneseTypography", "fontFamily", next, "font")) }),
        root.row("japaneseTypography", "secondaryFontFamily", "Secondary font", "choice", "", { tune: true, part: "Type",
            choices: root.choices([["", "Same as title"], ["serif", "Serif / Mincho"], ["sans-serif", "Sans / Gothic"], ["monospace", "Monospace"]]),
            apply: next => root.relative("japaneseTypography", JapanesePresets.setValue("background.widgets.japaneseTypography", "secondaryFontFamily", next, "font")) }),
        root.row("japaneseTypography", "latinFontFamily", "Footer font", "choice", "", { tune: true, part: "Type",
            choices: root.choices([["", "Interface font"], ["serif", "Serif"], ["sans-serif", "Sans"], ["monospace", "Monospace"]]),
            apply: next => root.relative("japaneseTypography", JapanesePresets.setValue("background.widgets.japaneseTypography", "latinFontFamily", next, "font")) }),
        ...[["primaryWeight", "Lead weight", 500, 100, 900, 100, "", "font"], ["secondaryWeight", "Secondary weight", 400, 100, 900, 100, "", "font"], ["latinWeight", "Footer weight", 600, 100, 900, 100, "", "font"],
            ["primarySize", "Lead size", 72, 28, 140, 2, " px", "composition"], ["secondarySize", "Secondary size", 18, 10, 48, 1, " px", "composition"],
            ["footerSize", "Footer size", 14, 8, 32, 1, " px", "composition"], ["dateSize", "Date size", 12, 8, 28, 1, " px", "composition"],
            ["primaryColumns", "Lead columns", 2, 1, 4, 1, "", "composition"], ["secondaryColumns", "Secondary columns", 2, 1, 5, 1, "", "composition"],
            ["columnGap", "Column gap", 14, 4, 48, 1, " px", "composition"], ["letterSpacing", "Lead spacing", 2, 0, 20, 1, " px", "font"],
            ["secondaryLetterSpacing", "Secondary spacing", 1, 0, 20, 1, " px", "font"],
            ["primaryOpacity", "Lead opacity", 100, 10, 100, 5, " %", "palette"], ["secondaryOpacity", "Secondary opacity", 78, 10, 100, 5, " %", "palette"],
            ["sealOpacity", "Seal opacity", 100, 10, 100, 5, " %", "palette"], ["detailOpacity", "Detail opacity", 72, 10, 100, 5, " %", "palette"],
            ["ruleOpacity", "Rule opacity", 78, 10, 100, 5, " %", "palette"], ["ruleThickness", "Rule thickness", 1, 1, 6, 1, " px", "composition"],
            ["sealFillOpacity", "Seal fill", 0, 0, 100, 5, " %", "palette"], ["shadowStrength", "Wallpaper shadow", 35, 0, 100, 5, " %", "palette"],
            ["outlineOpacity", "Text outline", 0, 0, 100, 5, " %", "palette"]]
            .map(entry => root.row("japaneseTypography", entry[0], entry[1], "range", entry[2], { min: entry[3], max: entry[4], step: entry[5], unit: entry[6],
                part: entry[7] === "palette" ? "Colours" : "Type",
                apply: next => root.relative("japaneseTypography", JapanesePresets.setValue("background.widgets.japaneseTypography", entry[0], next, entry[7])) })),
        root.row("japaneseTypography", "outlineColor", "Outline color", "text", "#000000", { placeholder: "#000000", part: "Colours",  // iris-literal: the stored default outline colour
            when: () => Number(root.value("japaneseTypography", "outlineOpacity", 0)) > 0 }),
        ...root.closing("japaneseTypography", true),

        // ── Editorial ──
        ...root.opening("editorial"),
        root.row("editorial", "style", "Style", "choice", "poster", { choices: root.choices([["poster", "Poster"], ["quote", "Quote"], ["label", "Label"]]) }),
        root.row("editorial", "title", "Title", "text", "Make room for wonder.", { placeholder: "Title" }),
        root.row("editorial", "caption", "Caption", "text", "A LITTLE EVERY DAY", { placeholder: "Caption" }),
        root.row("editorial", "footer", "Footer", "text", "YOUR OWN PERSPECTIVE", { placeholder: "Footer" }),
        root.row("editorial", "showAccent", "Accents", "choice", true, { choices: root.choices([[true, "Decorative accents"], [false, "Text only"]]) }),
        root.row("editorial", "contentWidth", "Width", "range", 360, { min: 180, max: 900, step: 20, unit: " px" }),
        root.row("editorial", "contentHeight", "Height", "range", 240, { min: 140, max: 900, step: 20, unit: " px" }),
        ...root.closing("editorial", true),

        // ── Mascot ──
        ...root.opening("mascot"),
        root.row("mascot", "poseFilter", "Poses", "choice", "all", { tune: true,
            choices: root.choices([["all", "All"], ["featured", "Featured"], ["pixel", "Pixel"], ["street", "Street"], ["chibi", "Chibi"], ["loops", "Loops"], ["manual", "Manual"]]) }),
        root.row("mascot", "pose", "Pose on the desktop", "choice", "reading", { choicesFrom: "mascotPoses", when: () => String(root.value("mascot", "customPath", "")).length === 0 }),
        root.row("mascot", "customPath", "Custom image", "text", "", { placeholder: "Path to any image or GIF (empty = pose above)" }),
        ...root.closing("mascot", true)
    ]
    // What a row shows and what it writes (IrisOptions.currentValue / commit route `spec.widget` rows here).
    function read(spec: var): var {
        if (spec.widgetEnable) return root.on(spec.widget)
        return root.value(spec.widget, spec.key, spec.fallback)
    }
    function write(spec: var, next: var): void {
        if (spec.widgetEnable) { DesktopWidgetLayout.setGloballyEnabled(spec.widget, Boolean(next)); return }
        let value = next
        if (spec.key === "timezones") value = Array.from(next ?? []).slice(0, WorldClock.maxTimezones)
        const values = spec.apply ? spec.apply(value) : ({})
        if (!spec.apply) values[spec.key] = value
        DesktopWidgetLayout.setEverywhere(spec.widget, values)
    }
    function choicesFor(source: string): var {
        if (source === "timezones") return WorldClock.comboModel.map(entry => ({ label: entry.label, value: entry.tz }))
        if (source === "shapes") return DesktopWidgetShapes.choices.map(entry => ({ label: entry.label, value: entry.value }))
        if (source === "mascotPoses") return MascotCatalog.desktopWidgetPosesForGroup(String(root.value("mascot", "poseFilter", "all")))
            .map(pose => ({ label: String(pose).replace(/[-_]/g, " ").replace(/^./, first => first.toUpperCase()), value: pose }))
        if (source === "screens") return Quickshell.screens.map(screen => ({ label: String(screen.name), value: String(screen.name) }))
        return []
    }
    // A preset's updates come as full paths; rows write keys relative to their widget.
    function relative(widget: string, updates: var): var {
        const prefix = "background.widgets." + widget + "."
        const out = ({})
        for (const path of Object.keys(updates)) out[path.startsWith(prefix) ? path.slice(prefix.length) : path] = updates[path]
        return out
    }

    // Arranging and power: what every widget shares.
    readonly property var sharedRows: [
        { section: "widgets", group: "Arranging", label: "Edit desktop widgets", description: "Carry a widget near another and it lines up; drop it on one that is taken and it finds the nearest free spot. Hold Alt to place it freely.",
            kind: "action", button: "Edit", run: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.setWidgetEditMode(true) },
            keywords: ["arrange", "move", "edit", "drag", "editar", "mover"] },
        { section: "widgets", group: "Arranging", label: "Snap", description: "To the grid, the screen's edges and centre, and the widgets around.", path: "background.widgets.editGrid.snap", kind: "switch", fallback: true,
            keywords: ["snap", "magnet", "grid", "align", "guides", "imán", "alinear"] },
        { section: "widgets", group: "Arranging", label: "Grid", path: "background.widgets.editGrid.size", visibleWhen: "background.widgets.editGrid.snap", kind: "range", fallback: 32, min: 8, max: 128, step: 8, unit: " px" },
        { section: "widgets", group: "Arranging", label: "Fade with windows", description: "Widgets fade when windows are open on the workspace.", path: "background.widgets.dynamicOpacity", kind: "range", fallback: 0, min: 0, max: 100, step: 10, unit: " %", zeroLabel: "Off",
            keywords: ["fade", "windows", "opacity", "hide"] },
        { section: "widgets", group: "Power saving", label: "Enable power saving", path: "background.widgets.powerSaving.enable", kind: "switch", fallback: true, keywords: ["power", "battery", "pause", "energía"] },
        { section: "widgets", group: "Power saving", label: "Pause on GameMode", tune: true, path: "background.widgets.powerSaving.pauseOnGameMode", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: true },
        { section: "widgets", group: "Power saving", label: "Pause on fullscreen", tune: true, path: "background.widgets.powerSaving.pauseOnFullscreen", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: true },
        { section: "widgets", group: "Power saving", label: "Pause when windows present", tune: true, path: "background.widgets.powerSaving.pauseWhenWindowsPresent", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: false },
        { section: "widgets", group: "Power saving", label: "Show paused effect", path: "background.widgets.powerSaving.showPausedEffect", visibleWhen: "background.widgets.powerSaving.enable", kind: "switch", fallback: false, tune: true }
    ]
    readonly property var rows: root.sharedRows.concat(root.widgetRows)

    // ── The Edge wave (Organic edge), whole, in Now Playing, after the group's own rows (`trail`) ──
    function edge(key: string, label: string, kind: string, extra: var): var {
        return Object.assign({ section: "player", group: "Edge wave", path: EdgeConfig.path + "." + key, label: label, kind: kind,
            fallback: EdgeConfig.defaults[key], visibleWhen: "iris.surround.music=widget", showIf: () => Boolean(Config.options?.background?.edgeWidgets?.organic?.enable), tune: true, trail: true }, extra ?? {})
    }
    function edgeChoices(list: var): var { return list.map(entry => ({ label: entry[1], value: entry[0] })) }
    readonly property var edgeRows: [
        root.edge("edges", "Sides", "pieces", { part: "Where", choices: root.edgeChoices([["top", "Top"], ["right", "Right"], ["bottom", "Bottom"], ["left", "Left"]]), tune: false }),
        root.edge("respectPanels", "Respect bars and dock", "switch", { part: "Where" }),
        root.edge("joinMode", "Corner relationship", "choice", { part: "Where", choices: root.edgeChoices([["auto", "Join connected edges"], ["separate", "Keep edges separate"]]) }),
        ...[["span", "Edge length", 10, 100, 5, " %"], ["position", "Position along edge", 0, 100, 1, " %"], ["depth", "Field depth", 24, 600, 4, " px"],
            ["inset", "Screen inset", 0, 160, 2, " px"], ["cornerRadius", "Screen corner radius", 0, 160, 2, " px"], ["cornerBlend", "Corner handoff", 0, 100, 5, " %"],
            ["taper", "Endpoint softness", 0, 50, 1, " %"], ["topScale", "Top reach", 10, 200, 5, " %"], ["rightScale", "Right reach", 10, 200, 5, " %"],
            ["bottomScale", "Bottom reach", 10, 200, 5, " %"], ["leftScale", "Left reach", 10, 200, 5, " %"]]
            .map(entry => root.edge(entry[0], entry[1], "range", { part: "Where", min: entry[2], max: entry[3], step: entry[4], unit: entry[5] })),
        root.edge("style", "Material", "choice", { part: "Material", choices: root.edgeChoices([["silk", "Silk"], ["aurora", "Aurora"], ["contour", "Contour"], ["liquid", "Liquid"]]) }),
        root.edge("shape", "Contour language", "choice", { part: "Material", choices: root.edgeChoices([["flow", "Flow"], ["ribbon", "Ribbon"], ["cells", "Pulse cells"], ["filament", "Filament"]]) }),
        root.edge("colorMode", "Color movement", "choice", { part: "Material", choices: root.edgeChoices([["flow", "Flow"], ["spectrum", "Spectrum"], ["pulse", "Beat"], ["static", "Static"]]) }),
        root.edge("effectMode", "Light behavior", "choice", { part: "Material", choices: root.edgeChoices([["clean", "Clean"], ["shimmer", "Harmonic shimmer"], ["echo", "Pulse echo"], ["prism", "Spectral prism"],
            ["bloom", "Bass bloom"], ["caustic", "Liquid caustics"], ["afterglow", "Peak afterglow"]]) }),
        ...[["primaryColor", "Primary"], ["secondaryColor", "Secondary"], ["tertiaryColor", "Tertiary"]]
            .map(entry => root.edge(entry[0], entry[1], "text", { part: "Material", placeholder: String(EdgeConfig.defaults[entry[0]]), showIf: () => Boolean(Config.options?.background?.edgeWidgets?.organic?.enable)
                && String(Config.getNestedValue(EdgeConfig.path + ".palette", "theme")) === "custom" })),
        ...[["thickness", "Body weight", 5, 70, 1], ["bodyOpacity", "Body opacity", 0, 100, 5], ["crestStrength", "Crest brightness", 0, 150, 5], ["detail", "Contour detail", 0, 100, 5],
            ["glow", "Glow intensity", 0, 100, 5], ["glowSpread", "Glow spread", 0, 100, 5], ["effectStrength", "Effect strength", 0, 100, 5],
            ["colorSpeed", "Color travel", 0, 100, 5], ["colorIntensity", "Color intensity", 0, 150, 5]]
            .map(entry => root.edge(entry[0], entry[1], "range", { part: "Material", min: entry[2], max: entry[3], step: entry[4], unit: " %" })),
        root.edge("hueShift", "Hue shift", "range", { part: "Material", min: -180, max: 180, step: 5, unit: "°" }),
        root.edge("restPresence", "Rest presence", "range", { part: "Music", min: 0, max: 100, step: 5, unit: " %" }),
        root.edge("frequencyProfile", "Frequency focus", "choice", { part: "Music", choices: root.edgeChoices([["flat", "Balanced"], ["bass", "Bass"], ["warm", "Warm"], ["vocal", "Vocals"], ["treble", "Treble"], ["smile", "Bass + treble"]]) }),
        root.edge("flowDirection", "Travel direction", "choice", { part: "Music", choices: root.edgeChoices([["clockwise", "Clockwise"], ["counterclockwise", "Counter-clockwise"]]) }),
        ...[["motionSpeed", "Motion speed", 0, 250, 5, " %"], ["idleMotion", "Ambient motion", 0, 100, 5, " %"], ["sensitivity", "Audio sensitivity", 0, 200, 5, " %"],
            ["audioRange", "Audio range", 0, 150, 5, " %"], ["pulse", "Beat pulse", 0, 150, 5, " %"], ["beatGlow", "Beat glow", 0, 150, 5, " %"],
            ["transientStrength", "Transient punch", 0, 150, 5, " %"], ["attack", "Attack speed", 20, 250, 5, " %"], ["release", "Release speed", 20, 250, 5, " %"],
            ["smoothing", "Audio smoothing", 0, 8, 1, ""], ["bassDrive", "Bass drive", 0, 150, 5, " %"], ["trebleDrive", "Treble shimmer", 0, 150, 5, " %"],
            ["compression", "Frequency separation", 0, 100, 5, " %"], ["accentStrength", "Frequency emphasis", 0, 100, 5, " %"]]
            .map(entry => root.edge(entry[0], entry[1], "range", { part: "Music", min: entry[2], max: entry[3], step: entry[4], unit: entry[5] })),
        root.edge("screenList", "Screens", "pieces", { part: "Where", choicesFrom: "screens", description: "None chosen shows it on every screen.", showIf: () => Boolean(Config.options?.background?.edgeWidgets?.organic?.enable) && Quickshell.screens.length > 1 })
    ]
}
