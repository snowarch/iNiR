pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.services.deferred
import qs.services.ai
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

/**
 * AI settings page (waffle family). ii mirror: modules/settings/AiConfig.qml —
 * keep both in sync; every control here writes the same config keys.
 *
 * Registered in waffleSettings.qml pages[] (index 15 — waffle indices are
 * positional, so new pages are appended at the END) and in
 * WSettingsContent.qml's searchIndex with pageIndex 15.
 *
 * Known difference from ii: the system prompt is a single-line field here.
 * waffle has no multi-line settings input, and inventing one for a single
 * consumer was not worth the shared-component risk.
 */
WSettingsPage {
    id: root
    settingsPageIndex: 15
    pageTitle: Translation.tr("AI")
    pageIcon: "wand"
    pageDescription: Translation.tr("Providers, models, behavior, voice input")

    Component.onCompleted: Ai.ensureInitialized()

    readonly property bool hasModel: (Ai.getModel() ?? null) !== null
    readonly property bool hasLocalModel: AiProviderCatalog.localModelCount > 0
        || Ai.modelList.some(m => Ai.models[m]?.local === true)

    // ── Get started ──────────────────────────────────────────────────────
    WSettingsCard {
        title: Translation.tr("Get started")
        icon: "flash-on"

        WSettingsInfoBar {
            severity: root.hasModel ? WSettingsInfoBar.Severity.Success : WSettingsInfoBar.Severity.Warning
            message: root.hasModel
                ? Translation.tr("Active model: %1").arg(Ai.getModel().name)
                : Translation.tr("No model selected. Connect a provider below and iNiR will discover compatible models automatically.")
        }

        WSettingsInfoBar {
            severity: Ai.currentModelHasApiKey ? WSettingsInfoBar.Severity.Success : WSettingsInfoBar.Severity.Warning
            message: Ai.currentModelHasApiKey
                ? Translation.tr("API key stored for the active model")
                : Translation.tr("The active model needs an API key. Connect the provider below; keys stay in the system keyring.")
        }

        WSettingsInfoBar {
            severity: root.hasLocalModel ? WSettingsInfoBar.Severity.Success : WSettingsInfoBar.Severity.Info
            message: root.hasLocalModel
                ? Translation.tr("%1 local model(s) detected").arg(AiProviderCatalog.localModelCount)
                : Translation.tr("No local models. Start Ollama or LM Studio to chat privately without an account or key.")
        }

        WSettingsInfoBar {
            severity: AiProviderCatalog.availableModelCount > 0
                ? WSettingsInfoBar.Severity.Success : WSettingsInfoBar.Severity.Info
            message: AiProviderCatalog.refreshing
                ? Translation.tr("Refreshing live model catalogs…")
                : Translation.tr("%1 live model(s): %2 free · %3 local · %4 key-enabled · %5 browseable")
                    .arg(AiProviderCatalog.availableModelCount)
                    .arg(AiProviderCatalog.freeModelCount)
                    .arg(AiProviderCatalog.localModelCount)
                    .arg(AiProviderCatalog.healthyProviderCount)
                    .arg(AiProviderCatalog.browseableProviderCount)
        }

        WSettingsButton {
            label: Translation.tr("Live model catalogs")
            description: Translation.tr("Refresh provider availability, model IDs, context and capabilities")
            icon: "arrow-sync"
            buttonText: Translation.tr("Refresh")
            buttonIcon: "arrow-sync"
            enabled: !AiProviderCatalog.refreshing
            onButtonClicked: AiProviderCatalog.refreshAll()
        }
    }

    // ── Providers & models ───────────────────────────────────────────────
    WSettingsCard {
        id: providersCard
        title: Translation.tr("Providers & models")
        icon: "apps"

        readonly property var extraModels: Config.options?.ai?.extraModels ?? []
        readonly property var formatLabels: ({
            "openai": "OpenAI",
            "gemini": "Gemini",
            "mistral": "Mistral",
            "anthropic": "Anthropic",
            "openai-response": "Responses"
        })

        function openForm(entry, editIndex) {
            providerForm.editingIndex = editIndex ?? -1
            providerForm.presetId = editIndex >= 0 ? (entry?.provider_id ?? "") : (entry?.id ?? "")
            const resolvedPreset = AiProviderPresets.byId(providerForm.presetId)
            providerForm.presetKeyId = resolvedPreset?.keyId ?? entry?.key_id ?? entry?.keyId ?? ""
            const liveModels = providerForm.presetId.length > 0
                ? AiProviderCatalog.modelsFor(providerForm.presetId) : []
            providerNameInput.text = resolvedPreset?.name ?? entry?.name ?? ""
            providerEndpointInput.text = resolvedPreset?.endpoint ?? entry?.endpoint ?? ""
            providerModelInput.text = liveModels[0]?.remoteId
                ?? resolvedPreset?.model ?? entry?.model ?? ""
            providerForm.selectedFormat = resolvedPreset?.api_format ?? entry?.api_format ?? "openai"
            providerApiKeyInput.text = ""
            providerForm.expanded = true
        }

        function closeForm() {
            providerForm.expanded = false
            providerForm.editingIndex = -1
            providerNameInput.text = ""
            providerEndpointInput.text = ""
            providerModelInput.text = ""
            providerApiKeyInput.text = ""
            providerForm.selectedFormat = "openai"
            providerForm.presetId = ""
            providerForm.presetKeyId = ""
        }

        WText {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            wrapMode: Text.Wrap
            text: Translation.tr("Choose a provider. iNiR discovers its current models and API protocol automatically.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
        }

        Repeater {
            model: AiProviderPresets.presets

            delegate: WSettingsButton {
                id: providerChoice
                required property var modelData
                readonly property var preset: providerChoice.modelData
                readonly property var providerState: AiProviderCatalog.stateFor(preset.id)
                readonly property bool connected: providerState.status === "ready"
                readonly property string providerStatus: {
                    if (providerState.status === "loading") return Translation.tr("Refreshing catalog…")
                    if (providerState.status === "ready")
                        return Translation.tr("Key stored · %1 models").arg(providerState.modelCount)
                    if (providerState.status === "catalog-ready")
                        return Translation.tr("%1 models visible · connect to use").arg(providerState.modelCount)
                    if (providerState.status === "needs-key") return Translation.tr("API key required")
                    if (providerState.status === "unavailable")
                        return preset.local ? Translation.tr("Service not running") : Translation.tr("Provider unavailable")
                    return preset.local ? Translation.tr("Detect local service") : Translation.tr("Connect provider")
                }

                label: preset.name
                description: providerStatus
                icon: preset.local ? "desktop"
                    : connected ? "checkmark"
                    : providerState.status === "catalog-ready" ? "lock-closed" : "key"
                buttonText: connected ? Translation.tr("Update")
                    : preset.local ? Translation.tr("Detect") : Translation.tr("Connect")
                buttonIcon: connected ? "settings" : "arrow-right"
                accent: connected
                onButtonClicked: providersCard.openForm(providerChoice.preset, -1)
            }
        }

        // ── Configured providers ─────────────────────────────────────────
        Repeater {
            model: providersCard.extraModels

            delegate: RowLayout {
                id: providerRow
                required property var modelData
                required property int index
                readonly property string providerId: modelData?.provider_id ?? "custom"
                readonly property var preset: AiProviderPresets.byId(providerId)
                readonly property var providerState: AiProviderCatalog.stateFor(providerId)
                readonly property bool guided: preset !== null
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    WText {
                        Layout.fillWidth: true
                        text: providerRow.preset?.name
                            ?? providerRow.modelData?.name
                            ?? providerRow.modelData?.model
                            ?? Translation.tr("Unnamed")
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.fg
                        elide: Text.ElideRight
                    }
                    WText {
                        Layout.fillWidth: true
                        text: providerRow.guided
                            ? (providerRow.providerState.status === "ready"
                                ? Translation.tr("Key stored · %1 live models").arg(providerRow.providerState.modelCount)
                                : providerRow.providerState.status === "catalog-ready"
                                    ? Translation.tr("Catalog available · API key required")
                                    : Translation.tr("Connection needs attention"))
                            : (providersCard.formatLabels[providerRow.modelData?.api_format] ?? "OpenAI")
                                + " · " + (providerRow.modelData?.model ?? "")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                        elide: Text.ElideMiddle
                    }
                }

                WButton {
                    id: editProviderButton
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: providersCard.openForm(providerRow.modelData, providerRow.index)
                    contentItem: FluentIcon {
                        anchors.centerIn: parent
                        icon: "settings"
                        implicitSize: 16
                        color: Looks.colors.subfg
                    }
                    WToolTip {
                        visible: editProviderButton.hovered
                        text: Translation.tr("Edit")
                    }
                }

                WButton {
                    id: removeProviderButton
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: {
                        let models = [...providersCard.extraModels]
                        models.splice(providerRow.index, 1)
                        Config.setNestedValue("ai.extraModels", models)
                    }
                    contentItem: FluentIcon {
                        anchors.centerIn: parent
                        icon: "delete"
                        implicitSize: 16
                        color: Looks.colors.subfg
                    }
                    WToolTip {
                        visible: removeProviderButton.hovered
                        text: Translation.tr("Remove")
                    }
                }
            }
        }

        WText {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            visible: providersCard.extraModels.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Translation.tr("No custom providers. Curated providers are managed above; add a custom endpoint only when it is not already supported.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
        }

        // ── Add / edit form ──────────────────────────────────────────────
        WSettingsButton {
            visible: !providerForm.expanded
            label: Translation.tr("Add custom endpoint")
            description: Translation.tr("For providers that are not already supported above")
            icon: "add"
            buttonText: Translation.tr("Add")
            buttonIcon: "add"
            accent: true
            onButtonClicked: providersCard.openForm(null, -1)
        }

        ColumnLayout {
            id: providerForm
            Layout.fillWidth: true
            spacing: 4

            property bool expanded: false
            property int editingIndex: -1
            property string selectedFormat: "openai"
            property string presetId: ""
            property string presetKeyId: ""
            readonly property var preset: AiProviderPresets.byId(presetId)
            readonly property bool guidedPreset: preset !== null
            readonly property bool hasStoredKey: preset?.keyId
                ? ((KeyringStorage.keyringData?.apiKeys?.[preset.keyId]?.length ?? 0) > 0)
                : false

            visible: expanded

            WSettingsInfoBar {
                visible: providerForm.guidedPreset
                severity: WSettingsInfoBar.Severity.Info
                message: providerForm.preset
                    ? Translation.tr(providerForm.preset.description)
                        + "\n" + Translation.tr("iNiR will discover model IDs and capabilities automatically.")
                    : ""
            }

            WSettingsTextField {
                visible: !providerForm.guidedPreset
                id: providerNameInput
                label: Translation.tr("Provider name")
                icon: "info"
                placeholderText: Translation.tr("e.g. My Claude Proxy")
                onTextEdited: newText => providerNameInput.text = newText
            }

            WSettingsTextField {
                id: providerEndpointInput
                visible: !providerForm.guidedPreset
                label: Translation.tr("API endpoint URL")
                icon: "globe-search"
                placeholderText: "https://api.openai.com/v1/chat/completions"
                onTextEdited: newText => {
                    providerEndpointInput.text = newText
                    // Same auto-detection as the ii page: the format follows the
                    // endpoint unless the user picks one explicitly below.
                    const url = newText.toLowerCase()
                    if (url.includes("generativelanguage.googleapis.com"))
                        providerForm.selectedFormat = "gemini"
                    else if (url.includes("api.anthropic.com") || url.includes("/v1/messages"))
                        providerForm.selectedFormat = "anthropic"
                    else if (url.includes("api.openai.com") || url.includes("/v1/chat/completions"))
                        providerForm.selectedFormat = "openai"
                }
            }

            WSettingsTextField {
                id: providerModelInput
                visible: !providerForm.guidedPreset
                label: Translation.tr("Model code")
                icon: "apps"
                placeholderText: "gpt-4.1"
                onTextEdited: newText => providerModelInput.text = newText
            }

            WSettingsTextField {
                id: providerApiKeyInput
                label: providerForm.preset?.requiresKey
                    ? Translation.tr("API key") : Translation.tr("API key (optional)")
                icon: "key"
                description: Translation.tr("Stored in the system keyring, never in config.json")
                placeholderText: providerForm.hasStoredKey
                    ? Translation.tr("A key is already stored — leave blank to keep it")
                    : "sk-..."
                onTextEdited: newText => providerApiKeyInput.text = newText
            }

            WSettingsChoiceGroup {
                visible: !providerForm.guidedPreset
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                columns: 4
                currentValue: providerForm.selectedFormat
                onSelected: newValue => providerForm.selectedFormat = newValue
                options: [
                    { label: "OpenAI", value: "openai" },
                    { label: "Gemini", value: "gemini" },
                    { label: "Anthropic", value: "anthropic" },
                    { label: Translation.tr("Responses"), value: "openai-response" }
                ]
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                Layout.topMargin: 4
                spacing: 8

                Item { Layout.fillWidth: true }

                WButton {
                    implicitWidth: 90
                    implicitHeight: 32
                    onClicked: providersCard.closeForm()
                    contentItem: WText {
                        anchors.centerIn: parent
                        text: Translation.tr("Cancel")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.fg
                    }
                }

                WButton {
                    implicitWidth: 90
                    implicitHeight: 32
                    colBackground: Looks.colors.accent
                    colBackgroundHover: Looks.colors.accentHover
                    enabled: providerEndpointInput.text.trim() !== ""
                        && providerModelInput.text.trim() !== ""
                        && (!(providerForm.preset?.requiresKey ?? false)
                            || providerApiKeyInput.text.trim().length > 0
                            || providerForm.hasStoredKey)
                    onClicked: {
                        const modelCode = providerModelInput.text.trim()
                        const apiKey = providerApiKeyInput.text.trim()
                        const preset = providerForm.preset
                        const keyId = providerForm.presetKeyId
                            || modelCode.toLowerCase().replace(/[:\/ ]/g, "-")

                        const entry = {
                            name: providerNameInput.text.trim() || modelCode,
                            endpoint: providerEndpointInput.text.trim(),
                            model: modelCode,
                            api_format: providerForm.selectedFormat,
                            requires_key: preset ? !!preset.requiresKey : apiKey.length > 0,
                            key_id: keyId,
                            provider_id: providerForm.presetId || "custom",
                            auth_scheme: preset?.authScheme ?? "strategy",
                            description: preset ? Translation.tr(preset.description) : "",
                            icon: preset?.icon ?? "neurology",
                            key_get_link: preset?.keyGetLink ?? "",
                        }

                        let models = [...providersCard.extraModels]
                        if (preset) {
                            const filtered = models.filter(model =>
                                (model?.provider_id ?? "") !== preset.id)
                            if (filtered.length !== models.length)
                                Config.setNestedValue("ai.extraModels", filtered)
                        } else {
                            if (providerForm.editingIndex >= 0) {
                                const orig = models[providerForm.editingIndex]
                                if (orig) {
                                    for (let k in orig) {
                                        if (!(k in entry) && k !== "index") entry[k] = orig[k]
                                    }
                                }
                                models[providerForm.editingIndex] = entry
                            } else {
                                models.push(entry)
                            }
                            Config.setNestedValue("ai.extraModels", models)
                        }

                        if (apiKey.length > 0)
                            KeyringStorage.setNestedField(["apiKeys", keyId], apiKey)
                        if (providerForm.presetId.length > 0)
                            Qt.callLater(() => AiProviderCatalog.refreshProvider(providerForm.presetId))

                        providersCard.closeForm()
                    }
                    contentItem: WText {
                        anchors.centerIn: parent
                        text: providerForm.editingIndex >= 0 ? Translation.tr("Save") : Translation.tr("Add")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.accentFg
                    }
                }
            }
        }
    }

    // ── Assistant behavior ───────────────────────────────────────────────
    WSettingsCard {
        title: Translation.tr("Assistant behavior")
        icon: "wand"

        WSettingsTextField {
            id: systemPromptInput
            label: Translation.tr("AI system prompt")
            icon: "info"
            description: Translation.tr("Custom instructions the assistant always receives")
            placeholderText: Translation.tr("System prompt")
            text: Config.options?.ai?.systemPrompt ?? ""
            onTextEdited: newText => {
                systemPromptInput.text = newText
                Config.setNestedValue("ai.systemPrompt", newText)
            }
        }

        WSettingsRow {
            label: Translation.tr("AI tools")
            icon: "settings-cog-multiple"
            description: Translation.tr("Shell tools use typed actions and configuration previews. Raw commands are isolated in Advanced mode.")
        }

        WSettingsChoiceGroup {
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            columns: 4
            currentValue: Config.options?.ai?.tool ?? "search"
            onSelected: newValue => Config.setNestedValue("ai.tool", newValue)
            options: [
                { label: Translation.tr("Shell tools"), value: "functions" },
                { label: Translation.tr("Search"), value: "search" },
                { label: Translation.tr("Advanced"), value: "advanced" },
                { label: Translation.tr("None"), value: "none" }
            ]
        }

        WSettingsSlider {
            label: Translation.tr("Temperature")
            icon: "flash-on"
            description: Translation.tr("Higher is more creative, lower is more predictable. Default 0.5")
            from: 0
            to: 1
            stepSize: 0.05
            displayDecimals: 2
            value: Persistent.states?.ai?.temperature ?? 0.5
            onMoved: {
                if (Persistent.states?.ai)
                    Persistent.states.ai.temperature = Math.round(value * 100) / 100
            }
        }
    }

    // ── Privacy ──────────────────────────────────────────────────────────
    WSettingsCard {
        title: Translation.tr("Privacy & policy")
        icon: "shield"

        WSettingsRow {
            label: Translation.tr("Allow AI features")
            icon: "shield"
            description: Translation.tr("Local only restricts the assistant to models running on this machine, such as Ollama or LM Studio")
        }

        WSettingsChoiceGroup {
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            columns: 3
            currentValue: Config.options?.policies?.ai ?? 0
            onSelected: newValue => Config.setNestedValue("policies.ai", newValue)
            options: [
                { label: Translation.tr("No"), value: 0 },
                { label: Translation.tr("Yes"), value: 1 },
                { label: Translation.tr("Local only"), value: 2 }
            ]
        }
    }

    // ── Voice input ──────────────────────────────────────────────────────
    WSettingsCard {
        title: Translation.tr("Voice input")
        icon: "mic"

        WSettingsRow {
            label: Translation.tr("Transcription backend")
            icon: "mic"
            description: Translation.tr("Auto prefers local Whisper, then connected online speech providers")
        }

        WSettingsChoiceGroup {
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            columns: 5
            currentValue: Config.options?.voiceSearch?.provider ?? "auto"
            onSelected: newValue => Config.setNestedValue("voiceSearch.provider", newValue)
            options: [
                { label: Translation.tr("Auto"), value: "auto" },
                { label: Translation.tr("Local"), value: "local" },
                { label: "Groq", value: "groq" },
                { label: "Gemini", value: "gemini" },
                { label: "OpenAI", value: "openai" }
            ]
        }

        WSettingsInfoBar {
            severity: VoiceSearch.hasBackend
                ? WSettingsInfoBar.Severity.Success : WSettingsInfoBar.Severity.Warning
            message: VoiceSearch.hasBackend
                ? Translation.tr("Active backend: %1").arg(VoiceSearch.backendLabel)
                : Translation.tr("No backend is ready. Connect a speech provider or install whisper.cpp locally.")
        }

        WSettingsButton {
            label: VoiceSearch.localAvailable
                ? Translation.tr("Local Whisper detected")
                : Translation.tr("Local Whisper not detected")
            description: VoiceSearch.detectedLocalModel
            icon: "desktop"
            buttonText: Translation.tr("Refresh")
            buttonIcon: "arrow-sync"
            onButtonClicked: VoiceSearch.refreshBackends()
        }

        WSettingsRow {
            label: Translation.tr("Language")
            icon: "globe-search"
            description: Translation.tr("Auto detect is recommended for multilingual dictation")
        }

        WSettingsChoiceGroup {
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            columns: 4
            currentValue: Config.options?.voiceSearch?.language ?? "auto"
            onSelected: newValue => Config.setNestedValue("voiceSearch.language", newValue)
            options: [
                { label: Translation.tr("Auto"), value: "auto" },
                { label: Translation.tr("Spanish"), value: "es" },
                { label: Translation.tr("English"), value: "en" },
                { label: Translation.tr("Portuguese"), value: "pt" },
                { label: Translation.tr("French"), value: "fr" },
                { label: Translation.tr("German"), value: "de" },
                { label: Translation.tr("Japanese"), value: "ja" }
            ]
        }

        WSettingsSpinBox {
            id: voiceDurationSpin
            // Without the guard the spin box writes its own default over the
            // user's value while the page is still being created.
            property bool _ready: false
            Component.onCompleted: _ready = true

            label: Translation.tr("Voice input")
            icon: "timer"
            description: Translation.tr("Max recording length for the chat mic button and voice search")
            suffix: Translation.tr(" s")
            from: 3
            to: 60
            stepSize: 1
            value: Config.options?.voiceSearch?.duration ?? 8
            onValueChanged: {
                if (voiceDurationSpin._ready)
                    Config.setNestedValue("voiceSearch.duration", value)
            }
        }

        WText {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            wrapMode: Text.Wrap
            text: Translation.tr("The same backend is used for chat dictation and voice web search. Keys are passed through the process environment and never written to commands or config files.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
        }
    }
}
