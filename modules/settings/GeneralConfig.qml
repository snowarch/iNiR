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
    settingsPageName: Translation.tr("General")

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
                                if (current.length === 0 && !checked) {
                                    current = screens.map(s => s.name).filter(Boolean)
                                }
                                if (checked && !current.includes(screenName)) {
                                    current.push(screenName)
                                } else if (!checked) {
                                    current = current.filter(n => n !== screenName)
                                }
                                const allNames = screens.map(s => s.name).filter(Boolean)
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
                                if (current.length === 0 && !checked) {
                                    current = screens.map(s => s.name).filter(Boolean)
                                }
                                if (checked && !current.includes(screenName)) {
                                    current.push(screenName)
                                } else if (!checked) {
                                    current = current.filter(n => n !== screenName)
                                }
                                const allNames = screens.map(s => s.name).filter(Boolean)
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
}
