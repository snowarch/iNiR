import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.services.deferred
import qs.services.ai
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    settingsPageIndex: 24
    settingsPageName: Translation.tr("AI")

    Component.onCompleted: Ai.ensureInitialized()

    // ── Setup status ─────────────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: "rocket_launch"
        title: Translation.tr("Get started")

        SettingsGroup {
            component StatusRow: RowLayout {
                id: statusRow
                property string statusIcon: ""
                property bool ok: false
                property string label: ""
                property string detail: ""
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: statusRow.statusIcon
                    iconSize: 20
                    color: statusRow.ok ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: statusRow.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: statusRow.detail.length > 0
                        text: statusRow.detail
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }
                }
                MaterialSymbol {
                    text: statusRow.ok ? "check_circle" : "radio_button_unchecked"
                    iconSize: 18
                    color: statusRow.ok ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }

            StatusRow {
                statusIcon: "smart_toy"
                ok: (Ai.getModel() ?? null) !== null
                label: (Ai.getModel() ?? null) !== null
                    ? Translation.tr("Active model: %1").arg(Ai.getModel().name)
                    : Translation.tr("No model selected")
                detail: Translation.tr("iNiR keeps the selected model and can add live models from connected providers automatically")
            }

            StatusRow {
                statusIcon: "key"
                ok: Ai.currentModelHasApiKey
                label: Ai.currentModelHasApiKey
                    ? Translation.tr("API key stored for the active model")
                    : Translation.tr("The active model needs an API key")
                detail: Ai.currentModelHasApiKey ? "" : Translation.tr("Connect the provider below. Keys are stored in the system keyring.")
            }

            StatusRow {
                readonly property bool localFound: AiProviderCatalog.localModelCount > 0
                    || Ai.modelList.some(m => Ai.models[m]?.local === true)
                statusIcon: "computer"
                ok: localFound
                label: localFound
                    ? Translation.tr("Local models detected")
                    : Translation.tr("No local models")
                detail: localFound ? Translation.tr("%1 local model(s) available").arg(AiProviderCatalog.localModelCount)
                    : Translation.tr("Start Ollama or LM Studio to chat privately without an account or key")
            }

            StatusRow {
                statusIcon: AiProviderCatalog.refreshing ? "sync" : "cloud_sync"
                ok: AiProviderCatalog.availableModelCount > 0
                label: AiProviderCatalog.refreshing
                    ? Translation.tr("Refreshing live model catalogs…")
                    : Translation.tr("%1 live model(s) discovered").arg(AiProviderCatalog.availableModelCount)
                detail: Translation.tr("%1 free · %2 local · %3 connected · %4 browseable")
                    .arg(AiProviderCatalog.freeModelCount)
                    .arg(AiProviderCatalog.localModelCount)
                    .arg(AiProviderCatalog.healthyProviderCount)
                    .arg(AiProviderCatalog.browseableProviderCount)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: Translation.tr("Choose local privacy, a currently free online model, or connect a provider. Model IDs and capabilities are discovered for you.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }

                RippleButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    enabled: !AiProviderCatalog.refreshing
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: AiProviderCatalog.refreshAll()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledToolTip { text: Translation.tr("Refresh model catalogs") }
                }
            }

        }
    }

    // ── Providers ────────────────────────────────────────────────
    SettingsCardSection {
        expanded: true
        icon: "cloud"
        title: Translation.tr("Providers & models")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.bottomMargin: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("AI Providers")
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
                    onClicked: {
                        providerForm.editingIndex = -1
                        providerForm.titleText = Translation.tr("Add custom endpoint")
                        providerForm.saveLabelText = Translation.tr("Add")
                        providerNameInput.text = ""
                        providerEndpointInput.text = ""
                        providerForm.selectedFormat = "openai"
                        providerForm._manualOverride = false
                        providerForm._presetId = ""
                        providerForm._presetKeyId = ""
                        providerModelInput.text = ""
                        providerApiKeyInput.text = ""
                        providerForm.expanded = true
                    }

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
                            text: Translation.tr("Custom endpoint")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: Translation.tr("Choose a provider. iNiR discovers its current models and the correct API protocol automatically.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                columns: width >= 720 ? 2 : 1
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: AiProviderPresets.presets

                    delegate: RippleButton {
                        id: providerCard
                        required property var modelData
                        readonly property var preset: providerCard.modelData
                        readonly property var providerState: AiProviderCatalog.stateFor(preset.id)
                        readonly property var discoveredModels: AiProviderCatalog.modelsFor(preset.id)
                        readonly property bool configured: (Config.options?.ai?.extraModels ?? []).some(m =>
                            (m?.provider_id ?? "") === preset.id
                            || (m?.endpoint ?? "") === preset.endpoint)
                        readonly property bool connected: providerState.status === "ready"
                        readonly property string statusText: {
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

                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        buttonRadius: Appearance.rounding.normal
                        colBackground: connected
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.91)
                            : Appearance.colors.colLayer2
                        colBackgroundHover: connected
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.84)
                            : Appearance.colors.colLayer2Hover

                        onClicked: {
                            providerForm.editingIndex = -1
                            providerForm.titleText = connected
                                ? Translation.tr("Update %1").arg(preset.name)
                                : Translation.tr("Connect %1").arg(preset.name)
                            providerForm.saveLabelText = connected ? Translation.tr("Update") : Translation.tr("Connect")
                            providerNameInput.text = preset.name
                            providerEndpointInput.text = preset.endpoint
                            providerModelInput.text = providerCard.discoveredModels[0]?.remoteId ?? preset.model
                            providerForm.selectedFormat = preset.api_format ?? "openai"
                            providerForm._manualOverride = true
                            providerForm._presetId = preset.id ?? ""
                            providerForm._presetKeyId = preset.keyId ?? ""
                            providerApiKeyInput.text = ""
                            providerForm.expanded = true
                        }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Loader {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                readonly property string iconName: String(providerCard.preset.icon ?? "neurology")
                                readonly property color iconColor: providerCard.connected
                                    ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                                sourceComponent: iconName.endsWith("-symbolic")
                                    && iconName !== "anthropic-symbolic" ? providerThemeIcon : providerMaterialIcon

                                Component {
                                    id: providerThemeIcon
                                    CustomIcon {
                                        source: parent.iconName
                                        colorize: true
                                        color: parent.iconColor
                                    }
                                }
                                Component {
                                    id: providerMaterialIcon
                                    MaterialSymbol {
                                        text: parent.iconName === "anthropic-symbolic" ? "psychology" : parent.iconName
                                        iconSize: 24
                                        color: parent.iconColor
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerCard.preset.name
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer2
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerCard.statusText
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: providerCard.connected
                                        ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }
                            MaterialSymbol {
                                text: providerCard.providerState.status === "loading" ? "sync"
                                    : providerCard.connected ? "check_circle"
                                    : providerCard.providerState.status === "catalog-ready" ? "lock"
                                    : providerCard.preset.local ? "computer" : "arrow_forward"
                                iconSize: Appearance.font.pixelSize.large
                                color: providerCard.connected
                                    ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                        }

                        StyledToolTip {
                            text: Translation.tr(providerCard.preset.description)
                        }
                    }
                }
            }

            Repeater {
                model: Config.options?.ai?.extraModels ?? []

                delegate: Item {
                    id: providerItem
                    required property var modelData
                    required property int index
                    readonly property string providerId: modelData?.provider_id ?? "custom"
                    readonly property var preset: AiProviderPresets.byId(providerId)
                    readonly property var providerState: AiProviderCatalog.stateFor(providerId)
                    readonly property bool guided: preset !== null
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

                            MaterialSymbol {
                                readonly property var formatIcons: ({
                                    "openai": "smart_toy",
                                    "gemini": "auto_awesome",
                                    "mistral": "smart_toy",
                                    "anthropic": "psychology",
                                    "openai-response": "bolt"
                                })
                                text: formatIcons[providerItem.modelData?.api_format] ?? "smart_toy"
                                iconSize: 20
                                color: Appearance.colors.colTertiary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerItem.preset?.name
                                        ?? providerItem.modelData?.name
                                        ?? providerItem.modelData?.model
                                        ?? Translation.tr("Unnamed")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: providerItem.guided
                                        ? (providerItem.providerState.status === "ready"
                                            ? Translation.tr("Key stored · %1 live models").arg(providerItem.providerState.modelCount)
                                            : providerItem.providerState.status === "catalog-ready"
                                                ? Translation.tr("Catalog available · API key required")
                                                : Translation.tr("Connection needs attention"))
                                        : (providerItem.modelData?.model ?? "")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                visible: !providerItem.guided
                                width: visible ? fmtLabel.implicitWidth + 12 : 0
                                height: 22
                                radius: Appearance.rounding.full
                                color: ColorUtils.transparentize(Appearance.colors.colTertiary, 0.88)

                                readonly property var formatLabels: ({
                                    "openai": "OpenAI",
                                    "gemini": "Gemini",
                                    "mistral": "Mistral",
                                    "anthropic": "Anthropic",
                                    "openai-response": "Responses"
                                })

                                StyledText {
                                    id: fmtLabel
                                    anchors.centerIn: parent
                                    text: parent.formatLabels[providerItem.modelData?.api_format] ?? providerItem.modelData?.api_format ?? "OpenAI"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colTertiary
                                }
                            }

                            RippleButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: 14
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const m = providerItem.modelData
                                    const preset = providerItem.preset
                                    const liveModels = preset ? AiProviderCatalog.modelsFor(preset.id) : []
                                    providerForm.editingIndex = providerItem.index
                                    providerForm.titleText = preset
                                        ? Translation.tr("Update %1").arg(preset.name)
                                        : Translation.tr("Edit AI Provider")
                                    providerForm.saveLabelText = Translation.tr("Save")
                                    providerNameInput.text = preset?.name ?? m?.name ?? ""
                                    providerEndpointInput.text = preset?.endpoint ?? m?.endpoint ?? ""
                                    providerForm.selectedFormat = preset?.api_format ?? m?.api_format ?? "openai"
                                    providerForm._manualOverride = true
                                    providerForm._presetId = m?.provider_id ?? ""
                                    providerForm._presetKeyId = preset?.keyId ?? m?.key_id ?? ""
                                    providerModelInput.text = liveModels[0]?.remoteId ?? preset?.model ?? m?.model ?? ""
                                    providerApiKeyInput.text = ""
                                    providerForm.expanded = true
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "edit"
                                    iconSize: 14
                                    color: Appearance.colors.colSubtext
                                }

                                StyledToolTip { text: Translation.tr("Edit") }
                            }

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

                                StyledToolTip { text: Translation.tr("Remove") }
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

            ColumnLayout {
                visible: (Config.options?.ai?.extraModels ?? []).length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "neurology"
                    iconSize: 28
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No custom providers")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Curated providers are managed above. Add a custom endpoint only when it is not already supported.")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                }
            }

            Rectangle {
                id: providerForm
                Layout.fillWidth: true
                Layout.topMargin: 4

                property bool expanded: false
                property int editingIndex: -1
                property string titleText: Translation.tr("Add AI Provider")
                property string saveLabelText: Translation.tr("Add")
                property string selectedFormat: "openai"
                property bool _manualOverride: false
                property string _presetId: ""
                readonly property var _preset: AiProviderPresets.byId(_presetId)
                readonly property bool _guidedPreset: _preset !== null
                readonly property bool _hasStoredPresetKey: _preset?.keyId
                    ? ((KeyringStorage.keyringData?.apiKeys?.[_preset.keyId]?.length ?? 0) > 0)
                    : false
                // Set from preset.keyId on quick-add so the keyring lookup key
                // doesn't drift from what scripts like gemini-translate.sh expect
                // (e.g. "gemini") when the model text differs from the id/text slug.
                property string _presetKeyId: ""

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
                        text: providerForm.titleText
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    SettingsNote {
                        visible: providerForm._guidedPreset
                        icon: providerForm._preset?.local ? "computer" : "cloud_sync"
                        text: providerForm._preset
                            ? Translation.tr(providerForm._preset.description)
                                + "\n\n" + Translation.tr("iNiR will discover the available model IDs and capabilities automatically.")
                            : ""
                    }

                    ColumnLayout {
                        visible: !providerForm._guidedPreset
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
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerNameInput.activeFocus ? 2 : 1
                                border.color: providerNameInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        visible: !providerForm._guidedPreset
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
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerEndpointInput.activeFocus ? 2 : 1
                                border.color: providerEndpointInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }

                            onTextChanged: {
                                if (providerForm._manualOverride) return
                                const url = text.toLowerCase()
                                if (url.includes("generativelanguage.googleapis.com")) {
                                    providerForm.selectedFormat = "gemini"
                                } else if (url.includes("api.anthropic.com") || url.includes("/v1/messages")) {
                                    providerForm.selectedFormat = "anthropic"
                                } else if (url.includes("api.openai.com") || url.includes("/v1/chat/completions")) {
                                    providerForm.selectedFormat = "openai"
                                }
                            }
                        }
                    }

                    ContentSubsection {
                        visible: !providerForm._guidedPreset
                        title: Translation.tr("API format")

                        ConfigSelectionArray {
                            enableSettingsSearch: false
                            options: [
                                { displayName: "OpenAI", icon: "smart_toy", value: "openai" },
                                { displayName: "Gemini", icon: "auto_awesome", value: "gemini" },
                                { displayName: "Anthropic", icon: "psychology", value: "anthropic" },
                                { displayName: Translation.tr("Responses API"), icon: "bolt", value: "openai-response" }
                            ]
                            currentValue: providerForm.selectedFormat
                            onSelected: (newValue) => {
                                providerForm.selectedFormat = newValue
                                providerForm._manualOverride = true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: providerForm.selectedFormat === "openai"
                            text: Translation.tr("Compatible with OpenAI, Mistral, Ollama, OpenRouter, vLLM, and any OpenAI-compatible endpoint.")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        visible: !providerForm._guidedPreset
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
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerModelInput.activeFocus ? 2 : 1
                                border.color: providerModelInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        StyledText {
                            text: providerForm._preset?.requiresKey
                                ? Translation.tr("API key")
                                : Translation.tr("API key (optional)")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }

                        MaterialTextField {
                            id: providerApiKeyInput
                            Layout.fillWidth: true
                            placeholderText: providerForm._hasStoredPresetKey
                                ? Translation.tr("A key is already stored — leave blank to keep it")
                                : "sk-..."
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            echoMode: TextInput.Password
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: providerApiKeyInput.activeFocus ? 2 : 1
                                border.color: providerApiKeyInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                        }
                    }

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
                                providerForm.expanded = false
                                providerForm.editingIndex = -1
                                providerNameInput.text = ""
                                providerEndpointInput.text = ""
                                providerForm.selectedFormat = "openai"
                                providerForm._manualOverride = false
                                providerForm._presetId = ""
                                providerForm._presetKeyId = ""
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
                            enabled: providerEndpointInput.text.trim() !== ""
                                && providerModelInput.text.trim() !== ""
                                && (!(providerForm._preset?.requiresKey ?? false)
                                    || providerApiKeyInput.text.trim().length > 0
                                    || providerForm._hasStoredPresetKey)
                            opacity: enabled ? 1 : 0.5
                            onClicked: {
                                const modelCode = providerModelInput.text.trim()
                                const apiKey = providerApiKeyInput.text.trim()
                                const preset = providerForm._preset
                                const keyId = providerForm._presetKeyId || modelCode.toLowerCase().replace(/[:\/ ]/g, "-")

                                const entry = {
                                    name: providerNameInput.text.trim() || modelCode,
                                    endpoint: providerEndpointInput.text.trim(),
                                    model: modelCode,
                                    api_format: providerForm.selectedFormat,
                                    requires_key: preset ? !!preset.requiresKey : apiKey.length > 0,
                                    key_id: keyId,
                                    provider_id: providerForm._presetId || "custom",
                                    auth_scheme: preset?.authScheme ?? "strategy",
                                    description: preset ? Translation.tr(preset.description) : "",
                                    icon: preset?.icon ?? "neurology",
                                    key_get_link: preset?.keyGetLink ?? "",
                                }

                                let models = [...(Config.options?.ai?.extraModels ?? [])]
                                if (preset) {
                                    // Curated providers are key + live catalog records.
                                    // Remove any legacy hardcoded model row.
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

                                if (apiKey.length > 0) {
                                    KeyringStorage.setNestedField(["apiKeys", keyId], apiKey)
                                }
                                if (providerForm._presetId.length > 0)
                                    Qt.callLater(() => AiProviderCatalog.refreshProvider(providerForm._presetId))

                                providerForm.expanded = false
                                providerForm.editingIndex = -1
                                providerNameInput.text = ""
                                providerEndpointInput.text = ""
                                providerForm.selectedFormat = "openai"
                                providerForm._manualOverride = false
                                providerForm._presetId = ""
                                providerForm._presetKeyId = ""
                                providerModelInput.text = ""
                                providerApiKeyInput.text = ""
                            }

                            contentItem: StyledText {
                                id: saveProviderLabel
                                anchors.centerIn: parent
                                text: providerForm.saveLabelText
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

    // ── Assistant behavior ───────────────────────────────────────
    SettingsCardSection {
        expanded: false
        icon: "psychology"
        title: Translation.tr("Assistant behavior")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("System prompt")
                tooltip: Translation.tr("Custom instructions the assistant always receives")

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

            ContentSubsection {
                title: Translation.tr("Default tool mode")
                tooltip: Translation.tr("What the assistant is allowed to do.")

                ConfigSelectionArray {
                    enableSettingsSearch: false
                    currentValue: Config.options?.ai?.tool ?? "search"
                    onSelected: newValue => {
                        Config.setNestedValue("ai.tool", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Shell tools"), icon: "service_toolbox", value: "functions" },
                        { displayName: Translation.tr("Search"), icon: "search", value: "search" },
                        { displayName: Translation.tr("Advanced"), icon: "terminal", value: "advanced" },
                        { displayName: Translation.tr("None"), icon: "block", value: "none" }
                    ]
                }

                SettingsNote {
                    icon: "service_toolbox"
                    text: Config.options?.ai?.tool === "advanced"
                        ? Translation.tr("Advanced also exposes raw shell commands. Every command still requires approval.")
                        : Translation.tr("Shell configuration changes show a typed preview and require approval. Search appears only when the selected provider supports it.")
                }
            }

            ContentSubsection {
                title: Translation.tr("Temperature")
                tooltip: Translation.tr("Higher = more creative, lower = more predictable. Default 0.5")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        text: "device_thermostat"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledSlider {
                        id: temperatureSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        stepSize: 0.05
                        value: Persistent.states?.ai?.temperature ?? 0.5
                        configuration: StyledSlider.Configuration.S
                        tooltipContent: value.toFixed(2)
                        onMoved: {
                            if (Persistent.states?.ai) Persistent.states.ai.temperature = Math.round(value * 100) / 100;
                        }
                    }
                    StyledText {
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignRight
                        text: temperatureSlider.value.toFixed(2)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    // ── Privacy ──────────────────────────────────────────────────
    SettingsCardSection {
        expanded: false
        icon: "policy"
        title: Translation.tr("Privacy & policy")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Allow AI features")
                tooltip: Translation.tr("Local only restricts the assistant to models running on this machine, such as Ollama or LM Studio")

                ConfigSelectionArray {
                    enableSettingsSearch: false
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
        }
    }

    // ── Voice input ──────────────────────────────────────────────
    SettingsCardSection {
        expanded: false
        icon: "mic"
        title: Translation.tr("Voice input")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Transcription backend")
                tooltip: Translation.tr("Auto prefers local Whisper, then connected online speech providers")

                ConfigSelectionArray {
                    enableSettingsSearch: false
                    currentValue: Config.options?.voiceSearch?.provider ?? "auto"
                    onSelected: newValue => Config.setNestedValue("voiceSearch.provider", newValue)
                    options: [
                        { displayName: Translation.tr("Auto"), icon: "auto_awesome", value: "auto" },
                        { displayName: Translation.tr("Local Whisper"), icon: "shield_lock", value: "local" },
                        { displayName: "Groq", icon: "bolt", value: "groq" },
                        { displayName: "Gemini", icon: "auto_awesome", value: "gemini" },
                        { displayName: "OpenAI", icon: "neurology", value: "openai" }
                    ]
                }

                SettingsNote {
                    icon: VoiceSearch.hasBackend ? "check_circle" : "info"
                    text: VoiceSearch.hasBackend
                        ? Translation.tr("Active backend: %1").arg(VoiceSearch.backendLabel)
                        : Translation.tr("No backend is ready. Connect Groq, Gemini or OpenAI above, or install whisper.cpp with a local model.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: VoiceSearch.localAvailable
                            ? Translation.tr("Local Whisper detected")
                            : Translation.tr("Local Whisper not detected")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: VoiceSearch.refreshBackends()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 17
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Language")
                ConfigSelectionArray {
                    enableSettingsSearch: false
                    currentValue: Config.options?.voiceSearch?.language ?? "auto"
                    onSelected: newValue => Config.setNestedValue("voiceSearch.language", newValue)
                    options: [
                        { displayName: Translation.tr("Auto detect"), icon: "translate", value: "auto" },
                        { displayName: Translation.tr("Spanish"), icon: "language", value: "es" },
                        { displayName: Translation.tr("English"), icon: "language", value: "en" },
                        { displayName: Translation.tr("Portuguese"), icon: "language", value: "pt" },
                        { displayName: Translation.tr("French"), icon: "language", value: "fr" },
                        { displayName: Translation.tr("German"), icon: "language", value: "de" },
                        { displayName: Translation.tr("Japanese"), icon: "language", value: "ja" }
                    ]
                }
            }

            ConfigSpinBox {
                id: voiceDurationSpin
                // Without the guard the spin box writes its own default over the
                // user's value while the page is still being created.
                property bool _ready: false
                Component.onCompleted: _ready = true

                icon: "timer"
                text: Translation.tr("Max recording length (seconds)")
                value: Config.options?.voiceSearch?.duration ?? 5
                from: 3
                to: 60
                stepSize: 1
                onValueChanged: {
                    if (voiceDurationSpin._ready)
                        Config.setNestedValue("voiceSearch.duration", value)
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: Translation.tr("The same backend is used for chat dictation and voice web search. Keys are passed through the process environment and are never written to commands or config files.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }
}
