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
    property string searchText: ""
    property var searchResults: []
    property bool navExpanded: width > 800
    
    // Complete search index with all individual options + targetLabel for spotlight
    property var searchIndex: [
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
        { pageIndex: 1, pageName: "General", section: "Time & Language", label: "Language", targetLabel: "Language", keywords: ["language", "locale", "translation", "idioma", "español", "english"] },
        // Window Management
        { pageIndex: 1, pageName: "General", section: "Window Management", label: "Confirm before closing", targetLabel: "Confirm before closing", keywords: ["close", "confirm", "window", "dialog", "super+q"] },
        // Sounds
        { pageIndex: 1, pageName: "General", section: "Sounds", label: "Battery sounds", targetLabel: "Battery sounds", keywords: ["sound", "audio", "battery", "beep"] },
        { pageIndex: 1, pageName: "General", section: "Sounds", label: "Notification sounds", targetLabel: "Notification sounds", keywords: ["sound", "audio", "notification", "alert"] },
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
        
        // === Taskbar (2) ===
        { pageIndex: 2, pageName: "Taskbar", section: "Position & Layout", label: "Bottom position", targetLabel: "Bottom position", keywords: ["taskbar", "bar", "position", "bottom", "top"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Position & Layout", label: "Left-align apps", targetLabel: "Left-align apps", keywords: ["taskbar", "align", "left", "center", "apps"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Icons", label: "Tint app icons", targetLabel: "Tint app icons", keywords: ["taskbar", "icons", "tint", "monochrome", "accent", "color"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Icons", label: "Tint tray icons", targetLabel: "Tint tray icons", keywords: ["tray", "icons", "tint", "system", "monochrome"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Desktop Peek", label: "Enable hover peek", targetLabel: "Enable hover peek", keywords: ["desktop", "peek", "hover", "show", "corner"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Desktop Peek", label: "Hover delay", targetLabel: "Hover delay", keywords: ["desktop", "peek", "delay", "timeout"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Clock & Notifications", label: "Show seconds", targetLabel: "Show seconds", keywords: ["clock", "seconds", "time", "taskbar"] },
        { pageIndex: 2, pageName: "Taskbar", section: "Clock & Notifications", label: "Show unread count", targetLabel: "Show unread count", keywords: ["notification", "badge", "count", "unread", "clock"] },
        
        // === Background (3) ===
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Use Material ii wallpaper", targetLabel: "Use Material ii wallpaper", keywords: ["wallpaper", "background", "material", "share", "image"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper", label: "Waffle wallpaper", targetLabel: "Waffle wallpaper", keywords: ["wallpaper", "background", "waffle", "change", "image"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Enable blur", targetLabel: "Enable blur", keywords: ["blur", "wallpaper", "background", "effect"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Blur radius", targetLabel: "Blur radius", keywords: ["blur", "radius", "intensity"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Dim overlay", targetLabel: "Dim overlay", keywords: ["dim", "dark", "darken", "overlay", "wallpaper"] },
        { pageIndex: 3, pageName: "Background", section: "Wallpaper Effects", label: "Extra dim with windows", targetLabel: "Extra dim with windows", keywords: ["dim", "dynamic", "windows", "wallpaper"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Enable backdrop", targetLabel: "Enable backdrop", keywords: ["backdrop", "overview", "background"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Use separate wallpaper", targetLabel: "Use separate wallpaper", keywords: ["backdrop", "wallpaper", "separate", "different"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Hide main wallpaper", targetLabel: "Hide main wallpaper", keywords: ["backdrop", "wallpaper", "hide", "main"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop blur", targetLabel: "Backdrop blur", keywords: ["backdrop", "blur", "radius"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop dim", targetLabel: "Backdrop dim", keywords: ["backdrop", "dim", "dark"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop saturation", targetLabel: "Backdrop saturation", keywords: ["backdrop", "saturation", "color", "vibrant"] },
        { pageIndex: 3, pageName: "Background", section: "Backdrop (Overview)", label: "Backdrop contrast", targetLabel: "Backdrop contrast", keywords: ["backdrop", "contrast"] },
        
        // === Themes (4) ===
        { pageIndex: 4, pageName: "Themes", section: "Color Theme", label: "Color Theme", targetLabel: "Color Theme", keywords: ["theme", "color", "preset", "gruvbox", "catppuccin", "nord", "dracula", "monokai", "tokyo"] },
        { pageIndex: 4, pageName: "Themes", section: "Dark Mode", label: "Appearance", targetLabel: "Appearance", keywords: ["dark", "light", "mode", "theme", "appearance"] },
        { pageIndex: 4, pageName: "Themes", section: "Color Scheme", label: "Palette type", targetLabel: "Palette type", keywords: ["palette", "scheme", "matugen", "material", "colors", "expressive", "fidelity"] },
        { pageIndex: 4, pageName: "Themes", section: "Waffle Typography", label: "Font family", targetLabel: "Font family", keywords: ["font", "family", "typography", "segoe", "inter", "roboto", "noto"] },
        { pageIndex: 4, pageName: "Themes", section: "Waffle Typography", label: "Font scale", targetLabel: "Font scale", keywords: ["font", "size", "scale", "typography", "bigger", "smaller"] },
        
        // === Interface (5) ===
        { pageIndex: 5, pageName: "Interface", section: "Notifications", label: "Normal timeout", targetLabel: "Normal timeout", keywords: ["notification", "timeout", "duration", "normal"] },
        { pageIndex: 5, pageName: "Interface", section: "Notifications", label: "Low priority timeout", targetLabel: "Low priority timeout", keywords: ["notification", "timeout", "low", "priority"] },
        { pageIndex: 5, pageName: "Interface", section: "Notifications", label: "Critical timeout", targetLabel: "Critical timeout", keywords: ["notification", "timeout", "critical", "urgent"] },
        { pageIndex: 5, pageName: "Interface", section: "Notifications", label: "Ignore app timeout", targetLabel: "Ignore app timeout", keywords: ["notification", "timeout", "app", "ignore", "override"] },
        { pageIndex: 5, pageName: "Interface", section: "Notifications", label: "Popup position", targetLabel: "Popup position", keywords: ["notification", "position", "popup", "corner", "top", "bottom", "left", "right"] },
        { pageIndex: 5, pageName: "Interface", section: "Notifications", label: "Do Not Disturb", targetLabel: "Do Not Disturb", keywords: ["notification", "dnd", "silent", "mute", "disturb", "quiet"] },
        { pageIndex: 5, pageName: "Interface", section: "On-Screen Display", label: "OSD timeout", targetLabel: "OSD timeout", keywords: ["osd", "volume", "brightness", "timeout", "duration"] },
        { pageIndex: 5, pageName: "Interface", section: "Lock Screen", label: "Enable blur", targetLabel: "Enable blur", keywords: ["lock", "screen", "blur", "background"] },
        { pageIndex: 5, pageName: "Interface", section: "Lock Screen", label: "Blur radius", targetLabel: "Blur radius", keywords: ["lock", "screen", "blur", "radius"] },
        { pageIndex: 5, pageName: "Interface", section: "Lock Screen", label: "Center clock", targetLabel: "Center clock", keywords: ["lock", "screen", "clock", "center", "position"] },
        { pageIndex: 5, pageName: "Interface", section: "Lock Screen", label: "Show 'Locked' text", targetLabel: "Show 'Locked' text", keywords: ["lock", "screen", "text", "locked"] },
        { pageIndex: 5, pageName: "Interface", section: "Screen Corners", label: "Fake rounded corners", targetLabel: "Fake rounded corners", keywords: ["screen", "corners", "rounded", "rounding", "fake"] },
        
        // === Modules (6) ===
        { pageIndex: 6, pageName: "Modules", section: "Panel Style", label: "Panel family", targetLabel: "Panel family", keywords: ["panel", "family", "style", "material", "waffle", "windows"] },
        { pageIndex: 6, pageName: "Modules", section: "Material Modules in Waffle", label: "Left Sidebar", targetLabel: "Left Sidebar", keywords: ["sidebar", "left", "ai", "chat", "translator"] },
        { pageIndex: 6, pageName: "Modules", section: "Material Modules in Waffle", label: "Right Sidebar", targetLabel: "Right Sidebar", keywords: ["sidebar", "right", "quick", "settings", "calendar"] },
        { pageIndex: 6, pageName: "Modules", section: "Material Modules in Waffle", label: "Dock", targetLabel: "Dock", keywords: ["dock", "macos", "pinned", "apps"] },
        { pageIndex: 6, pageName: "Modules", section: "Material Modules in Waffle", label: "Media Controls Overlay", targetLabel: "Media Controls Overlay", keywords: ["media", "controls", "overlay", "music", "player"] },
        { pageIndex: 6, pageName: "Modules", section: "Material Modules in Waffle", label: "Screen Corners", targetLabel: "Screen Corners", keywords: ["screen", "corners", "hot", "rounded"] },
        { pageIndex: 6, pageName: "Modules", section: "Waffle Modules", label: "Widgets Panel", targetLabel: "Widgets Panel", keywords: ["widgets", "panel", "weather", "system", "media"] },
        { pageIndex: 6, pageName: "Modules", section: "Waffle Modules", label: "Desktop Backdrop", targetLabel: "Desktop Backdrop", keywords: ["backdrop", "desktop", "overview", "blur"] },
        
        // === Waffle Style (7) ===
        { pageIndex: 7, pageName: "Waffle Style", section: "Theming", label: "Use Material colors", targetLabel: "Use Material colors", keywords: ["material", "colors", "theme", "grey", "accent"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Style", targetLabel: "Style", keywords: ["alt", "tab", "switcher", "style", "thumbnails", "cards", "compact", "list"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Quick switch", targetLabel: "Quick switch", keywords: ["alt", "tab", "quick", "switch", "fast"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Most recent first", targetLabel: "Most recent first", keywords: ["alt", "tab", "recent", "order", "mru"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Auto-hide", targetLabel: "Auto-hide", keywords: ["alt", "tab", "auto", "hide", "timeout"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Alt+Tab Switcher", label: "Auto-hide delay", targetLabel: "Auto-hide delay", keywords: ["alt", "tab", "auto", "hide", "delay", "timeout"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Behavior", label: "Allow multiple panels open", targetLabel: "Allow multiple panels open", keywords: ["panels", "multiple", "open", "start", "action"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Behavior", label: "Smoother menu animations", targetLabel: "Smoother menu animations", keywords: ["menu", "animations", "smooth", "popup"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Widgets Panel", label: "Show date & time", targetLabel: "Show date & time", keywords: ["widgets", "date", "time", "clock"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Widgets Panel", label: "Show weather", targetLabel: "Show weather", keywords: ["widgets", "weather", "temperature", "forecast"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Widgets Panel", label: "Show system info", targetLabel: "Show system info", keywords: ["widgets", "system", "info", "cpu", "ram", "memory"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Widgets Panel", label: "Show media controls", targetLabel: "Show media controls", keywords: ["widgets", "media", "controls", "music", "player"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Widgets Panel", label: "Show quick actions", targetLabel: "Show quick actions", keywords: ["widgets", "quick", "actions", "buttons"] },
        { pageIndex: 7, pageName: "Waffle Style", section: "Calendar", label: "Force 2-char day names", targetLabel: "Force 2-char day names", keywords: ["calendar", "day", "names", "short", "2char"] },
        
        // === Shortcuts (8) ===
        { pageIndex: 8, pageName: "Shortcuts", section: "", label: "Keyboard Shortcuts", targetLabel: "", keywords: ["shortcuts", "keybinds", "hotkeys", "keyboard", "niri", "super", "mod"] },
        
        // === About (9) ===
        { pageIndex: 9, pageName: "About", section: "", label: "About ii", targetLabel: "", keywords: ["about", "version", "credits", "github", "info"] }
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
        
        for (var i = 0; i < searchIndex.length; i++) {
            var entry = searchIndex[i];
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
    
    // Timer to wait for page to load before spotlight
    Timer {
        id: spotlightTimer
        interval: 100
        repeat: true
        property string targetLabel: ""
        property int retries: 0
        property int maxRetries: 20  // 2 seconds max wait
        
        onTriggered: {
            if (!targetLabel || typeof SettingsSearchRegistry === "undefined") {
                console.log("[Spotlight] No targetLabel or registry")
                stop();
                return;
            }
            
            // Find entry by label in registry
            var entries = SettingsSearchRegistry.entries;
            console.log("[Spotlight] Looking for:", targetLabel, "in page", root.currentPage, "- entries:", entries.length, "retry:", retries)
            
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].label === targetLabel && entries[i].pageIndex === root.currentPage) {
                    console.log("[Spotlight] Found! Focusing option", entries[i].id)
                    SettingsSearchRegistry.focusOption(entries[i].id);
                    retries = 0;
                    stop();
                    return;
                }
            }
            
            // Retry until found or max retries
            retries++;
            if (retries >= maxRetries) {
                console.log("[Spotlight] Max retries reached, giving up")
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
            Layout.preferredWidth: root.navExpanded ? 280 : 64
            color: Looks.colors.bgPanelFooterBase
            
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 4
                
                // Header with app name (expanded)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    spacing: 12
                    visible: root.navExpanded
                    
                    Rectangle {
                        width: 32
                        height: 32
                        radius: Looks.radius.medium
                        color: Looks.colors.accent
                        
                        FluentIcon {
                            anchors.centerIn: parent
                            icon: "settings"
                            implicitSize: 18
                            color: Looks.colors.accentFg
                        }
                    }
                    
                    WText {
                        Layout.fillWidth: true
                        text: Translation.tr("Settings")
                        font.pixelSize: Looks.font.pixelSize.larger
                        font.weight: Font.DemiBold
                    }
                    
                    WBorderlessButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: root.closeRequested()
                        
                        contentItem: FluentIcon {
                            anchors.centerIn: parent
                            icon: "dismiss"
                            implicitSize: 16
                            color: Looks.colors.fg
                        }
                    }
                }
                
                // Header icon (collapsed)
                Rectangle {
                    visible: !root.navExpanded
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    radius: Looks.radius.medium
                    color: Looks.colors.accent
                    
                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "settings"
                        implicitSize: 20
                        color: Looks.colors.accentFg
                    }
                }
                
                // Search bar (only when expanded)
                Rectangle {
                    id: searchBarContainer
                    visible: root.navExpanded
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Looks.radius.medium
                    color: Looks.colors.inputBg
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? Looks.colors.accent : Looks.colors.bg2Border
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }
                    
                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8
                        
                        FluentIcon {
                            icon: "search"
                            implicitSize: 16
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
                                visible: !searchInput.text && !searchInput.activeFocus
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
                                color: clearMouse.containsMouse ? Looks.colors.bg2Hover : "transparent"
                                
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
                
                // Search results dropdown
                Rectangle {
                    id: searchResultsDropdown
                    visible: root.searchText.length > 0 && root.searchResults.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min((searchResultsList.contentHeight || 0) + 8, 300)
                    radius: Looks.radius.large
                    color: Looks.colors.bg1Base
                    border.width: 1
                    border.color: Looks.colors.bg2Border
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        color: Looks.colors.shadow
                        radius: 8
                        samples: 9
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
                                if (resultMouse.containsMouse) return Looks.colors.bg2Hover;
                                return "transparent";
                            }
                            
                            Behavior on color {
                                ColorAnimation { duration: 80 }
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
                                        NumberAnimation { duration: 80 }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // No results indicator
                Rectangle {
                    visible: root.searchText.length > 0 && root.searchResults.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Looks.radius.medium
                    color: Looks.colors.bg1Base
                    
                    RowLayout {
                        anchors.centerIn: parent
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

                Item { height: 8 }
                
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
                        spacing: 2
                        
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
                
                // Expand/collapse button
                WBorderlessButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    
                    contentItem: RowLayout {
                        spacing: 12
                        
                        Item {
                            implicitWidth: 24
                            implicitHeight: 24
                            Layout.leftMargin: root.navExpanded ? 8 : 12
                            
                            FluentIcon {
                                anchors.centerIn: parent
                                icon: root.navExpanded ? "panel-left-contract" : "panel-left-expand"
                                implicitSize: 20
                                color: Looks.colors.fg
                            }
                        }
                        
                        WText {
                            visible: root.navExpanded
                            Layout.fillWidth: true
                            text: Translation.tr("Collapse")
                            font.pixelSize: Looks.font.pixelSize.normal
                        }
                    }
                    
                    onClicked: root.navExpanded = !root.navExpanded
                }
            }
        }
        
        // Separator
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Looks.colors.bg2Border
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
                
                property var visitedPages: ({})
                property bool allPagesLoaded: false
                
                Connections {
                    target: root
                    function onCurrentPageChanged() {
                        pageStack.visitedPages[root.currentPage] = true
                        pageStack.visitedPagesChanged()
                    }
                }
                
                Component.onCompleted: {
                    visitedPages[root.currentPage] = true
                    // Pre-load all pages async for search registration
                    preloadTimer.start()
                }
                
                // Timer to pre-load pages one by one
                Timer {
                    id: preloadTimer
                    interval: 100
                    repeat: true
                    property int nextPage: 1  // Start from 1, page 0 is already loaded
                    
                    onTriggered: {
                        if (nextPage >= root.pages.length) {
                            pageStack.allPagesLoaded = true
                            stop()
                            return
                        }
                        
                        if (!pageStack.visitedPages[nextPage]) {
                            pageStack.visitedPages[nextPage] = true
                            pageStack.visitedPagesChanged()
                        }
                        nextPage++
                    }
                }
                
                Repeater {
                    model: root.pages.length
                    
                    Loader {
                        id: pageLoader
                        required property int index
                        anchors.fill: parent
                        active: Config.ready && (pageStack.visitedPages[index] === true)
                        asynchronous: index !== root.currentPage
                        source: root.pages[index].component
                        visible: index === root.currentPage && status === Loader.Ready
                        opacity: visible ? 1 : 0
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
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
