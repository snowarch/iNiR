pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.waffle.looks

// Main Windows 11 style settings container
Item {
    id: root
    
    signal closeRequested()
    
    property var pages: []
    property int currentPage: 0
    property bool loadEnabled: true
    // Parent/child currentPage is bidirectional. Delay child writeback until
    // construction finishes so a persisted or command-line page is not reset
    // by this component's initial default value.
    property bool navigationReady: false
    property string searchText: ""
    property var searchResults: []
    property bool navExpanded: width > Looks.dp(760)

    Component.onCompleted: Qt.callLater(() => root.navigationReady = true)
    
    // Complete search index with all individual options + targetLabel for spotlight
    property var searchIndex: [
        { pageIndex: 17, pageName: "Shell Layout", section: "Live shell layout", label: "Edit live", targetLabel: "Edit live", keywords: ["layout", "move", "position", "taskbar", "output", "edit", "live"] },
        { pageIndex: 17, pageName: "Shell Layout", section: "Taskbar placement", label: "Current position", targetLabel: "Current position", keywords: ["layout", "taskbar", "top", "bottom", "position", "reset"] },
        // === Quick (0) ===
        { pageIndex: 0, pageName: "Quick", section: "Wallpaper & Colors", label: "Dark mode", targetLabel: "Dark mode", keywords: ["quick", "dark", "light", "mode", "theme", "scheme"] },
        { pageIndex: 0, pageName: "Quick", section: "Wallpaper & Colors", label: "Per-monitor wallpapers", targetLabel: "Per-monitor wallpapers", keywords: ["quick", "wallpaper", "monitor", "display", "multi-monitor", "per-monitor"] },
        { pageIndex: 0, pageName: "Quick", section: "Wallpaper & Colors", label: "Colors only mode", targetLabel: "Colors only mode", keywords: ["quick", "wallpaper", "colors", "theme source", "preview", "palette"] },
        { pageIndex: 0, pageName: "Quick", section: "Wallpaper & Colors", label: "Color scheme", targetLabel: "Color scheme", keywords: ["quick", "colors", "scheme", "palette", "material", "theme"] },
        { pageIndex: 0, pageName: "Quick", section: "Wallpaper & Colors", label: "Color strength", targetLabel: "Color strength", keywords: ["quick", "wallpaper", "color", "strength", "vivid", "accent"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Show mascot illustration", targetLabel: "Show mascot illustration", keywords: ["mascot", "cat", "girl", "branding", "illustration", "waifu"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Playful companion", targetLabel: "Playful companion", keywords: ["mascot", "companion", "peek", "interactive", "playful", "edge"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Companion visit interval", targetLabel: "Companion visit interval", keywords: ["mascot", "companion", "interval", "frequency", "minutes"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Visit length", targetLabel: "Visit length", keywords: ["mascot", "companion", "duration", "visible", "seconds", "stay"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Slide animation", targetLabel: "Slide animation", keywords: ["mascot", "companion", "animation", "speed", "slide", "appear"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Event reactions", targetLabel: "React to music", keywords: ["mascot", "companion", "reactions", "events", "music", "battery", "notifications", "wallpaper", "screenshot", "gaming", "unlock", "react", "snoop"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Pose for this event", targetLabel: "Pose for this event", keywords: ["mascot", "pose", "image", "override", "custom", "picker"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Only react to real music", targetLabel: "Only react to real music", keywords: ["mascot", "music", "artist", "video", "browser", "detection", "mpris"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Chaos mode", targetLabel: "Chaos mode", keywords: ["mascot", "chaos", "romp", "kick", "bonk", "widgets", "rearrange", "tidy", "physics"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot", label: "Peek now", targetLabel: "Peek now", keywords: ["mascot", "test", "preview", "peek", "try"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot surfaces", label: "Mascot surfaces", targetLabel: "Mascot surfaces", keywords: ["mascot", "surfaces", "where", "empty states", "about", "dashboard", "customize"] },
        { pageIndex: 14, pageName: "Mascot", section: "Mascot surfaces", label: "Dialogs", targetLabel: "Dialogs", keywords: ["mascot", "dialogs", "close", "confirmation", "warning"] },
        { pageIndex: 14, pageName: "Mascot", section: "Kira collection", label: "Kira collection", targetLabel: "Kira collection", keywords: ["mascot", "kira", "collection", "gallery", "archive", "pose", "full body", "animated", "portrait", "chibi", "editorial"] },

        // === AI (15) ===
        { pageIndex: 15, pageName: "AI", section: "Providers & models", label: "AI providers", targetLabel: "Add AI provider", keywords: ["ai", "provider", "model", "api", "key", "endpoint", "ollama", "openrouter", "gemini", "groq", "anthropic", "local", "add", "llm"] },
        { pageIndex: 15, pageName: "AI", section: "Assistant behavior", label: "AI system prompt", targetLabel: "AI system prompt", keywords: ["ai", "prompt", "system", "instructions", "custom", "assistant", "personality"] },
        { pageIndex: 15, pageName: "AI", section: "Assistant behavior", label: "AI tools", targetLabel: "AI tools", keywords: ["ai", "tool", "functions", "search", "temperature", "creativity"] },
        { pageIndex: 15, pageName: "AI", section: "Privacy & policy", label: "Allow AI features", targetLabel: "Allow AI features", keywords: ["ai", "privacy", "policy", "local", "allow", "disable"] },
        { pageIndex: 15, pageName: "AI", section: "Voice input", label: "Voice input", targetLabel: "Voice input", keywords: ["voice", "mic", "microphone", "dictate", "speech", "transcribe", "recording"] },

        { pageIndex: 0, pageName: "Quick", section: "Wallpaper & Colors", label: "Transparency", targetLabel: "Transparency", keywords: ["quick", "transparency", "glass", "blur", "appearance"] },
        { pageIndex: 0, pageName: "Quick", section: "Quick actions", label: "Show reload notifications", targetLabel: "Show reload notifications", keywords: ["quick", "reload", "notifications", "toast", "quickshell", "niri"] },
        { pageIndex: 0, pageName: "Quick", section: "Capture locations", label: "Recordings folder", targetLabel: "Recordings folder", keywords: ["quick", "capture", "record", "recording", "video", "save", "folder", "path"] },
        { pageIndex: 0, pageName: "Quick", section: "Capture locations", label: "Screenshots folder", targetLabel: "Screenshots folder", keywords: ["quick", "capture", "screenshot", "snip", "save", "folder", "path"] },

        // === General (1) ===
        // Audio
        { pageIndex: 1, pageName: "General", section: "Audio", label: "Volume protection", targetLabel: "Volume protection", keywords: ["volume", "sound", "audio", "protection", "limit", "hearing", "damage", "loud"] },
        { pageIndex: 1, pageName: "General", section: "Audio", label: "Maximum volume", targetLabel: "Maximum volume", keywords: ["volume", "max", "limit", "percent"] },
        { pageIndex: 1, pageName: "General", section: "Audio", label: "Max increase per step", targetLabel: "Max increase per step", keywords: ["volume", "step", "increment"] },
        // Battery
        { pageIndex: 1, pageName: "General", section: "Battery", label: "Low battery warning", targetLabel: "Low battery warning", keywords: ["battery", "low", "warning", "power", "energy"] },
        { pageIndex: 1, pageName: "General", section: "Battery", label: "Critical battery", targetLabel: "Critical battery", keywords: ["battery", "critical", "suspend", "shutdown"] },
        { pageIndex: 1, pageName: "General", section: "Battery", label: "Full battery notification", targetLabel: "Full battery notification", keywords: ["battery", "full", "charged", "notification"] },
        // Time & Language
        { pageIndex: 1, pageName: "General", section: "Time & Language", label: "Show seconds", targetLabel: "Show seconds", keywords: ["time", "clock", "seconds", "format"] },
        { pageIndex: 1, pageName: "General", section: "Time & Language", label: "Long date format", targetLabel: "Long date format", keywords: ["date", "format", "long", "weekday", "month", "clock", "taskbar"] },
        { pageIndex: 1, pageName: "General", section: "Time & Language", label: "Short date format", targetLabel: "Short date format", keywords: ["date", "format", "short", "compact", "clock", "calendar"] },
        { pageIndex: 1, pageName: "General", section: "Time & Language", label: "Language", targetLabel: "Language", keywords: ["language", "locale", "translation", "idioma", "español", "english"] },
        // Keyboard indicators
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Keyboard popups", targetLabel: "Keyboard popups", keywords: ["keyboard", "caps", "num", "layout", "language", "popup", "indicator"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Layout popup", targetLabel: "Layout popup", keywords: ["keyboard", "layout", "language", "popup", "indicator", "show", "hide"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Caps Lock popup", targetLabel: "Caps Lock popup", keywords: ["keyboard", "caps", "capslock", "lock", "popup", "indicator", "show", "hide"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Num Lock popup", targetLabel: "Num Lock popup", keywords: ["keyboard", "num", "numlock", "lock", "popup", "indicator", "show", "hide"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Keyboard panel indicators", targetLabel: "Keyboard panel indicators", keywords: ["keyboard", "caps", "num", "layout", "language", "bar", "taskbar", "indicator"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Layout indicator", targetLabel: "Layout indicator", keywords: ["keyboard", "layout", "language", "indicator", "bar", "taskbar", "show", "hide"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Caps Lock indicator", targetLabel: "Caps Lock indicator", keywords: ["keyboard", "caps", "capslock", "lock", "indicator", "bar", "taskbar", "show", "hide"] },
        { pageIndex: 1, pageName: "General", section: "Keyboard indicators", label: "Num Lock indicator", targetLabel: "Num Lock indicator", keywords: ["keyboard", "num", "numlock", "lock", "indicator", "bar", "taskbar", "show", "hide"] },
        // Window Management
        { pageIndex: 1, pageName: "General", section: "Window Management", label: "Confirm before closing", targetLabel: "Confirm before closing", keywords: ["close", "confirm", "window", "dialog", "super+q"] },
        { pageIndex: 1, pageName: "General", section: "Window Management", label: "Auto-expand a single tiling window", targetLabel: "Auto-expand a single tiling window", keywords: ["niri", "window", "tiling", "maximize", "expand", "single", "column"] },
        // Sounds
        { pageIndex: 1, pageName: "General", section: "Sounds", label: "Battery sounds", targetLabel: "Battery sounds", keywords: ["sound", "audio", "battery", "beep"] },
        { pageIndex: 1, pageName: "General", section: "Sounds", label: "Sound volume", targetLabel: "Sound volume", keywords: ["sound", "volume", "audio", "loudness"] },
        { pageIndex: 1, pageName: "General", section: "Sounds", label: "Notification sounds", targetLabel: "Notification sounds", keywords: ["sound", "audio", "notification", "alert"] },
        { pageIndex: 1, pageName: "General", section: "Event sounds", label: "Event sounds", targetLabel: "Event sounds", keywords: ["sound", "audio", "event", "custom", "theme", "notification", "battery", "timer", "pomodoro"] },
        // Idle & Sleep
        { pageIndex: 1, pageName: "General", section: "Idle & Sleep", label: "Screen off timeout", targetLabel: "Screen off timeout", keywords: ["screen", "off", "timeout", "idle", "dpms", "monitor"] },
        { pageIndex: 1, pageName: "General", section: "Idle & Sleep", label: "Lock timeout", targetLabel: "Lock timeout", keywords: ["lock", "timeout", "idle", "security"] },
        { pageIndex: 1, pageName: "General", section: "Idle & Sleep", label: "Suspend timeout", targetLabel: "Suspend timeout", keywords: ["suspend", "sleep", "timeout", "idle", "hibernate"] },
        { pageIndex: 1, pageName: "General", section: "Idle & Sleep", label: "Lock before sleep", targetLabel: "Lock before sleep", keywords: ["lock", "sleep", "suspend", "security"] },
        // Game Mode
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Auto-detect fullscreen", targetLabel: "Auto-detect fullscreen", keywords: ["game", "gaming", "fullscreen", "auto", "detect"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Disable animations", targetLabel: "Disable animations", keywords: ["game", "gaming", "animations", "performance"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Disable effects", targetLabel: "Disable effects", keywords: ["game", "gaming", "effects", "blur", "shadows", "performance"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Disable Niri animations", targetLabel: "Disable Niri animations", keywords: ["game", "gaming", "niri", "compositor", "animations"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Disable Discover overlay", targetLabel: "Disable Discover overlay", keywords: ["game", "gaming", "discover", "overlay", "discord", "performance"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Minimal mode", targetLabel: "Minimal mode", keywords: ["game", "gaming", "minimal", "lightweight", "performance", "shell"] },
        { pageIndex: 16, pageName: "Effects", section: "Blur and glass", label: "Default blur backend", targetLabel: "Default blur backend", keywords: ["effects", "blur", "backend", "wallpaper", "compositor", "style", "glass"] },
        { pageIndex: 16, pageName: "Effects", section: "Blur and glass", label: "Allow compositor blur", targetLabel: "Allow compositor blur", keywords: ["performance", "native", "blur", "niri", "gpu", "compositor", "glass"] },
        { pageIndex: 16, pageName: "Effects", section: "Per-area overrides", label: "Bars", targetLabel: "Bars", keywords: ["effects", "bar", "area", "blur"] },
        { pageIndex: 16, pageName: "Effects", section: "Per-area overrides", label: "Dock", targetLabel: "Dock", keywords: ["effects", "dock", "area", "blur"] },
        { pageIndex: 16, pageName: "Effects", section: "Per-area overrides", label: "Islands and Ricelin", targetLabel: "Islands and Ricelin", keywords: ["effects", "islands", "ricelin", "pill", "blur"] },
        { pageIndex: 16, pageName: "Effects", section: "Motion and power", label: "Reduce animations", targetLabel: "Reduce animations", keywords: ["motion", "animation", "reduce", "accessibility", "performance"] },
        { pageIndex: 16, pageName: "Effects", section: "Motion and power", label: "Notify when a restart would free memory", targetLabel: "Notify when a restart would free memory", keywords: ["performance", "memory", "leak", "notification", "warning", "restart", "watchdog"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Suppress notifications", targetLabel: "Suppress notifications", keywords: ["game", "gaming", "notifications", "suppress", "hide", "popup", "silent"] },
        { pageIndex: 1, pageName: "General", section: "Game Mode", label: "Hide reload toasts", targetLabel: "Hide reload toasts", keywords: ["game", "gaming", "reload", "toast", "notifications", "suppress"] },
        
        // === Taskbar (2) ===
        { pageIndex: 2, pageName: "Taskbar", section: "Position & Layout", label: "Bottom position", targetLabel: "Bottom position", keywords: ["taskbar", "bar", "position", "bottom", "top"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Position & Layout", label: "Left-align apps", targetLabel: "Left-align apps", keywords: ["taskbar", "align", "left", "center", "apps"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Icons", label: "Tint app icons", targetLabel: "Tint app icons", keywords: ["taskbar", "icons", "tint", "monochrome", "accent", "color"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Icons", label: "Tint tray icons", targetLabel: "Tint tray icons", keywords: ["tray", "icons", "tint", "system", "monochrome"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Desktop Peek", label: "Enable hover peek", targetLabel: "Enable hover peek", keywords: ["desktop", "peek", "hover", "show", "corner"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Desktop Peek", label: "Hover delay", targetLabel: "Hover delay", keywords: ["desktop", "peek", "delay", "timeout"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Clock & Notifications", label: "Show seconds", targetLabel: "Show seconds", keywords: ["clock", "seconds", "time", "taskbar"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Clock & Notifications", label: "Show unread count", targetLabel: "Show unread count", keywords: ["notification", "badge", "count", "unread", "clock"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Clock & Notifications", label: "Activation watermark", targetLabel: "Activation watermark", keywords: ["taskbar", "activation", "watermark", "activate", "windows"] },
        
        // === Background (3) ===
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Use Material ii wallpaper", targetLabel: "Use Material ii wallpaper", keywords: ["wallpaper", "background", "material", "share", "image"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Waffle wallpaper", targetLabel: "Waffle wallpaper", keywords: ["wallpaper", "background", "waffle", "change", "image"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Per-monitor wallpapers", targetLabel: "Per-monitor wallpapers", keywords: ["wallpaper", "background", "monitor", "display", "multi-monitor", "per-monitor"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Hide main wallpaper in fullscreen", targetLabel: "Hide main wallpaper in fullscreen", keywords: ["wallpaper", "background", "fullscreen", "hide", "gaming", "performance", "backdrop", "task view"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Wallpaper scaling", targetLabel: "Wallpaper scaling", keywords: ["wallpaper", "background", "scaling", "fill", "fit", "center"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Enable blur", targetLabel: "Enable blur", keywords: ["blur", "wallpaper", "background", "effect"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Blur radius", targetLabel: "Blur radius", keywords: ["blur", "radius", "intensity"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Dim overlay", targetLabel: "Dim overlay", keywords: ["dim", "dark", "darken", "overlay", "wallpaper"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Extra dim with windows", targetLabel: "Extra dim with windows", keywords: ["dim", "dynamic", "windows", "wallpaper"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Transitions", label: "Enable wallpaper transitions", targetLabel: "Enable wallpaper transitions", keywords: ["wallpaper", "background", "transition", "animation"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Transitions", label: "Transition style", targetLabel: "Transition style", keywords: ["wallpaper", "background", "transition", "style", "fade", "wipe", "wave"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Transitions", label: "Transition direction", targetLabel: "Transition direction", keywords: ["wallpaper", "background", "transition", "direction", "left", "right", "top", "bottom"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Transitions", label: "Transition duration", targetLabel: "Transition duration", keywords: ["wallpaper", "background", "transition", "duration", "speed"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Enable clock", targetLabel: "Enable clock", keywords: ["background", "desktop", "clock", "wallpaper", "widget"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Placement", targetLabel: "Placement", keywords: ["background", "desktop", "clock", "placement", "least busy", "most busy", "draggable"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Reset free position", targetLabel: "Reset free position", keywords: ["background", "desktop", "clock", "position", "reset", "center", "draggable"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Clock style", targetLabel: "Clock style", keywords: ["background", "desktop", "clock", "style", "hero", "balanced", "minimal"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Time format", targetLabel: "Time format", keywords: ["background", "desktop", "clock", "time", "format", "12-hour", "24-hour"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Show seconds", targetLabel: "Show seconds", keywords: ["background", "desktop", "clock", "seconds", "precision"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Show date", targetLabel: "Show date", keywords: ["background", "desktop", "clock", "date", "calendar"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Date style", targetLabel: "Date style", keywords: ["background", "desktop", "clock", "date", "weekday", "numeric", "minimal"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Color tone", targetLabel: "Color tone", keywords: ["background", "desktop", "clock", "color", "tone", "adaptive", "accent", "plain"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Animate time change", targetLabel: "Animate time change", keywords: ["background", "desktop", "clock", "animate", "time"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Clock dim", targetLabel: "Clock dim", keywords: ["background", "desktop", "clock", "dim", "opacity"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Time scale", targetLabel: "Time scale", keywords: ["background", "desktop", "clock", "time", "scale", "size"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Date scale", targetLabel: "Date scale", keywords: ["background", "desktop", "clock", "date", "scale", "size"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Show shadow", targetLabel: "Show shadow", keywords: ["background", "desktop", "clock", "shadow", "contrast"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Show lock status", targetLabel: "Show lock status", keywords: ["background", "desktop", "clock", "lock", "status", "locked"] },
        { pageIndex: 3, pageName: "Background", section: "Desktop Clock", label: "Clock font", targetLabel: "Clock font", keywords: ["background", "desktop", "clock", "font", "segoe", "inter", "roboto"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Enable backdrop", targetLabel: "Enable backdrop", keywords: ["backdrop", "overview", "background"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Use separate wallpaper", targetLabel: "Use separate wallpaper", keywords: ["backdrop", "wallpaper", "separate", "different"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop wallpaper", targetLabel: "Backdrop wallpaper", keywords: ["backdrop", "wallpaper", "change", "overview"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Derive theme colors from backdrop", targetLabel: "Derive theme colors from backdrop", keywords: ["backdrop", "theme", "colors", "wallpaper", "material you"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Hide main wallpaper", targetLabel: "Hide main wallpaper", keywords: ["backdrop", "wallpaper", "hide", "main"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop blur", targetLabel: "Backdrop blur", keywords: ["backdrop", "blur", "radius"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop dim", targetLabel: "Backdrop dim", keywords: ["backdrop", "dim", "dark"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop saturation", targetLabel: "Backdrop saturation", keywords: ["backdrop", "saturation", "color", "vibrant"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop contrast", targetLabel: "Backdrop contrast", keywords: ["backdrop", "contrast"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Enable vignette", targetLabel: "Enable vignette", keywords: ["backdrop", "vignette", "edges", "gradient"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Vignette intensity", targetLabel: "Vignette intensity", keywords: ["backdrop", "vignette", "intensity", "dark"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Vignette radius", targetLabel: "Vignette radius", keywords: ["backdrop", "vignette", "radius", "edges"] },
        
        // === Themes (4) ===
        { pageIndex: 4, pageName: "Themes", section: "Color Theme", label: "Color Theme", targetLabel: "Color Theme", keywords: ["theme", "color", "preset", "gruvbox", "catppuccin", "nord", "dracula", "monokai", "tokyo"] },
        { pageIndex: 4, pageName: "Themes", section: "Dark Mode", label: "Appearance", targetLabel: "Appearance", keywords: ["dark", "light", "mode", "theme", "appearance"] },
        { pageIndex: 4, pageName: "Themes", section: "Color Scheme", label: "Palette type", targetLabel: "Palette type", keywords: ["palette", "scheme", "material you", "material", "colors", "expressive", "fidelity"] },
        { pageIndex: 4, pageName: "Themes", section: "Cava Options", label: "Cava palette and response", targetLabel: "Color source", keywords: ["cava", "visualizer", "spectrum", "audio", "palette", "vibrant", "album", "cover", "sensitivity", "bars", "framerate", "stereo", "wave", "opacity", "reset"] },
        { pageIndex: 4, pageName: "Themes", section: "Waffle Typography", label: "Font family", targetLabel: "Font family", keywords: ["font", "family", "typography", "segoe", "inter", "roboto", "noto"] },
        { pageIndex: 4, pageName: "Themes", section: "Waffle Typography", label: "Font scale", targetLabel: "Font scale", keywords: ["font", "size", "scale", "typography", "bigger", "smaller"] },
        
        // === Gowall (5) ===
        { pageIndex: 5, pageName: "Gowall", section: "Source Image", label: "Source image", targetLabel: "Source image", keywords: ["gowall", "wallpaper", "image", "source", "browse"] },
        { pageIndex: 5, pageName: "Gowall", section: "Source Image", label: "Use current wallpaper", targetLabel: "Use current wallpaper", keywords: ["gowall", "wallpaper", "current"] },
        { pageIndex: 5, pageName: "Gowall", section: "Operation", label: "Recolor", targetLabel: "Operation", keywords: ["gowall", "recolor", "convert", "palette", "theme"] },
        { pageIndex: 5, pageName: "Gowall", section: "Operation", label: "Effects", targetLabel: "Operation", keywords: ["gowall", "effects", "grayscale", "flip", "mirror", "brightness"] },
        { pageIndex: 5, pageName: "Gowall", section: "Operation", label: "Invert", targetLabel: "Operation", keywords: ["gowall", "invert", "colors", "negative"] },
        { pageIndex: 5, pageName: "Gowall", section: "Operation", label: "Pixelate", targetLabel: "Operation", keywords: ["gowall", "pixelate", "pixel", "8bit"] },
        { pageIndex: 5, pageName: "Gowall", section: "Operation", label: "Upscale", targetLabel: "Operation", keywords: ["gowall", "upscale", "ai", "esrgan", "quality"] },
        { pageIndex: 5, pageName: "Gowall", section: "Color Scheme Source", label: "Built-in theme", targetLabel: "Color Scheme Source", keywords: ["gowall", "builtin", "theme", "catppuccin", "nord", "gruvbox"] },
        { pageIndex: 5, pageName: "Gowall", section: "Color Scheme Source", label: "iNiR theme", targetLabel: "Color Scheme Source", keywords: ["gowall", "inir", "palette", "material you"] },
        { pageIndex: 5, pageName: "Gowall", section: "Color Scheme Source", label: "Custom palette", targetLabel: "Color Scheme Source", keywords: ["gowall", "custom", "palette", "colors"] },
        { pageIndex: 5, pageName: "Gowall", section: "Output", label: "Format", targetLabel: "Format", keywords: ["gowall", "output", "format", "png", "webp", "jpg"] },
        { pageIndex: 5, pageName: "Gowall", section: "Extract Palette", label: "Extract colors", targetLabel: "Extract colors", keywords: ["gowall", "extract", "palette", "colors", "picker"] },
        
        // === Interface (6) ===
        { pageIndex: 6, pageName: "Interface", section: "Notifications", label: "Normal timeout", targetLabel: "Normal timeout", keywords: ["notification", "timeout", "duration", "normal"] },
        { pageIndex: 6, pageName: "Interface", section: "Notifications", label: "Low priority timeout", targetLabel: "Low priority timeout", keywords: ["notification", "timeout", "low", "priority"] },
        { pageIndex: 6, pageName: "Interface", section: "Notifications", label: "Critical timeout", targetLabel: "Critical timeout", keywords: ["notification", "timeout", "critical", "urgent"] },
        { pageIndex: 6, pageName: "Interface", section: "Notifications", label: "Ignore app timeout", targetLabel: "Ignore app timeout", keywords: ["notification", "timeout", "app", "ignore", "override"] },
        { pageIndex: 6, pageName: "Interface", section: "Notifications", label: "Popup position", targetLabel: "Popup position", keywords: ["notification", "position", "popup", "corner", "top", "bottom", "left", "right"] },
        { pageIndex: 6, pageName: "Interface", section: "Notifications", label: "Do Not Disturb", targetLabel: "Do Not Disturb", keywords: ["notification", "dnd", "silent", "mute", "disturb", "quiet"] },
        { pageIndex: 6, pageName: "Interface", section: "On-Screen Display", label: "Media OSD", targetLabel: "Media OSD", keywords: ["osd", "media", "music", "player", "shortcuts", "pill", "track", "game", "automatic", "skip"] },
        { pageIndex: 6, pageName: "Interface", section: "On-Screen Display", label: "OSD timeout", targetLabel: "OSD timeout", keywords: ["osd", "volume", "brightness", "media", "timeout", "duration"] },
        { pageIndex: 6, pageName: "Interface", section: "Floating tools (Super+G)", label: "Floating tools (Super+G)", targetLabel: "Floating tools (Super+G)", keywords: ["super+g", "super g", "overlay", "floating", "tools", "widgets", "desktop", "notes", "image", "crosshair", "mixer", "resources", "fps", "recorder"] },
        { pageIndex: 6, pageName: "Interface", section: "Screen Recording", label: "Recording audio", targetLabel: "Recording audio", keywords: ["screen", "record", "recording", "video", "capture", "wf-recorder", "audio", "system sound", "desktop audio", "microphone", "mic", "mix", "pipewire"] },
        { pageIndex: 6, pageName: "Interface", section: "Screen Recording", label: "Recordings folder", targetLabel: "Recordings folder", keywords: ["screen", "record", "recording", "video", "save", "folder", "path", "destination"] },
        { pageIndex: 6, pageName: "Interface", section: "Screen Recording", label: "Screenshots folder", targetLabel: "Screenshots folder", keywords: ["screenshot", "snip", "capture", "save", "folder", "path", "destination"] },
        { pageIndex: 6, pageName: "Interface", section: "Lock Screen", label: "Enable blur", targetLabel: "Enable blur", keywords: ["lock", "screen", "blur", "background"] },
        { pageIndex: 6, pageName: "Interface", section: "Lock Screen", label: "Blur radius", targetLabel: "Blur radius", keywords: ["lock", "screen", "blur", "radius"] },
        { pageIndex: 6, pageName: "Interface", section: "Lock Screen", label: "Center clock", targetLabel: "Center clock", keywords: ["lock", "screen", "clock", "center", "position"] },
        { pageIndex: 6, pageName: "Interface", section: "Lock Screen", label: "Show 'Locked' text", targetLabel: "Show 'Locked' text", keywords: ["lock", "screen", "text", "locked"] },
        { pageIndex: 6, pageName: "Interface", section: "Screen Corners", label: "Fake rounded corners", targetLabel: "Fake rounded corners", keywords: ["screen", "corners", "rounded", "rounding", "fake"] },
        
        // === Modules (7) ===
        { pageIndex: 7, pageName: "Modules", section: "Panel Style", label: "Panel family", targetLabel: "Panel family", keywords: ["panel", "family", "style", "material", "waffle", "windows"] },
        { pageIndex: 7, pageName: "Modules", section: "Sidebars", label: "Arrange sidebar sections", targetLabel: "Sidebars", keywords: ["sidebar", "right", "arrange", "order", "sections", "resize", "notifications", "widgets"] },
        { pageIndex: 7, pageName: "Modules", section: "Sidebars", label: "Arrange sidebar tabs", targetLabel: "Sidebars", keywords: ["sidebar", "left", "arrange", "order", "tabs", "drag", "ai"] },
        { pageIndex: 7, pageName: "Modules", section: "Sidebars", label: "Collapse notifications when empty", targetLabel: "Sidebars", keywords: ["sidebar", "right", "notifications", "collapse", "empty", "fit", "height"] },
        { pageIndex: 7, pageName: "Modules", section: "Sidebars", label: "Fit left sidebar to widgets", targetLabel: "Sidebars", keywords: ["sidebar", "left", "widgets", "fit", "collapse", "height"] },
        { pageIndex: 7, pageName: "Modules", section: "Material Modules in Waffle", label: "Left Sidebar", targetLabel: "Left Sidebar", keywords: ["sidebar", "left", "ai", "chat", "translator"] },
        { pageIndex: 7, pageName: "Modules", section: "Material Modules in Waffle", label: "Right Sidebar", targetLabel: "Right Sidebar", keywords: ["sidebar", "right", "quick", "settings", "calendar"] },
        { pageIndex: 7, pageName: "Modules", section: "Material Modules in Waffle", label: "Dock", targetLabel: "Dock", keywords: ["dock", "macos", "pinned", "apps"] },
        { pageIndex: 7, pageName: "Modules", section: "Material Modules in Waffle", label: "Media Controls Overlay", targetLabel: "Media Controls Overlay", keywords: ["media", "controls", "overlay", "music", "player"] },
        { pageIndex: 7, pageName: "Modules", section: "Material Modules in Waffle", label: "Screen Corners", targetLabel: "Screen Corners", keywords: ["screen", "corners", "hot", "rounded"] },
        { pageIndex: 7, pageName: "Modules", section: "Waffle Modules", label: "Widgets Panel", targetLabel: "Widgets Panel", keywords: ["widgets", "panel", "weather", "system", "media"] },
        { pageIndex: 7, pageName: "Modules", section: "Waffle Modules", label: "Desktop Backdrop", targetLabel: "Desktop Backdrop", keywords: ["backdrop", "desktop", "overview", "blur"] },
        
        // === Waffle Style (8) ===
        { pageIndex: 8, pageName: "Waffle Style", section: "Theming", label: "Use Material colors", targetLabel: "Use Material colors", keywords: ["material", "colors", "theme", "grey", "accent"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Style", targetLabel: "Style", keywords: ["alt", "tab", "switcher", "style", "thumbnails", "cards", "compact", "list"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Quick switch", targetLabel: "Quick switch", keywords: ["alt", "tab", "quick", "switch", "fast"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Most recent first", targetLabel: "Most recent first", keywords: ["alt", "tab", "recent", "order", "mru"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Auto-hide", targetLabel: "Auto-hide", keywords: ["alt", "tab", "auto", "hide", "timeout"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Auto-hide delay", targetLabel: "Auto-hide delay", keywords: ["alt", "tab", "auto", "hide", "delay", "timeout"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Behavior", label: "Allow multiple panels open", targetLabel: "Allow multiple panels open", keywords: ["panels", "multiple", "open", "start", "action"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Behavior", label: "Smoother menu animations", targetLabel: "Smoother menu animations", keywords: ["menu", "animations", "smooth", "popup"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Widgets Panel", label: "Show date & time", targetLabel: "Show date & time", keywords: ["widgets", "date", "time", "clock"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Widgets Panel", label: "Show weather", targetLabel: "Show weather", keywords: ["widgets", "weather", "temperature", "forecast"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Widgets Panel", label: "Show system info", targetLabel: "Show system info", keywords: ["widgets", "system", "info", "cpu", "ram", "memory"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Widgets Panel", label: "Show media controls", targetLabel: "Show media controls", keywords: ["widgets", "media", "controls", "music", "player"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Widgets Panel", label: "Show quick actions", targetLabel: "Show quick actions", keywords: ["widgets", "quick", "actions", "buttons"] },
        { pageIndex: 8, pageName: "Waffle Style", section: "Calendar", label: "Force 2-char day names", targetLabel: "Force 2-char day names", keywords: ["calendar", "day", "names", "short", "2char"] },
        
        // === Shortcuts (9) ===
        { pageIndex: 9, pageName: "Shortcuts", section: "", label: "Keyboard Shortcuts", targetLabel: "", keywords: ["shortcuts", "keybinds", "hotkeys", "keyboard", "niri", "super", "mod"] },
        
        // === About (10) ===
        { pageIndex: 10, pageName: "About", section: "", label: "About ii", targetLabel: "", keywords: ["about", "version", "credits", "github", "info"] },

        // === Monitors (11) ===
        { pageIndex: 11, pageName: "Monitors", section: "Shell visibility", label: "Primary monitor", targetLabel: "Primary monitor", keywords: ["monitor", "screen", "display", "primary", "output", "fallback"] },
        { pageIndex: 11, pageName: "Monitors", section: "Overview placement", label: "Active screen only", targetLabel: "Active screen only", keywords: ["overview", "monitor", "screen", "focused", "active", "output"] },
        { pageIndex: 11, pageName: "Monitors", section: "Waffle shell surfaces", label: "Taskbar", targetLabel: "Taskbar", keywords: ["monitor", "screen", "display", "bar", "taskbar", "visibility"] },
        { pageIndex: 11, pageName: "Monitors", section: "Popups", label: "Notification popups", targetLabel: "Notification popups", keywords: ["monitor", "screen", "display", "notifications", "popups", "visibility"] },
        { pageIndex: 11, pageName: "Monitors", section: "Desktop widgets", label: "Desktop widgets", targetLabel: "Desktop widgets", keywords: ["monitor", "screen", "display", "desktop", "widgets", "layout", "visibility"] },
        { pageIndex: 11, pageName: "Monitors", section: "Popups", label: "OSD indicators", targetLabel: "OSD indicators", keywords: ["monitor", "screen", "display", "media", "osd", "volume", "brightness", "visibility"] }
    ]
    
    function highlightTerms(text: string, terms: list<string>): string {
        if (!text || !terms || terms.length === 0) return text;
        var result = text;
        for (var i = 0; i < terms.length; i++) {
            var term = terms[i];
            var idx = result.toLowerCase().indexOf(term.toLowerCase());
            if (idx >= 0) {
                var original = result.substring(idx, idx + term.length);
                result = result.substring(0, idx) + "<b>" + original + "</b>" + result.substring(idx + term.length);
            }
        }
        return result;
    }
    
    function recomputeSearchResults(): void {
        var q = String(searchText || "").toLowerCase().trim();
        if (!q.length) {
            searchResults = [];
            return;
        }
        
        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var results = [];
        
        // Runtime gate checks — items inside conditionally-visible sections
        var clockEnabled = Config.options?.waffles?.background?.widgets?.clock?.enable ?? false
        var blurEnabled = Config.options?.waffles?.background?.effects?.enableBlur ?? false
        var backdropEnabled = Config.options?.waffles?.background?.backdrop?.enable ?? true
        var vignetteEnabled = Config.options?.waffles?.background?.backdrop?.vignetteEnabled ?? false
        
        for (var i = 0; i < searchIndex.length; i++) {
            var entry = searchIndex[i];
            
            // Skip Desktop Clock sub-options when the clock is disabled.
            if (entry.section === "Desktop Clock" && entry.label !== "Enable clock" && !clockEnabled) {
                continue;
            }
            
            // Skip "Blur radius" when blur is disabled (it's hidden by visible: in the card).
            if (entry.section === "Wallpaper Effects" && entry.label === "Blur radius" && !blurEnabled) {
                continue;
            }
            
            // Skip Backdrop sub-options (anything except "Enable backdrop") when backdrop is disabled.
            if (entry.section === "Backdrop (Overview)" && entry.label !== "Enable backdrop" && !backdropEnabled) {
                continue;
            }
            
            // Skip vignette sub-options when vignette is disabled.
            if (entry.section === "Backdrop (Overview)" && (entry.label === "Vignette intensity" || entry.label === "Vignette radius") && !vignetteEnabled) {
                continue;
            }
            
            var label = (entry.label || "").toLowerCase();
            var section = (entry.section || "").toLowerCase();
            var page = (entry.pageName || "").toLowerCase();
            var kw = (entry.keywords || []).join(" ").toLowerCase();
            
            var matchCount = 0;
            var score = 0;
            
            for (var j = 0; j < terms.length; j++) {
                var term = terms[j];
                if (label.indexOf(term) >= 0 || section.indexOf(term) >= 0 || 
                    page.indexOf(term) >= 0 || kw.indexOf(term) >= 0) {
                    matchCount++;
                    if (label.indexOf(term) === 0) score += 800;
                    else if (label.indexOf(term) > 0) score += 400;
                    if (kw.indexOf(term) >= 0) score += 300;
                    if (section.indexOf(term) >= 0) score += 200;
                }
            }
            
            if (matchCount === terms.length) {
                results.push({
                    pageIndex: entry.pageIndex,
                    pageName: entry.pageName,
                    section: entry.section,
                    label: entry.label,
                    labelHighlighted: highlightTerms(entry.label, terms),
                    targetLabel: entry.targetLabel || "",
                    score: score
                });
            }
        }
        
        // Also search in dynamic registry if available
        if (typeof SettingsSearchRegistry !== "undefined") {
            var widgetResults = SettingsSearchRegistry.buildResults(searchText);
            results = results.concat(widgetResults);
        }
        
        results.sort((a, b) => b.score - a.score);
        
        // Remove duplicates
        var seen = {};
        var unique = [];
        for (var k = 0; k < results.length; k++) {
            var key = (results[k].label || "") + "|" + (results[k].section || "");
            if (!seen[key]) {
                seen[key] = true;
                unique.push(results[k]);
            }
        }
        
        searchResults = unique.slice(0, 30);
    }
    
    function openSearchResult(entry: var): void {
        if (entry && entry.pageIndex !== undefined && entry.pageIndex >= 0) {
            currentPage = entry.pageIndex;
            
            // Focus option - try optionId first (dynamic registry), then targetLabel (static index)
            if (typeof SettingsSearchRegistry !== "undefined") {
                if (entry.optionId !== undefined) {
                    // Dynamic registry entry - use optionId
                    const optionId = entry.optionId;
                    Qt.callLater(() => {
                        SettingsSearchRegistry.focusOption(optionId);
                    });
                } else if (entry.targetLabel) {
                    // Static index entry - find widget by label after page loads
                    const targetLabel = entry.targetLabel;
                    spotlightTimer.targetLabel = targetLabel;
                    spotlightTimer.restart();
                }
            }
        }
        
        searchText = "";
        searchInput.text = "";
    }
    
    // Timer to wait for page load before focusing target
    Timer {
        id: spotlightTimer
        interval: 100
        repeat: true
        property string targetLabel: ""
        property int retries: 0
        property int maxRetries: 20  // 2 seconds max wait
        
        onTriggered: {
            if (!targetLabel || typeof SettingsSearchRegistry === "undefined") {
                stop();
                return;
            }
            
            // Find entry by label in registry
            var entries = SettingsSearchRegistry.entries;
            
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].label === targetLabel && entries[i].pageIndex === root.currentPage) {
                    SettingsSearchRegistry.focusOption(entries[i].id);
                    retries = 0;
                    stop();
                    return;
                }
            }
            
            // Retry until found or max retries
            retries++;
            if (retries >= maxRetries) {
                retries = 0;
                stop();
            }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Navigation sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.navExpanded ? Looks.dp(240) : Looks.dp(56)
            color: Looks.colors.bg1Base
            
            Behavior on Layout.preferredWidth {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
            
            ColumnLayout {
                anchors {
                    fill: parent
                    topMargin: Looks.dp(10)
                    bottomMargin: Looks.dp(10)
                    leftMargin: Looks.dp(12)
                    rightMargin: Looks.dp(12)
                }
                spacing: Looks.dp(4)
                
                // Header with app name (expanded)
                Revealer {
                    vertical: true
                    reveal: root.navExpanded
                    Layout.fillWidth: true
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    Layout.bottomMargin: Looks.dp(6)
                    spacing: Looks.dp(10)

                    WUserAvatar {
                        sourceSize: Qt.size(Looks.dp(32), Looks.dp(32))
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        WText {
                            text: Translation.tr("Settings")
                            font.pixelSize: Looks.font.pixelSize.larger
                            font.weight: Looks.font.weight.stronger
                            color: Looks.colors.fg
                        }

                        WText {
                            text: SystemInfo.displayName || SystemInfo.username
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                            elide: Text.ElideRight
                        }
                    }

                    WBorderlessButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])

                        contentItem: FluentIcon {
                            anchors.centerIn: parent
                            icon: "lock-closed"
                            implicitSize: 14
                            color: Looks.colors.subfg
                        }
                    }

                    WBorderlessButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        onClicked: root.closeRequested()
                        
                        contentItem: FluentIcon {
                            anchors.centerIn: parent
                            icon: "dismiss"
                            implicitSize: 14
                            color: Looks.colors.subfg
                        }
                    }
                }
                }
                
                // Subtle separator under header
                Revealer {
                    vertical: true
                    reveal: root.navExpanded
                    Layout.fillWidth: true
                    Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 1
                        color: Looks.settings.stroke
                        opacity: 0.15
                    }
                }
                
                // Header icon (collapsed)
                Revealer {
                    vertical: true
                    reveal: !root.navExpanded
                    Layout.fillWidth: true
                Item {
                    implicitWidth: parent.width
                    implicitHeight: Looks.dp(38)

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "settings"
                        implicitSize: 20
                        color: Looks.colors.subfg
                    }
                }
                }
                
                // Search bar (only when expanded)
                Revealer {
                    vertical: true
                    reveal: root.navExpanded
                    Layout.fillWidth: true
                Rectangle {
                    id: searchBarContainer
                    // Revealer sizes itself from its child's implicit size.
                    implicitWidth: parent.width
                    implicitHeight: Looks.dp(36)
                    radius: Looks.settings.radiusLarge
                    color: searchInput.activeFocus
                        ? Looks.settings.tileHover : Looks.settings.tile
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus
                        ? Looks.colors.accent : Looks.settings.stroke
                    
                      Behavior on border.color {
                          animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                      }
                    
                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 9
                            rightMargin: 9
                        }
                        spacing: 7
                        
                        FluentIcon {
                            icon: "search"
                            implicitSize: 14
                            color: Looks.colors.subfg
                        }
                        
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                color: Looks.colors.fg
                                selectionColor: Looks.colors.accent
                                selectedTextColor: Looks.colors.accentFg
                                font.family: Looks.font.family.ui
                                font.pixelSize: Looks.font.pixelSize.normal
                                clip: true
                                
                                onTextChanged: {
                                    root.searchText = text;
                                    root.recomputeSearchResults();
                                }
                                
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Down && root.searchResults.length > 0) {
                                        searchResultsList.forceActiveFocus();
                                        searchResultsList.currentIndex = 0;
                                        event.accepted = true;
                                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.searchResults.length > 0) {
                                        root.openSearchResult(root.searchResults[0]);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.openSearchResult({});
                                        event.accepted = true;
                                    }
                                }
                            }
                            
                            // Placeholder text (separate element to avoid overlap)
                            WText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: Translation.tr("Find a setting")
                                color: Looks.colors.subfg
                                font.family: Looks.font.family.ui
                                font.pixelSize: Looks.font.pixelSize.normal
                                visible: !searchInput.text
                                opacity: 0.6
                            }
                        }
                        
                        // Clear button
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            visible: searchInput.text.length > 0
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 10  // pill shape
                                color: clearMouse.containsMouse
                                    ? Looks.settings.tileHover : "transparent"
                                
                                FluentIcon {
                                    anchors.centerIn: parent
                                    icon: "dismiss"
                                    implicitSize: 12
                                    color: Looks.colors.subfg
                                }
                                
                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = "";
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
                }
                
                // Search results dropdown
                Revealer {
                    vertical: true
                    reveal: root.searchText.length > 0 && root.searchResults.length > 0
                    Layout.fillWidth: true
                Rectangle {
                    id: searchResultsDropdown
                    // Revealer sizes itself from its child's implicit size.
                    implicitWidth: parent.width
                    implicitHeight: Math.min(
                        (searchResultsList.contentHeight || 0) + Looks.dp(8),
                        Looks.dp(300))
                    radius: Looks.settings.radiusLarge
                    color: Looks.settings.tile
                    border.width: 1
                    border.color: Looks.settings.strokeStrong
                    
                    layer.enabled: Looks.effectsEnabled && searchResultsDropdown.visible
                    layer.effect: DropShadow {
                        color: Looks.colors.shadow
                        radius: 6
                        samples: 7
                        verticalOffset: 2
                    }
                    
                    ListView {
                        id: searchResultsList
                        anchors {
                            fill: parent
                            margins: 4
                        }
                        spacing: 2
                        model: root.searchResults
                        clip: true
                        currentIndex: -1
                        boundsBehavior: Flickable.StopAtBounds
                        
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Up) {
                                if (currentIndex > 0) currentIndex--;
                                else searchInput.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (currentIndex < count - 1) currentIndex++;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (currentIndex >= 0) root.openSearchResult(root.searchResults[currentIndex]);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.openSearchResult({});
                                searchInput.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                        
                        delegate: Rectangle {
                            id: resultDelegate
                            required property var modelData
                            required property int index
                            
                            width: searchResultsList.width
                            height: 44
                            radius: Looks.radius.medium
                            color: {
                                if (ListView.isCurrentItem) return Looks.colors.accent;
                                if (resultMouse.containsMouse) return Looks.settings.tileHover;
                                return "transparent";
                            }
                            
                              Behavior on color {
                                  animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                              }
                            
                            MouseArea {
                                id: resultMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSearchResult(resultDelegate.modelData)
                            }
                            
                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 10
                                
                                // Page icon
                                FluentIcon {
                                    icon: {
                                        var icons = ["home", "settings", "desktop", "image", "color", 
                                                    "apps", "settings-cog-multiple", "desktop", "info"];
                                        return icons[resultDelegate.modelData.pageIndex] || "settings";
                                    }
                                    implicitSize: 16
                                    color: resultDelegate.ListView.isCurrentItem 
                                        ? Looks.colors.accentFg 
                                        : Looks.colors.accent
                                }
                                
                                // Text content
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: resultDelegate.modelData.labelHighlighted || resultDelegate.modelData.label || ""
                                        textFormat: Text.StyledText
                                        font.family: Looks.font.family.ui
                                        font.pixelSize: Looks.font.pixelSize.normal
                                        font.weight: Font.Medium
                                        color: resultDelegate.ListView.isCurrentItem 
                                            ? Looks.colors.accentFg 
                                            : Looks.colors.fg
                                        elide: Text.ElideRight
                                    }
                                    
                                    WText {
                                        Layout.fillWidth: true
                                        text: resultDelegate.modelData.pageName + (resultDelegate.modelData.section ? " › " + resultDelegate.modelData.section : "")
                                        font.pixelSize: Looks.font.pixelSize.small
                                        color: resultDelegate.ListView.isCurrentItem 
                                            ? Looks.colors.accentFg 
                                            : Looks.colors.subfg
                                        elide: Text.ElideRight
                                        opacity: 0.8
                                    }
                                }
                                
                                // Arrow
                                FluentIcon {
                                    icon: "chevron-right"
                                    implicitSize: 12
                                    color: resultDelegate.ListView.isCurrentItem 
                                        ? Looks.colors.accentFg 
                                        : Looks.colors.subfg
                                    opacity: resultMouse.containsMouse || resultDelegate.ListView.isCurrentItem ? 1 : 0
                                    
                                      Behavior on opacity {
                                          animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                                      }
                                }
                            }
                        }
                    }
                }
                }
                
                // No results indicator
                Revealer {
                    vertical: true
                    reveal: root.searchText.length > 0 && root.searchResults.length === 0
                    Layout.fillWidth: true
                Rectangle {
                    implicitWidth: parent.width
                    implicitHeight: noResultsCol.implicitHeight + 16
                    radius: Looks.radius.medium
                    color: Looks.settings.tile

                    ColumnLayout {
                        id: noResultsCol
                        anchors.centerIn: parent
                        spacing: 6

                        MascotImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 88
                            Layout.preferredHeight: 88
                            pose: "settings-judging"
                            surface: "emptyStates"
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            FluentIcon {
                                icon: "search"
                                implicitSize: 14
                                color: Looks.colors.subfg
                            }

                            WText {
                                text: Translation.tr("No results")
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.subfg
                            }
                        }
                    }
                }
                }

                Item { height: Looks.dp(4) }
                
                // Navigation items
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: navColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    
                    ColumnLayout {
                        id: navColumn
                        width: parent.width
                        spacing: Looks.dp(2)
                        
                        Repeater {
                            model: root.pages
                            
                            WSettingsNavItem {
                                required property int index
                                required property var modelData
                                
                                Layout.fillWidth: true
                                text: modelData.name
                                navIcon: modelData.icon
                                selected: root.currentPage === index
                                expanded: root.navExpanded
                                
                                onClicked: root.currentPage = index
                            }
                        }
                    }
                }
                
                // Separator above collapse button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Looks.dp(4)
                    height: 1
                    color: Looks.settings.stroke
                    opacity: 0.15
                }
                
                // Expand/collapse button
                WBorderlessButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Looks.dp(32)
                    
                    contentItem: RowLayout {
                        spacing: Looks.dp(10)
                        
                        Item {
                            implicitWidth: Looks.dp(20)
                            implicitHeight: Looks.dp(20)
                            Layout.leftMargin: root.navExpanded ? Looks.dp(12) : 0
                            Layout.fillWidth: !root.navExpanded
                            Layout.alignment: root.navExpanded ? Qt.AlignVCenter : Qt.AlignCenter
                            
                            FluentIcon {
                                anchors.centerIn: parent
                                icon: root.navExpanded ? "panel-left-contract" : "panel-left-expand"
                                implicitSize: Looks.dp(16)
                                color: Looks.colors.subfg
                            }
                        }
                        
                        WText {
                            visible: root.navExpanded
                            Layout.fillWidth: true
                            text: Translation.tr("Collapse")
                            font.pixelSize: Looks.font.pixelSize.normal
                            color: Looks.colors.subfg
                        }
                    }
                    
                    onClicked: root.navExpanded = !root.navExpanded
                }
            }
        }
        
        // Separator — subtle divider
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Looks.settings.stroke
            opacity: 0.2
        }
        
        // Content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Looks.colors.bg0
            
            // Page stack
            Item {
                id: pageStack
                anchors.fill: parent
                
                // Keep only the active page alive. Search navigates to an
                // unloaded page and the targetLabel focus retry waits for it to
                // register its controls.
                property int keepRadius: 0

                 Repeater {
                     id: pageRepeater
                     model: root.pages.length

                     Loader {
                         id: pageLoader
                         required property int index
                         anchors.fill: parent
                         active: root.loadEnabled && Math.abs(index - root.currentPage) <= pageStack.keepRadius
                        asynchronous: index !== root.currentPage
                        source: root.pages[index].component
                        visible: index === root.currentPage && status === Loader.Ready
                        opacity: visible ? 1 : 0
                        // Disabled pages must not intercept mouse events even at opacity 0
                        enabled: visible

                         Behavior on opacity {
                             animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.OutCubic }
                         }

                         Connections {
                             target: pageLoader.item
                             ignoreUnknownSignals: true

                             function onNavigateRequested(pageIndex) {
                                 if (pageIndex < 0 || pageIndex >= root.pages.length)
                                     return

                                 root.currentPage = pageIndex
                             }
                         }
                     }
                 }
             }
         }
     }
    
    // Keyboard shortcut for search
    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: {
            if (!root.navExpanded) root.navExpanded = true;
            searchInput.forceActiveFocus();
        }
    }
}
