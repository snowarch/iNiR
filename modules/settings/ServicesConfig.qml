import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true
    settingsPageIndex: 6
    settingsPageName: Translation.tr("Services")

    SettingsCardSection {
        expanded: true
        icon: "bedtime"
        title: Translation.tr("Idle & Sleep")

        SettingsGroup {
            ConfigSpinBox {
                icon: "monitor"
                text: Translation.tr("Screen off") + ` (${value > 0 ? Math.floor(value/60) + "m " + (value%60) + "s" : Translation.tr("disabled")})`
                value: Config.options.idle.screenOffTimeout
                from: 0
                to: 3600
                stepSize: 30
                onValueChanged: Config.options.idle.screenOffTimeout = value
                StyledToolTip {
                    text: Translation.tr("Turn off display after this many seconds of inactivity (0 = never)")
                }
            }

            ConfigSpinBox {
                icon: "lock"
                text: Translation.tr("Lock screen") + ` (${value > 0 ? Math.floor(value/60) + "m" : Translation.tr("disabled")})`
                value: Config.options.idle.lockTimeout
                from: 0
                to: 3600
                stepSize: 60
                onValueChanged: Config.options.idle.lockTimeout = value
                StyledToolTip {
                    text: Translation.tr("Lock screen after this many seconds of inactivity (0 = never)")
                }
            }

            ConfigSpinBox {
                icon: "dark_mode"
                text: Translation.tr("Suspend") + ` (${value > 0 ? Math.floor(value/60) + "m" : Translation.tr("disabled")})`
                value: Config.options.idle.suspendTimeout
                from: 0
                to: 7200
                stepSize: 60
                onValueChanged: Config.options.idle.suspendTimeout = value
                StyledToolTip {
                    text: Translation.tr("Suspend system after this many seconds of inactivity (0 = never)")
                }
            }

            SettingsSwitch {
                buttonIcon: "lock_clock"
                text: Translation.tr("Lock before sleep")
                checked: Config.options.idle.lockBeforeSleep
                onCheckedChanged: Config.options.idle.lockBeforeSleep = checked
                StyledToolTip {
                    text: Translation.tr("Lock the screen before the system goes to sleep")
                }
            }

            SettingsSwitch {
                buttonIcon: "coffee"
                text: Translation.tr("Keep awake (caffeine)")
                checked: Idle.inhibit
                onCheckedChanged: {
                    if (checked !== Idle.inhibit) Idle.toggleInhibit()
                }
                StyledToolTip {
                    text: Translation.tr("Temporarily prevent screen from turning off and system from sleeping")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "neurology"
        title: Translation.tr("AI")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("System prompt")
                text: Config.options.ai.systemPrompt
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.options.ai.systemPrompt = text;
                    });
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        SettingsGroup {
            ConfigSpinBox {
                icon: "timer_off"
                text: Translation.tr("Total duration timeout (s)")
                value: Config.options.musicRecognition.timeout
                from: 10
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.musicRecognition.timeout = value;
                }
                StyledToolTip {
                    text: Translation.tr("Maximum time to wait for music recognition result")
                }
            }
            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Polling interval (s)")
                value: Config.options.musicRecognition.interval
                from: 2
                to: 10
                stepSize: 1
                onValueChanged: {
                    Config.options.musicRecognition.interval = value;
                }
                StyledToolTip {
                    text: Translation.tr("How often to check for recognition result")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "cell_tower"
        title: Translation.tr("Networking")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("User agent (for services that require it)")
                text: Config.options.networking.userAgent
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.networking.userAgent = text;
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "memory"
        title: Translation.tr("Resources")

        SettingsGroup {
            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Polling interval (ms)")
                value: Config.options.resources.updateInterval
                from: 100
                to: 10000
                stepSize: 100
                onValueChanged: {
                    Config.options.resources.updateInterval = value;
                }
                StyledToolTip {
                    text: Translation.tr("How often to update CPU, RAM, and disk usage stats")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "search"
        title: Translation.tr("Search")

        SettingsGroup {
            SettingsSwitch {
                text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
                checked: Config.options.search.sloppy
                onCheckedChanged: {
                    Config.options.search.sloppy = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
                }
            }

            ContentSubsection {
                title: Translation.tr("Prefixes")
                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Action")
                        text: Config.options.search.prefix.action
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.action = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Clipboard")
                        text: Config.options.search.prefix.clipboard
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.clipboard = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Emojis")
                        text: Config.options.search.prefix.emojis
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.emojis = text;
                        }
                    }
                }

                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Math")
                        text: Config.options.search.prefix.math
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.math = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Shell command")
                        text: Config.options.search.prefix.shellCommand
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.shellCommand = text;
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Web search")
                        text: Config.options.search.prefix.webSearch
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.options.search.prefix.webSearch = text;
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Web search")
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Base URL")
                    text: Config.options.search.engineBaseUrl
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.engineBaseUrl = text;
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "system_update"
        title: Translation.tr("Updates")

        SettingsGroup {
            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Check interval") + ` (${value}m)`
                value: Config.options?.updates?.checkInterval ?? 120
                from: 15
                to: 1440
                stepSize: 15
                onValueChanged: Config.setNestedValue("updates.checkInterval", value)
                StyledToolTip {
                    text: Translation.tr("How often to check for system updates (in minutes)")
                }
            }

            ConfigSpinBox {
                icon: "notifications"
                text: Translation.tr("Show icon threshold")
                value: Config.options?.updates?.adviseUpdateThreshold ?? 10
                from: 1
                to: 200
                stepSize: 5
                onValueChanged: Config.setNestedValue("updates.adviseUpdateThreshold", value)
                StyledToolTip {
                    text: Translation.tr("Show update icon in bar when available updates exceed this number")
                }
            }

            ConfigSpinBox {
                icon: "warning"
                text: Translation.tr("Warning threshold")
                value: Config.options?.updates?.stronglyAdviseUpdateThreshold ?? 50
                from: 10
                to: 500
                stepSize: 10
                onValueChanged: Config.setNestedValue("updates.stronglyAdviseUpdateThreshold", value)
                StyledToolTip {
                    text: Translation.tr("Show warning color when available updates exceed this number")
                }
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Update command")
                text: Config.options?.apps?.update ?? ""
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.setNestedValue("apps.update", text)
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "weather_mix"
        title: Translation.tr("Weather")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Weather data is provided by Open-Meteo. Leave city empty to auto-detect from your IP address.")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("City (e.g. Buenos Aires, London, Tokyo)")
                text: Config.options?.bar?.weather?.city ?? ""
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.setNestedValue("bar.weather.city", text)
            }

            ConfigRow {
                SettingsSwitch {
                    buttonIcon: "my_location"
                    text: Translation.tr("Use GPS location")
                    checked: Config.options?.bar?.weather?.enableGPS ?? false
                    onCheckedChanged: Config.setNestedValue("bar.weather.enableGPS", checked)
                    StyledToolTip {
                        text: Translation.tr("Override city with GPS coordinates when available")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "thermometer"
                    text: Translation.tr("Use Fahrenheit (°F)")
                    checked: Config.options?.bar?.weather?.useUSCS ?? false
                    onCheckedChanged: Config.setNestedValue("bar.weather.useUSCS", checked)
                }
            }

            ConfigSpinBox {
                icon: "update"
                text: Translation.tr("Update interval (minutes)")
                value: Config.options?.bar?.weather?.fetchInterval ?? 10
                from: 5
                to: 60
                stepSize: 5
                onValueChanged: Config.setNestedValue("bar.weather.fetchInterval", value)
                StyledToolTip {
                    text: Translation.tr("How often to check for new weather data from Open-Meteo")
                }
            }
        }
    }
}
