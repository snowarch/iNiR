pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

// Waffle-side settings for the shared Workspace Strip module (the strip itself
// loads in both families; this mirrors modules/settings/WorkspaceStripConfig.qml).
WSettingsPage {
    id: root
    settingsPageIndex: 13
    pageTitle: Translation.tr("Workspace Strip")
    pageIcon: "desktop"
    pageDescription: Translation.tr("Edge-hover workspace navigator")

    function isPanelEnabled(): bool {
        return (Config.options?.enabledPanels ?? []).includes("iiWorkspaceStrip")
    }

    function setPanelEnabled(enabled: bool): void {
        const panels = [...(Config.options?.enabledPanels ?? [])]
        const index = panels.indexOf("iiWorkspaceStrip")
        if (enabled && index === -1)
            panels.push("iiWorkspaceStrip")
        else if (!enabled && index !== -1)
            panels.splice(index, 1)
        Config.setNestedValue("enabledPanels", panels)
    }

    WSettingsInfoBar {
        severity: WSettingsInfoBar.Severity.Info
        message: Translation.tr("Optional edge navigator, disabled on fresh installs. Hover the configured edge to open it, hover a workspace to inspect it, click cards or windows to focus them, drag windows between cards, and hold × to close. Window snapshots are available on Niri.")
    }

    WSettingsCard {
        title: Translation.tr("Edge behavior")
        icon: "desktop"

        WSettingsSwitch {
            label: Translation.tr("Enable workspace strip")
            icon: "desktop"
            description: Translation.tr("Keeps a compact workspace strip visible on the configured edge")
            checked: root.isPanelEnabled()
            onCheckedChanged: root.setPanelEnabled(checked)
        }

        WSettingsRow {
            label: Translation.tr("Edge")
            icon: "border-outside"

            control: Component {
                WSettingsChoiceGroup {
                    columns: 2
                    currentValue: Config.options?.workspaceStrip?.side ?? "right"
                    onSelected: newValue => Config.setNestedValue("workspaceStrip.side", newValue)
                    options: [
                        { value: "left", label: Translation.tr("Left") },
                        { value: "right", label: Translation.tr("Right") }
                    ]
                }
            }
        }

        WSettingsRow {
            label: Translation.tr("Look")
            icon: "image"

            control: Component {
                WSettingsChoiceGroup {
                    columns: 3
                    currentValue: Config.options?.workspaceStrip?.style ?? "auto"
                    onSelected: newValue => Config.setNestedValue("workspaceStrip.style", newValue)
                    options: [
                        { value: "auto", label: Translation.tr("Follow bar") },
                        { value: "island", label: Translation.tr("Island") },
                        { value: "stock", label: Translation.tr("Stock") }
                    ]
                }
            }
        }

        WSettingsSpinBox {
            label: Translation.tr("Panel width")
            icon: "desktop"
            suffix: "px"
            from: 360; to: 760; stepSize: 4
            value: Config.options?.workspaceStrip?.panelWidth ?? 480
            onValueChanged: Config.setNestedValue("workspaceStrip.panelWidth", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Preview size")
            icon: "image"
            suffix: "px"
            from: 96; to: 260; stepSize: 4
            value: Config.options?.workspaceStrip?.previewSize ?? 150
            onValueChanged: Config.setNestedValue("workspaceStrip.previewSize", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Trigger width")
            icon: "panel-left-expand"
            suffix: "px"
            from: 1; to: 16; stepSize: 1
            value: Config.options?.workspaceStrip?.triggerWidth ?? 6
            onValueChanged: Config.setNestedValue("workspaceStrip.triggerWidth", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Open delay")
            icon: "timer"
            suffix: "ms"
            from: 1; to: 500; stepSize: 10
            value: Config.options?.workspaceStrip?.openDelay ?? 110
            onValueChanged: Config.setNestedValue("workspaceStrip.openDelay", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Close delay")
            icon: "timer"
            suffix: "ms"
            from: 100; to: 1200; stepSize: 20
            value: Config.options?.workspaceStrip?.closeDelay ?? 320
            onValueChanged: Config.setNestedValue("workspaceStrip.closeDelay", value)
        }
    }

    WSettingsCard {
        title: Translation.tr("Navigation")
        icon: "arrow-sync"

        WSettingsSwitch {
            label: Translation.tr("Scroll to navigate")
            icon: "arrow-sync"
            description: Translation.tr("Use the mouse wheel over the strip to move between workspaces instead of scrolling the thumbnail list")
            checked: Config.options?.workspaceStrip?.scrollNavigation ?? false
            onCheckedChanged: Config.setNestedValue("workspaceStrip.scrollNavigation", checked)
        }

        WSettingsSwitch {
            visible: Config.options?.workspaceStrip?.scrollNavigation ?? false
            label: Translation.tr("Switch workspace on scroll")
            icon: "desktop"
            description: Translation.tr("Also focus the workspace in the compositor when scrolling through the strip")
            checked: Config.options?.workspaceStrip?.scrollNavigationSwitchWorkspace ?? true
            onCheckedChanged: Config.setNestedValue("workspaceStrip.scrollNavigationSwitchWorkspace", checked)
        }

        WSettingsSpinBox {
            visible: Config.options?.workspaceStrip?.scrollNavigation ?? false
            label: Translation.tr("Scroll debounce")
            icon: "timer"
            suffix: "ms"
            from: 50; to: 800; stepSize: 10
            value: Config.options?.workspaceStrip?.scrollNavigationDebounceMs ?? 180
            onValueChanged: Config.setNestedValue("workspaceStrip.scrollNavigationDebounceMs", value)
        }
    }

    WSettingsCard {
        title: Translation.tr("Workspace cards")
        icon: "apps"

        WSettingsSwitch {
            label: Translation.tr("Window previews")
            icon: "image"
            description: Translation.tr("Live preview for the active workspace and refreshed snapshots for hidden workspaces")
            checked: Config.options?.workspaceStrip?.showPreviews ?? true
            onCheckedChanged: Config.setNestedValue("workspaceStrip.showPreviews", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Window metadata")
            icon: "info"
            description: Translation.tr("Show workspace name, focused window title and window count")
            checked: Config.options?.workspaceStrip?.showMetadata ?? true
            onCheckedChanged: Config.setNestedValue("workspaceStrip.showMetadata", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("App icons")
            icon: "apps"
            description: Translation.tr("Show icons for open applications on the selected workspace card")
            checked: Config.options?.workspaceStrip?.showAppIcons ?? true
            onCheckedChanged: Config.setNestedValue("workspaceStrip.showAppIcons", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Now-playing player")
            icon: "settings"
            description: Translation.tr("Add a media card at the top of the strip with playback controls when music is playing")
            checked: Config.options?.workspaceStrip?.showMediaPlayer ?? true
            onCheckedChanged: Config.setNestedValue("workspaceStrip.showMediaPlayer", checked)
        }

        WSettingsSwitch {
            enabled: CompositorService.isNiri
            label: Translation.tr("Per-monitor workspaces")
            icon: "desktop"
            description: CompositorService.isNiri
                ? Translation.tr("Each screen shows only its own Niri workspaces")
                : Translation.tr("Only available on Niri")
            checked: Config.options?.workspaceStrip?.perMonitor ?? true
            onCheckedChanged: Config.setNestedValue("workspaceStrip.perMonitor", checked)
        }
    }
}
