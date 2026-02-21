pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 50 // milliseconds
    property bool blockWrites: false

    signal configChanged()

    function flushWrites(): void {
        fileWriteTimer.stop();
        configFileView.writeAdapter();
    }

    function setNestedValue(nestedKey, value) {
        let keys = [];
        if (Array.isArray(nestedKey)) {
            keys = nestedKey;
        } else if (typeof nestedKey === "string") {
            keys = nestedKey.split(".");
        } else {
            console.warn("[Config] setNestedValue called with invalid nestedKey:", nestedKey);
            return;
        }

        if (keys.length === 0) {
            console.warn("[Config] setNestedValue called with empty key");
            return;
        }
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
        root.configChanged()
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.writeAdapter()
        }
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                console.log("[Config] File not found, creating new file.")
                // Ensure parent directory exists
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'))
                Process.exec(["/usr/bin/mkdir", "-p", parentDir])
                writeAdapter();
            }
            // Set ready even on failure so UI doesn't stay blank
            root.ready = true;
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            // Panel system
            property list<string> enabledPanels: [
                "iiBar", "iiBackground", "iiBackdrop", "iiCheatsheet", "iiControlPanel", "iiDock", "iiLock", "iiMediaControls",
                "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard", "iiOverlay",
                "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners", "iiSessionScreen",
                "iiSidebarLeft", "iiSidebarRight", "iiTilingOverlay", "iiVerticalBar", "iiWallpaperSelector", "iiClipboard", "iiShellUpdate"
            ]
            property string panelFamily: "ii" // "ii" or "waffle"
            property bool familyTransitionAnimation: true // Show animated overlay when switching families

            property JsonObject policies: JsonObject {
                property int ai: 1 // 0: No | 1: Yes | 2: Local
                property int weeb: 1 // 0: No | 1: Open | 2: Closet
            }

            property JsonObject ai: JsonObject {
                property string systemPrompt: "## Style\n- Use casual tone, don't be formal! Make sure you answer precisely without hallucination and prefer bullet points over walls of text. You can have a friendly greeting at the beginning of the conversation, but don't repeat the user's question\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a {DISTRO} Linux system\n- Desktop environment: {DE}\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with h2 headers and a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n"
                property string tool: "functions" // search, functions, or none
                property list<var> extraModels: [
                    {
                        "api_format": "openai", // Most of the time you want "openai". Use "gemini" for Google's models
                        "description": "This is a custom model. Edit the config to add more! | Anyway, this is DeepSeek R1 Distill LLaMA 70B",
                        "endpoint": "https://openrouter.ai/api/v1/chat/completions",
                        "homepage": "https://openrouter.ai/deepseek/deepseek-r1-distill-llama-70b:free", // Not mandatory
                        "icon": "spark-symbolic", // Not mandatory
                        "key_get_link": "https://openrouter.ai/settings/keys", // Not mandatory
                        "key_id": "openrouter",
                        "model": "deepseek/deepseek-r1-distill-llama-70b:free",
                        "name": "Custom: DS R1 Dstl. LLaMA 70B",
                        "requires_key": true
                    }
                ]
            }

            property JsonObject appearance: JsonObject {
                property string theme: "auto" // Theme preset ID: "auto" for wallpaper-based, or preset name like "gruvbox-dark", "catppuccin-mocha", "custom", etc.
                property string globalStyle: "material" // "material" | "cards" | "aurora" | "inir" | "angel"
                property string angelSubStyle: "frost" // "frost" | "neon" | "void"
                property JsonObject angel: JsonObject {
                    property JsonObject blur: JsonObject {
                        property real intensity: 0.25
                        property real saturation: 0.15
                        property real overlayOpacity: 0.35
                        property real noiseOpacity: 0.15
                        property real vignetteStrength: 0.4
                    }
                    property JsonObject transparency: JsonObject {
                        property real panel: 0.35
                        property real card: 0.50
                        property real popup: 0.35
                        property real tooltip: 0.25
                    }
                    property JsonObject escalonado: JsonObject {
                        property int offsetX: 2
                        property int offsetY: 2
                        property int hoverOffsetX: 7
                        property int hoverOffsetY: 7
                        property real opacity: 0.40
                        property real borderOpacity: 0.60
                        property real hoverOpacity: 0.60
                    }
                    property JsonObject escalonadoShadow: JsonObject {
                        property int offsetX: 4
                        property int offsetY: 4
                        property int hoverOffsetX: 10
                        property int hoverOffsetY: 10
                        property real opacity: 0.30
                        property real borderOpacity: 0.50
                        property real hoverOpacity: 0.50
                        property bool glass: true
                        property real glassBlur: 0.15
                        property real glassOverlay: 0.50
                    }
                    property JsonObject border: JsonObject {
                        property real width: 1.5
                        property int accentBarHeight: 0
                        property int accentBarWidth: 0
                        property real coverage: 0.0
                        property real opacity: 0.0
                        property real hoverOpacity: 0.0
                        property real activeOpacity: 0.0
                        property int insetGlowHeight: 0
                        property real insetGlowOpacity: 0.0
                    }
                    property JsonObject surface: JsonObject {
                        property int panelBorderWidth: 0
                        property int cardBorderWidth: 1
                        property real panelBorderOpacity: 0.0
                        property real cardBorderOpacity: 0.30
                    }
                    property JsonObject glow: JsonObject {
                        property real opacity: 0.80
                        property real strongOpacity: 0.65
                    }
                    property JsonObject rounding: JsonObject {
                        property int small: 10
                        property int normal: 15
                        property int large: 25
                    }
                    property real colorStrength: 1.0
                    property string customPreset: ""
                }
                property list<string> recentThemes: []  // Last 4 used themes
                property list<string> favoriteThemes: []  // User's favorite themes
                property JsonObject themeSchedule: JsonObject {
                    property bool enabled: false
                    property string dayTheme: "auto"
                    property string nightTheme: "auto"
                    property string dayStart: "06:00"
                    property string nightStart: "18:00"
                }
                // Corner style preference per global style (0=Hug, 1=Float, 2=Rect, 3=Card)
                property JsonObject globalStyleCornerStyles: JsonObject {
                    property int material: 1
                    property int cards: 3
                    property int aurora: 0
                    property int inir: 1
                    property int angel: 1
                }
                property bool extraBackgroundTint: true
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
                property JsonObject transparency: JsonObject {
                    property bool enable: false
                    property bool automatic: true
                    property real backgroundTransparency: 0.11
                    property real contentTransparency: 0.57
                }
                property JsonObject wallpaperTheming: JsonObject {
                    property bool enableAppsAndShell: true
                    property bool enableQtApps: true
                    property bool enableTerminal: true
                    property bool enableVesktop: true
                    property bool useBackdropForColors: false
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
                property JsonObject palette: JsonObject {
                    property string type: "auto" // Allowed: auto, scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot
                }
                property JsonObject typography: JsonObject {
                    property string mainFont: "Roboto Flex"
                    property string titleFont: "Gabarito"
                    property string monospaceFont: "JetBrainsMono Nerd Font"
                    property real sizeScale: 1.0
                    property bool syncWithSystem: true // Sync fonts with GTK/KDE apps
                    property JsonObject variableAxes: JsonObject {
                        property int wght: 300
                        property int wdth: 105
                        property int grad: 175
                    }
                }
                property string iconTheme: "" // System icon theme (tray, GTK/Qt apps)
                property string dockIconTheme: "" // Dock icon theme (overrides system for dock only)
            }

            property JsonObject performance: JsonObject {
                property bool lowPower: false
                property bool reduceAnimations: false
            }

            property JsonObject powerProfiles: JsonObject {
                property bool restoreOnStart: true
                property string preferredProfile: "" // "power-saver" | "balanced" | "performance"
            }

            property JsonObject idle: JsonObject {
                property int screenOffTimeout: 300 // seconds, 0 = disabled
                property int lockTimeout: 600 // seconds, 0 = disabled
                property int suspendTimeout: 0 // seconds, 0 = disabled
                property bool lockBeforeSleep: true
            }

            property JsonObject modules: JsonObject {
                property bool altSwitcher: true
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
                property bool disableAnimations: true
                property bool disableEffects: true
                property bool disableNiriAnimations: true
                property bool disableReloadToasts: true
                property bool disableDiscoverOverlay: true
                property bool minimalMode: true // Make panels transparent/minimal during GameMode
                // Throttle Niri window list updates - 100ms = 10 FPS, sufficient for smooth UI
                // Lower values increase CPU usage with diminishing returns on perceived smoothness
                property int niriWindowListUpdateIntervalMs: 100
                property int niriWindowListUpdateIntervalMsGameMode: 500 // 2 FPS during gaming - minimal overhead
                property int checkInterval: 5000 // ms - fallback only, events are primary
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

            property JsonObject apps: JsonObject {
                property string bluetooth: "kcmshell6 kcm_bluetooth"
                property string network: "kitty -1 fish -c nmtui"
                property string networkEthernet: "kcmshell6 kcm_networkmanagement"
                property string taskManager: "missioncenter"
                property string terminal: "kitty" // This is only for shell actions
                property string volumeMixer: `~/.config/quickshell/ii/scripts/launch_first_available.sh "pavucontrol-qt" "pavucontrol"`
                property string discord: "discord" // Shell command to launch Discord client
                property string update: "kitty -e sudo pacman -Syu" // Command to run system updates
            }

            property JsonObject background: JsonObject {
                property JsonObject widgets: JsonObject {
                    property JsonObject clock: JsonObject {
                        property bool enable: true
                        property string placementStrategy: "leastBusy" // "free", "leastBusy", "mostBusy"
                        property real x: 100
                        property real y: 100
                        property string style: "cookie" // Options: "cookie", "digital"
                        property int dim: 0 // Extra dim for clock text (0-100)
                        property JsonObject cookie: JsonObject {
                            property bool aiStyling: false
                            property int sides: 14
                            property string dialNumberStyle: "full"   // Options: "dots" , "numbers", "full" , "none"
                            property string hourHandStyle: "fill"     // Options: "classic", "fill", "hollow", "hide"
                            property string minuteHandStyle: "medium" // Options "classic", "thin", "medium", "bold", "hide"
                            property string secondHandStyle: "dot"    // Options: "dot", "line", "classic", "hide"
                            property string dateStyle: "bubble"       // Options: "border", "rect", "bubble" , "hide"
                            property bool timeIndicators: true
                            property bool hourMarks: false
                            property bool dateInClock: true
                            property bool constantlyRotate: false
                            property bool useSineCookie: false
                        }
                        property JsonObject digital: JsonObject {
                            property bool animateChange: true
                        }
                        property JsonObject quote: JsonObject {
                            property bool enable: false
                            property string text: ""
                        }
                    }
                    property JsonObject weather: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 400
                        property real y: 100
                    }

                    property JsonObject mediaControls: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property string playerPreset: "full" // "full", "compact", "minimal", "albumart", "visualizer", "classic"
                        property real x: 240
                        property real y: 240
                    }
                }
                property string wallpaperPath: ""
                property string thumbnailPath: ""
                property string fillMode: "fill" // "fill", "fit", "center", "tile"
                property bool enableAnimation: true // Enable animated wallpapers (video/gif). When disabled, shows thumbnail instead (better performance)
                property bool hideWhenFullscreen: true
                property JsonObject effects: JsonObject {
                    property bool enableBlur: false
                    property int blurRadius: 32
                    property int blurStatic: 0 // 0-100, blur mínimo incluso sin ventanas
                    property int videoBlurStrength: 50
                    property int dim: 0 // 0-100 percentage (base overlay)
                    property int dynamicDim: 0 // Extra dim when there are windows on the current workspace (0-100)
                }
                property JsonObject backdrop: JsonObject {
                    property bool enable: true
                    property bool hideWallpaper: false
                    property bool useMainWallpaper: true
                    property string wallpaperPath: ""
                    property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
                    property bool enableAnimation: false // Enable animated wallpapers (video/gif) in backdrop (disabled by default for performance)
                    property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                    property int blurRadius: 32
                    property int dim: 35 // 0-100
                    property real saturation: 1.0
                    property real contrast: 1.0
                    property bool vignetteEnabled: false
                    property real vignetteIntensity: 0.5
                    property real vignetteRadius: 0.7
                    property bool useAuroraStyle: false
                    property real auroraOverlayOpacity: 0.38
                }
                property JsonObject parallax: JsonObject {
                    property bool vertical: false
                    property bool autoVertical: false
                    property bool enableWorkspace: true
                    property real workspaceZoom: 1.07 // Relative to your screen, not wallpaper size
                    property bool enableSidebar: true
                    property real widgetsFactor: 1.2
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
            }

            property JsonObject bar: JsonObject {
                property JsonObject autoHide: JsonObject {
                    property bool enable: false
                    property int hoverRegionWidth: 2
                    property bool pushWindows: false
                    property JsonObject showWhenPressingSuper: JsonObject {
                        property bool enable: true
                        property int delay: 140
                    }
                }
                property bool bottom: false // Instead of top
                property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle
                property int customRounding: -1 // -1: use global theme rounding | 0+: override bar rounding (px)
                property bool floatStyleShadow: true // Show shadow behind bar when cornerStyle == 1 (Float)
                property bool borderless: false // true for no grouping of items
                property string topLeftIcon: "spark" // Options: "distro" or any icon name in ~/.config/quickshell/ii/assets/icons
                property bool showBackground: true
                property bool showScrollHints: true // Show brightness/volume scroll hints on hover
                property JsonObject blurBackground: JsonObject {
                    property bool enabled: false
                    property real overlayOpacity: 0.3
                }
                property bool verbose: true
                property bool vertical: false
                property JsonObject vignette: JsonObject {
                    property bool enabled: false
                    property real intensity: 0.6
                    property real radius: 0.5
                }
                property JsonObject modules: JsonObject {
                    property bool leftSidebarButton: true
                    property bool activeWindow: true
                    property bool resources: true
                    property bool media: true
                    property bool workspaces: true
                    property bool clock: true
                    property bool utilButtons: true
                    property bool battery: true
                    property bool rightSidebarButton: true
                    property bool sysTray: true
                    property bool weather: true
                }
                property JsonObject modulesPlacement: JsonObject {
                    property string resources: "start"
                    property string media: "start"
                    property string workspaces: "center"
                    property string clock: "end"
                    property string utilButtons: "end"
                    property string battery: "end"
                }
                property JsonObject modulesLayout: JsonObject {
                    // Global ordering of central bar modules.
                    // Valid ids: resources, media, workspaces, clock, utilButtons, battery
                    property list<string> order: ["resources", "media", "workspaces", "clock", "utilButtons", "battery"]
                }
                property JsonObject edgeModulesLayout: JsonObject {
                    // Ordering of side modules (left and right sections)
                    // Left side valid ids: leftSidebarButton, activeWindow
                    // Right side valid ids: rightSidebarButton, sysTray, weather
                    property list<string> leftOrder: ["leftSidebarButton", "activeWindow"]
                    property list<string> rightOrder: ["rightSidebarButton", "sysTray", "weather"]
                }
                property JsonObject resources: JsonObject {
                    property bool alwaysShowSwap: true
                    property bool alwaysShowCpu: true
                    property int memoryWarningThreshold: 95
                    property int swapWarningThreshold: 85
                    property int cpuWarningThreshold: 90
                }
                property list<string> screenList: [] // List of names, like "eDP-1", find out with 'hyprctl monitors' command
                property JsonObject utilButtons: JsonObject {
                    property bool showScreenSnip: true
                    property bool showScreenRecord: true
                    property bool showColorPicker: false
                    property bool showMicToggle: false
                    property bool showKeyboardToggle: true
                    property bool showDarkModeToggle: true
                    property bool showPerformanceProfileToggle: false
                    property bool showScreenCast: false
                    property string screenCastOutput: "HDMI-A-1"
                    property bool showNotepad: true
                }
                property JsonObject tray: JsonObject {
                    property bool monochromeIcons: true
                    property bool showItemId: false
                    property bool invertPinnedItems: true // Makes the below a whitelist for the tray and blacklist for the pinned area
                    property list<string> pinnedItems: [ ]
                    property bool filterPassive: true
                }
                property JsonObject workspaces: JsonObject {
                    property string scrollBehavior: "workspace" // "workspace" or "column"
                    property bool monochromeIcons: true
                    property bool dynamicCount: true // Auto-detect workspace count (Niri)
                    property int shown: 10 // Only used when dynamicCount is false
                    property bool wrapAround: true // Cycle from last to first and vice versa
                    property int scrollSteps: 3 // Wheel steps required to switch
                    property bool showAppIcons: true
                    property bool alwaysShowNumbers: false
                    property int showNumberDelay: 300 // milliseconds
                    property list<string> numberMap: ["1", "2"] // Characters to show instead of numbers on workspace indicator
                    property bool useNerdFont: false
                }
                property JsonObject weather: JsonObject {
                    property bool enable: false
                    property bool useUSCS: false // Instead of metric (SI) units
                    property int fetchInterval: 10 // minutes
                    property string city: "" // Manual city name (e.g. "Buenos Aires"). Empty = auto-detect
                    property bool enableGPS: false // Use geoclue GPS if available
                    property real manualLat: 0 // Manual latitude (e.g. -34.6037)
                    property real manualLon: 0 // Manual longitude (e.g. -58.3816)
                }
                property JsonObject indicators: JsonObject {
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: false
                    }
                }
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 5
                property int full: 101
                property bool automaticSuspend: true
                property int suspend: 3
                property bool notifyFull: true
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

            property JsonObject dock: JsonObject {
                property bool cardStyle: false
                property bool enable: false
                property bool monochromeIcons: true
                property string position: "bottom" // "top", "bottom", "left", "right"
                property real height: 60
                property real iconSize: 35
                property real hoverRegionHeight: 2
                property bool pinnedOnStartup: false
                property bool hoverToReveal: true // When false, only reveals on empty workspace
                property bool showOnDesktop: true // Show dock when no window is focused (desktop visible)
                property bool showBackground: true
                property bool minimizeUnfocused: false // Show dot for unfocused apps
                property bool enableBlurGlass: true
                property bool separatePinnedFromRunning: true // Waffle-style: pinned-only apps on left, running on right
                property list<string> pinnedApps: [ // IDs of pinned entries
                    "org.gnome.Nautilus", "firefox", "foot",]
                property list<string> ignoredAppRegexes: []
                property list<string> screenList: [] // List of screen names to show dock on (e.g. ["DP-2"]). Empty = all screens
                // Smart indicator settings
                property bool smartIndicator: true // Show which window is focused
                property bool showAllWindowDots: true // Show dots for all windows (even inactive apps)
                property int maxIndicatorDots: 5 // Maximum dots to show
                // Window preview on hover
                property bool hoverPreview: true // Show window preview popup on hover
                property int hoverPreviewDelay: 400 // Delay before showing preview (ms)
                // Drag & drop reordering
                property bool enableDragReorder: true // Allow drag to reorder pinned apps
            }

            property JsonObject interactions: JsonObject {
                property JsonObject scrolling: JsonObject {
                    property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
                    property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
                    property int mouseScrollFactor: 120
                    property int touchpadScrollFactor: 450
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
                    property bool automatic: true
                    property string from: "19:00" // Format: "HH:mm", 24-hour time
                    property string to: "06:30"   // Format: "HH:mm", 24-hour time
                    property int colorTemperature: 5000
                }
                property JsonObject antiFlashbang: JsonObject {
                    property bool enable: false
                }
            }

            property JsonObject lock: JsonObject {
                property bool useHyprlock: false
                property bool launchOnStartup: false
                property JsonObject blur: JsonObject {
                    property bool enable: true
                    property real radius: 100
                    property real extraZoom: 1.1
                }
                property bool centerClock: true
                property bool showLockedText: true
                property JsonObject security: JsonObject {
                    property bool unlockKeyring: true
                    property bool requirePasswordToPower: false
                }
                property bool materialShapeChars: true
            }

            property JsonObject media: JsonObject {
                // Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)
                property bool filterDuplicatePlayers: true
                // Popup mode: "dock" (bottom overlay, default) or "bar" (anchored to bar widget)
                property string popupMode: "dock"
            }

            property JsonObject networking: JsonObject {
                property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7000
                // Timeouts por urgencia (ms). 0 = no expira automáticamente
                property int timeoutLow: 5000
                property int timeoutNormal: 7000
                property int timeoutCritical: 0
                // Always use user timeout settings instead of app-defined ones
                property bool ignoreAppTimeout: false
                // Posición del popup de notificaciones: topRight, bottomRight, topLeft, bottomLeft
                property string position: "topRight"
                // Margen respecto a los bordes de pantalla (px)
                property int edgeMargin: 4
                // Slightly enlarge notifications when the mouse hovers over them
                property bool scaleOnHover: false
                // Do Not Disturb mode
                property bool silent: false
                // Use legacy manual counter (false = auto-sync with popup list, true = manual counter)
                property bool useLegacyCounter: true
            }

            property JsonObject osd: JsonObject {
                property int timeout: 1000
            }

            property JsonObject osk: JsonObject {
                property string layout: "qwerty_full"
                property bool pinnedOnStartup: false
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
                }
            }

            property JsonObject resources: JsonObject {
                property int updateInterval: 3000
            }

            property JsonObject musicRecognition: JsonObject {
                property int timeout: 16
                property int interval: 4
            }

            property JsonObject voiceSearch: JsonObject {
                property int duration: 5
            }

            property JsonObject search: JsonObject {
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
                    property string imageSearchEngineBaseUrl: "https://lens.google.com/uploadbyurl?url="
                    property bool useCircleSelection: false
                }
            }

            property JsonObject sidebar: JsonObject {
                property bool cardStyle: false
                property bool keepRightSidebarLoaded: true
                property bool keepLeftSidebarLoaded: true
                property bool openFolderOnDownload: false // Open file manager after wallpaper download
                property JsonObject translator: JsonObject {
                    property bool enable: true
                    property int delay: 300 // Delay before sending request. Reduces (potential) rate limits and lag.
                }
                property JsonObject ai: JsonObject {
                    property bool textFadeIn: false
                }
                property JsonObject booru: JsonObject {
                    property bool allowNsfw: false
                    property string defaultProvider: "yandere"
                    property int limit: 20
                    property JsonObject zerochan: JsonObject {
                        property string username: "[unset]"
                    }
                }
                // Wallhaven-specific sidebar module options
                property JsonObject wallhaven: JsonObject {
                    // Enable/disable the Wallhaven tab in the left sidebar
                    property bool enable: true
                    // Default page size for API search
                    property int limit: 24
                    // Optional API key for NSFW & user-specific filters
                    property string apiKey: ""
                }
                // Anime Schedule tab - AniList API
                property JsonObject animeSchedule: JsonObject {
                    property bool enable: false
                    property bool showNsfw: false
                    // Custom streaming site URL (use %s for search query placeholder)
                    // Examples: "https://hianime.to/search?keyword=%s", "https://9animetv.to/search?keyword=%s"
                    property string watchSite: ""
                }
                // Reddit tab - public JSON API
                property JsonObject reddit: JsonObject {
                    property bool enable: false
                    property list<string> subreddits: ["unixporn", "linux", "archlinux", "kde", "gnome"]
                    property int limit: 25
                }
                // Tools tab - Niri debug options and quick actions
                property JsonObject tools: JsonObject {
                    property bool enable: false
                }
                // YT Music tab - Search and play YouTube music via yt-dlp
                property JsonObject ytmusic: JsonObject {
                    property bool enable: false
                    property bool autoConnect: true
                    property bool hideSyncBanner: false
                    property string browser: "firefox"
                    property string cookiesPath: ""
                    property bool connected: false
                    property string resolvedBrowserArg: ""
                    property bool shuffleMode: false
                    property int repeatMode: 0
                    property list<string> recentSearches: []
                    property list<var> queue: []
                    property list<var> playlists: []
                    property list<var> liked: []
                    property string lastLikedSync: ""
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
                }
                // Widgets tab in left sidebar
                property JsonObject widgets: JsonObject {
                    property bool enable: true
                    // Widget visibility
                    property bool media: true
                    property bool week: true
                    property bool context: true
                    property bool note: false
                    property bool launch: false
                    property bool controls: true
                    property bool status: true
                    property bool crypto: false
                    property bool wallpaper: true
                    // ContextCard specific
                    property bool contextShowWeather: true
                    // Widget order (drag to reorder)
                    property list<string> widgetOrder: ["media", "week", "context", "note", "launch", "controls", "status", "crypto", "wallpaper"]
                    // Spacing between widgets (px)
                    property int spacing: 8

                    // GlanceHeader behavior
                    property JsonObject glance: JsonObject {
                        property bool showVolume: true
                        property bool showGameMode: true
                        property bool showDnd: true
                    }

                    // StatusRings behavior
                    property JsonObject statusRings: JsonObject {
                        property bool showCpu: true
                        property bool showRam: true
                        property bool showDisk: true
                        property bool showTemp: true
                        property bool showBattery: true
                    }

                    // ControlsCard behavior
                    property JsonObject controlsCard: JsonObject {
                        property bool showDarkMode: true
                        property bool showDnd: true
                        property bool showNightLight: true
                        property bool showGameMode: true
                        property bool showNetwork: true
                        property bool showBluetooth: true
                        property bool showSettings: true
                        property bool showLock: true
                    }

                    // CryptoWidget behavior
                    property JsonObject crypto_settings: JsonObject {
                        property int refreshInterval: 60
                        property list<string> coins: ["bitcoin", "ethereum"]
                    }

                    // QuickLaunch shortcuts
                    property list<var> quickLaunch: [
                        { "icon": "folder", "name": "Files", "cmd": "/usr/bin/nautilus" },
                        { "icon": "terminal", "name": "Terminal", "cmd": "/usr/bin/kitty" },
                        { "icon": "web", "name": "Browser", "cmd": "/usr/bin/firefox" },
                        { "icon": "code", "name": "Code", "cmd": "/usr/bin/code" }
                    ]

                    // QuickWallpaper settings
                    property JsonObject quickWallpaper: JsonObject {
                        property int itemSize: 72
                        property bool showHeader: true
                    }
                }
                property JsonObject cornerOpen: JsonObject {
                    property bool enable: true
                    property bool bottom: false
                    property bool valueScroll: true
                    property bool clickless: false
                    property int cornerRegionWidth: 250
                    property int cornerRegionHeight: 5
                    property bool visualize: false
                    property bool clicklessCornerEnd: true
                    property int clicklessCornerVerticalOffset: 1
                }

                property JsonObject quickToggles: JsonObject {
                    property string style: "android" // Options: classic, android
                    property JsonObject android: JsonObject {
                        property int columns: 5
                        property list<var> toggles: [
                            { "size": 2, "type": "network" },
                            { "size": 2, "type": "bluetooth"  },
                            { "size": 1, "type": "idleInhibitor" },
                            { "size": 1, "type": "mic" },
                            { "size": 2, "type": "audio" },
                            { "size": 2, "type": "nightLight" }
                        ]
                    }
                }

                property JsonObject quickSliders: JsonObject {
                    property bool enable: false
                    property bool showMic: false
                    property bool showVolume: true
                    property bool showBrightness: true
                }

                // Right sidebar widget toggles
                property JsonObject right: JsonObject {
                    property list<string> enabledWidgets: ["calendar", "todo", "notepad", "calculator", "sysmon", "timer"]
                }
            }

            property JsonObject sounds: JsonObject {
                property bool battery: false
                property bool timer: false
                property bool pomodoro: false
                property string theme: "freedesktop"
                property bool notifications: false
                property real volume: 0.5
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

            property JsonObject wallpaperSelector: JsonObject {
                property bool useSystemFileDialog: false
                property string selectionTarget: "main"
                property string targetMonitor: ""
            }

            property JsonObject screenRecord: JsonObject {
                property string savePath: "" // Empty = use XDG Videos or ~/Videos
            }

            property JsonObject windows: JsonObject {
                property bool showTitlebar: true // Client-side decoration for shell apps
                property bool centerTitle: true
            }

            property JsonObject settingsUi: JsonObject {
                property bool overlayMode: false // true = layer shell overlay (live preview), false = separate window (default)
                property JsonObject overlayAppearance: JsonObject {
                    property int scrimDim: 35           // % dim of the backdrop scrim behind the settings panel (0-100)
                    property real backgroundOpacity: 1.0 // opacity of the settings panel background itself (0.2-1.0)
                    property bool enableBlur: false      // extra blur override for glass background (aurora/angel only)
                }
            }

            property JsonObject hacks: JsonObject {
                property int arbitraryRaceConditionDelay: 20 // milliseconds
            }

            property JsonObject tray: JsonObject {
                property bool monochromeIcons: true
                property bool showItemId: false
                property bool invertPinnedItems: true
                property list<string> pinnedItems: [ ]
                property bool filterPassive: true
            }
            property JsonObject updates: JsonObject {
                property int checkInterval: 120
                property int adviseUpdateThreshold: 75
                property int stronglyAdviseUpdateThreshold: 200
            }
            property JsonObject shellUpdates: JsonObject {
                property bool enabled: true
                property int checkIntervalMinutes: 360
                property string dismissedCommit: ""
                property string lastNotifiedCommit: ""
            }
            property JsonObject welcomeWizard: JsonObject {
                property bool completed: false
                property bool skipped: false
            }

            property JsonObject waffles: JsonObject {
                property JsonObject settings: JsonObject {
                    property bool useMaterialStyle: false
                }
                property JsonObject modules: JsonObject {
                    property bool sidebarLeft: false
                    property bool sidebarRight: false
                    property bool dock: false
                    property bool mediaControls: false
                    property bool screenCorners: false
                }
                property JsonObject tweaks: JsonObject {
                    property bool smootherMenuAnimations: true
                    property bool switchHandlePositionFix: true
                }
                property JsonObject altSwitcher: JsonObject {
                    property string preset: "default"
                    property bool noVisualUi: false
                    property bool monochromeIcons: false
                    property bool enableAnimation: true
                    property int animationDurationMs: 300
                    property real backgroundOpacity: 1.0
                    property real blurAmount: 0.0
                    property int scrimDim: 0
                    property int autoHideDelayMs: 300
                    property bool showOverviewWhileSwitching: false
                    property bool compactStyle: false
                    property string panelAlignment: "center"
                    property bool useM3Layout: false
                    property bool useMostRecentFirst: true
                    property bool quickSwitch: true
                    property bool autoHide: true
                    property bool closeOnFocus: true
                    property int thumbnailWidth: 280
                    property int thumbnailHeight: 180
                    property real scrimOpacity: 0.4
                }
                property JsonObject background: JsonObject {
                    property string wallpaperPath: "" // Empty = use main wallpaper
                    property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
                    property bool useMainWallpaper: true
                    property bool enableAnimation: true // Enable animated wallpapers (video/gif)
                    property bool hideWhenFullscreen: true
                    property JsonObject effects: JsonObject {
                        property bool enableBlur: false
                        property int blurRadius: 32
                        property int blurStatic: 0
                        property int dim: 0
                        property int dynamicDim: 0
                        property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                        property int thumbnailBlurStrength: 70 // Blur strength for animated wallpapers (0-100)
                    }
                    property JsonObject backdrop: JsonObject {
                        property bool enable: false
                        property bool hideWallpaper: false
                        property bool useMainWallpaper: true
                        property string wallpaperPath: ""
                        property string thumbnailPath: "" // Thumbnail for animated wallpapers (video/gif)
                        property bool enableAnimation: false // Enable animated wallpapers (video/gif) in backdrop (disabled by default for performance)
                        property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
                        property int blurRadius: 32
                        property int dim: 35
                        property real saturation: 1.0
                        property real contrast: 1.0
                        property bool vignetteEnabled: false
                        property real vignetteIntensity: 0.5
                        property real vignetteRadius: 0.7
                    }
                }
                property JsonObject bar: JsonObject {
                    property bool bottom: true
                    property bool leftAlignApps: false
                    property bool monochromeIcons: false
                    property bool tintTrayIcons: false
                }
                property JsonObject actionCenter: JsonObject {
                    property list<string> toggles: [ "network", "bluetooth", "easyEffects", "powerProfile", "idleInhibitor", "nightLight", "darkMode", "antiFlashbang", "cloudflareWarp", "mic", "musicRecognition", "notifications", "onScreenKeyboard", "gameMode", "screenSnip", "colorPicker" ]
                }
                property JsonObject calendar: JsonObject {
                    property bool force2CharDayOfWeek: true
                    property string locale: ""
                }
                property JsonObject theming: JsonObject {
                    property bool useMaterialColors: true // Use Material ii colors instead of W11 grey
                    property JsonObject font: JsonObject {
                        property string family: "Noto Sans"
                        property real scale: 1.0 // Font size multiplier (0.8 - 1.5)
                    }
                }
                property JsonObject startMenu: JsonObject {
                    property string sizePreset: "normal" // mini, compact, normal, large, wide
                    property real scale: 1.0 // Start menu scale (0.8 - 1.5)
                }
                property JsonObject behavior: JsonObject {
                    property bool allowMultiplePanels: false // Allow multiple panels open at once (for screenshots)
                }
                property JsonObject widgetsPanel: JsonObject {
                    property bool showDateTime: true
                    property bool showWeather: true
                    property bool showSystem: true
                    property bool showMedia: true
                    property bool showQuickActions: true
                    property bool weatherHideLocation: false // Privacy: hide city name
                }
                property JsonObject workspaceNames: JsonObject {
                    // Custom workspace names, keyed by workspace index (1-based)
                    // Example: "1": "Main", "2": "Work", "3": "Gaming"
                }
                property JsonObject taskView: JsonObject {
                    property string mode: "centered" // "carousel" or "centered"
                    property bool closeOnSelect: false // Close TaskView when clicking a window
                }
            }
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
    }
}
