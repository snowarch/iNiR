import QtQuick
import Quickshell.Io

// The config schema: every key and what the shell uses when the file doesn't say. Config.qml reads the file into
// one of these.
JsonAdapter {
    // Panel system
    property list<string> enabledPanels: ["iiBar", "iiBackground", "iiBackdrop", "iiCheatsheet", "iiControlPanel", "iiDock", "iiLock", "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard", "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners", "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiTilingOverlay", "iiVerticalBar", "iiWallpaperSelector", "iiWallpaperLauncher", "iiCoverflowSelector", "iiClipboard", "iiShellUpdate", "iiDashboard", "iiMascotCompanion"]
    property list<string> knownPanels: [] // Tracks panels the user has seen; used to distinguish "user disabled" from "new in update"
    property string panelFamily: "ii" // an installed family's id (Plugins.families)
    property bool familyTransitionAnimation: true // Show animated overlay when switching families
    property list<string> familyCycle: ["ii", "waffle", "iris"] // Families the switch shortcut (panelFamily cycle) walks through

    property JsonObject policies: JsonObject {
        property int ai: 0 // 0: No | 1: Yes | 2: Local
        property int weeb: 0 // 0: No | 1: Open | 2: Closet
    }

    property JsonObject ai: JsonObject {
        property string systemPrompt: "## Style\n- Use casual tone, don't be formal! Make sure you answer precisely without hallucination and prefer bullet points over walls of text. You can have a friendly greeting at the beginning of the conversation, but don't repeat the user's question\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a {DISTRO} Linux system\n- Desktop environment: {DE}\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with h2 headers and a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n"
        property string tool: "functions" // search, functions, or none
        property list<var> extraModels: [
            {
                "api_format": "openai" // Most of the time you want "openai". Use "gemini" for Google's models
                ,
                "description": "This is a custom model. Edit the config to add more! | Anyway, this is DeepSeek R1 Distill LLaMA 70B",
                "endpoint": "https://openrouter.ai/api/v1/chat/completions",
                "homepage": "https://openrouter.ai/deepseek/deepseek-r1-distill-llama-70b:free" // Not mandatory
                ,
                "icon": "spark-symbolic" // Not mandatory
                ,
                "key_get_link": "https://openrouter.ai/settings/keys" // Not mandatory
                ,
                "key_id": "openrouter",
                "model": "deepseek/deepseek-r1-distill-llama-70b:free",
                "name": "Custom: DS R1 Dstl. LLaMA 70B",
                "requires_key": true
            }
        ]
    }

    property JsonObject mascot: JsonObject {
        property bool enable: false // Show the iNiR mascot illustration across shell surfaces (empty states, About, etc.)
        property JsonObject surfaces: JsonObject {
            // Where the static mascot may appear; each maps to a group of placements
            property bool emptyStates: true // Notifications, clipboard, todo, media, calendar, wallpapers, search results
            property bool about: true // About pages
            property bool session: true // Session (power) screen
            property bool aiChat: true // AI chat greeting
            property bool dashboard: true // Dashboard welcome/weather cards
            property bool cheatsheet: true // Cheatsheet nav rail
            property bool bootGreeting: true // Boot welcome wave
            property bool updates: true // Shell update overlay
            property bool dialogs: true // Close confirmation and similar dialogs
        }
        property JsonObject companion: JsonObject {
            property bool enable: true // Playful companion: she peeks from screen edges and reacts to events (needs mascot.enable)
            property int intervalMinutes: 25 // Roughly how often she peeks on her own; event reactions are rate-limited separately
            property int size: 150 // Sprite size in px
            property int visibleSeconds: 5 // How long a peek stays before she slides away (hover keeps her)
            property int slideMs: 400 // Slide in/out animation duration
            property bool musicRequireArtist: true // Ignore artist-less MPRIS players (browser videos posing as music)
            property int minQuietMinutes: 10
            property int maxVisitsPerHour: 3
            property bool respectQuiet: true
            property bool shellReactions: true
            property bool dialogue: true
            property JsonObject events: JsonObject {
                // Which shell events she reacts to (event reactions, not idle peeks)
                property bool music: true
                property bool battery: true
                property bool update: true
                property bool network: true
                property bool dnd: true
                property bool notification: true
                property bool wallpaper: true
                property bool screenshot: true
                property bool gaming: true
                property bool workspace: true
                property bool unlock: true
            }
            property JsonObject eventPoses: JsonObject {
                // Per-event pose override; "" rotates the manifest pose pool
                property string music: ""
                property string battery: ""
                property string update: ""
                property string network: ""
                property string dnd: ""
                property string notification: ""
                property string wallpaper: ""
                property string screenshot: ""
                property string gaming: ""
                property string workspace: ""
                property string unlock: ""
            }
            property list<string> customLines: [] // Extra things she can say on idle peeks (one per entry)
            property JsonObject edges: JsonObject {
                property bool left: true
                property bool right: true
                property bool top: true
                property bool bottom: true
            }
            property string placement: "peek" // "peek" | "panel-sitter" — float off-screen edge or sit on bar/dock
            property bool contextualPlacement: false // Opt-in: appear near triggering widget instead of random edge
            property string monitor: "primary" // "primary" | "focused" — which screen she appears on
        }
        property JsonObject surfacePoses: JsonObject {
            // Per-surface pose override ("" = each spot's curated
            // default). GIF catalog names animate. Fine keys win over
            // the coarse emptyStates group they were split from.
            property string emptyStates: ""
            property string about: ""
            property string session: ""
            property string aiChat: ""
            property string dashboard: ""
            property string cheatsheet: ""
            property string updates: ""
            property string dialogs: ""
            property string notifications: ""
            property string clipboard: ""
            property string mediaControls: ""
            property string todo: ""
            property string calendar: ""
            property string wifi: ""
            property string startMenu: ""
            property string wallpaperSelector: ""
            property string bootGreeting: ""
        }
        property JsonObject personality: JsonObject {
            property bool enabled: true // Session-long mood flavor (sleepy/hyper/snarky/contemplative)
            property int idleMoodIntervalMinutes: 30 // How often mood rolls (with ±50% jitter)
            property bool commentary: true // Personal observations (3AM commits, uptime, app marathons); off = generic lines only
            property string voiceMode: "adaptive" // adaptive | casual | dry | composed | chaotic
        }
        property JsonObject chaos: JsonObject {
            property bool enable: false // Chaos mode: she may run across the desktop and mess with widgets/panels
            property bool allowRearrange: false // Let her actually relocate widgets (otherwise everything bounces back)
            property bool sfx: true // Impact foley from the freedesktop sound theme during chaos
            property bool systemEvents: true // Rare romps reacting to low battery, notification pileup, or late-night hours
            property string artStyle: "jrpg"
            property int intervalMinutes: 45
            property bool callingCards: false
        }
    }

    property JsonObject appearance: JsonObject {
        property string theme: "auto" // Theme preset ID: "auto" for wallpaper-based, or preset name like "gruvbox-dark", "catppuccin-mocha", "custom", etc.
        property bool colorInvert: false // Rotate all m3 colors 180° (complementary palette). Shell-only, does not affect external apps.
        property list<string> recentThemes: []  // Last 4 used themes
        property list<string> favoriteThemes: []  // User's favorite themes
        property JsonObject themeSchedule: JsonObject {
            property bool enabled: false
            property string dayTheme: "auto"
            property string nightTheme: "auto"
            property string dayStart: "06:00"
            property string nightStart: "18:00"
        }
        property bool softenColors: true
        property JsonObject customTheme: JsonObject {
            property bool darkmode: true
            property string m3background: "#282828"
            property string m3onBackground: "#ebdbb2"
            property string m3surface: "#282828"
            property string m3surfaceDim: "#1d2021"
            property string m3surfaceBright: "#3c3836"
            property string m3surfaceContainerLowest: "#1d2021"
            property string m3surfaceContainerLow: "#282828"
            property string m3surfaceContainer: "#32302f"
            property string m3surfaceContainerHigh: "#3c3836"
            property string m3surfaceContainerHighest: "#504945"
            property string m3onSurface: "#ebdbb2"
            property string m3surfaceVariant: "#504945"
            property string m3onSurfaceVariant: "#d5c4a1"
            property string m3inverseSurface: "#ebdbb2"
            property string m3inverseOnSurface: "#282828"
            property string m3outline: "#928374"
            property string m3outlineVariant: "#665c54"
            property string m3shadow: "#000000"
            property string m3scrim: "#000000"
            property string m3surfaceTint: "#fe8019"
            property string m3primary: "#fe8019"
            property string m3onPrimary: "#1d2021"
            property string m3primaryContainer: "#af3a03"
            property string m3onPrimaryContainer: "#fbd5a8"
            property string m3inversePrimary: "#d65d0e"
            property string m3secondary: "#b8bb26"
            property string m3onSecondary: "#1d2021"
            property string m3secondaryContainer: "#79740e"
            property string m3onSecondaryContainer: "#d5c4a1"
            property string m3tertiary: "#83a598"
            property string m3onTertiary: "#1d2021"
            property string m3tertiaryContainer: "#427b58"
            property string m3onTertiaryContainer: "#d5c4a1"
            property string m3error: "#fb4934"
            property string m3onError: "#1d2021"
            property string m3errorContainer: "#cc241d"
            property string m3onErrorContainer: "#fbd5a8"
            property string m3primaryFixed: "#fabd2f"
            property string m3primaryFixedDim: "#d79921"
            property string m3onPrimaryFixed: "#1d2021"
            property string m3onPrimaryFixedVariant: "#3c3836"
            property string m3secondaryFixed: "#b8bb26"
            property string m3secondaryFixedDim: "#98971a"
            property string m3onSecondaryFixed: "#1d2021"
            property string m3onSecondaryFixedVariant: "#3c3836"
            property string m3tertiaryFixed: "#8ec07c"
            property string m3tertiaryFixedDim: "#689d6a"
            property string m3onTertiaryFixed: "#1d2021"
            property string m3onTertiaryFixedVariant: "#3c3836"
            property string m3success: "#b8bb26"
            property string m3onSuccess: "#1d2021"
            property string m3successContainer: "#79740e"
            property string m3onSuccessContainer: "#d5c4a1"
        }
        property int fakeScreenRounding: 2 // 0: None | 1: Always | 2: When not fullscreen
        property JsonObject wallpaperTheming: JsonObject {
            // Auto-pick the light/dark scheme from the wallpaper's brightness
            // on each wallpaper change, so UI text stays readable. Opt-in;
            // when off, the mode follows the manual dark-mode toggle as before.
            property bool autoDarkLightMode: false
            property bool enableAppsAndShell: true
            property bool enableQtApps: true
            property bool enableTerminal: true
            property bool enableVesktop: true
            property bool enableZed: true
            property bool enableVSCode: true
            property bool enableChrome: true
            property bool enableFirefox: true
            property bool enableSpicetify: true
            property string spicetifyTheme: "Inir"
            property bool enableSteam: true
            property bool enablePearDesktop: true
            property bool enableLimusic: false
            property bool enableClaudeCode: false
            property bool enableOpenCode: false
            property bool enableNeovim: false
            property bool enableCava: true
            property real colorStrength: 1.0
            property JsonObject vscodeEditors: JsonObject {
                property bool code: true           // Official VSCode
                property bool codium: true         // VSCodium (FOSS)
                property bool codeOss: true        // Code - OSS
                property bool codeInsiders: true   // Code - Insiders
                property bool cursor: true         // Cursor AI
                property bool windsurf: true       // Windsurf AI
                property bool windsurfNext: true   // Windsurf - Next
                property bool qoder: true          // Qoder
                property bool antigravity: true    // Antigravity
                property bool positron: true       // Positron
                property bool voidEditor: true     // Void
                property bool melty: true          // Melty
                property bool pearai: true         // PearAI
                property bool aide: true           // Aide
            }
            property bool useBackdropForColors: false
            property bool colorsOnlyMode: false
            property string previewSourcePath: ""
            property JsonObject terminals: JsonObject {
                property bool kitty: true
                property bool alacritty: true
                property bool foot: true
                property bool wezterm: true
                property bool ghostty: true
                property bool konsole: true
                property bool starship: true
                property bool btop: true
                property bool lazygit: true
                property bool yazi: true
                property bool omp: true
            }
            property JsonObject terminalGenerationProps: JsonObject {
                property real harmony: 0.6
                property real harmonizeThreshold: 100
                property real termFgBoost: 0.35
                property bool forceDarkMode: false
            }
            property JsonObject terminalColorAdjustments: JsonObject {
                property real saturation: 0.65  // 0.0 - 1.0
                property real brightness: 0.60  // 0.0 - 1.0 (lightness for dark mode)
                property real harmony: 0.40     // 0.0 - 1.0 (how much to shift towards primary)
                property real backgroundBrightness: 0.50  // 0.0 - 1.0 (0=darkest, 1=lightest)
            }
        }
        property JsonObject cava: JsonObject {
            property string colorSource: "theme" // Internal visualizers + standalone cava: theme | vibrant | cover
            property int gradientCount: 8 // 1-8; one color becomes a solid standalone cava foreground
            property string foreground: "" // empty = gradient; hex = solid foreground
            property string background: "" // empty = palette surface; hex = override
            property int sensitivity: 100 // 1-500
            property int bars: 0 // 0 = auto
            property int framerate: 60 // 30-165
            property int barWidth: 2
            property int barSpacing: 1
            property bool stereo: true
            property int waveOpacity: 30 // 5-100, fill alpha for WaveVisualizer (0.05–1.0)
            // Internal visualizer source exclusions. Empty keeps automatic
            // active-player/source selection.
            property list<string> blockedApps: []
        }
        property JsonObject palette: JsonObject {
            property string type: "auto" // Allowed: auto, scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot
            property string accentColor: "" // Seed color hex for scheme variant (e.g. "#ab1234"), empty = use theme primary
            property string harmony: "accent" // accent = secondary and tertiary stay beside the accent's hue; scheme = as generated
        }
        property JsonObject typography: JsonObject {
            property string mainFont: "Google Sans Flex"
            property string titleFont: "Gabarito"
            property string monospaceFont: "JetBrainsMono Nerd Font"
            property real sizeScale: 1.0
            property bool syncWithSystem: true // Sync fonts with GTK/KDE apps
            property JsonObject variableAxes: JsonObject {
                property int wght: 300
                property int wdth: 105
                property int grad: 150
            }
        }
        property string iconTheme: "WhiteSur-dark" // System icon theme (tray, GTK/Qt apps)
        property string dockIconTheme: "" // Dock icon theme (overrides system for dock only)
        property real shellScale: 1.0 // Legacy compatibility key. Launcher keeps QT_SCALE_FACTOR=1; use appearance.typography.sizeScale.
    }

    property JsonObject performance: JsonObject {
        property bool lowPower: false
        property bool reduceAnimations: false
        // JSGCHeap watchdog (#164). Stats stay on `inir memory`;
        // the restart notification is opt-in.
        property bool memoryMonitoring: true
        property int jsgcThreshold: 300
        property bool memoryWarningNotification: false
        // Delegate shaped panel blur to Niri via ext-background-effect-v1.
        // The request is only activated on Niri; QML blur remains the fallback.
        property bool compositorBlur: true
        property string blurBackend: "auto" // auto | wallpaper | compositor | off
        property JsonObject blurAreas: JsonObject {
            property string bar: "inherit"
            property string dock: "inherit"
            property string panels: "inherit"
            property string islands: "inherit"
            property string widgets: "inherit"
        }
    }

    property JsonObject powerProfiles: JsonObject {
        property bool restoreOnStart: true
        property string preferredProfile: "" // "power-saver" | "balanced" | "performance"
    }

    property JsonObject hub: JsonObject {
        // Extra community hub indexes (URLs or local paths to an index.json); the official hub is always read.
        property list<string> sources: []
        // How every family's Hub page lists the catalogue: "list" rows or a "grid" of cards, in Hub.sorts order.
        property string view: "list"
        property string sort: "popular"
    }

    property JsonObject idle: JsonObject {
        property int screenOffTimeout: 300 // seconds, 0 = disabled
        property int lockTimeout: 600 // seconds, 0 = disabled
        property int suspendTimeout: 0 // seconds, 0 = disabled
        property bool lockBeforeSleep: true
        // Tighter timeouts applied only while running on battery.
        // Ignored on desktops (no battery present).
        property JsonObject onBattery: JsonObject {
            property bool enable: false
            property int screenOffTimeout: 120
            property int lockTimeout: 300
            property int suspendTimeout: 600
        }
    }

    property JsonObject modules: JsonObject {
        property bool altSwitcher: false
        property bool bar: true
        property bool background: true
        property bool cheatsheet: true
        property bool clipboard: true
        property bool crosshair: false
        property bool dock: true
        property bool lock: true
        property bool mediaControls: true
        property bool notificationPopup: true
        property bool onScreenDisplay: true
        property bool onScreenKeyboard: true
        property bool overview: true
        property bool overlay: true
        property bool polkit: true
        property bool regionSelector: true
        property bool reloadPopup: true
        property bool screenCorners: true
        property bool sessionScreen: true
        property bool sidebarLeft: true
        property bool sidebarRight: true
        property bool verticalBar: true
        property bool wallpaperSelector: true
    }

    property JsonObject gameMode: JsonObject {
        property bool autoDetect: true
        property bool disableAnimations: false
        property bool disableEffects: false
        property bool disableVisualizers: true
        property bool disableNiriAnimations: false
        property bool disableReloadToasts: true
        property bool disableDiscoverOverlay: true // Only where discover-overlay is installed
        property bool suppressNotifications: true // Hide notification popups during GameMode
        property bool minimalMode: true // Make panels transparent/minimal during GameMode
        // Throttle Niri window list updates - 100ms = 10 FPS, sufficient for smooth UI
        // Lower values increase CPU usage with diminishing returns on perceived smoothness
        property int niriWindowListUpdateIntervalMs: 100
        property int niriWindowListUpdateIntervalMsGameMode: 500 // 2 FPS during gaming - minimal overhead
    }

    property JsonObject reloadToasts: JsonObject {
        property bool enable: true
    }

    property JsonObject audio: JsonObject {
        // Values in %
        property JsonObject protection: JsonObject {
            // Prevent sudden bangs
            property bool enable: true
            property real maxAllowedIncrease: 10
            property real maxAllowed: 100
        }
    }

    property JsonObject compositor: JsonObject {
        property bool autoExpandSingleTilingWindow: false
    }

    property JsonObject apps: JsonObject {
        property string bluetooth: "kcmshell6 kcm_bluetooth"
        property string network: "kitty -1 fish -c nmtui"
        property string networkEthernet: "kcmshell6 kcm_networkmanagement"
        property string taskManager: "missioncenter"
        property string terminal: "kitty" // This is only for shell actions
        property string browser: "firefox" // Used by launcher-backed browser shortcuts
        property string volumeMixer: "pavucontrol"
        property string discord: "discord" // Shell command to launch Discord client
        property string update: "" // Empty uses the package-manager-aware update backend
        property string manageUser: "kcmshell6 kcm_users" // User account management
        property list<string> pinned: [ // IDs of pinned entries
            "org.gnome.Nautilus", "firefox", "kitty",]
        property list<string> ignoredRegexes: []
    }

    property JsonObject background: JsonObject {
        property JsonObject widgets: JsonObject {
            // "panel" (stock per-style plate) | "island" (Ricelin card)
            property string style: "panel"
            property string design: "individual" // individual, instrument, readout
            property list<var> designUndo: [] // widget looks a design change cleared, for undo
            property int dynamicOpacity: 0 // 0-100: reduce widget opacity when windows are on current workspace
            // Opt-in local wallpaper sampling. Off keeps semantic widget
            // colors stable when widgets move; on lets eligible widgets
            // choose readable ink/semantic foregrounds from their region.
            property bool adaptColorsToWallpaperPosition: true
            property JsonObject powerSaving: JsonObject {
                property bool enable: true
                property bool pauseOnGameMode: true
                property bool pauseOnFullscreen: true
                property bool pauseWhenWindowsPresent: false
                property bool showPausedEffect: false
            }
            property list<string> screenList: []
            property list<var> outputOverrides: []
            // Persistent bottom-to-top widget instance keys. Entries are
            // output-qualified ("OUTPUT::configEntryName") so each screen
            // keeps its own overlap order after edit mode closes/restarts.
            property list<string> layerOrder: []
            // iRiS widget stacks: [{ id, members: [widget keys], rotate, interval (seconds) }].
            // A stack's place and look live in outputOverrides under "stack:<id>".
            property list<var> stacks: []
            property JsonObject clock: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                property real x: 100
                property real y: 100
                property string style: "digital" // "digital" | "androidStacked" | "cookie" | "pixel" | "instrument"
                property int dim: 0 // Extra dim for clock text (0-100)
                property string fontFamily: "Space Grotesk"
                property string timeFormat: "system" // "system", "24h", "12h"
                property string dateStyle: "long" // "long", "minimal", "weekday", "numeric"
                property bool showDate: true
                property bool showSeconds: false
                property bool instrumentTrail: true
                property int instrumentTrailLength: 6
                property bool instrumentNumerals: true
                property bool showShadow: true
                property int timeScale: 100
                property int dateScale: 100
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0
                property real borderWidth: 0
                property real borderOpacity: 0.08
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property JsonObject cookie: JsonObject {
                    property bool aiStyling: false
                    property int sides: 15
                    property string dialNumberStyle: "full"   // Options: "dots" , "numbers", "full" , "none"
                    property string hourHandStyle: "hollow"   // Options: "classic", "fill", "hollow", "hide"
                    property string minuteHandStyle: "hide"   // Options "classic", "thin", "medium", "bold", "hide"
                    property string secondHandStyle: "hide"   // Options: "dot", "line", "classic", "hide"
                    property string dateStyle: "bubble"       // Options: "border", "rect", "bubble" , "hide"
                    property bool timeIndicators: false
                    property bool hourMarks: false
                    property bool dateInClock: true
                    property bool constantlyRotate: false
                    property bool useSineCookie: false
                    property int size: 230
                    property string preset: "default"
                }
                property JsonObject digital: JsonObject {
                    property bool adaptToWallpaper: true
                    property bool animateChange: true
                    property int fontWeight: 600
                    property int spacing: 6
                    property string preset: "default"
                }
                property JsonObject pixel: JsonObject {
                    property string orientation: "horizontal" // "horizontal" | "vertical"
                }
                property JsonObject quote: JsonObject {
                    property bool enable: false
                    property string text: ""
                }
            }
            property JsonObject weather: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                property real x: 100
                property real y: 200
                property int size: 200
                property int tempSize: 80
                property int iconSize: 80
                property bool showTemp: true
                property bool showIcon: true
                property bool showCondition: false
                property bool showSunPath: true
                property bool showSunTimes: true
                property bool showLocation: true
                property int padding: 20
                property int tempFontWeight: 500 // Font.Medium
                property real conditionOpacity: 0.7
                property string preset: "default"
                property string style: "pill" // "pill" (shape), "card" (adaptive overlay), "detail" (M3 tonal), "dial" (instrument)
                property bool showMetrics: true // "detail" style only
                property string shape: "pill" // MaterialShape shape name
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
            }

            property JsonObject customImage: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string sourceMode: "file" // "file" | "folder"
                property string path: ""
                property string folder: ""
                property string mediaFilter: "all" // "all" | "images" | "gifs" | "videos"
                property int intervalSeconds: 30
                property string order: "sequential" // "sequential" | "random"
                property int transitionDuration: 450
                property string shape: "Cookie4Sided"
                property string fitMode: "cover"
                property int dim: 0
                property int widgetScale: 100
                property int widgetOpacity: 100
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 120
                property real y: 320
            }

            property JsonObject imageConverter: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string selectedFormat: "webp"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.22
                property real borderWidth: 1
                property real borderOpacity: 0.22
                property real cornerRadius: -1
                property real x: 120
                property real y: 360
            }

            property JsonObject mediaControls: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                property string playerPreset: "full" // "full", "compact", "minimal", "albumart", "visualizer", "classic", "lyrics", "lyricsSplit", "expandingLyrics"
                property string visualizerType: "wave" // "wave", "bars", "organic"
                property string visualizerPosition: "bottom" // "bottom", "top", "fill", "none"
                property string visualizerPaletteMode: "cava" // "cava", "accent", "player" (album-derived)
                property int visualizerOpacity: 55
                property int visualizerSmoothing: 2
                property string visualizerFrequencyProfile: "flat"
                property int visualizerAccentStrength: 70
                property int visualizerRange: 88
                property int visualizerBarCount: 32
                property int organicSensitivity: 35
                property int organicPulse: 150
                property int organicCompression: 0 // 0-100, spatially focus spectrum regions
                property int organicMotionSpeed: 250
                property int organicIdleMotion: 40
                property int organicGlow: 100
                property int organicOpacity: 100
                property int organicReach: 35 // 20-140, outward edge reach
                property int organicRange: 20 // 20-100, Organic deformation range
                property bool lyricsExpanded: false
                property real x: 240
                property real y: 240
                property int widgetScale: 100
                property int widgetOpacity: 100
                property string colorMode: "auto"
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
            }

            property JsonObject visualizer: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string vizType: "bars"
                property string preset: "default" // legacy, kept for compat
                property string paletteMode: "cava" // "cava", "accent", "primary", "album"
                property string barsOrigin: "bottom" // "bottom", "top", "center", "mirror"
                property string waveMode: "fill" // "fill", "line", "ribbon"
                property string frequencyProfile: "flat" // "flat", "bass", "warm", "vocal", "treble", "smile"
                property int smoothing: 2
                property int organicSensitivity: 25 // 25-200, Organic visualizer deformation gain
                property int organicPulse: 150 // 0-150, beat/bass expansion
                property int organicCompression: 0 // 0-100, spatially focus spectrum regions
                property int organicMotionSpeed: 250 // 20-250, contour animation speed
                property int organicIdleMotion: 18 // 0-100, ambient motion floor
                property int organicOpacity: 100 // 10-100, Organic halo opacity
                property int organicGlow: 100 // 0-100, Organic outer glow
                property int organicCoverSize: 51 // 30-90, Organic cover size relative to widget span
                property int organicRange: 20 // 20-100, Organic deformation range
                property int fillRatio: 90
                property int barOpacity: 100
                property int waveOpacity: -1 // -1 = use global (appearance.cava.waveOpacity)
                property int barCount: 48
                property int barSpacing: 2
                property int barRadius: 2
                property int barMinHeight: 1
                property int lineWidth: 2
                property int edgeInset: 0
                property int edgeSoftness: 28
                property int accentStrength: 70
                property int dim: 0
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 100
                property real y: 100
            }

            property JsonObject systemMonitor: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string displayMode: "bars" // "bars", "graph", "rings", "text", "tiles", "instrument"
                property int barCount: 32
                property int barSpacing: 2
                property real trackAlpha: 0.08
                property real fillOpacity: 0.7
                property real graphFillOpacity: 0.3
                property bool showCpu: true
                property bool showMemory: true
                property bool showGpu: true
                property bool showTemp: false
                property bool showGpuTemp: false
                property bool showDisk: false
                property bool showLabels: true
                property string preset: "default"
                property int dim: 0
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 50
                property real y: 400
            }

            property JsonObject battery: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string displayMode: "ring"
                property bool showTime: true
                property bool showRate: true
                property int ringSize: 72
                property int ringLineWidth: 6
                property int barCount: 20
                property int barSpacing: 2
                property int barRadius: 2
                property int pillHeight: 12
                property string preset: "default"
                property int dim: 0
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 50
                property real y: 50
            }

            property JsonObject notes: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string text: ""
                property int fontSize: 14
                property string fontFamily: "sans"
                property string textAlign: "left"
                property string style: "card" // "card" | "instrument" (ruled field note)
                property bool showRules: true
                property int dim: 0
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.10
                property real borderWidth: 1
                property real borderOpacity: 0.12
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 80
                property real y: 80
            }

            property JsonObject japaneseTypography: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string preset: "exhibition"
                property string primaryText: "夏の記憶"
                property string secondaryText: "潮風と、あの子と、終わらない夏"
                property string sealText: "特別展"
                property string footerText: "PACIFIC DRIVE-IN"
                property string dateText: "7.12 — 8.31"
                property bool showSecondary: true
                property bool showSeal: true
                property bool showFooter: true
                property bool showRule: true
                property string fontPreset: "mincho"
                property string fontFamily: "serif"
                property string secondaryFontFamily: ""
                property string latinFontFamily: ""
                property int primaryWeight: 500
                property int secondaryWeight: 400
                property int latinWeight: 600
                property int primarySize: 72
                property int secondarySize: 18
                property int footerSize: 14
                property int dateSize: 12
                property int primaryColumns: 2
                property int secondaryColumns: 2
                property int columnGap: 14
                property int letterSpacing: 2
                property int secondaryLetterSpacing: 1
                property bool mirrorLayout: false
                property bool rotateLatin: false
                property string paletteMode: "adaptive"
                property string palettePreset: "adaptive"
                property string primaryColor: "#E7D4B2"
                property string secondaryColor: "#CDB48D"
                property string sealColor: "#A64B39"
                property string detailColor: "#D0B996"
                property string ruleColor: "#C18A53"
                property int primaryOpacity: 100
                property int secondaryOpacity: 78
                property int sealOpacity: 100
                property int detailOpacity: 72
                property int ruleOpacity: 78
                property real sealFillOpacity: 0
                property int ruleThickness: 1
                property string outlineColor: "#000000"
                property int outlineOpacity: 0
                property int shadowStrength: 35
                property int dim: 10
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0
                property real borderWidth: 0
                property real borderOpacity: 0.12
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 56
                property real y: 120
            }

            property JsonObject calendarUpcoming: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int maxEvents: 5
                property bool showDate: true
                property bool showTime: true
                property bool showLocation: false
                property bool groupByDay: true
                property string style: "card" // "card" | "instrument" (agenda ledger)
                property int dim: 0
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.10
                property real borderWidth: 1
                property real borderOpacity: 0.12
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property real x: 80
                property real y: 80
            }

            property JsonObject monthCalendar: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int weekStart: 1 // 0 Sunday, 1 Monday
                property bool showAdjacentDays: true
                property string style: "card" // "card" | "instrument" (readout on wallpaper ink)
                property bool instrumentRule: true
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.14
                property real borderWidth: 1
                property real borderOpacity: 0.16
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 420
                property real y: 120
            }

            property JsonObject todo: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property string style: "card" // "card" | "instrument" (readout on wallpaper ink)
                property bool instrumentRules: true
                property bool showCompleted: true
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.14
                property real borderWidth: 1
                property real borderOpacity: 0.16
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 120
                property real y: 180
            }

            property JsonObject timers: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property bool vertical: false
                property string style: "cards" // "cards" | "instrument" (measurement readouts)
                property bool glow: true // running-state pulse in Instrument presentation
                property bool showProgress: true
                property bool showState: true
                property bool showHundredths: true
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0
                property real borderWidth: 0
                property real borderOpacity: 0.16
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 360
                property real y: 420
            }

            property JsonObject dayProgress: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0
                property real borderWidth: 0
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property string style: "ring"
                property bool comet: true
                property bool showIcon: true
                property bool showDate: true
                property bool hourLabels: true
                property int fontScale: 100
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 80
                property real y: 260
            }

            property JsonObject uptime: JsonObject {
                property bool enable: false
                property bool locked: false
                property string style: "row"
                property bool showSince: true
                property bool showBreakdown: true
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 80
                property real y: 80
            }

            property JsonObject controls: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property real cornerRadius: -1
                property real x: 120
                property real y: 420
            }

            property JsonObject screenTime: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property real cornerRadius: -1
                property real x: 120
                property real y: 240
            }

            property JsonObject palette: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property real cornerRadius: -1
                property real x: 120
                property real y: 600
            }

            property JsonObject lyrics: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property real cornerRadius: -1
                property real x: 520
                property real y: 600
            }

            property JsonObject shape: JsonObject {
                property bool enable: false
                property string treatment: "flat"
                property string shape: "Flower"
                property bool outline: false
                property real angle: 0
                property real strokeWidth: 3
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0
                property real borderWidth: 0
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 80
                property real y: 240
            }

            property JsonObject editorial: JsonObject {
                property bool enable: false
                property string title: "Make room for wonder."
                property string caption: "A LITTLE EVERY DAY"
                property string footer: "YOUR OWN PERSPECTIVE"
                property string style: "poster"
                property bool showAccent: true
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0.12
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 100
                property real y: 300
            }

            property JsonObject dateBadge: JsonObject {
                property bool enable: false
                property string style: "ticket"
                property bool showYear: true
                property bool showWeekday: true
                property bool showOrdinal: true
                property bool instrumentMarks: true
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 260
                property real y: 80
            }

            property JsonObject worldClock: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 80
                property real y: 200
                property list<string> timezones: ["Asia/Tokyo", "Europe/London", "America/New_York"]
                property string style: "cards" // "cards" (list) | "instrument" (chronometer board)
                property string instrumentLayout: "grid" // "grid" | "rows"
                property bool showNames: true
                property bool showOffsets: true
                property bool showDate: true
                property bool showDayState: true
                property bool pulseSeparator: false
            }

            property JsonObject userCard: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property string style: "card" // "card" | "instrument" (identity/session plate)
                property bool showAvatar: true
                property bool showWeather: true
                property bool showHostname: true
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 80
                property real y: 420
            }

            property JsonObject mascot: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: false
                property bool useBlur: false
                property bool showBorder: false
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property string pose: "reading"
                property string poseFilter: "all" // all | featured | pixel | street | chibi | loops | manual
                property string posePickerMode: "buttons" // desktop quick controls: buttons | gallery
                property string customPath: "" // any user image/GIF replaces the catalog pose
                property string anchorWidget: "" // configEntryName of another widget she perches on top of; "" = free
                property real x: 120
                property real y: 320
            }

            property JsonObject newsTicker: JsonObject {
                property bool enable: false
                property bool locked: false
                property string placementStrategy: "free"
                property int widgetScale: 100
                property int widgetOpacity: 100
                property bool showBackground: true
                property bool useBlur: false
                property bool showBorder: true
                property real backgroundOpacity: 0.16
                property real borderWidth: 1
                property real borderOpacity: 0.20
                property real cornerRadius: -1
                property string colorMode: "auto"
                property string style: "card" // "card" | "instrument" (wire bulletin)
                property bool showMeta: true
                property int rotateSeconds: 45
                property JsonObject palette: JsonObject {
                    property string primary: "primary"
                    property string secondary: "secondary"
                    property string tertiary: "tertiary"
                    property string signal: "signal"
                    property string surface: "surface"
                }
                property int dim: 0
                property real x: 100
                property real y: 260
            }

            property JsonObject editGrid: JsonObject {
                property int size: 32
                property bool snap: true
            }
            // off: arranging happens on the full-size desktop, no card
            property bool editCard: true

            // Custom widget data lives in root.customWidgetData (not here)
            // to avoid JsonAdapter crash on property var inside JsonObject.
        }
        property JsonObject edgeWidgets: JsonObject {
            property JsonObject organic: JsonObject {
                property bool enable: false
                property list<string> edges: []
                property int inset: 0
                property bool respectPanels: false
                property int topScale: 100
                property int rightScale: 100
                property int bottomScale: 100
                property int leftScale: 100
                property int cornerRadius: 24
                property int cornerBlend: 55
                property int taper: 14
                property int thickness: 22
                property int detail: 42
                property string style: "silk"
                property string shape: "flow"
                property string palette: "theme"
                property string colorMode: "flow"
                property string effectMode: "clean"
                property string joinMode: "auto"
                property string primaryColor: "#b5a0ff"
                property string secondaryColor: "#64dbcf"
                property string tertiaryColor: "#ffb2cf"
                property int colorSpeed: 35
                property int hueShift: 0
                property int colorIntensity: 100
                property int effectStrength: 38
                property bool audioReactive: true
                property string idleMode: "ambient"
                property int bodyOpacity: 32
                property int crestStrength: 90
                property int glowSpread: 48
                property int audioRange: 78
                property int beatGlow: 64
                property int transientStrength: 90
                property int bassDrive: 88
                property int trebleDrive: 68
                property int attack: 105
                property int release: 82
                property string edge: "bottom" // top | right | bottom | left
                property int span: 70 // percent of the selected edge
                property int position: 50 // center position along the edge, percent
                property int depth: 180 // render field extending inward from the physical edge
                property int opacity: 100
                property int smoothing: 2
                property string frequencyProfile: "flat"
                property int accentStrength: 70
                property int sensitivity: 72
                property int pulse: 90
                property int compression: 12
                property int motionSpeed: 100
                property int idleMotion: 14
                property string flowDirection: "clockwise"
                property int restPresence: 58
                property int glow: 52
                property list<string> screenList: []
            }
        }
        property string wallpaperPath: ""
        property string thumbnailPath: ""
        property string fillMode: "fill" // "fill", "fit", "stretch", "tile", "center" or "span" (one picture across every screen); Wallpapers.fillMode
        property bool enableAnimation: true // Enable animated wallpapers (video/gif). When disabled, shows thumbnail instead (better performance)
        property bool pauseAnimationOnBattery: true // Freeze video/gif wallpapers while on battery power (all surfaces, both families)
        property string videoPause: "covered" // when a live wallpaper stops decoding: "never", "fullscreen" or "covered" (tiled windows span the output)
        property bool hideWhenFullscreen: true
        property JsonObject effects: JsonObject {
            property bool enableBlur: true
            property int blurRadius: 22
            property int thumbnailBlurStrength: 50
            property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
            property int dim: 30 // 0-100 percentage (base overlay)
            property int dynamicDim: 20 // Extra dim when there are windows on the current workspace (0-100)
            property JsonObject ripple: JsonObject {
                property bool enable: false
                property bool charging: true
                property bool overview: true
                property bool reload: true
                property bool lock: true
                property bool session: true
                property bool hotcorners: true
                property int rippleDuration: 3000
                property real sparkleIntensity: 1.0 // 0.0 = no sparkles, 2.0 = intense
                property real glowIntensity: 1.0    // 0.0 = no glow, 2.0 = strong
                property real ringWidth: 0.15       // 0.05 = thin ring, 0.5 = wide ring
            }
        }
        property JsonObject backdrop: JsonObject {
            property bool enable: true
            property bool hideWallpaper: false
            property string fillMode: "fill" // legacy persisted key; backdrop rendering always covers the output
            property bool useMainWallpaper: true
            property string wallpaperPath: ""
            property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
            property bool enableAnimation: false // Enable animated wallpapers (video/gif) in backdrop (disabled by default for performance)
            property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
            property int blurRadius: 32
            property int dim: 35
            property real saturation: 0
            property real contrast: 0
            property bool vignetteEnabled: false
            property real vignetteIntensity: 0.5
            property real vignetteRadius: 0.7
            property bool useAuroraStyle: false
            property real auroraOverlayOpacity: 0.38
        }
        property JsonObject parallax: JsonObject {
            property bool enable: false
            property string axis: "vertical"
            property bool vertical: false
            property bool autoVertical: false
            property bool enableWorkspace: true
            property real workspaceShift: 1.0
            property real workspaceZoom: 1.0 // Relative to wallpaper size, with headroom applied internally
            property real zoom: 1.0
            property bool enableSidebar: true
            property real panelShift: 0.15
            property real widgetsFactor: 1.2
            property real widgetDepth: 1.2
            property bool pauseDuringTransitions: true
            property int transitionSettleMs: 220
        }
        property JsonObject multiMonitor: JsonObject {
            property bool enable: false
        }
        property list<var> wallpapersByMonitor: []
        property JsonObject autoWallpaper: JsonObject {
            property bool enable: false
            property int intervalMinutes: 30 // minutes between wallpaper changes
            property bool generateColors: true // regenerate theme colors on each change
            property string folder: "" // empty = use current wallpaper folder
        }
        property JsonObject pan: JsonObject {
            property real x: 0.0 // Focal point offset X (-1.0 to 1.0, stored as fraction; -1 = full left, +1 = full right)
            property real y: 0.0 // Focal point offset Y (-1.0 to 1.0; -1 = top, +1 = bottom)
            property real zoom: 1.0 // Extra zoom on top of fill-crop (1.0 = standard fill, 2.0 = 2× zoom, max 3.0)
        }
        property JsonObject backend: JsonObject {
            property string provider: "awww"
            property JsonObject awww: JsonObject {
                property int transitionFps: 60
                property int simpleStep: 5
                property int spatialStep: 30
            }
            property JsonObject web: JsonObject {
                property string source: ""
                property bool interactive: false
            }
        }
        property JsonObject transition: JsonObject {
            property bool enable: true
            // awww-native names plus shared internal QML/shader transitions.
            // Shader assets are transient overlays; awww remains the final static renderer.
            property string type: "random"
            property string direction: "right"
            property int duration: 800 // ms
            property list<var> bezier: [0.54, 0.0, 0.34, 0.99]
        }
        property bool hideUpscaleNotification: false
    }


    property JsonObject battery: JsonObject {
        property int low: 20
        property int critical: 5
        property int full: 101
        property bool automaticSuspend: false
        property int suspend: 3
        property bool notifyFull: true
        property JsonObject chargeLimit: JsonObject {
            property bool enable: false
            property int threshold: 80
        }
    }

    // External calendar integration (ICS/iCal URL sync)
    property JsonObject calendar: JsonObject {
        property JsonObject externalSync: JsonObject {
            property bool enable: false
            property int refreshMinutes: 15
            // Array of calendar sources: { id, name, url, color, enabled }
            property list<var> sources: []
        }
        // Show upcoming events below calendar grid
        property bool showUpcoming: true
        // Number of days to show in upcoming view
        property int upcomingDays: 3
    }

    property JsonObject closeConfirm: JsonObject {
        property bool enabled: false
    }

    property JsonObject conflictKiller: JsonObject {
        property bool autoKillNotificationDaemons: false
        property bool autoKillTrays: false
    }

    property JsonObject crosshair: JsonObject {
        // Valorant crosshair format. Use https://www.vcrdb.net/builder
        property string code: "0;P;d;1;0l;10;0o;2;1b;0"
    }

    property JsonObject display: JsonObject {
        property string primaryMonitor: ""
    }




    property JsonObject interactions: JsonObject {
        property JsonObject scrolling: JsonObject {
            property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
            property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
            property int mouseScrollFactor: 120
            property int touchpadScrollFactor: 450
            property bool invertWorkspaces: false // Invert scroll direction
        }
        property JsonObject deadPixelWorkaround: JsonObject { // Hyprland leaves out 1 pixel on the right for interactions
            property bool enable: false
        }
    }

    property JsonObject language: JsonObject {
        property string ui: "auto" // UI language. "auto" for system locale, or specific language code like "zh_CN", "en_US"
        property JsonObject translator: JsonObject {
            property string engine: "auto" // Run `trans -list-engines` for available engines. auto should use google
            // Defaults tuned for ES -> EN (American English)
            // Codes follow what `trans` expects, e.g. "es" and "en"
            property string targetLanguage: "en" // American English
            property string sourceLanguage: "es" // Spanish
        }
    }

    property JsonObject light: JsonObject {
        property JsonObject night: JsonObject {
            property bool automatic: false
            property bool enabled: false // Manual night light state when automatic mode is disabled
            property string from: "19:00" // Format: "HH:mm", 24-hour time
            property string to: "06:30"   // Format: "HH:mm", 24-hour time
            property int colorTemperature: 6000
        }
        property JsonObject antiFlashbang: JsonObject {
            property bool enable: false
        }
    }

    property JsonObject lock: JsonObject {
        property bool useHyprlock: false
        property bool launchOnStartup: false
        property JsonObject security: JsonObject {
            property bool unlockKeyring: true
            property bool requirePasswordToPower: false
        }
        property string loginScreen: "auto" // SDDM look: "auto" (the family's own, plugin.json `loginScreen`, else classic), "classic" or a family's look
        property string loginStyle: "lens" // the iRiS login's composition: "cover", "frame" or "lens"
        property bool enableAnimation: false // Play video/GIF wallpapers on lock screen (default: show first frame)
    }

    property JsonObject media: JsonObject {
        // Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)
        property bool filterDuplicatePlayers: true
        // Popup mode: "dock" (bottom overlay, default) or "bar" (anchored to bar widget)
        property string popupMode: "dock"
        property list<string> screenList: []
    }

    property JsonObject hotspot: JsonObject {
        property string ssid: "iNiR Hotspot"
        property string password: ""
        property string band: "bg" // "bg" = 2.4GHz, "a" = 5GHz
    }

    property JsonObject keyboardIndicators: JsonObject {
        property bool showPopup: true
        property bool showPanel: true
        property JsonObject popup: JsonObject {
            property bool layout: true
            property bool caps: true
            property bool num: false
        }
        property JsonObject panel: JsonObject {
            property bool layout: true
            property bool caps: true
            property bool num: false
        }
    }

    property JsonObject networking: JsonObject {
        property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
    }

    property JsonObject notifications: JsonObject {
        property int timeout: 7000
        property list<string> screenList: []
        // App/service names dropped at notification ingress. Empty = allow all.
        property list<string> blockedApps: []
        // Apps delivered quietly: kept in the history, with no banner, sound or unread mark (their app keys).
        property list<string> silentApps: []
        // Daily window where popups are suppressed. History is unaffected.
        // A window whose end is before its start wraps past midnight.
        property JsonObject quietHours: JsonObject {
            property bool enable: false
            property string start: "22:00"
            property string end: "08:00"
        }
        // Timeouts por urgencia (ms). 0 = no expira automáticamente
        property int timeoutLow: 5000
        property int timeoutNormal: 7000
        property int timeoutCritical: 0
        // Always use user timeout settings instead of app-defined ones
        property bool ignoreAppTimeout: false
        // Max popup lifetime (ms). Caps persistent notifications. 0 = no cap.
        property int maxPopupLifetime: 30000
        // Do Not Disturb mode
        property bool silent: false
        // Use legacy manual counter (false = auto-sync with popup list, true = manual counter)
        property bool useLegacyCounter: true
    }

    property JsonObject osd: JsonObject {
        property int timeout: 1000
        property bool mediaEnabled: true
        property list<string> screenList: []
        property JsonObject connections: JsonObject {
            property bool enable: true
            property bool network: true
            property bool internet: true
            property bool bluetooth: true
            property bool usb: true
            property bool power: true
            property bool audio: true
            property bool displays: true
            property bool drives: true
        }
    }

    property JsonObject osk: JsonObject {
        property string layout: "qwerty_full"
        property bool pinnedOnStartup: false
        property bool keepOnTop: false
    }

    property JsonObject overlay: JsonObject {
        property bool openingZoomAnimation: true
        property bool darkenScreen: true
        property real clickthroughOpacity: 0.8
        property real backgroundOpacity: 0.9 // 0-1, opacidad de los paneles de overlay
        property int scrimDim: 35 // 0-100, intensidad del oscurecido de pantalla
        // Duraciones de animación del overlay (ms)
        property int animationDurationMs: 180
        property int scrimAnimationDurationMs: 140
        property JsonObject floatingImage: JsonObject {
            property string imageSource: "https://media.tenor.com/H5U5bJzj3oAAAAAi/kukuru.gif"
            property real scale: 0.5
        }
        property JsonObject gamePerformance: JsonObject {
            property bool transparentBackground: false
            // -1 inherits overlay.backgroundOpacity.
            property real backgroundOpacity: -1
        }
    }

    property JsonObject overview: JsonObject {
        property bool enable: true
        property real scale: 0.17 // Relative to screen size
        property real rows: 3
        property real columns: 1
        property bool centerIcons: true
        property bool backgroundBlurEnable: true
        property int backgroundBlurRadius: 22
        property int backgroundDim: 35
        property int scrimDim: 35
        property int topMargin: 0
        property int bottomMargin: 0
        property bool respectBar: true
        property real maxPanelWidthRatio: 1.0
        property int workspaceSpacing: 5
        property int windowTileMargin: 6
        property int iconMinSize: 0
        property int iconMaxSize: 0
        property bool showWorkspaceNumbers: true
        property bool switchToWorkspaceOnOpen: false
        property int switchWorkspaceIndex: 0
        property bool focusAnimationEnable: true
        property int focusAnimationDurationMs: 180
        property int scrollWorkspaceSteps: 2
        property bool keepOverviewOpenOnWindowClick: true
        property bool closeAfterWindowMove: true
        property bool showPreviews: false // Show window thumbnails in overview
        property bool activeScreenOnly: true // Show only on active screen (multi-monitor)
        property bool allAppsGrid: false // Show an all-apps grid instead of the workspace overview
        property string allAppsGridMode: "minimal" // "minimal" (alphabetical) or "folder" (by category)
        property JsonObject dashboard: JsonObject {
            property bool enable: false
            property bool showToggles: true
            property bool showMedia: true
            property bool showVolume: true
            property bool showWeather: true
            property bool showSystem: true
        }
    }

    property JsonObject orbit: JsonObject {
        property bool enable: true
        property string stageMode: "stage" // "stage" | "orbital"
        property bool backdropBlurEnable: true
        property string backdropBlurMode: "" // "" | "shell" | "off"; legacy inherit/niri resolve to shell
        property int backdropBlurStrength: 72
        property int backdropBlurSaturation: 18
        property int backdropBlurTint: 28
        property bool hotCornerEnable: true
        property string hotCorner: "topRight"
        property int hotCornerSize: 12
        property int hotCornerActivationDistance: 2
        property int hotCornerDwellMs: 0
        property int workspaceCount: 3
        property int workspaceScalePercent: 27
        property int maxPanelWidthPercent: 92
        property int workspaceSpacing: 18
        property int windowGap: 4
        property string windowLabels: "hover" // "hover" | "always" | "off"
        property bool windowLabelIcons: true
        property int scrimDim: 35
        property bool showWorkspaceNumbers: true
        property bool balancedGrid: true
        property bool closeOnSelect: true
        property bool keyboardNavigation: true
        property bool scrollNavigation: true
        property int scrollSteps: 1
        property bool scrollSwitchWorkspace: true
        property bool scrollWrapAround: false
        property bool canvasScrubNavigation: true
        property int canvasScrubThreshold: 96
        property string userPresetJson: ""
        property JsonObject studio: JsonObject {
            property string surfaceStyle: "ricelin" // "current" | "ricelin"
            property int widthPercent: 26
            property string density: "compact" // "compact" | "comfortable"
            property bool showDescriptions: true
        }
        property JsonObject presentation: JsonObject {
            property string preset: "adaptive" // "adaptive" | "soft" | "float" | "sweep" | "instant"
            property bool advanced: false
            property string entryStyle: "cascade" // "fade" | "drift" | "cascade" | "instant"
            property string direction: "top" // "center" | "top" | "bottom" | "left" | "right"
            property int distance: 92
            property int enterDurationMs: 300
            property int exitDurationMs: 220
            property int entryDelayMs: 64
            property int entryStaggerMs: 42
            property int shelfDelayMs: 72
            property int entryOpacityPercent: 0
        }
        property JsonObject navigationMotion: JsonObject {
            property string preset: "fluid" // "snappy" | "fluid" | "cinematic" | "instant" | "custom"
            property bool advanced: false
            property int durationMs: 320
            property string easing: "smooth" // "direct" | "smooth" | "linear"
        }
        property bool showTrail: true
        property int trailItems: 5
        property bool showStash: true
        property bool showNewWorkspaceDrop: true
        property string stashRestoreMode: "original"
        property JsonObject orbital: JsonObject {
            property string layout: "orbit" // "orbit" | "horizon" | "gallery" | "deck" | "atlas"
            property int visibleWorkspaces: 5
            property int coreSizePercent: 48
            property int satelliteSizePercent: 42
            property int horizontalSpreadPercent: 82
            property int verticalSpreadPercent: 58
            property int depthPercent: 18
            property JsonObject surface: JsonObject {
                property string style: "current" // "current" | "ricelin"
                property bool outline: true
                property int outlineWidth: 1
                property int outlineOpacityPercent: 72
                property int frameInset: 5
                property string shadowMode: "core" // "off" | "core" | "all"
                property int shadowOpacityPercent: 72
                property int coreElevation: 2
                property int satelliteElevation: 1
                property int radiusPercent: 100
            }
            property JsonObject geometry: JsonObject {
                property bool advanced: false
                property int edgePadding: 10
                property int horizonGap: 12
                property int horizonInset: 24
                property int horizonVerticalBase: 8
                property int horizonVerticalRange: 26
                property int galleryBaseGap: 34
                property int galleryRowGap: 14
                property int deckBaseGap: 26
                property int deckStep: 44
                property int deckLiftStep: 24
                property int atlasGap: 14
                property int atlasColumns: 3
                property int atlasCoreBoostPercent: 10
                property int coreContentMargin: 9
                property int satelliteContentMargin: 6
            }
            property bool satellitePreviews: true
            property string satelliteClickAction: "select" // "select" | "enter"
            property bool showWorkspaceLabels: true
            property string workspaceLabelMode: "" // "" preserves legacy showWorkspaceLabels; index | name | workspace | full | off
            property bool showWorkspaceWallpaper: true
            property int workspaceWallpaperOpacity: 70
        }
        property JsonObject pocket: JsonObject {
            property string layout: "cards"
            property bool showPreviews: true
        }
        property JsonObject shelf: JsonObject {
            property bool enable: true
            property bool showStudioButton: true
            property string layout: "islands" // "bar" | "islands" | "minimal"
            property string density: "comfortable" // "comfortable" | "compact" | "huge"
            property string labels: "auto" // "auto" | "always" | "icons"
            property string islandStyle: "material" // "material" | "ricelin"
            property int moduleSpacing: 7
            property int islandPadding: 8
            property string trailScope: "output" // "output" | "workspace"
            property string locatorLabel: "auto" // "auto" | "index" | "name"
            property list<string> modules: ["locator", "trail", "niri", "actions", "stash"]
            property list<string> niriActions: ["maximize", "consume", "expel"]
            property list<string> pinnedActions: ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
            property bool closeOnAction: true
        }
    }

    // Settings for the custom Alt-Tab switcher in ii
    property JsonObject altSwitcher: JsonObject {
        // Preset style: "default" (sidebar) or "list" (centered list)
        property string preset: "default"
        property bool noVisualUi: false
        // Whether to tint app icons (monochrome), similar to dock/workspaces
        property bool monochromeIcons: false
        // Enable/disable slide in/out animation
        property bool enableAnimation: true
        // Slide animation duration in milliseconds
        property int animationDurationMs: 200
        // Whether to order windows by most recently used (MRU) instead of by workspace/app name
        property bool useMostRecentFirst: true
        // Enable local glass-like blur behind the switcher panel
        property bool enableBlurGlass: true
        // Background opacity for the switcher panel (0-1)
        property real backgroundOpacity: 0.9
        // Blur strength for the glass effect (0-1, mapped from UI percentage)
        property real blurAmount: 0.4
        // Dim strength for the fullscreen scrim (0-100)
        property int scrimDim: 35
        property string panelAlignment: "right" // right | center
        property bool useM3Layout: false
        property bool compactStyle: false // Compact horizontal icon-only style
        property bool showOverviewWhileSwitching: false
        property int autoHideDelayMs: 500
    }

    property JsonObject regionSelector: JsonObject {
        property int borderSize: 4
        property int numSize: 48
        // Remember the snip action/shape picked in the overlay toolbar,
        // so the screenshot keybind reopens with the same choice.
        property bool rememberSnipChoice: true
        // Tesseract language expression. "auto" follows the session locale;
        // explicit values may combine installed models with +.
        property string ocrLanguage: "auto"
        property JsonObject japaneseLookup: JsonObject {
            property bool enabled: true
            property string translationTarget: "auto" // auto follows UI/system locale; common targets: en, es
            property JsonObject anki: JsonObject {
                property bool enabled: false
                property string endpoint: "http://127.0.0.1:8765"
                property string deck: "Default"
                property string model: "Basic"
                property string frontField: "Front"
                property string backField: "Back"
            }
        }
        property int lastAction: 0 // SnipAction ordinal: 0 Shot, 1 Edit, 2 Search, 3 OCR (Record never persists)
        property int lastMode: 0 // SelectionMode ordinal: 0 rectangle, 1 circle
        property JsonObject targetRegions: JsonObject {
            property bool windows: true
            property bool layers: false
            property bool content: true
            property bool showLabel: false
            property real opacity: 0.3
            property real contentRegionOpacity: 0.8
            property int selectionPadding: 5
        }
        property JsonObject rect: JsonObject {
            property bool showAimLines: true
        }
        property JsonObject circle: JsonObject {
            property int strokeWidth: 6
            property int padding: 10
        }
        property JsonObject annotation: JsonObject {
            property bool useSatty: false
            // Use the in-shell native annotation editor for the Edit action
            // instead of the external swappy/satty tools.
            property bool useNativeEditor: true
        }
        property string savePath: "" // Empty = use XDG Pictures/Screenshots
        property string screenshotNameFormat: "ss-%Y%m%d-%H%M%S" // date(1) format for screenshot filenames (without extension)
    }

    property JsonObject resources: JsonObject {
        property int updateInterval: 3000
        property bool monitorGpu: true
        property int tempCautionThreshold: 65
        property int tempWarningThreshold: 80
        property int memoryWarningThreshold: 95
        property int swapWarningThreshold: 85
        property int cpuWarningThreshold: 90
        property int gpuWarningThreshold: 90
    }

    property JsonObject musicRecognition: JsonObject {
        property int timeout: 16
        property int interval: 4
    }

    property JsonObject voiceSearch: JsonObject {
        property int duration: 5
        property string provider: "auto" // auto | local | groq | gemini | openai
        property string language: "auto"
        property string localModelPath: ""
        property string groqModel: "whisper-large-v3-turbo"
        property string geminiModel: "gemini-2.5-flash"
        property string openaiModel: "gpt-4o-mini-transcribe"
    }

    property JsonObject shelf: JsonObject {
        property bool enable: true // what you copied, shot and dropped (iRiS shows it on the Island)
        property int length: 24
        property bool images: true
        property bool clearOnLogout: false
    }

    property JsonObject clipboard: JsonObject {
        // Decoded text of pinned entries, newest first. Stored decoded so a
        // pin survives cliphist rotating its store past the original id.
        property list<string> pinned: []
    }

    property JsonObject search: JsonObject {
        property string style: "default" // "default" | "island" (Ricelin gradient card surface)
        property int nonAppResultDelay: 30 // This prevents lagging when typing
        property string engineBaseUrl: "https://www.google.com/search?q="
        property list<string> excludedSites: ["quora.com", "facebook.com"]
        property bool sloppy: false // Uses levenshtein distance based scoring instead of fuzzy sort. Very weird.
        property JsonObject prefix: JsonObject {
            property bool showDefaultActionsWithoutPrefix: true
            property string action: "/"
            property string app: ">"
            property string clipboard: ";"
            property string emojis: ":"
            property string math: "="
            property string shellCommand: "$"
            property string webSearch: "?"
        }
        property JsonObject imageSearch: JsonObject {
            property string imageSearchEngineBaseUrl: "https://yandex.com/images/search?rpt=imageview&url="
            property string fileUploadApiEndpoint: "https://0x0.st"
            property string fileUploadApiFallback: "https://litterbox.catbox.moe/resources/internals/api.php"
            property string fileUploadApiFallback2: "https://catbox.moe/user/api.php"
            property bool useCircleSelection: false
        }
        property JsonObject globalActions: JsonObject {
            property bool enableSystem: true
            property bool enableAppearance: true
            property bool enableTools: true
            property bool enableMedia: true
            property bool enableSettings: true
            property bool enablePackages: true
            property bool enableSetup: true
            property bool enableCustom: true
        }
    }


    property JsonObject sounds: JsonObject {
        property bool battery: false
        property bool timer: false
        property bool pomodoro: false
        property string theme: "freedesktop"
        property bool notifications: true
        property real volume: 0.5
        property JsonObject events: JsonObject {
            // Per-event override: "" = theme default; a bare name
            // plays that sound from the current theme; an absolute
            // path (or file://) plays the file directly
            property string notification: ""
            property string notificationCritical: ""
            property string batteryLow: ""
            property string batteryCritical: ""
            property string batteryFull: ""
            property string powerPlug: ""
            property string powerUnplug: ""
            property string pomodoroDone: ""
            property string timerDone: ""
        }
    }

    property JsonObject time: JsonObject {
        // https://doc.qt.io/qt-6/qtime.html#toString
        property string format: "hh:mm"
        property string shortDateFormat: "dd/MM"
        property string dateFormat: "ddd, dd/MM"
        property JsonObject pomodoro: JsonObject {
            property int breakTime: 300
            property int cyclesBeforeLongBreak: 4
            property int focus: 1500
            property int longBreak: 900
        }
        property bool secondPrecision: false
    }

    property JsonObject wallpapers: JsonObject {
        property string directory: "" // Custom wallpapers directory path. Empty = ~/Pictures/Wallpapers
    }

    property JsonObject wallpaperSelector: JsonObject {
        property bool useSystemFileDialog: false
        property string selectionTarget: "main"
        property string targetMonitor: ""
        property string style: "grid" // "grid" | "coverflow" | "launcher"
        property string coverflowView: "gallery" // "gallery" | "skew"
    }

    property JsonObject screenRecord: JsonObject {
        property JsonObject recordingOsd: JsonObject {
            property bool autoHide: false
        }
        property bool showOsd: false
        property bool showNotifications: true
        property string savePath: "" // Empty = use XDG Videos or ~/Videos
        property string qualityPreset: "balanced"
        property string videoCodec: "libx264"
        property string audioCodec: "aac"
        property string accelerationMode: "auto"
        property string hardwareDevice: "/dev/dri/renderD128"
        property int fps: 60
        property int videoBitrateKbps: 12000
        property int audioBitrateKbps: 192
        property string audioMode: "system" // "none" | "system" | "microphone" | "both"
        property string audioSource: "" // Legacy single-source override; retained for existing configs
        property string systemAudioSource: "" // Empty = default sink monitor
        property string microphoneSource: "" // Empty = default non-monitor source
        property string audioBackend: ""
        property int audioSampleRate: 48000
        property string pixelFormat: "yuv420p"
        property string preset: "veryfast"
        property int crf: 21
        property string vaapiFilter: "scale_vaapi=format=nv12:out_range=full"
        property bool enableFallback: true
        property string recordingNameFormat: "recording_%Y-%m-%d_%H.%M.%S" // date(1) format for recording filenames (without extension)
        property JsonObject discordCompress: JsonObject {
            property bool enabled: false
            property real targetSizeMb: 10
            property real safetyMarginMb: 0.5
            property bool onlyIfNeeded: true
            property int audioBitrateKbps: 96
            property string preset: "slow"
            property int maxDimension: 1280
        }
    }

    property JsonObject windows: JsonObject {
        property bool showTitlebar: true // Client-side decoration for shell apps
        property bool centerTitle: true
        // Optional per-window identity remapping for apps whose windows
        // all share one app_id (e.g. browser PWA windows). Each entry:
        // { appIdRegex, titleRegex, desktopId } — both regexes are
        // optional but at least one is required. The first matching
        // rule wins; malformed rules are ignored; empty = no changes.
        property list<var> appIdentityRules: []
    }


    property JsonObject hacks: JsonObject {
        property int arbitraryRaceConditionDelay: 20 // milliseconds
    }

    property JsonObject tray: JsonObject {
        property bool monochromeIcons: true
        property bool showItemId: false
        property bool invertPinnedItems: true
        property list<string> pinnedItems: []
        property bool filterPassive: true
    }
    property JsonObject updates: JsonObject {
        property int checkInterval: 120
        property int adviseUpdateThreshold: 75
        property int stronglyAdviseUpdateThreshold: 200
    }
    property JsonObject vpn: JsonObject {
        // The VPN button in the Control Center / quick controls. Off by default:
        // it changes the toggle grid's shape, so it is asked for, not assumed.
        property bool quickToggle: false
        // The VPN card's details: addresses, name, account, exit node, devices and live traffic.
        property bool details: false
    }
    property JsonObject shellUpdates: JsonObject {
        property bool enabled: true
        property int checkIntervalMinutes: 360
        property string dismissedCommit: ""
        property real dismissedAt: 0
        property string lastNotifiedCommit: ""
        // Days before a still-pending update is raised again. 0 tells it once and
        // then stays quiet until the next upstream commit.
        property int remindDays: 3
        property real lastNotifiedAt: 0
        // The hub's pending versions last told, and when (ShellUpdates.maybeNotifyHub).
        property string lastNotifiedHub: ""
        property real lastNotifiedHubAt: 0
        // When true, performUpdate() launches setup in a terminal window so the
        // user sees the full TUI output (progress bars, success/warn/error lines)
        // instead of just the bar pill X/N indicator. Auto-closes on success,
        // pauses on failure so the user can read the error.
        property bool openTerminalOnUpdate: true
    }
    property JsonObject bootGreeting: JsonObject {
        property bool enable: false
        property int autoDismissDelay: 5000
        property bool showWeather: true
        property bool showDate: true
    }
    property JsonObject welcomeWizard: JsonObject {
        property bool completed: false
        property bool skipped: false
        property string profile: "balanced"
        property string stylePreset: "material"
        property string performancePreset: "balanced"
    }

    property JsonObject workspaceStrip: JsonObject {
        // Chrome dialect: "auto" follows the bar (island look only when
        // the pill bar is active), "island"/"stock" force it.
        property string style: "auto"
        property string side: "right"
        property int panelWidth: 480
        property int previewSize: 150
        property int triggerWidth: 6
        property int openDelay: 110
        property int closeDelay: 320
        property bool showPreviews: true
        property bool showAppIcons: true
        property bool showMetadata: true
        property bool showMediaPlayer: true
        property bool perMonitor: true
        property bool scrollNavigation: false
        property bool scrollNavigationSwitchWorkspace: true
        property int scrollNavigationDebounceMs: 180
    }

    property JsonObject weather: JsonObject {
        property bool enable: true
        property bool useUSCS: false // Instead of metric (SI) units
        property int fetchInterval: 10 // minutes
        property string city: "" // Manual city name (e.g. "Buenos Aires"). Empty = auto-detect
        property bool enableGPS: false // Use geoclue GPS if available
        property real manualLat: 0 // Manual latitude (e.g. -34.6037)
        property real manualLon: 0 // Manual longitude (e.g. -58.3816)
        property bool hideLocation: false // Privacy: no city name on any family's weather
    }
    property JsonObject translator: JsonObject {
        property bool enable: false
        property int delay: 300 // Delay before sending request. Reduces (potential) rate limits and lag.
    }
    property JsonObject booru: JsonObject {
        property bool allowNsfw: false
        property string defaultProvider: "yandere"
        property int limit: 20
        property JsonObject gelbooru: JsonObject {
            property string apiKey: ""
            property string userId: ""
        }
        property JsonObject zerochan: JsonObject {
            property string username: "[unset]"
        }
        property JsonObject downloadPath: JsonObject {
            property string sfw: ""
            property string nsfw: ""
        }
    }
    // Wallpapers sidebar options (path kept as wallhaven for config compatibility)
    property JsonObject wallhaven: JsonObject {
        // Enable/disable the Wallpapers tab in the left sidebar
        property bool enable: true
        // Default page size for API search
        property int limit: 24
        property string fitMode: "auto" // "auto" | "native" | "aspect" | "any"
        // Optional API key for NSFW & user-specific filters
        property string apiKey: ""
    }
    // News tab - Google News RSS, geo feed follows the Weather location
    property JsonObject news: JsonObject {
        property bool enable: true
        property string mode: "local" // "local" | "top" | "topic"
        property string topic: "WORLD"
    }
    // Anime Schedule tab - AniList API
    property JsonObject animeSchedule: JsonObject {
        property bool enable: false
        property bool showNsfw: false
        // Custom streaming site URL (use %s for search query placeholder)
        // Examples: "https://9animetv.to/search?keyword=%s", "https://anitaku.pe/search.html?keyword=%s"
        property string watchSite: ""
    }
    // YT Music tab - Search and play YouTube music via yt-dlp
    property JsonObject ytmusic: JsonObject {
        property bool enable: false
        // Legacy persisted key. Browser profiles are never read implicitly on startup;
        // account reconnect is an explicit Connect/Retry action.
        property bool autoConnect: false
        property bool hideSyncBanner: false
        property string browser: ""
        property string cookiesPath: ""
        property bool useManualCookies: false
        property bool connected: false
        property string resolvedBrowserArg: ""
        property string audioQuality: "best"
        property bool normalizeVolume: true   // EBU R128 loudness normalization (YouTube-style, ~-14 LUFS)
        property bool verbose: false
        property bool shuffleMode: false
        property int repeatMode: 0
        property list<string> recentSearches: []
        property list<var> queue: []
        property list<var> playlists: []
        property list<var> liked: []
        property string lastLikedSync: ""
        property bool upNextNotifications: true
        property bool suppressUpNextInFullscreen: true
        property int volume: 100
        property JsonObject profile: JsonObject {
            property string name: ""
            property string avatar: ""
            property string url: ""
        }
        property JsonObject cache: JsonObject {
            property list<var> playlists: []
            property list<var> albums: []
            property list<var> liked: []
        }
        property JsonObject resume: JsonObject {
            property string videoId: ""
            property string title: ""
            property string artist: ""
            property string thumbnail: ""
            property string url: ""
            property real position: 0
            property bool wasPlaying: false
            property list<var> activePlaylist: []
            property int currentIndex: -1
            property string activePlaylistSource: ""
        }
    }
    property JsonObject screenTime: JsonObject {
        property bool enable: false
        property int pollIntervalSeconds: 5
        property int retentionDays: 30
    }
    property JsonObject cornerOpen: JsonObject {
        property bool enable: false
        property bool bottom: false
        property bool valueScroll: true
        property bool clickless: false
        property int cornerRegionWidth: 250
        property int cornerRegionHeight: 5
        property bool visualize: false
        property bool clicklessCornerEnd: true
        property int clicklessCornerVerticalOffset: 1
    }
    // Plugins' own parts of the config, under their key: Config puts the plugin's schema here (plugin.json
    // `configKey`, part `config`), or a holder that keeps the subtree as it is when the plugin is not installed.
    property JsonObject iris

    property JsonObject waffles

    property JsonObject material
    property JsonObject workSafety: JsonObject {
        property JsonObject enable: JsonObject {
            property bool wallpaper: false
            property bool clipboard: false
        }
        property JsonObject triggerCondition: JsonObject {
            property list<string> networkNameKeywords: ["airport", "cafe", "college", "company", "eduroam", "free", "guest", "public", "school", "university"]
            property list<string> fileKeywords: ["anime", "booru", "ecchi", "hentai", "yande.re", "konachan", "breast", "nipples", "pussy", "nsfw", "spoiler", "girl"]
            property list<string> linkKeywords: ["hentai", "porn", "sukebei", "hitomi.la", "rule34", "gelbooru", "fanbox", "dlsite"]
        }
    }
}
