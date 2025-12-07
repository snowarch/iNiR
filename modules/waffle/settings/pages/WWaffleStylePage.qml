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
        visible: root.isWaffleActive
        title: Translation.tr("Theming")
        icon: "dark-theme"
        
        WSettingsSwitch {
            label: Translation.tr("Use Material colors")
            icon: "dark-theme"
            description: Translation.tr("Apply Material color scheme instead of Windows 11 grey")
            checked: Config.options?.waffles?.theming?.useMaterialColors ?? false
            onCheckedChanged: Config.setNestedValue("waffles.theming.useMaterialColors", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Alt+Tab Switcher")
        icon: "apps"
        
        WSettingsDropdown {
            label: Translation.tr("Style")
            icon: "options"
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
            description: Translation.tr("Single Alt+Tab switches without showing UI")
            checked: Config.options?.waffles?.altSwitcher?.quickSwitch ?? false
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.quickSwitch", checked)
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
            icon: "options"
            description: Translation.tr("Hide switcher after delay when not interacting")
            checked: Config.options?.waffles?.altSwitcher?.autoHide ?? true
            onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.autoHide", checked)
        }
        
        WSettingsSpinBox {
            visible: Config.options?.waffles?.altSwitcher?.autoHide ?? true
            label: Translation.tr("Auto-hide delay")
            icon: "options"
            suffix: "ms"
            from: 100; to: 2000; stepSize: 100
            value: Config.options?.waffles?.altSwitcher?.autoHideDelayMs ?? 500
            onValueChanged: Config.setNestedValue("waffles.altSwitcher.autoHideDelayMs", value)
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
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Widgets Panel")
        icon: "apps"
        
        WSettingsSwitch {
            label: Translation.tr("Show date & time")
            icon: "options"
            checked: Config.options?.waffles?.widgetsPanel?.showDateTime ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showDateTime", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show weather")
            icon: "weather-sunny"
            checked: Config.options?.waffles?.widgetsPanel?.showWeather ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showWeather", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show system info")
            icon: "desktop"
            checked: Config.options?.waffles?.widgetsPanel?.showSystem ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showSystem", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show media controls")
            icon: "music-note-2"
            checked: Config.options?.waffles?.widgetsPanel?.showMedia ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showMedia", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show quick actions")
            icon: "flash-on"
            checked: Config.options?.waffles?.widgetsPanel?.showQuickActions ?? true
            onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.showQuickActions", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Calendar")
        icon: "calendar-ltr"
        
        WSettingsSwitch {
            label: Translation.tr("Force 2-char day names")
            icon: "options"
            description: Translation.tr("Use Mo, Tu, We instead of Mon, Tue, Wed")
            checked: Config.options?.waffles?.calendar?.force2CharDayOfWeek ?? true
            onCheckedChanged: Config.setNestedValue("waffles.calendar.force2CharDayOfWeek", checked)
        }
    }
}
