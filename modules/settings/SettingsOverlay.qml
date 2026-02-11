import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

/**
 * Settings UI as a layer shell overlay panel.
 * Allows users to see live changes to the shell (sidebars, bar, etc.)
 * without opening a separate window. Loaded by the main shell when
 * Config.options.settingsUi.overlayMode is true.
 */
Scope {
    id: root

    property bool settingsOpen: GlobalStates.settingsOverlayOpen ?? false

    // Keep alive after first open for instant re-open
    property bool _everOpened: false

    // ── Search system (full, same as settings.qml) ──
    property string overlaySearchText: ""
    property var overlaySearchResults: []

    // Spotlight effect for search results
    property var spotlightTarget: null
    property rect spotlightRect: Qt.rect(0, 0, 0, 0)
    property bool spotlightActive: false

    Timer {
        id: searchDebounceTimer
        interval: 200
        onTriggered: root.recomputeOverlaySearchResults()
    }

    // Full search index matching settings.qml
    property var overlaySearchIndex: [
        // Quick (page 0)
        { pageIndex: 0, pageName: overlayPages[0].name, section: Translation.tr("Wallpaper & Colors"), label: Translation.tr("Wallpaper & Colors"), description: Translation.tr("Wallpaper, palette and transparency settings"), keywords: ["wallpaper", "colors", "palette", "theme", "background"] },
        { pageIndex: 0, pageName: overlayPages[0].name, section: Translation.tr("Bar & screen"), label: Translation.tr("Bar & screen"), description: Translation.tr("Bar position and screen rounding"), keywords: ["bar", "position", "screen", "round", "corner"] },
        // General (page 1)
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Audio"), label: Translation.tr("Audio"), description: Translation.tr("Volume protection and limits"), keywords: ["audio", "volume", "earbang", "limit", "sound"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Audio"), label: Translation.tr("Volume protection"), description: Translation.tr("Prevent sudden volume spikes"), keywords: ["volume", "protection", "earbang", "spike", "loud", "limit", "max"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Audio"), label: Translation.tr("Max volume increase"), description: Translation.tr("Maximum volume jump allowed per step"), keywords: ["volume", "increase", "step", "max", "jump"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Battery"), label: Translation.tr("Battery"), description: Translation.tr("Battery warnings and auto suspend thresholds"), keywords: ["battery", "low", "critical", "suspend", "full"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Battery"), label: Translation.tr("Low battery threshold"), description: Translation.tr("Percentage to show low battery warning"), keywords: ["battery", "low", "warning", "threshold", "percentage"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Battery"), label: Translation.tr("Critical battery"), description: Translation.tr("Percentage for critical battery warning"), keywords: ["battery", "critical", "danger", "threshold"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Battery"), label: Translation.tr("Auto suspend"), description: Translation.tr("Automatically suspend on critical battery"), keywords: ["battery", "suspend", "sleep", "auto", "critical"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Language"), label: Translation.tr("Language"), description: Translation.tr("Interface language and AI translations"), keywords: ["language", "locale", "translation", "gemini", "idioma", "español", "english"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Language"), label: Translation.tr("UI Language"), description: Translation.tr("Interface display language"), keywords: ["language", "locale", "ui", "display", "idioma", "english", "spanish", "chinese", "japanese", "russian"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Policies"), label: Translation.tr("AI Policy"), description: Translation.tr("Enable or disable AI features"), keywords: ["ai", "policy", "enable", "disable", "local", "privacy"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Policies"), label: Translation.tr("Weeb Policy"), description: Translation.tr("Anime and manga content visibility"), keywords: ["weeb", "anime", "manga", "nsfw", "content", "policy"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Sounds"), label: Translation.tr("Sounds"), description: Translation.tr("Battery, Pomodoro and notification sounds"), keywords: ["sound", "notification", "pomodoro", "battery", "alert", "audio"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Sounds"), label: Translation.tr("Notification sound"), description: Translation.tr("Play sound when a notification arrives"), keywords: ["sound", "notification", "alert", "ring", "chime"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Time"), label: Translation.tr("Time"), description: Translation.tr("Clock format and seconds"), keywords: ["time", "clock", "24h", "12h", "format"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Time"), label: Translation.tr("Clock format"), description: Translation.tr("Time display format (e.g., hh:mm or h:mm AP)"), keywords: ["time", "clock", "format", "24h", "12h", "am", "pm", "hour", "minute"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Time"), label: Translation.tr("Show seconds"), description: Translation.tr("Update clock every second"), keywords: ["time", "seconds", "precision", "clock", "update"] },
        { pageIndex: 1, pageName: overlayPages[1].name, section: Translation.tr("Work Safety"), label: Translation.tr("Work Safety"), description: Translation.tr("Hide sensitive content on public networks"), keywords: ["work", "safety", "nsfw", "public", "network", "hide", "clipboard", "wallpaper"] },
        // Bar (page 2)
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Positioning"), label: Translation.tr("Bar position"), description: Translation.tr("Bar position, auto hide and style"), keywords: ["bar", "position", "auto", "hide", "corner", "style", "top", "bottom", "float", "vertical"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Positioning"), label: Translation.tr("Auto hide"), description: Translation.tr("Automatically hide the bar"), keywords: ["bar", "auto", "hide", "show", "hover", "reveal"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Positioning"), label: Translation.tr("Corner style"), description: Translation.tr("Bar corner style: hug, float, rectangle or card"), keywords: ["bar", "corner", "style", "hug", "float", "rectangle", "card", "rounding"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Positioning"), label: Translation.tr("Vertical bar"), description: Translation.tr("Use vertical bar layout on the side"), keywords: ["bar", "vertical", "side", "left", "orientation"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Positioning"), label: Translation.tr("Bar background"), description: Translation.tr("Show or hide bar background"), keywords: ["bar", "background", "transparent", "show", "hide"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Positioning"), label: Translation.tr("Blur background"), description: Translation.tr("Enable glass blur behind the bar"), keywords: ["bar", "blur", "glass", "background", "transparent"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Notifications"), label: Translation.tr("Notification indicator"), description: Translation.tr("Notification unread count in the bar"), keywords: ["notifications", "unread", "indicator", "count", "badge", "bar"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Tray"), label: Translation.tr("System tray"), description: Translation.tr("System tray icons behaviour"), keywords: ["tray", "systray", "icons", "pinned", "monochrome"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Tray"), label: Translation.tr("Monochrome tray icons"), description: Translation.tr("Tint tray icons to match theme"), keywords: ["tray", "monochrome", "tint", "icons", "theme", "color"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Utility buttons"), label: Translation.tr("Utility buttons"), description: Translation.tr("Screen snip, color picker and toggles"), keywords: ["screen", "snip", "color", "picker", "mic", "dark", "mode", "performance", "screenshot", "record", "notepad", "keyboard"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Utility buttons"), label: Translation.tr("Screen record button"), description: Translation.tr("Show screen record button in bar"), keywords: ["screen", "record", "button", "bar", "recording", "video"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Utility buttons"), label: Translation.tr("Dark mode toggle"), description: Translation.tr("Show dark/light mode toggle in bar"), keywords: ["dark", "mode", "light", "toggle", "bar", "theme"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Workspaces"), label: Translation.tr("Workspaces"), description: Translation.tr("Workspace indicator count, numbers and icons"), keywords: ["workspace", "numbers", "icons", "delays", "scroll", "indicator"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Workspaces"), label: Translation.tr("App icons in workspaces"), description: Translation.tr("Show app icons inside workspace indicators"), keywords: ["workspace", "app", "icons", "show", "indicator"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Workspaces"), label: Translation.tr("Monochrome workspace icons"), description: Translation.tr("Tint workspace app icons to match theme"), keywords: ["workspace", "monochrome", "icons", "tint", "theme"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Workspaces"), label: Translation.tr("Scroll behavior"), description: Translation.tr("Workspace or column scroll behavior"), keywords: ["workspace", "scroll", "column", "behavior", "mouse", "touchpad"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Weather"), label: Translation.tr("Bar weather"), description: Translation.tr("Show weather in the bar"), keywords: ["weather", "bar", "temperature", "enable"] },
        { pageIndex: 2, pageName: overlayPages[2].name, section: Translation.tr("Bar modules"), label: Translation.tr("Bar module layout"), description: Translation.tr("Reorder and toggle bar modules"), keywords: ["bar", "module", "layout", "order", "reorder", "resources", "media", "clock"] },
        // Background (page 3)
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Parallax"), label: Translation.tr("Parallax"), description: Translation.tr("Background parallax based on workspace and sidebar"), keywords: ["parallax", "background", "zoom", "workspace", "sidebar"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Parallax"), label: Translation.tr("Workspace parallax"), description: Translation.tr("Shift background when switching workspaces"), keywords: ["parallax", "workspace", "shift", "scroll", "zoom"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Effects"), label: Translation.tr("Wallpaper effects"), description: Translation.tr("Wallpaper blur and dim overlay"), keywords: ["blur", "dim", "wallpaper", "effects", "overlay"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Effects"), label: Translation.tr("Wallpaper blur"), description: Translation.tr("Blur the wallpaper when windows are open"), keywords: ["blur", "wallpaper", "background", "radius", "gaussian"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Effects"), label: Translation.tr("Wallpaper dim"), description: Translation.tr("Darken wallpaper overlay"), keywords: ["dim", "wallpaper", "darken", "overlay", "opacity"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Effects"), label: Translation.tr("Dynamic dim"), description: Translation.tr("Extra dim when windows are present on workspace"), keywords: ["dynamic", "dim", "windows", "workspace", "darken"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Backdrop"), label: Translation.tr("Backdrop"), description: Translation.tr("Panel backdrop wallpaper and effects"), keywords: ["backdrop", "panel", "wallpaper", "blur", "vignette", "saturation"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Backdrop"), label: Translation.tr("Backdrop vignette"), description: Translation.tr("Vignette darkening effect on backdrop"), keywords: ["backdrop", "vignette", "darken", "edges", "effect"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Widget: Clock"), label: Translation.tr("Background clock"), description: Translation.tr("Clock widget on the desktop background"), keywords: ["clock", "widget", "cookie", "digital", "background", "desktop"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Widget: Clock"), label: Translation.tr("Clock style"), description: Translation.tr("Cookie (analog) or digital clock"), keywords: ["clock", "style", "cookie", "digital", "analog", "hands"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Widget: Weather"), label: Translation.tr("Background weather widget"), description: Translation.tr("Weather display on the desktop background"), keywords: ["weather", "widget", "background", "temperature"] },
        { pageIndex: 3, pageName: overlayPages[3].name, section: Translation.tr("Widget: Media"), label: Translation.tr("Background media widget"), description: Translation.tr("Media player controls on the desktop background"), keywords: ["media", "widget", "background", "player", "music", "album"] },
        // Themes (page 4)
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Global Style"), label: Translation.tr("Global Style"), description: Translation.tr("Material, Cards, Aurora glass effect, Inir TUI style"), keywords: ["global", "style", "aurora", "inir", "material", "cards", "glass", "tui", "transparency", "blur"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Global Style"), label: Translation.tr("Aurora"), description: Translation.tr("Glass effect with wallpaper blur behind panels"), keywords: ["aurora", "glass", "blur", "transparency", "style", "translucent"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Global Style"), label: Translation.tr("Inir"), description: Translation.tr("TUI-inspired style with accent borders"), keywords: ["inir", "tui", "terminal", "borders", "style", "minimal"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Global Style"), label: Translation.tr("Material"), description: Translation.tr("Material Design solid backgrounds"), keywords: ["material", "solid", "style", "default", "google"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Global Style"), label: Translation.tr("Cards"), description: Translation.tr("Card-style elevated containers"), keywords: ["cards", "card", "style", "elevated", "shadow"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Theme Presets"), label: Translation.tr("Theme Presets"), description: Translation.tr("Predefined color themes like Gruvbox, Catppuccin, Nord, Dracula"), keywords: ["theme", "preset", "gruvbox", "catppuccin", "nord", "dracula", "material", "colors", "palette", "monokai", "solarized", "tokyo", "night", "everforest", "rose", "pine"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Auto Theme"), label: Translation.tr("Auto Theme"), description: Translation.tr("Automatic colors from wallpaper"), keywords: ["auto", "wallpaper", "dynamic", "colors", "matugen", "generate"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Custom Theme"), label: Translation.tr("Custom Theme Editor"), description: Translation.tr("Create and edit custom color themes"), keywords: ["custom", "theme", "editor", "color", "create", "edit", "picker"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Typography"), label: Translation.tr("Font settings"), description: Translation.tr("Main font, title font, monospace font and size"), keywords: ["font", "typography", "size", "family", "main", "title", "monospace", "scale"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Typography"), label: Translation.tr("Font sync"), description: Translation.tr("Sync fonts with GTK/KDE system apps"), keywords: ["font", "sync", "gtk", "kde", "system", "apps"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Icons"), label: Translation.tr("Icon theme"), description: Translation.tr("System icon theme for tray and apps"), keywords: ["icon", "theme", "tray", "system", "apps", "gtk"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Icons"), label: Translation.tr("Dock icon theme"), description: Translation.tr("Separate icon theme for the dock"), keywords: ["dock", "icon", "theme", "separate", "override"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Terminal Theming"), label: Translation.tr("Terminal theming"), description: Translation.tr("Apply wallpaper colors to terminal emulators"), keywords: ["terminal", "theme", "kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "colors"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Transparency"), label: Translation.tr("Transparency"), description: Translation.tr("Panel and content transparency"), keywords: ["transparency", "opacity", "translucent", "see-through", "glass"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Screen Rounding"), label: Translation.tr("Fake screen rounding"), description: Translation.tr("Rounded corners for the screen edges"), keywords: ["screen", "rounding", "corners", "fake", "round", "edges"] },
        { pageIndex: 4, pageName: overlayPages[4].name, section: Translation.tr("Theme Schedule"), label: Translation.tr("Theme schedule"), description: Translation.tr("Automatically switch themes at day/night times"), keywords: ["theme", "schedule", "day", "night", "auto", "switch", "time"] },
        // Interface (page 5)
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Crosshair overlay"), label: Translation.tr("Crosshair overlay"), description: Translation.tr("In-game crosshair overlay"), keywords: ["crosshair", "overlay", "aim", "game", "fps"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Overlay"), label: Translation.tr("Overlay"), description: Translation.tr("Fullscreen overlay effects and animations"), keywords: ["overlay", "darken", "scrim", "zoom", "animation", "opacity"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Overlay"), label: Translation.tr("Overlay opacity"), description: Translation.tr("Background opacity of overlay panels"), keywords: ["overlay", "opacity", "background", "transparent", "panel"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Alt+Tab Switcher"), label: Translation.tr("Alt+Tab Switcher"), description: Translation.tr("Window switcher preset and behavior"), keywords: ["alt", "tab", "switcher", "window", "preset", "default", "list", "compact"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Dock"), description: Translation.tr("Dock position and behaviour"), keywords: ["dock", "position", "pinned", "hover", "reveal", "desktop", "show"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Dock enable"), description: Translation.tr("Enable or disable the dock"), keywords: ["dock", "enable", "disable", "show", "hide"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Dock position"), description: Translation.tr("Dock position: top, bottom, left, right"), keywords: ["dock", "position", "top", "bottom", "left", "right"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Pinned apps"), description: Translation.tr("Apps pinned to the dock"), keywords: ["dock", "pinned", "apps", "pin", "favorite"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Show on desktop"), description: Translation.tr("Show dock when no window is focused"), keywords: ["dock", "desktop", "show", "focus", "window", "empty"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Window preview"), description: Translation.tr("Show window preview on hover"), keywords: ["dock", "preview", "hover", "window", "thumbnail"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Dock icon size"), description: Translation.tr("Size of dock icons"), keywords: ["dock", "icon", "size", "height"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Dock"), label: Translation.tr("Monochrome dock icons"), description: Translation.tr("Tint dock icons to match theme"), keywords: ["dock", "monochrome", "icons", "tint", "theme"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Lock screen"), label: Translation.tr("Lock screen"), description: Translation.tr("Lock screen behaviour and style"), keywords: ["lock", "screen", "hyprlock", "blur", "password", "security"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Notifications"), label: Translation.tr("Notifications"), description: Translation.tr("Notification timeouts and popup position"), keywords: ["notifications", "timeout", "popup", "position"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Notifications"), label: Translation.tr("Notification timeout"), description: Translation.tr("Duration before notification auto-closes"), keywords: ["notification", "timeout", "duration", "auto", "close", "dismiss"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Notifications"), label: Translation.tr("Notification position"), description: Translation.tr("Where popup notifications appear on screen"), keywords: ["notification", "position", "popup", "corner", "top", "bottom", "left", "right"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Notifications"), label: Translation.tr("Do Not Disturb"), description: Translation.tr("Silence all notifications"), keywords: ["notification", "dnd", "silent", "mute", "disturb", "quiet", "do not"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Sidebars"), label: Translation.tr("Sidebars"), description: Translation.tr("Sidebar toggles, sliders and corner open"), keywords: ["sidebar", "quick", "toggles", "sliders", "corner"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Sidebars"), label: Translation.tr("Corner open"), description: Translation.tr("Open sidebar by hovering screen corners"), keywords: ["sidebar", "corner", "open", "hover", "edge", "clickless"] },
        { pageIndex: 5, pageName: overlayPages[5].name, section: Translation.tr("Overview"), label: Translation.tr("Overview"), description: Translation.tr("Overview scale, rows and columns"), keywords: ["overview", "grid", "rows", "columns", "scale"] },
        // Services (page 6)
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("AI"), label: Translation.tr("AI"), description: Translation.tr("System prompt for sidebar AI"), keywords: ["ai", "prompt", "system", "sidebar", "chat"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("Music Recognition"), label: Translation.tr("Music Recognition"), description: Translation.tr("Song recognition timeout and interval"), keywords: ["music", "recognition", "song", "timeout", "shazam", "songrec"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("Search"), label: Translation.tr("Search"), description: Translation.tr("Search engine, prefix configuration"), keywords: ["search", "prefix", "engine", "web", "google", "app", "launcher"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("Weather"), label: Translation.tr("Weather"), description: Translation.tr("Weather units, GPS and city"), keywords: ["weather", "gps", "city", "fahrenheit", "celsius", "temperature", "units"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("Idle & Power"), label: Translation.tr("Idle & Power"), description: Translation.tr("Screen off, lock and suspend timeouts"), keywords: ["idle", "power", "screen", "off", "lock", "suspend", "sleep", "timeout"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("Night Light"), label: Translation.tr("Night light"), description: Translation.tr("Blue light filter / color temperature"), keywords: ["night", "light", "blue", "filter", "color", "temperature", "warm", "redshift"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("GameMode"), label: Translation.tr("GameMode"), description: Translation.tr("Auto-detect fullscreen games and reduce effects"), keywords: ["game", "mode", "fullscreen", "performance", "fps", "auto", "detect", "animations", "effects"] },
        { pageIndex: 6, pageName: overlayPages[6].name, section: Translation.tr("Applications"), label: Translation.tr("Default applications"), description: Translation.tr("Terminal, file manager, browser commands"), keywords: ["apps", "applications", "terminal", "browser", "file", "manager", "discord", "default"] },
        // Advanced (page 7)
        { pageIndex: 7, pageName: overlayPages[7].name, section: Translation.tr("Color generation"), label: Translation.tr("Color generation"), description: Translation.tr("Wallpaper-based color theming and palette type"), keywords: ["color", "generation", "theming", "wallpaper", "matugen", "palette"] },
        { pageIndex: 7, pageName: overlayPages[7].name, section: Translation.tr("Performance"), label: Translation.tr("Low power mode"), description: Translation.tr("Reduce resource usage for low-end hardware"), keywords: ["performance", "low", "power", "mode", "reduce", "battery", "laptop"] },
        { pageIndex: 7, pageName: overlayPages[7].name, section: Translation.tr("Interactions"), label: Translation.tr("Scrolling"), description: Translation.tr("Touchpad and mouse scroll speed"), keywords: ["scroll", "touchpad", "mouse", "speed", "fast", "slow", "sensitivity"] },
        // Shortcuts (page 8)
        { pageIndex: 8, pageName: overlayPages[8].name, section: Translation.tr("Keyboard Shortcuts"), label: Translation.tr("Keyboard Shortcuts"), description: Translation.tr("Niri and ii keybindings reference"), keywords: ["shortcuts", "keybindings", "hotkeys", "keyboard", "cheatsheet", "terminal", "clipboard", "volume", "brightness", "screenshot", "lock", "workspace", "window", "focus", "move", "fullscreen", "floating", "overview", "settings", "wallpaper", "media", "play", "pause"] },
        // Modules (page 9)
        { pageIndex: 9, pageName: overlayPages[9].name, section: Translation.tr("Panel Modules"), label: Translation.tr("Panel Modules"), description: Translation.tr("Enable or disable shell modules"), keywords: ["modules", "panels", "enable", "disable", "bar", "sidebar", "overview"] },
        // Waffle Style (page 10)
        { pageIndex: 10, pageName: overlayPages[10].name, section: Translation.tr("Waffle Taskbar"), label: Translation.tr("Waffle Taskbar"), description: Translation.tr("Windows 11 style taskbar settings"), keywords: ["waffle", "taskbar", "windows", "bottom", "tray"] },
        { pageIndex: 10, pageName: overlayPages[10].name, section: Translation.tr("Waffle Start Menu"), label: Translation.tr("Waffle Start Menu"), description: Translation.tr("Start menu size and behavior"), keywords: ["waffle", "start", "menu", "apps", "pinned"] },
        // About (page 11)
        { pageIndex: 11, pageName: overlayPages[11].name, section: Translation.tr("About"), label: Translation.tr("About ii"), description: Translation.tr("Version info, credits and links"), keywords: ["about", "version", "credits", "github", "info"] }
    ]

    function recomputeOverlaySearchResults() {
        var q = String(overlaySearchText || "").toLowerCase().trim();
        if (!q.length) {
            overlaySearchResults = [];
            return;
        }

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var results = [];

        var isWaffleActive = Config.options?.panelFamily === "waffle";
        var wafflePageIndex = 10;

        // 1. Static index
        for (var i = 0; i < overlaySearchIndex.length; i++) {
            var entry = overlaySearchIndex[i];
            if (entry.pageIndex === wafflePageIndex && !isWaffleActive) continue;

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
                    score: score + 500,
                    isSection: true
                });
            }
        }

        // 2. Dynamic widget registry
        if (typeof SettingsSearchRegistry !== "undefined") {
            var widgetResults = SettingsSearchRegistry.buildResults(overlaySearchText);
            if (!isWaffleActive) {
                widgetResults = widgetResults.filter(r => r.pageIndex !== wafflePageIndex);
            }
            results = results.concat(widgetResults);
        }

        // 3. Sort and deduplicate
        results.sort((a, b) => b.score - a.score);
        var seen = {};
        var unique = [];
        for (var k = 0; k < results.length; k++) {
            var r = results[k];
            var key = (r.label || "") + "|" + (r.section || "");
            if (!seen[key]) {
                seen[key] = { index: unique.length, hasOptionId: r.optionId !== undefined };
                unique.push(r);
            } else if (r.optionId !== undefined && !seen[key].hasOptionId) {
                unique[seen[key].index] = r;
                seen[key].hasOptionId = true;
            }
        }

        overlaySearchResults = unique.slice(0, 50);
    }

    // ── Spotlight system (ported from settings.qml) ──
    property int pendingSpotlightOptionId: -1
    property string pendingSpotlightLabel: ""
    property string pendingSpotlightSection: ""
    property int pendingSpotlightPageIndex: -1
    property var spotlightFlickable: null
    property real spotlightTargetScrollY: 0
    property int spotlightRetryCount: 0
    property int spotlightMaxRetries: 15

    function openOverlaySearchResult(entry) {
        overlaySearchText = "";
        if (typeof overlaySearchField !== "undefined" && overlaySearchField) overlaySearchField.text = "";

        deactivateSpotlight();

        if (!entry || entry.pageIndex === undefined || entry.pageIndex < 0) return;

        pendingSpotlightOptionId = (entry.optionId !== undefined) ? entry.optionId : -1;
        pendingSpotlightLabel = entry.label || "";
        pendingSpotlightSection = entry.section || "";
        pendingSpotlightPageIndex = entry.pageIndex;

        if (overlayCurrentPage !== entry.pageIndex) {
            overlayCurrentPage = entry.pageIndex;
        }

        if (pendingSpotlightOptionId >= 0 || pendingSpotlightLabel.length > 0) {
            spotlightRetryCount = 0;
            spotlightPageLoadTimer.restart();
        }
    }

    Timer {
        id: spotlightPageLoadTimer
        interval: 150
        onTriggered: root.trySpotlight()
    }

    function trySpotlight() {
        var control = null;

        if (pendingSpotlightOptionId >= 0) {
            control = SettingsSearchRegistry.getControlById(pendingSpotlightOptionId);
        }

        if (!control && (pendingSpotlightLabel.length > 0 || pendingSpotlightSection.length > 0)) {
            var labelLower = pendingSpotlightLabel.toLowerCase();
            var sectionLower = pendingSpotlightSection.toLowerCase();
            var sectionParts = sectionLower.split(" · ");
            var sectionOnly = sectionParts.length > 1 ? sectionParts[sectionParts.length - 1] : sectionLower;

            for (var i = 0; i < SettingsSearchRegistry.entries.length; i++) {
                var e = SettingsSearchRegistry.entries[i];
                if (e.pageIndex === pendingSpotlightPageIndex) {
                    var eLabelLower = (e.label || "").toLowerCase();
                    var eSectionLower = (e.section || "").toLowerCase();

                    if (eLabelLower === labelLower) { control = e.control; break; }
                    if (eSectionLower === sectionOnly || eSectionLower === labelLower) { control = e.control; break; }
                    if (labelLower.length > 2 && eLabelLower.indexOf(labelLower) >= 0) { control = e.control; break; }
                    if (e.keywords && e.keywords.some(k => k.toLowerCase() === labelLower)) { control = e.control; break; }
                }
            }
        }

        if (control) {
            doSpotlightForControl(control);
        } else if (spotlightRetryCount < spotlightMaxRetries) {
            spotlightRetryCount++;
            spotlightPageLoadTimer.restart();
        } else {
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightSection = "";
            pendingSpotlightPageIndex = -1;
        }
    }

    function doSpotlightForControl(control) {
        if (!control) return;

        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.expandSectionForControl(control);
        }

        var flick = findParentFlickable(control);
        if (!flick) {
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightPageIndex = -1;
            return;
        }

        var posInContent = control.mapToItem(flick.contentItem, 0, 0);
        var controlYInContent = posInContent.y;
        var viewportHeight = flick.height;
        var controlHeight = control.height;
        var targetScrollY = controlYInContent - (viewportHeight / 2) + (controlHeight / 2);
        var maxScroll = Math.max(0, flick.contentHeight - flick.height);
        targetScrollY = Math.max(0, Math.min(targetScrollY, maxScroll));

        spotlightTargetScrollY = targetScrollY;
        flick.contentY = targetScrollY;

        spotlightTarget = control;
        spotlightFlickable = flick;

        spotlightShowTimer.restart();
    }

    Timer {
        id: spotlightShowTimer
        interval: 250
        onTriggered: root.showSpotlight()
    }

    function showSpotlight() {
        if (!spotlightTarget || !spotlightFlickable) {
            deactivateSpotlight();
            return;
        }

        var control = spotlightTarget;
        var flick = spotlightFlickable;

        var scrollDiff = Math.abs(flick.contentY - spotlightTargetScrollY);
        if (scrollDiff > 2) {
            spotlightShowTimer.restart();
            return;
        }

        var pos = control.mapToItem(overlayContentContainer, 0, 0);
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

    // Reset page when panel family changes to avoid showing stale page from other family
    property string _lastFamily: Config.options?.panelFamily ?? "ii"
    onSettingsOpenChanged: {
        var currentFamily = Config.options?.panelFamily ?? "ii";
        if (currentFamily !== _lastFamily) {
            _lastFamily = currentFamily;
            overlayCurrentPage = 0;
        }
    }
    Connections {
        target: Config.options ?? null
        function onPanelFamilyChanged() {
            root._lastFamily = Config.options?.panelFamily ?? "ii";
            root.overlayCurrentPage = 0;
        }
    }

    Connections {
        target: GlobalStates
        function onSettingsOverlayOpenChanged() {
            if (GlobalStates.settingsOverlayOpen) {
                root._everOpened = true
            }
        }
    }

    Loader {
        id: panelLoader
        active: root._everOpened

        sourceComponent: PanelWindow {
            id: settingsPanel

            visible: GlobalStates.settingsOverlayOpen ?? false

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:settingsOverlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Focus grab for Hyprland
            CompositorFocusGrab {
                id: grab
                windows: [settingsPanel]
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.settingsOverlayOpen = false
                }
            }

            Connections {
                target: GlobalStates
                function onSettingsOverlayOpenChanged() {
                    grabTimer.restart()
                }
            }

            Timer {
                id: grabTimer
                interval: 100
                onTriggered: grab.active = (GlobalStates.settingsOverlayOpen ?? false)
            }

            // ── Scrim backdrop ──
            Rectangle {
                id: scrimBg
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: (GlobalStates.settingsOverlayOpen ?? false) ? (Config.options?.overlay?.scrimDim ?? 35) / 100 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.settingsOverlayOpen = false
                }
            }

            // ── Floating settings card ──
            Rectangle {
                id: settingsCard

                readonly property real maxCardWidth: Math.min(1100, settingsPanel.width * 0.88)
                readonly property real maxCardHeight: Math.min(850, settingsPanel.height * 0.88)

                anchors.centerIn: parent
                width: maxCardWidth
                height: maxCardHeight
                radius: Appearance.rounding.windowRounding
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer0
                     : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Base
                     : Appearance.m3colors.m3background
                clip: true

                border.width: Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.inirEverywhere
                    ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer0Border)
                    : "transparent"

                // Scale + fade animation
                opacity: (GlobalStates.settingsOverlayOpen ?? false) ? 1 : 0
                scale: (GlobalStates.settingsOverlayOpen ?? false) ? 1.0 : 0.92

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }

                // Shadow - hidden in aurora, visible in material/inir
                layer.enabled: Appearance.effectsEnabled && !Appearance.auroraEverywhere
                layer.effect: DropShadow {
                    color: Appearance.colors.colShadow
                    radius: 24
                    samples: 25
                    verticalOffset: 8
                    horizontalOffset: 0
                }

                // Prevent clicks from closing
                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                // ── Main content ──
                ColumnLayout {
                    id: mainLayout
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    spacing: 0

                    // ── Title bar ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Layout.bottomMargin: 12
                        spacing: 12

                        MaterialSymbol {
                            text: "settings"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colPrimary
                            opacity: 0.85
                        }

                        StyledText {
                            text: Translation.tr("Settings")
                            font {
                                family: Appearance.font.family.title
                                pixelSize: Appearance.font.pixelSize.title
                                variableAxes: Appearance.font.variableAxes.title
                            }
                            color: Appearance.colors.colOnLayer0
                        }

                        Item { Layout.fillWidth: true }

                        // Search field
                        Rectangle {
                            id: overlaySearchContainer
                            Layout.preferredWidth: Math.min(360, settingsCard.width * 0.38)
                            Layout.preferredHeight: 40
                            radius: Appearance.rounding.full
                            color: overlaySearchField.activeFocus
                                ? Appearance.colors.colLayer1
                                : (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                  : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                  : Appearance.m3colors.m3surfaceContainerLow)
                            border.width: overlaySearchField.activeFocus ? 2 : 1
                            border.color: overlaySearchField.activeFocus
                                ? Appearance.colors.colPrimary
                                : (Appearance.inirEverywhere ? Appearance.inir.colBorderMuted
                                  : Appearance.m3colors.m3outlineVariant)

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                            Behavior on border.color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    text: root.overlaySearchResults.length > 0 ? "manage_search" : "search"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: overlaySearchField.activeFocus
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colSubtext

                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    StyledText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                        verticalAlignment: Text.AlignVCenter
                                        visible: overlaySearchField.text.length === 0 && !overlaySearchField.activeFocus
                                        text: Translation.tr("Search settings... (Ctrl+F)")
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.small
                                        }
                                        color: Appearance.colors.colSubtext
                                    }

                                    TextInput {
                                        id: overlaySearchField
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                        verticalAlignment: Text.AlignVCenter
                                        color: Appearance.colors.colOnLayer1
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.small
                                        }
                                        clip: true
                                        selectByMouse: true
                                        selectionColor: Appearance.colors.colPrimaryContainer
                                        selectedTextColor: Appearance.colors.colOnPrimaryContainer

                                        cursorVisible: activeFocus
                                        cursorDelegate: Rectangle {
                                            visible: overlaySearchField.cursorVisible
                                            width: 2
                                            color: Appearance.colors.colPrimary

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: overlaySearchField.cursorVisible
                                                NumberAnimation { to: 0; duration: 530 }
                                                NumberAnimation { to: 1; duration: 530 }
                                            }
                                        }

                                        text: root.overlaySearchText
                                        onTextChanged: {
                                            root.overlaySearchText = text;
                                            searchDebounceTimer.restart();
                                        }

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Down && root.overlaySearchResults.length > 0) {
                                                overlayResultsList.forceActiveFocus();
                                                if (overlayResultsList.currentIndex < 0) {
                                                    overlayResultsList.currentIndex = 0;
                                                }
                                                event.accepted = true;
                                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.overlaySearchResults.length > 0) {
                                                var idx = (overlayResultsList.currentIndex >= 0 && overlayResultsList.currentIndex < root.overlaySearchResults.length)
                                                    ? overlayResultsList.currentIndex
                                                    : 0;
                                                root.openOverlaySearchResult(root.overlaySearchResults[idx]);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Escape) {
                                                root.openOverlaySearchResult({});
                                                event.accepted = true;
                                            }
                                        }
                                    }
                                }

                                // Results count badge
                                Rectangle {
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: overlayResultsCountText.implicitWidth + 14
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: root.overlaySearchText.length > 0 && root.overlaySearchResults.length > 0
                                    radius: Appearance.rounding.full
                                    color: Appearance.colors.colPrimaryContainer
                                    opacity: visible ? 1 : 0

                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                    }

                                    StyledText {
                                        id: overlayResultsCountText
                                        anchors.centerIn: parent
                                        text: root.overlaySearchResults.length.toString()
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                // Clear button
                                RippleButton {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    buttonRadius: Appearance.rounding.full
                                    visible: root.overlaySearchText.length > 0
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                    }
                                    onClicked: {
                                        overlaySearchField.text = "";
                                        overlaySearchField.forceActiveFocus();
                                    }
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: 16
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }
                        }

                        // Close button
                        RippleButton {
                            buttonRadius: Appearance.rounding.full
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: GlobalStates.settingsOverlayOpen = false
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "close"
                                iconSize: 20
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    // ── Navigation + Content ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        // Navigation rail with labels
                        Rectangle {
                            id: navColumn
                            Layout.fillHeight: true
                            Layout.preferredWidth: 160
                            radius: Appearance.rounding.normal
                            color: "transparent"

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 2
                                contentHeight: navCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: StyledScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                ColumnLayout {
                                    id: navCol
                                    width: parent.width
                                    spacing: 2

                                    Repeater {
                                        model: overlayPages
                                        delegate: RippleButton {
                                            id: navBtn
                                            required property int index
                                            required property var modelData

                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            buttonRadius: Appearance.rounding.small

                                            toggled: overlayCurrentPage === index
                                            colBackground: "transparent"
                                            colBackgroundToggled: Appearance.inirEverywhere
                                                ? Appearance.inir.colLayer2
                                                : Appearance.auroraEverywhere
                                                    ? Appearance.aurora.colElevatedSurface
                                                    : Appearance.colors.colLayer1
                                            colBackgroundToggledHover: Appearance.inirEverywhere
                                                ? Appearance.inir.colLayer1Hover
                                                : Appearance.auroraEverywhere
                                                    ? Appearance.aurora.colElevatedSurface
                                                    : Appearance.colors.colLayer1Hover
                                            colBackgroundHover: Appearance.inirEverywhere
                                                ? Appearance.inir.colLayer1Hover
                                                : Appearance.auroraEverywhere
                                                    ? Appearance.aurora.colSubSurface
                                                    : CF.ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.5)

                                            onClicked: overlayCurrentPage = index

                                            contentItem: Item {
                                                anchors.fill: parent

                                                // Active indicator pill (left edge)
                                                Rectangle {
                                                    id: indicatorPill
                                                    width: 3
                                                    height: navBtn.toggled ? 18 : 0
                                                    radius: 2
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: Appearance.inirEverywhere
                                                        ? Appearance.inir.colAccent
                                                        : Appearance.colors.colPrimary
                                                    opacity: navBtn.toggled ? 1 : 0

                                                    Behavior on height {
                                                        enabled: Appearance.animationsEnabled
                                                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                                    }
                                                    Behavior on opacity {
                                                        enabled: Appearance.animationsEnabled
                                                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 8
                                                    spacing: 10

                                                    MaterialSymbol {
                                                        text: modelData.icon
                                                        iconSize: 18
                                                        color: navBtn.toggled
                                                            ? (Appearance.inirEverywhere
                                                                ? Appearance.inir.colAccent
                                                                : Appearance.colors.colPrimary)
                                                            : Appearance.colors.colOnSurfaceVariant
                                                        rotation: modelData.iconRotation || 0

                                                        Behavior on color {
                                                            enabled: Appearance.animationsEnabled
                                                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                                        }
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: modelData.name
                                                        font {
                                                            family: Appearance.font.family.main
                                                            pixelSize: Appearance.font.pixelSize.small
                                                            weight: navBtn.toggled ? Font.Medium : Font.Normal
                                                        }
                                                        color: navBtn.toggled
                                                            ? Appearance.colors.colOnLayer1
                                                            : Appearance.colors.colOnSurfaceVariant
                                                        elide: Text.ElideRight

                                                        Behavior on color {
                                                            enabled: Appearance.animationsEnabled
                                                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Content area
                        Rectangle {
                            id: overlayContentContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.normal
                            color: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                 : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                 : Appearance.m3colors.m3surfaceContainerLow
                            border.width: Appearance.inirEverywhere ? 1 : 0
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : "transparent"
                            clip: true

                            // Loading indicator
                            CircularProgress {
                                anchors.centerIn: parent
                                visible: {
                                    for (var i = 0; i < overlayPagesRepeater.count; i++) {
                                        var loader = overlayPagesRepeater.itemAt(i);
                                        if (loader && loader.index === overlayCurrentPage && loader.status !== Loader.Ready) {
                                            return true;
                                        }
                                    }
                                    return false;
                                }
                            }

                            // Page stack
                            Item {
                                id: overlayPagesStack
                                anchors.fill: parent

                                property var visitedPages: ({})
                                property int preloadIndex: 0

                                Connections {
                                    target: root
                                    function onSettingsOpenChanged() {
                                        if (root.settingsOpen) {
                                            overlayPagesStack.visitedPages[overlayCurrentPage] = true
                                            overlayPagesStack.visitedPagesChanged()
                                            overlayPreloadTimer.start()
                                        }
                                    }
                                }

                                Connections {
                                    target: root
                                    function onOverlayCurrentPageChanged() {
                                        overlayPagesStack.visitedPages[overlayCurrentPage] = true
                                        overlayPagesStack.visitedPagesChanged()
                                    }
                                }

                                Timer {
                                    id: initialLoadTimer
                                    interval: 1
                                    onTriggered: {
                                        overlayPagesStack.visitedPages[overlayCurrentPage] = true
                                        overlayPagesStack.visitedPagesChanged()
                                    }
                                }

                                Component.onCompleted: {
                                    initialLoadTimer.start()
                                }

                                Timer {
                                    id: overlayPreloadTimer
                                    interval: 100
                                    repeat: true
                                    onTriggered: {
                                        // Load 2 pages per tick for faster indexing
                                        for (var i = 0; i < 2 && overlayPagesStack.preloadIndex < overlayPages.length; i++) {
                                            if (!overlayPagesStack.visitedPages[overlayPagesStack.preloadIndex]) {
                                                overlayPagesStack.visitedPages[overlayPagesStack.preloadIndex] = true
                                                overlayPagesStack.visitedPagesChanged()
                                            }
                                            overlayPagesStack.preloadIndex++
                                        }
                                        if (overlayPagesStack.preloadIndex >= overlayPages.length) {
                                            overlayPreloadTimer.stop()
                                        }
                                    }
                                }

                                Repeater {
                                    id: overlayPagesRepeater
                                    model: overlayPages.length
                                    delegate: Loader {
                                        id: overlayPageLoader
                                        required property int index
                                        anchors.fill: parent
                                        active: Config.ready && (overlayPagesStack.visitedPages[index] === true)
                                        asynchronous: index !== overlayCurrentPage
                                        source: overlayPages[index].component
                                        visible: index === overlayCurrentPage && status === Loader.Ready
                                        opacity: visible ? 1 : 0

                                        Behavior on opacity {
                                            enabled: Appearance.animationsEnabled
                                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                        }
                                    }
                                }
                            }

                            // ── Spotlight overlay ──
                            Item {
                                id: spotlightOverlay
                                anchors.fill: parent
                                visible: root.spotlightActive
                                z: 200

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.deactivateSpotlight()
                                }

                                Canvas {
                                    id: spotlightCanvas
                                    anchors.fill: parent

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.fillStyle = Qt.rgba(0, 0, 0, 0.5);
                                        ctx.fillRect(0, 0, width, height);

                                        if (root.spotlightActive && root.spotlightRect.width > 0) {
                                            ctx.globalCompositeOperation = "destination-out";
                                            var r = root.spotlightRect;
                                            var radius = Appearance.rounding.normal;
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
                                        function onSpotlightRectChanged() { spotlightCanvas.requestPaint(); }
                                        function onSpotlightActiveChanged() { spotlightCanvas.requestPaint(); }
                                    }
                                }

                                // Border around cutout
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

                                Timer {
                                    running: root.spotlightActive
                                    interval: 2500
                                    onTriggered: root.deactivateSpotlight()
                                }

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

                // ── Search results overlay ──
                Rectangle {
                    id: overlaySearchResultsOverlay
                    anchors.fill: parent
                    visible: root.overlaySearchText.length > 0
                    color: "transparent"
                    z: 100

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openOverlaySearchResult({})
                    }

                    // Results card
                    Rectangle {
                        id: overlaySearchResultsCard
                        visible: root.overlaySearchResults.length > 0
                        width: Math.min(parent.width - 40, 480)
                        height: Math.min(overlayResultsList.contentHeight + 16, 380)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 56
                        radius: Appearance.rounding.normal
                        color: Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.colors.colLayer1
                        border.width: Appearance.inirEverywhere ? 1 : 1
                        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.m3colors.m3outlineVariant

                        layer.enabled: Appearance.effectsEnabled && !Appearance.auroraEverywhere
                        layer.effect: DropShadow {
                            color: Qt.rgba(0, 0, 0, 0.3)
                            radius: 12
                            samples: 13
                            verticalOffset: 4
                        }

                        ListView {
                            id: overlayResultsList
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            model: root.overlaySearchResults
                            clip: true
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up) {
                                    if (overlayResultsList.currentIndex > 0) {
                                        overlayResultsList.currentIndex--;
                                    } else {
                                        overlaySearchField.forceActiveFocus();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (overlayResultsList.currentIndex < overlayResultsList.count - 1) {
                                        overlayResultsList.currentIndex++;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (overlayResultsList.currentIndex >= 0) {
                                        root.openOverlaySearchResult(root.overlaySearchResults[overlayResultsList.currentIndex]);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openOverlaySearchResult({});
                                    overlaySearchField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            delegate: RippleButton {
                                id: resultItem
                                required property var modelData
                                required property int index

                                width: overlayResultsList.width
                                implicitHeight: 52
                                buttonRadius: Appearance.rounding.small

                                colBackground: ListView.isCurrentItem
                                    ? (Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                      : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                      : Appearance.colors.colLayer2)
                                    : "transparent"
                                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                                                  : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                                  : Appearance.colors.colLayer2

                                Keys.forwardTo: [overlayResultsList]
                                onClicked: root.openOverlaySearchResult(modelData)

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
                                            ? Appearance.colors.colOnLayer1
                                            : Appearance.colors.colPrimary
                                    }

                                    // Text content
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: resultItem.modelData.labelHighlighted || resultItem.modelData.label || resultItem.modelData.pageName || ""
                                            textFormat: Text.StyledText
                                            font {
                                                family: Appearance.font.family.main
                                                pixelSize: Appearance.font.pixelSize.small
                                                weight: Font.Medium
                                            }
                                            color: resultItem.ListView.isCurrentItem
                                                ? Appearance.colors.colOnLayer1
                                                : Appearance.colors.colOnLayer1
                                            elide: Text.ElideRight
                                        }

                                        // Breadcrumb path
                                        Row {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            visible: resultItem.modelData.pageName !== undefined

                                            StyledText {
                                                text: resultItem.modelData.pageName || ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                                opacity: 0.9
                                            }
                                            MaterialSymbol {
                                                visible: resultItem.modelData.section && resultItem.modelData.section !== resultItem.modelData.pageName
                                                text: "chevron_right"
                                                iconSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                                opacity: 0.6
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                visible: resultItem.modelData.section && resultItem.modelData.section !== resultItem.modelData.pageName
                                                text: resultItem.modelData.section || ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                                opacity: 0.9
                                            }
                                        }
                                    }

                                    // Arrow
                                    MaterialSymbol {
                                        text: "arrow_forward"
                                        iconSize: 16
                                        color: Appearance.colors.colSubtext
                                        opacity: resultItem.hovered || resultItem.ListView.isCurrentItem ? 1 : 0
                                    }
                                }
                            }
                        }
                    }

                    // No results indicator
                    Rectangle {
                        visible: root.overlaySearchText.length > 0 && root.overlaySearchResults.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 56
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
                }

                // Escape key handler + Ctrl+F
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (root.spotlightActive) {
                            root.deactivateSpotlight();
                        } else if (root.overlaySearchText.length > 0) {
                            root.openOverlaySearchResult({});
                        } else {
                            GlobalStates.settingsOverlayOpen = false
                        }
                        event.accepted = true
                    } else if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_F) {
                            overlaySearchField.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                            overlayCurrentPage = (overlayCurrentPage + 1) % overlayPages.length
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                            overlayCurrentPage = (overlayCurrentPage - 1 + overlayPages.length) % overlayPages.length
                            event.accepted = true
                        }
                    }
                }

                // Grab focus when opened
                Connections {
                    target: GlobalStates
                    function onSettingsOverlayOpenChanged() {
                        if (GlobalStates.settingsOverlayOpen) {
                            settingsCard.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ── Page definitions (same as settings.qml) ──
    property int overlayCurrentPage: 0

    property var overlayPages: [
        {
            name: Translation.tr("Quick"),
            shortName: "",
            icon: "instant_mix",
            component: Quickshell.shellPath("modules/settings/QuickConfig.qml")
        },
        {
            name: Translation.tr("General"),
            shortName: "",
            icon: "browse",
            component: Quickshell.shellPath("modules/settings/GeneralConfig.qml")
        },
        {
            name: Translation.tr("Bar"),
            shortName: "",
            icon: "toast",
            iconRotation: 180,
            component: Quickshell.shellPath("modules/settings/BarConfig.qml")
        },
        {
            name: Translation.tr("Background"),
            shortName: "",
            icon: "texture",
            component: Quickshell.shellPath("modules/settings/BackgroundConfig.qml")
        },
        {
            name: Translation.tr("Themes"),
            shortName: "",
            icon: "palette",
            component: Quickshell.shellPath("modules/settings/ThemesConfig.qml")
        },
        {
            name: Translation.tr("Interface"),
            shortName: "",
            icon: "bottom_app_bar",
            component: Quickshell.shellPath("modules/settings/InterfaceConfig.qml")
        },
        {
            name: Translation.tr("Services"),
            shortName: "",
            icon: "settings",
            component: Quickshell.shellPath("modules/settings/ServicesConfig.qml")
        },
        {
            name: Translation.tr("Advanced"),
            shortName: "",
            icon: "construction",
            component: Quickshell.shellPath("modules/settings/AdvancedConfig.qml")
        },
        {
            name: Translation.tr("Shortcuts"),
            shortName: "",
            icon: "keyboard",
            component: Quickshell.shellPath("modules/settings/CheatsheetConfig.qml")
        },
        {
            name: Translation.tr("Modules"),
            shortName: "",
            icon: "extension",
            component: Quickshell.shellPath("modules/settings/ModulesConfig.qml")
        },
        {
            name: Translation.tr("Waffle Style"),
            shortName: "",
            icon: "window",
            component: Quickshell.shellPath("modules/settings/WaffleConfig.qml")
        },
        {
            name: Translation.tr("About"),
            shortName: "",
            icon: "info",
            component: Quickshell.shellPath("modules/settings/About.qml")
        }
    ]
}
