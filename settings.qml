//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    property var pages: [
        {
            name: Translation.tr("Quick"),
            icon: "instant_mix",
            component: "modules/settings/QuickConfig.qml"
        },
        {
            name: Translation.tr("General"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            name: Translation.tr("Background"),
            icon: "texture",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            name: Translation.tr("Themes"),
            icon: "palette",
            component: "modules/settings/ThemesConfig.qml"
        },
        {
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            name: Translation.tr("Services"),
            icon: "settings",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            name: Translation.tr("Advanced"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            name: Translation.tr("Shortcuts"),
            icon: "keyboard",
            component: "modules/settings/CheatsheetConfig.qml"
        },
        {
            name: Translation.tr("Modules"),
            icon: "extension",
            component: "modules/settings/ModulesConfig.qml"
        },
        {
            name: Translation.tr("Waffle Style"),
            icon: "window",
            component: "modules/settings/WaffleConfig.qml"
        },
        {
            name: Translation.tr("About"),
            icon: "info",
            component: "modules/settings/About.qml"
        }
    ]
    property int currentPage: 0
    property bool uiReady: Config.ready && ThemeService.ready

    // Global settings search
    property string settingsSearchText: ""
    property var settingsSearchResults: []

    // Spotlight effect for search results
    property var spotlightTarget: null
    property rect spotlightRect: Qt.rect(0, 0, 0, 0)
    property bool spotlightActive: false

    // Índice de secciones y opciones individuales para el buscador.
    // Cada entrada con targetLabel permite spotlight scroll-to en la página destino.
    property var settingsSearchIndex: [
        // =====================================================================
        // Quick (page 0)
        // =====================================================================
        {
            pageIndex: 0, pageName: pages[0].name,
            section: Translation.tr("Wallpaper & Colors"),
            label: Translation.tr("Wallpaper & Colors"),
            description: Translation.tr("Wallpaper, palette and transparency settings"),
            keywords: ["wallpaper", "colors", "palette", "theme", "background"]
        },
        {
            pageIndex: 0, pageName: pages[0].name,
            section: Translation.tr("Bar & screen"),
            label: Translation.tr("Bar & screen"),
            description: Translation.tr("Bar position and screen rounding"),
            keywords: ["bar", "position", "screen", "round", "corner"]
        },

        // =====================================================================
        // General (page 1) — per-option entries
        // =====================================================================
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Audio"),
            description: Translation.tr("Volume protection and limits"),
            keywords: ["audio", "volume", "earbang", "limit", "sound"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Volume protection"),
            description: Translation.tr("Prevent sudden volume spikes"),
            keywords: ["volume", "protection", "earbang", "spike", "loud", "limit", "max"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Max volume increase"),
            description: Translation.tr("Maximum volume jump allowed per step"),
            keywords: ["volume", "increase", "step", "max", "jump"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Battery"),
            description: Translation.tr("Battery warnings and auto suspend thresholds"),
            keywords: ["battery", "low", "critical", "suspend", "full"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Low battery threshold"),
            description: Translation.tr("Percentage to show low battery warning"),
            keywords: ["battery", "low", "warning", "threshold", "percentage"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Critical battery"),
            description: Translation.tr("Percentage for critical battery warning"),
            keywords: ["battery", "critical", "danger", "threshold"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Auto suspend"),
            description: Translation.tr("Automatically suspend on critical battery"),
            keywords: ["battery", "suspend", "sleep", "auto", "critical"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Language"),
            label: Translation.tr("Language"),
            description: Translation.tr("Interface language and AI translations"),
            keywords: ["language", "locale", "translation", "gemini", "idioma", "español", "english"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Language"),
            label: Translation.tr("UI Language"),
            description: Translation.tr("Interface display language"),
            keywords: ["language", "locale", "ui", "display", "idioma", "english", "spanish", "chinese", "japanese", "russian"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Policies"),
            label: Translation.tr("AI Policy"),
            description: Translation.tr("Enable or disable AI features"),
            keywords: ["ai", "policy", "enable", "disable", "local", "privacy"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Policies"),
            label: Translation.tr("Weeb Policy"),
            description: Translation.tr("Anime and manga content visibility"),
            keywords: ["weeb", "anime", "manga", "nsfw", "content", "policy"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Sounds"),
            label: Translation.tr("Sounds"),
            description: Translation.tr("Battery, Pomodoro and notification sounds"),
            keywords: ["sound", "notification", "pomodoro", "battery", "alert", "audio"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Sounds"),
            label: Translation.tr("Notification sound"),
            description: Translation.tr("Play sound when a notification arrives"),
            keywords: ["sound", "notification", "alert", "ring", "chime"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Time"),
            description: Translation.tr("Clock format and seconds"),
            keywords: ["time", "clock", "24h", "12h", "format"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Clock format"),
            description: Translation.tr("Time display format (e.g., hh:mm or h:mm AP)"),
            keywords: ["time", "clock", "format", "24h", "12h", "am", "pm", "hour", "minute"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Show seconds"),
            description: Translation.tr("Update clock every second"),
            keywords: ["time", "seconds", "precision", "clock", "update"]
        },
        {
            pageIndex: 1, pageName: pages[1].name,
            section: Translation.tr("Work Safety"),
            label: Translation.tr("Work Safety"),
            description: Translation.tr("Hide sensitive content on public networks"),
            keywords: ["work", "safety", "nsfw", "public", "network", "hide", "clipboard", "wallpaper"]
        },

        // =====================================================================
        // Bar (page 2) — per-option entries
        // =====================================================================
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Bar position"),
            description: Translation.tr("Bar position, auto hide and style"),
            keywords: ["bar", "position", "auto", "hide", "corner", "style", "top", "bottom", "float", "vertical"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Auto hide"),
            description: Translation.tr("Automatically hide the bar"),
            keywords: ["bar", "auto", "hide", "show", "hover", "reveal"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Corner style"),
            description: Translation.tr("Bar corner style: hug, float, rectangle or card"),
            keywords: ["bar", "corner", "style", "hug", "float", "rectangle", "card", "rounding"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Vertical bar"),
            description: Translation.tr("Use vertical bar layout on the side"),
            keywords: ["bar", "vertical", "side", "left", "orientation"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Bar background"),
            description: Translation.tr("Show or hide bar background"),
            keywords: ["bar", "background", "transparent", "show", "hide"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Blur background"),
            description: Translation.tr("Enable glass blur behind the bar"),
            keywords: ["bar", "blur", "glass", "background", "transparent"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification indicator"),
            description: Translation.tr("Notification unread count in the bar"),
            keywords: ["notifications", "unread", "indicator", "count", "badge", "bar"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Tray"),
            label: Translation.tr("System tray"),
            description: Translation.tr("System tray icons behaviour"),
            keywords: ["tray", "systray", "icons", "pinned", "monochrome"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Tray"),
            label: Translation.tr("Monochrome tray icons"),
            description: Translation.tr("Tint tray icons to match theme"),
            keywords: ["tray", "monochrome", "tint", "icons", "theme", "color"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Utility buttons"),
            label: Translation.tr("Utility buttons"),
            description: Translation.tr("Screen snip, color picker and toggles"),
            keywords: ["screen", "snip", "color", "picker", "mic", "dark", "mode", "performance", "screenshot", "record", "notepad", "keyboard"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Utility buttons"),
            label: Translation.tr("Screen record button"),
            description: Translation.tr("Show screen record button in bar"),
            keywords: ["screen", "record", "button", "bar", "recording", "video"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Utility buttons"),
            label: Translation.tr("Dark mode toggle"),
            description: Translation.tr("Show dark/light mode toggle in bar"),
            keywords: ["dark", "mode", "light", "toggle", "bar", "theme"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Workspaces"),
            description: Translation.tr("Workspace indicator count, numbers and icons"),
            keywords: ["workspace", "numbers", "icons", "delays", "scroll", "indicator"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("App icons in workspaces"),
            description: Translation.tr("Show app icons inside workspace indicators"),
            keywords: ["workspace", "app", "icons", "show", "indicator"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Monochrome workspace icons"),
            description: Translation.tr("Tint workspace app icons to match theme"),
            keywords: ["workspace", "monochrome", "icons", "tint", "theme"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Scroll behavior"),
            description: Translation.tr("Workspace or column scroll behavior"),
            keywords: ["workspace", "scroll", "column", "behavior", "mouse", "touchpad"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Weather"),
            label: Translation.tr("Bar weather"),
            description: Translation.tr("Show weather in the bar"),
            keywords: ["weather", "bar", "temperature", "enable"]
        },
        {
            pageIndex: 2, pageName: pages[2].name,
            section: Translation.tr("Bar modules"),
            label: Translation.tr("Bar module layout"),
            description: Translation.tr("Reorder and toggle bar modules"),
            keywords: ["bar", "module", "layout", "order", "reorder", "resources", "media", "clock"]
        },

        // =====================================================================
        // Background (page 3) — per-option entries
        // =====================================================================
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Parallax"),
            label: Translation.tr("Parallax"),
            description: Translation.tr("Background parallax based on workspace and sidebar"),
            keywords: ["parallax", "background", "zoom", "workspace", "sidebar"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Parallax"),
            label: Translation.tr("Workspace parallax"),
            description: Translation.tr("Shift background when switching workspaces"),
            keywords: ["parallax", "workspace", "shift", "scroll", "zoom"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Effects"),
            label: Translation.tr("Wallpaper effects"),
            description: Translation.tr("Wallpaper blur and dim overlay"),
            keywords: ["blur", "dim", "wallpaper", "effects", "overlay"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Effects"),
            label: Translation.tr("Wallpaper blur"),
            description: Translation.tr("Blur the wallpaper when windows are open"),
            keywords: ["blur", "wallpaper", "background", "radius", "gaussian"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Effects"),
            label: Translation.tr("Wallpaper dim"),
            description: Translation.tr("Darken wallpaper overlay"),
            keywords: ["dim", "wallpaper", "darken", "overlay", "opacity"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Effects"),
            label: Translation.tr("Dynamic dim"),
            description: Translation.tr("Extra dim when windows are present on workspace"),
            keywords: ["dynamic", "dim", "windows", "workspace", "darken"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Backdrop"),
            label: Translation.tr("Backdrop"),
            description: Translation.tr("Panel backdrop wallpaper and effects"),
            keywords: ["backdrop", "panel", "wallpaper", "blur", "vignette", "saturation"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Backdrop"),
            label: Translation.tr("Backdrop vignette"),
            description: Translation.tr("Vignette darkening effect on backdrop"),
            keywords: ["backdrop", "vignette", "darken", "edges", "effect"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Widget: Clock"),
            label: Translation.tr("Background clock"),
            description: Translation.tr("Clock widget on the desktop background"),
            keywords: ["clock", "widget", "cookie", "digital", "background", "desktop"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Widget: Clock"),
            label: Translation.tr("Clock style"),
            description: Translation.tr("Cookie (analog) or digital clock"),
            keywords: ["clock", "style", "cookie", "digital", "analog", "hands"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Widget: Weather"),
            label: Translation.tr("Background weather widget"),
            description: Translation.tr("Weather display on the desktop background"),
            keywords: ["weather", "widget", "background", "temperature"]
        },
        {
            pageIndex: 3, pageName: pages[3].name,
            section: Translation.tr("Widget: Media"),
            label: Translation.tr("Background media widget"),
            description: Translation.tr("Media player controls on the desktop background"),
            keywords: ["media", "widget", "background", "player", "music", "album"]
        },

        // =====================================================================
        // Themes (page 4) — per-option entries
        // =====================================================================
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Global Style"),
            description: Translation.tr("Material, Cards, Aurora glass effect, Inir TUI style"),
            keywords: ["global", "style", "aurora", "inir", "material", "cards", "glass", "tui", "transparency", "blur"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Aurora"),
            description: Translation.tr("Glass effect with wallpaper blur behind panels"),
            keywords: ["aurora", "glass", "blur", "transparency", "style", "translucent"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Inir"),
            description: Translation.tr("TUI-inspired style with accent borders"),
            keywords: ["inir", "tui", "terminal", "borders", "style", "minimal"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Material"),
            description: Translation.tr("Material Design solid backgrounds"),
            keywords: ["material", "solid", "style", "default", "google"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Global Style"),
            label: Translation.tr("Cards"),
            description: Translation.tr("Card-style elevated containers"),
            keywords: ["cards", "card", "style", "elevated", "shadow"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Theme Presets"),
            label: Translation.tr("Theme Presets"),
            description: Translation.tr("Predefined color themes like Gruvbox, Catppuccin, Nord, Dracula"),
            keywords: ["theme", "preset", "gruvbox", "catppuccin", "nord", "dracula", "material", "colors", "palette",
                       "monokai", "solarized", "tokyo", "night", "everforest", "rose", "pine"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Auto Theme"),
            label: Translation.tr("Auto Theme"),
            description: Translation.tr("Automatic colors from wallpaper"),
            keywords: ["auto", "wallpaper", "dynamic", "colors", "matugen", "generate"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Custom Theme"),
            label: Translation.tr("Custom Theme Editor"),
            description: Translation.tr("Create and edit custom color themes"),
            keywords: ["custom", "theme", "editor", "color", "create", "edit", "picker"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Typography"),
            label: Translation.tr("Font settings"),
            description: Translation.tr("Main font, title font, monospace font and size"),
            keywords: ["font", "typography", "size", "family", "main", "title", "monospace", "scale"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Typography"),
            label: Translation.tr("Font sync"),
            description: Translation.tr("Sync fonts with GTK/KDE system apps"),
            keywords: ["font", "sync", "gtk", "kde", "system", "apps"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Icons"),
            label: Translation.tr("Icon theme"),
            description: Translation.tr("System icon theme for tray and apps"),
            keywords: ["icon", "theme", "tray", "system", "apps", "gtk"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Icons"),
            label: Translation.tr("Dock icon theme"),
            description: Translation.tr("Separate icon theme for the dock"),
            keywords: ["dock", "icon", "theme", "separate", "override"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Terminal Theming"),
            label: Translation.tr("Terminal theming"),
            description: Translation.tr("Apply wallpaper colors to terminal emulators"),
            keywords: ["terminal", "theme", "kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "colors"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Transparency"),
            label: Translation.tr("Transparency"),
            description: Translation.tr("Panel and content transparency"),
            keywords: ["transparency", "opacity", "translucent", "see-through", "glass"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Screen Rounding"),
            label: Translation.tr("Fake screen rounding"),
            description: Translation.tr("Rounded corners for the screen edges"),
            keywords: ["screen", "rounding", "corners", "fake", "round", "edges"]
        },
        {
            pageIndex: 4, pageName: pages[4].name,
            section: Translation.tr("Theme Schedule"),
            label: Translation.tr("Theme schedule"),
            description: Translation.tr("Automatically switch themes at day/night times"),
            keywords: ["theme", "schedule", "day", "night", "auto", "switch", "time"]
        },

        // =====================================================================
        // Interface (page 5) — per-option entries
        // =====================================================================
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Crosshair overlay"),
            label: Translation.tr("Crosshair overlay"),
            description: Translation.tr("In-game crosshair overlay"),
            keywords: ["crosshair", "overlay", "aim", "game", "fps"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Overlay"),
            label: Translation.tr("Overlay"),
            description: Translation.tr("Fullscreen overlay effects and animations"),
            keywords: ["overlay", "darken", "scrim", "zoom", "animation", "opacity"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Overlay"),
            label: Translation.tr("Overlay opacity"),
            description: Translation.tr("Background opacity of overlay panels"),
            keywords: ["overlay", "opacity", "background", "transparent", "panel"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Alt+Tab Switcher"),
            label: Translation.tr("Alt+Tab Switcher"),
            description: Translation.tr("Window switcher preset and behavior"),
            keywords: ["alt", "tab", "switcher", "window", "preset", "default", "list", "compact"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Alt+Tab Switcher"),
            label: Translation.tr("Alt+Tab preset"),
            description: Translation.tr("Switcher style: default sidebar or centered list"),
            keywords: ["alt", "tab", "preset", "style", "sidebar", "list", "compact"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock"),
            description: Translation.tr("Dock position and behaviour"),
            keywords: ["dock", "position", "pinned", "hover", "reveal", "desktop", "show"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock enable"),
            description: Translation.tr("Enable or disable the dock"),
            keywords: ["dock", "enable", "disable", "show", "hide"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock position"),
            description: Translation.tr("Dock position: top, bottom, left, right"),
            keywords: ["dock", "position", "top", "bottom", "left", "right"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Pinned apps"),
            description: Translation.tr("Apps pinned to the dock"),
            keywords: ["dock", "pinned", "apps", "pin", "favorite"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Show on desktop"),
            description: Translation.tr("Show dock when no window is focused"),
            keywords: ["dock", "desktop", "show", "focus", "window", "empty"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Window preview"),
            description: Translation.tr("Show window preview on hover"),
            keywords: ["dock", "preview", "hover", "window", "thumbnail"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock icon size"),
            description: Translation.tr("Size of dock icons"),
            keywords: ["dock", "icon", "size", "height"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Monochrome dock icons"),
            description: Translation.tr("Tint dock icons to match theme"),
            keywords: ["dock", "monochrome", "icons", "tint", "theme"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Smart indicator"),
            description: Translation.tr("Show which window is focused in the dock"),
            keywords: ["dock", "smart", "indicator", "focused", "window", "dots"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Lock screen"),
            description: Translation.tr("Lock screen behaviour and style"),
            keywords: ["lock", "screen", "hyprlock", "blur", "password", "security"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Lock screen blur"),
            description: Translation.tr("Blur effect on the lock screen wallpaper"),
            keywords: ["lock", "blur", "radius", "zoom", "wallpaper"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Keyring unlock"),
            description: Translation.tr("Unlock keyring when unlocking the screen"),
            keywords: ["lock", "keyring", "unlock", "security", "password", "gnome"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notifications"),
            description: Translation.tr("Notification timeouts and popup position"),
            keywords: ["notifications", "timeout", "popup", "position"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification timeout"),
            description: Translation.tr("Duration before notification auto-closes"),
            keywords: ["notification", "timeout", "duration", "auto", "close", "dismiss"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification position"),
            description: Translation.tr("Where popup notifications appear on screen"),
            keywords: ["notification", "position", "popup", "corner", "top", "bottom", "left", "right"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Do Not Disturb"),
            description: Translation.tr("Silence all notifications"),
            keywords: ["notification", "dnd", "silent", "mute", "disturb", "quiet", "do not"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notification badge sync"),
            description: Translation.tr("Auto-sync badge count with popup list"),
            keywords: ["notification", "badge", "sync", "count", "unread", "legacy"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Edge margin"),
            description: Translation.tr("Spacing between notifications and screen edge"),
            keywords: ["notification", "margin", "edge", "spacing", "gap"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Region selector (screen snipping/Google Lens)"),
            label: Translation.tr("Region selector"),
            description: Translation.tr("Screen snipping target regions and Lens behaviour"),
            keywords: ["region", "selector", "snip", "lens", "screenshot", "google"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Sidebars"),
            description: Translation.tr("Sidebar toggles, sliders and corner open"),
            keywords: ["sidebar", "quick", "toggles", "sliders", "corner"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Corner open"),
            description: Translation.tr("Open sidebar by hovering screen corners"),
            keywords: ["sidebar", "corner", "open", "hover", "edge", "clickless"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Quick toggles style"),
            description: Translation.tr("Classic or Android-style quick toggles"),
            keywords: ["sidebar", "quick", "toggles", "style", "android", "classic"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Keep sidebars loaded"),
            description: Translation.tr("Keep sidebar content in memory for faster opening"),
            keywords: ["sidebar", "loaded", "memory", "keep", "preload", "fast"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("On-screen display"),
            label: Translation.tr("OSD timeout"),
            description: Translation.tr("How long the volume/brightness OSD stays visible"),
            keywords: ["osd", "volume", "brightness", "timeout", "duration"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Overview"),
            description: Translation.tr("Overview scale, rows and columns"),
            keywords: ["overview", "grid", "rows", "columns", "scale"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Overview scale"),
            description: Translation.tr("Size of workspace thumbnails in overview"),
            keywords: ["overview", "scale", "size", "workspace", "thumbnail"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Window previews in overview"),
            description: Translation.tr("Show window thumbnails in overview"),
            keywords: ["overview", "preview", "window", "thumbnail"]
        },
        {
            pageIndex: 5, pageName: pages[5].name,
            section: Translation.tr("Wallpaper selector"),
            label: Translation.tr("Wallpaper selector"),
            description: Translation.tr("Wallpaper picker behaviour"),
            keywords: ["wallpaper", "selector", "file", "dialog", "picker"]
        },

        // =====================================================================
        // Services (page 6) — per-option entries
        // =====================================================================
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("AI"),
            label: Translation.tr("AI"),
            description: Translation.tr("System prompt for sidebar AI"),
            keywords: ["ai", "prompt", "system", "sidebar", "chat"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("AI"),
            label: Translation.tr("AI system prompt"),
            description: Translation.tr("Custom instructions for the AI assistant"),
            keywords: ["ai", "prompt", "system", "instructions", "custom", "assistant"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Music Recognition"),
            label: Translation.tr("Music Recognition"),
            description: Translation.tr("Song recognition timeout and interval"),
            keywords: ["music", "recognition", "song", "timeout", "shazam", "songrec"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Networking"),
            label: Translation.tr("User agent"),
            description: Translation.tr("Custom user agent string for web requests"),
            keywords: ["network", "user", "agent", "http", "web", "request"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Resources"),
            label: Translation.tr("Resource monitor interval"),
            description: Translation.tr("Polling interval for CPU/RAM/disk monitor"),
            keywords: ["resources", "cpu", "memory", "ram", "disk", "interval", "poll", "monitor"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search"),
            description: Translation.tr("Search engine, prefix configuration"),
            keywords: ["search", "prefix", "engine", "web", "google", "app", "launcher"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search engine"),
            description: Translation.tr("Default search engine URL"),
            keywords: ["search", "engine", "url", "google", "duckduckgo", "web"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search prefixes"),
            description: Translation.tr("Type shortcuts: / for actions, > for apps, = for math"),
            keywords: ["search", "prefix", "shortcut", "action", "app", "math", "emoji", "clipboard"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Weather"),
            label: Translation.tr("Weather"),
            description: Translation.tr("Weather units, GPS and city"),
            keywords: ["weather", "gps", "city", "fahrenheit", "celsius", "temperature", "units"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Idle & Power"),
            label: Translation.tr("Idle & Power"),
            description: Translation.tr("Screen off, lock and suspend timeouts"),
            keywords: ["idle", "power", "screen", "off", "lock", "suspend", "sleep", "timeout"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Idle & Power"),
            label: Translation.tr("Screen off timeout"),
            description: Translation.tr("Time before screen turns off"),
            keywords: ["screen", "off", "timeout", "idle", "dpms", "blank"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Idle & Power"),
            label: Translation.tr("Lock timeout"),
            description: Translation.tr("Time before screen locks"),
            keywords: ["lock", "timeout", "idle", "auto", "security"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Night Light"),
            label: Translation.tr("Night light"),
            description: Translation.tr("Blue light filter / color temperature"),
            keywords: ["night", "light", "blue", "filter", "color", "temperature", "warm", "redshift"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Night Light"),
            label: Translation.tr("Night light schedule"),
            description: Translation.tr("Automatic night light based on time"),
            keywords: ["night", "light", "schedule", "auto", "time", "sunset", "sunrise"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("GameMode"),
            label: Translation.tr("GameMode"),
            description: Translation.tr("Auto-detect fullscreen games and reduce effects"),
            keywords: ["game", "mode", "fullscreen", "performance", "fps", "auto", "detect", "animations", "effects"]
        },
        {
            pageIndex: 6, pageName: pages[6].name,
            section: Translation.tr("Applications"),
            label: Translation.tr("Default applications"),
            description: Translation.tr("Terminal, file manager, browser commands"),
            keywords: ["apps", "applications", "terminal", "browser", "file", "manager", "discord", "default"]
        },

        // =====================================================================
        // Advanced (page 7)
        // =====================================================================
        {
            pageIndex: 7, pageName: pages[7].name,
            section: Translation.tr("Color generation"),
            label: Translation.tr("Color generation"),
            description: Translation.tr("Wallpaper-based color theming and palette type"),
            keywords: ["color", "generation", "theming", "wallpaper", "matugen", "palette"]
        },
        {
            pageIndex: 7, pageName: pages[7].name,
            section: Translation.tr("Color generation"),
            label: Translation.tr("Palette type"),
            description: Translation.tr("Material You palette algorithm variant"),
            keywords: ["palette", "type", "scheme", "content", "expressive", "fidelity", "tonal", "spot", "monochrome"]
        },
        {
            pageIndex: 7, pageName: pages[7].name,
            section: Translation.tr("Terminal Colors"),
            label: Translation.tr("Terminal color adjustments"),
            description: Translation.tr("Fine-tune terminal theme colors"),
            keywords: ["terminal", "color", "saturation", "brightness", "harmony", "adjustment"]
        },
        {
            pageIndex: 7, pageName: pages[7].name,
            section: Translation.tr("Performance"),
            label: Translation.tr("Low power mode"),
            description: Translation.tr("Reduce resource usage for low-end hardware"),
            keywords: ["performance", "low", "power", "mode", "reduce", "battery", "laptop"]
        },
        {
            pageIndex: 7, pageName: pages[7].name,
            section: Translation.tr("Interactions"),
            label: Translation.tr("Scrolling"),
            description: Translation.tr("Touchpad and mouse scroll speed"),
            keywords: ["scroll", "touchpad", "mouse", "speed", "fast", "slow", "sensitivity"]
        },

        // =====================================================================
        // Shortcuts (page 8)
        // =====================================================================
        {
            pageIndex: 8, pageName: pages[8].name,
            section: Translation.tr("Keyboard Shortcuts"),
            label: Translation.tr("Keyboard Shortcuts"),
            description: Translation.tr("Niri and ii keybindings reference"),
            keywords: ["shortcuts", "keybindings", "hotkeys", "keyboard", "cheatsheet",
                       "terminal", "clipboard", "volume", "brightness", "screenshot", "lock",
                       "workspace", "window", "focus", "move", "fullscreen", "floating",
                       "overview", "settings", "wallpaper", "media", "play", "pause"]
        },

        // =====================================================================
        // Modules (page 9)
        // =====================================================================
        {
            pageIndex: 9, pageName: pages[9].name,
            section: Translation.tr("Panel Modules"),
            label: Translation.tr("Panel Modules"),
            description: Translation.tr("Enable or disable shell modules"),
            keywords: ["modules", "panels", "enable", "disable", "bar", "sidebar", "overview"]
        },
        {
            pageIndex: 9, pageName: pages[9].name,
            section: Translation.tr("Panel Modules"),
            label: Translation.tr("Enable notification popups"),
            description: Translation.tr("Toggle notification toast popups"),
            keywords: ["module", "notification", "popup", "toast", "enable", "disable"]
        },
        {
            pageIndex: 9, pageName: pages[9].name,
            section: Translation.tr("Panel Modules"),
            label: Translation.tr("Enable dock"),
            description: Translation.tr("Toggle dock panel"),
            keywords: ["module", "dock", "enable", "disable", "panel"]
        },
        {
            pageIndex: 9, pageName: pages[9].name,
            section: Translation.tr("Panel Modules"),
            label: Translation.tr("Enable overview"),
            description: Translation.tr("Toggle workspace overview"),
            keywords: ["module", "overview", "enable", "disable", "workspace"]
        },
        {
            pageIndex: 9, pageName: pages[9].name,
            section: Translation.tr("Panel Modules"),
            label: Translation.tr("Enable sidebars"),
            description: Translation.tr("Toggle left and right sidebars"),
            keywords: ["module", "sidebar", "left", "right", "enable", "disable"]
        },
        {
            pageIndex: 9, pageName: pages[9].name,
            section: Translation.tr("Alt+Tab Switcher"),
            label: Translation.tr("Alt+Tab Switcher"),
            description: Translation.tr("Window switcher style and behavior"),
            keywords: ["alt", "tab", "switcher", "windows", "thumbnails"]
        },

        // =====================================================================
        // Waffle Style (page 10)
        // =====================================================================
        {
            pageIndex: 10, pageName: pages[10].name,
            section: Translation.tr("Waffle Taskbar"),
            label: Translation.tr("Waffle Taskbar"),
            description: Translation.tr("Windows 11 style taskbar settings"),
            keywords: ["waffle", "taskbar", "windows", "bottom", "tray"]
        },
        {
            pageIndex: 10, pageName: pages[10].name,
            section: Translation.tr("Waffle Start Menu"),
            label: Translation.tr("Waffle Start Menu"),
            description: Translation.tr("Start menu size and behavior"),
            keywords: ["waffle", "start", "menu", "apps", "pinned"]
        },
        {
            pageIndex: 10, pageName: pages[10].name,
            section: Translation.tr("Waffle Action Center"),
            label: Translation.tr("Waffle Action Center"),
            description: Translation.tr("Quick toggles and action center"),
            keywords: ["waffle", "action", "center", "toggles", "quick"]
        },
        {
            pageIndex: 10, pageName: pages[10].name,
            section: Translation.tr("Waffle Widgets"),
            label: Translation.tr("Waffle Widgets"),
            description: Translation.tr("Widgets panel settings"),
            keywords: ["waffle", "widgets", "panel", "weather", "calendar"]
        },
        {
            pageIndex: 10, pageName: pages[10].name,
            section: Translation.tr("Waffle Alt+Tab"),
            label: Translation.tr("Waffle Alt+Tab"),
            description: Translation.tr("Waffle window switcher with thumbnails"),
            keywords: ["waffle", "alt", "tab", "switcher", "thumbnails", "carousel"]
        },
        {
            pageIndex: 10, pageName: pages[10].name,
            section: Translation.tr("Waffle Background"),
            label: Translation.tr("Waffle Background"),
            description: Translation.tr("Waffle-specific wallpaper and backdrop settings"),
            keywords: ["waffle", "background", "wallpaper", "backdrop", "effects"]
        },

        // =====================================================================
        // About (page 11)
        // =====================================================================
        {
            pageIndex: 11, pageName: pages[11].name,
            section: Translation.tr("About"),
            label: Translation.tr("About ii"),
            description: Translation.tr("Version info, credits and links"),
            keywords: ["about", "version", "credits", "github", "info"]
        }
    ]

    function recomputeSettingsSearchResults() {
        var q = String(settingsSearchText || "").toLowerCase().trim();
        if (!q.length) {
            settingsSearchResults = [];
            return;
        }

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var results = [];

        // Check if waffle family is active
        var isWaffleActive = Config.options?.panelFamily === "waffle";
        var wafflePageIndex = 10; // "Waffle Style" page index

        // 1. Buscar en el índice estático de secciones (para navegación rápida a secciones)
        for (var i = 0; i < settingsSearchIndex.length; i++) {
            var entry = settingsSearchIndex[i];

            // Skip Waffle Style page if waffle family is not active
            if (entry.pageIndex === wafflePageIndex && !isWaffleActive) {
                continue;
            }

            var label = (entry.label || "").toLowerCase();
            var desc = (entry.description || "").toLowerCase();
            var page = (entry.pageName || "").toLowerCase();
            var sect = (entry.section || "").toLowerCase();
            var kw = (entry.keywords || []).join(" ").toLowerCase();

            var matchCount = 0;
            var score = 0;

            for (var j = 0; j < terms.length; j++) {
                var term = terms[j];
                if (label.indexOf(term) >= 0 || desc.indexOf(term) >= 0 ||
                    page.indexOf(term) >= 0 || sect.indexOf(term) >= 0 || kw.indexOf(term) >= 0) {
                    matchCount++;
                    if (label.indexOf(term) === 0) score += 800;
                    else if (label.indexOf(term) > 0) score += 400;
                    if (kw.indexOf(term) >= 0) score += 300;
                    if (sect.indexOf(term) >= 0) score += 200;
                }
            }

            if (matchCount === terms.length) {
                results.push({
                    pageIndex: entry.pageIndex,
                    pageName: entry.pageName,
                    section: entry.section,
                    label: entry.label,
                    labelHighlighted: SettingsSearchRegistry.highlightTerms(entry.label, terms),
                    description: entry.description,
                    descriptionHighlighted: SettingsSearchRegistry.highlightTerms(entry.description, terms),
                    score: score + 500, // Bonus para secciones principales
                    isSection: true
                });
            }
        }

        // 2. Buscar en el registro dinámico de widgets
        if (typeof SettingsSearchRegistry !== "undefined") {
            var widgetResults = SettingsSearchRegistry.buildResults(settingsSearchText);
            // Filter out Waffle Style widgets if waffle family is not active
            if (!isWaffleActive) {
                widgetResults = widgetResults.filter(r => r.pageIndex !== wafflePageIndex);
            }
            results = results.concat(widgetResults);
        }

        // 3. Ordenar por score y eliminar duplicados
        results.sort((a, b) => b.score - a.score);

        // Eliminar duplicados por label+section, preferring entries with optionId
        var seen = {};
        var unique = [];
        for (var k = 0; k < results.length; k++) {
            var r = results[k];
            var key = (r.label || "") + "|" + (r.section || "");
            if (!seen[key]) {
                seen[key] = { index: unique.length, hasOptionId: r.optionId !== undefined };
                unique.push(r);
            } else if (r.optionId !== undefined && !seen[key].hasOptionId) {
                // Replace the existing entry (without optionId) with this one (with optionId)
                unique[seen[key].index] = r;
                seen[key].hasOptionId = true;
            }
        }

        settingsSearchResults = unique.slice(0, 50);
    }

    // Pending spotlight data
    property int pendingSpotlightOptionId: -1
    property string pendingSpotlightLabel: ""
    property string pendingSpotlightSection: ""
    property int pendingSpotlightPageIndex: -1
    property var spotlightFlickable: null

    function openSearchResult(entry) {
        // Clear search immediately
        settingsSearchText = "";
        if (settingsSearchField) {
            settingsSearchField.text = "";
        }

        // Deactivate any existing spotlight
        deactivateSpotlight();

        if (!entry || entry.pageIndex === undefined || entry.pageIndex < 0) {
            return;
        }

        // Store spotlight target info
        pendingSpotlightOptionId = (entry.optionId !== undefined) ? entry.optionId : -1;
        pendingSpotlightLabel = entry.label || "";
        pendingSpotlightSection = entry.section || "";
        pendingSpotlightPageIndex = entry.pageIndex;

        // Navigate to page (this triggers page load if needed)
        if (currentPage !== entry.pageIndex) {
            currentPage = entry.pageIndex;
        }

        // Always try spotlight (with retry for lazy-loaded widgets)
        if (pendingSpotlightOptionId >= 0 || pendingSpotlightLabel.length > 0) {
            spotlightRetryCount = 0;
            spotlightPageLoadTimer.restart();
        }
    }

    property int spotlightRetryCount: 0
    property int spotlightMaxRetries: 15

    // Timer to wait for page load and widget registration
    Timer {
        id: spotlightPageLoadTimer
        interval: 150
        onTriggered: root.trySpotlight()
    }

    function trySpotlight() {
        var control = null;

        // Try by optionId first
        if (pendingSpotlightOptionId >= 0) {
            control = SettingsSearchRegistry.getControlById(pendingSpotlightOptionId);
        }

        // Fallback: search in registry by various criteria
        if (!control && (pendingSpotlightLabel.length > 0 || pendingSpotlightSection.length > 0)) {
            var labelLower = pendingSpotlightLabel.toLowerCase();
            var sectionLower = pendingSpotlightSection.toLowerCase();
            // Remove page name prefix from section if present (e.g., "Themes › Global Style" -> "Global Style")
            var sectionParts = sectionLower.split(" › ");
            var sectionOnly = sectionParts.length > 1 ? sectionParts[sectionParts.length - 1] : sectionLower;

            for (var i = 0; i < SettingsSearchRegistry.entries.length; i++) {
                var e = SettingsSearchRegistry.entries[i];
                if (e.pageIndex === pendingSpotlightPageIndex) {
                    var eLabelLower = (e.label || "").toLowerCase();
                    var eSectionLower = (e.section || "").toLowerCase();

                    // Exact label match
                    if (eLabelLower === labelLower) {
                        control = e.control;
                        break;
                    }
                    // Section title match (for SettingsCardSection)
                    if (eSectionLower === sectionOnly || eSectionLower === labelLower) {
                        control = e.control;
                        break;
                    }
                    // Label contains search term
                    if (labelLower.length > 2 && eLabelLower.indexOf(labelLower) >= 0) {
                        control = e.control;
                        break;
                    }
                    // Keywords contain search term
                    if (e.keywords && e.keywords.some(k => k.toLowerCase() === labelLower)) {
                        control = e.control;
                        break;
                    }
                }
            }
        }

        if (control) {
            doSpotlightForControl(control);
        } else if (spotlightRetryCount < spotlightMaxRetries) {
            spotlightRetryCount++;
            spotlightPageLoadTimer.restart();
        } else {
            // Give up after max retries - clear pending data
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightSection = "";
            pendingSpotlightPageIndex = -1;
        }
    }

    function doSpotlightForControl(control) {
        if (!control) return;

        // Expand the section containing the control and collapse others
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.expandSectionForControl(control);
        }

        // Find the parent Flickable (ContentPage/StyledFlickable)
        var flick = findParentFlickable(control);
        if (!flick) {
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightPageIndex = -1;
            return;
        }

        // Use mapToItem to get the control's position relative to the Flickable's contentItem
        // This accounts for all intermediate containers (ColumnLayout margins, etc.)
        var posInContent = control.mapToItem(flick.contentItem, 0, 0);
        var controlYInContent = posInContent.y;

        // Calculate target scroll position to center the control in viewport
        var viewportHeight = flick.height;
        var controlHeight = control.height;
        var targetScrollY = controlYInContent - (viewportHeight / 2) + (controlHeight / 2);

        // Clamp to valid scroll range
        var maxScroll = Math.max(0, flick.contentHeight - flick.height);
        targetScrollY = Math.max(0, Math.min(targetScrollY, maxScroll));

        // Store the target scroll position for later verification
        spotlightTargetScrollY = targetScrollY;

        // Scroll to position - set directly to bypass animation
        flick.contentY = targetScrollY;

        // Store references for spotlight calculation
        spotlightTarget = control;
        spotlightFlickable = flick;

        // Wait for layout to update after scroll
        spotlightShowTimer.restart();
    }

    property real spotlightTargetScrollY: 0

    Timer {
        id: spotlightShowTimer
        interval: 250  // Must be longer than scroll animation (200ms) + layout time
        onTriggered: root.showSpotlight()
    }

    function showSpotlight() {
        if (!spotlightTarget || !spotlightFlickable) {
            deactivateSpotlight();
            return;
        }

        var control = spotlightTarget;
        var flick = spotlightFlickable;

        // Check if scroll animation is still running (contentY hasn't reached target)
        var scrollDiff = Math.abs(flick.contentY - spotlightTargetScrollY);
        if (scrollDiff > 2) {
            // Animation still in progress, wait a bit more
            spotlightShowTimer.restart();
            return;
        }

        // Use mapToItem directly to get the control's visual position in contentContainer
        // This is the most reliable method as it accounts for all transformations
        var pos = control.mapToItem(contentContainer, 0, 0);

        // Sanity check: control should be roughly centered vertically
        var expectedY = (contentContainer.height - control.height) / 2;
        var yDiff = Math.abs(pos.y - expectedY);

        // If position is way off from center, something went wrong
        if (yDiff > contentContainer.height / 2) {
            // Fallback: recalculate scroll position
            var posInContent = control.mapToItem(flick.contentItem, 0, 0);
            var targetScrollY = posInContent.y - (flick.height / 2) + (control.height / 2);
            var maxScroll = Math.max(0, flick.contentHeight - flick.height);
            targetScrollY = Math.max(0, Math.min(targetScrollY, maxScroll));
            spotlightTargetScrollY = targetScrollY;
            flick.contentY = targetScrollY;
            spotlightShowTimer.restart();
            return;
        }

        var padding = 8;
        spotlightRect = Qt.rect(
            Math.max(0, pos.x - padding),
            Math.max(0, pos.y - padding),
            control.width + padding * 2,
            control.height + padding * 2
        );
        spotlightActive = true;
        pendingSpotlightOptionId = -1;
    }

    function findParentFlickable(item) {
        var p = item ? item.parent : null;
        while (p) {
            // Check for Flickable properties (contentY, contentHeight, contentItem)
            if (p.hasOwnProperty("contentY") &&
                p.hasOwnProperty("contentHeight") &&
                p.hasOwnProperty("contentItem")) {
                return p;
            }
            p = p.parent;
        }
        return null;
    }

    function deactivateSpotlight() {
        spotlightActive = false;
        spotlightTarget = null;
        spotlightFlickable = null;
        spotlightTargetScrollY = 0;
        pendingSpotlightOptionId = -1;
    }

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    Component.onCompleted: {
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed

        const startPage = Quickshell.env("QS_SETTINGS_PAGE");
        if (startPage) root.currentPage = parseInt(startPage);

        const startSection = Quickshell.env("QS_SETTINGS_SECTION");
        if (startSection) {
            root.pendingSpotlightSection = startSection;
            root.pendingSpotlightPageIndex = root.currentPage;
            root.trySpotlight();
        }
    }

    // Apply theme when Config is ready
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) ThemeService.applyCurrentTheme()
        }
    }

    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: root.uiReady ? Appearance.m3colors.m3background : "transparent"

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: settingsSearchField.forceActiveFocus()
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }
        visible: root.uiReady
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        Item { // Titlebar
            visible: Config.options?.windows?.showTitlebar ?? true
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: Math.max(titleText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: titleText
                anchors {
                    left: (Config.options?.windows?.centerTitle ?? false) ? undefined : parent.left
                    horizontalCenter: (Config.options?.windows?.centerTitle ?? false) ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Settings")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }
        }

        // Global settings search bar - Material Design style
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 8

            Item { Layout.fillWidth: true }

            // Search container with visual feedback
            Rectangle {
                id: searchContainer
                Layout.preferredWidth: Math.min(560, root.width - 200)
                Layout.preferredHeight: 48
                radius: Appearance.rounding.full
                color: settingsSearchField.activeFocus
                    ? Appearance.colors.colLayer1
                    : Appearance.colors.colLayer0
                border.width: settingsSearchField.activeFocus ? 2 : 1
                border.color: settingsSearchField.activeFocus
                    ? Appearance.colors.colPrimary
                    : Appearance.m3colors.m3outlineVariant

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Icono animado
                    MaterialShapeWrappedMaterialSymbol {
                        id: settingsSearchIcon
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: Appearance.font.pixelSize.huge
                        shape: root.settingsSearchText.length > 0
                            ? MaterialShape.Shape.SoftBurst
                            : MaterialShape.Shape.Cookie7Sided
                        text: root.settingsSearchResults.length > 0 ? "manage_search" : "search"
                    }

                    // Campo de texto
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Placeholder text (behind TextField, separate element)
                        StyledText {
                            id: searchPlaceholder
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Search settings... (Ctrl+F)")
                            color: Appearance.colors.colSubtext
                            font {
                                family: Appearance.font.family.main
                                pixelSize: Appearance.font.pixelSize.normal
                            }
                            visible: settingsSearchField.text.length === 0 && !settingsSearchField.activeFocus
                        }

                        TextInput {
                            id: settingsSearchField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            verticalAlignment: Text.AlignVCenter

                            color: Appearance.colors.colOnLayer1
                            selectionColor: Appearance.colors.colPrimaryContainer
                            selectedTextColor: Appearance.colors.colOnPrimaryContainer
                            font {
                                family: Appearance.font.family.main
                                pixelSize: Appearance.font.pixelSize.normal
                            }

                            // Custom cursor color
                            cursorVisible: activeFocus
                            cursorDelegate: Rectangle {
                                visible: settingsSearchField.cursorVisible
                                width: 2
                                color: Appearance.colors.colPrimary

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: settingsSearchField.cursorVisible
                                    NumberAnimation { to: 0; duration: 530 }
                                    NumberAnimation { to: 1; duration: 530 }
                                }
                            }

                            text: root.settingsSearchText
                            onTextChanged: {
                                root.settingsSearchText = text;
                                root.recomputeSettingsSearchResults();
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Down && root.settingsSearchResults.length > 0) {
                                    resultsListView.forceActiveFocus();
                                    if ((resultsListView.currentIndex < 0 || resultsListView.currentIndex >= resultsListView.count) && resultsListView.count > 0) {
                                        resultsListView.currentIndex = 0;
                                    }
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.settingsSearchResults.length > 0) {
                                    var idx = (resultsListView.currentIndex >= 0 && resultsListView.currentIndex < root.settingsSearchResults.length)
                                        ? resultsListView.currentIndex
                                        : 0;
                                    root.openSearchResult(root.settingsSearchResults[idx]);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openSearchResult({});
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Botón de limpiar
                    RippleButton {
                        id: clearButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: Appearance.rounding.full
                        visible: root.settingsSearchText.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        onClicked: {
                            settingsSearchField.text = "";
                            settingsSearchField.forceActiveFocus();
                        }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 18
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    // Badge de resultados
                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: resultsCountText.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 4
                        visible: root.settingsSearchText.length > 0 && root.settingsSearchResults.length > 0
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer

                        StyledText {
                            id: resultsCountText
                            anchors.centerIn: parent
                            text: root.settingsSearchResults.length.toString()
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding
            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                implicitWidth: navRail.expanded ? 150 : fab.baseSize
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Flickable {
                    id: navRailFlickable
                    anchors.fill: parent
                    contentWidth: navRail.width
                    contentHeight: navRail.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    NavigationRail {
                        id: navRail
                        width: navRailWrapper.implicitWidth
                        spacing: 10
                        expanded: false  // Default collapsed, user can expand with button

                        NavigationRailExpandButton {
                            focus: root.visible
                        }

                        FloatingActionButton {
                            id: fab
                            property bool justCopied: false
                            iconText: justCopied ? "check" : "edit"
                            buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                            expanded: navRail.expanded
                            downAction: () => {
                                Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                            }
                            altAction: () => {
                                Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                                fab.justCopied = true;
                                revertTextTimer.restart()
                            }

                            Timer {
                                id: revertTextTimer
                                interval: 1500
                                onTriggered: {
                                    fab.justCopied = false;
                                }
                            }

                            StyledToolTip {
                                text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                            }
                        }

                        NavigationRailTabArray {
                            currentIndex: root.currentPage
                            expanded: navRail.expanded
                            Repeater {
                                model: root.pages
                                NavigationRailButton {
                                    required property var index
                                    required property var modelData
                                    toggled: root.currentPage === index
                                    onPressed: root.currentPage = index;
                                    expanded: navRail.expanded
                                    buttonIcon: modelData.icon
                                    buttonIconRotation: modelData.iconRotation || 0
                                    buttonText: modelData.name
                                    showToggledHighlight: false
                                }
                            }
                        }
                    }
                }
            }
            Rectangle { // Content container
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding

                Item {
                    id: pagesStack
                    anchors.fill: parent

                    // Track which pages have been visited (for lazy loading with cache)
                    property var visitedPages: ({})
                    property int preloadIndex: 0

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            pagesStack.visitedPages[root.currentPage] = true
                            pagesStack.visitedPagesChanged()
                        }
                    }

                    Component.onCompleted: {
                        // Mark initial page as visited
                        visitedPages[root.currentPage] = true
                        // Start preloading other pages after a short delay
                        preloadTimer.start()
                    }

                    // Preload all pages for search - faster interval
                    Timer {
                        id: preloadTimer
                        interval: 100
                        repeat: true
                        onTriggered: {
                            // Load 2 pages per tick for faster indexing
                            for (var i = 0; i < 2 && pagesStack.preloadIndex < root.pages.length; i++) {
                                if (!pagesStack.visitedPages[pagesStack.preloadIndex]) {
                                    pagesStack.visitedPages[pagesStack.preloadIndex] = true
                                    pagesStack.visitedPagesChanged()
                                }
                                pagesStack.preloadIndex++
                            }
                            if (pagesStack.preloadIndex >= root.pages.length) {
                                preloadTimer.stop()
                            }
                        }
                    }

                    Repeater {
                        model: root.pages.length
                        delegate: Loader {
                            id: pageLoader
                            required property int index
                            anchors.fill: parent
                            // Lazy load: only load when visited, keep loaded after
                            active: Config.ready && (pagesStack.visitedPages[index] === true)
                            asynchronous: index !== root.currentPage // Load non-current pages async
                            source: root.pages[index].component
                            visible: index === root.currentPage && status === Loader.Ready
                            opacity: visible ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveEnter.type
                                    easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                                }
                            }
                        }
                    }
                }

                // Search results overlay - Simple dropdown style
                Rectangle {
                    id: settingsSearchOverlay
                    anchors.fill: parent
                    visible: root.settingsSearchText.length > 0 && root.settingsSearchResults.length > 0
                    color: "transparent"
                    z: 100

                    // Click outside to close
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openSearchResult({})
                    }

                    // Results card
                    Rectangle {
                        id: searchResultsCard
                        width: Math.min(parent.width - 40, 500)
                        height: Math.min(resultsListView.contentHeight + 16, 400)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        radius: Appearance.rounding.normal
                        color: Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.m3colors.m3outlineVariant

                        layer.enabled: Appearance.effectsEnabled
                        layer.effect: DropShadow {
                            color: Qt.rgba(0, 0, 0, 0.3)
                            radius: 12
                            samples: 13
                            verticalOffset: 4
                        }

                        ListView {
                            id: resultsListView
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            model: root.settingsSearchResults
                            clip: true
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up) {
                                    if (resultsListView.currentIndex > 0) {
                                        resultsListView.currentIndex--;
                                    } else {
                                        settingsSearchField.forceActiveFocus();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (resultsListView.currentIndex < resultsListView.count - 1) {
                                        resultsListView.currentIndex++;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (resultsListView.currentIndex >= 0) {
                                        root.openSearchResult(root.settingsSearchResults[resultsListView.currentIndex]);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openSearchResult({});
                                    settingsSearchField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            delegate: RippleButton {
                                id: resultItem
                                required property var modelData
                                required property int index

                                width: resultsListView.width
                                implicitHeight: 52
                                buttonRadius: Appearance.rounding.small

                                colBackground: ListView.isCurrentItem ? Appearance.colors.colPrimaryContainer : "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2

                                Keys.forwardTo: [resultsListView]
                                onClicked: root.openSearchResult(modelData)

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Page icon
                                    MaterialSymbol {
                                        text: {
                                            var icons = ["instant_mix", "browse", "toast", "texture", "palette",
                                                        "bottom_app_bar", "settings", "construction", "keyboard",
                                                        "extension", "window", "info"];
                                            return icons[resultItem.modelData.pageIndex] || "settings";
                                        }
                                        iconSize: 20
                                        color: resultItem.ListView.isCurrentItem
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colPrimary
                                    }

                                    // Text content
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: resultItem.modelData.labelHighlighted || resultItem.modelData.label || ""
                                            textFormat: Text.StyledText
                                            font {
                                                family: Appearance.font.family.main
                                                pixelSize: Appearance.font.pixelSize.small
                                                weight: Font.Medium
                                            }
                                            color: resultItem.ListView.isCurrentItem
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : Appearance.colors.colOnLayer1
                                            elide: Text.ElideRight
                                        }

                                        // Breadcrumb path with arrows
                                        Row {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            StyledText {
                                                text: resultItem.modelData.pageName || ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: resultItem.ListView.isCurrentItem
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.9
                                            }
                                            MaterialSymbol {
                                                visible: resultItem.modelData.section && resultItem.modelData.section !== resultItem.modelData.pageName
                                                text: "chevron_right"
                                                iconSize: Appearance.font.pixelSize.smaller
                                                color: resultItem.ListView.isCurrentItem
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.6
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                visible: resultItem.modelData.section && resultItem.modelData.section !== resultItem.modelData.pageName
                                                text: resultItem.modelData.section || ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: resultItem.ListView.isCurrentItem
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.9
                                            }
                                        }
                                    }

                                    // Arrow
                                    MaterialSymbol {
                                        text: "arrow_forward"
                                        iconSize: 16
                                        color: resultItem.ListView.isCurrentItem
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colSubtext
                                        opacity: resultItem.hovered || resultItem.ListView.isCurrentItem ? 1 : 0
                                    }
                                }
                            }
                        }
                    }
                }

                // No results indicator (inline, not overlay)
                Rectangle {
                    visible: root.settingsSearchText.length > 0 && root.settingsSearchResults.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    width: noResultsRow.implicitWidth + 24
                    height: 36
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer1
                    z: 100

                    RowLayout {
                        id: noResultsRow
                        anchors.centerIn: parent
                        spacing: 8

                        MaterialSymbol {
                            text: "search_off"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: Translation.tr("No results found")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Spotlight overlay - scrim with cutout for focused option
                Item {
                    id: spotlightOverlay
                    anchors.fill: parent
                    visible: root.spotlightActive
                    z: 200

                    // Click anywhere to dismiss
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.deactivateSpotlight()
                    }

                    // Dark scrim with cutout using Canvas
                    Canvas {
                        id: spotlightCanvas
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();

                            // Fill entire area with semi-transparent dark
                            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.5);
                            ctx.fillRect(0, 0, width, height);

                            // Cut out the spotlight area (clear it)
                            if (root.spotlightActive && root.spotlightRect.width > 0) {
                                ctx.globalCompositeOperation = "destination-out";

                                var r = root.spotlightRect;
                                var radius = Appearance.rounding.normal;

                                // Draw rounded rectangle cutout
                                ctx.beginPath();
                                ctx.moveTo(r.x + radius, r.y);
                                ctx.lineTo(r.x + r.width - radius, r.y);
                                ctx.quadraticCurveTo(r.x + r.width, r.y, r.x + r.width, r.y + radius);
                                ctx.lineTo(r.x + r.width, r.y + r.height - radius);
                                ctx.quadraticCurveTo(r.x + r.width, r.y + r.height, r.x + r.width - radius, r.y + r.height);
                                ctx.lineTo(r.x + radius, r.y + r.height);
                                ctx.quadraticCurveTo(r.x, r.y + r.height, r.x, r.y + r.height - radius);
                                ctx.lineTo(r.x, r.y + radius);
                                ctx.quadraticCurveTo(r.x, r.y, r.x + radius, r.y);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        Connections {
                            target: root
                            function onSpotlightRectChanged() {
                                spotlightCanvas.requestPaint();
                            }
                            function onSpotlightActiveChanged() {
                                spotlightCanvas.requestPaint();
                            }
                        }
                    }

                    // Subtle border around the cutout
                    Rectangle {
                        visible: root.spotlightActive && root.spotlightRect.width > 0
                        x: root.spotlightRect.x - 1
                        y: root.spotlightRect.y - 1
                        width: root.spotlightRect.width + 2
                        height: root.spotlightRect.height + 2
                        radius: Appearance.rounding.normal + 1
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        opacity: 0.8
                    }

                    // Auto-dismiss after 2.5 seconds
                    Timer {
                        running: root.spotlightActive
                        interval: 2500
                        onTriggered: root.deactivateSpotlight()
                    }

                    // Keyboard dismiss
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.deactivateSpotlight();
                            event.accepted = true;
                        }
                    }

                    Component.onCompleted: forceActiveFocus()
                }
            }
        }
    }
}
