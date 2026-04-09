import QtQuick
import Quickshell
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
        icon: "devices"
        title: Translation.tr("Displays")

        SettingsGroup {
            // Connected monitors info
            Repeater {
                model: Quickshell.screens

                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property string screenName: modelData.name ?? ""
                    readonly property int screenW: modelData.width ?? 0
                    readonly property int screenH: modelData.height ?? 0
                    Layout.fillWidth: true
                    implicitHeight: monitorRow.implicitHeight + 4

                    RowLayout {
                        id: monitorRow
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 8; rightMargin: 8
                        }
                        spacing: 10

                        MaterialSymbol {
                            text: "monitor"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: screenName || ("Monitor " + (index + 1))
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: screenW + "×" + screenH
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Primary monitor")
                tooltip: Translation.tr("Choose which monitor is used as the default for popups like wallpaper selector, OSD, and notifications when the focused screen can't be detected.")

                ConfigSelectionArray {
                    currentValue: Config.options?.display?.primaryMonitor ?? ""
                    onSelected: newValue => {
                        Config.setNestedValue("display.primaryMonitor", newValue)
                    }
                    options: {
                        let opts = [{ displayName: Translation.tr("Auto (first available)"), icon: "auto_mode", value: "" }]
                        const screens = Quickshell.screens
                        for (let i = 0; i < screens.length; i++) {
                            const name = screens[i].name ?? ""
                            if (name.length > 0) {
                                opts.push({
                                    displayName: name,
                                    icon: "monitor",
                                    value: name
                                })
                            }
                        }
                        return opts
                    }
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Bar visibility")
                tooltip: Translation.tr("Choose which monitors show the bar. All enabled = shown everywhere.")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: Quickshell.screens

                        SettingsSwitch {
                            required property var modelData
                            required property int index
                            readonly property string screenName: modelData.name ?? ""
                            Layout.fillWidth: true
                            buttonIcon: "web_asset"
                            text: screenName || ("Monitor " + (index + 1))
                            checked: {
                                const list = Config.options?.bar?.screenList ?? []
                                return list.length === 0 || list.includes(screenName)
                            }
                            onCheckedChanged: {
                                const screens = Quickshell.screens
                                let current = [...(Config.options?.bar?.screenList ?? [])]
                                const allNames = screens.map(s => s?.name ?? "").filter(n => n.length > 0)
                                current = current.filter(n => allNames.includes(n))
                                if (current.length === 0 && !checked) {
                                    current = allNames
                                }
                                if (checked && !current.includes(screenName)) {
                                    current.push(screenName)
                                } else if (!checked) {
                                    current = current.filter(n => n !== screenName)
                                }
                                if (allNames.length > 0 && allNames.every(n => current.includes(n))) {
                                    current = []
                                }
                                Config.setNestedValue("bar.screenList", current)
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dock visibility")
                tooltip: Translation.tr("Choose which monitors show the dock. All enabled = shown everywhere.")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: Quickshell.screens

                        SettingsSwitch {
                            required property var modelData
                            required property int index
                            readonly property string screenName: modelData.name ?? ""
                            Layout.fillWidth: true
                            buttonIcon: "call_to_action"
                            text: screenName || ("Monitor " + (index + 1))
                            checked: {
                                const list = Config.options?.dock?.screenList ?? []
                                return list.length === 0 || list.includes(screenName)
                            }
                            onCheckedChanged: {
                                const screens = Quickshell.screens
                                let current = [...(Config.options?.dock?.screenList ?? [])]
                                const allNames = screens.map(s => s?.name ?? "").filter(n => n.length > 0)
                                current = current.filter(n => allNames.includes(n))
                                if (current.length === 0 && !checked) {
                                    current = allNames
                                }
                                if (checked && !current.includes(screenName)) {
                                    current.push(screenName)
                                } else if (!checked) {
                                    current = current.filter(n => n !== screenName)
                                }
                                if (allNames.length > 0 && allNames.every(n => current.includes(n))) {
                                    current = []
                                }
                                Config.setNestedValue("dock.screenList", current)
                            }
                        }
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
                    onCheckedChanged: {
                        Config.setNestedValue("battery.chargeLimit.enable", checked);
                    }
                    StyledToolTip {
                        text: !Battery.chargeLimitSupported
                            ? Translation.tr("Not supported on this device")
                            : Battery.chargeLimitAdjustable
                                ? Translation.tr("Stop charging at a specific percentage to extend battery lifespan (requires polkit)")
                                : Translation.tr("Use your device's built-in battery conservation mode (requires polkit)")
                    }
                }
                ConfigSpinBox {
                    visible: Battery.chargeLimitAdjustable
                    enabled: (Config.options?.battery?.chargeLimit?.enable ?? false) && Battery.chargeLimitAdjustable
                    icon: "speed"
                    text: Translation.tr("at")
                    value: Config.options?.battery?.chargeLimit?.threshold ?? 80
                    from: 20
                    to: 100
                    stepSize: 5
                    onValueChanged: {
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
                tooltip: Translation.tr("You'll need to enter your Gemini API key first.\nType /key on the sidebar for instructions.")
                
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
        expanded: false
        icon: "notification_sound"
        title: Translation.tr("Sounds")
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
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "select_window"
        title: Translation.tr("Window Management")

        SettingsGroup {
            SettingsSwitch {
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
                        text: Translation.tr("Remember that on most devices one can always hold the power button to force shutdown\nThis only makes it a tiny bit harder for accidents to happen")
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
                        text: Translation.tr("This is usually safe and needed for your browser and AI sidebar anyway\nMostly useful for those who use lock on startup instead of a display manager that does it (GDM, SDDM, etc.)")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Style: general")

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
                        text: Translation.tr("Play video and GIF wallpapers on the lock screen instead of showing a still frame. May increase GPU/battery usage.")
                    }
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
