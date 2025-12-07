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
    settingsPageIndex: 1
    pageTitle: Translation.tr("General")
    pageIcon: "settings"
    pageDescription: Translation.tr("System behavior and preferences")
    
    WSettingsCard {
        title: Translation.tr("Audio")
        icon: "speaker-2-filled"
        
        WSettingsSwitch {
            label: Translation.tr("Volume protection")
            icon: "speaker-mute"
            description: Translation.tr("Limit volume to prevent hearing damage")
            checked: Config.options?.audio?.protection?.enable ?? false
            onCheckedChanged: Config.setNestedValue("audio.protection.enable", checked)
        }
        
        WSettingsSpinBox {
            visible: Config.options?.audio?.protection?.enable ?? false
            label: Translation.tr("Maximum volume")
            icon: "speaker-1"
            suffix: "%"
            from: 50; to: 150; stepSize: 5
            value: Config.options?.audio?.protection?.maxAllowed ?? 99
            onValueChanged: Config.setNestedValue("audio.protection.maxAllowed", value)
        }
        
        WSettingsSpinBox {
            visible: Config.options?.audio?.protection?.enable ?? false
            label: Translation.tr("Max increase per step")
            icon: "speaker-1"
            description: Translation.tr("Maximum volume increase per key press")
            suffix: "%"
            from: 1; to: 20; stepSize: 1
            value: Config.options?.audio?.protection?.maxAllowedIncrease ?? 10
            onValueChanged: Config.setNestedValue("audio.protection.maxAllowedIncrease", value)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Battery")
        icon: "battery-full"
        
        WSettingsSpinBox {
            label: Translation.tr("Low battery warning")
            icon: "battery-warning"
            suffix: "%"
            from: 5; to: 50; stepSize: 5
            value: Config.options?.battery?.low ?? 20
            onValueChanged: Config.setNestedValue("battery.low", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Critical battery")
            icon: "battery-0"
            description: Translation.tr("Auto-suspend threshold")
            suffix: "%"
            from: 1; to: 20; stepSize: 1
            value: Config.options?.battery?.critical ?? 5
            onValueChanged: Config.setNestedValue("battery.critical", value)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Full battery notification")
            icon: "battery-charge"
            checked: Config.options?.battery?.notifyFull ?? true
            onCheckedChanged: Config.setNestedValue("battery.notifyFull", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Time & Language")
        icon: "globe-search"
        
        WSettingsSwitch {
            label: Translation.tr("Show seconds")
            icon: "options"
            description: Translation.tr("Display seconds in clock")
            checked: Config.options?.time?.secondPrecision ?? false
            onCheckedChanged: Config.setNestedValue("time.secondPrecision", checked)
        }
        
        WSettingsDropdown {
            label: Translation.tr("Language")
            icon: "globe-search"
            currentValue: Config.options?.language?.ui ?? "auto"
            options: [
                { value: "auto", displayName: Translation.tr("Auto") },
                { value: "en_US", displayName: "English" },
                { value: "es_AR", displayName: "Español" },
                { value: "pt_BR", displayName: "Português" },
                { value: "de_DE", displayName: "Deutsch" },
                { value: "fr_FR", displayName: "Français" },
                { value: "it_IT", displayName: "Italiano" },
                { value: "ru_RU", displayName: "Русский" },
                { value: "zh_CN", displayName: "简体中文" },
                { value: "ja_JP", displayName: "日本語" }
            ]
            onSelected: newValue => Config.setNestedValue("language.ui", newValue)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Window Management")
        icon: "desktop"
        
        WSettingsSwitch {
            label: Translation.tr("Confirm before closing")
            icon: "dismiss"
            description: Translation.tr("Show dialog when closing windows with Super+Q")
            checked: Config.options?.closeConfirm?.enabled ?? false
            onCheckedChanged: Config.setNestedValue("closeConfirm.enabled", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Sounds")
        icon: "speaker-2-filled"
        
        WSettingsSwitch {
            label: Translation.tr("Battery sounds")
            icon: "speaker-2-filled"
            checked: Config.options?.sounds?.battery ?? false
            onCheckedChanged: Config.setNestedValue("sounds.battery", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Notification sounds")
            icon: "alert-filled"
            checked: Config.options?.sounds?.notifications ?? false
            onCheckedChanged: Config.setNestedValue("sounds.notifications", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Idle & Sleep")
        icon: "weather-moon"
        
        WSettingsSpinBox {
            label: Translation.tr("Screen off timeout")
            icon: "desktop"
            description: Translation.tr("Turn off screen after inactivity (0 = never)")
            suffix: "s"
            from: 0; to: 1800; stepSize: 30
            value: Config.options?.idle?.screenOffTimeout ?? 300
            onValueChanged: Config.setNestedValue("idle.screenOffTimeout", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Lock timeout")
            icon: "lock-closed"
            description: Translation.tr("Lock screen after inactivity (0 = never)")
            suffix: "s"
            from: 0; to: 3600; stepSize: 60
            value: Config.options?.idle?.lockTimeout ?? 600
            onValueChanged: Config.setNestedValue("idle.lockTimeout", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Suspend timeout")
            icon: "weather-moon"
            description: Translation.tr("Suspend after inactivity (0 = never)")
            suffix: "s"
            from: 0; to: 7200; stepSize: 60
            value: Config.options?.idle?.suspendTimeout ?? 0
            onValueChanged: Config.setNestedValue("idle.suspendTimeout", value)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Lock before sleep")
            icon: "lock-closed"
            description: Translation.tr("Lock screen before suspending")
            checked: Config.options?.idle?.lockBeforeSleep ?? true
            onCheckedChanged: Config.setNestedValue("idle.lockBeforeSleep", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Game Mode")
        icon: "games"
        
        WSettingsSwitch {
            label: Translation.tr("Auto-detect fullscreen")
            icon: "games"
            description: Translation.tr("Enable game mode when apps go fullscreen")
            checked: Config.options?.gameMode?.autoDetect ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.autoDetect", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Disable animations")
            icon: "wand"
            description: Translation.tr("Turn off UI animations in game mode")
            checked: Config.options?.gameMode?.disableAnimations ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableAnimations", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Disable effects")
            icon: "options"
            description: Translation.tr("Turn off blur and shadows in game mode")
            checked: Config.options?.gameMode?.disableEffects ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableEffects", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Disable Niri animations")
            icon: "desktop"
            description: Translation.tr("Turn off compositor animations in game mode")
            checked: Config.options?.gameMode?.disableNiriAnimations ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableNiriAnimations", checked)
        }
    }
}
