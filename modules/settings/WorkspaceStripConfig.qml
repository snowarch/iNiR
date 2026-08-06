import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 18
    settingsPageName: Translation.tr("Workspace Strip")

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

    SettingsCardSection {
        expanded: true
        icon: "view_sidebar"
        title: Translation.tr("Edge behavior")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Optional edge navigator, disabled on fresh installs. Move the pointer to the configured edge, hover a workspace to inspect it, click its card to switch, click a window to focus it, drag it to another card to move it, and hold × to close.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: CompositorService.isNiri
                    ? Translation.tr("Window snapshots refresh when the strip opens.")
                    : Translation.tr("Window snapshots are available on Niri; workspace navigation and app icons remain available here.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                wrapMode: Text.WordWrap
                opacity: 0.78
            }

            SettingsSwitch {
                buttonIcon: "dock_to_right"
                text: Translation.tr("Enable workspace strip")
                checked: root.isPanelEnabled()
                onCheckedChanged: root.setPanelEnabled(checked)
                StyledToolTip {
                    text: Translation.tr("Keeps a compact workspace strip visible on the configured edge")
                }
            }

            ContentSubsection {
                title: Translation.tr("Edge")

                ConfigSelectionArray {
                    currentValue: Config.options?.workspaceStrip?.side ?? "right"
                    onSelected: value => Config.setNestedValue("workspaceStrip.side", value)
                    options: [
                        { displayName: Translation.tr("Left"), icon: "dock_to_left", value: "left" },
                        { displayName: Translation.tr("Right"), icon: "dock_to_right", value: "right" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Look")

                ConfigSelectionArray {
                    currentValue: Config.options?.workspaceStrip?.style ?? "auto"
                    onSelected: value => Config.setNestedValue("workspaceStrip.style", value)
                    options: [
                        { displayName: Translation.tr("Follow bar"), icon: "link", value: "auto" },
                        { displayName: Translation.tr("Island"), icon: "landscape", value: "island" },
                        { displayName: Translation.tr("Stock"), icon: "layers", value: "stock" }
                    ]
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Island applies the Ricelin card look; Follow bar uses it only while the pill bar is active")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            ContentSubsection {
                title: Translation.tr("Size")

                // One spinbox per row: stacked three-up they collide because each
                // ConfigSpinBox already carries its own label + control.
                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "width"
                    text: Translation.tr("Panel width")
                    value: Config.options?.workspaceStrip?.panelWidth ?? 480
                    from: 360
                    to: 760
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("workspaceStrip.panelWidth", value)
                    StyledToolTip {
                        text: Translation.tr("Total width of the strip, including the side flyout")
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "photo_size_select_large"
                    text: Translation.tr("Preview size")
                    value: Config.options?.workspaceStrip?.previewSize ?? 150
                    from: 96
                    to: 260
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("workspaceStrip.previewSize", value)
                    StyledToolTip {
                        text: Translation.tr("Width of the workspace thumbnails in pixels")
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "swipe"
                    text: Translation.tr("Trigger width")
                    value: Config.options?.workspaceStrip?.triggerWidth ?? 6
                    from: 1
                    to: 16
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("workspaceStrip.triggerWidth", value)
                    StyledToolTip {
                        text: Translation.tr("Invisible edge area that opens the strip")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Hover timing")

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "timer"
                    text: Translation.tr("Open delay")
                    value: Config.options?.workspaceStrip?.openDelay ?? 110
                    from: 1
                    to: 500
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("workspaceStrip.openDelay", value)
                    StyledToolTip { text: Translation.tr("Milliseconds before edge hover opens the strip") }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "timer_off"
                    text: Translation.tr("Close delay")
                    value: Config.options?.workspaceStrip?.closeDelay ?? 320
                    from: 100
                    to: 1200
                    stepSize: 20
                    onValueChanged: Config.setNestedValue("workspaceStrip.closeDelay", value)
                    StyledToolTip { text: Translation.tr("Milliseconds before the strip closes after leaving") }
                }
            }

            ContentSubsection {
                title: Translation.tr("Navigation")

                ConfigSwitch {
                    text: Translation.tr("Scroll to navigate")
                    description: Translation.tr("Use the mouse wheel over the strip to move between workspaces instead of scrolling the thumbnail list")
                    checked: Config.options?.workspaceStrip?.scrollNavigation ?? false
                    onCheckedChanged: Config.setNestedValue("workspaceStrip.scrollNavigation", checked)
                }

                ConfigSwitch {
                    enabled: Config.options?.workspaceStrip?.scrollNavigation ?? false
                    text: Translation.tr("Switch workspace on scroll")
                    description: Translation.tr("Also focus the workspace in the compositor when scrolling through the strip")
                    checked: Config.options?.workspaceStrip?.scrollNavigationSwitchWorkspace ?? true
                    onCheckedChanged: Config.setNestedValue("workspaceStrip.scrollNavigationSwitchWorkspace", checked)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: Config.options?.workspaceStrip?.scrollNavigation ?? false
                    icon: "speed"
                    text: Translation.tr("Scroll debounce")
                    value: Config.options?.workspaceStrip?.scrollNavigationDebounceMs ?? 180
                    from: 50
                    to: 800
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("workspaceStrip.scrollNavigationDebounceMs", value)
                    StyledToolTip {
                        text: Translation.tr("Minimum milliseconds between scroll-navigation steps — prevents rapid workspace cycling")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "preview"
        title: Translation.tr("Workspace cards")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Window previews")
                description: Translation.tr("Live preview for the active workspace and refreshed snapshots for hidden workspaces")
                checked: Config.options?.workspaceStrip?.showPreviews ?? true
                onCheckedChanged: Config.setNestedValue("workspaceStrip.showPreviews", checked)
            }

            ConfigSwitch {
                text: Translation.tr("Window metadata")
                description: Translation.tr("Show workspace name, focused window title and window count")
                checked: Config.options?.workspaceStrip?.showMetadata ?? true
                onCheckedChanged: Config.setNestedValue("workspaceStrip.showMetadata", checked)
            }

            ConfigSwitch {
                text: Translation.tr("App icons")
                description: Translation.tr("Show icons for open applications on the selected workspace card")
                checked: Config.options?.workspaceStrip?.showAppIcons ?? true
                onCheckedChanged: Config.setNestedValue("workspaceStrip.showAppIcons", checked)
            }

            ConfigSwitch {
                text: Translation.tr("Now-playing player")
                description: Translation.tr("Add a media card at the top of the strip with playback controls when music is playing")
                checked: Config.options?.workspaceStrip?.showMediaPlayer ?? true
                onCheckedChanged: Config.setNestedValue("workspaceStrip.showMediaPlayer", checked)
            }

            ConfigSwitch {
                text: Translation.tr("Per-monitor workspaces")
                description: CompositorService.isNiri
                    ? Translation.tr("Each screen shows only its own Niri workspaces")
                    : Translation.tr("Only available on Niri")
                enabled: CompositorService.isNiri
                checked: Config.options?.workspaceStrip?.perMonitor ?? true
                onCheckedChanged: Config.setNestedValue("workspaceStrip.perMonitor", checked)
            }
        }
    }
}
