pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.services.ai
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Capability-aware model picker for the AI chat.
 *
 * Catalog visibility and execution readiness are intentionally separate:
 * public catalogs remain browseable before connection, while locked rows open
 * Settings instead of selecting a model that would fail authentication.
 */
Item {
    id: root

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    property bool expanded: false
    property string filter: ""
    property string catalogFilter: "recommended"
    // The popup is positioned inside the actual AiChat surface. PanelWindow
    // spans the full output and therefore is not a valid horizontal boundary.
    property Item containmentItem: null

    readonly property var currentModel: Ai.getModel()
    readonly property string currentName: currentModel?.name ?? Translation.tr("Select model")
    readonly property var catalogFilters: [
        { id: "recommended", label: Translation.tr("Recommended"), icon: "auto_awesome" },
        { id: "available", label: Translation.tr("Available"), icon: "check_circle" },
        { id: "free", label: Translation.tr("Free"), icon: "money_off" },
        { id: "local", label: Translation.tr("Local"), icon: "computer" },
        { id: "vision", label: Translation.tr("Vision"), icon: "image" },
        { id: "coding", label: Translation.tr("Coding"), icon: "code" },
        { id: "all", label: Translation.tr("All"), icon: "apps" },
    ]

    readonly property var entries: {
        const out = []
        const query = root.filter.trim().toLowerCase()
        const recommended = new Set(Ai.recommendedModelIds("auto", 18))

        for (const id of (Ai.modelList ?? [])) {
            const model = Ai.models[id]
            if (!model) continue

            const provider = AiProviderCatalog.providerById(model.provider_id ?? "")
            const state = AiProviderCatalog.stateFor(model.provider_id ?? "")
            const name = model.name ?? id
            const providerName = provider?.name
                ?? (model.provider_id === "custom" ? Translation.tr("Custom") : "")
            const capabilities = model.capabilities ?? ({})
            const local = model.local === true
            const free = model.free === true
            const ready = Ai.modelCanRun(model)
            const searchable = (name + " " + id + " " + (model.model ?? "")
                + " " + providerName + " " + (model.description ?? "")).toLowerCase()

            if (query.length > 0 && !searchable.includes(query)) continue
            if (root.catalogFilter === "recommended" && !recommended.has(id)) continue
            if (root.catalogFilter === "available" && !ready) continue
            if (root.catalogFilter === "free" && !free) continue
            if (root.catalogFilter === "local" && !local) continue
            if (root.catalogFilter === "vision" && capabilities.vision !== "supported") continue
            if (root.catalogFilter === "coding") {
                const codeLabel = ((model.model ?? "") + " " + name).toLowerCase()
                const codeNamed = /code|coder|codex|devstral|codestral/.test(codeLabel)
                if (capabilities.toolCalling !== "supported" && !codeNamed) continue
            }

            out.push({
                id,
                name,
                icon: model.icon ?? "neurology",
                description: model.description ?? "",
                providerId: model.provider_id ?? "",
                providerName,
                requiresKey: !!model.requires_key,
                ready,
                hasKey: Ai.hasApiKeyForModel(model),
                isLocal: local,
                isFree: free,
                capabilities,
                contextTokens: model.context_tokens ?? 0,
                status: state.status ?? model.catalog_status ?? "available",
            })
        }
        return out
    }
    readonly property int readyEntryCount: entries.filter(entry => entry.ready).length
    readonly property int lockedEntryCount: entries.length - readyEntryCount

    function close(): void {
        root.expanded = false
        root.filter = ""
    }

    // Settings navigation is page-level only; there is no per-provider
    // deep link, so this intentionally takes no provider argument.
    function openProviderSettings(): void {
        root.close()
        GlobalStates.settingsOverlayRequestedPage = 24
        GlobalStates.settingsOverlayOpen = true
    }

    function contextLabel(tokens): string {
        const value = Number(tokens ?? 0)
        if (value >= 1000000)
            return (value / 1000000).toFixed(value % 1000000 === 0 ? 0 : 1) + "M"
        if (value >= 1000) return Math.round(value / 1000) + "K"
        return value > 0 ? String(value) : ""
    }

    RippleButton {
        id: pill
        anchors.left: parent.left
        anchors.top: parent.top
        implicitHeight: 30
        implicitWidth: pillRow.implicitWidth + 20
        width: root.width > 0 ? root.width : implicitWidth
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        onClicked: root.expanded = !root.expanded

        contentItem: RowLayout {
            id: pillRow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            AiModelIcon {
                icon: root.currentModel?.icon ?? "spark-symbolic"
                size: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.currentName
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer2
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            MaterialSymbol {
                visible: !!root.currentModel && !Ai.currentModelReady
                text: "lock"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colError
            }
            MaterialSymbol {
                visible: root.currentModel?.local === true
                text: "shield_lock"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
            MaterialSymbol {
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
            }
        }
    }

    Rectangle {
        id: popup
        anchors.top: pill.bottom
        anchors.topMargin: 6
        z: 100

        readonly property real horizontalInset: 8
        readonly property real availableSurfaceWidth: root.containmentItem?.width ?? 0
        readonly property bool narrowSurface: availableSurfaceWidth < 520
        readonly property real maximumPopupWidth: narrowSurface ? availableSurfaceWidth : 380
        readonly property real targetWidth: Math.max(0,
            Math.min(maximumPopupWidth, availableSurfaceWidth - horizontalInset * 2))
        readonly property real absoluteY: root.mapToItem(null, 0, pill.height + 6).y
        readonly property real availableHeight: {
            const win = root.Window.window
            if (!win) return 480
            return Math.max(220, win.height - absoluteY - 12)
        }
        readonly property real openHeight: Math.min(popupContent.implicitHeight + 16, availableHeight, 500)
        readonly property bool compact: width < 340

        width: targetWidth
        x: {
            const owner = root.containmentItem
            if (!owner || !root.expanded) return 0
            const rootX = root.mapToItem(owner, 0, 0).x
            const centeredX = (owner.width - width) / 2
            const maximumX = Math.max(horizontalInset, owner.width - horizontalInset - width)
            const surfaceX = Math.max(horizontalInset, Math.min(centeredX, maximumX))
            return surfaceX - rootX
        }
        height: root.expanded ? openHeight : 0
        clip: true
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        radius: Appearance.rounding.normal
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
            : Appearance.colors.colLayer3Base
        border.width: 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
            : Appearance.colors.colLayer0Border

        Behavior on height {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        ColumnLayout {
            id: popupContent
            anchors.fill: parent
            anchors.margins: 8
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: Appearance.concentricRadius(Appearance.rounding.normal, 8)
                    color: Appearance.colors.colLayer2

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        text: "search"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colSubtext
                    }
                    StyledTextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 30
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        text: root.filter
                        onTextChanged: root.filter = text

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: Translation.tr("Search models or providers…")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
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
                        text: AiProviderCatalog.refreshing ? "sync" : "refresh"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledToolTip { text: Translation.tr("Refresh live catalogs") }
                }
            }

            Flickable {
                id: filterFlickable
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                contentWidth: filterRow.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                RowLayout {
                    id: filterRow
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: root.catalogFilters
                        delegate: RippleButton {
                            id: filterButton
                            required property var modelData
                            readonly property bool selected: root.catalogFilter === modelData.id
                            Layout.preferredWidth: filterButtonContent.implicitWidth + 14
                            Layout.preferredHeight: 26
                            buttonRadius: Appearance.rounding.full
                            colBackground: selected
                                ? Appearance.colors.colSecondaryContainer : "transparent"
                            colBackgroundHover: selected
                                ? Appearance.colors.colSecondaryContainerHover
                                : Appearance.colors.colLayer2Hover
                            onClicked: root.catalogFilter = modelData.id

                            contentItem: RowLayout {
                                id: filterButtonContent
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    text: filterButton.modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: filterButton.selected
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: filterButton.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: filterButton.selected
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                StyledText {
                    Layout.fillWidth: true
                    text: root.lockedEntryCount > 0
                        ? Translation.tr("%1 available · %2 need connection")
                            .arg(root.readyEntryCount).arg(root.lockedEntryCount)
                        : Translation.tr("%1 available model(s)").arg(root.readyEntryCount)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
                StyledText {
                    visible: AiProviderCatalog.refreshing
                    text: Translation.tr("Refreshing…")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colPrimary
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.margins: 8
                visible: root.entries.length === 0
                text: AiProviderCatalog.refreshing
                    ? Translation.tr("Discovering compatible models…")
                    : Translation.tr("No model matches these filters.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            StyledListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(contentHeight, 354)
                visible: root.entries.length > 0
                clip: true
                model: root.entries
                spacing: 2

                delegate: RippleButton {
                    id: modelRow
                    required property var modelData
                    required property int index
                    width: listView.width
                    implicitHeight: modelRowContent.implicitHeight + 12
                    buttonRadius: Appearance.concentricRadius(Appearance.rounding.normal, 8)
                    readonly property bool isCurrent: modelData.id === Ai.currentModelId
                    colBackground: isCurrent
                        ? Appearance.colors.colSecondaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    opacity: modelData.ready ? 1 : 0.72

                    onClicked: {
                        if (modelData.ready) {
                            Ai.setModel(modelData.id)
                            root.close()
                        } else {
                            root.openProviderSettings()
                        }
                    }

                    contentItem: RowLayout {
                        id: modelRowContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        AiModelIcon {
                            icon: modelRow.modelData.icon
                            size: Appearance.font.pixelSize.larger
                            color: modelRow.isCurrent
                                ? Appearance.colors.colOnSecondaryContainer
                                : modelRow.modelData.ready
                                    ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            StyledText {
                                Layout.fillWidth: true
                                text: modelRow.modelData.name
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: modelRow.isCurrent ? Font.DemiBold : Font.Normal
                                color: modelRow.isCurrent
                                    ? Appearance.colors.colOnSecondaryContainer
                                    : Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const parts = []
                                    if (modelRow.modelData.providerName.length > 0)
                                        parts.push(modelRow.modelData.providerName)
                                    const context = root.contextLabel(modelRow.modelData.contextTokens)
                                    if (context.length > 0) parts.push(context + " ctx")
                                    if (modelRow.modelData.isFree) parts.push(Translation.tr("free"))
                                    if (modelRow.modelData.isLocal) parts.push(Translation.tr("local"))
                                    if (!modelRow.modelData.ready) parts.push(Translation.tr("connect"))
                                    return parts.join(" · ")
                                }
                                visible: text.length > 0
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: modelRow.isCurrent
                                    ? ColorUtils.transparentize(Appearance.colors.colOnSecondaryContainer, 0.25)
                                    : Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }
                        MaterialSymbol {
                            visible: !popup.compact
                                && modelRow.modelData.capabilities.vision === "supported"
                            text: "image"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            visible: !popup.compact
                                && modelRow.modelData.capabilities.toolCalling === "supported"
                            text: "service_toolbox"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            visible: !modelRow.modelData.ready
                            text: "lock"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colError
                        }
                        MaterialSymbol {
                            visible: modelRow.isCurrent
                            text: "check"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    StyledToolTip {
                        text: modelRow.modelData.ready
                            ? modelRow.modelData.description
                            : Translation.tr("Connect %1 in Settings → AI to use this model.")
                                .arg(modelRow.modelData.providerName)
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.expanded
        visible: enabled
        z: -1
        onClicked: root.close()
        propagateComposedEvents: true
    }
}
