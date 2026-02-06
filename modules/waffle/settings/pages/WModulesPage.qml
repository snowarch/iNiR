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

        Config.options.enabledPanels = panels
    }

    WSettingsCard {
        title: Translation.tr("Panel Style")
        icon: "desktop"

        WSettingsDropdown {
            label: Translation.tr("Panel family")
            icon: "desktop"
            description: Translation.tr("Changing this will reload the shell")
            currentValue: Config.options?.panelFamily ?? "waffle"
            options: [
                { value: "ii", displayName: Translation.tr("Material (ii)") },
                { value: "waffle", displayName: Translation.tr("Windows 11 (Waffle)") }
            ]
            onSelected: newValue => {
                if (newValue !== Config.options?.panelFamily) {
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "panelFamily", "set", newValue])
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Default Terminal")
        icon: "window-terminal"

        WSettingsDropdown {
            label: Translation.tr("Terminal emulator")
            icon: "window-terminal"
            description: Translation.tr("Used by shell actions and update commands")
            currentValue: Config.options?.apps?.terminal ?? "kitty"
            options: [
                { value: "kitty", displayName: "Kitty" },
                { value: "foot", displayName: "Foot" },
                { value: "ghostty", displayName: "Ghostty" },
                { value: "alacritty", displayName: "Alacritty" },
                { value: "wezterm", displayName: "WezTerm" }
            ]
            onSelected: newValue => {
                Config.options.apps.terminal = newValue
                Config.options.apps.update = newValue + " -e sudo pacman -Syu"
            }
        }
    }

    // Waffle modules
    WSettingsCard {
        visible: root.isWaffleActive
        title: Translation.tr("Panels")
        icon: "desktop"

        WSettingsSwitch {
            label: Translation.tr("Taskbar")
            icon: "desktop"
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
            icon: "apps"
            checked: root.isPanelEnabled("wStartMenu")
            onCheckedChanged: root.setPanelEnabled("wStartMenu", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Action Center")
            icon: "settings"
            checked: root.isPanelEnabled("wActionCenter")
            onCheckedChanged: root.setPanelEnabled("wActionCenter", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Notification Center")
            icon: "alert"
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
            icon: "speaker-2"
            checked: root.isPanelEnabled("wOnScreenDisplay")
            onCheckedChanged: root.setPanelEnabled("wOnScreenDisplay", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Widgets Panel")
            icon: "apps"
            checked: root.isPanelEnabled("wWidgets")
            onCheckedChanged: root.setPanelEnabled("wWidgets", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Task View")
            icon: "desktop"
            description: Translation.tr("Overview of all workspaces and windows. Supports carousel and centered focus modes.")
            checked: root.isPanelEnabled("wTaskView")
            onCheckedChanged: root.setPanelEnabled("wTaskView", checked)
        }
    }
}
