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
    settingsPageIndex: 6
    pageTitle: Translation.tr("Modules")
    pageIcon: "settings-cog-multiple"
    pageDescription: Translation.tr("Panel style and optional modules")
    
    property bool isWaffleActive: Config.options?.panelFamily === "waffle"
    
    WSettingsCard {
        title: Translation.tr("Panel Style")
        icon: "desktop"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("Choose between Material Design (ii) and Windows 11 (Waffle) styles. Changing this will reload the shell.")
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }
        
        WSettingsDropdown {
            label: Translation.tr("Panel family")
            icon: "desktop"
            currentValue: Config.options?.panelFamily ?? "waffle"
            options: [
                { value: "ii", displayName: Translation.tr("Material (ii)") },
                { value: "waffle", displayName: Translation.tr("Windows 11 (Waffle)") }
            ]
            onSelected: newValue => {
                if (newValue !== Config.options?.panelFamily) {
                    Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "panelFamily", "set", newValue])
                }
            }
        }
    }
    
    // Material modules available in Waffle
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Material Modules in Waffle")
        icon: "options"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("Enable Material ii modules while using Waffle style. These provide additional functionality not available in Windows 11 style.")
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }
        
        WSettingsSwitch {
            label: Translation.tr("Left Sidebar")
            icon: "panel-left"
            description: Translation.tr("AI chat, wallpaper selector, translator")
            checked: Config.options?.waffles?.modules?.sidebarLeft ?? false
            onCheckedChanged: Config.setNestedValue("waffles.modules.sidebarLeft", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Right Sidebar")
            icon: "panel-right"
            description: Translation.tr("Quick settings, calendar, notifications (Material style)")
            checked: Config.options?.waffles?.modules?.sidebarRight ?? false
            onCheckedChanged: Config.setNestedValue("waffles.modules.sidebarRight", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Dock")
            icon: "apps"
            description: Translation.tr("macOS-style dock with pinned apps")
            checked: Config.options?.waffles?.modules?.dock ?? false
            onCheckedChanged: Config.setNestedValue("waffles.modules.dock", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Media Controls Overlay")
            icon: "music-note-2"
            description: Translation.tr("Floating media player controls")
            checked: Config.options?.waffles?.modules?.mediaControls ?? false
            onCheckedChanged: Config.setNestedValue("waffles.modules.mediaControls", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Screen Corners")
            icon: "desktop"
            description: Translation.tr("Hot corners and rounded screen corners")
            checked: Config.options?.waffles?.modules?.screenCorners ?? false
            onCheckedChanged: Config.setNestedValue("waffles.modules.screenCorners", checked)
        }
    }
    
    // Waffle-specific modules
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Waffle Modules")
        icon: "desktop"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("These modules are part of the Windows 11 style and are enabled by default.")
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }
        
        WSettingsRow {
            label: Translation.tr("Taskbar")
            icon: "desktop"
            description: Translation.tr("Windows 11 style taskbar")
            
            WText {
                text: Translation.tr("Always enabled")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
            }
        }
        
        WSettingsRow {
            label: Translation.tr("Start Menu")
            icon: "apps"
            description: Translation.tr("Windows 11 style start menu")
            
            WText {
                text: Translation.tr("Always enabled")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
            }
        }
        
        WSettingsRow {
            label: Translation.tr("Action Center")
            icon: "settings"
            description: Translation.tr("Quick settings and toggles")
            
            WText {
                text: Translation.tr("Always enabled")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
            }
        }
        
        WSettingsRow {
            label: Translation.tr("Notification Center")
            icon: "alert"
            description: Translation.tr("Notification history and calendar")
            
            WText {
                text: Translation.tr("Always enabled")
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
            }
        }
        
        WSettingsSwitch {
            label: Translation.tr("Widgets Panel")
            icon: "apps"
            description: Translation.tr("Weather, system info, media controls")
            checked: Config.options?.waffles?.modules?.widgets ?? true
            onCheckedChanged: Config.setNestedValue("waffles.modules.widgets", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Desktop Backdrop")
            icon: "image"
            description: Translation.tr("Blurred backdrop for overview")
            checked: Config.options?.waffles?.background?.backdrop?.enable ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enable", checked)
        }
    }
    
    // Shared modules info
    WSettingsCard {
        title: Translation.tr("Shared Modules")
        icon: "link"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("These modules work with both panel styles and are always available:")
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }
        
        WText {
            Layout.fillWidth: true
            text: "• " + Translation.tr("Overview (Super key)") + "\n" +
                  "• " + Translation.tr("Clipboard Manager") + "\n" +
                  "• " + Translation.tr("Lock Screen") + "\n" +
                  "• " + Translation.tr("Session Screen (logout/shutdown)") + "\n" +
                  "• " + Translation.tr("On-Screen Display (volume/brightness)") + "\n" +
                  "• " + Translation.tr("Cheatsheet (keybindings)") + "\n" +
                  "• " + Translation.tr("Wallpaper Selector")
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.fg
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }
    }
}
