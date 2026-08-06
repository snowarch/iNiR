import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    settingsPageIndex: 22
    settingsPageName: Translation.tr("Dock")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "call_to_action"
        title: Translation.tr("Dock")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.dock.enable
                onCheckedChanged: {
                    Config.setNestedValue("dock.enable", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Show the macOS-style dock at the bottom of the screen")
                }
            }

            ContentSubsection {
                title: Translation.tr("Dock style")
                tooltip: Translation.tr("How the dock surface is drawn.")

                ConfigSelectionArray {
                    currentValue: Config.options?.dock?.style ?? "panel"
                    onSelected: newValue => {
                        Config.setNestedValue("dock.style", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Panel"),  icon: "dock_to_bottom", value: "panel"  },
                        { displayName: Translation.tr("Pill"),   icon: "interests",      value: "pill"   },
                        { displayName: Translation.tr("macOS"),  icon: "desktop_mac",    value: "macos"  },
                        { displayName: Translation.tr("Island"), icon: "blur_on",        value: "island" },
                        { displayName: Translation.tr("M3"),     icon: "category",       value: "m3"     }
                    ]
                }

                SettingsNote {
                    icon: "dock_to_bottom"
                    text: Translation.tr("Redraws the dock surface.")
                }
            }

            ConfigRow {
                uniform: true
                ContentSubsection {
                    title: Translation.tr("Dock position")

                    ConfigSelectionArray {
                        currentValue: Config.options?.dock?.position ?? "bottom"
                        onSelected: newValue => {
                            Config.setNestedValue('dock.position', newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Top"), icon: "arrow_upward", value: "top" },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                        ]
                    }
                }
                ContentSubsection {
                    title: Translation.tr("Reveal behavior")
                    tooltip: Translation.tr("When the dock shows. Hover hides it until you reach the screen edge; Empty workspace keeps it visible on an empty desktop.")

                    ConfigSelectionArray {
                        currentValue: Config.options?.dock?.hoverToReveal ?? true
                        onSelected: newValue => {
                            Config.setNestedValue('dock.hoverToReveal', newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Hover"), icon: "highlight_mouse_cursor", value: true },
                            { displayName: Translation.tr("Empty workspace"), icon: "desktop_windows", value: false }
                        ]
                    }
                    SettingsSwitch {
                        buttonIcon: "desktop_windows"
                        text: Translation.tr("Show on desktop")
                        // In Hover mode the dock is already hidden by default, so
                        // this only matters for Empty workspace mode.
                        enabled: !(Config.options?.dock?.hoverToReveal ?? true)
                        checked: Config.options?.dock?.showOnDesktop ?? true
                        onCheckedChanged: Config.setNestedValue('dock.showOnDesktop', checked)
                        StyledToolTip {
                            text: Translation.tr("Show dock when no window is focused (Empty workspace mode only)")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "keep"
                        text: Translation.tr("Pinned on startup")
                        // A pinned dock can never hide, which cancels Hover reveal.
                        // Disable it under Hover so the contradiction is visible.
                        enabled: !(Config.options?.dock?.hoverToReveal ?? true)
                        checked: Config.options.dock.pinnedOnStartup
                        onCheckedChanged: {
                            Config.setNestedValue("dock.pinnedOnStartup", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Keep dock visible at all times (Empty workspace mode only)")
                        }
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr("Tint app icons")
                checked: Config.options.dock.monochromeIcons
                onCheckedChanged: {
                    Config.setNestedValue("dock.monochromeIcons", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to dock app icons")
                }
            }
            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Show dock background")
                checked: Config.options.dock.showBackground
                onCheckedChanged: Config.setNestedValue("dock.showBackground", checked)
                StyledToolTip {
                    text: Translation.tr("Show a background behind the dock")
                }
            }

            SettingsSwitch {
                buttonIcon: "splitscreen"
                text: Translation.tr("Separate pinned from running")
                checked: Config.options?.dock?.separatePinnedFromRunning ?? true
                onCheckedChanged: Config.setNestedValue('dock.separatePinnedFromRunning', checked)
                StyledToolTip {
                    text: Translation.tr("Show pinned-only apps on the left, running apps on the right with a separator")
                }
            }

            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Notification badges")
                checked: Config.options?.dock?.notificationBadge ?? true
                onCheckedChanged: Config.setNestedValue('dock.notificationBadge', checked)
                StyledToolTip {
                    text: Translation.tr("Show the number of pending notifications on each app icon")
                }
            }

            SettingsSwitch {
                buttonIcon: "drag_indicator"
                text: Translation.tr("Drag to reorder")
                checked: Config.options?.dock?.enableDragReorder ?? true
                onCheckedChanged: Config.setNestedValue('dock.enableDragReorder', checked)
                StyledToolTip {
                    text: Translation.tr("Long-press and drag dock icons to reorder pinned apps")
                }
            }

            ContentSubsection {
                title: Translation.tr("Appearance")

                SettingsSwitch {
                    buttonIcon: "branding_watermark"
                    text: Translation.tr("Use Card style")
                    checked: Config.options.dock?.cardStyle ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.cardStyle", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Use the new Card style (lighter background, specific rounding) generic to settings")
                    }
                }

                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Dock height (px)")
                    value: Config.options.dock.height ?? 60
                    from: 40
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("dock.height", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Height of the dock container")
                    }
                }

                ConfigSpinBox {
                    icon: "aspect_ratio"
                    text: Translation.tr("Icon size (px)")
                    value: Config.options.dock.iconSize ?? 35
                    from: 20
                    to: 60
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("dock.iconSize", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Size of application icons in the dock")
                    }
                }

                ConfigSpinBox {
                    icon: {
                        const pos = Config.options?.dock?.position ?? "bottom"
                        switch (pos) {
                            case "top": return "vertical_align_top"
                            case "left": return "align_horizontal_left"
                            case "right": return "align_horizontal_right"
                            default: return "vertical_align_bottom"
                        }
                    }
                    text: Translation.tr("Hover reveal region size (px)")
                    value: Config.options.dock.hoverRegionHeight ?? 2
                    from: 1
                    to: 20
                    stepSize: 1
                    enabled: Config.options.dock.hoverToReveal
                    onValueChanged: {
                        Config.setNestedValue("dock.hoverRegionHeight", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Size of the invisible area at screen edge that triggers dock reveal")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Window indicators")

                SettingsSwitch {
                    buttonIcon: "my_location"
                    text: Translation.tr("Smart indicator (highlight focused window)")
                    checked: Config.options.dock.smartIndicator !== false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.smartIndicator", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("When multiple windows of the same app are open, highlight which one is focused")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "more_horiz"
                    text: Translation.tr("Show dots for inactive apps")
                    checked: Config.options.dock.showAllWindowDots !== false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.showAllWindowDots", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a dot per window even for apps that aren't currently focused")
                    }
                }

                ConfigSpinBox {
                    icon: "filter_5"
                    text: Translation.tr("Maximum indicator dots")
                    value: Config.options.dock.maxIndicatorDots ?? 5
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("dock.maxIndicatorDots", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Limit the number of open window dots shown below an app icon")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Window preview")

                SettingsSwitch {
                    buttonIcon: "preview"
                    text: Translation.tr("Show preview on hover")
                    checked: Config.options.dock.hoverPreview !== false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.hoverPreview", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Display a live preview of windows when hovering over dock icons")
                    }
                }

                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Hover delay (ms)")
                    value: Config.options.dock.hoverPreviewDelay ?? 400
                    from: 0
                    to: 1000
                    stepSize: 50
                    enabled: Config.options.dock.hoverPreview !== false
                    onValueChanged: {
                        Config.setNestedValue("dock.hoverPreviewDelay", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Time to wait before showing window preview")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "keep"
                    text: Translation.tr("Keep preview on click")
                    enabled: Config.options.dock.hoverPreview !== false
                    checked: Config.options?.dock?.keepPreviewOnClick ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.keepPreviewOnClick", checked)
                    }
                    StyledToolTip {
                        text: Translation.tr("Keeps the preview open while you click through windows.")
                    }
                }
            }
        }
    }

}
