import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 2
    settingsPageName: Translation.tr("Bar")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    // Conflict detection helpers
    readonly property bool isCardStyle: Config.options?.bar?.cornerStyle === 3
    readonly property bool isHugStyle: Config.options?.bar?.cornerStyle === 0
    readonly property bool isFloatStyle: Config.options?.bar?.cornerStyle === 1
    readonly property bool isRectStyle: Config.options?.bar?.cornerStyle === 2
    readonly property bool isGlobalCards: Config.options?.dock?.cardStyle && Config.options?.sidebar?.cardStyle && isCardStyle
    readonly property bool hasVignette: Config.options?.bar?.vignette?.enabled ?? false
    readonly property bool isAutoHide: Config.options?.bar?.autoHide?.enable ?? false
    readonly property bool isBorderless: Config.options?.bar?.borderless ?? false
    readonly property bool showBackground: Config.options?.bar?.showBackground ?? true

    // Global style detection
    readonly property string currentGlobalStyle: Config.options?.appearance?.globalStyle ?? "material"
    readonly property bool isAurora: currentGlobalStyle === "aurora"
    readonly property bool isInir: currentGlobalStyle === "inir"
    readonly property bool isCards: currentGlobalStyle === "cards"
    readonly property bool isMaterial: currentGlobalStyle === "material"

    // Corner style compatibility per global style
    readonly property bool hugNeedsBackground: isHugStyle && !showBackground
    readonly property bool hugOnAurora: isHugStyle && isAurora
    readonly property bool cardOnNonCards: isCardStyle && !isCards

    // Helper component for conflict warnings
    component ConflictNote: RowLayout {
        property string text
        property string icon: "info"
        property bool warning: false
        spacing: 6
        Layout.fillWidth: true

        readonly property color noteColor: {
            if (warning) {
                return Appearance.inirEverywhere ? Appearance.inir.colWarning
                     : Appearance.colors.colTertiary
            }
            return Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                 : Appearance.colors.colSubtext
        }

        MaterialSymbol {
            text: parent.icon
            iconSize: Appearance.font.pixelSize.small
            color: parent.noteColor
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.text
            color: parent.noteColor
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
    }

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

    // ═══════════════════════════════════════════════════════════════════
    // APPEARANCE & LAYOUT
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "dashboard"
        title: Translation.tr("Appearance & Layout")

        SettingsGroup {
            ConfigRow {
                uniform: true

                ContentSubsection {
                    title: Translation.tr("Position")

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
                    title: Translation.tr("Corner style")

                    ConfigSelectionArray {
                        currentValue: Config.options.bar.cornerStyle
                        onSelected: newValue => {
                            Config.options.bar.cornerStyle = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                            { displayName: Translation.tr("Float"), icon: "page_header", value: 1 },
                            { displayName: Translation.tr("Rect"), icon: "toolbar", value: 2 },
                            { displayName: Translation.tr("Card"), icon: "branding_watermark", value: 3 }
                        ]
                    }
                }
            }

            // Corner style conflict notes
            ConflictNote {
                visible: root.hugNeedsBackground
                warning: true
                icon: "warning"
                text: Translation.tr("Hug style requires background enabled to show the corner decorations.")
            }

            ConflictNote {
                visible: root.isCardStyle && !root.isGlobalCards
                warning: true
                icon: "sync_problem"
                text: Translation.tr("Card style here doesn't match dock/sidebar. Go to Themes → Global Style for consistency.")
            }

            ConfigSpinBox {
                icon: "rounded_corner"
                text: Translation.tr("Custom bar rounding (px)")
                value: Config.options?.bar?.customRounding ?? -1
                from: -1
                to: 50
                stepSize: 1
                onValueChanged: {
                    Config.setNestedValue("bar.customRounding", value);
                }
                StyledToolTip {
                    text: Translation.tr("Override bar corner rounding independently from the global theme.\n-1 = use theme default, 0 = sharp corners, higher = rounder")
                }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true

                ContentSubsection {
                    title: Translation.tr("Group style")

                    ConfigSelectionArray {
                        currentValue: Config.options.bar.borderless
                        onSelected: newValue => {
                            Config.options.bar.borderless = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Pills"), icon: "location_chip", value: false },
                            { displayName: Translation.tr("Seamless"), icon: "split_scene", value: true }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Auto-hide")

                    ConfigSelectionArray {
                        currentValue: Config.options.bar.autoHide.enable
                        onSelected: newValue => {
                            Config.options.bar.autoHide.enable = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Off"), icon: "visibility", value: false },
                            { displayName: Translation.tr("On"), icon: "visibility_off", value: true }
                        ]
                    }
                }
            }

            ConflictNote {
                visible: root.isBorderless && root.isCardStyle
                warning: true
                icon: "warning"
                text: Translation.tr("Seamless group style may look odd with Card corner style.")
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "layers"
                text: Translation.tr("Show background")
                checked: Config.options.bar.showBackground
                onCheckedChanged: Config.options.bar.showBackground = checked
                StyledToolTip {
                    text: Translation.tr("Display a background behind the bar")
                }
            }

            SettingsSwitch {
                buttonIcon: "touch_app"
                text: Translation.tr("Show scroll hints")
                checked: Config.options?.bar?.showScrollHints ?? true
                onCheckedChanged: Config.setNestedValue("bar.showScrollHints", checked)
                StyledToolTip {
                    text: Translation.tr("Show brightness/volume icons when hovering bar edges")
                }
            }

            ConflictNote {
                visible: !root.showBackground && root.isBorderless
                icon: "lightbulb"
                text: Translation.tr("No background + Seamless style = floating widgets look")
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "vignette"
                text: Translation.tr("Vignette effect")
                checked: root.hasVignette
                onCheckedChanged: {
                    Config.setNestedValue("bar.vignette.enabled", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Gradient shadow from screen edge")
                }
            }

            ConfigSpinBox {
                visible: root.hasVignette
                icon: "opacity"
                text: Translation.tr("Intensity (%)")
                value: Math.round((Config.options?.bar?.vignette?.intensity ?? 0.6) * 100)
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("bar.vignette.intensity", value / 100)
                }
            }

            ConfigSpinBox {
                visible: root.hasVignette
                icon: "blur_on"
                text: Translation.tr("Radius (%)")
                value: Math.round((Config.options?.bar?.vignette?.radius ?? 0.5) * 100)
                from: 10
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("bar.vignette.radius", value / 100)
                }
            }

            ConflictNote {
                visible: root.hasVignette && root.isAutoHide
                icon: "info"
                text: Translation.tr("Vignette will hide along with the bar when auto-hide is active.")
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MODULES (what to show)
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "widgets"
        title: Translation.tr("Modules")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Toggle which widgets appear in the bar")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "side_navigation"
                    text: Translation.tr("Left sidebar button")
                    checked: Config.options?.bar?.modules?.leftSidebarButton ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.leftSidebarButton", checked)
                }
                SettingsSwitch {
                    buttonIcon: "call_to_action"
                    text: Translation.tr("Right sidebar button")
                    checked: Config.options?.bar?.modules?.rightSidebarButton ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.rightSidebarButton", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "window"
                    text: Translation.tr("Active window title")
                    checked: Config.options?.bar?.modules?.activeWindow ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.activeWindow", checked)
                }
                SettingsSwitch {
                    buttonIcon: "shelf_auto_hide"
                    text: Translation.tr("System tray")
                    checked: Config.options?.bar?.modules?.sysTray ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.sysTray", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "memory"
                    text: Translation.tr("Resources")
                    checked: Config.options?.bar?.modules?.resources ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.resources", checked)
                }
                SettingsSwitch {
                    buttonIcon: "music_note"
                    text: Translation.tr("Media")
                    checked: Config.options?.bar?.modules?.media ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.media", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "workspaces"
                    text: Translation.tr("Workspaces")
                    checked: Config.options?.bar?.modules?.workspaces ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.workspaces", checked)
                }
                SettingsSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Clock")
                    checked: Config.options?.bar?.modules?.clock ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.clock", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "build"
                    text: Translation.tr("Utility buttons")
                    checked: Config.options?.bar?.modules?.utilButtons ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.utilButtons", checked)
                }
                SettingsSwitch {
                    buttonIcon: "battery_full"
                    text: Translation.tr("Battery")
                    checked: Config.options?.bar?.modules?.battery ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.battery", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "cloud"
                    text: Translation.tr("Weather")
                    checked: Config.options?.bar?.modules?.weather ?? false
                    onCheckedChanged: Config.setNestedValue("bar.modules.weather", checked)
                    enabled: Config.options?.bar?.weather?.enable ?? false
                    opacity: enabled ? 1 : 0.5
                }
                Item { Layout.fillWidth: true }
            }

            SettingsDivider {}

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Weather configuration is in Services → Weather")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MEDIA
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "music_note"
        title: Translation.tr("Media")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Popup mode")

                ConfigSelectionArray {
                    currentValue: Config.options?.media?.popupMode ?? "dock"
                    onSelected: newValue => {
                        Config.setNestedValue("media.popupMode", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Bottom overlay"), icon: "picture_in_picture", value: "dock" },
                        { displayName: Translation.tr("From bar"), icon: "open_in_new", value: "bar" }
                    ]
                }
            }

            ConflictNote {
                icon: "info"
                text: Config.options?.media?.popupMode === "bar"
                    ? Translation.tr("Classic style popup anchored to bar widget")
                    : Translation.tr("Modern overlay at screen bottom")
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // WORKSPACES
    // ═══════════════════════════════════════════════════════════════════
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

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "counter_1"
                    text: Translation.tr("Always show numbers")
                    checked: Config.options.bar.workspaces.alwaysShowNumbers
                    onCheckedChanged: Config.options.bar.workspaces.alwaysShowNumbers = checked
                    StyledToolTip {
                        text: Translation.tr("Show numbers instead of only when Super is held")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "award_star"
                    text: Translation.tr("Show app icons")
                    checked: Config.options.bar.workspaces.showAppIcons
                    onCheckedChanged: Config.options.bar.workspaces.showAppIcons = checked
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "colors"
                    text: Translation.tr("Tint app icons")
                    checked: Config.options.bar.workspaces.monochromeIcons
                    onCheckedChanged: Config.options.bar.workspaces.monochromeIcons = checked
                    enabled: Config.options.bar.workspaces.showAppIcons
                    opacity: enabled ? 1 : 0.5
                }
                SettingsSwitch {
                    buttonIcon: "dynamic_feed"
                    text: Translation.tr("Dynamic count")
                    checked: Config.options.bar.workspaces.dynamicCount
                    onCheckedChanged: Config.options.bar.workspaces.dynamicCount = checked
                    StyledToolTip {
                        text: Translation.tr("Only show existing workspaces (Niri)")
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "all_inclusive"
                text: Translation.tr("Wrap around")
                checked: Config.options.bar.workspaces.wrapAround
                onCheckedChanged: Config.options.bar.workspaces.wrapAround = checked
                StyledToolTip {
                    text: Translation.tr("Cycle from last to first and vice versa")
                }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "view_column"
                    text: Translation.tr("Shown")
                    value: Config.options.bar.workspaces.shown
                    from: 1
                    to: 30
                    stepSize: 1
                    onValueChanged: Config.options.bar.workspaces.shown = value
                    enabled: !Config.options.bar.workspaces.dynamicCount
                    opacity: enabled ? 1 : 0.5
                }
                ConfigSpinBox {
                    icon: "mouse"
                    text: Translation.tr("Scroll steps")
                    value: Config.options.bar.workspaces.scrollSteps
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: Config.options.bar.workspaces.scrollSteps = value
                }
            }

            ConfigSpinBox {
                icon: "touch_long"
                text: Translation.tr("Number reveal delay (ms)")
                value: Config.options.bar.workspaces.showNumberDelay
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: Config.options.bar.workspaces.showNumberDelay = value
                enabled: !Config.options.bar.workspaces.alwaysShowNumbers
                opacity: enabled ? 1 : 0.5
            }

            ConflictNote {
                visible: Config.options.bar.workspaces.alwaysShowNumbers
                icon: "info"
                text: Translation.tr("Number reveal delay is ignored when 'Always show numbers' is enabled")
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Number style")

                ConfigSelectionArray {
                    enabled: Config.options?.bar?.workspaces?.alwaysShowNumbers ?? false
                    opacity: enabled ? 1 : 0.5
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

            ConflictNote {
                visible: !Config.options?.bar?.workspaces?.alwaysShowNumbers
                icon: "lightbulb"
                text: Translation.tr("Enable 'Always show numbers' to use number styles")
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SYSTEM TRAY
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "shelf_auto_hide"
        title: Translation.tr("System Tray")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Pin icons by default")
                checked: Config.options.bar.tray.invertPinnedItems
                onCheckedChanged: Config.options.bar.tray.invertPinnedItems = checked
                StyledToolTip {
                    text: Translation.tr("New tray icons are visible by default instead of hidden")
                }
            }

            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr("Tint icons")
                checked: Config.options.bar.tray.monochromeIcons
                onCheckedChanged: Config.options.bar.tray.monochromeIcons = checked
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to tray icons")
                }
            }

            SettingsSwitch {
                buttonIcon: "bug_report"
                text: Translation.tr("Show item ID in tooltip")
                checked: Config.options.bar.tray.showItemId
                onCheckedChanged: Config.options.bar.tray.showItemId = checked
                StyledToolTip {
                    text: Translation.tr("Useful for debugging tray issues")
                }
            }

            ConflictNote {
                visible: !Config.options.bar.modules.sysTray
                warning: true
                icon: "visibility_off"
                text: Translation.tr("System tray is disabled in Modules section above")
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // UTILITY BUTTONS
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "build"
        title: Translation.tr("Utility Buttons")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Quick action buttons in the bar")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "content_cut"
                    text: Translation.tr("Screen snip")
                    checked: Config.options.bar.utilButtons.showScreenSnip
                    onCheckedChanged: Config.options.bar.utilButtons.showScreenSnip = checked
                }
                SettingsSwitch {
                    buttonIcon: "videocam"
                    text: Translation.tr("Screen record")
                    checked: Config.options.bar.utilButtons.showScreenRecord
                    onCheckedChanged: Config.options.bar.utilButtons.showScreenRecord = checked
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Screen cast")
                    checked: Config.options.bar.utilButtons.showScreenCast
                    onCheckedChanged: Config.options.bar.utilButtons.showScreenCast = checked
                    StyledToolTip {
                        text: Translation.tr("Toggle Niri dynamic screen casting (mirroring) to a target output")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "colorize"
                    text: Translation.tr("Color picker")
                    checked: Config.options.bar.utilButtons.showColorPicker
                    onCheckedChanged: Config.options.bar.utilButtons.showColorPicker = checked
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "edit_note"
                    text: Translation.tr("Notepad")
                    checked: Config.options.bar.utilButtons.showNotepad
                    onCheckedChanged: Config.options.bar.utilButtons.showNotepad = checked
                }
                // Empty slot for future button
                Item { Layout.fillWidth: true }
            }

            StyledText {
                visible: Config.options.bar.utilButtons.showScreenCast
                Layout.fillWidth: true
                text: Translation.tr("Toggle button to start/stop Niri dynamic casting (screen mirroring) to a target output.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            MaterialTextArea {
                visible: Config.options.bar.utilButtons.showScreenCast
                Layout.fillWidth: true
                placeholderText: "HDMI-A-1"
                text: Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1"
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.setNestedValue("bar.utilButtons.screenCastOutput", text)
                }
            }

            StyledText {
                visible: Config.options.bar.utilButtons.showScreenCast
                Layout.fillWidth: true
                text: Translation.tr("Run 'niri msg outputs' to find your output name")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "keyboard"
                    text: Translation.tr("Virtual keyboard")
                    checked: Config.options.bar.utilButtons.showKeyboardToggle
                    onCheckedChanged: Config.options.bar.utilButtons.showKeyboardToggle = checked
                }
                SettingsSwitch {
                    buttonIcon: "mic"
                    text: Translation.tr("Mic toggle")
                    checked: Config.options.bar.utilButtons.showMicToggle
                    onCheckedChanged: Config.options.bar.utilButtons.showMicToggle = checked
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Dark/Light mode")
                    checked: Config.options.bar.utilButtons.showDarkModeToggle
                    onCheckedChanged: Config.options.bar.utilButtons.showDarkModeToggle = checked
                }
                SettingsSwitch {
                    buttonIcon: "speed"
                    text: Translation.tr("Power profile")
                    checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                    onCheckedChanged: Config.options.bar.utilButtons.showPerformanceProfileToggle = checked
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // NOTIFICATIONS
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "notifications"
        title: Translation.tr("Notifications")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "counter_2"
                text: Translation.tr("Show unread count")
                checked: Config.options.bar.indicators.notifications.showUnreadCount
                onCheckedChanged: Config.options.bar.indicators.notifications.showUnreadCount = checked
                StyledToolTip {
                    text: Translation.tr("Show number instead of just a dot")
                }
            }
        }
    }
}
