import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
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
                text: Translation.tr("Automatically checks the iNiR git repository for new versions and shows a notification in the bar.")
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

            // Status card with visual states
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusCardCol.implicitHeight + 24
                radius: Appearance.rounding.normal
                visible: Config.options?.shellUpdates?.enabled ?? true

                color: {
                    if (ShellUpdates.hasUpdate) return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.92)
                    if (ShellUpdates.lastError.length > 0) return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.92)
                    return Appearance.colors.colSurfaceContainerLow
                }
                border.width: 1
                border.color: {
                    if (ShellUpdates.hasUpdate) return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.7)
                    if (ShellUpdates.lastError.length > 0) return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.7)
                    return Appearance.colors.colLayer0Border
                }

                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                Behavior on border.color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                ColumnLayout {
                    id: statusCardCol
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 10

                    // Status header with icon
                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Rectangle {
                            width: 40
                            height: 40
                            radius: Appearance.rounding.small
                            color: {
                                if (ShellUpdates.hasUpdate) return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.8)
                                if (ShellUpdates.isChecking || ShellUpdates.isUpdating) return ColorUtils.transparentize(Appearance.colors.colSubtext, 0.85)
                                if (ShellUpdates.lastError.length > 0) return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.8)
                                return ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.85)
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: {
                                    if (ShellUpdates.isUpdating) return "hourglass_top"
                                    if (ShellUpdates.isChecking) return "sync"
                                    if (ShellUpdates.hasUpdate) return "upgrade"
                                    if (ShellUpdates.lastError.length > 0) return "error"
                                    if (ShellUpdates.available) return "check_circle"
                                    return "cloud_off"
                                }
                                iconSize: Appearance.font.pixelSize.huge
                                color: {
                                    if (ShellUpdates.hasUpdate) return Appearance.m3colors.m3primary
                                    if (ShellUpdates.lastError.length > 0) return Appearance.m3colors.m3error
                                    if (ShellUpdates.available) return Appearance.m3colors.m3tertiary
                                    return Appearance.colors.colSubtext
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            StyledText {
                                text: {
                                    if (ShellUpdates.isUpdating) return Translation.tr("Updating…")
                                    if (ShellUpdates.isChecking) return Translation.tr("Checking for updates…")
                                    if (ShellUpdates.hasUpdate) return Translation.tr("Update available")
                                    if (ShellUpdates.lastError.length > 0) return Translation.tr("Error")
                                    if (ShellUpdates.available) return Translation.tr("Up to date")
                                    return Translation.tr("Not available")
                                }
                                font {
                                    pixelSize: Appearance.font.pixelSize.normal
                                    weight: Font.DemiBold
                                }
                                color: {
                                    if (ShellUpdates.hasUpdate) return Appearance.m3colors.m3primary
                                    if (ShellUpdates.lastError.length > 0) return Appearance.m3colors.m3error
                                    return Appearance.colors.colOnSurface
                                }
                            }

                            StyledText {
                                visible: ShellUpdates.hasUpdate
                                text: Translation.tr("%1 commit(s) behind on %2").arg(ShellUpdates.commitsBehind).arg(ShellUpdates.currentBranch || "main")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                visible: !ShellUpdates.hasUpdate && !ShellUpdates.isChecking && !ShellUpdates.isUpdating && ShellUpdates.lastError.length === 0 && ShellUpdates.available
                                text: ShellUpdates.currentBranch.length > 0
                                    ? Translation.tr("Branch: %1").arg(ShellUpdates.currentBranch)
                                    : ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    // Version comparison row
                    RowLayout {
                        visible: ShellUpdates.localCommit.length > 0
                        spacing: 8
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: localCommitCol.implicitHeight + 12
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border

                            ColumnLayout {
                                id: localCommitCol
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                spacing: 2

                                StyledText {
                                    text: Translation.tr("Current")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: ShellUpdates.localCommit || "—"
                                    font {
                                        pixelSize: Appearance.font.pixelSize.smaller
                                        family: Appearance.font.family.monospace
                                        weight: Font.Medium
                                    }
                                    color: Appearance.colors.colOnSurface
                                }
                            }
                        }

                        MaterialSymbol {
                            visible: ShellUpdates.hasUpdate && ShellUpdates.remoteCommit.length > 0
                            text: "arrow_forward"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3primary
                        }

                        Rectangle {
                            visible: ShellUpdates.hasUpdate && ShellUpdates.remoteCommit.length > 0
                            Layout.fillWidth: true
                            implicitHeight: remoteCommitCol.implicitHeight + 12
                            radius: Appearance.rounding.small
                            color: ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.88)
                            border.width: 1
                            border.color: ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.7)

                            ColumnLayout {
                                id: remoteCommitCol
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                spacing: 2

                                StyledText {
                                    text: Translation.tr("Available")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.m3colors.m3primary
                                    opacity: 0.8
                                }
                                StyledText {
                                    text: ShellUpdates.remoteCommit || "—"
                                    font {
                                        pixelSize: Appearance.font.pixelSize.smaller
                                        family: Appearance.font.family.monospace
                                        weight: Font.DemiBold
                                    }
                                    color: Appearance.m3colors.m3primary
                                }
                            }
                        }
                    }

                    // Latest commit message
                    RowLayout {
                        visible: ShellUpdates.latestMessage.length > 0 && ShellUpdates.hasUpdate
                        spacing: 6
                        Layout.fillWidth: true

                        MaterialSymbol {
                            text: "notes"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            Layout.alignment: Qt.AlignTop
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: ShellUpdates.latestMessage
                            font {
                                pixelSize: Appearance.font.pixelSize.smallest
                                family: Appearance.font.family.monospace
                            }
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }

                    // Error display
                    RowLayout {
                        visible: ShellUpdates.lastError.length > 0
                        spacing: 6
                        Layout.fillWidth: true

                        MaterialSymbol {
                            text: "warning"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3error
                            Layout.alignment: Qt.AlignTop
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: ShellUpdates.lastError
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.m3colors.m3error
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: Config.options?.shellUpdates?.enabled ?? true

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    enabled: !ShellUpdates.isChecking && !ShellUpdates.isUpdating
                    opacity: enabled ? 1.0 : 0.5
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
                            text: ShellUpdates.isChecking ? Translation.tr("Checking…") : Translation.tr("Check Now")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    onClicked: {
                        if (Config.options?.settingsUi?.overlayMode ?? false) {
                            // Overlay mode: settings runs inside the main shell process — direct call works
                            ShellUpdates.openOverlay()
                        } else {
                            // Separate window mode (default): settings.qml is a separate qs process.
                            // Singletons are isolated per-process, so we must use IPC to reach
                            // the main shell's ShellUpdates.openOverlay() instead.
                            Quickshell.execDetached(["qs", "-c", "inir", "ipc", "call", "shellUpdate", "open"])
                        }
                    }

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: "open_in_new"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            text: Translation.tr("Open Details")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    visible: ShellUpdates.hasUpdate
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.m3colors.m3primary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    enabled: !ShellUpdates.isUpdating
                    opacity: enabled ? 1.0 : 0.5
                    onClicked: ShellUpdates.performUpdate()

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: ShellUpdates.isUpdating ? "hourglass_top" : "upgrade"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onPrimary
                        }
                        StyledText {
                            text: ShellUpdates.isUpdating ? Translation.tr("Updating…") : Translation.tr("Update Now")
                            font {
                                pixelSize: Appearance.font.pixelSize.smaller
                                weight: Font.DemiBold
                            }
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
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
                        text: Translation.tr("Dismiss update (hide bar indicator)")
                    }
                }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
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
                text: Translation.tr("Set a city name or coordinates for precise location. Leave empty to auto-detect from IP. Data provided by wttr.in.")
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

            // Manual location
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                enabled: Config.options?.bar?.weather?.enable ?? false

                StyledText {
                    text: Translation.tr("City (leave empty to auto-detect)")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                MaterialTextField {
                    id: weatherCityInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. Buenos Aires, London, Tokyo")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSurface
                    placeholderTextColor: Appearance.colors.colSubtext
                    text: Config.options?.bar?.weather?.city ?? ""
                    background: Rectangle {
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        border.width: weatherCityInput.activeFocus ? 2 : 1
                        border.color: weatherCityInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                    }
                    onTextEdited: Config.setNestedValue("bar.weather.city", text)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                enabled: Config.options?.bar?.weather?.enable ?? false

                StyledText {
                    text: Translation.tr("Manual coordinates (optional, overrides city)")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: weatherLatInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Latitude (e.g. -34.6037)")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        placeholderTextColor: Appearance.colors.colSubtext
                        text: {
                            const v = Config.options?.bar?.weather?.manualLat ?? 0;
                            return v !== 0 ? String(v) : "";
                        }
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.small
                            border.width: weatherLatInput.activeFocus ? 2 : 1
                            border.color: weatherLatInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                        }
                        onTextEdited: {
                            const num = parseFloat(text);
                            Config.setNestedValue("bar.weather.manualLat", isNaN(num) ? 0 : num);
                        }
                    }

                    MaterialTextField {
                        id: weatherLonInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Longitude (e.g. -58.3816)")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        placeholderTextColor: Appearance.colors.colSubtext
                        text: {
                            const v = Config.options?.bar?.weather?.manualLon ?? 0;
                            return v !== 0 ? String(v) : "";
                        }
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.small
                            border.width: weatherLonInput.activeFocus ? 2 : 1
                            border.color: weatherLonInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                        }
                        onTextEdited: {
                            const num = parseFloat(text);
                            Config.setNestedValue("bar.weather.manualLon", isNaN(num) ? 0 : num);
                        }
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "my_location"
                text: Translation.tr("Use GPS location (requires geoclue)")
                checked: Config.options?.bar?.weather?.enableGPS ?? false
                onCheckedChanged: Config.setNestedValue("bar.weather.enableGPS", checked)
                enabled: Config.options?.bar?.weather?.enable ?? false
                StyledToolTip {
                    text: Translation.tr("Uses GPS when no manual location is set")
                }
            }

            // Current detected location display
            StyledText {
                Layout.fillWidth: true
                visible: (Config.options?.bar?.weather?.enable ?? false) && Weather.location.valid
                text: Translation.tr("Current location:") + " " + (Weather.location.name || (Weather.location.lat + ", " + Weather.location.lon))
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                font.italic: true
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Use Fahrenheit (°F)")
                checked: Config.options?.bar?.weather?.useUSCS ?? false
                onCheckedChanged: Config.setNestedValue("bar.weather.useUSCS", checked)
                enabled: Config.options?.bar?.weather?.enable ?? false
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
