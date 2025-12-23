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

    SettingsCardSection {
        visible: !root.isIiActive
        expanded: true
        icon: "info"
        title: Translation.tr("Not Active")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("These settings only apply when using the Material (ii) panel style. Go to Modules → Panel Style to switch.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "notifications"
        title: Translation.tr("Notifications")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "counter_2"
                text: Translation.tr("Unread indicator: show count")
                checked: Config.options.bar.indicators.notifications.showUnreadCount
                onCheckedChanged: {
                    Config.options.bar.indicators.notifications.showUnreadCount = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Show the number of unread notifications instead of just a dot")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "widgets"
        title: Translation.tr("Bar modules")

        SettingsGroup {
            // Edge modules: simple toggles
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "side_navigation"
                    text: Translation.tr("Left sidebar button")
                    checked: Config.options.bar.modules.leftSidebarButton
                    onCheckedChanged: {
                        Config.options.bar.modules.leftSidebarButton = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show button to open AI chat and tools sidebar")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "window"
                    text: Translation.tr("Active window title")
                    checked: Config.options.bar.modules.activeWindow
                    onCheckedChanged: {
                        Config.options.bar.modules.activeWindow = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show the title of the currently focused window")
                    }
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "call_to_action"
                    text: Translation.tr("Right sidebar button")
                    checked: Config.options.bar.modules.rightSidebarButton
                    onCheckedChanged: {
                        Config.options.bar.modules.rightSidebarButton = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show button to open quick settings and notifications sidebar")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "shelf_auto_hide"
                    text: Translation.tr("System tray")
                    checked: Config.options.bar.modules.sysTray
                    onCheckedChanged: {
                        Config.options.bar.modules.sysTray = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show system tray icons from running applications")
                    }
                }
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "cloud"
                text: Translation.tr("Weather")
                checked: Config.options.bar.modules.weather
                onCheckedChanged: {
                    Config.options.bar.modules.weather = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Show current weather conditions in the bar")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "spoke"
        title: Translation.tr("Positioning")

        SettingsGroup {
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
                            { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
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
                            { displayName: Translation.tr("No"), icon: "close", value: false },
                            { displayName: Translation.tr("Yes"), icon: "check", value: true }
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
                            { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                            { displayName: Translation.tr("Float"), icon: "page_header", value: 1 },
                            { displayName: Translation.tr("Rect"), icon: "toolbar", value: 2 },
                            { displayName: Translation.tr("Card"), icon: "branding_watermark", value: 3 }
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
                            { displayName: Translation.tr("Pills"), icon: "location_chip", value: false },
                            { displayName: Translation.tr("Line-separated"), icon: "split_scene", value: true }
                        ]
                    }
                }
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "layers"
                text: Translation.tr("Show bar background")
                checked: Config.options.bar.showBackground
                onCheckedChanged: {
                    Config.options.bar.showBackground = checked;
                    if (checked) {
                        Config.setNestedValue("bar.blurBackground.enabled", false)
                    }
                }
                StyledToolTip {
                    text: Translation.tr("Show a semi-transparent background behind the bar")
                }
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Blur bar background")
                checked: Config.options?.bar?.blurBackground?.enabled ?? false
                onCheckedChanged: {
                    Config.setNestedValue("bar.blurBackground.enabled", checked)
                    if (checked) {
                        Config.options.bar.showBackground = false;
                    }
                }
                StyledToolTip {
                    text: Translation.tr("Uses a blurred wallpaper background effect similar to the Media Controls popup")
                }
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "vignette"
                text: Translation.tr("Vignette effect")
                checked: Config.options?.bar?.vignette?.enabled ?? false
                onCheckedChanged: {
                    Config.setNestedValue("bar.vignette.enabled", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Add an elegant gradient from the screen edge toward the content")
                }
            }

            ConfigSpinBox {
                visible: Config.options?.bar?.vignette?.enabled ?? false
                icon: "opacity"
                text: Translation.tr("Vignette intensity (%)")
                value: Math.round((Config.options?.bar?.vignette?.intensity ?? 0.6) * 100)
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("bar.vignette.intensity", value / 100)
                }
                StyledToolTip {
                    text: Translation.tr("Control the darkness of the vignette gradient")
                }
            }

            ConfigSpinBox {
                visible: Config.options?.bar?.vignette?.enabled ?? false
                icon: "blur_on"
                text: Translation.tr("Vignette radius (%)")
                value: Math.round((Config.options?.bar?.vignette?.radius ?? 0.5) * 100)
                from: 10
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("bar.vignette.radius", value / 100)
                }
                StyledToolTip {
                    text: Translation.tr("Control how far the gradient extends from the screen edge")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "shelf_auto_hide"
        title: Translation.tr("Tray")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "keep"
                text: Translation.tr('Make icons pinned by default')
                checked: Config.options.bar.tray.invertPinnedItems
                onCheckedChanged: {
                    Config.options.bar.tray.invertPinnedItems = checked;
                }
                StyledToolTip {
                    text: Translation.tr("New tray icons will be visible by default instead of hidden")
                }
            }
            
            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr('Tint icons')
                checked: Config.options.bar.tray.monochromeIcons
                onCheckedChanged: {
                    Config.options.bar.tray.monochromeIcons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to tray icons")
                }
            }

            SettingsSwitch {
                buttonIcon: "bug_report"
                text: Translation.tr('Show item ID in tooltip')
                checked: Config.options.bar.tray.showItemId
                onCheckedChanged: {
                    Config.options.bar.tray.showItemId = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Show the internal ID of tray items (useful for debugging)")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "widgets"
        title: Translation.tr("Utility buttons")

        SettingsGroup {
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "content_cut"
                    text: Translation.tr("Screen snip")
                    checked: Config.options.bar.utilButtons.showScreenSnip
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showScreenSnip = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Open the screen snipping tool")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "colorize"
                    text: Translation.tr("Color picker")
                    checked: Config.options.bar.utilButtons.showColorPicker
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showColorPicker = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Pick a color from the screen")
                    }
                }
            }
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "keyboard"
                    text: Translation.tr("Keyboard toggle")
                    checked: Config.options.bar.utilButtons.showKeyboardToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showKeyboardToggle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Toggle virtual keyboard visibility")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "mic"
                    text: Translation.tr("Mic toggle")
                    checked: Config.options.bar.utilButtons.showMicToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showMicToggle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Toggle microphone mute state")
                    }
                }
            }
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Dark/Light toggle")
                    checked: Config.options.bar.utilButtons.showDarkModeToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showDarkModeToggle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Toggle system dark/light mode")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "speed"
                    text: Translation.tr("Performance Profile toggle")
                    checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showPerformanceProfileToggle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Switch power profiles (Power Saver / Balanced / Performance)")
                    }
                }
            }
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "videocam"
                    text: Translation.tr("Record")
                    checked: Config.options.bar.utilButtons.showScreenRecord
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showScreenRecord = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Start/Stop screen recording")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "edit_note"
                    text: Translation.tr("Notepad")
                    checked: Config.options.bar.utilButtons.showNotepad
                    onCheckedChanged: {
                        Config.options.bar.utilButtons.showNotepad = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Open quick notepad")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "cloud"
        title: Translation.tr("Weather")
        
        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "check"
                text: Translation.tr("Show in bar")
                checked: Config.options?.bar?.weather?.enable ?? false
                onCheckedChanged: Config.setNestedValue("bar.weather.enable", checked)
            }
            
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Configure city, units and update interval in Services → Weather")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "workspaces"
        title: Translation.tr("Workspaces")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Scroll behavior")
                visible: CompositorService.isNiri

                ConfigSelectionArray {
                    currentValue: Config.options?.bar?.workspaces?.scrollBehavior ?? "workspace"
                    onSelected: newValue => {
                        Config.setNestedValue("bar.workspaces.scrollBehavior", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Switch workspaces"), icon: "workspaces", value: "workspace" },
                        { displayName: Translation.tr("Cycle columns"), icon: "view_column", value: "column" }
                    ]
                }
            }

            SettingsSwitch {
                buttonIcon: "counter_1"
                text: Translation.tr('Always show numbers')
                checked: Config.options.bar.workspaces.alwaysShowNumbers
                onCheckedChanged: {
                    Config.options.bar.workspaces.alwaysShowNumbers = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Always display workspace numbers instead of only when Super is held")
                }
            }

            SettingsSwitch {
                buttonIcon: "award_star"
                text: Translation.tr('Show app icons')
                checked: Config.options.bar.workspaces.showAppIcons
                onCheckedChanged: {
                    Config.options.bar.workspaces.showAppIcons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Show icons of apps running in each workspace")
                }
            }

            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr('Tint app icons')
                checked: Config.options.bar.workspaces.monochromeIcons
                onCheckedChanged: {
                    Config.options.bar.workspaces.monochromeIcons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to workspace app icons")
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
                StyledToolTip {
                    text: Translation.tr("Number of static workspaces to display in the bar")
                }
            }

            SettingsSwitch {
                buttonIcon: "dynamic_feed"
                text: Translation.tr("Dynamic workspace count")
                checked: Config.options.bar.workspaces.dynamicCount
                onCheckedChanged: {
                    Config.options.bar.workspaces.dynamicCount = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Automatically show only existing workspaces (Niri)")
                }
            }

            SettingsSwitch {
                buttonIcon: "all_inclusive"
                text: Translation.tr("Wrap around")
                checked: Config.options.bar.workspaces.wrapAround
                onCheckedChanged: {
                    Config.options.bar.workspaces.wrapAround = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Cycle from last to first workspace and vice versa")
                }
            }

            ConfigSpinBox {
                icon: "mouse"
                text: Translation.tr("Scroll steps")
                value: Config.options.bar.workspaces.scrollSteps
                from: 1
                to: 10
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.workspaces.scrollSteps = value;
                }
                StyledToolTip {
                    text: Translation.tr("Wheel steps required to switch workspace/column")
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
                StyledToolTip {
                    text: Translation.tr("Delay before showing workspace numbers when holding Super key")
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
                        { displayName: Translation.tr("Normal"), icon: "timer_10", value: '["1","2","3","4","5","6","7","8","9","10"]' },
                        { displayName: Translation.tr("Japanese"), icon: "square_dot", value: '["一","二","三","四","五","六","七","八","九","十"]' },
                        { displayName: Translation.tr("Roman"), icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X"]' }
                    ]
                }
            }
        }
    }
}
