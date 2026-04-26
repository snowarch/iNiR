import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    settingsPageIndex: 7
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
                text: Config.options?.ai?.systemPrompt ?? ""
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.setNestedValue("ai.systemPrompt", text)
                    });
                }
            }
        }

        // Custom AI Providers
        SettingsGroup {
            // Section header
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.bottomMargin: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Custom Providers")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                RippleButton {
                    implicitWidth: addProviderBtnRow.implicitWidth + 16
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.80)
                    onClicked: addProviderForm.expanded = true

                    contentItem: RowLayout {
                        id: addProviderBtnRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "add"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Add Provider")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }

            // Provider list
            Repeater {
                model: Config.options?.ai?.extraModels ?? []

                delegate: Item {
                    id: providerItem
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: providerRow.implicitHeight + 12

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: providerMA.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                        RowLayout {
                            id: providerRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerItem.modelData?.name ?? providerItem.modelData?.model ?? Translation.tr("Unnamed")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: (providerItem.modelData?.model ?? "") + " · " + (providerItem.modelData?.endpoint ?? "")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideMiddle
                                }
                            }

                            // API format badge
                            Rectangle {
                                width: fmtLabel.implicitWidth + 12
                                height: 20
                                radius: 10
                                color: ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.85)

                                readonly property var formatLabels: ({
                                    "openai": "OpenAI Chat",
                                    "gemini": "Gemini",
                                    "mistral": "Mistral",
                                    "anthropic": "Anthropic",
                                    "openai-response": "OpenAI Response"
                                })

                                StyledText {
                                    id: fmtLabel
                                    anchors.centerIn: parent
                                    text: parent.formatLabels[providerItem.modelData?.api_format] ?? providerItem.modelData?.api_format ?? "openai"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.Medium
                                    color: Appearance.m3colors.m3tertiary
                                }
                            }

                            // Delete button
                            RippleButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: 14
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    let models = [...(Config.options?.ai?.extraModels ?? [])]
                                    models.splice(providerItem.index, 1)
                                    Config.setNestedValue("ai.extraModels", models)
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 14
                                    color: Appearance.colors.colSubtext
                                }

                                StyledToolTip {
                                    text: Translation.tr("Remove")
                                }
                            }
                        }

                        MouseArea {
                            id: providerMA
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                        }
                    }
                }
            }

            // Empty state
            StyledText {
                visible: (Config.options?.ai?.extraModels ?? []).length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                text: Translation.tr("No custom providers added yet")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                font.italic: true
            }

            // Help text
            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                text: Translation.tr("Add custom API endpoints using standard protocols. After adding, restart the shell and use /model in the AI sidebar to switch to your provider.")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
                opacity: 0.7
            }

            // Inline add-provider form
            Rectangle {
                id: addProviderForm
                Layout.fillWidth: true
                Layout.topMargin: 4

                property bool expanded: false

                implicitHeight: expanded ? aiAddFormCol.implicitHeight + 24 : 0
                visible: expanded
                clip: true
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerLow
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                ColumnLayout {
                    id: aiAddFormCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    StyledText {
                        text: Translation.tr("Add Custom AI Provider")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Provider name")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerNameInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. My Claude Proxy")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerNameInput.activeFocus ? 2 : 1
                                border.color: providerNameInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("API endpoint URL")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerEndpointInput
                            Layout.fillWidth: true
                            placeholderText: "https://api.openai.com/v1/chat/completions"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerEndpointInput.activeFocus ? 2 : 1
                                border.color: providerEndpointInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4

                        StyledText {
                            text: Translation.tr("API format")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        RowLayout {
                            id: apiFormatRow
                            spacing: 8
                            Layout.fillWidth: true

                            property string selectedFormat: "openai"

                            Repeater {
                                model: [
                                    { value: "openai", label: "OpenAI Chat", desc: Translation.tr("OpenAI / Mistral / Ollama / OpenRouter / vLLM / ...") },
                                    { value: "anthropic", label: "Anthropic", desc: Translation.tr("Anthropic Messages API") },
                                    { value: "openai-response", label: "OpenAI Response", desc: Translation.tr("New OpenAI Responses API") }
                                ]

                                Rectangle {
                                    required property var modelData
                                    required property int index

                                    readonly property bool selected: apiFormatRow.selectedFormat === modelData.value

                                    Layout.fillWidth: true
                                    implicitHeight: fmtBtnCol.implicitHeight + 16
                                    radius: Appearance.rounding.small
                                    color: selected
                                        ? Appearance.colors.colPrimary
                                        : formatMA.containsMouse
                                            ? Appearance.colors.colLayer1Hover
                                            : Appearance.colors.colLayer1
                                    border.width: selected ? 0 : 1
                                    border.color: Appearance.colors.colLayer0Border

                                    Behavior on color {
                                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                    }

                                    ColumnLayout {
                                        id: fmtBtnCol
                                        anchors.centerIn: parent
                                        spacing: 2

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: selected ? Font.DemiBold : Font.Normal
                                            color: selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: selected
                                            text: modelData.desc
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: selected ? ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.8) : Appearance.colors.colSubtext
                                        }
                                    }

                                    MouseArea {
                                        id: formatMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: apiFormatRow.selectedFormat = modelData.value
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Model code")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerModelInput
                            Layout.fillWidth: true
                            placeholderText: "gpt-4.1"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerModelInput.activeFocus ? 2 : 1
                                border.color: providerModelInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("API key (optional)")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerApiKeyInput
                            Layout.fillWidth: true
                            placeholderText: "sk-..."
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            echoMode: TextInput.Password
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerApiKeyInput.activeFocus ? 2 : 1
                                border.color: providerApiKeyInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    // Action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitWidth: cancelProviderLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                addProviderForm.expanded = false
                                providerNameInput.text = ""
                                providerEndpointInput.text = ""
                                apiFormatRow.selectedFormat = "openai"
                                providerModelInput.text = ""
                                providerApiKeyInput.text = ""
                            }

                            contentItem: StyledText {
                                id: cancelProviderLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Cancel")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        RippleButton {
                            implicitWidth: saveProviderLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            enabled: providerEndpointInput.text.trim() !== "" && providerModelInput.text.trim() !== ""
                            opacity: enabled ? 1 : 0.5
                            onClicked: {
                                const modelCode = providerModelInput.text.trim()
                                const apiKey = providerApiKeyInput.text.trim()
                                const keyId = modelCode.toLowerCase().replace(/[:\/ ]/g, "-")

                                const newModel = {
                                    name: providerNameInput.text.trim() || modelCode,
                                    endpoint: providerEndpointInput.text.trim(),
                                    model: modelCode,
                                    api_format: apiFormatRow.selectedFormat,
                                    requires_key: apiKey.length > 0,
                                    key_id: keyId,
                                }

                                let models = [...(Config.options?.ai?.extraModels ?? [])]
                                models.push(newModel)
                                Config.setNestedValue("ai.extraModels", models)

                                if (apiKey.length > 0) {
                                    KeyringStorage.setNestedField(["apiKeys", keyId], apiKey)
                                }

                                addProviderForm.expanded = false
                                providerNameInput.text = ""
                                providerEndpointInput.text = ""
                                apiFormatRow.selectedFormat = "openai"
                                providerModelInput.text = ""
                                providerApiKeyInput.text = ""
                            }

                            contentItem: StyledText {
                                id: saveProviderLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Add")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
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
                value: Config.options?.musicRecognition?.timeout ?? 16
                from: 10
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.setNestedValue("musicRecognition.timeout", value)
                }
                StyledToolTip {
                    text: Translation.tr("Maximum time to wait for music recognition result")
                }
            }
            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Polling interval (s)")
                value: Config.options?.musicRecognition?.interval ?? 4
                from: 2
                to: 10
                stepSize: 1
                onValueChanged: {
                    Config.setNestedValue("musicRecognition.interval", value)
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
                text: Config.options?.networking?.userAgent ?? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.setNestedValue("networking.userAgent", text)
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "wifi_tethering"
        title: Translation.tr("Hotspot")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Network name (SSID)")
                text: Config.options?.hotspot?.ssid ?? "iNiR Hotspot"
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.setNestedValue("hotspot.ssid", text)
                StyledToolTip {
                    text: Translation.tr("The name your hotspot will broadcast")
                }
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Password")
                text: Config.options?.hotspot?.password ?? "inirhotspot"
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.setNestedValue("hotspot.password", text)
                StyledToolTip {
                    text: Translation.tr("WPA2 passphrase for the hotspot")
                }
            }

            SettingsSwitch {
                text: Translation.tr("Use 5 GHz band")
                checked: (Config.options?.hotspot?.band ?? "bg") === "a"
                onCheckedChanged: Config.setNestedValue("hotspot.band", checked ? "a" : "bg")
                StyledToolTip {
                    text: Translation.tr("Use 5 GHz (802.11a) instead of 2.4 GHz. Requires adapter support.")
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
                value: Config.options?.resources?.updateInterval ?? 3000
                from: 100
                to: 10000
                stepSize: 100
                onValueChanged: {
                    Config.setNestedValue("resources.updateInterval", value)
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
                checked: Config.options?.search?.sloppy ?? false
                onCheckedChanged: {
                    Config.setNestedValue("search.sloppy", checked)
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
                        text: Config.options?.search?.prefix?.action ?? "/"
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.setNestedValue("search.prefix.action", text)
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Clipboard")
                        text: Config.options?.search?.prefix?.clipboard ?? ";"
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.setNestedValue("search.prefix.clipboard", text)
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Emojis")
                        text: Config.options?.search?.prefix?.emojis ?? ":"
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.setNestedValue("search.prefix.emojis", text)
                        }
                    }
                }

                ConfigRow {
                    uniform: true
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Math")
                        text: Config.options?.search?.prefix?.math ?? "="
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.setNestedValue("search.prefix.math", text)
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Shell command")
                        text: Config.options?.search?.prefix?.shellCommand ?? "$"
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.setNestedValue("search.prefix.shellCommand", text)
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Web search")
                        text: Config.options?.search?.prefix?.webSearch ?? "?"
                        wrapMode: TextEdit.Wrap
                        onTextChanged: {
                            Config.setNestedValue("search.prefix.webSearch", text)
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Web search")
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Base URL")
                    text: Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q="
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.setNestedValue("search.engineBaseUrl", text)
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

                Behavior on color { animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on border.color { animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

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
                                    if (ShellUpdates.isUpdating) {
                                        if (ShellUpdates.updateStepMessage.length > 0) {
                                            return Translation.tr(ShellUpdates.updateStepMessage) + (ShellUpdates.updateStep > 0 ? " (" + ShellUpdates.updateStep + "/" + ShellUpdates.updateTotalSteps + ")" : "")
                                        }
                                        return Translation.tr("Updating…")
                                    }
                                    if (ShellUpdates.isChecking) return Translation.tr("Checking for updates…")
                                    if (ShellUpdates.hasUpdate) return Translation.tr("Update available")
                                    if (ShellUpdates.managedExternally) return "Managed externally"
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
                                color: ShellUpdates.isNonMainBranch
                                    ? Appearance.m3colors.m3tertiary
                                    : Appearance.colors.colSubtext
                            }

                            StyledText {
                                visible: ShellUpdates.isNonMainBranch && !ShellUpdates.isChecking && !ShellUpdates.isUpdating
                                text: Translation.tr("Non-release branch — updates track %1").arg(ShellUpdates.currentBranch)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.m3colors.m3tertiary
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                visible: ShellUpdates.managedExternally
                                text: ShellUpdates.unavailableHint
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.WordWrap
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
                    enabled: !ShellUpdates.isChecking && !ShellUpdates.isUpdating && !ShellUpdates.managedExternally
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
                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "shellUpdate", "open"])
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
                    visible: ShellUpdates.hasUpdate && ShellUpdates.selfUpdateSupported
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
                            text: ShellUpdates.isUpdating
                                ? (ShellUpdates.updateStepMessage.length > 0
                                    ? Translation.tr(ShellUpdates.updateStepMessage) + "…"
                                    : Translation.tr("Updating…"))
                                : Translation.tr("Update Now")
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

            SettingsSwitch {
                buttonIcon: "visibility_off"
                text: Translation.tr("Hide weather location")
                checked: Config.options?.waffles?.widgetsPanel?.weatherHideLocation ?? false
                onCheckedChanged: Config.setNestedValue("waffles.widgetsPanel.weatherHideLocation", checked)
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

    SettingsCardSection {
        icon: "calendar_month"
        title: Translation.tr("Calendar Sync")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "sync"
                text: Translation.tr("Enable external calendar sync")
                checked: Config.options?.calendar?.externalSync?.enable ?? false
                onCheckedChanged: Config.setNestedValue("calendar.externalSync.enable", checked)
            }

            ConfigSpinBox {
                icon: "update"
                text: Translation.tr("Refresh interval (minutes)")
                value: Config.options?.calendar?.externalSync?.refreshMinutes ?? 15
                from: 5
                to: 120
                stepSize: 5
                onValueChanged: Config.setNestedValue("calendar.externalSync.refreshMinutes", value)
                enabled: Config.options?.calendar?.externalSync?.enable ?? false
            }

            SettingsSwitch {
                buttonIcon: "event"
                text: Translation.tr("Show upcoming events below calendar")
                checked: Config.options?.calendar?.showUpcoming ?? true
                onCheckedChanged: Config.setNestedValue("calendar.showUpcoming", checked)
            }

            ConfigSpinBox {
                icon: "date_range"
                text: Translation.tr("Upcoming days to show")
                value: Config.options?.calendar?.upcomingDays ?? 3
                from: 1
                to: 14
                stepSize: 1
                onValueChanged: Config.setNestedValue("calendar.upcomingDays", value)
            }
        }

        // Calendar source list
        SettingsGroup {
            visible: Config.options?.calendar?.externalSync?.enable ?? false

            // Section header for sources
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.bottomMargin: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Calendar Sources")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                RippleButton {
                    implicitWidth: addRow.implicitWidth + 16
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.80)
                    onClicked: addSourceForm.expanded = true

                    contentItem: RowLayout {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "add"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Add")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }

            // Source list
            Repeater {
                model: Config.options?.calendar?.externalSync?.sources ?? []

                delegate: Item {
                    id: sourceItem
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: sourceRow.implicitHeight + 12

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: sourceMA.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                        RowLayout {
                            id: sourceRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            // Color dot
                            Rectangle {
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                radius: 6
                                color: sourceItem.modelData?.color ?? Appearance.colors.colPrimary
                            }

                            // Name and URL
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: sourceItem.modelData?.name ?? Translation.tr("Unnamed")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: sourceItem.modelData?.url ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideMiddle
                                }
                            }

                            // Status indicator
                            MaterialSymbol {
                                visible: {
                                    const st = CalendarSync.sourceStatuses?.[sourceItem.modelData?.id]
                                    return st?.error && st.error !== ""
                                }
                                text: "error"
                                iconSize: 16
                                color: Appearance.m3colors.m3error

                                StyledToolTip {
                                    text: CalendarSync.sourceStatuses?.[sourceItem.modelData?.id]?.error ?? ""
                                }
                            }

                            // Toggle enabled
                            Switch {
                                checked: sourceItem.modelData?.enabled ?? true
                                onCheckedChanged: {
                                    if (checked !== (sourceItem.modelData?.enabled ?? true)) {
                                        CalendarSync.toggleSource(sourceItem.modelData.id, checked)
                                    }
                                }
                            }

                            // Remove button
                            RippleButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: 14
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: CalendarSync.removeSource(sourceItem.modelData.id)

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 14
                                    color: Appearance.colors.colSubtext
                                }

                                StyledToolTip {
                                    text: Translation.tr("Remove")
                                }
                            }
                        }

                        MouseArea {
                            id: sourceMA
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                        }
                    }
                }
            }

            // Empty state
            StyledText {
                visible: (Config.options?.calendar?.externalSync?.sources ?? []).length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                text: Translation.tr("No calendar sources added yet")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                font.italic: true
            }

            // Help text for getting ICS URLs
            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                text: Translation.tr("Paste an ICS/iCal URL from Google Calendar, Outlook, or any CalDAV provider. No account login needed — just the calendar URL.")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
                opacity: 0.7
            }

            // Inline add-source form (expands in place)
            Rectangle {
                id: addSourceForm
                Layout.fillWidth: true
                Layout.topMargin: 4

                property bool expanded: false

                implicitHeight: expanded ? addFormCol.implicitHeight + 24 : 0
                visible: expanded
                clip: true
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerLow
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                ColumnLayout {
                    id: addFormCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    StyledText {
                        text: Translation.tr("Add Calendar Source")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Name")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: sourceNameInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Work Calendar")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: sourceNameInput.activeFocus ? 2 : 1
                                border.color: sourceNameInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("ICS URL")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: sourceUrlInput
                            Layout.fillWidth: true
                            placeholderText: "https://calendar.google.com/calendar/ical/..."
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3onSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: sourceUrlInput.activeFocus ? 2 : 1
                                border.color: sourceUrlInput.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    // Color picker
                    ColumnLayout {
                        spacing: 4

                        StyledText {
                            text: Translation.tr("Color")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        Row {
                            id: colorPickerRow
                            spacing: 6
                            property string selectedColor: CalendarSync.presetColors[0]

                            Repeater {
                                model: CalendarSync.presetColors

                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: modelData
                                    border.width: colorPickerRow.selectedColor === modelData ? 2 : 0
                                    border.color: Appearance.colors.colOnLayer1
                                    opacity: colorPickMA.containsMouse ? 0.8 : 1

                                    MouseArea {
                                        id: colorPickMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: colorPickerRow.selectedColor = modelData
                                    }
                                }
                            }
                        }
                    }

                    // Action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitWidth: cancelLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                addSourceForm.expanded = false
                                sourceNameInput.text = ""
                                sourceUrlInput.text = ""
                            }

                            contentItem: StyledText {
                                id: cancelLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Cancel")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        RippleButton {
                            implicitWidth: addLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            enabled: sourceNameInput.text.trim() !== "" && sourceUrlInput.text.trim() !== ""
                            opacity: enabled ? 1 : 0.5
                            onClicked: {
                                CalendarSync.addSource(
                                    sourceNameInput.text.trim(),
                                    sourceUrlInput.text.trim(),
                                    colorPickerRow.selectedColor
                                )
                                sourceNameInput.text = ""
                                sourceUrlInput.text = ""
                                addSourceForm.expanded = false
                            }

                            contentItem: StyledText {
                                id: addLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Add")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }
        }
    }

}
