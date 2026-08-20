import QtQuick
import Quickshell.Io
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    settingsPageIndex: 1
    settingsPageName: Translation.tr("System")

    Process {
        id: translationProc
        property string locale: ""
        command: [Directories.aiTranslationScriptPath, translationProc.locale]
    }

    SettingsCardSection {
        expanded: true
        icon: "volume_up"
        title: Translation.tr("Audio")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "hearing"
                text: Translation.tr("Earbang protection")
                checked: Config.options?.audio?.protection?.enable ?? false
                onCheckedChanged: {
                    Config.setNestedValue("audio.protection.enable", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Prevents abrupt increments and restricts volume limit")
                }
            }

            SettingsDivider {}

            ConfigRow {
                enabled: Config.options?.audio?.protection?.enable ?? false
                ConfigSpinBox {
                    icon: "arrow_warm_up"
                    text: Translation.tr("Max allowed increase")
                    value: Config.options?.audio?.protection?.maxAllowedIncrease ?? 0
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.setNestedValue("audio.protection.maxAllowedIncrease", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Maximum volume increase per key press")
                    }
                }
                ConfigSpinBox {
                    icon: "vertical_align_top"
                    text: Translation.tr("Volume limit")
                    value: Config.options?.audio?.protection?.maxAllowed ?? 0
                    from: 0
                    to: 154 // pavucontrol allows up to 153%
                    stepSize: 2
                    onValueChanged: {
                        Config.setNestedValue("audio.protection.maxAllowed", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Maximum volume percentage (pavucontrol allows up to 153%)")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "battery_android_full"
        title: Translation.tr("Battery")

        SettingsGroup {
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "warning"
                    text: Translation.tr("Low warning")
                    value: Config.options?.battery?.low ?? 0
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("battery.low", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show warning notification when battery drops below this level")
                    }
                }
                ConfigSpinBox {
                    icon: "dangerous"
                    text: Translation.tr("Critical warning")
                    value: Config.options?.battery?.critical ?? 0
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("battery.critical", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show critical warning when battery drops below this level")
                    }
                }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: false
                Layout.fillWidth: false
                SettingsSwitch {
                    buttonIcon: "pause"
                    text: Translation.tr("Automatic suspend")
                    checked: Config.options?.battery?.automaticSuspend ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("battery.automaticSuspend", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Automatically suspends the system when battery is low")
                    }
                }
                ConfigSpinBox {
                    enabled: Config.options?.battery?.automaticSuspend ?? false
                    text: Translation.tr("at")
                    value: Config.options?.battery?.suspend ?? 0
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("battery.suspend", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Percentage of battery to trigger suspend")
                    }
                }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "charger"
                    text: Translation.tr("Full warning")
                    value: Config.options?.battery?.full ?? 0
                    from: 0
                    to: 101
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("battery.full", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Notify when battery reaches this level while charging (101 = disabled)")
                    }
                }
            }

            SettingsDivider {}

            ConfigRow {
                enabled: Battery.chargeLimitSupported
                uniform: false
                Layout.fillWidth: false
                SettingsSwitch {
                    buttonIcon: "battery_saver"
                    text: Translation.tr("Charge limit")
                    checked: Config.options?.battery?.chargeLimit?.enable ?? false
                    autoToggle: false
                    onToggledByUser: checked => Config.setNestedValue("battery.chargeLimit.enable", checked)
                    StyledToolTip {
                        text: !Battery.chargeLimitSupported
                            ? Translation.tr("Not supported on this device")
                            : Battery.chargeLimitAdjustable
                                ? Translation.tr("Stop charging at a specific percentage to extend battery lifespan (requires polkit)")
                                : Translation.tr("Use your device's built-in battery conservation mode (requires polkit)")
                    }
                }
                ConfigSpinBox {
                    property bool _ready: false
                    visible: Battery.chargeLimitAdjustable
                    enabled: (Config.options?.battery?.chargeLimit?.enable ?? false) && Battery.chargeLimitAdjustable
                    icon: "speed"
                    text: Translation.tr("at")
                    value: Config.options?.battery?.chargeLimit?.threshold ?? 80
                    from: 20
                    to: 100
                    stepSize: 5
                    Component.onCompleted: _ready = true
                    onValueChanged: {
                        if (_ready && value !== (Config.options?.battery?.chargeLimit?.threshold ?? 80))
                            Config.setNestedValue("battery.chargeLimit.threshold", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Maximum charge percentage")
                    }
                }
            }

            StyledText {
                visible: Battery.chargeLimitSupported
                Layout.leftMargin: 16
                text: Battery.chargeLimitActive
                    ? (Battery.currentChargeLimit > 0 && Battery.currentChargeLimit < 100
                        ? Translation.tr("Current limit: %1%").arg(Battery.currentChargeLimit)
                        : Translation.tr("Battery conservation mode active"))
                    : Translation.tr("No charge limit active")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
    
    SettingsCardSection {
        expanded: false
        icon: "language"
        title: Translation.tr("Language")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Interface Language")
                tooltip: Translation.tr("Select the language for the user interface.\n\"Auto\" will use your system's locale.")

                ConfigSelectionArray {
                    id: languageSelector
                    currentValue: Config.options?.language?.ui ?? "auto"
                    onSelected: newValue => {
                        Config.setNestedValue("language.ui", newValue);
                    }
                    options: [
                        {
                            displayName: Translation.tr("Auto (System)"),
                            value: "auto"
                        },
                        ...Translation.allAvailableLanguages.map(lang => {
                            return {
                                displayName: lang,
                                value: lang
                            };
                        })
                    ]
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Generate translation with Gemini")
                tooltip: Translation.tr("Needs a Gemini API key — type /key in the sidebar.")
                
                ConfigRow {
                    MaterialTextArea {
                        id: localeInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Locale code, e.g. fr_FR, de_DE, zh_CN...")
                        text: (Config.options?.language?.ui ?? "auto") === "auto" ? Qt.locale().name : (Config.options?.language?.ui ?? "auto")
                    }
                    RippleButtonWithIcon {
                        id: generateTranslationBtn
                        Layout.fillHeight: true
                        nerdIcon: ""
                        enabled: !translationProc.running || (translationProc.locale !== localeInput.text.trim())
                        mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")
                        onClicked: {
                            translationProc.locale = localeInput.text.trim();
                            translationProc.running = false;
                            translationProc.running = true;
                        }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: false
        icon: "rule"
        title: Translation.tr("Policies")

        SettingsGroup {
            ConfigRow {
                Layout.alignment: Qt.AlignTop
                
                ContentSubsection {
                    title: Translation.tr("AI")
                    tooltip: Translation.tr("Control AI features availability")
                    ConfigSelectionArray {
                        currentValue: Config.options?.policies?.ai ?? 0
                        onSelected: newValue => {
                            Config.setNestedValue("policies.ai", newValue);
                        }
                        options: [
                            { displayName: Translation.tr("No"), icon: "close", value: 0 },
                            { displayName: Translation.tr("Yes"), icon: "check", value: 1 },
                            { displayName: Translation.tr("Local only"), icon: "sync_saved_locally", value: 2 }
                        ]
                    }
                }
                
                ContentSubsection {
                    title: Translation.tr("Weeb")
                    tooltip: Translation.tr("Control anime content visibility")
                    ConfigSelectionArray {
                        currentValue: Config.options?.policies?.weeb ?? 0
                        onSelected: newValue => {
                            Config.setNestedValue("policies.weeb", newValue);
                        }
                        options: [
                            { displayName: Translation.tr("No"), icon: "close", value: 0 },
                            { displayName: Translation.tr("Yes"), icon: "check", value: 1 },
                            { displayName: Translation.tr("Closet"), icon: "ev_shadow", value: 2 }
                        ]
                    }
                }
            }
        }
    }

    SettingsCardSection {
        id: soundsSection
        expanded: false
        icon: "notification_sound"
        title: Translation.tr("Sounds")

        // One row per shell sound event (keys match Audio.soundEvents)
        readonly property var soundEventRows: [
            { key: "notification", label: Translation.tr("Notification") },
            { key: "notificationCritical", label: Translation.tr("Critical notification") },
            { key: "batteryLow", label: Translation.tr("Battery low") },
            { key: "batteryCritical", label: Translation.tr("Battery critical") },
            { key: "batteryFull", label: Translation.tr("Battery full") },
            { key: "powerPlug", label: Translation.tr("Power plugged in") },
            { key: "powerUnplug", label: Translation.tr("Power unplugged") },
            { key: "pomodoroDone", label: Translation.tr("Pomodoro ends") },
            { key: "timerDone", label: Translation.tr("Timer ends") }
        ]

        SettingsGroup {
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "battery_android_full"
                    text: Translation.tr("Battery")
                    checked: Config.options?.sounds?.battery ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("sounds.battery", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Play sound for battery warnings")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "hourglass_empty"
                    text: Translation.tr("Timer")
                    checked: Config.options?.sounds?.timer ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("sounds.timer", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Play sound when countdown timer ends")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "av_timer"
                    text: Translation.tr("Pomodoro")
                    checked: Config.options?.sounds?.pomodoro ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("sounds.pomodoro", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Play sound when pomodoro timer ends")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "notifications"
                    text: Translation.tr("Notifications")
                    checked: Config.options?.sounds?.notifications ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("sounds.notifications", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Play sound for incoming notifications")
                    }
                }
            }
        }

        SettingsGroup {
            StyledText {
                text: Translation.tr("Volume")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                stepSize: 0.05
                value: Config.options?.sounds?.volume ?? 0.5
                configuration: StyledSlider.Configuration.S
                settingsSearchLabel: Translation.tr("Sound volume")
                settingsSearchKeywords: ["sound", "volume", "audio", "event"]
                onPressedChanged: {
                    if (!pressed) Config.setNestedValue("sounds.volume", value)
                }
            }
        }

        SettingsGroup {
            StyledText {
                text: Translation.tr("Event sounds")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Pick the sound each event plays: one from your sound theme, or any audio file")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            Repeater {
                model: soundsSection.soundEventRows
                delegate: SoundPicker {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.label
                    eventId: modelData.key
                }
            }
        }
    }
    
    SettingsCardSection {
        expanded: false
        icon: "nest_clock_farsight_analog"
        title: Translation.tr("Time")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "pace"
                text: Translation.tr("Second precision")
                checked: Config.options?.time?.secondPrecision ?? false
                onCheckedChanged: {
                    Config.setNestedValue("time.secondPrecision", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Enable if you want clocks to show seconds accurately")
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Format")
                tooltip: Translation.tr("Choose between 12-hour and 24-hour clock formats")

                ConfigSelectionArray {
                    currentValue: Config.options?.time?.format ?? "hh:mm"
                    onSelected: newValue => {
                        Config.setNestedValue("time.format", newValue);
                    }
                    options: [
                        {
                            displayName: Translation.tr("24h"),
                            value: "hh:mm"
                        },
                        {
                            displayName: Translation.tr("12h am/pm"),
                            value: "h:mm ap"
                        },
                        {
                            displayName: Translation.tr("12h AM/PM"),
                            value: "h:mm AP"
                        },
                    ]
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Date formats")
                tooltip: Translation.tr("Customize how dates are shown across the shell")

                ContentSubsectionLabel {
                    text: Translation.tr("Long date format")
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. dddd, MMMM dd")
                    text: Config.options?.time?.dateFormat ?? "ddd, dd/MM"
                    onEditingFinished: Config.setNestedValue("time.dateFormat", text)
                }

                ContentSubsectionLabel {
                    text: Translation.tr("Short date format")
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. dd/MM")
                    text: Config.options?.time?.shortDateFormat ?? "dd/MM"
                    onEditingFinished: Config.setNestedValue("time.shortDateFormat", text)
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "keyboard"
        title: Translation.tr("Keyboard")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Keyboard popups")
                checked: Config.options?.keyboardIndicators?.showPopup ?? true
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.showPopup", checked)
                StyledToolTip {
                    text: Translation.tr("Show a popup when Caps Lock, Num Lock, or the keyboard layout changes")
                }
            }

            SettingsSwitch {
                buttonIcon: "language"
                text: Translation.tr("Layout popup")
                checked: Config.options?.keyboardIndicators?.popup?.layout ?? true
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.popup.layout", checked)
                StyledToolTip {
                    text: Translation.tr("Show a popup when the keyboard layout changes")
                }
            }

            SettingsSwitch {
                buttonIcon: "keyboard_capslock"
                text: Translation.tr("Caps Lock popup")
                checked: Config.options?.keyboardIndicators?.popup?.caps ?? true
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.popup.caps", checked)
                StyledToolTip {
                    text: Translation.tr("Show a popup when Caps Lock changes")
                }
            }

            SettingsSwitch {
                buttonIcon: "dialpad"
                text: Translation.tr("Num Lock popup")
                checked: Config.options?.keyboardIndicators?.popup?.num ?? false
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.popup.num", checked)
                StyledToolTip {
                    text: Translation.tr("Show a popup when Num Lock changes")
                }
            }

            SettingsSwitch {
                buttonIcon: "dock_to_right"
                text: Translation.tr("Keyboard panel indicators")
                checked: Config.options?.keyboardIndicators?.showPanel ?? true
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.showPanel", checked)
                StyledToolTip {
                    text: Translation.tr("Show layout and lock state indicators in the bar or taskbar")
                }
            }

            SettingsSwitch {
                buttonIcon: "language"
                text: Translation.tr("Layout indicator")
                checked: Config.options?.keyboardIndicators?.panel?.layout ?? true
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.panel.layout", checked)
                StyledToolTip {
                    text: Translation.tr("Show the current keyboard layout in the bar or taskbar")
                }
            }

            SettingsSwitch {
                buttonIcon: "keyboard_capslock"
                text: Translation.tr("Caps Lock indicator")
                checked: Config.options?.keyboardIndicators?.panel?.caps ?? true
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.panel.caps", checked)
                StyledToolTip {
                    text: Translation.tr("Show Caps Lock in the bar or taskbar")
                }
            }

            SettingsSwitch {
                buttonIcon: "dialpad"
                text: Translation.tr("Num Lock indicator")
                checked: Config.options?.keyboardIndicators?.panel?.num ?? false
                onCheckedChanged: Config.setNestedValue("keyboardIndicators.panel.num", checked)
                StyledToolTip {
                    text: Translation.tr("Show Num Lock in the bar or taskbar")
                }
            }
        }
    }

    SettingsCardSection {
        visible: !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: false
        icon: "select_window"
        title: Translation.tr("Window Management")

        SettingsGroup {
            SettingsSwitch {
                visible: CompositorService.isNiri
                buttonIcon: "help"
                text: Translation.tr("Confirm before closing windows")
                checked: Config.options?.closeConfirm?.enabled ?? false
                onCheckedChanged: {
                    Config.setNestedValue("closeConfirm.enabled", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Show a confirmation dialog when pressing Super+Q")
                }
            }
        }
    }

    SettingsCardSection {
        visible: !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: false
        icon: "work_alert"
        title: Translation.tr("Work safety")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "assignment"
                text: Translation.tr("Hide clipboard images copied from sussy sources")
                checked: Config.options?.workSafety?.enable?.clipboard ?? false
                onCheckedChanged: {
                    Config.setNestedValue("workSafety.enable.clipboard", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Blur clipboard preview for images from anime/NSFW sites")
                }
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "wallpaper"
                text: Translation.tr("Hide sussy/anime wallpapers")
                checked: Config.options?.workSafety?.enable?.wallpaper ?? false
                onCheckedChanged: {
                    Config.setNestedValue("workSafety.enable.wallpaper", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Replace anime wallpapers with a solid color when enabled")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "waving_hand"
        title: Translation.tr("Boot greeting")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "waving_hand"
                text: Translation.tr("Show greeting on startup")
                checked: Config.options?.bootGreeting?.enable ?? true
                onCheckedChanged: {
                    Config.setNestedValue("bootGreeting.enable", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Display a fullscreen welcome screen with clock and weather when the shell starts")
                }
            }

            SettingsDivider {}

            ConfigSpinBox {
                enabled: Config.options?.bootGreeting?.enable ?? true
                icon: "timer"
                text: Translation.tr("Auto-dismiss delay (ms)")
                value: Config.options?.bootGreeting?.autoDismissDelay ?? 5000
                from: 2000
                to: 15000
                stepSize: 500
                onValueChanged: {
                    Config.setNestedValue("bootGreeting.autoDismissDelay", value);
                }
                StyledToolTip {
                    text: Translation.tr("How long to show the greeting before it fades out automatically")
                }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    enabled: Config.options?.bootGreeting?.enable ?? true
                    buttonIcon: "thermostat"
                    text: Translation.tr("Show weather")
                    checked: Config.options?.bootGreeting?.showWeather ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("bootGreeting.showWeather", checked);
                    }
                }
                SettingsSwitch {
                    enabled: Config.options?.bootGreeting?.enable ?? true
                    buttonIcon: "calendar_today"
                    text: Translation.tr("Show date")
                    checked: Config.options?.bootGreeting?.showDate ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("bootGreeting.showDate", checked);
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "lock"
        title: Translation.tr("Lock screen")

        SettingsGroup {
            SettingsSwitch {
                visible: CompositorService.isHyprland
                buttonIcon: "water_drop"
                text: Translation.tr('Use Hyprlock (instead of Quickshell)')
                checked: Config.options?.lock?.useHyprlock ?? false
                onCheckedChanged: {
                    Config.setNestedValue("lock.useHyprlock", checked);
                }
                StyledToolTip {
                    text: Translation.tr("If you want to somehow use fingerprint unlock...")
                }
            }

            SettingsSwitch {
                buttonIcon: "account_circle"
                text: Translation.tr('Launch on startup')
                checked: Config.options?.lock?.launchOnStartup ?? false
                onCheckedChanged: {
                    Config.setNestedValue("lock.launchOnStartup", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Enable this if you want to use Quickshell as your lock screen provider")
                }
            }

            ContentSubsection {
                title: Translation.tr("Security")

                SettingsSwitch {
                    buttonIcon: "settings_power"
                    text: Translation.tr('Require password to power off/restart')
                    checked: Config.options?.lock?.security?.requirePasswordToPower ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("lock.security.requirePasswordToPower", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Guards against accidents only — holding the power button still forces a shutdown.")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "key_vertical"
                    text: Translation.tr('Also unlock keyring')
                    checked: Config.options?.lock?.security?.unlockKeyring ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("lock.security.unlockKeyring", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Safe, and needed by your browser and the AI sidebar. Mostly for lock-on-startup setups.")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Style: general")

                SettingsSwitch {
                    buttonIcon: "notifications"
                    text: Translation.tr('Show notifications on lock screen')
                    checked: Config.options?.lock?.notifications?.enable ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("lock.notifications.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Display recent notifications on the lock screen clock view")
                    }
                }

                SettingsSwitch {
                    visible: Config.options?.lock?.notifications?.enable ?? false
                    buttonIcon: "visibility"
                    text: Translation.tr('Show notification body text')
                    checked: Config.options?.lock?.notifications?.showBody ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("lock.notifications.showBody", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Display the message content of notifications. Disable for privacy.")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.lock?.notifications?.enable ?? false
                    icon: "format_list_numbered"
                    text: Translation.tr("Max notifications shown")
                    value: Config.options?.lock?.notifications?.maxCount ?? 3
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("lock.notifications.maxCount", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Maximum number of notifications to display on the lock screen")
                    }
                }
            }

            ContentSubsection {
                visible: Config.options?.lock?.notifications?.enable ?? false
                title: Translation.tr("Notification position")
                tooltip: Translation.tr("Auto centres on Material, right-aligns on Waffle.")

                ConfigSelectionArray {
                    currentValue: Config.options?.lock?.notifications?.position ?? "auto"
                    options: [
                        { displayName: Translation.tr("Auto"), value: "auto" },
                        { displayName: Translation.tr("Center"), value: "center" },
                        { displayName: Translation.tr("Left"), value: "left" },
                        { displayName: Translation.tr("Right"), value: "right" }
                    ]
                    onSelected: (newValue) => Config.setNestedValue("lock.notifications.position", newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock style")
                tooltip: Translation.tr("Visual style for the lock screen clock")

                ConfigSelectionArray {
                    currentValue: Config.options?.lock?.clock?.style ?? "default"
                    options: [
                        { displayName: Translation.tr("Default"), value: "default" },
                        { displayName: Translation.tr("Minimal"), value: "minimal" },
                        { displayName: Translation.tr("Analog"), value: "analog" }
                    ]
                    onSelected: (newValue) => Config.setNestedValue("lock.clock.style", newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock position")
                tooltip: Translation.tr("Where the clock appears on the lock screen")

                ConfigSelectionArray {
                    currentValue: Config.options?.lock?.clock?.position ?? "center"
                    options: [
                        { displayName: Translation.tr("Center"), value: "center" },
                        { displayName: Translation.tr("Top Left"), value: "topLeft" },
                        { displayName: Translation.tr("Bottom Left"), value: "bottomLeft" }
                    ]
                    onSelected: (newValue) => Config.setNestedValue("lock.clock.position", newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Extras")

                SettingsSwitch {
                    buttonIcon: "info"
                    text: Translation.tr('Show status indicators')
                    checked: Config.options?.lock?.status?.enable ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("lock.status.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show WiFi, Bluetooth, volume and battery indicators on the lock screen")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "brightness_6"
                    text: Translation.tr('Dim wallpaper')
                    checked: Config.options?.lock?.dim?.enable ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("lock.dim.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply a dark overlay to the wallpaper for better contrast on the lock screen")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.lock?.dim?.enable ?? false
                    text: Translation.tr("Dim amount")
                    icon: "opacity"
                    value: Math.round((Config.options?.lock?.dim?.opacity ?? 0.3) * 100)
                    from: 10
                    to: 80
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("lock.dim.opacity", value / 100)
                    StyledToolTip {
                        text: Translation.tr("How much to dim the wallpaper (percentage)")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "center_focus_weak"
                    text: Translation.tr('Center clock')
                    checked: Config.options?.lock?.centerClock ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("lock.centerClock", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Align the lock screen clock to the center instead of following layout rules")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "info"
                    text: Translation.tr('Show "Locked" text')
                    checked: Config.options?.lock?.showLockedText ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("lock.showLockedText", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Display a 'Locked' label on the lock screen")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "shapes"
                    text: Translation.tr('Use varying shapes for password characters')
                    checked: Config.options?.lock?.materialShapeChars ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("lock.materialShapeChars", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show different geometric shapes instead of bullets for password input")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "play_circle"
                    text: Translation.tr("Animate video/GIF wallpapers")
                    checked: Config.options?.lock?.enableAnimation ?? false
                    onCheckedChanged: Config.setNestedValue("lock.enableAnimation", checked)
                    StyledToolTip {
                        text: Translation.tr("Animated wallpapers on the lock screen. Costs GPU and battery.")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Widgets")

                SettingsSwitch {
                    buttonIcon: "thermostat"
                    text: Translation.tr("Weather")
                    checked: Config.options?.lock?.widgets?.weather ?? true
                    onCheckedChanged: Config.setNestedValue("lock.widgets.weather", checked)
                }

                SettingsSwitch {
                    buttonIcon: "music_note"
                    text: Translation.tr("Media player")
                    checked: Config.options?.lock?.widgets?.media ?? true
                    onCheckedChanged: Config.setNestedValue("lock.widgets.media", checked)
                }

                SettingsSwitch {
                    buttonIcon: "power_settings_new"
                    text: Translation.tr("Power buttons")
                    checked: Config.options?.lock?.widgets?.powerButtons ?? true
                    onCheckedChanged: Config.setNestedValue("lock.widgets.powerButtons", checked)
                }

                SettingsSwitch {
                    buttonIcon: "touch_app"
                    text: Translation.tr("Unlock hint text")
                    checked: Config.options?.lock?.widgets?.hintText ?? true
                    onCheckedChanged: Config.setNestedValue("lock.widgets.hintText", checked)
                }
            }
            ContentSubsection {
                title: Translation.tr("Style: Blurred")

                SettingsSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr('Enable blur')
                    checked: Config.options?.lock?.blur?.enable ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("lock.blur.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply blur effect to the lock screen background")
                    }
                }

                ConfigSpinBox {
                    icon: "blur_linear"
                    text: Translation.tr("Blur radius")
                    value: Config.options?.lock?.blur?.radius ?? 100
                    from: 0
                    to: 200
                    stepSize: 10
                    onValueChanged: {
                        Config.setNestedValue("lock.blur.radius", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Intensity of the blur effect")
                    }
                }

                ConfigSpinBox {
                    icon: "loupe"
                    text: Translation.tr("Extra wallpaper zoom (%)")
                    value: (Config.options?.lock?.blur?.extraZoom ?? 1.1) * 100
                    from: 1
                    to: 150
                    stepSize: 2
                    onValueChanged: {
                        Config.setNestedValue("lock.blur.extraZoom", value / 100);
                    }
                    StyledToolTip {
                        text: Translation.tr("Zoom level for the background wallpaper when blur is enabled")
                    }
                }
            }
        }
    }
}
