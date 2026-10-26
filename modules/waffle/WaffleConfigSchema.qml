import QtQuick
import Quickshell.Io

// Waffle's part of the shell config (`waffles.*` in config.json): Config holds it in its `waffles` slot once this
// plugin is installed (plugin.json `configKey`).
JsonObject {
    property JsonObject settings: JsonObject {
        property bool useMaterialStyle: false
    }
    property JsonObject modules: JsonObject {
        property bool sidebarLeft: false
        property bool sidebarRight: false
        property bool dock: false
        property bool mediaControls: false
        property bool screenCorners: false
        property bool widgets: true
    }
    property JsonObject tweaks: JsonObject {
        property bool smootherMenuAnimations: true
        property bool switchHandlePositionFix: true
    }
    property JsonObject altSwitcher: JsonObject {
        property string preset: "thumbnails"
        property bool noVisualUi: false
        property bool monochromeIcons: false
        property bool enableAnimation: true
        property int animationDurationMs: 300
        property real backgroundOpacity: 1.0
        property real blurAmount: 0.0
        property int scrimDim: 0
        property int autoHideDelayMs: 500
        property bool showOverviewWhileSwitching: false
        property bool compactStyle: false
        property string panelAlignment: "center"
        property bool useM3Layout: false
        property bool useMostRecentFirst: true
        property bool quickSwitch: false
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
        property JsonObject transition: JsonObject {
            property bool enable: true
            property string type: "crossfade"
            property string direction: "right"
            property int duration: 800
        }
        property JsonObject effects: JsonObject {
            property bool enableBlur: false
            property int blurRadius: 32
            property int dim: 0
            property int dynamicDim: 0
            property bool enableAnimatedBlur: false // Enable blur for animated wallpapers (video/gif) - has performance impact
            property int thumbnailBlurStrength: 70 // Blur strength for animated wallpapers (0-100)
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
            property int dim: 35
            property real saturation: 0
            property real contrast: 0
            property bool vignetteEnabled: false
            property real vignetteIntensity: 0.5
            property real vignetteRadius: 0.7
        }
        property JsonObject parallax: JsonObject {
            property bool enable: false
            property string axis: "horizontal"
            property bool vertical: false
            property bool autoVertical: true
            property bool enableWorkspace: false
            property real workspaceShift: 1.0
            property real workspaceZoom: 1.0
            property real zoom: 1.0
            property bool enableSidebar: false
            property real panelShift: 0.12
            property real widgetsFactor: 1.0
            property real widgetDepth: 1.0
            property bool pauseDuringTransitions: true
            property int transitionSettleMs: 220
        }
        property JsonObject widgets: JsonObject {
            property JsonObject clock: JsonObject {
                property bool enable: false
                property string placementStrategy: "leastBusy"
                property int x: 100
                property int y: 100
                property int dim: 55
                property string fontFamily: "Segoe UI Variable Display"
                property string style: "hero"
                property string timeFormat: "system"
                property string dateStyle: "long"
                property string colorMode: "adaptive"
                property bool showDate: true
                property bool showSeconds: false
                property bool showShadow: true
                property bool showLockStatus: true
                property int timeScale: 100
                property int dateScale: 100
                property JsonObject digital: JsonObject {
                    property bool animateChange: true
                }
            }
        }
    }
    property JsonObject bar: JsonObject {
        property bool bottom: true
        property bool leftAlignApps: false
        property bool monochromeIcons: false
        property bool tintTrayIcons: false
        property int iconSize: 26
        property int searchIconSize: 24
        property list<string> screenList: [] // Waffle taskbar output filter. Empty = all screens.
        property JsonObject activationWatermark: JsonObject {
            property bool enable: false
        }
        property JsonObject desktopPeek: JsonObject {
            property bool hoverPeek: false
            property int hoverDelay: 500
        }
        property JsonObject notifications: JsonObject {
            property bool showUnreadCount: true
        }
    }
    property JsonObject notifications: JsonObject {
        property bool showUnreadCount: true
    }
    property JsonObject actionCenter: JsonObject {
        property list<string> toggles: ["network", "hotspot", "bluetooth", "easyEffects", "powerProfile", "idleInhibitor", "nightLight", "darkMode", "antiFlashbang", "vpn", "cloudflareWarp", "mic", "musicRecognition", "notifications", "onScreenKeyboard", "gameMode", "screenSnip", "colorPicker"]
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
        property bool showCustom: true // cards of custom widgets with a waffle face
        property bool showQuickActions: true
        property list<string> quickActions: ["files", "terminal", "settings", "wallpaper", "screenshot", "screenRecord", "session"]
        // Individual quick action toggles (used by settings switches)
        property bool showFiles: true
        property bool showTerminal: true
        property bool showSettings: true
        property bool showWallpaper: true
        property bool showScreenshot: true
        property bool showScreenRecord: true
        property bool showSession: true
        property bool showColorScheme: true
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
