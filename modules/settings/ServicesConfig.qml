import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true
    settingsPageIndex: 6
    settingsPageName: Translation.tr("Services")

    ContentSection {
        icon: "bedtime"
        title: Translation.tr("Idle & Sleep")

        ConfigSpinBox {
            icon: "monitor"
            text: Translation.tr("Screen off") + ` (${value > 0 ? Math.floor(value/60) + "m " + (value%60) + "s" : Translation.tr("disabled")})`
            value: Config.options.idle.screenOffTimeout
            from: 0
            to: 3600
            stepSize: 30
            onValueChanged: Config.options.idle.screenOffTimeout = value
        }

        ConfigSpinBox {
            icon: "lock"
            text: Translation.tr("Lock screen") + ` (${value > 0 ? Math.floor(value/60) + "m" : Translation.tr("disabled")})`
            value: Config.options.idle.lockTimeout
            from: 0
            to: 3600
            stepSize: 60
            onValueChanged: Config.options.idle.lockTimeout = value
        }

        ConfigSpinBox {
            icon: "dark_mode"
            text: Translation.tr("Suspend") + ` (${value > 0 ? Math.floor(value/60) + "m" : Translation.tr("disabled")})`
            value: Config.options.idle.suspendTimeout
            from: 0
            to: 7200
            stepSize: 60
            onValueChanged: Config.options.idle.suspendTimeout = value
        }

        ConfigSwitch {
            buttonIcon: "lock_clock"
            text: Translation.tr("Lock before sleep")
            checked: Config.options.idle.lockBeforeSleep
            onCheckedChanged: Config.options.idle.lockBeforeSleep = checked
        }

        ConfigSwitch {
            buttonIcon: "coffee"
            text: Translation.tr("Keep awake (caffeine)")
            checked: Idle.inhibit
            onCheckedChanged: {
                if (checked !== Idle.inhibit) Idle.toggleInhibit()
            }
        }
    }

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI")

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

    ContentSection {
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

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
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

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

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources")

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
        }
        
    }

    ContentSection {
        icon: "search"
        title: Translation.tr("Search")

        ConfigSwitch {
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

    ContentSection {
        icon: "system_update"
        title: Translation.tr("Updates")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Check interval") + ` (${value}m)`
            value: Config.options?.updates?.checkInterval ?? 120
            from: 15
            to: 1440
            stepSize: 15
            onValueChanged: Config.setNestedValue("updates.checkInterval", value)
        }

        ConfigSpinBox {
            icon: "notifications"
            text: Translation.tr("Show icon threshold")
            value: Config.options?.updates?.adviseUpdateThreshold ?? 10
            from: 1
            to: 200
            stepSize: 5
            onValueChanged: Config.setNestedValue("updates.adviseUpdateThreshold", value)
        }

        ConfigSpinBox {
            icon: "warning"
            text: Translation.tr("Warning threshold")
            value: Config.options?.updates?.stronglyAdviseUpdateThreshold ?? 50
            from: 10
            to: 500
            stepSize: 10
            onValueChanged: Config.setNestedValue("updates.stronglyAdviseUpdateThreshold", value)
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Update command")
            text: Config.options?.apps?.update ?? ""
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.setNestedValue("apps.update", text)
        }
    }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Weather")
        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }
}
