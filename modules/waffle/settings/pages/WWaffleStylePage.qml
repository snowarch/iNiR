pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 7
    pageTitle: Translation.tr("Waffle Style")
    pageIcon: "desktop"
    pageDescription: Translation.tr("Windows 11 style customization")
    
    property bool isWaffleActive: Config.options?.panelFamily === "waffle"

    // Helper to check if a module is enabled
    function isPanelEnabled(panelId: string): bool {
        return (Config.options?.enabledPanels ?? []).includes(panelId)
    }
    
    // Warning when not active
    WSettingsCard {
        visible: !root.isWaffleActive
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            FluentIcon {
                icon: "info"
                implicitSize: 24
                color: Looks.colors.accent
            }
            
            WText {
                Layout.fillWidth: true
                text: Translation.tr("These settings only apply when using the Windows 11 (Waffle) panel style. Go to Modules to enable it.")
                wrapMode: Text.WordWrap
                color: Looks.colors.subfg
            }
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive && root.isPanelEnabled("iiAltSwitcher")
        title: Translation.tr("Alt+Tab Switcher")
        icon: "apps"
        
        WSettingsDropdown {
            label: Translation.tr("Style")
            icon: "image"
            description: Translation.tr("Visual layout of the window switcher")
            currentValue: Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails"
            options: [
                { value: "thumbnails", displayName: Translation.tr("Thumbnails") },
                { value: "cards", displayName: Translation.tr("Cards") },
                { value: "compact", displayName: Translation.tr("Compact") },
                { value: "list", displayName: Translation.tr("List") },
                { value: "none", displayName: Translation.tr("Disabled") }
            ]
            onSelected: newValue => Config.setNestedValue("waffles.altSwitcher.preset", newValue)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Quick switch")
            icon: "flash-on"
            description: Translation.tr("Single Alt+Tab switches instantly without UI")
            checked: Config.options?.waffles?.altSwitcher?.quickSwitch ?? false
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.quickSwitch", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("No visual UI")
            icon: "eye-off"
            description: Translation.tr("Switch windows without showing overlay")
            checked: Config.options?.waffles?.altSwitcher?.noVisualUi ?? false
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.noVisualUi", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Most recent first")
            icon: "arrow-counterclockwise"
            description: Translation.tr("Order windows by most recently used")
            checked: Config.options?.waffles?.altSwitcher?.useMostRecentFirst ?? true
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.useMostRecentFirst", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Auto-hide")
            icon: "arrow-clockwise"
            description: Translation.tr("Hide after releasing Alt key")
            checked: Config.options?.waffles?.altSwitcher?.autoHide ?? true
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.autoHide", checked)
        }
        
        WSettingsSpinBox {
            visible: Config.options?.waffles?.altSwitcher?.autoHide ?? true
            label: Translation.tr("Auto-hide delay")
            icon: "arrow-clockwise"
            suffix: "ms"
            from: 100; to: 2000; stepSize: 100
            value: Config.options?.waffles?.altSwitcher?.autoHideDelayMs ?? 500
            onValueChanged: Config.setNestedValue("waffles.altSwitcher.autoHideDelayMs", value)
        }

        WSettingsSwitch {
            label: Translation.tr("Close on window focus")
            icon: "dismiss"
            checked: Config.options?.waffles?.altSwitcher?.closeOnFocus ?? true
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.closeOnFocus", checked)
        }

        WSettingsSpinBox {
            visible: (Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails") === "thumbnails"
            label: Translation.tr("Thumbnail width")
            icon: "image-copy"
            suffix: "px"
            from: 150; to: 500; stepSize: 20
            value: Config.options?.waffles?.altSwitcher?.thumbnailWidth ?? 280
            onValueChanged: Config.setNestedValue("waffles.altSwitcher.thumbnailWidth", value)
        }

        WSettingsSpinBox {
            visible: (Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails") === "thumbnails"
            label: Translation.tr("Thumbnail height")
            icon: "image-copy"
            suffix: "px"
            from: 100; to: 400; stepSize: 20
            value: Config.options?.waffles?.altSwitcher?.thumbnailHeight ?? 180
            onValueChanged: Config.setNestedValue("waffles.altSwitcher.thumbnailHeight", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Background dim")
            icon: "dark-theme"
            description: Translation.tr("Scrim opacity behind the switcher")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: Math.round((Config.options?.waffles?.altSwitcher?.scrimOpacity ?? 0.4) * 100)
            onValueChanged: Config.setNestedValue("waffles.altSwitcher.scrimOpacity", value / 100.0)
        }

        WSettingsSwitch {
            label: Translation.tr("Show Niri overview while switching")
            icon: "desktop"
            description: Translation.tr("Open compositor overview alongside the switcher")
            checked: Config.options?.waffles?.altSwitcher?.showOverviewWhileSwitching ?? false
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.showOverviewWhileSwitching", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive && root.isPanelEnabled("wTaskView")
        title: Translation.tr("Task View")
        icon: "task-view-dark"
        
        WSettingsDropdown {
            label: Translation.tr("View mode")
            icon: "task-view-dark"
            description: Translation.tr("Carousel shows desktops equally. Centered highlights the active one.")
            currentValue: Config.options?.waffles?.taskView?.mode ?? "centered"
            options: [
                { value: "carousel", displayName: Translation.tr("Carousel") },
                { value: "centered", displayName: Translation.tr("Centered focus") }
            ]
            onSelected: newValue => Config.setNestedValue("waffles.taskView.mode", newValue)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Close on window select")
            icon: "dismiss"
            description: Translation.tr("Exit Task View when clicking a window")
            checked: Config.options?.waffles?.taskView?.closeOnSelect ?? false
            onCheckedChanged: Config.setNestedValue("waffles.taskView.closeOnSelect", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Behavior")
        icon: "settings"
        
        WSettingsSwitch {
            label: Translation.tr("Allow multiple panels open")
            icon: "desktop"
            description: Translation.tr("Keep start menu open when opening action center")
            checked: Config.options?.waffles?.behavior?.allowMultiplePanels ?? false
            onCheckedChanged: Config.setNestedValue("waffles.behavior.allowMultiplePanels", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Smoother menu animations")
            icon: "wand"
            description: Translation.tr("Use smoother closing animations for popups")
            checked: Config.options?.waffles?.tweaks?.smootherMenuAnimations ?? true
            onCheckedChanged: Config.setNestedValue("waffles.tweaks.smootherMenuAnimations", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Switch handle position fix")
            icon: "settings"
            description: Translation.tr("Fix toggle switch handle alignment")
            checked: Config.options?.waffles?.tweaks?.switchHandlePositionFix ?? true
            onCheckedChanged: Config.setNestedValue("waffles.tweaks.switchHandlePositionFix", checked)
        }
    }

    WSettingsCard {
        visible: root.isWaffleActive && root.isPanelEnabled("wStartMenu")
        title: Translation.tr("Start Menu")
        icon: "start-here"

        WSettingsDropdown {
            label: Translation.tr("Size preset")
            icon: "desktop"
            description: Translation.tr("Choose the start menu size")
            currentValue: Config.options?.waffles?.startMenu?.sizePreset ?? "normal"
            options: [
                { value: "mini", displayName: Translation.tr("Mini") },
                { value: "compact", displayName: Translation.tr("Compact") },
                { value: "normal", displayName: Translation.tr("Normal") },
                { value: "large", displayName: Translation.tr("Large") },
                { value: "wide", displayName: Translation.tr("Wide") }
            ]
            onSelected: newValue => Config.setNestedValue("waffles.startMenu.sizePreset", newValue)
        }

        WSettingsSpinBox {
            label: Translation.tr("Text scale")
            icon: "auto"
            description: Translation.tr("Scale text in the start menu")
            suffix: "%"
            from: 80; to: 150; stepSize: 5
            value: Math.round((Config.options?.waffles?.startMenu?.scale ?? 1.0) * 100)
            onValueChanged: Config.setNestedValue("waffles.startMenu.scale", value / 100.0)
        }
    }

    WSettingsCard {
        title: Translation.tr("Family Transition")
        icon: "arrow-sync"

        WSettingsSwitch {
            label: Translation.tr("Animated transition")
            icon: "wand"
            description: Translation.tr("Smooth animated overlay when switching between panel families")
            checked: Config.options?.familyTransitionAnimation ?? true
            onCheckedChanged: Config.setNestedValue("familyTransitionAnimation", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive && root.isPanelEnabled("wWidgets")
        title: Translation.tr("Widgets Panel")
        icon: "apps"
        
        WSettingsSwitch {
            label: Translation.tr("Show date & time")
            icon: "pulse"
            description: Translation.tr("Display date and time widget")
            checked: Config.options?.waffles?.widgetsPanel?.showDateTime ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showDateTime", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show weather")
            icon: "weather-sunny"
            description: Translation.tr("Display weather conditions widget")
            checked: Config.options?.waffles?.widgetsPanel?.showWeather ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showWeather", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show system info")
            icon: "desktop"
            description: Translation.tr("Display CPU, RAM, and disk usage")
            checked: Config.options?.waffles?.widgetsPanel?.showSystem ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showSystem", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show media controls")
            icon: "music-note-2"
            description: Translation.tr("Display now playing and media controls")
            checked: Config.options?.waffles?.widgetsPanel?.showMedia ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showMedia", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show quick actions")
            icon: "flash-on"
            description: Translation.tr("Display quick action buttons")
            checked: Config.options?.waffles?.widgetsPanel?.showQuickActions ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showQuickActions", checked)
        }
    }
    
    // Weather configuration - shared with ii family
    WSettingsCard {
        title: Translation.tr("Weather")
        icon: "weather-sunny"
        
        WSettingsTextField {
            label: Translation.tr("City")
            icon: "globe-search"
            description: Translation.tr("Leave empty to auto-detect from IP")
            placeholderText: Translation.tr("e.g. Buenos Aires, London, Tokyo")
            text: Config.options?.bar?.weather?.city ?? ""
            onTextEdited: newText => Config.setNestedValue("bar.weather.city", newText)
        }
        
        WSettingsTextField {
            label: Translation.tr("Latitude")
            icon: "globe-search"
            description: Translation.tr("Manual latitude (overrides city). e.g. -34.6037")
            placeholderText: Translation.tr("e.g. -34.6037")
            text: {
                const v = Config.options?.bar?.weather?.manualLat ?? 0;
                return v !== 0 ? String(v) : "";
            }
            onTextEdited: newText => {
                const num = parseFloat(newText);
                Config.setNestedValue("bar.weather.manualLat", isNaN(num) ? 0 : num);
            }
        }
        
        WSettingsTextField {
            label: Translation.tr("Longitude")
            icon: "globe-search"
            description: Translation.tr("Manual longitude (overrides city). e.g. -58.3816")
            placeholderText: Translation.tr("e.g. -58.3816")
            text: {
                const v = Config.options?.bar?.weather?.manualLon ?? 0;
                return v !== 0 ? String(v) : "";
            }
            onTextEdited: newText => {
                const num = parseFloat(newText);
                Config.setNestedValue("bar.weather.manualLon", isNaN(num) ? 0 : num);
            }
        }
        
        WSettingsSwitch {
            label: Translation.tr("Use GPS location")
            icon: "globe-search"
            description: Translation.tr("Uses GPS when no manual location is set (requires geoclue)")
            checked: Config.options?.bar?.weather?.enableGPS ?? false
            onCheckedChanged: Config.setNestedValue("bar.weather.enableGPS", checked)
        }
        
        // Current detected location
        WSettingsRow {
            visible: Weather.location.valid
            label: Translation.tr("Detected location")
            icon: "globe-search"
            description: Weather.location.name || (Weather.location.lat + ", " + Weather.location.lon)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Use Fahrenheit")
            icon: "weather-sunny"
            description: Translation.tr("Display temperature in °F instead of °C")
            checked: Config.options?.bar?.weather?.useUSCS ?? false
            onCheckedChanged: Config.setNestedValue("bar.weather.useUSCS", checked)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Update interval")
            icon: "arrow-sync"
            description: Translation.tr("How often to refresh weather data")
            suffix: " min"
            from: 5; to: 60; stepSize: 5
            value: Config.options?.bar?.weather?.fetchInterval ?? 10
            onValueChanged: Config.setNestedValue("bar.weather.fetchInterval", value)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive && root.isPanelEnabled("wNotificationCenter")
        title: Translation.tr("Calendar")
        icon: "news"
        
        WSettingsSwitch {
            label: Translation.tr("Force 2-char day names")
            icon: "news"
            description: Translation.tr("Use Mo, Tu, We instead of Mon, Tue, Wed")
            checked: Config.options?.waffles?.calendar?.force2CharDayOfWeek ?? true
            onCheckedChanged: Config.setNestedValue("waffles.calendar.force2CharDayOfWeek", checked)
        }
    }
}
