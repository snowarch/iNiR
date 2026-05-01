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

        WSettingsSwitch {
            label: Translation.tr("Charge limit")
            icon: "battery-saver"
            description: !Battery.chargeLimitSupported
                ? Translation.tr("Not supported on this device")
                : Battery.chargeLimitAdjustable
                    ? Translation.tr("Limit maximum charge to preserve battery health")
                    : Translation.tr("Use your device's built-in battery conservation mode (requires polkit)")
            enabled: Battery.chargeLimitSupported
            checked: Config.options?.battery?.chargeLimit?.enable ?? false
            onCheckedChanged: Config.setNestedValue("battery.chargeLimit.enable", checked)
        }

        WSettingsSpinBox {
            visible: Battery.chargeLimitAdjustable
            enabled: Config.options?.battery?.chargeLimit?.enable ?? false
            label: Translation.tr("Charge limit threshold")
            icon: "battery-saver"
            suffix: "%"
            from: 20; to: 100; stepSize: 5
            value: Config.options?.battery?.chargeLimit?.threshold ?? 80
            onValueChanged: Config.setNestedValue("battery.chargeLimit.threshold", value)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Time & Language")
        icon: "globe-search"
        
        WSettingsSwitch {
            label: Translation.tr("Show seconds")
            icon: "timer"
            description: Translation.tr("Display seconds in clock")
            checked: Config.options?.time?.secondPrecision ?? false
            onCheckedChanged: Config.setNestedValue("time.secondPrecision", checked)
        }

        WSettingsTextField {
            label: Translation.tr("Long date format")
            icon: "calendar"
            description: Translation.tr("Used by clocks and full date labels. Example: dddd, MMMM dd")
            placeholderText: Translation.tr("e.g. dddd, MMMM dd")
            text: Config.options?.time?.dateFormat ?? "ddd, dd/MM"
            onTextEdited: newText => Config.setNestedValue("time.dateFormat", newText)
        }

        WSettingsTextField {
            label: Translation.tr("Short date format")
            icon: "calendar-month"
            description: Translation.tr("Used by compact date surfaces. Example: dd/MM")
            placeholderText: Translation.tr("e.g. dd/MM")
            text: Config.options?.time?.shortDateFormat ?? "dd/MM"
            onTextEdited: newText => Config.setNestedValue("time.shortDateFormat", newText)
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
        title: Translation.tr("Keyboard indicators")
        icon: "keyboard"

        WSettingsSwitch {
            label: Translation.tr("Keyboard popups")
            icon: "keyboard"
            description: Translation.tr("Show a popup when Caps Lock, Num Lock, or the keyboard layout changes")
            checked: Config.options?.keyboardIndicators?.showPopup ?? true
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.showPopup", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Layout popup")
            icon: "globe"
            description: Translation.tr("Show a popup when the keyboard layout changes")
            checked: Config.options?.keyboardIndicators?.popup?.layout ?? true
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.popup.layout", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Caps Lock popup")
            icon: "key"
            description: Translation.tr("Show a popup when Caps Lock changes")
            checked: Config.options?.keyboardIndicators?.popup?.caps ?? true
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.popup.caps", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Num Lock popup")
            icon: "keyboard-dock"
            description: Translation.tr("Show a popup when Num Lock changes")
            checked: Config.options?.keyboardIndicators?.popup?.num ?? false
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.popup.num", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Keyboard panel indicators")
            icon: "keyboard-dock"
            description: Translation.tr("Show layout and lock state indicators in the bar or taskbar")
            checked: Config.options?.keyboardIndicators?.showPanel ?? true
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.showPanel", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Layout indicator")
            icon: "globe"
            description: Translation.tr("Show the current keyboard layout in the taskbar")
            checked: Config.options?.keyboardIndicators?.panel?.layout ?? true
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.panel.layout", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Caps Lock indicator")
            icon: "key"
            description: Translation.tr("Show Caps Lock in the taskbar")
            checked: Config.options?.keyboardIndicators?.panel?.caps ?? true
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.panel.caps", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Num Lock indicator")
            icon: "keyboard-dock"
            description: Translation.tr("Show Num Lock in the taskbar")
            checked: Config.options?.keyboardIndicators?.panel?.num ?? false
            onCheckedChanged: Config.setNestedValue("keyboardIndicators.panel.num", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Windows & Sounds")
        icon: "app-generic"
        
        WSettingsSwitch {
            label: Translation.tr("Confirm before closing")
            icon: "shield"
            description: Translation.tr("Show dialog when closing windows with Super+Q")
            checked: Config.options?.closeConfirm?.enabled ?? false
            onCheckedChanged: Config.setNestedValue("closeConfirm.enabled", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Battery sounds")
            icon: "speaker"
            checked: Config.options?.sounds?.battery ?? false
            onCheckedChanged: Config.setNestedValue("sounds.battery", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Notification sounds")
            icon: "music-note-2"
            checked: Config.options?.sounds?.notifications ?? true
            onCheckedChanged: Config.setNestedValue("sounds.notifications", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Idle & Sleep")
        icon: "weather-moon"
        
        WSettingsSpinBox {
            label: Translation.tr("Screen off timeout")
            icon: "flash-off"
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
            icon: "eye"
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
            icon: "eye-off"
            description: Translation.tr("Turn off blur and shadows in game mode")
            checked: Config.options?.gameMode?.disableEffects ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableEffects", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Disable Niri animations")
            icon: "pulse"
            description: Translation.tr("Turn off compositor animations in game mode")
            checked: Config.options?.gameMode?.disableNiriAnimations ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableNiriAnimations", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Disable Discover overlay")
            icon: "headphones"
            description: Translation.tr("Stop discover-overlay while game mode is active")
            checked: Config.options?.gameMode?.disableDiscoverOverlay ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableDiscoverOverlay", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Minimal mode")
            icon: "leaf-two"
            description: Translation.tr("Make shell surfaces lighter while game mode is active")
            checked: Config.options?.gameMode?.minimalMode ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.minimalMode", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Suppress notifications")
            icon: "alert-off"
            description: Translation.tr("Hide notification popups while game mode is active")
            checked: Config.options?.gameMode?.suppressNotifications ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.suppressNotifications", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Hide reload toasts")
            icon: "alert-snooze"
            description: Translation.tr("Suppress reload notifications when Game Mode is active")
            checked: Config.options?.gameMode?.disableReloadToasts ?? true
            onCheckedChanged: Config.setNestedValue("gameMode.disableReloadToasts", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Hotspot")
        icon: "wifi-tethering"

        WSettingsTextField {
            label: Translation.tr("Network name (SSID)")
            icon: "wifi-tethering"
            description: Translation.tr("The name your hotspot will broadcast")
            text: Config.options?.hotspot?.ssid ?? "iNiR Hotspot"
            onTextEdited: (newText) => Config.setNestedValue("hotspot.ssid", newText)
        }

        WSettingsTextField {
            label: Translation.tr("Password")
            icon: "key"
            description: Translation.tr("WPA2 passphrase for the hotspot")
            text: Config.options?.hotspot?.password ?? "inirhotspot"
            onTextEdited: (newText) => Config.setNestedValue("hotspot.password", newText)
        }

        WSettingsSwitch {
            label: Translation.tr("Use 5 GHz band")
            icon: "pulse"
            description: Translation.tr("Use 5 GHz (802.11a) instead of 2.4 GHz. Requires adapter support.")
            checked: (Config.options?.hotspot?.band ?? "bg") === "a"
            onCheckedChanged: Config.setNestedValue("hotspot.band", checked ? "a" : "bg")
        }
    }

    WSettingsCard {
        title: Translation.tr("Calendar")
        icon: "schedule"

        WSettingsSwitch {
            label: Translation.tr("External calendar sync")
            icon: "arrow-sync"
            description: Translation.tr("Sync events from external ICS/iCal URLs (Google Calendar, Outlook, etc.)")
            checked: Config.options?.calendar?.externalSync?.enable ?? false
            onCheckedChanged: Config.setNestedValue("calendar.externalSync.enable", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Refresh interval")
            icon: "arrow-clockwise"
            description: Translation.tr("Minutes between calendar fetches")
            value: Config.options?.calendar?.externalSync?.refreshMinutes ?? 15
            from: 5
            to: 120
            stepSize: 5
            onValueChanged: Config.setNestedValue("calendar.externalSync.refreshMinutes", value)
            enabled: Config.options?.calendar?.externalSync?.enable ?? false
        }

        WSettingsSwitch {
            label: Translation.tr("Show upcoming events")
            icon: "list"
            description: Translation.tr("Display upcoming events below the calendar")
            checked: Config.options?.calendar?.showUpcoming ?? true
            onCheckedChanged: Config.setNestedValue("calendar.showUpcoming", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Upcoming days")
            icon: "timer"
            description: Translation.tr("How many days ahead to show")
            value: Config.options?.calendar?.upcomingDays ?? 3
            from: 1
            to: 14
            stepSize: 1
            onValueChanged: Config.setNestedValue("calendar.upcomingDays", value)
        }
    }
}
