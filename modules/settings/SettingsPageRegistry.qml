pragma Singleton
import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Single source of truth for the Settings UI shared between the overlay
 * (modules/settings/SettingsOverlay.qml) and the standalone window
 * (settings.qml): page list, sidebar categories and the static search index.
 * Component paths are relative to the shell root — resolve with
 * Quickshell.shellPath(page.component).
 */
Singleton {
    id: root

    readonly property var pages: [
        {
            key: "quick",
            name: Translation.tr("Quick"),
            icon: "instant_mix",
            desc: Translation.tr("Wallpaper & quick tweaks"),
            essential: true,
            component: "modules/settings/QuickConfig.qml"
        },
        {
            key: "system",
            name: Translation.tr("System"),
            icon: "browse",
            desc: Translation.tr("Audio, battery, language, lock"),
            essential: true,
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            key: "bar",
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            desc: Translation.tr("Position, tray, modules"),
            essential: true,
            component: "modules/settings/BarConfig.qml"
        },
        {
            key: "wallpaper",
            name: Translation.tr("Wallpaper"),
            icon: "texture",
            desc: Translation.tr("Backend, effects, backdrop"),
            essential: false,
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            key: "themes",
            name: Translation.tr("Themes"),
            icon: "palette",
            desc: Translation.tr("Colors, fonts, styles"),
            essential: true,
            component: "modules/settings/ThemesConfig.qml"
        },
        {
            key: "panels",
            name: Translation.tr("Panels"),
            icon: "bottom_app_bar",
            desc: Translation.tr("Dock, sidebars, overview"),
            essential: true,
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            key: "tools",
            name: Translation.tr("Tools"),
            icon: "build",
            desc: Translation.tr("Recording, crosshair, overlays"),
            essential: false,
            component: "modules/settings/ToolsConfig.qml"
        },
        {
            key: "services",
            name: Translation.tr("Services"),
            icon: "settings",
            desc: Translation.tr("Weather, music, calendar, apps"),
            essential: false,
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            key: "advanced",
            name: Translation.tr("Advanced"),
            icon: "construction",
            desc: Translation.tr("Color gen, performance"),
            essential: false,
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            key: "shortcuts",
            name: Translation.tr("Shortcuts"),
            icon: "keyboard",
            desc: Translation.tr("Keybindings reference"),
            essential: true,
            component: "modules/settings/CheatsheetConfig.qml"
        },
        {
            key: "modules",
            name: Translation.tr("Modules"),
            icon: "extension",
            desc: Translation.tr("Enable/disable panels, scaling"),
            essential: false,
            component: "modules/settings/ModulesConfig.qml"
        },
        {
            key: "waffle-style",
            name: Translation.tr("Waffle Style"),
            icon: "window",
            desc: Translation.tr("Win11-style taskbar"),
            essential: false,
            component: "modules/settings/WaffleConfig.qml"
        },
        {
            key: "compositor",
            name: Translation.tr("Compositor"),
            icon: "desktop_windows",
            desc: Translation.tr("Display, input, layout"),
            essential: false,
            component: "modules/settings/NiriConfig.qml"
        },
        {
            key: "about",
            name: Translation.tr("About"),
            icon: "info",
            desc: Translation.tr("Version & credits"),
            essential: true,
            component: "modules/settings/About.qml"
        },
        {
            key: "widgets",
            name: Translation.tr("Widgets"),
            icon: "widgets",
            desc: Translation.tr("Clock, weather, media, custom"),
            essential: false,
            component: "modules/settings/DesktopWidgetsConfig.qml"
        },
        {
            key: "monitors",
            name: Translation.tr("Monitors"),
            icon: "display_settings",
            desc: Translation.tr("Per-monitor shell visibility"),
            essential: true,
            component: "modules/settings/MonitorVisibilityConfig.qml"
        },
        {
            key: "dashboard",
            name: Translation.tr("Dashboard"),
            icon: "space_dashboard",
            desc: Translation.tr("Welcome hub panel & widgets"),
            essential: false,
            component: "modules/settings/DashboardConfig.qml"
        },
        {
            key: "autostart",
            name: Translation.tr("Autostart"),
            icon: "rocket_launch",
            desc: Translation.tr("Apps that start with iNiR"),
            essential: false,
            component: "modules/settings/AutostartConfig.qml"
        },
        {
            key: "workspace-strip",
            name: Translation.tr("Workspace Strip"),
            icon: "view_sidebar",
            desc: Translation.tr("Edge strip for workspace navigation"),
            essential: false,
            component: "modules/settings/WorkspaceStripConfig.qml"
        },
        {
            key: "mascot",
            name: Translation.tr("Mascot"),
            icon: "pets",
            desc: Translation.tr("Companion behavior, reactions, poses"),
            essential: false,
            component: "modules/settings/MascotConfig.qml"
        },
        {
            key: "arrange",
            name: Translation.tr("Arrange"),
            icon: "swap_vert",
            desc: Translation.tr("Reorder and hide navigation pages"),
            essential: false,
            component: "modules/settings/ArrangeConfig.qml"
        },
        {
            key: "ricelin",
            name: Translation.tr("Ricelin"),
            icon: "jp:リ",
            desc: Translation.tr("The washi & flame dialect: pill bar, islands, surfaces"),
            essential: false,
            component: "modules/settings/RicelinConfig.qml"
        },
        {
            key: "dock",
            name: Translation.tr("Dock"),
            icon: "call_to_action",
            desc: Translation.tr("Dock style, position, behavior and indicators"),
            essential: false,
            component: "modules/settings/DockConfig.qml"
        },
        {
            key: "sidebars",
            name: Translation.tr("Sidebars"),
            icon: "side_navigation",
            desc: Translation.tr("Left and right sidebar content and behavior"),
            essential: false,
            component: "modules/settings/SidebarsConfig.qml"
        },
        {
            key: "ai",
            name: Translation.tr("AI"),
            icon: "neurology",
            desc: Translation.tr("Providers, models, behavior, voice input"),
            essential: false,
            component: "modules/settings/AiConfig.qml"
        },
        {
            key: "effects",
            name: Translation.tr("Effects"),
            icon: "blur_on",
            desc: Translation.tr("Blur, glass, motion and rendering policy"),
            essential: true,
            component: "modules/settings/EffectsConfig.qml"
        },
        {
            key: "shell-layout",
            name: Translation.tr("Shell Layout"),
            icon: "dashboard_customize",
            desc: Translation.tr("Move and resize persistent shell surfaces"),
            essential: true,
            component: "modules/settings/ShellLayoutConfig.qml"
        },
        {
            key: "orbit",
            name: Translation.tr("Orbit"),
            icon: "hub",
            desc: Translation.tr("Niri workspace navigator, Trail and Stash"),
            essential: true,
            component: "modules/settings/OrbitConfig.qml"
        }
    ]

    // Sidebar grouping shared by both modes. Page indices reference the
    // pages array above — order here defines the visual nav order.
    readonly property var defaultCategories: [
        { label: Translation.tr("Essentials"), pages: [0] },
        { label: Translation.tr("Appearance"), pages: [4, 25, 3, 14, 21] },
        { label: Translation.tr("Shell"), pages: [2, 26, 27, 5, 22, 23, 16, 10, 11, 18, 19, 20] },
        { label: Translation.tr("System"), pages: [1, 24, 7, 6, 12, 15, 8, 17] },
        { label: Translation.tr("Reference"), pages: [9, 13] }
    ]

    // User-arranged nav (Settings › Arrange). Saved value is either the v1
    // array of groups or the v2 object { groups, hidden }. Sanitized so
    // every non-hidden page stays reachable: invalid indices drop, pages
    // missing from the saved layout land in a trailing "More" group.
    // Hidden pages leave the nav but search still reaches them.
    readonly property var _arrangement: {
        const fallback = ({ groups: defaultCategories, hidden: [] })
        const raw = Config.options?.settingsUi?.categories ?? ""
        if (!raw || raw.length === 0) return fallback
        let saved
        try {
            saved = JSON.parse(raw)
        } catch (e) {
            return fallback
        }
        const groupsIn = Array.isArray(saved) ? saved : (Array.isArray(saved?.groups) ? saved.groups : null)
        if (!groupsIn || groupsIn.length === 0) return fallback
        const hidden = (Array.isArray(saved?.hidden) ? saved.hidden : [])
            .filter(i => Number.isInteger(i) && i >= 0 && i < pages.length)
        const seen = new Set(hidden)
        const out = []
        for (const c of groupsIn) {
            if (!c || typeof c.label !== "string") continue
            const pageIdxs = (Array.isArray(c.pages) ? c.pages : [])
                .filter(i => Number.isInteger(i) && i >= 0 && i < pages.length && !seen.has(i))
            pageIdxs.forEach(i => seen.add(i))
            // empty groups survive so the editor can move pages into them
            out.push({ label: c.label, pages: pageIdxs })
        }
        const missing = []
        for (let i = 0; i < pages.length; i++)
            if (!seen.has(i)) missing.push(i)
        if (missing.length > 0) out.push({ label: Translation.tr("More"), pages: missing })
        return out.length > 0 ? ({ groups: out, hidden: hidden }) : fallback
    }
    readonly property var categories: _arrangement.groups
    readonly property var hiddenPages: _arrangement.hidden

    function iconForPage(idx) {
        return (idx >= 0 && idx < pages.length) ? (pages[idx].icon || "settings") : "settings";
    }

    property var _staticSearchIndex: null

    Connections {
        target: Translation
        function onLanguageCodeChanged(): void { root._staticSearchIndex = null }
        function onTranslationsChanged(): void { root._staticSearchIndex = null }
        function onGeneratedTranslationsChanged(): void { root._staticSearchIndex = null }
    }

    function searchIndex(): var {
        if (_staticSearchIndex !== null)
            return _staticSearchIndex

        _staticSearchIndex = [
        {
            pageIndex: 27, pageName: root.pages[27].name,
            section: Translation.tr("Activation"),
            label: Translation.tr("Orbit hot corner"),
            description: Translation.tr("Choose the corner, activation distance and conflict-safe behavior with Niri Overview"),
            keywords: ["orbit", "overview", "task view", "hot corner", "niri", "workspace", "navigation", "distance", "conflict"]
        },
        {
            pageIndex: 27, pageName: root.pages[27].name,
            section: Translation.tr("Workspace layout"),
            label: Translation.tr("Orbit layout"),
            description: Translation.tr("Visible workspaces, scale, spacing and balanced window grid"),
            keywords: ["orbit", "workspace", "grid", "scale", "spacing", "preview", "window"]
        },
        {
            pageIndex: 27, pageName: root.pages[27].name,
            section: Translation.tr("Navigation"),
            label: Translation.tr("Trail and Stash"),
            description: Translation.tr("Recent-window navigation and temporary window parking"),
            keywords: ["orbit", "trail", "stash", "recent", "mru", "minimize", "park", "window"]
        },
        {
            pageIndex: 27, pageName: root.pages[27].name,
            section: Translation.tr("Material motion"),
            label: Translation.tr("Orbit motion"),
            description: Translation.tr("Entry presentation and workspace navigation motion"),
            keywords: ["orbit", "animation", "motion", "navigation", "glide", "material"]
        },
        {
            pageIndex: 26, pageName: root.pages[26].name,
            section: Translation.tr("Live shell layout"),
            label: Translation.tr("Edit live"),
            description: Translation.tr("Move bar, dock and sidebars directly on the desktop"),
            keywords: ["layout", "move", "position", "sidebar", "bar", "dock", "output", "edit", "live"]
        },
        {
            pageIndex: 26, pageName: root.pages[26].name,
            section: Translation.tr("Live shell layout"),
            label: Translation.tr("Sidebar size"),
            description: Translation.tr("Full, fit and custom sidebar height and width"),
            keywords: ["layout", "sidebar", "size", "height", "width", "fit", "custom", "resize", "reset"]
        },
        // =====================================================================
        // Quick (page 0)
        // =====================================================================
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Wallpaper & Colors"),
            label: Translation.tr("Wallpaper & Colors"),
            description: Translation.tr("Wallpaper, palette and transparency settings"),
            keywords: ["wallpaper", "colors", "palette", "theme", "background"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Bar & screen"),
            label: Translation.tr("Bar & screen"),
            description: Translation.tr("Bar position and screen rounding"),
            keywords: ["bar", "position", "screen", "round", "corner"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Capture locations"),
            label: Translation.tr("Recordings folder"),
            description: Translation.tr("Where screen recordings are saved"),
            keywords: ["capture", "record", "recording", "video", "save", "path", "folder", "directory"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Capture locations"),
            label: Translation.tr("Screenshots folder"),
            description: Translation.tr("Where iNiR screenshots are saved"),
            keywords: ["capture", "screenshot", "snip", "save", "path", "folder", "directory", "picture"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("App filters"),
            label: Translation.tr("Notification and visualizer app filters"),
            description: Translation.tr("Mute selected notification senders and restrict visualizer playback sources"),
            keywords: ["filter", "filters", "app", "apps", "notification", "mute", "block", "visualizer", "cava", "audio", "spotify", "ncspot", "ytmusic", "discord", "slack"]
        },
        {
            pageIndex: 19, pageName: root.pages[19].name,
            section: Translation.tr("Mascot"),
            label: Translation.tr("Mascot"),
            description: Translation.tr("Mascot illustration and playful companion"),
            keywords: ["mascot", "cat", "girl", "companion", "waifu", "illustration", "peek"]
        },
        {
            pageIndex: 19, pageName: root.pages[19].name,
            section: Translation.tr("Mascot"),
            label: Translation.tr("Event reactions"),
            description: Translation.tr("What she reacts to and which pose each event uses"),
            keywords: ["mascot", "reactions", "events", "music", "battery", "notifications", "wallpaper", "screenshot", "gaming", "unlock", "pose", "image", "artist", "video", "monitor", "focused"]
        },
        {
            pageIndex: 19, pageName: root.pages[19].name,
            section: Translation.tr("Mascot"),
            label: Translation.tr("Pose for this event"),
            description: Translation.tr("Choose from the curated full-body pose collection"),
            keywords: ["mascot", "pose", "full body", "animation", "event", "override", "picker"]
        },
        {
            pageIndex: 19, pageName: root.pages[19].name,
            section: Translation.tr("Mascot"),
            label: Translation.tr("Chaos mode"),
            description: Translation.tr("She runs across the desktop, bonks widgets and rattles the bar"),
            keywords: ["mascot", "chaos", "romp", "kick", "bonk", "widgets", "rearrange", "tidy", "physics"]
        },
        {
            pageIndex: 19, pageName: root.pages[19].name,
            section: Translation.tr("Kira collection"),
            label: Translation.tr("Kira collection"),
            description: Translation.tr("Browse every full-body pose, animation, portrait, chibi and editorial illustration"),
            keywords: ["mascot", "kira", "collection", "gallery", "archive", "pose", "full body", "animated", "portrait", "chibi", "editorial"]
        },
        {
            pageIndex: 20, pageName: root.pages[20].name,
            section: Translation.tr("Arrange settings"),
            label: Translation.tr("Arrange settings"),
            description: Translation.tr("Reorder groups and pages, or hide pages from navigation"),
            keywords: ["arrange", "reorder", "categories", "groups", "nav", "sidebar", "customize", "layout", "settings", "hide", "show", "visibility", "drag"]
        },

        // =====================================================================
        // General (page 1) — per-option entries
        // =====================================================================
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Audio"),
            description: Translation.tr("Volume protection and limits"),
            keywords: ["audio", "volume", "earbang", "limit", "sound"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Volume protection"),
            description: Translation.tr("Prevent sudden volume spikes"),
            keywords: ["volume", "protection", "earbang", "spike", "loud", "limit", "max"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Max volume increase"),
            description: Translation.tr("Maximum volume jump allowed per step"),
            keywords: ["volume", "increase", "step", "max", "jump"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Battery"),
            description: Translation.tr("Battery warnings and auto suspend thresholds"),
            keywords: ["battery", "low", "critical", "suspend", "full"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Low battery threshold"),
            description: Translation.tr("Percentage to show low battery warning"),
            keywords: ["battery", "low", "warning", "threshold", "percentage"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Critical battery"),
            description: Translation.tr("Percentage for critical battery warning"),
            keywords: ["battery", "critical", "danger", "threshold"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Auto suspend"),
            description: Translation.tr("Automatically suspend on critical battery"),
            keywords: ["battery", "suspend", "sleep", "auto", "critical"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Charge limit"),
            description: Translation.tr("Limit maximum charge to preserve battery health"),
            keywords: ["battery", "charge", "limit", "health", "threshold", "conservation", "sysfs"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Language"),
            label: Translation.tr("Language"),
            description: Translation.tr("Interface language and AI translations"),
            keywords: ["language", "locale", "translation", "gemini", "idioma", "español", "english"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Language"),
            label: Translation.tr("UI Language"),
            description: Translation.tr("Interface display language"),
            keywords: ["language", "locale", "ui", "display", "idioma", "english", "spanish", "chinese", "japanese", "russian"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Policies"),
            label: Translation.tr("AI Policy"),
            description: Translation.tr("Enable or disable AI features"),
            keywords: ["ai", "policy", "enable", "disable", "local", "privacy"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Policies"),
            label: Translation.tr("Weeb Policy"),
            description: Translation.tr("Anime and manga content visibility"),
            keywords: ["weeb", "anime", "manga", "nsfw", "content", "policy"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Sounds"),
            label: Translation.tr("Sounds"),
            description: Translation.tr("Battery, Pomodoro and notification sounds"),
            keywords: ["sound", "notification", "pomodoro", "battery", "alert", "audio"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Sounds"),
            label: Translation.tr("Notification sound"),
            description: Translation.tr("Play sound when a notification arrives"),
            keywords: ["sound", "notification", "alert", "ring", "chime"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Time"),
            description: Translation.tr("Clock format and seconds"),
            keywords: ["time", "clock", "24h", "12h", "format"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Clock format"),
            description: Translation.tr("Time display format (e.g., hh:mm or h:mm AP)"),
            keywords: ["time", "clock", "format", "24h", "12h", "am", "pm", "hour", "minute"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Show seconds"),
            description: Translation.tr("Update clock every second"),
            keywords: ["time", "seconds", "precision", "clock", "update"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Work safety"),
            label: Translation.tr("Work Safety"),
            description: Translation.tr("Hide sensitive content on public networks"),
            keywords: ["work", "safety", "nsfw", "public", "network", "hide", "clipboard", "wallpaper"]
        },

        // =====================================================================
        // Bar (page 2) — per-option entries
        // =====================================================================
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Bar position"),
            description: Translation.tr("Bar position, auto hide and style"),
            keywords: ["bar", "position", "auto", "hide", "corner", "style", "top", "bottom", "float", "vertical"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Auto hide"),
            description: Translation.tr("Automatically hide the bar"),
            keywords: ["bar", "auto", "hide", "show", "hover", "reveal"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Corner style"),
            description: Translation.tr("Bar corner style: hug, float, rectangle or card"),
            keywords: ["bar", "corner", "style", "hug", "float", "rectangle", "card", "rounding"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Bar appearance"),
            description: Translation.tr("Bar surface style: classic, islands, scenic, frame, M3 or pill"),
            keywords: ["bar", "appearance", "islands", "scenic", "frame", "m3", "material", "tonal", "pill", "surface", "floating", "capsule", "gradient", "outline"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Audio spectrum"),
            label: Translation.tr("Bar audio spectrum"),
            description: Translation.tr("Bars, waves, frequency accents, dynamic curve fit and screen-spanning Pill wings"),
            keywords: ["spectrum", "audio", "cava", "bars", "wave", "origin", "bottom", "top", "center", "mirror", "ribbon", "density", "gap", "smoothing", "edge", "curve", "headroom", "profile", "accent", "bass", "warm", "vocal", "treble", "smile", "pill", "wings", "full screen", "bleed", "underlap", "ytmusic", "youtube music"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("M3 Bar"),
            label: Translation.tr("M3 layout and surfaces"),
            description: Translation.tr("M3 presets, joined or separate pills, transparent mode, gaps and widget layout"),
            keywords: ["m3", "material", "bar", "layout", "preset", "joined", "separate", "transparent", "surface", "gap", "left", "center", "right", "widgets"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("M3 Bar"),
            label: Translation.tr("M3 media and dividers"),
            description: Translation.tr("Media title, preferred player, width and divider appearance"),
            keywords: ["m3", "media", "title", "artist", "player", "width", "divider", "line", "dot", "space"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("M3 Bar"),
            label: Translation.tr("M3 resources and utility buttons"),
            description: Translation.tr("Resource rings, thresholds, dock sizing and utility controls"),
            keywords: ["m3", "resources", "cpu", "ram", "temperature", "disk", "swap", "threshold", "dock", "utility", "screenshot", "mic", "wallpaper"]
        },
        {
            pageIndex: 21, pageName: root.pages[21].name,
            section: Translation.tr("Pill bar"),
            label: Translation.tr("Pill setup"),
            description: Translation.tr("Behavior, floating window overlap, entry points, readability, surfaces, modules and geometry"),
            keywords: ["ricelin", "pill", "bar", "morph", "float", "floating", "overlap", "underlap", "window", "reserve", "launcher", "media", "overview", "kanji", "glyph", "sysmon", "clipboard", "scale", "gap", "expanded", "persistent", "compact", "toast", "osd", "notification", "hover", "row", "workspaces", "weather", "tray", "wifi", "battery", "mixer", "sidebar", "power", "soul", "bead", "icon", "size", "spacing"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Islands options"),
            description: Translation.tr("Islands bar geometry: capsule inset and padding"),
            keywords: ["islands", "bar", "inset", "padding", "capsule", "geometry", "spacing", "ricelin"]
        },
        {
            pageIndex: 21, pageName: root.pages[21].name,
            section: Translation.tr("Pill bar"),
            label: Translation.tr("Ricelin dialect"),
            description: Translation.tr("Enable the Ricelin Pill bar and configure it in this page"),
            keywords: ["ricelin", "pill", "bar", "mode", "setup", "washi", "flame"]
        },
        {
            pageIndex: 21, pageName: root.pages[21].name,
            section: Translation.tr("Island surfaces"),
            label: Translation.tr("Island surfaces and skin"),
            description: Translation.tr("Shared Ricelin body opacity, glass background, blur, radius and surface opt-ins"),
            keywords: ["ricelin", "island", "dock", "sidebar", "search", "control panel", "widgets", "workspace strip", "card", "body", "opacity", "glass", "background", "blur", "radius", "sheen", "shadow", "skin", "transparency"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Vertical bar"),
            description: Translation.tr("Use vertical bar layout on the side"),
            keywords: ["bar", "vertical", "side", "left", "orientation"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Bar background"),
            description: Translation.tr("Show or hide bar background"),
            keywords: ["bar", "background", "transparent", "show", "hide"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Appearance & Layout"),
            label: Translation.tr("Blur background"),
            description: Translation.tr("Enable glass blur behind the bar"),
            keywords: ["bar", "blur", "glass", "background", "transparent"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification indicator"),
            description: Translation.tr("Notification unread count in the bar"),
            keywords: ["notifications", "unread", "indicator", "count", "badge", "bar"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("System Tray"),
            label: Translation.tr("System tray"),
            description: Translation.tr("System tray icons behaviour"),
            keywords: ["tray", "systray", "icons", "pinned", "monochrome"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("System Tray"),
            label: Translation.tr("Monochrome tray icons"),
            description: Translation.tr("Tint tray icons to match theme"),
            keywords: ["tray", "monochrome", "tint", "icons", "theme", "color", "m3", "classic"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Utility Buttons"),
            label: Translation.tr("Utility buttons"),
            description: Translation.tr("Screen snip, color picker and toggles"),
            keywords: ["screen", "snip", "color", "picker", "mic", "dark", "mode", "performance", "screenshot", "record", "notepad", "keyboard"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Utility Buttons"),
            label: Translation.tr("Screen record button"),
            description: Translation.tr("Show screen record button in bar"),
            keywords: ["screen", "record", "button", "bar", "recording", "video"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Utility Buttons"),
            label: Translation.tr("Dark mode toggle"),
            description: Translation.tr("Show dark/light mode toggle in bar"),
            keywords: ["dark", "mode", "light", "toggle", "bar", "theme"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Workspaces"),
            description: Translation.tr("Workspace indicator count, numbers and icons"),
            keywords: ["workspace", "numbers", "icons", "delays", "scroll", "indicator"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("App icons in workspaces"),
            description: Translation.tr("Show app icons inside workspace indicators"),
            keywords: ["workspace", "app", "icons", "show", "indicator"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Monochrome workspace icons"),
            description: Translation.tr("Tint workspace app icons to match theme"),
            keywords: ["workspace", "monochrome", "icons", "tint", "theme"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Scroll behavior"),
            description: Translation.tr("Workspace or column scroll behavior"),
            keywords: ["workspace", "scroll", "column", "behavior", "mouse", "touchpad"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Modules"),
            label: Translation.tr("Bar weather"),
            description: Translation.tr("Show weather in the bar"),
            keywords: ["weather", "bar", "temperature", "enable"]
        },
        {
            pageIndex: 2, pageName: root.pages[2].name,
            section: Translation.tr("Bar module layout"),
            label: Translation.tr("Bar module layout"),
            description: Translation.tr("Reorder and toggle bar modules"),
            keywords: ["bar", "module", "layout", "order", "reorder", "resources", "media", "clock"]
        },

        // =====================================================================
        // Background (page 3) — per-option entries
        // =====================================================================
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Parallax"),
            label: Translation.tr("Parallax"),
            description: Translation.tr("Background parallax based on workspace and sidebar"),
            keywords: ["parallax", "background", "zoom", "workspace", "sidebar"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Parallax"),
            label: Translation.tr("Workspace parallax"),
            description: Translation.tr("Shift background when switching workspaces"),
            keywords: ["parallax", "workspace", "shift", "scroll", "zoom"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Wallpaper effects"),
            label: Translation.tr("Wallpaper effects"),
            description: Translation.tr("Wallpaper blur and dim overlay"),
            keywords: ["blur", "dim", "wallpaper", "effects", "overlay"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Wallpaper effects"),
            label: Translation.tr("Wallpaper blur"),
            description: Translation.tr("Blur the wallpaper when windows are open"),
            keywords: ["blur", "wallpaper", "background", "radius", "gaussian"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Wallpaper effects"),
            label: Translation.tr("Wallpaper dim"),
            description: Translation.tr("Darken wallpaper overlay"),
            keywords: ["dim", "wallpaper", "darken", "overlay", "opacity"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Wallpaper effects"),
            label: Translation.tr("Dynamic dim"),
            description: Translation.tr("Extra dim when windows are present on workspace"),
            keywords: ["dynamic", "dim", "windows", "workspace", "darken"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Fullscreen behavior"),
            label: Translation.tr("Hide main wallpaper in fullscreen"),
            description: Translation.tr("Reduce background rendering while keeping the overview backdrop available"),
            keywords: ["fullscreen", "wallpaper", "background", "gaming", "performance", "overview", "backdrop", "hide"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Multi-monitor"),
            label: Translation.tr("Backdrop"),
            description: Translation.tr("Panel backdrop wallpaper and effects"),
            keywords: ["backdrop", "panel", "wallpaper", "blur", "vignette", "saturation"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Multi-monitor"),
            label: Translation.tr("Show entire backdrop"),
            description: Translation.tr("Fit the full backdrop without cropping"),
            keywords: ["backdrop", "wallpaper", "fit", "full", "entire", "crop", "zoom", "bars"]
        },
        {
            pageIndex: 3, pageName: root.pages[3].name,
            section: Translation.tr("Multi-monitor"),
            label: Translation.tr("Backdrop vignette"),
            description: Translation.tr("Vignette darkening effect on backdrop"),
            keywords: ["backdrop", "vignette", "darken", "edges", "effect"]
        },

        // =====================================================================
        // Themes (page 4) — per-option entries
        // =====================================================================
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Global Style"),
            description: Translation.tr("Material, Cards, Aurora glass effect, Inir TUI style"),
            keywords: ["global", "style", "aurora", "inir", "material", "cards", "glass", "tui", "transparency", "blur"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Aurora"),
            description: Translation.tr("Glass effect with wallpaper blur behind panels"),
            keywords: ["aurora", "glass", "blur", "transparency", "style", "translucent"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Regalia"),
            description: Translation.tr("Luxury layered surfaces with optional wallpaper glass"),
            keywords: ["regalia", "glass", "blur", "luxury", "layered", "surface", "rounding"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Inir"),
            description: Translation.tr("TUI-inspired style with accent borders"),
            keywords: ["inir", "tui", "terminal", "borders", "style", "minimal"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Material"),
            description: Translation.tr("Material Design solid backgrounds"),
            keywords: ["material", "solid", "style", "default", "google"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Cards"),
            description: Translation.tr("Card-style elevated containers"),
            keywords: ["cards", "card", "style", "elevated", "shadow"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Color Themes"),
            label: Translation.tr("Theme Presets"),
            description: Translation.tr("Predefined color themes like Gruvbox, Catppuccin, Nord, Dracula"),
            keywords: ["theme", "preset", "gruvbox", "catppuccin", "nord", "dracula", "material", "colors", "palette",
                       "monokai", "solarized", "tokyo", "night", "everforest", "rose", "pine"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Color Themes"),
            label: Translation.tr("Auto Theme"),
            description: Translation.tr("Automatic colors from wallpaper"),
            keywords: ["auto", "wallpaper", "dynamic", "colors", "material you", "generate"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Custom Theme Editor"),
            label: Translation.tr("Custom Theme Editor"),
            description: Translation.tr("Create and edit custom color themes"),
            keywords: ["custom", "theme", "editor", "color", "create", "edit", "picker"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Typography"),
            label: Translation.tr("Font settings"),
            description: Translation.tr("Main font, title font, monospace font and size"),
            keywords: ["font", "typography", "size", "family", "main", "title", "monospace", "scale"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Typography"),
            label: Translation.tr("Font sync"),
            description: Translation.tr("Sync fonts with GTK/KDE system apps"),
            keywords: ["font", "sync", "gtk", "kde", "system", "apps"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Icon Theme"),
            label: Translation.tr("Icon theme"),
            description: Translation.tr("System icon theme for tray and apps"),
            keywords: ["icon", "theme", "tray", "system", "apps", "gtk"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Icon Theme"),
            label: Translation.tr("Dock icon theme"),
            description: Translation.tr("Separate icon theme for the dock"),
            keywords: ["dock", "icon", "theme", "separate", "override"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Terminal Colors"),
            label: Translation.tr("Terminal theming"),
            description: Translation.tr("Apply wallpaper colors to terminal emulators"),
            keywords: ["terminal", "theme", "kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "colors"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Wallpaper & Colors"),
            label: Translation.tr("Transparency"),
            description: Translation.tr("Panel and content transparency"),
            keywords: ["transparency", "opacity", "translucent", "see-through", "glass"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Bar & screen"),
            label: Translation.tr("Fake screen rounding"),
            description: Translation.tr("Rounded corners for the screen edges"),
            keywords: ["screen", "rounding", "corners", "fake", "round", "edges"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Theme Scheduling"),
            label: Translation.tr("Theme schedule"),
            description: Translation.tr("Automatically switch themes at day/night times"),
            keywords: ["theme", "schedule", "day", "night", "auto", "switch", "time"]
        },

        // =====================================================================
        // Interface (page 5) — per-option entries
        // =====================================================================
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Display scaling"),
            label: Translation.tr("UI scale (%)"),
            description: Translation.tr("Scale the entire shell UI for HiDPI / 4K monitors"),
            keywords: ["scale", "dpi", "hidpi", "4k", "zoom", "size", "display", "monitor", "resolution"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Crosshair overlay"),
            label: Translation.tr("Crosshair overlay"),
            description: Translation.tr("In-game crosshair overlay"),
            keywords: ["crosshair", "overlay", "aim", "game", "fps"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Visual Effects"),
            label: Translation.tr("Overlay"),
            description: Translation.tr("Fullscreen overlay effects and animations"),
            keywords: ["overlay", "darken", "scrim", "zoom", "animation", "opacity"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Visual Effects"),
            label: Translation.tr("Overlay opacity"),
            description: Translation.tr("Background opacity of overlay panels"),
            keywords: ["overlay", "opacity", "background", "transparent", "panel"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Alt-Tab switcher (Material ii)"),
            label: Translation.tr("Alt+Tab Switcher"),
            description: Translation.tr("Window switcher preset and behavior"),
            keywords: ["alt", "tab", "switcher", "window", "preset", "default", "list", "compact"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Alt-Tab switcher (Material ii)"),
            label: Translation.tr("Alt+Tab preset"),
            description: Translation.tr("Switcher style: default sidebar or centered list"),
            keywords: ["alt", "tab", "preset", "style", "sidebar", "list", "compact"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock"),
            description: Translation.tr("Dock position and behaviour"),
            keywords: ["dock", "position", "pinned", "hover", "reveal", "desktop", "show"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock enable"),
            description: Translation.tr("Enable or disable the dock"),
            keywords: ["dock", "enable", "disable", "show", "hide"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock position"),
            description: Translation.tr("Dock position: top, bottom, left, right"),
            keywords: ["dock", "position", "top", "bottom", "left", "right"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Pinned apps"),
            description: Translation.tr("Apps pinned to the dock"),
            keywords: ["dock", "pinned", "apps", "pin", "favorite"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Show on desktop"),
            description: Translation.tr("Show dock when no window is focused"),
            keywords: ["dock", "desktop", "show", "focus", "window", "empty"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Window preview"),
            description: Translation.tr("Show window preview on hover"),
            keywords: ["dock", "preview", "hover", "window", "thumbnail"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock icon size"),
            description: Translation.tr("Size of dock icons"),
            keywords: ["dock", "icon", "size", "height"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Monochrome dock icons"),
            description: Translation.tr("Tint dock icons to match theme"),
            keywords: ["dock", "monochrome", "icons", "tint", "theme"]
        },
        {
            pageIndex: 22, pageName: root.pages[22].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Smart indicator"),
            description: Translation.tr("Show which window is focused in the dock"),
            keywords: ["dock", "smart", "indicator", "focused", "window", "dots"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Lock screen"),
            description: Translation.tr("Lock screen behaviour and style"),
            keywords: ["lock", "screen", "hyprlock", "blur", "password", "security"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Lock screen blur"),
            description: Translation.tr("Blur effect on the lock screen wallpaper"),
            keywords: ["lock", "blur", "radius", "zoom", "wallpaper"]
        },
        {
            pageIndex: 1, pageName: root.pages[1].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Keyring unlock"),
            description: Translation.tr("Unlock keyring when unlocking the screen"),
            keywords: ["lock", "keyring", "unlock", "security", "password", "gnome"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notifications"),
            description: Translation.tr("Notification timeouts and popup position"),
            keywords: ["notifications", "timeout", "popup", "position"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification timeout"),
            description: Translation.tr("Duration before notification auto-closes"),
            keywords: ["notification", "timeout", "duration", "auto", "close", "dismiss"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification position"),
            description: Translation.tr("Where popup notifications appear on screen"),
            keywords: ["notification", "position", "popup", "corner", "top", "bottom", "left", "right"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Do Not Disturb"),
            description: Translation.tr("Silence all notifications"),
            keywords: ["notification", "dnd", "silent", "mute", "disturb", "quiet", "do not"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification badge sync"),
            description: Translation.tr("Auto-sync badge count with popup list"),
            keywords: ["notification", "badge", "sync", "count", "unread", "legacy"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Edge margin"),
            description: Translation.tr("Spacing between notifications and screen edge"),
            keywords: ["notification", "margin", "edge", "spacing", "gap"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Region selector (screen snipping/Google Lens)"),
            label: Translation.tr("Region selector"),
            description: Translation.tr("Screen snipping target regions and Lens behaviour"),
            keywords: ["region", "selector", "snip", "lens", "screenshot", "google"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Sidebars"),
            description: Translation.tr("Sidebar toggles, sliders and corner open"),
            keywords: ["sidebar", "quick", "toggles", "sliders", "corner"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Arrange sidebar sections"),
            description: Translation.tr("Reorder right sidebar sections and balance notifications against widgets"),
            keywords: ["sidebar", "right", "arrange", "order", "sections", "notifications", "widgets", "resize", "height"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Arrange sidebar tabs"),
            description: Translation.tr("Reorder the tabs shown in the left sidebar"),
            keywords: ["sidebar", "left", "arrange", "order", "tabs", "drag", "widgets", "ai"]
        },
        {
            pageIndex: 21, pageName: root.pages[21].name,
            section: Translation.tr("Island surfaces"),
            label: Translation.tr("Island body & glass"),
            description: Translation.tr("Shared body opacity, glass background, blur, radius, shadow and top edge for Ricelin surfaces"),
            keywords: ["island", "pill", "radius", "opacity", "shadow", "sheen", "card", "gradient", "ricelin", "skin", "glass", "blur", "transparency"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Sidebar style"),
            description: Translation.tr("Panel or island (gradient card) sidebar surface"),
            keywords: ["sidebar", "style", "island", "panel", "card", "gradient", "ricelin"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Collapse notifications when empty"),
            description: Translation.tr("Shrink the right sidebar when there are no notifications"),
            keywords: ["sidebar", "notifications", "collapse", "empty", "compact", "shrink"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Fit left sidebar to widgets"),
            description: Translation.tr("Shrink the left sidebar to its content on the Widgets tab instead of full height"),
            keywords: ["sidebar", "left", "widgets", "fit", "collapse", "compact", "shrink", "height"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Region selector (screen snipping/Google Lens)"),
            label: Translation.tr("Remember last snip choice"),
            description: Translation.tr("Reopen the unified snip menu with the last action and shape picked in its toolbar"),
            keywords: ["screenshot", "snip", "remember", "region", "rectangle", "default", "action", "shape"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search surface style"),
            description: Translation.tr("Default or island (gradient card) search surface"),
            keywords: ["search", "style", "island", "card", "gradient", "launcher", "apps", "ricelin"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Corner open"),
            description: Translation.tr("Open sidebar by hovering screen corners"),
            keywords: ["sidebar", "corner", "open", "hover", "edge", "clickless"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Quick toggles style"),
            description: Translation.tr("Classic or Android-style quick toggles"),
            keywords: ["sidebar", "quick", "toggles", "style", "android", "classic"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Right sidebar header"),
            description: Translation.tr("Profile card with avatar and banner, or the classic uptime row"),
            keywords: ["sidebar", "header", "profile", "avatar", "uptime", "user", "distro", "classic"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Header banner"),
            description: Translation.tr("Live wallpaper, custom media, a solid plate, or no banner at all"),
            keywords: ["sidebar", "header", "banner", "wallpaper", "video", "gif", "image", "solid", "custom", "picture"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Keep sidebars loaded"),
            description: Translation.tr("Keep sidebar content in memory for faster opening"),
            keywords: ["sidebar", "loaded", "memory", "keep", "preload", "fast"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("YT Music Up Next notifications"),
            description: Translation.tr("Enable or disable next-track notifications for YT Music auto-advance"),
            keywords: ["ytmusic", "youtube", "music", "up next", "notification", "auto", "advance"]
        },
        {
            pageIndex: 23, pageName: root.pages[23].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("YT Music fullscreen suppression"),
            description: Translation.tr("Mute YT Music Up Next notifications during fullscreen apps or GameMode"),
            keywords: ["ytmusic", "fullscreen", "gamemode", "mute", "suppress", "notification", "gaming"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("On-screen display"),
            label: Translation.tr("OSD timeout"),
            description: Translation.tr("How long the volume, brightness and media OSD stays visible"),
            keywords: ["osd", "volume", "brightness", "media", "timeout", "duration"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("On-screen display"),
            label: Translation.tr("Media OSD"),
            description: Translation.tr("Control explicit media feedback and Pill track announcements; automatic changes stay hidden during games"),
            keywords: ["osd", "media", "music", "player", "shortcuts", "pill", "track", "fullscreen", "game", "automatic", "skip"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Overview"),
            description: Translation.tr("Overview scale, rows and columns"),
            keywords: ["overview", "grid", "rows", "columns", "scale"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Overview scale"),
            description: Translation.tr("Size of workspace thumbnails in overview"),
            keywords: ["overview", "scale", "size", "workspace", "thumbnail"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Window previews in overview"),
            description: Translation.tr("Show window thumbnails in overview"),
            keywords: ["overview", "preview", "window", "thumbnail"]
        },
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Wallpaper selector"),
            label: Translation.tr("Wallpaper selector"),
            description: Translation.tr("Wallpaper picker behaviour"),
            keywords: ["wallpaper", "selector", "file", "dialog", "picker"]
        },

        // =====================================================================
        // Tools (page 6)
        // =====================================================================
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Screen recording"),
            label: Translation.tr("Screen recording"),
            description: Translation.tr("Screen recording settings and shortcuts"),
            keywords: ["screen", "record", "recording", "video", "capture", "wf-recorder", "audio", "system sound", "desktop audio", "microphone", "mic", "mix", "pipewire", "discord", "compress", "10mb"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Screen recording"),
            label: Translation.tr("Recording folder"),
            description: Translation.tr("Choose where screen recordings are saved"),
            keywords: ["recording", "video", "save", "path", "folder", "directory", "destination"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Region selector (screen snipping/Google Lens)"),
            label: Translation.tr("Region selector"),
            description: Translation.tr("Screenshot region selector tool"),
            keywords: ["region", "selector", "screenshot", "snip", "area", "capture"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Region selector (screen snipping/Google Lens)"),
            label: Translation.tr("Screenshots folder"),
            description: Translation.tr("Choose where iNiR screenshots are saved"),
            keywords: ["screenshot", "snip", "capture", "save", "path", "folder", "directory", "destination"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Crosshair overlay"),
            label: Translation.tr("Crosshair overlay"),
            description: Translation.tr("Screen crosshair overlay for aiming"),
            keywords: ["crosshair", "overlay", "aim", "center", "screen"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("Overlay: Discord"),
            label: Translation.tr("Discord overlay"),
            description: Translation.tr("Discord rich presence overlay widget"),
            keywords: ["discord", "overlay", "rich", "presence", "widget"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Floating tools (Super+G)"),
            label: Translation.tr("Floating tools (Super+G)"),
            description: Translation.tr("Floating image and widgets panel (Super+G)"),
            keywords: ["super+g", "super g", "overlay", "floating", "tools", "widgets", "desktop", "notes", "image", "crosshair", "mixer", "resources", "fps", "recorder"]
        },
        {
            pageIndex: 6, pageName: root.pages[6].name,
            section: Translation.tr("On-screen display"),
            label: Translation.tr("On-screen display"),
            description: Translation.tr("Volume and brightness OSD settings"),
            keywords: ["osd", "on", "screen", "display", "volume", "brightness"]
        },

        // =====================================================================
        // Services (page 7) — per-option entries
        // =====================================================================
        {
            pageIndex: 24, pageName: root.pages[24].name,
            section: Translation.tr("Get started"),
            label: Translation.tr("AI"),
            description: Translation.tr("Providers, models, behavior and voice input for the assistant"),
            keywords: ["ai", "assistant", "chat", "llm", "sidebar", "gemini", "ollama", "openai", "claude", "mistral"]
        },
        {
            pageIndex: 24, pageName: root.pages[24].name,
            section: Translation.tr("Assistant behavior"),
            label: Translation.tr("AI system prompt"),
            description: Translation.tr("Custom instructions for the AI assistant"),
            keywords: ["ai", "prompt", "system", "instructions", "custom", "assistant", "personality"]
        },
        {
            pageIndex: 24, pageName: root.pages[24].name,
            section: Translation.tr("Providers & models"),
            label: Translation.tr("AI providers"),
            description: Translation.tr("Add Ollama, OpenRouter, Gemini, Groq or any compatible endpoint"),
            keywords: ["ai", "provider", "model", "api", "key", "endpoint", "ollama", "openrouter", "gemini", "groq", "local", "add"]
        },
        {
            pageIndex: 24, pageName: root.pages[24].name,
            section: Translation.tr("Assistant behavior"),
            label: Translation.tr("AI tools & temperature"),
            description: Translation.tr("Default tool mode (functions, search) and creativity"),
            keywords: ["ai", "tool", "functions", "search", "temperature", "creativity"]
        },
        {
            pageIndex: 24, pageName: root.pages[24].name,
            section: Translation.tr("Voice input"),
            label: Translation.tr("Voice input"),
            description: Translation.tr("Dictate messages to the assistant and voice search duration"),
            keywords: ["voice", "mic", "microphone", "dictate", "speech", "transcribe", "recording"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Music Recognition"),
            label: Translation.tr("Music Recognition"),
            description: Translation.tr("Song recognition timeout and interval"),
            keywords: ["music", "recognition", "song", "timeout", "shazam", "songrec"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Networking"),
            label: Translation.tr("User agent"),
            description: Translation.tr("Custom user agent string for web requests"),
            keywords: ["network", "user", "agent", "http", "web", "request"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Resources"),
            label: Translation.tr("Resource monitor interval"),
            description: Translation.tr("Polling interval for CPU/RAM/disk monitor"),
            keywords: ["resources", "cpu", "memory", "ram", "disk", "interval", "poll", "monitor"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search"),
            description: Translation.tr("Search engine, prefix configuration"),
            keywords: ["search", "prefix", "engine", "web", "google", "app", "launcher"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search engine"),
            description: Translation.tr("Default search engine URL"),
            keywords: ["search", "engine", "url", "google", "duckduckgo", "web"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search prefixes"),
            description: Translation.tr("Type shortcuts: / for actions, > for apps, = for math"),
            keywords: ["search", "prefix", "shortcut", "action", "app", "math", "emoji", "clipboard"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Weather"),
            label: Translation.tr("Weather"),
            description: Translation.tr("Weather units, GPS and city"),
            keywords: ["weather", "gps", "city", "fahrenheit", "celsius", "temperature", "units"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Idle & Sleep"),
            label: Translation.tr("Idle & Power"),
            description: Translation.tr("Screen off, lock and suspend timeouts"),
            keywords: ["idle", "power", "screen", "off", "lock", "suspend", "sleep", "timeout"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Idle & Sleep"),
            label: Translation.tr("Screen off timeout"),
            description: Translation.tr("Time before screen turns off"),
            keywords: ["screen", "off", "timeout", "idle", "dpms", "blank"]
        },
        {
            pageIndex: 7, pageName: root.pages[7].name,
            section: Translation.tr("Idle & Sleep"),
            label: Translation.tr("Lock timeout"),
            description: Translation.tr("Time before screen locks"),
            keywords: ["lock", "timeout", "idle", "auto", "security"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Visual Effects"),
            label: Translation.tr("Night light"),
            description: Translation.tr("Blue light filter / color temperature"),
            keywords: ["night", "light", "blue", "filter", "color", "temperature", "warm", "redshift"]
        },
        {
            pageIndex: 5, pageName: root.pages[5].name,
            section: Translation.tr("Visual Effects"),
            label: Translation.tr("Night light schedule"),
            description: Translation.tr("Automatic night light based on time"),
            keywords: ["night", "light", "schedule", "auto", "time", "sunset", "sunrise"]
        },
        {
            pageIndex: 0, pageName: root.pages[0].name,
            section: Translation.tr("Game Mode"),
            label: Translation.tr("GameMode"),
            description: Translation.tr("Auto-detect fullscreen games and reduce effects"),
            keywords: ["game", "mode", "fullscreen", "performance", "fps", "auto", "detect", "animations", "effects"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Applications"),
            label: Translation.tr("Default applications"),
            description: Translation.tr("Terminal, file manager, browser commands"),
            keywords: ["apps", "applications", "terminal", "browser", "file", "manager", "discord", "default"]
        },

        // =====================================================================
        // Advanced (page 8)
        // =====================================================================
        {
            pageIndex: 8, pageName: root.pages[8].name,
            section: Translation.tr("Color generation"),
            label: Translation.tr("Color generation"),
            description: Translation.tr("Wallpaper-based color theming and palette type"),
            keywords: ["color", "generation", "theming", "wallpaper", "material you", "palette"]
        },
        {
            pageIndex: 8, pageName: root.pages[8].name,
            section: Translation.tr("Color generation"),
            label: Translation.tr("Palette type"),
            description: Translation.tr("Material You palette algorithm variant"),
            keywords: ["palette", "type", "scheme", "content", "expressive", "fidelity", "tonal", "spot", "monochrome"]
        },
        {
            pageIndex: 8, pageName: root.pages[8].name,
            section: Translation.tr("Cava options"),
            label: Translation.tr("Cava color source and response"),
            description: Translation.tr("Theme, vibrant or album-art palettes for internal visualizers and standalone cava"),
            keywords: ["cava", "visualizer", "spectrum", "audio", "palette", "vibrant", "saturated", "album", "cover", "sensitivity", "bars", "framerate", "stereo", "wave", "opacity", "reset"]
        },
        {
            pageIndex: 4, pageName: root.pages[4].name,
            section: Translation.tr("Terminal Colors"),
            label: Translation.tr("Terminal color adjustments"),
            description: Translation.tr("Fine-tune terminal theme colors"),
            keywords: ["terminal", "color", "saturation", "brightness", "harmony", "adjustment"]
        },
        {
            pageIndex: 25, pageName: root.pages[25].name,
            section: Translation.tr("Motion and power"),
            label: Translation.tr("Low power mode"),
            description: Translation.tr("Reduce resource usage for low-end hardware"),
            keywords: ["performance", "low", "power", "mode", "reduce", "battery", "laptop"]
        },
        {
            pageIndex: 25, pageName: root.pages[25].name,
            section: Translation.tr("Motion and power"),
            label: Translation.tr("Notify when a restart would free memory"),
            description: Translation.tr("Warn when accumulated JS heap makes a shell restart worthwhile"),
            keywords: ["performance", "memory", "leak", "notification", "warning", "restart", "watchdog"]
        },
        {
            pageIndex: 25, pageName: root.pages[25].name,
            section: Translation.tr("Blur and glass"),
            label: Translation.tr("Allow compositor blur"),
            description: Translation.tr("Allow exact shaped blur regions on supported Niri surfaces"),
            keywords: ["performance", "native", "blur", "niri", "gpu", "compositor", "glass"]
        },
        {
            pageIndex: 8, pageName: root.pages[8].name,
            section: Translation.tr("Color generation"),
            label: Translation.tr("Scrolling"),
            description: Translation.tr("Touchpad and mouse scroll speed"),
            keywords: ["scroll", "touchpad", "mouse", "speed", "fast", "slow", "sensitivity"]
        },

        // =====================================================================
        // Shortcuts (page 9)
        // =====================================================================
        {
            pageIndex: 9, pageName: root.pages[9].name,
            section: Translation.tr("Add keybind"),
            label: Translation.tr("Keyboard Shortcuts"),
            description: Translation.tr("Niri and ii keybindings reference"),
            keywords: ["shortcuts", "keybindings", "hotkeys", "keyboard", "cheatsheet",
                       "terminal", "clipboard", "volume", "brightness", "screenshot", "lock",
                       "workspace", "window", "focus", "move", "fullscreen", "floating",
                       "overview", "settings", "wallpaper", "media", "play", "pause"]
        },

        // =====================================================================
        // Modules (page 10)
        // =====================================================================
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Shell Modules"),
            label: Translation.tr("Panel Modules"),
            description: Translation.tr("Enable or disable shell modules"),
            keywords: ["modules", "panels", "enable", "disable", "bar", "sidebar", "overview"]
        },
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Shell Modules"),
            label: Translation.tr("Enable notification popups"),
            description: Translation.tr("Toggle notification toast popups"),
            keywords: ["module", "notification", "popup", "toast", "enable", "disable"]
        },
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Shell Modules"),
            label: Translation.tr("Enable dock"),
            description: Translation.tr("Toggle dock panel"),
            keywords: ["module", "dock", "enable", "disable", "panel"]
        },
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Shell Modules"),
            label: Translation.tr("Enable overview"),
            description: Translation.tr("Toggle workspace overview"),
            keywords: ["module", "overview", "enable", "disable", "workspace"]
        },
        {
            pageIndex: 10, pageName: root.pages[10].name,
            section: Translation.tr("Shell Modules"),
            label: Translation.tr("Enable sidebars"),
            description: Translation.tr("Toggle left and right sidebars"),
            keywords: ["module", "sidebar", "left", "right", "enable", "disable"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Alt+Tab Switcher"),
            label: Translation.tr("Alt+Tab Switcher"),
            description: Translation.tr("Window switcher style and behavior"),
            keywords: ["alt", "tab", "switcher", "windows", "thumbnails"]
        },

        // =====================================================================
        // Waffle Style (page 11)
        // =====================================================================
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Taskbar"),
            label: Translation.tr("Waffle Taskbar"),
            description: Translation.tr("Windows 11 style taskbar settings"),
            keywords: ["waffle", "taskbar", "windows", "bottom", "tray"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Start Menu"),
            label: Translation.tr("Waffle Start Menu"),
            description: Translation.tr("Start menu size and behavior"),
            keywords: ["waffle", "start", "menu", "apps", "pinned"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Widgets Panel"),
            label: Translation.tr("Waffle Action Center"),
            description: Translation.tr("Quick toggles and action center"),
            keywords: ["waffle", "action", "center", "toggles", "quick"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Widgets Panel"),
            label: Translation.tr("Waffle Widgets"),
            description: Translation.tr("Widgets panel settings"),
            keywords: ["waffle", "widgets", "panel", "weather", "calendar"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Alt+Tab Switcher"),
            label: Translation.tr("Waffle Alt+Tab"),
            description: Translation.tr("Waffle window switcher with thumbnails"),
            keywords: ["waffle", "alt", "tab", "switcher", "thumbnails", "carousel"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Wallpaper"),
            label: Translation.tr("Waffle Background"),
            description: Translation.tr("Waffle-specific wallpaper and backdrop settings"),
            keywords: ["waffle", "background", "wallpaper", "backdrop", "effects"]
        },
        {
            pageIndex: 11, pageName: root.pages[11].name,
            section: Translation.tr("Wallpaper"),
            label: Translation.tr("Hide main wallpaper in fullscreen"),
            description: Translation.tr("Hide the Waffle wallpaper while keeping the Task View backdrop available"),
            keywords: ["waffle", "fullscreen", "wallpaper", "background", "gaming", "performance", "task view", "backdrop", "hide"]
        },

        // =====================================================================
        // Compositor (page 12)
        // =====================================================================
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Displays"),
            label: Translation.tr("Displays"),
            description: Translation.tr("Monitor configuration and display outputs"),
            keywords: ["display", "monitor", "output", "screen", "resolution", "refresh", "rate"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Keyboard"),
            label: Translation.tr("Keyboard"),
            description: Translation.tr("Keyboard layout and repeat settings"),
            keywords: ["keyboard", "layout", "repeat", "delay", "rate", "xkb", "input"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Touchpad"),
            label: Translation.tr("Touchpad"),
            description: Translation.tr("Touchpad gestures, tap and scroll"),
            keywords: ["touchpad", "tap", "scroll", "gesture", "natural", "click", "input"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Mouse"),
            label: Translation.tr("Mouse"),
            description: Translation.tr("Mouse acceleration and speed"),
            keywords: ["mouse", "acceleration", "speed", "pointer", "input"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Trackpoint"),
            label: Translation.tr("Trackpoint"),
            description: Translation.tr("Trackpoint speed and acceleration"),
            keywords: ["trackpoint", "speed", "acceleration", "thinkpad", "input"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("General Input"),
            label: Translation.tr("General Input"),
            description: Translation.tr("Focus follows mouse, workspace auto-back-and-forth"),
            keywords: ["input", "focus", "mouse", "workspace", "auto", "back", "forth"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Cursor"),
            label: Translation.tr("Cursor"),
            description: Translation.tr("Cursor theme, size, and hide on typing"),
            keywords: ["cursor", "theme", "size", "hide", "typing", "pointer"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Window gaps"),
            description: Translation.tr("Inner and outer gap size between windows"),
            keywords: ["gap", "gaps", "window", "inner", "outer", "spacing"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Window border"),
            description: Translation.tr("Active and inactive window border width and color"),
            keywords: ["border", "window", "active", "inactive", "color", "width"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Focus ring"),
            description: Translation.tr("Focus ring width and color"),
            keywords: ["focus", "ring", "color", "width", "active", "inactive"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Default column display"),
            description: Translation.tr("Default column width for new windows"),
            keywords: ["column", "display", "width", "default", "layout", "proportion"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Window shadow"),
            description: Translation.tr("Window shadow softness, spread, offset, color"),
            keywords: ["shadow", "window", "softness", "spread", "offset", "color"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Struts"),
            description: Translation.tr("Reserved screen edge space for panels"),
            keywords: ["struts", "edge", "space", "panel", "reserved", "left", "right", "top", "bottom"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Layout"),
            label: Translation.tr("Clip windows"),
            description: Translation.tr("Clip windows to their workspace bounds"),
            keywords: ["clip", "window", "workspace", "bounds", "hotspot"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Animations"),
            label: Translation.tr("Per-animation toggles"),
            description: Translation.tr("Enable or disable individual compositor animations"),
            keywords: ["animation", "toggle", "enable", "disable", "compositor", "transition"]
        },
        {
            pageIndex: 12, pageName: root.pages[12].name,
            section: Translation.tr("Niri config status"),
            label: Translation.tr("Managed overrides status"),
            description: Translation.tr("Actionable managed overrides and extra files in Niri config"),
            keywords: ["niri", "status", "managed", "override", "extra", "config", "kdl"]
        },

        // =====================================================================
        // About (page 13)
        // =====================================================================
        {
            pageIndex: 13, pageName: root.pages[13].name,
            section: Translation.tr("System"),
            label: Translation.tr("About ii"),
            description: Translation.tr("Version info, credits and links"),
            keywords: ["about", "version", "credits", "github", "info"]
        },

        // =====================================================================
        // Desktop Widgets (page 14)
        // =====================================================================
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Edit Mode"), label: Translation.tr("Widget edit mode"), description: Translation.tr("Grid overlay and snap-to-grid for widget placement"), keywords: ["widget", "edit", "grid", "snap", "placement", "drag"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Appearance"), label: Translation.tr("Desktop widgets"), description: Translation.tr("Current iNiR palette"), keywords: ["widget", "color", "colour", "palette", "preset", "primary", "secondary", "tertiary", "signal", "surface", "wallpaper"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Clock"), label: Translation.tr("Desktop clock"), description: Translation.tr("Clock widget on the desktop background"), keywords: ["clock", "widget", "cookie", "digital", "background", "desktop", "wallpaper", "adaptive", "colors"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Clock"), label: Translation.tr("Clock style"), description: Translation.tr("Cookie, digital or Android stacked clock"), keywords: ["clock", "style", "cookie", "digital", "android", "stacked", "analog", "hands"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Japanese Typography"), label: Translation.tr("Japanese typography widget"), description: Translation.tr("Vertical editorial lettering with layout, font, palette, seal, and footer controls"), keywords: ["japanese", "typography", "vertical", "text", "kanji", "kana", "poster", "magazine", "editorial", "seal", "widget", "font", "mincho", "gothic", "color", "palette", "sumi", "outline"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Weather"), label: Translation.tr("Desktop weather widget"), description: Translation.tr("Weather display on the desktop background"), keywords: ["weather", "widget", "background", "temperature"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Custom image"), label: Translation.tr("Custom media gallery"), description: Translation.tr("Show one image, GIF, or video, or rotate a mixed-media folder"), keywords: ["custom", "image", "photo", "static", "gif", "animated", "video", "movie", "gallery", "folder", "slideshow", "interval", "speed", "random", "sequential", "fit", "shape", "widget", "desktop", "drop"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Image converter"), label: Translation.tr("Image converter"), description: Translation.tr("Convert dropped images to PNG, JPG, WEBP, AVIF, BMP, TIFF or PDF"), keywords: ["image", "convert", "converter", "png", "jpg", "webp", "avif", "bmp", "tiff", "pdf", "drop", "desktop", "widget"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("World clock"), label: Translation.tr("World clock"), description: Translation.tr("Local time and four configurable time zones"), keywords: ["world", "clock", "timezone", "city", "desktop", "widget"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("User card"), label: Translation.tr("User card"), description: Translation.tr("Identity, uptime, weather and session actions"), keywords: ["user", "profile", "uptime", "weather", "lock", "settings", "power", "desktop", "widget"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Media Controls"), label: Translation.tr("Desktop media widget"), description: Translation.tr("Media player controls on the desktop background"), keywords: ["media", "widget", "background", "player", "music", "album"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Visualizer"), label: Translation.tr("Audio visualizer"), description: Translation.tr("Audio visualizer widget on the desktop"), keywords: ["visualizer", "audio", "bars", "wave", "music", "equalizer", "spectrum", "cava", "palette", "gradient", "smoothing", "frequency", "bass", "opacity"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("System Monitor"), label: Translation.tr("System monitor widget"), description: Translation.tr("CPU, RAM, GPU usage on the desktop"), keywords: ["system", "monitor", "cpu", "ram", "gpu", "usage", "performance"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Battery"), label: Translation.tr("Desktop battery widget"), description: Translation.tr("Battery status on the desktop background"), keywords: ["battery", "widget", "background", "charge", "power"] },
        { pageIndex: 14, pageName: root.pages[14].name, section: Translation.tr("Custom Widgets"), label: Translation.tr("Custom widgets"), description: Translation.tr("Create, install, and manage custom QML widgets"), keywords: ["custom", "widget", "create", "qml", "install", "user", "plugin"] },

        // =====================================================================
        // Monitors (page 15)
        // =====================================================================
        { pageIndex: 15, pageName: root.pages[15].name, section: Translation.tr("Monitor arrangement"), label: Translation.tr("Arrange monitors"), description: Translation.tr("Drag displays to match their physical position in Niri"), keywords: ["monitor", "display", "output", "arrange", "position", "layout", "drag", "niri"] },
        { pageIndex: 15, pageName: root.pages[15].name, section: Translation.tr("Shell visibility"), label: Translation.tr("Primary monitor"), description: Translation.tr("Choose the default output for shell popups"), keywords: ["monitor", "display", "primary", "screen", "output"] },
        { pageIndex: 15, pageName: root.pages[15].name, section: Translation.tr("Overview placement"), label: Translation.tr("Active screen only"), description: Translation.tr("Open the overview on the monitor where it was invoked"), keywords: ["overview", "monitor", "screen", "focused", "active", "output"] },
        { pageIndex: 15, pageName: root.pages[15].name, section: Translation.tr("Material shell surfaces"), label: Translation.tr("Bar, dock, sidebars, and media controls"), description: Translation.tr("Choose which monitors show Material shell surfaces"), keywords: ["monitor", "visibility", "bar", "dock", "sidebar", "media", "workspace", "secondary"] },
        { pageIndex: 15, pageName: root.pages[15].name, section: Translation.tr("Popups"), label: Translation.tr("Notification popups and OSD indicators"), description: Translation.tr("Choose which monitors show notifications and OSD feedback"), keywords: ["monitor", "visibility", "notifications", "osd", "popups", "secondary", "workspace"] },
        { pageIndex: 15, pageName: root.pages[15].name, section: Translation.tr("Desktop widgets"), label: Translation.tr("Desktop widgets"), description: Translation.tr("Choose widget visibility and layout per monitor"), keywords: ["monitor", "visibility", "desktop", "widgets", "layout", "secondary", "workspace"] },

        // =====================================================================
        // Dashboard (page 16)
        // =====================================================================
        { pageIndex: 16, pageName: root.pages[16].name, section: Translation.tr("General"), label: Translation.tr("Dashboard"), description: Translation.tr("Centered welcome hub panel with configurable widgets"), keywords: ["dashboard", "hub", "welcome", "panel", "home", "greeting"] },
        { pageIndex: 16, pageName: root.pages[16].name, section: Translation.tr("General"), label: Translation.tr("Panel width"), description: Translation.tr("Dashboard width as a percentage of the screen"), keywords: ["dashboard", "width", "size", "ratio", "screen"] },
        { pageIndex: 16, pageName: root.pages[16].name, section: Translation.tr("General"), label: Translation.tr("GitHub username"), description: Translation.tr("GitHub user for the contributions heatmap widget"), keywords: ["dashboard", "github", "contributions", "heatmap", "username", "activity"] },
        { pageIndex: 16, pageName: root.pages[16].name, section: Translation.tr("Widgets"), label: Translation.tr("Dashboard widgets"), description: Translation.tr("Place, hide and reorder dashboard widgets per column"), keywords: ["dashboard", "widgets", "layout", "column", "reorder", "clock", "weather", "media", "todo", "calendar", "notifications", "system"] },

        // =====================================================================
        // Autostart (page 17)
        // =====================================================================
        {
            pageIndex: 17, pageName: root.pages[17].name,
            section: Translation.tr("How autostart works"),
            label: Translation.tr("Autostart"),
            description: Translation.tr("Launch apps when iNiR starts"),
            keywords: ["autostart", "startup", "launch", "apps", "boot", "discord", "steam", "telegram"]
        },

        // =====================================================================
        // Workspace Strip (page 18)
        // =====================================================================
        { pageIndex: 18, pageName: root.pages[18].name, section: Translation.tr("Edge behavior"), label: Translation.tr("Workspace strip"), description: Translation.tr("Hidden edge-hover navigator with workspace previews"), keywords: ["workspace", "strip", "edge", "hover", "navigate", "switch", "thumbnail", "preview"] },
        { pageIndex: 18, pageName: root.pages[18].name, section: Translation.tr("Edge behavior"), label: Translation.tr("Hover timing"), description: Translation.tr("Control edge activation and close delays"), keywords: ["workspace", "strip", "hover", "delay", "open", "close", "trigger"] },
        { pageIndex: 18, pageName: root.pages[18].name, section: Translation.tr("Workspace cards"), label: Translation.tr("Window previews"), description: Translation.tr("Live active preview with cached hidden-workspace snapshots"), keywords: ["workspace", "strip", "preview", "live", "cached", "thumbnail", "window"] },
        { pageIndex: 18, pageName: root.pages[18].name, section: Translation.tr("Workspace cards"), label: Translation.tr("Metadata and app icons"), description: Translation.tr("Show focused-window details and filter workspaces per monitor"), keywords: ["workspace", "strip", "metadata", "icons", "monitor", "per-monitor", "apps"] },

        { pageIndex: 25, pageName: root.pages[25].name, section: Translation.tr("Blur and glass"), label: Translation.tr("Default blur backend"), description: Translation.tr("Let the style choose, use wallpaper glass, compositor blur, or disable blur"), keywords: ["effects", "blur", "backend", "wallpaper", "compositor", "style", "glass"] },
        { pageIndex: 25, pageName: root.pages[25].name, section: Translation.tr("Per-area overrides"), label: Translation.tr("Bars, dock, panels, islands and widgets"), description: Translation.tr("Override the blur backend independently for each shell area"), keywords: ["effects", "area", "bar", "dock", "panel", "island", "ricelin", "widget"] },
        { pageIndex: 25, pageName: root.pages[25].name, section: Translation.tr("Motion and power"), label: Translation.tr("Reduce animations"), description: Translation.tr("Use immediate reduced-motion state changes"), keywords: ["motion", "animation", "reduce", "accessibility", "performance"] }
        ]
        return _staticSearchIndex
    }
}
