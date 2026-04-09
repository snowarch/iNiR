pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * GlobalActions — Modular action registry for keyboard-driven workflows.
 *
 * Provides a unified, categorized catalog of shell actions that can be:
 * - Searched via the overview launcher (action prefix)
 * - Invoked via IPC: `inir globalActions run <actionId> [args]`
 * - Extended by users via scripts in ~/.config/illogical-impulse/actions/
 *
 * Architecture:
 *   Built-in providers (system, appearance, tools, settings) are defined as
 *   JS arrays inside this singleton. User scripts are loaded from disk.
 *   `allActions` is the merged, sorted list consumed by LauncherSearch and SearchWidget.
 *
 * Each action object: { id, name, description, icon, category, keywords[], execute(args) }
 */
Singleton {
    id: root

    // ── Public API ──────────────────────────────────────────────────────
    readonly property var allActions: _rebuildActions()

    function runLauncher(args): void {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir")].concat(args ?? []))
    }

    function fuzzyQuery(query: string): list<var> {
        if (!query || query.trim() === "") return allActions
        const q = query.toLowerCase().trim()
        const scored = allActions.map(action => {
            let score = 0
            const name = (action.name ?? "").toLowerCase()
            const desc = (action.description ?? "").toLowerCase()
            const id = (action.id ?? "").toLowerCase()
            const kw = (action.keywords ?? []).join(" ").toLowerCase()
            // Exact id match
            if (id === q) score += 100
            // Starts with
            if (name.startsWith(q)) score += 60
            if (id.startsWith(q)) score += 50
            // Contains
            if (name.includes(q)) score += 30
            if (desc.includes(q)) score += 15
            if (id.includes(q)) score += 20
            if (kw.includes(q)) score += 10
            // Per-word matching for multi-word queries
            const words = q.split(/\s+/)
            if (words.length > 1) {
                const combined = `${name} ${desc} ${id} ${kw}`
                const matchCount = words.filter(w => combined.includes(w)).length
                score += matchCount * 8
            }
            return { action, score }
        }).filter(item => item.score > 0)
        scored.sort((a, b) => b.score - a.score)
        return scored.map(item => item.action)
    }

    function runById(actionId: string, args: string): bool {
        const action = allActions.find(a => a.id === actionId)
        if (action) {
            action.execute(args ?? "")
            return true
        }
        return false
    }

    function listByCategory(category: string): list<var> {
        if (!category || category === "all") return allActions
        return allActions.filter(a => a.category === category)
    }

    readonly property list<string> categories: [
        "system", "appearance", "tools", "settings", "media", "custom"
    ]

    // ── IPC ─────────────────────────────────────────────────────────────
    IpcHandler {
        target: "globalActions"

        function run(actionId: string, args: string): string {
            if (root.runById(actionId, args ?? ""))
                return "ok"
            return "error: action not found: " + actionId
        }

        function list(category: string): string {
            const actions = root.listByCategory(category ?? "all")
            return actions.map(a => `${a.id}\t${a.category}\t${a.name}`).join("\n")
        }

        function search(query: string): string {
            const results = root.fuzzyQuery(query ?? "")
            return results.map(a => `${a.id}\t${a.category}\t${a.name}`).join("\n")
        }

        function open(): void {
            root.runLauncher(["overview", "actionOpen"])
        }
    }

    // ── Built-in Providers ──────────────────────────────────────────────

    // SYSTEM: WiFi, Bluetooth, Night Light, Game Mode, DND, Lock, Session
    readonly property var _systemActions: [
        {
            id: "toggle-wifi",
            name: Translation.tr("Toggle WiFi"),
            description: Translation.tr("Enable or disable WiFi"),
            icon: "wifi",
            category: "system",
            keywords: ["network", "wireless", "internet", "wifi"],
            execute: () => { Network.toggleWifi() }
        },
        {
            id: "toggle-bluetooth",
            name: Translation.tr("Toggle Bluetooth"),
            description: Translation.tr("Open Bluetooth manager"),
            icon: "bluetooth",
            category: "system",
            keywords: ["bt", "wireless", "devices"],
            execute: () => {
                AppLauncher.launch("bluetooth")
            }
        },
        {
            id: "toggle-nightlight",
            name: Translation.tr("Toggle Night Light"),
            description: Translation.tr("Toggle blue light filter"),
            icon: "nightlight",
            category: "system",
            keywords: ["night", "light", "blue", "filter", "hyprsunset", "redshift"],
            execute: () => { Hyprsunset.toggle() }
        },
        {
            id: "toggle-gamemode",
            name: Translation.tr("Toggle Game Mode"),
            description: Translation.tr("Enable or disable game mode"),
            icon: "sports_esports",
            category: "system",
            keywords: ["game", "performance", "fps"],
            execute: () => { GameMode.toggle() }
        },
        {
            id: "toggle-dnd",
            name: Translation.tr("Toggle Do Not Disturb"),
            description: Translation.tr("Silence notifications"),
            icon: "do_not_disturb_on",
            category: "system",
            keywords: ["dnd", "silent", "notifications", "quiet", "mute"],
            execute: () => { Notifications.toggleSilent() }
        },
        {
            id: "lock-screen",
            name: Translation.tr("Lock Screen"),
            description: Translation.tr("Lock the screen"),
            icon: "lock",
            category: "system",
            keywords: ["lock", "security", "screen"],
            execute: () => {
                root.runLauncher(["lock", "activate"])
            }
        },
        {
            id: "open-session",
            name: Translation.tr("Session Menu"),
            description: Translation.tr("Power off, reboot, logout, suspend"),
            icon: "power_settings_new",
            category: "system",
            keywords: ["power", "shutdown", "reboot", "logout", "suspend", "session"],
            execute: () => {
                root.runLauncher(["session", "open"])
            }
        },
        {
            id: "open-settings",
            name: Translation.tr("Open Settings"),
            description: Translation.tr("Open the shell settings panel"),
            icon: "settings",
            category: "system",
            keywords: ["settings", "config", "preferences", "configure"],
            execute: () => { GlobalStates.settingsOverlayOpen = true }
        },
        {
            id: "open-network-settings",
            name: Translation.tr("Network Settings"),
            description: Translation.tr("Open network connection manager"),
            icon: "lan",
            category: "system",
            keywords: ["network", "wifi", "ethernet", "connection", "nm"],
            execute: () => {
                AppLauncher.launchNetworkSettings(Network.ethernet)
            }
        },
        {
            id: "open-volume-mixer",
            name: Translation.tr("Volume Mixer"),
            description: Translation.tr("Open the system volume mixer"),
            icon: "tune",
            category: "system",
            keywords: ["audio", "sound", "volume", "mixer", "pavucontrol"],
            execute: () => {
                AppLauncher.launch("volumeMixer")
            }
        },
        {
            id: "open-task-manager",
            name: Translation.tr("Task Manager"),
            description: Translation.tr("Open system monitor"),
            icon: "monitoring",
            category: "system",
            keywords: ["task", "process", "monitor", "cpu", "ram", "htop"],
            execute: () => {
                AppLauncher.launch("taskManager")
            }
        },
    ]

    // APPEARANCE: Theme, Dark/Light, Wallpaper, Accent Color, Style
    readonly property var _appearanceActions: [
        {
            id: "dark-mode",
            name: Translation.tr("Switch to Dark Mode"),
            description: Translation.tr("Apply dark color scheme"),
            icon: "dark_mode",
            category: "appearance",
            keywords: ["dark", "theme", "night", "mode"],
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"])
            }
        },
        {
            id: "light-mode",
            name: Translation.tr("Switch to Light Mode"),
            description: Translation.tr("Apply light color scheme"),
            icon: "light_mode",
            category: "appearance",
            keywords: ["light", "theme", "day", "mode"],
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"])
            }
        },
        {
            id: "accent-color",
            name: Translation.tr("Change Accent Color"),
            description: Translation.tr("Set a custom accent color (pass hex code as argument)"),
            icon: "palette",
            category: "appearance",
            keywords: ["accent", "color", "tint", "hue"],
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args !== '' ? [`${args}`] : [])])
            }
        },
        {
            id: "change-wallpaper",
            name: Translation.tr("Change Wallpaper (Grid)"),
            description: Translation.tr("Open the grid wallpaper selector"),
            icon: "wallpaper",
            category: "appearance",
            keywords: ["wallpaper", "background", "wall", "image", "grid"],
            execute: () => {
                root.runLauncher(["coverflowSelector", "close"])
                root.runLauncher(["wallpaperSelector", "open"])
            }
        },
        {
            id: "wallpaper-coverflow",
            name: Translation.tr("Change Wallpaper (Coverflow)"),
            description: Translation.tr("Open the coverflow wallpaper selector"),
            icon: "view_carousel",
            category: "appearance",
            keywords: ["wallpaper", "background", "wall", "coverflow", "carousel"],
            execute: () => {
                root.runLauncher(["wallpaperSelector", "close"])
                root.runLauncher(["coverflowSelector", "open"])
            }
        },
        {
            id: "random-wallpaper",
            name: Translation.tr("Random Wallpaper (Konachan)"),
            description: Translation.tr("Set a random wallpaper from Konachan"),
            icon: "casino",
            category: "appearance",
            keywords: ["wallpaper", "random", "konachan"],
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")])
            }
        },
        {
            id: "style-material",
            name: Translation.tr("Style: Material"),
            description: Translation.tr("Switch to Material style"),
            icon: "format_paint",
            category: "appearance",
            keywords: ["style", "material", "theme"],
            execute: () => { Config.setNestedValue("appearance.globalStyle", "material") }
        },
        {
            id: "style-cards",
            name: Translation.tr("Style: Cards"),
            description: Translation.tr("Switch to Cards style"),
            icon: "dashboard",
            category: "appearance",
            keywords: ["style", "cards", "theme"],
            execute: () => { Config.setNestedValue("appearance.globalStyle", "cards") }
        },
        {
            id: "style-aurora",
            name: Translation.tr("Style: Aurora"),
            description: Translation.tr("Switch to Aurora style"),
            icon: "auto_awesome",
            category: "appearance",
            keywords: ["style", "aurora", "theme", "blur"],
            execute: () => { Config.setNestedValue("appearance.globalStyle", "aurora") }
        },
        {
            id: "style-inir",
            name: Translation.tr("Style: iNiR"),
            description: Translation.tr("Switch to iNiR style"),
            icon: "terminal",
            category: "appearance",
            keywords: ["style", "inir", "theme"],
            execute: () => { Config.setNestedValue("appearance.globalStyle", "inir") }
        },
        {
            id: "style-angel",
            name: Translation.tr("Style: Angel"),
            description: Translation.tr("Switch to Angel style"),
            icon: "stars",
            category: "appearance",
            keywords: ["style", "angel", "theme", "glass"],
            execute: () => { Config.setNestedValue("appearance.globalStyle", "angel") }
        },
    ]

    // TOOLS: Screenshot, Screen Record, Color Picker, Clipboard
    readonly property var _toolActions: [
        {
            id: "screenshot",
            name: Translation.tr("Take Screenshot"),
            description: Translation.tr("Capture a region of the screen"),
            icon: "screenshot_region",
            category: "tools",
            keywords: ["screenshot", "snip", "capture", "screen", "region"],
            execute: () => {
                root.runLauncher(["region", "screenshot"])
            }
        },
        {
            id: "color-picker",
            name: Translation.tr("Color Picker"),
            description: Translation.tr("Pick a color from the screen"),
            icon: "colorize",
            category: "tools",
            keywords: ["color", "picker", "eyedropper", "hex"],
            execute: () => {
                Quickshell.execDetached(["/usr/bin/hyprpicker", "-a"])
            }
        },
        {
            id: "screen-record",
            name: Translation.tr("Toggle Screen Recording"),
            description: Translation.tr("Start or stop screen recording with wf-recorder"),
            icon: "videocam",
            category: "tools",
            keywords: ["record", "screen", "video", "capture", "wf-recorder"],
            execute: () => {
                if (RecorderStatus.isRecording) {
                    Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
                } else {
                    Quickshell.execDetached(["/usr/bin/bash", Directories.recordScriptPath])
                }
            }
        },
        {
            id: "open-clipboard",
            name: Translation.tr("Clipboard History"),
            description: Translation.tr("Open clipboard history manager"),
            icon: "content_paste",
            category: "tools",
            keywords: ["clipboard", "paste", "history", "cliphist", "copy"],
            execute: () => {
                root.runLauncher(["clipboard", "open"])
            }
        },
        {
            id: "music-recognition",
            name: Translation.tr("Recognize Music"),
            description: Translation.tr("Identify the currently playing song"),
            icon: "music_note",
            category: "tools",
            keywords: ["shazam", "recognize", "music", "song", "identify", "songrec"],
            execute: () => { SongRec.toggleRunning() }
        },
        {
            id: "open-notepad",
            name: Translation.tr("Open Notepad"),
            description: Translation.tr("Open the quick notepad in the sidebar"),
            icon: "sticky_note_2",
            category: "tools",
            keywords: ["notepad", "notes", "write", "text", "memo"],
            execute: () => {
                const enabledWidgets = Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer"]
                const notepadIndex = Math.max(0, enabledWidgets.indexOf("notepad"))
                GlobalStates.sidebarRightOpen = true
                if (Persistent?.states?.sidebar?.bottomGroup) {
                    Persistent.states.sidebar.bottomGroup.collapsed = false
                    Persistent.states.sidebar.bottomGroup.tab = notepadIndex
                }
            }
        },
        {
            id: "wipe-clipboard",
            name: Translation.tr("Wipe Clipboard"),
            description: Translation.tr("Clear all clipboard history"),
            icon: "delete_sweep",
            category: "tools",
            keywords: ["clipboard", "clear", "wipe", "history", "cliphist"],
            execute: () => { Cliphist.wipe() }
        },
        {
            id: "superpaste",
            name: Translation.tr("Superpaste"),
            description: Translation.tr("Paste multiple clipboard entries (args: NUM[i] — e.g. 4i for images)"),
            icon: "content_paste_go",
            category: "tools",
            keywords: ["paste", "clipboard", "multi", "superpaste"],
            execute: args => {
                if (!args || !/^(\d+)/.test(args.trim())) {
                    Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Superpaste"),
                        Translation.tr("Usage: superpaste NUM[i]\nExamples: superpaste 4i (last 4 images), superpaste 7 (last 7 entries)"),
                        "-a", "Shell"])
                    return
                }
                const match = /^(?:(\d+)(i)?)/.exec(args.trim())
                const count = match[1] ? parseInt(match[1]) : 1
                const isImage = !!match[2]
                Cliphist.superpaste(count, isImage)
            }
        },
        {
            id: "todo",
            name: Translation.tr("Add Todo"),
            description: Translation.tr("Add a task to the todo list (pass task text as argument)"),
            icon: "checklist",
            category: "tools",
            keywords: ["todo", "task", "add", "note", "reminder"],
            execute: args => {
                if (!args || args.trim() === "") {
                    Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Add Todo"),
                        Translation.tr("Usage: todo <task description>"), "-a", "Shell"])
                    return
                }
                Todo.addTask(args.trim())
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Todo Added"),
                    args.trim(), "-a", "Shell", "-i", "checkbox-checked-symbolic"])
            }
        },
        {
            id: "open-cheatsheet",
            name: Translation.tr("Keyboard Shortcuts"),
            description: Translation.tr("Show keyboard shortcut cheatsheet"),
            icon: "keyboard",
            category: "tools",
            keywords: ["keyboard", "shortcuts", "cheatsheet", "keybinds", "hotkeys"],
            execute: () => {
                root.runLauncher(["cheatsheet", "open"])
            }
        },
        {
            id: "toggle-crosshair",
            name: Translation.tr("Toggle Crosshair"),
            description: Translation.tr("Show or hide the screen crosshair overlay"),
            icon: "my_location",
            category: "tools",
            keywords: ["crosshair", "aim", "overlay"],
            execute: () => { GlobalStates.crosshairOpen = !GlobalStates.crosshairOpen }
        },
    ]

    // MEDIA: Volume, Mute, Brightness, Playback
    readonly property var _mediaActions: [
        {
            id: "media-play-pause",
            name: Translation.tr("Play / Pause"),
            description: Translation.tr("Toggle media playback"),
            icon: "play_pause",
            category: "media",
            keywords: ["play", "pause", "media", "music", "player", "mpris"],
            execute: () => {
                root.runLauncher(["mpris", "playPause"])
            }
        },
        {
            id: "media-next",
            name: Translation.tr("Next Track"),
            description: Translation.tr("Skip to the next track"),
            icon: "skip_next",
            category: "media",
            keywords: ["next", "skip", "track", "media", "forward"],
            execute: () => {
                root.runLauncher(["mpris", "next"])
            }
        },
        {
            id: "media-previous",
            name: Translation.tr("Previous Track"),
            description: Translation.tr("Go to the previous track"),
            icon: "skip_previous",
            category: "media",
            keywords: ["previous", "back", "track", "media", "rewind"],
            execute: () => {
                root.runLauncher(["mpris", "previous"])
            }
        },
        {
            id: "toggle-mute",
            name: Translation.tr("Toggle Mute"),
            description: Translation.tr("Mute or unmute audio output"),
            icon: "volume_off",
            category: "media",
            keywords: ["mute", "audio", "sound", "volume", "speaker"],
            execute: () => { Audio.toggleMute() }
        },
        {
            id: "toggle-mic-mute",
            name: Translation.tr("Toggle Microphone Mute"),
            description: Translation.tr("Mute or unmute microphone"),
            icon: "mic_off",
            category: "media",
            keywords: ["mic", "microphone", "mute", "input"],
            execute: () => { Audio.toggleMicMute() }
        },
        {
            id: "volume-up",
            name: Translation.tr("Volume Up"),
            description: Translation.tr("Increase audio volume"),
            icon: "volume_up",
            category: "media",
            keywords: ["volume", "up", "increase", "louder", "audio"],
            execute: () => { Audio.incrementVolume() }
        },
        {
            id: "volume-down",
            name: Translation.tr("Volume Down"),
            description: Translation.tr("Decrease audio volume"),
            icon: "volume_down",
            category: "media",
            keywords: ["volume", "down", "decrease", "quieter", "audio"],
            execute: () => { Audio.decrementVolume() }
        },
        {
            id: "brightness-up",
            name: Translation.tr("Increase Brightness"),
            description: Translation.tr("Increase screen brightness"),
            icon: "brightness_high",
            category: "media",
            keywords: ["brightness", "screen", "display", "increase"],
            execute: () => { Brightness.increaseBrightness() }
        },
        {
            id: "brightness-down",
            name: Translation.tr("Decrease Brightness"),
            description: Translation.tr("Decrease screen brightness"),
            icon: "brightness_low",
            category: "media",
            keywords: ["brightness", "screen", "display", "decrease"],
            execute: () => { Brightness.decreaseBrightness() }
        },
        {
            id: "toggle-easyeffects",
            name: Translation.tr("Toggle EasyEffects"),
            description: Translation.tr("Enable or disable audio effects"),
            icon: "equalizer",
            category: "media",
            keywords: ["easyeffects", "equalizer", "audio", "effects", "eq"],
            execute: () => { EasyEffects.toggle() }
        },
    ]

    // SETTINGS: Quick config toggles
    readonly property var _settingsActions: [
        {
            id: "toggle-bar-autohide",
            name: Translation.tr("Toggle Bar Auto-hide"),
            description: Translation.tr("Toggle the top bar auto-hide behavior"),
            icon: "vertical_align_top",
            category: "settings",
            keywords: ["bar", "autohide", "hide", "panel"],
            execute: () => {
                const current = Config.options?.bar?.autoHide?.enable ?? false
                Config.setNestedValue("bar.autoHide.enable", !current)
            }
        },
        {
            id: "toggle-dock",
            name: Translation.tr("Toggle Dock"),
            description: Translation.tr("Enable or disable the dock"),
            icon: "dock_to_bottom",
            category: "settings",
            keywords: ["dock", "taskbar", "bottom", "panel"],
            execute: () => {
                const current = Config.options?.dock?.enable ?? true
                Config.setNestedValue("dock.enable", !current)
            }
        },
        {
            id: "toggle-animations",
            name: Translation.tr("Toggle Reduced Animations"),
            description: Translation.tr("Enable or disable reduced animations mode"),
            icon: "animation",
            category: "settings",
            keywords: ["animation", "reduce", "performance", "motion"],
            execute: () => {
                const current = Config.options?.performance?.reduceAnimations ?? false
                Config.setNestedValue("performance.reduceAnimations", !current)
            }
        },
        {
            id: "toggle-low-power",
            name: Translation.tr("Toggle Low Power Mode"),
            description: Translation.tr("Toggle low power mode for battery saving"),
            icon: "battery_saver",
            category: "settings",
            keywords: ["power", "battery", "low", "save", "efficiency"],
            execute: () => {
                const current = Config.options?.performance?.lowPower ?? false
                Config.setNestedValue("performance.lowPower", !current)
            }
        },
        {
            id: "toggle-overview",
            name: Translation.tr("Toggle Overview"),
            description: Translation.tr("Open or close the overview"),
            icon: "overview",
            category: "settings",
            keywords: ["overview", "windows", "workspace"],
            execute: () => {
                root.runLauncher(["overview", "toggle"])
            }
        },
        {
            id: "open-sidebar-left",
            name: Translation.tr("Open Left Sidebar"),
            description: Translation.tr("Open the left sidebar"),
            icon: "side_navigation",
            category: "settings",
            keywords: ["sidebar", "left", "panel"],
            execute: () => {
                root.runLauncher(["sidebarLeft", "open"])
            }
        },
        {
            id: "open-sidebar-right",
            name: Translation.tr("Open Right Sidebar"),
            description: Translation.tr("Open the right sidebar"),
            icon: "right_panel_open",
            category: "settings",
            keywords: ["sidebar", "right", "panel"],
            execute: () => {
                root.runLauncher(["sidebarRight", "open"])
            }
        },
        {
            id: "toggle-osk",
            name: Translation.tr("Toggle On-Screen Keyboard"),
            description: Translation.tr("Show or hide the on-screen keyboard"),
            icon: "keyboard",
            category: "settings",
            keywords: ["osk", "keyboard", "onscreen", "virtual"],
            execute: () => {
                root.runLauncher(["osk", "toggle"])
            }
        },
        {
            id: "zoom-in",
            name: Translation.tr("Zoom In"),
            description: Translation.tr("Increase screen zoom level"),
            icon: "zoom_in",
            category: "settings",
            keywords: ["zoom", "in", "magnify", "increase", "accessibility"],
            execute: () => { GlobalStates.screenZoom = Math.min(GlobalStates.screenZoom + 0.4, 3.0) }
        },
        {
            id: "zoom-out",
            name: Translation.tr("Zoom Out"),
            description: Translation.tr("Decrease screen zoom level"),
            icon: "zoom_out",
            category: "settings",
            keywords: ["zoom", "out", "reduce", "decrease", "accessibility"],
            execute: () => { GlobalStates.screenZoom = Math.max(GlobalStates.screenZoom - 0.4, 1.0) }
        },
        {
            id: "zoom-reset",
            name: Translation.tr("Reset Zoom"),
            description: Translation.tr("Reset screen zoom to 100%"),
            icon: "fit_screen",
            category: "settings",
            keywords: ["zoom", "reset", "100", "normal"],
            execute: () => { GlobalStates.screenZoom = 1.0 }
        },
        {
            id: "switch-family-ii",
            name: Translation.tr("Switch to ii Panel Family"),
            description: Translation.tr("Use the Material ii panel layout"),
            icon: "dashboard",
            category: "settings",
            keywords: ["family", "panel", "ii", "material", "layout"],
            execute: () => {
                root.runLauncher(["panelFamily", "set", "ii"])
            }
        },
        {
            id: "switch-family-waffle",
            name: Translation.tr("Switch to Waffle Panel Family"),
            description: Translation.tr("Use the Windows 11 / Waffle panel layout"),
            icon: "grid_view",
            category: "settings",
            keywords: ["family", "panel", "waffle", "win11", "windows", "layout"],
            execute: () => {
                root.runLauncher(["panelFamily", "set", "waffle"])
            }
        },
        {
            id: "toggle-control-panel",
            name: Translation.tr("Toggle Quick Settings"),
            description: Translation.tr("Open or close the quick settings panel"),
            icon: "toggle_on",
            category: "system",
            keywords: ["control", "panel", "quick", "settings", "toggles", "wifi", "bluetooth"],
            execute: () => {
                root.runLauncher(["controlPanel", "toggle"])
            }
        },
        {
            id: "toggle-media-controls",
            name: Translation.tr("Toggle Media Controls"),
            description: Translation.tr("Open or close fullscreen media controls"),
            icon: "featured_play_list",
            category: "media",
            keywords: ["media", "controls", "fullscreen", "player", "music", "album"],
            execute: () => {
                root.runLauncher(["mediaControls", "toggle"])
            }
        },
        {
            id: "toggle-tiling",
            name: Translation.tr("Toggle Tiling Overlay"),
            description: Translation.tr("Open or close the tiling layout picker"),
            icon: "grid_on",
            category: "tools",
            keywords: ["tiling", "layout", "grid", "snap", "window", "arrange"],
            execute: () => {
                root.runLauncher(["tiling", "toggle"])
            }
        },
    ]

    // PACKAGES: Run package manager commands (supports yay, paru, pacman)
    readonly property var _packageActions: [
        {
            id: "install-package",
            name: Translation.tr("Install Package"),
            description: Translation.tr("Install a package with yay/paru/pacman (pass package name as argument)"),
            icon: "download",
            category: "system",
            keywords: ["install", "package", "yay", "paru", "pacman", "aur", "setup"],
            execute: args => {
                if (!args || args.trim() === "") {
                    Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Install Package"),
                        Translation.tr("Usage: install-package <package-name>"),
                        "-a", "Shell"])
                    return
                }
                const pkg = args.trim()
                PackageSearch.installPackage(pkg, true)
            }
        },
        {
            id: "remove-package",
            name: Translation.tr("Remove Package"),
            description: Translation.tr("Remove a package with pacman (pass package name as argument)"),
            icon: "delete",
            category: "system",
            keywords: ["remove", "uninstall", "package", "pacman"],
            execute: args => {
                if (!args || args.trim() === "") {
                    Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Remove Package"),
                        Translation.tr("Usage: remove-package <package-name>"),
                        "-a", "Shell"])
                    return
                }
                const pkg = args.trim()
                PackageSearch.removePackage(pkg)
            }
        },
        {
            id: "update-system",
            name: Translation.tr("Update System"),
            description: Translation.tr("Run a full system update"),
            icon: "system_update_alt",
            category: "system",
            keywords: ["update", "upgrade", "system", "pacman", "yay", "paru"],
            execute: () => { PackageSearch.updateSystem() }
        },
    ]

    // ── User Script Provider ────────────────────────────────────────────
    property var _userScriptActions: {
        const actions = []
        for (let i = 0; i < userActionsFolder.count; i++) {
            const fileName = userActionsFolder.get(i, "fileName")
            const filePath = userActionsFolder.get(i, "filePath")
            if (fileName && filePath) {
                const actionName = fileName.replace(/\.[^/.]+$/, "")
                const resolvedPath = FileUtils.trimFileProtocol(filePath.toString())
                actions.push({
                    id: `custom-${actionName}`,
                    name: actionName,
                    description: Translation.tr("User script: %1").arg(fileName),
                    icon: "code",
                    category: "custom",
                    keywords: ["custom", "script", "user", actionName],
                    execute: ((path) => (args) => {
                        Quickshell.execDetached([path, ...(args ? args.split(" ") : [])])
                    })(resolvedPath)
                })
            }
        }
        return actions
    }

    FolderListModel {
        id: userActionsFolder
        folder: Qt.resolvedUrl(Directories.userActions)
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    // ── Merge All Providers ─────────────────────────────────────────────
    function _rebuildActions(): list<var> {
        const cfg = Config.options?.search?.globalActions
        let result = []
        if (cfg?.enableSystem ?? true)     result = result.concat(_systemActions)
        if (cfg?.enableAppearance ?? true) result = result.concat(_appearanceActions)
        if (cfg?.enableTools ?? true)      result = result.concat(_toolActions)
        if (cfg?.enableMedia ?? true)      result = result.concat(_mediaActions)
        if (cfg?.enableSettings ?? true)   result = result.concat(_settingsActions)
        if (cfg?.enablePackages ?? true)   result = result.concat(_packageActions)
        if (cfg?.enableCustom ?? true)     result = result.concat(_userScriptActions)
        return result
    }

    // ── Legacy compatibility: action name → execute mapping ─────────────
    // This bridges the old `searchActions` format used by LauncherSearch/SearchWidget
    // so they can consume GlobalActions without rewriting their result building.
    readonly property var searchActions: {
        return allActions.map(a => ({
            action: a.id,
            name: a.name,
            description: a.description,
            icon: a.icon,
            category: a.category,
            keywords: a.keywords,
            execute: a.execute
        }))
    }
}
