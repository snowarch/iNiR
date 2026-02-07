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
                value: Config.options?.idle?.screenOffTimeout ?? 300
                from: 0
                to: 3600
                stepSize: 30
                onValueChanged: Config.setNestedValue("idle.screenOffTimeout", value)
                StyledToolTip {
                    text: Translation.tr("Turn off display after this many seconds of inactivity (0 = never)")
                }
            }

            ConfigSpinBox {
                icon: "lock"
                text: Translation.tr("Lock screen") + ` (${value > 0 ? Math.floor(value/60) + "m" : Translation.tr("disabled")})`
                value: Config.options?.idle?.lockTimeout ?? 600
                from: 0
                to: 3600
                stepSize: 60
                onValueChanged: Config.setNestedValue("idle.lockTimeout", value)
                StyledToolTip {
                    text: Translation.tr("Lock screen after this many seconds of inactivity (0 = never)")
                }
            }

            ConfigSpinBox {
                icon: "dark_mode"
                text: Translation.tr("Suspend") + ` (${value > 0 ? Math.floor(value/60) + "m" : Translation.tr("disabled")})`
                value: Config.options?.idle?.suspendTimeout ?? 0
                from: 0
                to: 7200
                stepSize: 60
                onValueChanged: Config.setNestedValue("idle.suspendTimeout", value)
                StyledToolTip {
                    text: Translation.tr("Suspend system after this many seconds of inactivity (0 = never)")
                }
            }

            SettingsSwitch {
                buttonIcon: "lock_clock"
                text: Translation.tr("Lock before sleep")
                checked: Config.options?.idle?.lockBeforeSleep ?? true
                onCheckedChanged: Config.setNestedValue("idle.lockBeforeSleep", checked)
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
        icon: "deployed_code_update"
        title: Translation.tr("iNiR Shell Updates")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Automatically checks the iNiR git repository for new versions and shows a notification in the bar. Click the indicator to update, or right-click to dismiss.")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Enable shell update checker")
                checked: Config.options?.shellUpdates?.enabled ?? true
                onCheckedChanged: Config.setNestedValue("shellUpdates.enabled", checked)
            }

            ConfigSpinBox {
                icon: "schedule"
                text: Translation.tr("Check interval") + ` (${value}m)`
                value: Config.options?.shellUpdates?.checkIntervalMinutes ?? 360
                from: 30
                to: 1440
                stepSize: 30
                onValueChanged: Config.setNestedValue("shellUpdates.checkIntervalMinutes", value)
                enabled: Config.options?.shellUpdates?.enabled ?? true
                StyledToolTip {
                    text: Translation.tr("How often to check for iNiR updates (in minutes). Default: 360 (6 hours)")
                }
            }

            // Status display
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusCol.implicitHeight + 16
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerLow
                visible: Config.options?.shellUpdates?.enabled ?? true

                ColumnLayout {
                    id: statusCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        MaterialSymbol {
                            text: ShellUpdates.hasUpdate ? "update" : ShellUpdates.isChecking ? "sync" : "check_circle"
                            iconSize: Appearance.font.pixelSize.normal
                            color: ShellUpdates.hasUpdate ? Appearance.m3colors.m3primary
                                : ShellUpdates.isChecking ? Appearance.colors.colSubtext
                                : Appearance.m3colors.m3tertiary
                        }
                        StyledText {
                            text: {
                                if (ShellUpdates.isUpdating) return Translation.tr("Updating...")
                                if (ShellUpdates.isChecking) return Translation.tr("Checking...")
                                if (ShellUpdates.hasUpdate) return Translation.tr("Update available: %1 commit(s) behind").arg(ShellUpdates.commitsBehind)
                                if (ShellUpdates.available) return Translation.tr("Up to date")
                                return Translation.tr("Not available (no git repo)")
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    RowLayout {
                        visible: ShellUpdates.localCommit.length > 0
                        spacing: 6
                        StyledText {
                            text: Translation.tr("Local: %1").arg(ShellUpdates.localCommit)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            visible: ShellUpdates.remoteCommit.length > 0 && ShellUpdates.hasUpdate
                            text: "→ " + ShellUpdates.remoteCommit
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            font.weight: Font.DemiBold
                            color: Appearance.m3colors.m3primary
                        }
                    }
                    
                    // Branch info
                    RowLayout {
                        visible: ShellUpdates.currentBranch.length > 0
                        spacing: 4
                        MaterialSymbol {
                            text: "account_tree"
                            iconSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: ShellUpdates.currentBranch
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                        }
                    }

                    StyledText {
                        visible: ShellUpdates.lastError.length > 0
                        text: ShellUpdates.lastError
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.m3colors.m3error
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Action buttons row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: Config.options?.shellUpdates?.enabled ?? true

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    opacity: ShellUpdates.isChecking ? 0.5 : 1.0
                    onClicked: ShellUpdates.check()

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: "refresh"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            text: ShellUpdates.isChecking ? Translation.tr("Checking...") : Translation.tr("Check Now")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    visible: ShellUpdates.hasUpdate
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.m3colors.m3primary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    opacity: ShellUpdates.isUpdating ? 0.5 : 1.0
                    onClicked: { if (!ShellUpdates.isUpdating) ShellUpdates.performUpdate() }

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: ShellUpdates.isUpdating ? "hourglass_top" : "upgrade"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onPrimary
                        }
                        StyledText {
                            text: ShellUpdates.isUpdating ? Translation.tr("Updating...") : Translation.tr("Update Now")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    visible: ShellUpdates.hasUpdate && !ShellUpdates.isDismissed
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    onClicked: ShellUpdates.dismiss()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "notifications_off"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }

                    StyledToolTip {
                        text: Translation.tr("Dismiss this update (hide bar indicator)")
                    }
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    visible: ShellUpdates.isDismissed
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    onClicked: ShellUpdates.undismiss()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "notifications_active"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3primary
                    }

                    StyledToolTip {
                        text: Translation.tr("Show bar indicator again")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "cloud"
        title: Translation.tr("Weather")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Location is detected automatically. Weather data provided by wttr.in.")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Enable weather service")
                checked: Config.options?.bar?.weather?.enable ?? false
                onCheckedChanged: Config.setNestedValue("bar.weather.enable", checked)
            }

            SettingsSwitch {
                buttonIcon: "view_timeline"
                text: Translation.tr("Show in top bar")
                checked: Config.options?.bar?.modules?.weather ?? false
                onCheckedChanged: Config.setNestedValue("bar.modules.weather", checked)
                enabled: Config.options?.bar?.weather?.enable ?? false
            }

            SettingsSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Use Fahrenheit (°F)")
                checked: Config.options?.bar?.weather?.useUSCS ?? false
                onCheckedChanged: Config.setNestedValue("bar.weather.useUSCS", checked)
                enabled: Config.options?.bar?.weather?.enable ?? false
                StyledToolTip {
                    text: Translation.tr("May take a moment to update")
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
                enabled: Config.options?.bar?.weather?.enable ?? false
            }
        }
    }
}
