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
    pageTitle: Translation.tr("Modules")
    pageIcon: "settings-cog-multiple"
    pageDescription: Translation.tr("Panel style and modules")

    property bool isWaffleActive: Config.options?.panelFamily === "waffle"

    // Helper functions for enabledPanels management
    function isPanelEnabled(panelId: string): bool {
        return (Config.options?.enabledPanels ?? []).includes(panelId)
    }

    function setPanelEnabled(panelId: string, enabled: bool): void {
        let panels = [...(Config.options?.enabledPanels ?? [])]
        const idx = panels.indexOf(panelId)

        if (enabled && idx === -1) {
            panels.push(panelId)
        } else if (!enabled && idx !== -1) {
            panels.splice(idx, 1)
        }

        Config.setNestedValue("enabledPanels", panels)
    }

    // Helper functions for Action Center toggles management
    function isToggleEnabled(toggleId: string): bool {
        return (Config.options?.waffles?.actionCenter?.toggles ?? []).includes(toggleId)
    }

    function setToggleEnabled(toggleId: string, enabled: bool): void {
        let toggles = [...(Config.options?.waffles?.actionCenter?.toggles ?? [])]
        const idx = toggles.indexOf(toggleId)

        if (enabled && idx === -1) {
            toggles.push(toggleId)
        } else if (!enabled && idx !== -1) {
            toggles.splice(idx, 1)
        }

        Config.setNestedValue("waffles.actionCenter.toggles", toggles)
    }

    readonly property var allToggles: [
        { id: "network",          label: Translation.tr("Network / Wi-Fi"),   icon: "wifi-4"         },
        { id: "bluetooth",        label: Translation.tr("Bluetooth"),          icon: "bluetooth"      },
        { id: "hotspot",          label: Translation.tr("Hotspot"),            icon: "wifi-tethering" },
        { id: "audio",            label: Translation.tr("Audio output"),       icon: "speaker"        },
        { id: "mic",              label: Translation.tr("Microphone"),         icon: "mic"            },
        { id: "easyEffects",      label: Translation.tr("EasyEffects"),        icon: "device-eq"      },
        { id: "nightLight",       label: Translation.tr("Night Light"),        icon: "weather-moon"   },
        { id: "darkMode",         label: Translation.tr("Dark Mode"),          icon: "dark-theme"     },
        { id: "antiFlashbang",    label: Translation.tr("Anti-Flashbang"),     icon: "flash-off"      },
        { id: "powerProfile",     label: Translation.tr("Power Profile"),      icon: "flash-on"       },
        { id: "idleInhibitor",    label: Translation.tr("Idle Inhibitor"),     icon: "drink-coffee"   },
        { id: "notifications",    label: Translation.tr("Notifications"),      icon: "alert"          },
        { id: "onScreenKeyboard", label: Translation.tr("On-Screen Keyboard"), icon: "keyboard"       },
        { id: "cloudflareWarp",   label: Translation.tr("Cloudflare WARP"),   icon: "cloudflare"     },
        { id: "gameMode",         label: Translation.tr("Game Mode"),          icon: "games"          },
        { id: "musicRecognition", label: Translation.tr("Music Recognition"),  icon: "music-note-2"   },
        { id: "screenSnip",       label: Translation.tr("Screen Snip"),        icon: "cut"            },
        { id: "colorPicker",      label: Translation.tr("Color Picker"),       icon: "eyedropper"     }
    ]

    WSettingsInfoBar {
        visible: !root.isWaffleActive
        severity: WSettingsInfoBar.Severity.Info
        message: Translation.tr("These Waffle modules are currently inactive because another panel family is selected. You can still pre-configure them here before switching.")
    }

    WSettingsCard {
        title: Translation.tr("Panel Style")
        icon: "options"

        WSettingsDropdown {
            label: Translation.tr("Panel family")
            icon: "panel-left-expand"
            description: Translation.tr("Changing this will reload the shell")
            currentValue: Config.options?.panelFamily ?? "waffle"
            options: [
                { value: "ii", displayName: Translation.tr("Material (ii)") },
                { value: "waffle", displayName: Translation.tr("Windows 11 (Waffle)") }
            ]
            onSelected: newValue => {
                if (newValue !== Config.options?.panelFamily) {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "panelFamily", "set", newValue])
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Default Terminal")
        icon: "terminal"

        WSettingsDropdown {
            label: Translation.tr("Terminal emulator")
            icon: "terminal"
            description: Translation.tr("Used by shell actions, keybinds, and package commands")
            currentValue: AppLauncher.presetIdFor("terminal")
            options: AppLauncher.presetOptions("terminal")
            onSelected: newValue => {
                if (newValue !== "__custom__")
                    AppLauncher.applyPreset("terminal", newValue)
            }
        }
    }

    // Waffle modules
    WSettingsCard {
        title: Translation.tr("Panels")
        icon: "apps"

        WSettingsRow {
            visible: !root.isWaffleActive
            label: Translation.tr("Waffle family currently inactive")
            icon: "info"
            description: Translation.tr("Changes here will apply when you switch the panel family back to Windows 11 (Waffle).")
        }

        WSettingsSwitch {
            label: Translation.tr("Taskbar")
            icon: "panel-left-expand"
            checked: root.isPanelEnabled("wBar")
            onCheckedChanged: root.setPanelEnabled("wBar", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Background")
            icon: "image"
            checked: root.isPanelEnabled("wBackground")
            onCheckedChanged: root.setPanelEnabled("wBackground", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Start Menu")
            icon: "start-here"
            checked: root.isPanelEnabled("wStartMenu")
            onCheckedChanged: root.setPanelEnabled("wStartMenu", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Action Center")
            icon: "options"
            checked: root.isPanelEnabled("wActionCenter")
            onCheckedChanged: root.setPanelEnabled("wActionCenter", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Notification Center")
            icon: "alert-filled"
            checked: root.isPanelEnabled("wNotificationCenter")
            onCheckedChanged: root.setPanelEnabled("wNotificationCenter", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Notification Popups")
            icon: "alert"
            checked: root.isPanelEnabled("wNotificationPopup")
            onCheckedChanged: root.setPanelEnabled("wNotificationPopup", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("OSD")
            icon: "pulse"
            checked: root.isPanelEnabled("wOnScreenDisplay")
            onCheckedChanged: root.setPanelEnabled("wOnScreenDisplay", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Widgets Panel")
            icon: "widgets"
            checked: root.isPanelEnabled("wWidgets")
            onCheckedChanged: root.setPanelEnabled("wWidgets", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Task View")
            icon: "library"
            description: Translation.tr("Overview of all workspaces and windows. Supports carousel and centered focus modes.")
            checked: root.isPanelEnabled("wTaskView")
            onCheckedChanged: root.setPanelEnabled("wTaskView", checked)
        }
    }

    WSettingsSection {
        title: Translation.tr("Action Center Toggles")
        icon: "options"
    }

    WSettingsCard {
        title: Translation.tr("Visible toggles")
        icon: "checkmark"

        Repeater {
            model: root.allToggles
            delegate: WSettingsSwitch {
                required property var modelData
                label: modelData.label
                icon: modelData.icon
                checked: root.isToggleEnabled(modelData.id)
                onCheckedChanged: root.setToggleEnabled(modelData.id, checked)
            }
        }
    }
}
