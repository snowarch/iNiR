import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true
    settingsPageIndex: 2
    settingsPageName: Translation.tr("Bar")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    ContentSection {
        visible: !root.isIiActive
        icon: "info"
        title: Translation.tr("Not Active")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("These settings only apply when using the Material (ii) panel style. Go to Modules → Panel Style to switch.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "notifications"
        title: Translation.tr("Notifications")
        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Unread indicator: show count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "widgets"
        title: Translation.tr("Bar modules")
        // Edge modules: simple toggles
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "side_navigation"
                text: Translation.tr("Left sidebar button")
                checked: Config.options.bar.modules.leftSidebarButton
                onCheckedChanged: {
                    Config.options.bar.modules.leftSidebarButton = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "window"
                text: Translation.tr("Active window title")
                checked: Config.options.bar.modules.activeWindow
                onCheckedChanged: {
                    Config.options.bar.modules.activeWindow = checked;
                }
            }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "call_to_action"
                text: Translation.tr("Right sidebar button")
                checked: Config.options.bar.modules.rightSidebarButton
                onCheckedChanged: {
                    Config.options.bar.modules.rightSidebarButton = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "shelf_auto_hide"
                text: Translation.tr("System tray")
                checked: Config.options.bar.modules.sysTray
                onCheckedChanged: {
                    Config.options.bar.modules.sysTray = checked;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "cloud"
            text: Translation.tr("Weather")
            checked: Config.options.bar.modules.weather
            onCheckedChanged: {
                Config.options.bar.modules.weather = checked;
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "spoke"
        title: Translation.tr("Positioning")

        ConfigRow {
            uniform: true
            ContentSubsection {
                title: Translation.tr("Bar position")

                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top"),
                            icon: "arrow_upward",
                            value: 0 // bottom: false, vertical: false
                        },
                        {
                            displayName: Translation.tr("Left"),
                            icon: "arrow_back",
                            value: 2 // bottom: false, vertical: true
                        },
                        {
                            displayName: Translation.tr("Bottom"),
                            icon: "arrow_downward",
                            value: 1 // bottom: true, vertical: false
                        },
                        {
                            displayName: Translation.tr("Right"),
                            icon: "arrow_forward",
                            value: 3 // bottom: true, vertical: true
                        }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Automatically hide")

                ConfigSelectionArray {
                    currentValue: Config.options.bar.autoHide.enable
                    onSelected: newValue => {
                        Config.options.bar.autoHide.enable = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigRow {
            uniform: true
            ContentSubsection {
                title: Translation.tr("Corner style")

                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => {
                        Config.options.bar.cornerStyle = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("Hug"),
                            icon: "line_curve",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Float"),
                            icon: "page_header",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "toolbar",
                            value: 2
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Group style")

                ConfigSelectionArray {
                    currentValue: Config.options.bar.borderless
                    onSelected: newValue => {
                        Config.options.bar.borderless = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("Pills"),
                            icon: "location_chip",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Line-separated"),
                            icon: "split_scene",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "layers"
            text: Translation.tr("Show bar background")
            checked: Config.options.bar.showBackground
            onCheckedChanged: {
                Config.options.bar.showBackground = checked;
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "shelf_auto_hide"
        title: Translation.tr("Tray")

        ConfigSwitch {
            buttonIcon: "keep"
            text: Translation.tr('Make icons pinned by default')
            checked: Config.options.bar.tray.invertPinnedItems
            onCheckedChanged: {
                Config.options.bar.tray.invertPinnedItems = checked;
            }
        }
        
        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint icons')
            checked: Config.options.bar.tray.monochromeIcons
            onCheckedChanged: {
                Config.options.bar.tray.monochromeIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "bug_report"
            text: Translation.tr('Show item ID in tooltip')
            checked: Config.options.bar.tray.showItemId
            onCheckedChanged: {
                Config.options.bar.tray.showItemId = checked;
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "widgets"
        title: Translation.tr("Utility buttons")

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "content_cut"
                text: Translation.tr("Screen snip")
                checked: Config.options.bar.utilButtons.showScreenSnip
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenSnip = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "colorize"
                text: Translation.tr("Color picker")
                checked: Config.options.bar.utilButtons.showColorPicker
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showColorPicker = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Keyboard toggle")
                checked: Config.options.bar.utilButtons.showKeyboardToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showKeyboardToggle = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Mic toggle")
                checked: Config.options.bar.utilButtons.showMicToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showMicToggle = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Dark/Light toggle")
                checked: Config.options.bar.utilButtons.showDarkModeToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showDarkModeToggle = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "speed"
                text: Translation.tr("Performance Profile toggle")
                checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showPerformanceProfileToggle = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "videocam"
                text: Translation.tr("Record")
                checked: Config.options.bar.utilButtons.showScreenRecord
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenRecord = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "edit_note"
                text: Translation.tr("Notepad")
                checked: Config.options.bar.utilButtons.showNotepad
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showNotepad = checked;
                }
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "cloud"
        title: Translation.tr("Weather")
        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.bar.weather.enable
            onCheckedChanged: {
                Config.options.bar.weather.enable = checked;
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "workspaces"
        title: Translation.tr("Workspaces")

        ContentSubsection {
            title: Translation.tr("Scroll behavior")
            visible: CompositorService.isNiri

            ConfigSelectionArray {
                currentValue: Config.options?.bar?.workspaces?.scrollBehavior ?? "workspace"
                onSelected: newValue => {
                    Config.setNestedValue("bar.workspaces.scrollBehavior", newValue)
                }
                options: [
                    {
                        displayName: Translation.tr("Switch workspaces"),
                        icon: "workspaces",
                        value: "workspace"
                    },
                    {
                        displayName: Translation.tr("Cycle columns"),
                        icon: "view_column",
                        value: "column"
                    }
                ]
            }
        }

        ConfigSwitch {
            buttonIcon: "counter_1"
            text: Translation.tr('Always show numbers')
            checked: Config.options.bar.workspaces.alwaysShowNumbers
            onCheckedChanged: {
                Config.options.bar.workspaces.alwaysShowNumbers = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "award_star"
            text: Translation.tr('Show app icons')
            checked: Config.options.bar.workspaces.showAppIcons
            onCheckedChanged: {
                Config.options.bar.workspaces.showAppIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint app icons')
            checked: Config.options.bar.workspaces.monochromeIcons
            onCheckedChanged: {
                Config.options.bar.workspaces.monochromeIcons = checked;
            }
        }

        ConfigSpinBox {
            icon: "view_column"
            text: Translation.tr("Workspaces shown")
            value: Config.options.bar.workspaces.shown
            from: 1
            to: 30
            stepSize: 1
            onValueChanged: {
                Config.options.bar.workspaces.shown = value;
            }
        }

        ConfigSpinBox {
            icon: "touch_long"
            text: Translation.tr("Number show delay when pressing Super (ms)")
            value: Config.options.bar.workspaces.showNumberDelay
            from: 0
            to: 1000
            stepSize: 50
            onValueChanged: {
                Config.options.bar.workspaces.showNumberDelay = value;
            }
        }

        ContentSubsection {
            title: Translation.tr("Number style")

            ConfigSelectionArray {
                currentValue: JSON.stringify(Config.options.bar.workspaces.numberMap)
                onSelected: newValue => {
                    Config.options.bar.workspaces.numberMap = JSON.parse(newValue)
                }
                options: [
                    {
                        displayName: Translation.tr("Normal"),
                        icon: "timer_10",
                        value: '["1","2","3","4","5","6","7","8","9","10"]'
                    },
                    {
                        displayName: Translation.tr("Japanese"),
                        icon: "square_dot",
                        value: '["一","二","三","四","五","六","七","八","九","十"]'
                    },
                    {
                        displayName: Translation.tr("Roman"),
                        icon: "account_balance",
                        value: '["I","II","III","IV","V","VI","VII","VIII","IX","X"]'
                    }
                ]
            }
        }
    }
}
