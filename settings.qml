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

    // Índice de secciones principales de cada página para el buscador
    property var settingsSearchIndex: [
        // Quick
        {
            pageIndex: 0,
            pageName: pages[0].name,
            section: Translation.tr("Wallpaper & Colors"),
            label: Translation.tr("Wallpaper & Colors"),
            description: Translation.tr("Wallpaper, palette and transparency settings"),
            keywords: ["wallpaper", "colors", "palette", "theme", "background"]
        },
        {
            pageIndex: 0,
            pageName: pages[0].name,
            section: Translation.tr("Bar & screen"),
            label: Translation.tr("Bar & screen"),
            description: Translation.tr("Bar position and screen rounding"),
            keywords: ["bar", "position", "screen", "round", "corner"]
        },

        // General
        {
            pageIndex: 1,
            pageName: pages[1].name,
            section: Translation.tr("Audio"),
            label: Translation.tr("Audio"),
            description: Translation.tr("Volume protection and limits"),
            keywords: ["audio", "volume", "earbang", "limit", "sound"]
        },
        {
            pageIndex: 1,
            pageName: pages[1].name,
            section: Translation.tr("Battery"),
            label: Translation.tr("Battery"),
            description: Translation.tr("Battery warnings and auto suspend thresholds"),
            keywords: ["battery", "low", "critical", "suspend", "full"]
        },
        {
            pageIndex: 1,
            pageName: pages[1].name,
            section: Translation.tr("Language"),
            label: Translation.tr("Language"),
            description: Translation.tr("Interface language and AI translations"),
            keywords: ["language", "locale", "translation", "gemini"]
        },
        {
            pageIndex: 1,
            pageName: pages[1].name,
            section: Translation.tr("Sounds"),
            label: Translation.tr("Sounds"),
            description: Translation.tr("Battery, Pomodoro and notifications sounds"),
            keywords: ["sound", "notification", "pomodoro", "battery"]
        },
        {
            pageIndex: 1,
            pageName: pages[1].name,
            section: Translation.tr("Time"),
            label: Translation.tr("Time"),
            description: Translation.tr("Clock format and seconds"),
            keywords: ["time", "clock", "24h", "12h", "format"]
        },

        // Bar
        {
            pageIndex: 2,
            pageName: pages[2].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notifications"),
            description: Translation.tr("Notification indicator in the bar"),
            keywords: ["notifications", "unread", "indicator", "count"]
        },
        {
            pageIndex: 2,
            pageName: pages[2].name,
            section: Translation.tr("Positioning"),
            label: Translation.tr("Positioning"),
            description: Translation.tr("Bar position, auto hide and style"),
            keywords: ["bar", "position", "auto hide", "corner", "style"]
        },
        {
            pageIndex: 2,
            pageName: pages[2].name,
            section: Translation.tr("Tray"),
            label: Translation.tr("Tray"),
            description: Translation.tr("System tray icons behaviour"),
            keywords: ["tray", "systray", "icons", "pinned"]
        },
        {
            pageIndex: 2,
            pageName: pages[2].name,
            section: Translation.tr("Utility buttons"),
            label: Translation.tr("Utility buttons"),
            description: Translation.tr("Screen snip, color picker and toggles"),
            keywords: ["screen snip", "color picker", "mic", "dark mode", "performance"]
        },
        {
            pageIndex: 2,
            pageName: pages[2].name,
            section: Translation.tr("Workspaces"),
            label: Translation.tr("Workspaces"),
            description: Translation.tr("Workspace count, numbers and icons"),
            keywords: ["workspace", "numbers", "icons", "delays"]
        },

        // Background
        {
            pageIndex: 3,
            pageName: pages[3].name,
            section: Translation.tr("Parallax"),
            label: Translation.tr("Parallax"),
            description: Translation.tr("Background parallax based on workspace and sidebar"),
            keywords: ["parallax", "background", "zoom", "workspace"]
        },
        {
            pageIndex: 3,
            pageName: pages[3].name,
            section: Translation.tr("Effects"),
            label: Translation.tr("Effects"),
            description: Translation.tr("Wallpaper blur and dim overlay"),
            keywords: ["blur", "dim", "wallpaper", "effects"]
        },
        {
            pageIndex: 3,
            pageName: pages[3].name,
            section: Translation.tr("Widget: Clock"),
            label: Translation.tr("Widget: Clock"),
            description: Translation.tr("Clock widget style and behaviour"),
            keywords: ["clock", "widget", "cookie", "digital"]
        },
        {
            pageIndex: 3,
            pageName: pages[3].name,
            section: Translation.tr("Widget: Weather"),
            label: Translation.tr("Widget: Weather"),
            description: Translation.tr("Background weather widget"),
            keywords: ["weather", "widget", "background"]
        },

        // Themes
        {
            pageIndex: 4,
            pageName: pages[4].name,
            section: Translation.tr("Theme Presets"),
            label: Translation.tr("Theme Presets"),
            description: Translation.tr("Predefined color themes like Gruvbox, Catppuccin, Nord, Dracula"),
            keywords: ["theme", "preset", "gruvbox", "catppuccin", "nord", "dracula", "material", "colors", "palette"]
        },
        {
            pageIndex: 4,
            pageName: pages[4].name,
            section: Translation.tr("Auto Theme"),
            label: Translation.tr("Auto Theme"),
            description: Translation.tr("Automatic colors from wallpaper"),
            keywords: ["auto", "wallpaper", "dynamic", "colors", "matugen"]
        },

        // Interface
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Crosshair overlay"),
            label: Translation.tr("Crosshair overlay"),
            description: Translation.tr("In-game crosshair overlay"),
            keywords: ["crosshair", "overlay", "aim"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Dock"),
            label: Translation.tr("Dock"),
            description: Translation.tr("Dock position and behaviour"),
            keywords: ["dock", "position", "pinned", "hover"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Lock screen"),
            label: Translation.tr("Lock screen"),
            description: Translation.tr("Lock screen behaviour and style"),
            keywords: ["lock", "screen", "hyprlock", "blur"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Notifications"),
            label: Translation.tr("Notifications"),
            description: Translation.tr("Notification timeouts and popup position"),
            keywords: ["notifications", "timeout", "popup", "position"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Region selector (screen snipping/Google Lens)"),
            label: Translation.tr("Region selector (screen snipping/Google Lens)"),
            description: Translation.tr("Screen snipping target regions and Lens behaviour"),
            keywords: ["region", "selector", "snip", "lens", "screenshot"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Sidebars"),
            label: Translation.tr("Sidebars"),
            description: Translation.tr("Sidebar toggles, sliders and corner open"),
            keywords: ["sidebar", "quick toggles", "sliders", "corner"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("On-screen display"),
            label: Translation.tr("On-screen display"),
            description: Translation.tr("OSD timeout"),
            keywords: ["osd", "volume", "brightness", "timeout"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Overview"),
            label: Translation.tr("Overview"),
            description: Translation.tr("Overview scale, rows and columns"),
            keywords: ["overview", "grid", "rows", "columns"]
        },
        {
            pageIndex: 5,
            pageName: pages[5].name,
            section: Translation.tr("Wallpaper selector"),
            label: Translation.tr("Wallpaper selector"),
            description: Translation.tr("Wallpaper picker behaviour"),
            keywords: ["wallpaper", "selector", "file dialog"]
        },

        // Services
        {
            pageIndex: 6,
            pageName: pages[6].name,
            section: Translation.tr("AI"),
            label: Translation.tr("AI"),
            description: Translation.tr("System prompt for sidebar AI"),
            keywords: ["ai", "prompt", "system", "sidebar"]
        },
        {
            pageIndex: 6,
            pageName: pages[6].name,
            section: Translation.tr("Music Recognition"),
            label: Translation.tr("Music Recognition"),
            description: Translation.tr("Song recognition timeout and interval"),
            keywords: ["music", "recognition", "song", "timeout"]
        },
        {
            pageIndex: 6,
            pageName: pages[6].name,
            section: Translation.tr("Networking"),
            label: Translation.tr("Networking"),
            description: Translation.tr("Custom user agent string"),
            keywords: ["network", "user agent", "http"]
        },
        {
            pageIndex: 6,
            pageName: pages[6].name,
            section: Translation.tr("Resources"),
            label: Translation.tr("Resources"),
            description: Translation.tr("Polling interval for resource monitor"),
            keywords: ["resources", "cpu", "memory", "interval"]
        },
        {
            pageIndex: 6,
            pageName: pages[6].name,
            section: Translation.tr("Search"),
            label: Translation.tr("Search"),
            description: Translation.tr("Prefix configuration and engines"),
            keywords: ["search", "prefix", "engine", "web"]
        },
        {
            pageIndex: 6,
            pageName: pages[6].name,
            section: Translation.tr("Weather"),
            label: Translation.tr("Weather"),
            description: Translation.tr("Weather units, GPS and city"),
            keywords: ["weather", "gps", "city", "fahrenheit"]
        },

        // Advanced
        {
            pageIndex: 7,
            pageName: pages[7].name,
            section: Translation.tr("Color generation"),
            label: Translation.tr("Color generation"),
            description: Translation.tr("Wallpaper-based color theming"),
            keywords: ["color", "generation", "theming", "wallpaper"]
        },

        // Shortcuts
        {
            pageIndex: 8,
            pageName: pages[8].name,
            section: Translation.tr("Keyboard Shortcuts"),
            label: Translation.tr("Keyboard Shortcuts"),
            description: Translation.tr("Niri and ii keybindings reference"),
            keywords: ["shortcuts", "keybindings", "hotkeys", "keyboard", "cheatsheet",
                       "terminal", "clipboard", "volume", "brightness", "screenshot", "lock",
                       "workspace", "window", "focus", "move", "fullscreen", "floating",
                       "overview", "settings", "wallpaper", "media", "play", "pause"]
        },

        // Modules
        {
            pageIndex: 9,
            pageName: pages[9].name,
            section: Translation.tr("Panel Modules"),
            label: Translation.tr("Panel Modules"),
            description: Translation.tr("Enable or disable shell modules"),
            keywords: ["modules", "panels", "enable", "disable", "bar", "sidebar", "overview"]
        },
        {
            pageIndex: 9,
            pageName: pages[9].name,
            section: Translation.tr("Alt+Tab Switcher"),
            label: Translation.tr("Alt+Tab Switcher"),
            description: Translation.tr("Window switcher style and behavior"),
            keywords: ["alt", "tab", "switcher", "windows", "thumbnails"]
        },

        // Waffle Style
        {
            pageIndex: 10,
            pageName: pages[10].name,
            section: Translation.tr("Waffle Taskbar"),
            label: Translation.tr("Waffle Taskbar"),
            description: Translation.tr("Windows 11 style taskbar settings"),
            keywords: ["waffle", "taskbar", "windows", "bottom", "tray"]
        },
        {
            pageIndex: 10,
            pageName: pages[10].name,
            section: Translation.tr("Waffle Start Menu"),
            label: Translation.tr("Waffle Start Menu"),
            description: Translation.tr("Start menu size and behavior"),
            keywords: ["waffle", "start", "menu", "apps", "pinned"]
        },
        {
            pageIndex: 10,
            pageName: pages[10].name,
            section: Translation.tr("Waffle Action Center"),
            label: Translation.tr("Waffle Action Center"),
            description: Translation.tr("Quick toggles and action center"),
            keywords: ["waffle", "action", "center", "toggles", "quick"]
        },
        {
            pageIndex: 10,
            pageName: pages[10].name,
            section: Translation.tr("Waffle Widgets"),
            label: Translation.tr("Waffle Widgets"),
            description: Translation.tr("Widgets panel settings"),
            keywords: ["waffle", "widgets", "panel", "weather", "calendar"]
        },

        // About
        {
            pageIndex: 11,
            pageName: pages[11].name,
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
        
        // Fallback: search by label+pageIndex in registry
        if (!control && pendingSpotlightLabel.length > 0) {
            for (var i = 0; i < SettingsSearchRegistry.entries.length; i++) {
                var e = SettingsSearchRegistry.entries[i];
                if (e.pageIndex === pendingSpotlightPageIndex && e.label === pendingSpotlightLabel) {
                    control = e.control;
                    break;
                }
            }
        }
        
        if (control) {
            doSpotlightForControl(control);
        } else if (spotlightRetryCount < spotlightMaxRetries) {
            spotlightRetryCount++;
            spotlightPageLoadTimer.restart();
        } else {
            // Give up after max retries
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightPageIndex = -1;
        }
    }
    
    function doSpotlightForControl(control) {
        if (!control) return;
        
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
                    
                    // Preload all pages asynchronously for search
                    Timer {
                        id: preloadTimer
                        interval: 300
                        repeat: true
                        onTriggered: {
                            while (pagesStack.preloadIndex < root.pages.length) {
                                if (!pagesStack.visitedPages[pagesStack.preloadIndex]) {
                                    pagesStack.visitedPages[pagesStack.preloadIndex] = true
                                    pagesStack.visitedPagesChanged()
                                    pagesStack.preloadIndex++
                                    return // Load one page per tick
                                }
                                pagesStack.preloadIndex++
                            }
                            preloadTimer.stop()
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
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.m3colors.m3outlineVariant

                        layer.enabled: true
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
                                        spacing: 0

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

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: resultItem.modelData.pageName + (resultItem.modelData.section ? " › " + resultItem.modelData.section : "")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: resultItem.ListView.isCurrentItem 
                                                ? Appearance.colors.colOnPrimaryContainer 
                                                : Appearance.colors.colSubtext
                                            elide: Text.ElideRight
                                            opacity: 0.8
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
