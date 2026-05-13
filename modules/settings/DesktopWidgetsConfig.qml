import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 14
    settingsPageName: Translation.tr("Widgets")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    // Zone names for placement strategy resolution
    readonly property var _zoneNames: ["topLeft", "topCenter", "topRight", "centerLeft", "center", "centerRight", "bottomLeft", "bottomCenter", "bottomRight"]

    // Resolve any zone name to the display mode "zone"
    function _resolvedMode(strategy: string): string {
        if (root._zoneNames.indexOf(strategy) >= 0) return "zone";
        return strategy;
    }

    // Handle mode selection — when "zone" selected, default to center
    function _applyMode(configPath: string, mode: string, currentStrategy: string): void {
        if (mode === "zone") {
            // If already on a zone, keep it; otherwise default to center
            if (root._zoneNames.indexOf(currentStrategy) < 0)
                Config.setNestedValue(configPath + ".placementStrategy", "center");
        } else {
            Config.setNestedValue(configPath + ".placementStrategy", mode);
        }
    }

    function _placementOptions(): var {
        return [
            { displayName: Translation.tr("Draggable"), icon: "drag_pan", value: "free" },
            { displayName: Translation.tr("Least busy"), icon: "category", value: "leastBusy" },
            { displayName: Translation.tr("Most busy"), icon: "shapes", value: "mostBusy" },
            { displayName: Translation.tr("Zone"), icon: "grid_view", value: "zone" },
        ]
    }

    function _colorModeOptions(): var {
        return [
            { displayName: Translation.tr("Auto"), icon: "auto_awesome", value: "auto" },
            { displayName: Translation.tr("Light"), icon: "light_mode", value: "light" },
            { displayName: Translation.tr("Dark"), icon: "dark_mode", value: "dark" },
        ]
    }

    // ── Reusable zone picker (3x3 grid) ────────────────────────
    component WidgetZonePicker: ColumnLayout {
        id: wzp
        required property string configPath
        required property var configEntry
        Layout.fillWidth: true

        readonly property string currentStrategy: configEntry?.placementStrategy ?? "free"
        readonly property bool isZone: root._zoneNames.indexOf(currentStrategy) >= 0
        visible: isZone

        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            spacing: 3

            Repeater {
                model: [
                    { zone: "topLeft", icon: "north_west" },
                    { zone: "topCenter", icon: "north" },
                    { zone: "topRight", icon: "north_east" },
                    { zone: "centerLeft", icon: "west" },
                    { zone: "center", icon: "filter_center_focus" },
                    { zone: "centerRight", icon: "east" },
                    { zone: "bottomLeft", icon: "south_west" },
                    { zone: "bottomCenter", icon: "south" },
                    { zone: "bottomRight", icon: "south_east" }
                ]
                delegate: RippleButton {
                    required property var modelData
                    width: 36; height: 36
                    buttonRadius: Appearance.rounding.small
                    toggled: wzp.currentStrategy === modelData.zone
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                    colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                    colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                    downAction: () => Config.setNestedValue(wzp.configPath + ".placementStrategy", modelData.zone)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: 18
                        color: parent.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }

    // ── Reusable placement selector (resolves zone names) ──────
    component WidgetPlacementSelector: ConfigSelectionArray {
        id: wps
        required property string configPath
        required property var configEntry
        required property string defaultStrategy
        Layout.fillWidth: false

        readonly property string currentStrategy: configEntry?.placementStrategy ?? defaultStrategy

        currentValue: root._resolvedMode(wps.currentStrategy)
        onSelected: newValue => root._applyMode(wps.configPath, newValue, wps.currentStrategy)
        options: root._placementOptions()
    }

    // ── Reusable appearance controls for any widget ──────────
    component WidgetAppearanceControls: ContentSubsection {
        id: wac
        required property string configPath
        required property var configEntry
        property bool hasDim: true
        property bool hasCardControls: false
        property int dimDefault: 0
        title: Translation.tr("Appearance")

        ConfigRow {
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Scale"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSpinBox {
                from: 50; to: 200; stepSize: 10
                value: wac.configEntry?.widgetScale ?? 100
                onValueModified: Config.setNestedValue(wac.configPath + ".widgetScale", value)
            }
        }

        ConfigRow {
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Opacity"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSlider {
                from: 10; to: 100; stepSize: 5
                value: wac.configEntry?.widgetOpacity ?? 100
                onMoved: Config.setNestedValue(wac.configPath + ".widgetOpacity", Math.round(value))
            }
        }

        ConfigRow {
            visible: wac.hasDim
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Dim"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSlider {
                from: 0; to: 100; stepSize: 5
                value: wac.configEntry?.dim ?? wac.dimDefault
                onMoved: Config.setNestedValue(wac.configPath + ".dim", Math.round(value))
            }
        }

        ConfigRow {
            visible: wac.hasCardControls
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Background opacity"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSlider {
                from: 0; to: 100; stepSize: 1
                value: Math.round((wac.configEntry?.backgroundOpacity ?? 0.06) * 100)
                onMoved: Config.setNestedValue(wac.configPath + ".backgroundOpacity", Math.round(value) / 100)
            }
        }

        ConfigRow {
            visible: wac.hasCardControls
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Border width"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSpinBox {
                from: 0; to: 8; stepSize: 1
                value: wac.configEntry?.borderWidth ?? 1
                onValueModified: Config.setNestedValue(wac.configPath + ".borderWidth", value)
            }
        }

        ConfigRow {
            visible: wac.hasCardControls
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Border opacity"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSlider {
                from: 0; to: 100; stepSize: 1
                value: Math.round((wac.configEntry?.borderOpacity ?? 0.08) * 100)
                onMoved: Config.setNestedValue(wac.configPath + ".borderOpacity", Math.round(value) / 100)
            }
        }

        ConfigRow {
            visible: wac.hasCardControls
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Corner radius"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            StyledSpinBox {
                from: -1; to: 50; stepSize: 1
                value: wac.configEntry?.cornerRadius ?? -1
                onValueModified: Config.setNestedValue(wac.configPath + ".cornerRadius", value)
                StyledToolTip { text: Translation.tr("-1 = use theme default") }
            }
        }

        ConfigRow {
            Layout.fillWidth: true
            StyledText { text: Translation.tr("Color mode"); color: Appearance.colors.colOnLayer1 }
            Item { Layout.fillWidth: true }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: wac.configEntry?.colorMode ?? "auto"
                onSelected: newValue => Config.setNestedValue(wac.configPath + ".colorMode", newValue)
                options: root._colorModeOptions()
            }
        }
    }

    // ── Edit Mode & Grid ─────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: "grid_on"
        title: Translation.tr("Edit Mode")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "edit"
                    text: Translation.tr("Edit Mode")
                    autoToggle: false

                    checked: GlobalStates.widgetEditMode
                    onToggledByUser: checked => GlobalStates.widgetEditMode = checked
                    StyledToolTip {
                        text: Translation.tr("Show alignment grid and enable snap-to-grid for widget placement")
                    }
                }
            }
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "grid_3x3"
                    text: Translation.tr("Snap to grid")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.editGrid?.snap ?? true
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.editGrid.snap", checked)
                }
                Item { Layout.fillWidth: true }
                StyledSpinBox {
                    from: 8; to: 128; stepSize: 8
                    value: Config.options?.background?.widgets?.editGrid?.size ?? 32
                    onValueModified: Config.setNestedValue("background.widgets.editGrid.size", value)
                    StyledToolTip {
                        text: Translation.tr("Grid cell size in pixels")
                    }
                }
            }
        }
    }

    // ── Clock ────────────────────────────────────────────────
    SettingsCardSection {
        id: clockSection
        visible: root.isIiActive
        expanded: false
        icon: "schedule"
        title: Translation.tr("Clock")

        readonly property string _clockStyle: Config.options?.background?.widgets?.clock?.style ?? "cookie"

        SettingsGroup {
            // Enable + placement
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.clock?.enable ?? true
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.enable", checked)
                }
                Item { Layout.fillWidth: true }
                WidgetPlacementSelector {
                    configPath: "background.widgets.clock"
                    configEntry: Config.options?.background?.widgets?.clock
                    defaultStrategy: "leastBusy"
                }
            }

            WidgetZonePicker {
                configPath: "background.widgets.clock"
                configEntry: Config.options?.background?.widgets?.clock
            }

            // Style selector
            ContentSubsection {
                title: Translation.tr("Clock style")

                ConfigSelectionArray {
                    currentValue: Config.options?.background?.widgets?.clock?.style ?? "cookie"
                    onSelected: newValue => Config.setNestedValue("background.widgets.clock.style", newValue)
                    options: [
                        { displayName: Translation.tr("Digital"), icon: "timer", value: "digital" },
                        { displayName: Translation.tr("Cookie"), icon: "cookie", value: "cookie" },
                    ]
                }
            }

            // ── Digital clock settings ──
            ContentSubsection {
                visible: clockSection._clockStyle === "digital"
                title: Translation.tr("Time format")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.clock?.timeFormat ?? "system"
                    onSelected: newValue => Config.setNestedValue("background.widgets.clock.timeFormat", newValue)
                    options: [
                        { displayName: Translation.tr("System"), icon: "settings", value: "system" },
                        { displayName: Translation.tr("24h"), icon: "schedule", value: "24h" },
                        { displayName: Translation.tr("12h"), icon: "nest_clock_farsight_analog", value: "12h" },
                    ]
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "digital"
                title: Translation.tr("Date style")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.clock?.dateStyle ?? "long"
                    onSelected: newValue => Config.setNestedValue("background.widgets.clock.dateStyle", newValue)
                    options: [
                        { displayName: Translation.tr("Long"), icon: "calendar_month", value: "long" },
                        { displayName: Translation.tr("Minimal"), icon: "event_note", value: "minimal" },
                        { displayName: Translation.tr("Weekday"), icon: "today", value: "weekday" },
                        { displayName: Translation.tr("Numeric"), icon: "pin", value: "numeric" },
                    ]
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "digital"
                title: Translation.tr("Digital preset")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.clock?.digital?.preset ?? "default"
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.clock.digital.preset", newValue);
                        if (newValue === "default") {
                            Config.setNestedValue("background.widgets.clock.digital.fontWeight", 600);
                            Config.setNestedValue("background.widgets.clock.digital.spacing", 6);
                        } else if (newValue === "light") {
                            Config.setNestedValue("background.widgets.clock.digital.fontWeight", 300);
                            Config.setNestedValue("background.widgets.clock.digital.spacing", 8);
                        } else if (newValue === "bold") {
                            Config.setNestedValue("background.widgets.clock.digital.fontWeight", 800);
                            Config.setNestedValue("background.widgets.clock.digital.spacing", 4);
                        } else if (newValue === "mono") {
                            Config.setNestedValue("background.widgets.clock.digital.fontWeight", 500);
                            Config.setNestedValue("background.widgets.clock.digital.spacing", 2);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "timer", value: "default" },
                        { displayName: Translation.tr("Light"), icon: "format_size", value: "light" },
                        { displayName: Translation.tr("Bold"), icon: "format_bold", value: "bold" },
                        { displayName: Translation.tr("Mono"), icon: "terminal", value: "mono" },
                    ]
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "digital"
                title: Translation.tr("Display options")

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "timer"
                        text: Translation.tr("Seconds")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.clock?.showSeconds ?? false
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.showSeconds", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "calendar_today"
                        text: Translation.tr("Date")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.clock?.showDate ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.showDate", checked)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "shadow"
                        text: Translation.tr("Shadow")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.clock?.showShadow ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.showShadow", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "animation"
                        text: Translation.tr("Animate")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.clock?.digital?.animateChange ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.digital.animateChange", checked)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Font weight"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 100; to: 900; stepSize: 100
                        value: Config.options?.background?.widgets?.clock?.digital?.fontWeight ?? 600
                        onValueModified: Config.setNestedValue("background.widgets.clock.digital.fontWeight", value)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Spacing"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 20; stepSize: 1
                        value: Config.options?.background?.widgets?.clock?.digital?.spacing ?? 6
                        onValueModified: Config.setNestedValue("background.widgets.clock.digital.spacing", value)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Time scale"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 50; to: 200; stepSize: 5
                        value: Config.options?.background?.widgets?.clock?.timeScale ?? 100
                        onValueModified: Config.setNestedValue("background.widgets.clock.timeScale", value)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Date scale"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 50; to: 200; stepSize: 5
                        value: Config.options?.background?.widgets?.clock?.dateScale ?? 100
                        onValueModified: Config.setNestedValue("background.widgets.clock.dateScale", value)
                    }
                }

                FontSelector {
                    label: Translation.tr("Clock font")
                    icon: "font_download"
                    selectedFont: Config.options?.background?.widgets?.clock?.fontFamily ?? "Space Grotesk"
                    onSelectedFontChanged: Config.setNestedValue("background.widgets.clock.fontFamily", selectedFont)
                }
            }

            // ── Quote (digital + cookie) ──
            ContentSubsection {
                title: Translation.tr("Quote")

                SettingsSwitch {
                    buttonIcon: "format_quote"
                    text: Translation.tr("Show quote")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.clock?.quote?.enable ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.quote.enable", checked)
                }

                MaterialTextField {
                    visible: Config.options?.background?.widgets?.clock?.quote?.enable ?? false
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Enter a quote or message...")
                    text: Config.options?.background?.widgets?.clock?.quote?.text ?? ""
                    onAccepted: Config.setNestedValue("background.widgets.clock.quote.text", text)
                    onEditingFinished: Config.setNestedValue("background.widgets.clock.quote.text", text)
                }
            }

            // ── Cookie clock settings ──
            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Cookie preset")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.clock?.cookie?.preset ?? "default"
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.clock.cookie.preset", newValue);
                        if (newValue === "default") {
                            Config.setNestedValue("background.widgets.clock.cookie.size", 230);
                            Config.setNestedValue("background.widgets.clock.cookie.sides", 15);
                            Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", "full");
                            Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", "hollow");
                        } else if (newValue === "compact") {
                            Config.setNestedValue("background.widgets.clock.cookie.size", 160);
                            Config.setNestedValue("background.widgets.clock.cookie.sides", 12);
                            Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", "dots");
                            Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", "fill");
                        } else if (newValue === "large") {
                            Config.setNestedValue("background.widgets.clock.cookie.size", 300);
                            Config.setNestedValue("background.widgets.clock.cookie.sides", 18);
                            Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", "numbers");
                            Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", "classic");
                        } else if (newValue === "minimal") {
                            Config.setNestedValue("background.widgets.clock.cookie.size", 200);
                            Config.setNestedValue("background.widgets.clock.cookie.sides", 6);
                            Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", "none");
                            Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", "fill");
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "cookie", value: "default" },
                        { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" },
                        { displayName: Translation.tr("Large"), icon: "open_in_full", value: "large" },
                        { displayName: Translation.tr("Minimal"), icon: "circle", value: "minimal" },
                    ]
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Cookie clock shape")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Size"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 100; to: 400; stepSize: 10
                        value: Config.options?.background?.widgets?.clock?.cookie?.size ?? 230
                        onValueModified: Config.setNestedValue("background.widgets.clock.cookie.size", value)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "waves"
                    text: Translation.tr("Sine wave shape")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.clock?.cookie?.useSineCookie ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.cookie.useSineCookie", checked)
                    StyledToolTip { text: Translation.tr("Use smooth sine-wave edges instead of rounded polygon") }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Sides"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 3; to: 30; stepSize: 1
                        value: Config.options?.background?.widgets?.clock?.cookie?.sides ?? 15
                        onValueModified: Config.setNestedValue("background.widgets.clock.cookie.sides", value)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "rotate_right"
                    text: Translation.tr("Constant rotation")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.clock?.cookie?.constantlyRotate ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.cookie.constantlyRotate", checked)
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Dial style")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.clock?.cookie?.dialNumberStyle ?? "full"
                    onSelected: newValue => Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", newValue)
                    options: [
                        { displayName: Translation.tr("Lines"), icon: "linear_scale", value: "full" },
                        { displayName: Translation.tr("Dots"), icon: "more_horiz", value: "dots" },
                        { displayName: Translation.tr("Numbers"), icon: "123", value: "numbers" },
                        { displayName: Translation.tr("None"), icon: "block", value: "none" },
                    ]
                }

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "radio_button_checked"
                        text: Translation.tr("Hour marks")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.clock?.cookie?.hourMarks ?? false
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.cookie.hourMarks", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "pin"
                        text: Translation.tr("Time column")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.clock?.cookie?.timeIndicators ?? false
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.cookie.timeIndicators", checked)
                    }
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Hand styles")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Hour hand"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: Config.options?.background?.widgets?.clock?.cookie?.hourHandStyle ?? "hollow"
                        onSelected: newValue => Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Fill"), icon: "rectangle", value: "fill" },
                            { displayName: Translation.tr("Hollow"), icon: "crop_square", value: "hollow" },
                            { displayName: Translation.tr("Classic"), icon: "straighten", value: "classic" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Minute hand"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: Config.options?.background?.widgets?.clock?.cookie?.minuteHandStyle ?? "hide"
                        onSelected: newValue => Config.setNestedValue("background.widgets.clock.cookie.minuteHandStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Bold"), icon: "rectangle", value: "bold" },
                            { displayName: Translation.tr("Medium"), icon: "horizontal_rule", value: "medium" },
                            { displayName: Translation.tr("Thin"), icon: "remove", value: "thin" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Second hand"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: Config.options?.background?.widgets?.clock?.cookie?.secondHandStyle ?? "hide"
                        onSelected: newValue => Config.setNestedValue("background.widgets.clock.cookie.secondHandStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Classic"), icon: "straighten", value: "classic" },
                            { displayName: Translation.tr("Dot"), icon: "circle", value: "dot" },
                            { displayName: Translation.tr("Line"), icon: "remove", value: "line" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Cookie date indicator")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.clock?.cookie?.dateStyle ?? "bubble"
                    onSelected: newValue => Config.setNestedValue("background.widgets.clock.cookie.dateStyle", newValue)
                    options: [
                        { displayName: Translation.tr("Bubble"), icon: "chat_bubble", value: "bubble" },
                        { displayName: Translation.tr("Rectangle"), icon: "crop_square", value: "rect" },
                        { displayName: Translation.tr("Border"), icon: "rotate_right", value: "border" },
                        { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                    ]
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("AI styling")

                SettingsSwitch {
                    buttonIcon: "auto_awesome"
                    text: Translation.tr("Auto-style from wallpaper")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.clock?.cookie?.aiStyling ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.clock.cookie.aiStyling", checked)
                    StyledToolTip { text: Translation.tr("Automatically adjust cookie clock style based on wallpaper category") }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.clock"
                configEntry: Config.options?.background?.widgets?.clock
                dimDefault: 55
                hasCardControls: true
            }

            RippleButton {
                Layout.fillWidth: true
                text: Translation.tr("Reset to defaults")
                onClicked: {
                    Config.setNestedValue("background.widgets.clock.style", "digital");
                    Config.setNestedValue("background.widgets.clock.placementStrategy", "free");
                    Config.setNestedValue("background.widgets.clock.fontFamily", "Space Grotesk");
                    Config.setNestedValue("background.widgets.clock.timeFormat", "system");
                    Config.setNestedValue("background.widgets.clock.showSeconds", false);
                    Config.setNestedValue("background.widgets.clock.showDate", true);
                    Config.setNestedValue("background.widgets.clock.dateStyle", "long");
                    Config.setNestedValue("background.widgets.clock.timeScale", 100);
                    Config.setNestedValue("background.widgets.clock.dateScale", 100);
                    Config.setNestedValue("background.widgets.clock.showShadow", true);
                    Config.setNestedValue("background.widgets.clock.dim", 70);
                    Config.setNestedValue("background.widgets.clock.digital.animateChange", true);
                    Config.setNestedValue("background.widgets.clock.digital.fontWeight", 600);
                    Config.setNestedValue("background.widgets.clock.digital.spacing", 6);
                    Config.setNestedValue("background.widgets.clock.digital.preset", "default");
                    Config.setNestedValue("background.widgets.clock.quote.enable", false);
                    Config.setNestedValue("background.widgets.clock.quote.text", "");
                    Config.setNestedValue("background.widgets.clock.cookie.size", 230);
                    Config.setNestedValue("background.widgets.clock.cookie.preset", "default");
                    Config.setNestedValue("background.widgets.clock.cookie.sides", 15);
                    Config.setNestedValue("background.widgets.clock.cookie.useSineCookie", false);
                    Config.setNestedValue("background.widgets.clock.cookie.constantlyRotate", false);
                    Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", "full");
                    Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", "hollow");
                    Config.setNestedValue("background.widgets.clock.cookie.minuteHandStyle", "hide");
                    Config.setNestedValue("background.widgets.clock.cookie.secondHandStyle", "hide");
                    Config.setNestedValue("background.widgets.clock.cookie.dateStyle", "bubble");
                    Config.setNestedValue("background.widgets.clock.cookie.hourMarks", false);
                    Config.setNestedValue("background.widgets.clock.cookie.timeIndicators", false);
                    Config.setNestedValue("background.widgets.clock.cookie.aiStyling", false);
                    Config.setNestedValue("background.widgets.clock.widgetScale", 100);
                    Config.setNestedValue("background.widgets.clock.widgetOpacity", 100);
                    Config.setNestedValue("background.widgets.clock.showBackground", false);
                    Config.setNestedValue("background.widgets.clock.showBorder", false);
                    Config.setNestedValue("background.widgets.clock.backgroundOpacity", 0);
                    Config.setNestedValue("background.widgets.clock.borderWidth", 0);
                    Config.setNestedValue("background.widgets.clock.borderOpacity", 0.08);
                    Config.setNestedValue("background.widgets.clock.cornerRadius", -1);
                    Config.setNestedValue("background.widgets.clock.colorMode", "auto");
                    Config.setNestedValue("background.widgets.clock.x", 100);
                    Config.setNestedValue("background.widgets.clock.y", 100);
                }
            }
        }
    }

    // ── Weather ──────────────────────────────────────────────
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "cloud"
        title: Translation.tr("Weather")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.weather?.enable ?? true
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.weather.enable", checked)
                }
                Item { Layout.fillWidth: true }
                WidgetPlacementSelector {
                    configPath: "background.widgets.weather"
                    configEntry: Config.options?.background?.widgets?.weather
                    defaultStrategy: "leastBusy"
                }
            }

            WidgetZonePicker {
                configPath: "background.widgets.weather"
                configEntry: Config.options?.background?.widgets?.weather
            }

            ContentSubsection {
                title: Translation.tr("Preset")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.weather?.preset ?? "default"
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.weather.preset", newValue);
                        if (newValue === "default") {
                            Config.setNestedValue("background.widgets.weather.size", 200);
                            Config.setNestedValue("background.widgets.weather.tempSize", 80);
                            Config.setNestedValue("background.widgets.weather.iconSize", 80);
                            Config.setNestedValue("background.widgets.weather.showTemp", true);
                            Config.setNestedValue("background.widgets.weather.showIcon", true);
                            Config.setNestedValue("background.widgets.weather.showCondition", false);
                        } else if (newValue === "compact") {
                            Config.setNestedValue("background.widgets.weather.size", 140);
                            Config.setNestedValue("background.widgets.weather.tempSize", 50);
                            Config.setNestedValue("background.widgets.weather.iconSize", 50);
                            Config.setNestedValue("background.widgets.weather.showTemp", true);
                            Config.setNestedValue("background.widgets.weather.showIcon", true);
                            Config.setNestedValue("background.widgets.weather.showCondition", false);
                        } else if (newValue === "iconOnly") {
                            Config.setNestedValue("background.widgets.weather.size", 120);
                            Config.setNestedValue("background.widgets.weather.showTemp", false);
                            Config.setNestedValue("background.widgets.weather.showIcon", true);
                            Config.setNestedValue("background.widgets.weather.showCondition", false);
                        } else if (newValue === "textOnly") {
                            Config.setNestedValue("background.widgets.weather.size", 160);
                            Config.setNestedValue("background.widgets.weather.showTemp", true);
                            Config.setNestedValue("background.widgets.weather.showIcon", false);
                            Config.setNestedValue("background.widgets.weather.showCondition", true);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "cloud", value: "default" },
                        { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" },
                        { displayName: Translation.tr("Icon only"), icon: "image", value: "iconOnly" },
                        { displayName: Translation.tr("Text only"), icon: "text_fields", value: "textOnly" },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Content")

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "thermostat"
                        text: Translation.tr("Temperature")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.weather?.showTemp ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.weather.showTemp", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "cloud"
                        text: Translation.tr("Icon")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.weather?.showIcon ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.weather.showIcon", checked)
                    }
                }
                SettingsSwitch {
                    buttonIcon: "description"
                    text: Translation.tr("Condition text")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.weather?.showCondition ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.weather.showCondition", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Sizing")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Widget size"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 80; to: 400; stepSize: 10
                        value: Config.options?.background?.widgets?.weather?.size ?? 200
                        onValueModified: Config.setNestedValue("background.widgets.weather.size", value)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Temp size"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 20; to: 200; stepSize: 5
                        value: Config.options?.background?.widgets?.weather?.tempSize ?? 80
                        onValueModified: Config.setNestedValue("background.widgets.weather.tempSize", value)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Icon size"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 20; to: 200; stepSize: 5
                        value: Config.options?.background?.widgets?.weather?.iconSize ?? 80
                        onValueModified: Config.setNestedValue("background.widgets.weather.iconSize", value)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Padding"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 60; stepSize: 2
                        value: Config.options?.background?.widgets?.weather?.padding ?? 20
                        onValueModified: Config.setNestedValue("background.widgets.weather.padding", value)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Temp font weight"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 100; to: 900; stepSize: 100
                        value: Config.options?.background?.widgets?.weather?.tempFontWeight ?? 500
                        onValueModified: Config.setNestedValue("background.widgets.weather.tempFontWeight", value)
                    }
                }
                ConfigRow {
                    visible: Config.options?.background?.widgets?.weather?.showCondition ?? false
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Condition opacity"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSlider {
                        from: 0; to: 1; stepSize: 0.05
                        value: Config.options?.background?.widgets?.weather?.conditionOpacity ?? 0.7
                        onMoved: Config.setNestedValue("background.widgets.weather.conditionOpacity", Math.round(value * 100) / 100)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.weather"
                configEntry: Config.options?.background?.widgets?.weather
            }

            RippleButton {
                Layout.fillWidth: true
                text: Translation.tr("Reset to defaults")
                onClicked: {
                    Config.setNestedValue("background.widgets.weather.preset", "default");
                    Config.setNestedValue("background.widgets.weather.placementStrategy", "free");
                    Config.setNestedValue("background.widgets.weather.size", 200);
                    Config.setNestedValue("background.widgets.weather.tempSize", 80);
                    Config.setNestedValue("background.widgets.weather.iconSize", 80);
                    Config.setNestedValue("background.widgets.weather.showTemp", true);
                    Config.setNestedValue("background.widgets.weather.showIcon", true);
                    Config.setNestedValue("background.widgets.weather.showCondition", false);
                    Config.setNestedValue("background.widgets.weather.padding", 20);
                    Config.setNestedValue("background.widgets.weather.tempFontWeight", 500);
                    Config.setNestedValue("background.widgets.weather.conditionOpacity", 0.7);
                    Config.setNestedValue("background.widgets.weather.widgetScale", 100);
                    Config.setNestedValue("background.widgets.weather.widgetOpacity", 100);
                    Config.setNestedValue("background.widgets.weather.colorMode", "auto");
                    Config.setNestedValue("background.widgets.weather.dim", 0);
                    Config.setNestedValue("background.widgets.weather.x", 100);
                    Config.setNestedValue("background.widgets.weather.y", 200);
                }
            }
        }
    }

    // ── Media Controls ───────────────────────────────────────
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "album"
        title: Translation.tr("Media Controls")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.mediaControls?.enable ?? true
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.mediaControls.enable", checked)
                }
                Item { Layout.fillWidth: true }
                WidgetPlacementSelector {
                    configPath: "background.widgets.mediaControls"
                    configEntry: Config.options?.background?.widgets?.mediaControls
                    defaultStrategy: "leastBusy"
                }
            }

            WidgetZonePicker {
                configPath: "background.widgets.mediaControls"
                configEntry: Config.options?.background?.widgets?.mediaControls
            }

            ContentSubsection {
                title: Translation.tr("Player style")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.mediaControls?.playerPreset ?? "full"
                    onSelected: newValue => Config.setNestedValue("background.widgets.mediaControls.playerPreset", newValue)
                    options: [
                        { displayName: Translation.tr("Full"), icon: "featured_video", value: "full" },
                        { displayName: Translation.tr("Compact"), icon: "view_compact", value: "compact" },
                        { displayName: Translation.tr("Minimal"), icon: "view_headline", value: "minimal" },
                        { displayName: Translation.tr("Album Art"), icon: "image", value: "albumart" },
                        { displayName: Translation.tr("Visualizer"), icon: "equalizer", value: "visualizer" },
                        { displayName: Translation.tr("Classic"), icon: "radio", value: "classic" },
                    ]
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.mediaControls"
                configEntry: Config.options?.background?.widgets?.mediaControls
            }

            RippleButton {
                Layout.fillWidth: true
                text: Translation.tr("Reset to defaults")
                onClicked: {
                    Config.setNestedValue("background.widgets.mediaControls.placementStrategy", "leastBusy");
                    Config.setNestedValue("background.widgets.mediaControls.playerPreset", "full");
                    Config.setNestedValue("background.widgets.mediaControls.widgetScale", 100);
                    Config.setNestedValue("background.widgets.mediaControls.widgetOpacity", 100);
                    Config.setNestedValue("background.widgets.mediaControls.colorMode", "auto");
                    Config.setNestedValue("background.widgets.mediaControls.dim", 0);
                    Config.setNestedValue("background.widgets.mediaControls.x", 100);
                    Config.setNestedValue("background.widgets.mediaControls.y", 100);
                }
            }
        }
    }

    // ── Visualizer ───────────────────────────────────────────
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "equalizer"
        title: Translation.tr("Visualizer")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.visualizer?.enable ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.visualizer.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Audio visualizer widget on the desktop")
                    }
                }
                Item { Layout.fillWidth: true }
                WidgetPlacementSelector {
                    configPath: "background.widgets.visualizer"
                    configEntry: Config.options?.background?.widgets?.visualizer
                    defaultStrategy: "free"
                }
            }

            WidgetZonePicker {
                configPath: "background.widgets.visualizer"
                configEntry: Config.options?.background?.widgets?.visualizer
            }

            ContentSubsection {
                title: Translation.tr("Preset")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.visualizer?.preset ?? "default"
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.visualizer.preset", newValue);
                        if (newValue === "default") {
                            Config.setNestedValue("background.widgets.visualizer.barRadius", 2);
                            Config.setNestedValue("background.widgets.visualizer.barMinHeight", 1);
                            Config.setNestedValue("background.widgets.visualizer.contentWidth", 304);
                            Config.setNestedValue("background.widgets.visualizer.contentHeight", 104);
                            Config.setNestedValue("background.widgets.visualizer.barCount", 48);
                            Config.setNestedValue("background.widgets.visualizer.barSpacing", 2);
                        } else if (newValue === "dense") {
                            Config.setNestedValue("background.widgets.visualizer.barRadius", 1);
                            Config.setNestedValue("background.widgets.visualizer.barMinHeight", 2);
                            Config.setNestedValue("background.widgets.visualizer.contentWidth", 304);
                            Config.setNestedValue("background.widgets.visualizer.contentHeight", 80);
                            Config.setNestedValue("background.widgets.visualizer.barCount", 64);
                            Config.setNestedValue("background.widgets.visualizer.barSpacing", 1);
                        } else if (newValue === "minimal") {
                            Config.setNestedValue("background.widgets.visualizer.barRadius", 4);
                            Config.setNestedValue("background.widgets.visualizer.barMinHeight", 1);
                            Config.setNestedValue("background.widgets.visualizer.contentWidth", 200);
                            Config.setNestedValue("background.widgets.visualizer.contentHeight", 80);
                            Config.setNestedValue("background.widgets.visualizer.barCount", 24);
                            Config.setNestedValue("background.widgets.visualizer.barSpacing", 3);
                        } else if (newValue === "wide") {
                            Config.setNestedValue("background.widgets.visualizer.barRadius", 2);
                            Config.setNestedValue("background.widgets.visualizer.barMinHeight", 1);
                            Config.setNestedValue("background.widgets.visualizer.contentWidth", 480);
                            Config.setNestedValue("background.widgets.visualizer.contentHeight", 120);
                            Config.setNestedValue("background.widgets.visualizer.barCount", 80);
                            Config.setNestedValue("background.widgets.visualizer.barSpacing", 2);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "equalizer", value: "default" },
                        { displayName: Translation.tr("Dense"), icon: "density_small", value: "dense" },
                        { displayName: Translation.tr("Minimal"), icon: "view_headline", value: "minimal" },
                        { displayName: Translation.tr("Wide"), icon: "width_wide", value: "wide" },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Bars")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Bar count"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 8; to: 128; stepSize: 4
                        value: Config.options?.background?.widgets?.visualizer?.barCount ?? 48
                        onValueModified: Config.setNestedValue("background.widgets.visualizer.barCount", value)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Bar spacing"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 8; stepSize: 1
                        value: Config.options?.background?.widgets?.visualizer?.barSpacing ?? 2
                        onValueModified: Config.setNestedValue("background.widgets.visualizer.barSpacing", value)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Bar radius"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 16; stepSize: 1
                        value: Config.options?.background?.widgets?.visualizer?.barRadius ?? 2
                        onValueModified: Config.setNestedValue("background.widgets.visualizer.barRadius", value)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Min height"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 16; stepSize: 1
                        value: Config.options?.background?.widgets?.visualizer?.barMinHeight ?? 1
                        onValueModified: Config.setNestedValue("background.widgets.visualizer.barMinHeight", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dimensions")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Width"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 100; to: 800; stepSize: 20
                        value: Config.options?.background?.widgets?.visualizer?.contentWidth ?? 304
                        onValueModified: Config.setNestedValue("background.widgets.visualizer.contentWidth", value)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Height"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 40; to: 400; stepSize: 10
                        value: Config.options?.background?.widgets?.visualizer?.contentHeight ?? 104
                        onValueModified: Config.setNestedValue("background.widgets.visualizer.contentHeight", value)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.visualizer"
                configEntry: Config.options?.background?.widgets?.visualizer
                hasCardControls: true
            }

            RippleButton {
                Layout.fillWidth: true
                text: Translation.tr("Reset to defaults")
                onClicked: {
                    Config.setNestedValue("background.widgets.visualizer.preset", "default");
                    Config.setNestedValue("background.widgets.visualizer.placementStrategy", "free");
                    Config.setNestedValue("background.widgets.visualizer.barCount", 48);
                    Config.setNestedValue("background.widgets.visualizer.barSpacing", 2);
                    Config.setNestedValue("background.widgets.visualizer.barRadius", 2);
                    Config.setNestedValue("background.widgets.visualizer.barMinHeight", 1);
                    Config.setNestedValue("background.widgets.visualizer.contentWidth", 304);
                    Config.setNestedValue("background.widgets.visualizer.contentHeight", 104);
                    Config.setNestedValue("background.widgets.visualizer.dim", 0);
                    Config.setNestedValue("background.widgets.visualizer.widgetScale", 100);
                    Config.setNestedValue("background.widgets.visualizer.widgetOpacity", 100);
                    Config.setNestedValue("background.widgets.visualizer.showBackground", true);
                    Config.setNestedValue("background.widgets.visualizer.showBorder", true);
                    Config.setNestedValue("background.widgets.visualizer.backgroundOpacity", 0.06);
                    Config.setNestedValue("background.widgets.visualizer.borderWidth", 1);
                    Config.setNestedValue("background.widgets.visualizer.borderOpacity", 0.08);
                    Config.setNestedValue("background.widgets.visualizer.cornerRadius", -1);
                    Config.setNestedValue("background.widgets.visualizer.colorMode", "auto");
                    Config.setNestedValue("background.widgets.visualizer.x", 100);
                    Config.setNestedValue("background.widgets.visualizer.y", 100);
                }
            }
        }
    }

    // ── System Monitor ───────────────────────────────────────
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "monitor_heart"
        title: Translation.tr("System Monitor")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.systemMonitor?.enable ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.systemMonitor.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Show CPU, RAM, and GPU usage on the desktop")
                    }
                }
                Item { Layout.fillWidth: true }
                WidgetPlacementSelector {
                    configPath: "background.widgets.systemMonitor"
                    configEntry: Config.options?.background?.widgets?.systemMonitor
                    defaultStrategy: "free"
                }
            }

            WidgetZonePicker {
                configPath: "background.widgets.systemMonitor"
                configEntry: Config.options?.background?.widgets?.systemMonitor
            }

            ContentSubsection {
                title: Translation.tr("Preset")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.systemMonitor?.preset ?? "default"
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.systemMonitor.preset", newValue);
                        if (newValue === "default") {
                            Config.setNestedValue("background.widgets.systemMonitor.contentWidth", 320);
                            Config.setNestedValue("background.widgets.systemMonitor.contentHeight", 120);
                        } else if (newValue === "compact") {
                            Config.setNestedValue("background.widgets.systemMonitor.contentWidth", 240);
                            Config.setNestedValue("background.widgets.systemMonitor.contentHeight", 80);
                        } else if (newValue === "wide") {
                            Config.setNestedValue("background.widgets.systemMonitor.contentWidth", 480);
                            Config.setNestedValue("background.widgets.systemMonitor.contentHeight", 120);
                        } else if (newValue === "tall") {
                            Config.setNestedValue("background.widgets.systemMonitor.contentWidth", 320);
                            Config.setNestedValue("background.widgets.systemMonitor.contentHeight", 180);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "monitor_heart", value: "default" },
                        { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" },
                        { displayName: Translation.tr("Wide"), icon: "width_wide", value: "wide" },
                        { displayName: Translation.tr("Tall"), icon: "height", value: "tall" },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Display mode")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.systemMonitor?.displayMode ?? "bars"
                    onSelected: newValue => Config.setNestedValue("background.widgets.systemMonitor.displayMode", newValue)
                    options: [
                        { displayName: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { displayName: Translation.tr("Graph"), icon: "show_chart", value: "graph" },
                        { displayName: Translation.tr("Rings"), icon: "radio_button_checked", value: "rings" },
                        { displayName: Translation.tr("Text"), icon: "text_fields", value: "text" },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Resources")

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "memory"
                        text: Translation.tr("CPU")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.systemMonitor?.showCpu ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.systemMonitor.showCpu", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "storage"
                        text: Translation.tr("Memory")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.systemMonitor?.showMemory ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.systemMonitor.showMemory", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "developer_board"
                        text: Translation.tr("GPU")
                        autoToggle: false

                        checked: Config.options?.background?.widgets?.systemMonitor?.showGpu ?? true
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.systemMonitor.showGpu", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "label"
                    text: Translation.tr("Show labels and percentages")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.systemMonitor?.showLabels ?? true
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.systemMonitor.showLabels", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Dimensions")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Width"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 120; to: 800; stepSize: 20
                        value: Config.options?.background?.widgets?.systemMonitor?.contentWidth ?? 320
                        onValueModified: Config.setNestedValue("background.widgets.systemMonitor.contentWidth", value)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Height"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 40; to: 400; stepSize: 10
                        value: Config.options?.background?.widgets?.systemMonitor?.contentHeight ?? 120
                        onValueModified: Config.setNestedValue("background.widgets.systemMonitor.contentHeight", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Style")

                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Track opacity"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSlider {
                        from: 0; to: 0.5; stepSize: 0.02
                        value: Config.options?.background?.widgets?.systemMonitor?.trackAlpha ?? 0.08
                        onMoved: Config.setNestedValue("background.widgets.systemMonitor.trackAlpha", Math.round(value * 100) / 100)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Fill opacity"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSlider {
                        from: 0.1; to: 1; stepSize: 0.05
                        value: Config.options?.background?.widgets?.systemMonitor?.fillOpacity ?? 0.7
                        onMoved: Config.setNestedValue("background.widgets.systemMonitor.fillOpacity", Math.round(value * 100) / 100)
                    }
                }
                ConfigRow {
                    visible: (Config.options?.background?.widgets?.systemMonitor?.displayMode ?? "bars") === "graph"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Graph fill opacity"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSlider {
                        from: 0; to: 1; stepSize: 0.05
                        value: Config.options?.background?.widgets?.systemMonitor?.graphFillOpacity ?? 0.3
                        onMoved: Config.setNestedValue("background.widgets.systemMonitor.graphFillOpacity", Math.round(value * 100) / 100)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.systemMonitor"
                configEntry: Config.options?.background?.widgets?.systemMonitor
                hasCardControls: true
            }

            RippleButton {
                Layout.fillWidth: true
                text: Translation.tr("Reset to defaults")
                onClicked: {
                    Config.setNestedValue("background.widgets.systemMonitor.preset", "default");
                    Config.setNestedValue("background.widgets.systemMonitor.placementStrategy", "free");
                    Config.setNestedValue("background.widgets.systemMonitor.displayMode", "bars");
                    Config.setNestedValue("background.widgets.systemMonitor.showCpu", true);
                    Config.setNestedValue("background.widgets.systemMonitor.showMemory", true);
                    Config.setNestedValue("background.widgets.systemMonitor.showGpu", true);
                    Config.setNestedValue("background.widgets.systemMonitor.showLabels", true);
                    Config.setNestedValue("background.widgets.systemMonitor.contentWidth", 320);
                    Config.setNestedValue("background.widgets.systemMonitor.contentHeight", 120);
                    Config.setNestedValue("background.widgets.systemMonitor.trackAlpha", 0.08);
                    Config.setNestedValue("background.widgets.systemMonitor.fillOpacity", 0.7);
                    Config.setNestedValue("background.widgets.systemMonitor.graphFillOpacity", 0.3);
                    Config.setNestedValue("background.widgets.systemMonitor.dim", 0);
                    Config.setNestedValue("background.widgets.systemMonitor.widgetScale", 100);
                    Config.setNestedValue("background.widgets.systemMonitor.widgetOpacity", 100);
                    Config.setNestedValue("background.widgets.systemMonitor.showBackground", true);
                    Config.setNestedValue("background.widgets.systemMonitor.showBorder", true);
                    Config.setNestedValue("background.widgets.systemMonitor.backgroundOpacity", 0.06);
                    Config.setNestedValue("background.widgets.systemMonitor.borderWidth", 1);
                    Config.setNestedValue("background.widgets.systemMonitor.borderOpacity", 0.08);
                    Config.setNestedValue("background.widgets.systemMonitor.cornerRadius", -1);
                    Config.setNestedValue("background.widgets.systemMonitor.colorMode", "auto");
                    Config.setNestedValue("background.widgets.systemMonitor.x", 50);
                    Config.setNestedValue("background.widgets.systemMonitor.y", 400);
                }
            }
        }
    }

    // ── Battery ──────────────────────────────────────────────
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "battery_full"
        title: Translation.tr("Battery")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                visible: !Battery.available
                text: Translation.tr("No battery detected on this system.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            ConfigRow {
                Layout.fillWidth: true
                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.battery?.enable ?? false
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.battery.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Show battery status on the desktop (only visible on laptops)")
                    }
                }
                Item { Layout.fillWidth: true }
                WidgetPlacementSelector {
                    configPath: "background.widgets.battery"
                    configEntry: Config.options?.background?.widgets?.battery
                    defaultStrategy: "free"
                }
            }

            WidgetZonePicker {
                configPath: "background.widgets.battery"
                configEntry: Config.options?.background?.widgets?.battery
            }

            ContentSubsection {
                title: Translation.tr("Preset")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.battery?.preset ?? "default"
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.battery.preset", newValue);
                        if (newValue === "default") {
                            Config.setNestedValue("background.widgets.battery.ringLineWidth", 6);
                            Config.setNestedValue("background.widgets.battery.barCount", 20);
                            Config.setNestedValue("background.widgets.battery.pillHeight", 12);
                        } else if (newValue === "thin") {
                            Config.setNestedValue("background.widgets.battery.ringLineWidth", 3);
                            Config.setNestedValue("background.widgets.battery.barCount", 20);
                            Config.setNestedValue("background.widgets.battery.pillHeight", 8);
                        } else if (newValue === "thick") {
                            Config.setNestedValue("background.widgets.battery.ringLineWidth", 10);
                            Config.setNestedValue("background.widgets.battery.barCount", 12);
                            Config.setNestedValue("background.widgets.battery.pillHeight", 16);
                        } else if (newValue === "dense") {
                            Config.setNestedValue("background.widgets.battery.ringLineWidth", 6);
                            Config.setNestedValue("background.widgets.battery.barCount", 32);
                            Config.setNestedValue("background.widgets.battery.pillHeight", 12);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "battery_full", value: "default" },
                        { displayName: Translation.tr("Thin"), icon: "remove", value: "thin" },
                        { displayName: Translation.tr("Thick"), icon: "rectangle", value: "thick" },
                        { displayName: Translation.tr("Dense"), icon: "density_small", value: "dense" },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Display")

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.background?.widgets?.battery?.displayMode ?? "ring"
                    onSelected: newValue => Config.setNestedValue("background.widgets.battery.displayMode", newValue)
                    options: [
                        { displayName: Translation.tr("Ring"), icon: "radio_button_checked", value: "ring" },
                        { displayName: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { displayName: Translation.tr("Pill"), icon: "horizontal_rule", value: "pill" },
                    ]
                }

                ConfigRow {
                    visible: (Config.options?.background?.widgets?.battery?.displayMode ?? "ring") === "ring"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Ring size"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 40; to: 120; stepSize: 4
                        value: Config.options?.background?.widgets?.battery?.ringSize ?? 72
                        onValueModified: Config.setNestedValue("background.widgets.battery.ringSize", value)
                    }
                }

                ConfigRow {
                    visible: (Config.options?.background?.widgets?.battery?.displayMode ?? "ring") === "ring"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Line width"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 1; to: 16; stepSize: 1
                        value: Config.options?.background?.widgets?.battery?.ringLineWidth ?? 6
                        onValueModified: Config.setNestedValue("background.widgets.battery.ringLineWidth", value)
                    }
                }

                ConfigRow {
                    visible: (Config.options?.background?.widgets?.battery?.displayMode ?? "ring") === "bars"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Bar count"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 4; to: 48; stepSize: 2
                        value: Config.options?.background?.widgets?.battery?.barCount ?? 20
                        onValueModified: Config.setNestedValue("background.widgets.battery.barCount", value)
                    }
                }
                ConfigRow {
                    visible: (Config.options?.background?.widgets?.battery?.displayMode ?? "ring") === "bars"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Bar spacing"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 8; stepSize: 1
                        value: Config.options?.background?.widgets?.battery?.barSpacing ?? 2
                        onValueModified: Config.setNestedValue("background.widgets.battery.barSpacing", value)
                    }
                }
                ConfigRow {
                    visible: (Config.options?.background?.widgets?.battery?.displayMode ?? "ring") === "bars"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Bar radius"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 0; to: 12; stepSize: 1
                        value: Config.options?.background?.widgets?.battery?.barRadius ?? 2
                        onValueModified: Config.setNestedValue("background.widgets.battery.barRadius", value)
                    }
                }

                ConfigRow {
                    visible: (Config.options?.background?.widgets?.battery?.displayMode ?? "ring") === "pill"
                    Layout.fillWidth: true
                    StyledText { text: Translation.tr("Pill height"); color: Appearance.colors.colOnLayer1 }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        from: 4; to: 32; stepSize: 2
                        value: Config.options?.background?.widgets?.battery?.pillHeight ?? 12
                        onValueModified: Config.setNestedValue("background.widgets.battery.pillHeight", value)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Show time estimate")
                    autoToggle: false

                    checked: Config.options?.background?.widgets?.battery?.showTime ?? true
                    onToggledByUser: checked => Config.setNestedValue("background.widgets.battery.showTime", checked)
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.battery"
                configEntry: Config.options?.background?.widgets?.battery
                hasCardControls: true
            }

            RippleButton {
                Layout.fillWidth: true
                text: Translation.tr("Reset to defaults")
                onClicked: {
                    Config.setNestedValue("background.widgets.battery.preset", "default");
                    Config.setNestedValue("background.widgets.battery.placementStrategy", "free");
                    Config.setNestedValue("background.widgets.battery.displayMode", "ring");
                    Config.setNestedValue("background.widgets.battery.showTime", true);
                    Config.setNestedValue("background.widgets.battery.ringSize", 72);
                    Config.setNestedValue("background.widgets.battery.ringLineWidth", 6);
                    Config.setNestedValue("background.widgets.battery.barCount", 20);
                    Config.setNestedValue("background.widgets.battery.barSpacing", 2);
                    Config.setNestedValue("background.widgets.battery.barRadius", 2);
                    Config.setNestedValue("background.widgets.battery.pillHeight", 12);
                    Config.setNestedValue("background.widgets.battery.dim", 0);
                    Config.setNestedValue("background.widgets.battery.widgetScale", 100);
                    Config.setNestedValue("background.widgets.battery.widgetOpacity", 100);
                    Config.setNestedValue("background.widgets.battery.showBackground", true);
                    Config.setNestedValue("background.widgets.battery.showBorder", true);
                    Config.setNestedValue("background.widgets.battery.backgroundOpacity", 0.06);
                    Config.setNestedValue("background.widgets.battery.borderWidth", 1);
                    Config.setNestedValue("background.widgets.battery.borderOpacity", 0.08);
                    Config.setNestedValue("background.widgets.battery.cornerRadius", -1);
                    Config.setNestedValue("background.widgets.battery.colorMode", "auto");
                    Config.setNestedValue("background.widgets.battery.x", 50);
                    Config.setNestedValue("background.widgets.battery.y", 50);
                }
            }
        }
    }

    // ── Custom Widgets ──────────────────────────────────────
    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "widgets"
        title: Translation.tr("Custom Widgets")

        SettingsGroup {
            // Description
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("QML widgets you create or install. Place widget folders in ~/.config/inir/widgets/ — each needs a widget.json manifest and a .qml file.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            // Action bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Create new
                RippleButton {
                    width: implicitWidth; height: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.20)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                    downAction: () => { _cwCreateRow.visible = !_cwCreateRow.visible }
                    contentItem: Row {
                        anchors.centerIn: parent; spacing: 6; leftPadding: 14; rightPadding: 14
                        MaterialSymbol { text: "add"; iconSize: 18; color: Appearance.colors.colPrimary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: Translation.tr("New"); color: Appearance.colors.colPrimary; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                // Install example
                RippleButton {
                    width: implicitWidth; height: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                    downAction: () => CustomWidgets.installExample()
                    contentItem: Row {
                        anchors.centerIn: parent; spacing: 6; leftPadding: 14; rightPadding: 14
                        MaterialSymbol { text: "download"; iconSize: 18; color: Appearance.colors.colOnLayer1; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: Translation.tr("Example"); color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.small; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledToolTip { text: Translation.tr("Install the built-in example widget to learn from") }
                }

                Item { Layout.fillWidth: true }

                // Open folder
                RippleButton {
                    width: 36; height: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                    downAction: () => CustomWidgets.openWidgetDir("")
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "folder_open"; iconSize: 20; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: Translation.tr("Open widgets folder") }
                }

                // Reload
                RippleButton {
                    width: 36; height: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                    downAction: () => CustomWidgets.reload()
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 20; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: Translation.tr("Scan for new or changed widgets") }
                }
            }

            // Create widget inline form (hidden by default)
            ColumnLayout {
                id: _cwCreateRow
                visible: false
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    MaterialTextField {
                        id: _newWidgetNameField
                        Layout.fillWidth: true
                        height: 40
                        placeholderText: Translation.tr("widget-name (lowercase, dashes)")
                        font.pixelSize: Appearance.font.pixelSize.small
                        validator: RegularExpressionValidator { regularExpression: /[a-z0-9][a-z0-9\-]*/ }
                        onAccepted: {
                            if (text.length > 0) {
                                CustomWidgets.create(text);
                                text = "";
                                _cwCreateRow.visible = false;
                            }
                        }
                    }
                    RippleButton {
                        id: _cwCreateBtn
                        width: implicitWidth; height: 40
                        buttonRadius: Appearance.rounding.full
                        enabled: _newWidgetNameField.text.length > 0
                        opacity: enabled ? 1 : 0.4
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Qt.lighter(Appearance.colors.colPrimary, 1.1)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.24)
                        downAction: () => {
                            if (_newWidgetNameField.text.length > 0) {
                                CustomWidgets.create(_newWidgetNameField.text);
                                _newWidgetNameField.text = "";
                                _cwCreateRow.visible = false;
                            }
                        }
                        contentItem: Row {
                            anchors.centerIn: parent; spacing: 6; leftPadding: 16; rightPadding: 16
                            MaterialSymbol { text: "add"; iconSize: 18; color: Appearance.colors.colOnPrimary; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: Translation.tr("Create"); color: Appearance.colors.colOnPrimary; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Creates a template with all imports, services, and an example layout. Edit the .qml file to customize.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            // Empty state
            ColumnLayout {
                visible: CustomWidgets.ready && CustomWidgets.widgets.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.bottomMargin: 8
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "widgets"
                    iconSize: 40
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.2)
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No custom widgets installed")
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Click 'New' to create one, or 'Example' to install a demo widget")
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.35)
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        // Per-widget cards
        Repeater {
            model: CustomWidgets.ready ? CustomWidgets.widgets : []

            SettingsGroup {
                id: cwDelegate
                required property var modelData
                required property int index

                // Header: enable + name + actions
                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: cwDelegate.modelData.icon || "widgets"
                        text: cwDelegate.modelData.name
                        readonly property bool currentEnabled: Config.customWidgetData?.[cwDelegate.modelData.id]?.enable ?? true
                        autoToggle: false

                        checked: currentEnabled
                        onToggledByUser: checked => Config.setNestedValue("background.widgets.custom." + cwDelegate.modelData.id + ".enable", checked)
                    }
                    Item { Layout.fillWidth: true }
                    WidgetPlacementSelector {
                        configPath: "background.widgets.custom." + cwDelegate.modelData.id
                        configEntry: Config.customWidgetData?.[cwDelegate.modelData.id]
                        defaultStrategy: "free"
                    }
                }

                WidgetZonePicker {
                    configPath: "background.widgets.custom." + cwDelegate.modelData.id
                    configEntry: Config.customWidgetData?.[cwDelegate.modelData.id]
                }

                ContentSubsection {
                    title: Translation.tr("Position")

                    ConfigRow {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Coordinates")
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        Row {
                            spacing: 8
                            StyledSpinBox {
                                from: 0; to: 10000; stepSize: Config.options?.background?.widgets?.editGrid?.size ?? 32
                                value: Config.customWidgetData?.[cwDelegate.modelData.id]?.x ?? (240 + cwDelegate.index * 36)
                                onValueModified: Config.setNestedValue("background.widgets.custom." + cwDelegate.modelData.id + ".x", value)
                                StyledToolTip { text: Translation.tr("X position") }
                            }
                            StyledSpinBox {
                                from: 0; to: 10000; stepSize: Config.options?.background?.widgets?.editGrid?.size ?? 32
                                value: Config.customWidgetData?.[cwDelegate.modelData.id]?.y ?? (240 + cwDelegate.index * 28)
                                onValueModified: Config.setNestedValue("background.widgets.custom." + cwDelegate.modelData.id + ".y", value)
                                StyledToolTip { text: Translation.tr("Y position") }
                            }
                        }
                    }

                    ConfigRow {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Desktop editing")
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        RippleButton {
                            width: implicitWidth; height: 32
                            buttonRadius: Appearance.rounding.full
                            colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                            colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.20)
                            colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                            downAction: () => {
                                Config.setNestedValue("background.widgets.custom." + cwDelegate.modelData.id + ".enable", true);
                                GlobalStates.widgetEditMode = true;
                            }
                            contentItem: Row {
                                anchors.centerIn: parent; spacing: 6; leftPadding: 14; rightPadding: 14
                                MaterialSymbol { text: "drag_pan"; iconSize: 16; color: Appearance.colors.colPrimary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: Translation.tr("Edit on desktop"); color: Appearance.colors.colPrimary; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }

                ContentSubsection {
                    visible: Object.keys(cwDelegate.modelData.resizableAxes || {}).length > 0
                    title: Translation.tr("Size")

                    ConfigRow {
                        visible: (cwDelegate.modelData.resizableAxes || {}).width !== undefined
                        Layout.fillWidth: true
                        StyledText { text: Translation.tr("Width"); color: Appearance.colors.colOnLayer1 }
                        Item { Layout.fillWidth: true }
                        StyledSpinBox {
                            from: 40; to: 2000; stepSize: 10
                            value: CustomWidgets.getConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).width ?? "contentWidth", cwDelegate.modelData.defaultSize?.width ?? 200)
                            onValueModified: CustomWidgets.setConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).width ?? "contentWidth", value)
                        }
                    }

                    ConfigRow {
                        visible: (cwDelegate.modelData.resizableAxes || {}).height !== undefined
                        Layout.fillWidth: true
                        StyledText { text: Translation.tr("Height"); color: Appearance.colors.colOnLayer1 }
                        Item { Layout.fillWidth: true }
                        StyledSpinBox {
                            from: 30; to: 1200; stepSize: 10
                            value: CustomWidgets.getConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).height ?? "contentHeight", cwDelegate.modelData.defaultSize?.height ?? 100)
                            onValueModified: CustomWidgets.setConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).height ?? "contentHeight", value)
                        }
                    }

                    ConfigRow {
                        visible: (cwDelegate.modelData.resizableAxes || {}).uniform !== undefined && (cwDelegate.modelData.resizableAxes || {}).uniform !== "widgetScale"
                        Layout.fillWidth: true
                        StyledText { text: Translation.tr("Size"); color: Appearance.colors.colOnLayer1 }
                        Item { Layout.fillWidth: true }
                        StyledSpinBox {
                            from: 30; to: 2000; stepSize: 10
                            value: CustomWidgets.getConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).uniform ?? "size", cwDelegate.modelData.defaultSize?.width ?? 200)
                            onValueModified: CustomWidgets.setConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).uniform ?? "size", value)
                        }
                    }
                }

                // Meta row: version, author, actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: (cwDelegate.modelData.author ? (cwDelegate.modelData.author + " · ") : "") + "v" + cwDelegate.modelData.version
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    Item { Layout.fillWidth: true }

                    // Edit (open folder)
                    RippleButton {
                        width: 28; height: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                        downAction: () => CustomWidgets.openWidgetDir(cwDelegate.modelData.id)
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "edit"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Open widget folder") }
                    }

                    // Delete
                    RippleButton {
                        width: 28; height: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colError, 0.12)
                        downAction: () => { _cwDeleteConfirm.widgetId = cwDelegate.modelData.id; _cwDeleteConfirm.widgetName = cwDelegate.modelData.name; _cwDeleteConfirm.visible = true }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 16; color: Appearance.colors.colError }
                        StyledToolTip { text: Translation.tr("Remove widget") }
                    }
                }

                // Validation warnings
                NoticeBox {
                    visible: !cwDelegate.modelData.valid
                    Layout.fillWidth: true
                    materialIcon: "warning"
                    text: (cwDelegate.modelData.warnings || []).join("\n")
                }

                // Auto-generated controls from manifest configKeys
                ContentSubsection {
                    visible: Object.keys(cwDelegate.modelData.configKeys || {}).length > 0
                    title: Translation.tr("Settings")

                    Repeater {
                        model: {
                            const keys = cwDelegate.modelData.configKeys || {};
                            return Object.keys(keys).map(k => ({
                                key: k, spec: keys[k],
                                widgetId: cwDelegate.modelData.id
                            }));
                        }

                        ConfigRow {
                            required property var modelData
                            Layout.fillWidth: true
                            StyledText { text: modelData.spec.label || modelData.key; color: Appearance.colors.colOnLayer1 }
                            Item { Layout.fillWidth: true }

                            RippleButton {
                                visible: modelData.spec.type === "bool"
                                readonly property bool currentChecked: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? false)
                                width: 40; height: 28
                                buttonRadius: Appearance.rounding.small
                                toggled: currentChecked
                                colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                                colBackgroundHover: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24) : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                                colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                                downAction: () => CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, !currentChecked)
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: parent.toggled ? "check" : "close"
                                    iconSize: 16
                                    color: parent.toggled ? Appearance.colors.colPrimary : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.55)
                                }
                            }
                            StyledSpinBox {
                                visible: modelData.spec.type === "int"
                                from: modelData.spec.min ?? 0; to: modelData.spec.max ?? 999; stepSize: modelData.spec.step ?? 1
                                value: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? 0)
                                onValueModified: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, value)
                            }
                            StyledSlider {
                                visible: modelData.spec.type === "real"
                                from: modelData.spec.min ?? 0; to: modelData.spec.max ?? 100; stepSize: modelData.spec.step ?? 1
                                value: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? 0)
                                onMoved: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, Math.round(value * 100) / 100)
                            }
                            ConfigSelectionArray {
                                visible: modelData.spec.type === "string" && (modelData.spec.options !== undefined)
                                Layout.fillWidth: false
                                currentValue: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? "")
                                onSelected: newValue => CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, newValue)
                                options: (modelData.spec.options || []).map(o => ({ displayName: o, value: o }))
                            }
                            MaterialTextField {
                                visible: modelData.spec.type === "string" && (modelData.spec.options === undefined)
                                Layout.preferredWidth: 180
                                text: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? "")
                                onAccepted: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, text)
                            }
                        }
                    }
                }

                WidgetAppearanceControls {
                    configPath: "background.widgets.custom." + cwDelegate.modelData.id
                    configEntry: Config.customWidgetData?.[cwDelegate.modelData.id]
                    hasCardControls: true
                }
            }
        }
    }

    // Delete confirmation overlay (shared for all custom widgets)
    Rectangle {
        id: _cwDeleteConfirm
        property string widgetId: ""
        property string widgetName: ""
        visible: false
        Layout.fillWidth: true
        implicitHeight: _delCol.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.08)
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.2)

        ColumnLayout {
            id: _delCol
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Remove '%1'? This deletes the widget folder permanently.").arg(_cwDeleteConfirm.widgetName)
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                RippleButton {
                    width: implicitWidth; height: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                    downAction: () => { _cwDeleteConfirm.visible = false }
                    contentItem: StyledText {
                        anchors.centerIn: parent; leftPadding: 16; rightPadding: 16
                        text: Translation.tr("Cancel")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
                RippleButton {
                    width: implicitWidth; height: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colError
                    colBackgroundHover: Qt.lighter(Appearance.colors.colError, 1.1)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnError, 0.24)
                    downAction: () => {
                        CustomWidgets.remove(_cwDeleteConfirm.widgetId);
                        _cwDeleteConfirm.visible = false;
                    }
                    contentItem: Row {
                        anchors.centerIn: parent; spacing: 6; leftPadding: 16; rightPadding: 16
                        MaterialSymbol { text: "delete"; iconSize: 16; color: Appearance.colors.colOnError; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: Translation.tr("Delete"); color: Appearance.colors.colOnError; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
