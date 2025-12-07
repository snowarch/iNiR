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
    settingsPageIndex: 2
    pageTitle: Translation.tr("Taskbar")
    pageIcon: "desktop"
    pageDescription: Translation.tr("Taskbar appearance and behavior")
    
    property bool isWaffleActive: Config.options?.panelFamily === "waffle"
    
    // Warning when ii is active
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
        title: Translation.tr("Position & Layout")
        icon: "options"
        
        WSettingsSwitch {
            label: Translation.tr("Bottom position")
            icon: "options"
            description: Translation.tr("Place taskbar at bottom of screen")
            checked: Config.options?.waffles?.bar?.bottom ?? true
            onCheckedChanged: Config.setNestedValue("waffles.bar.bottom", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Left-align apps")
            icon: "options"
            description: Translation.tr("Align taskbar apps to the left instead of center")
            checked: Config.options?.waffles?.bar?.leftAlignApps ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.leftAlignApps", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Icons")
        icon: "apps"
        
        WSettingsSwitch {
            label: Translation.tr("Tint app icons")
            icon: "dark-theme"
            description: Translation.tr("Apply accent color to taskbar app icons")
            checked: Config.options?.waffles?.bar?.monochromeIcons ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.monochromeIcons", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Tint tray icons")
            icon: "dark-theme"
            description: Translation.tr("Apply accent color to system tray icons")
            checked: Config.options?.waffles?.bar?.tintTrayIcons ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.tintTrayIcons", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Desktop Peek")
        icon: "desktop"
        
        WSettingsSwitch {
            label: Translation.tr("Enable hover peek")
            icon: "desktop"
            description: Translation.tr("Show desktop when hovering the corner button")
            checked: Config.options?.waffles?.bar?.desktopPeek?.hoverPeek ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.desktopPeek.hoverPeek", checked)
        }
        
        WSettingsSpinBox {
            visible: Config.options?.waffles?.bar?.desktopPeek?.hoverPeek ?? false
            label: Translation.tr("Hover delay")
            icon: "options"
            suffix: "ms"
            from: 100; to: 2000; stepSize: 100
            value: Config.options?.waffles?.bar?.desktopPeek?.hoverDelay ?? 500
            onValueChanged: Config.setNestedValue("waffles.bar.desktopPeek.hoverDelay", value)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Clock & Notifications")
        icon: "options"
        
        WSettingsSwitch {
            label: Translation.tr("Show seconds")
            icon: "options"
            description: Translation.tr("Display seconds in taskbar clock")
            checked: Config.options?.time?.secondPrecision ?? false
            onCheckedChanged: Config.setNestedValue("time.secondPrecision", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show unread count")
            icon: "alert"
            description: Translation.tr("Display notification count badge on clock")
            checked: Config.options?.waffles?.bar?.notifications?.showUnreadCount ?? true
            onCheckedChanged: Config.setNestedValue("waffles.bar.notifications.showUnreadCount", checked)
        }
    }
    
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Updates")
        icon: "arrow-sync"
        
        WSettingsSpinBox {
            label: Translation.tr("Check interval")
            icon: "options"
            suffix: "m"
            from: 15; to: 1440; stepSize: 15
            value: Config.options?.updates?.checkInterval ?? 120
            onValueChanged: Config.setNestedValue("updates.checkInterval", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Show icon threshold")
            icon: "alert"
            description: Translation.tr("Show update icon when packages exceed this")
            from: 1; to: 200; stepSize: 5
            value: Config.options?.updates?.adviseUpdateThreshold ?? 10
            onValueChanged: Config.setNestedValue("updates.adviseUpdateThreshold", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Warning threshold")
            icon: "warning"
            description: Translation.tr("Show warning color when packages exceed this")
            from: 10; to: 500; stepSize: 10
            value: Config.options?.updates?.stronglyAdviseUpdateThreshold ?? 50
            onValueChanged: Config.setNestedValue("updates.stronglyAdviseUpdateThreshold", value)
        }
    }
}
