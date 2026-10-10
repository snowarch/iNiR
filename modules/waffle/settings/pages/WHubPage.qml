pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.settings

// The community hub in Waffle Settings, laid out like the Store: filter pills, a grid of cards
// with their pictures, and a page per item. Hub owns the catalogue and the installs.
WSettingsPage {
    id: root
    settingsPageIndex: 18
    pageTitle: Translation.tr("Hub")
    pageIcon: "store-microsoft"
    pageDescription: Translation.tr("Widgets, themes and web apps made by people who use iNiR")

    property string kind: ""
    property bool installedOnly: false
    property string query: ""
    property string openId: ""

    readonly property var shown: Hub.items.filter(item => Hub.matches(item, root.kind, root.query, root.installedOnly))
    readonly property var opened: root.openId.length > 0 ? Hub.find(root.openId) : null
    readonly property int gap: Looks.dp(12)
    readonly property int columns: Math.max(1, Math.floor((root.width - Looks.dp(56) + root.gap) / (Looks.dp(250) + root.gap)))
    readonly property bool customCards: Config.options?.waffles?.widgetsPanel?.showCustom ?? true

    readonly property var permissionGlyphs: ({ process: "terminal", network: "globe-search", files: "folder", inject: "wand" })
    readonly property var kindGlyphs: ({ widget: "widgets", theme: "paint-bucket", "iris-theme": "wand", webapp: "globe-search" })

    Component.onCompleted: Hub.ensureLoaded()
    onOpenIdChanged: root.contentY = 0

    function actionOf(item: var): var {
        switch (Hub.stateOf(item)) {
        case "installing": return { text: Translation.tr("Installing…"), busy: true }
        case "updating": return { text: Translation.tr("Updating…"), busy: true }
        case "removing": return { text: Translation.tr("Removing…"), busy: true }
        case "failed": return { text: Translation.tr("Try again"), run: () => item.installed ? Hub.update(item.id) : Hub.install(item.id) }
        case "update": return { text: Translation.tr("Update"), accent: true, run: () => Hub.update(item.id) }
        case "conflict": return { text: Translation.tr("Name taken") }
        case "incompatible": return { text: Translation.tr("Needs iNiR %1").arg(item.minInir) }
        case "get": return { text: Translation.tr("Get"), accent: true, run: () => Hub.install(item.id) }
        }
        if (item.kind === "theme")
            return { text: Translation.tr("Apply"), run: () => Hub.useTheme(item.id) }
        if (item.kind === "widget" && Hub.fits(item, "waffle")) {
            if (root.customCards)
                return { text: Translation.tr("In use") }
            return { text: Translation.tr("Use"), run: () => Config.setNestedValue("waffles.widgetsPanel.showCustom", true) }
        }
        return { text: Translation.tr("Installed") }
    }
    function whereOf(item: var): string {
        return Hub.fits(item, "waffle") ? Hub.whereText(item, "waffle") : Translation.tr("For %1").arg(Hub.familyNames(item))
    }

    // ── Search, filters, state ────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Looks.dp(8)
        visible: root.opened === null

        WTextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Search the hub")
            onTextChanged: searchDelay.restart()
            Timer { id: searchDelay; interval: 140; onTriggered: root.query = searchField.text }
        }
        WButton {
            visible: Hub.updates > 0
            text: Translation.tr("Update all (%1)").arg(Hub.updates)
            colBackground: Looks.colors.accent
            colBackgroundHover: Looks.colors.accentHover
            colForeground: Looks.colors.accentFg
            font.pixelSize: Looks.font.pixelSize.normal
            onClicked: Hub.updateAll()
        }
        WBorderlessButton {
            implicitWidth: Looks.dp(36)
            implicitHeight: Looks.dp(36)
            enabled: !Hub.loading
            contentItem: FluentIcon { anchors.centerIn: parent; icon: "arrow-sync"; implicitSize: Looks.dp(18) }
            onClicked: Hub.refresh(true)
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.opened === null
        spacing: Looks.dp(8)
        FilterPill {
            text: Translation.tr("Everything")
            checked: root.kind === ""
            onClicked: root.kind = ""
        }
        Repeater {
            model: Hub.kinds
            delegate: FilterPill {
                required property var modelData
                text: Translation.tr(modelData.label)
                checked: root.kind === modelData.id
                onClicked: root.kind = root.kind === modelData.id ? "" : modelData.id
            }
        }
        FilterPill {
            text: Translation.tr("Installed")
            checked: root.installedOnly
            onClicked: root.installedOnly = !root.installedOnly
        }
    }

    WSettingsInfoBar {
        Layout.fillWidth: true
        visible: Hub.loaded && (!Hub.online || Hub.error.length > 0)
        severity: WSettingsInfoBar.Severity.Warning
        message: !Hub.online ? Translation.tr("You're offline: this is the list from the last time the hub answered")
            : Hub.items.length > 0 ? Translation.tr("The hub didn't answer: this is the list from the last time it did")
            : Translation.tr("The hub didn't answer. Check your connection and try again")
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Looks.dp(32)
        visible: !Hub.loaded || (root.opened === null && root.shown.length === 0)
        spacing: Looks.dp(8)
        FluentIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: !Hub.loaded ? "arrow-sync" : root.query.length > 0 ? "search" : "store-microsoft"
            implicitSize: Looks.dp(36)
            color: Looks.colors.subfg
        }
        WText {
            Layout.alignment: Qt.AlignHCenter
            color: Looks.colors.subfg
            text: !Hub.loaded ? Translation.tr("Reading the hub…")
                : root.query.length > 0 ? Translation.tr("Nothing matches “%1”").arg(root.query)
                : root.installedOnly ? Translation.tr("Nothing installed from the hub yet")
                : Translation.tr("Nothing here yet")
        }
    }

    // ── The grid ──────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        visible: root.opened === null && root.shown.length > 0
        columns: root.columns
        columnSpacing: root.gap
        rowSpacing: root.gap
        Repeater {
            model: root.shown
            delegate: ItemCard {}
        }
    }

    // ── One item ──────────────────────────────────────────────────────
    Loader {
        Layout.fillWidth: true
        active: root.opened !== null
        visible: active
        sourceComponent: ItemPage {
            item: root.opened
        }
    }

    // ── Sources ───────────────────────────────────────────────────────
    WSettingsCard {
        visible: root.opened === null
        title: Translation.tr("Sources")
        icon: "globe-shield"
        description: Translation.tr("Everything in the official hub is reviewed before it is published. Other sources are not: add only the ones you trust.")
        collapsible: true
        expanded: false

        Repeater {
            model: Hub.sources
            delegate: WSettingsRow {
                id: sourceRow
                required property var modelData
                readonly property bool extra: Hub.extraSources.includes(modelData.source)
                enableSettingsSearch: false
                icon: modelData.error ? "alert" : extra ? "folder" : "shield"
                label: modelData.name || modelData.source
                description: modelData.error && modelData.count === 0 ? Translation.tr("Didn't answer")
                    : Translation.tr("%1 items · %2").arg(modelData.count).arg(modelData.source)
                control: Component {
                    WBorderedButton {
                        visible: sourceRow.extra
                        text: Translation.tr("Remove")
                        onClicked: Hub.removeSource(sourceRow.modelData.source)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Looks.dp(6)
            spacing: Looks.dp(8)
            WTextField {
                id: sourceField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Address of an index.json, or a folder")
                onAccepted: addButton.clicked()
            }
            WBorderedButton {
                id: addButton
                text: Translation.tr("Add")
                enabled: sourceField.text.trim().length > 0
                onClicked: {
                    Hub.addSource(sourceField.text)
                    sourceField.text = ""
                }
            }
        }
    }

    // ── Pieces ────────────────────────────────────────────────────────

    component FilterPill: WButton {
        id: pill
        implicitHeight: Looks.dp(32)
        horizontalPadding: Looks.dp(14)
        radius: height / 2
        colBackground: Looks.settings.tile
        colBackgroundHover: Looks.settings.tileHover
        colBackgroundActive: Looks.settings.tilePressed
        font.pixelSize: Looks.font.pixelSize.normal
        border.width: pill.checked ? 0 : 1
        border.color: Looks.settings.stroke
    }

    component Preview: ClippingRectangle {
        id: preview
        property var item
        color: Looks.colors.bg2
        Image {
            id: previewImage
            anchors.fill: parent
            source: preview.item?.previewUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Math.ceil(preview.width * 2)
            sourceSize.height: Math.ceil(preview.height * 2)
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0 }
            }
        }
        FluentIcon {
            anchors.centerIn: parent
            visible: previewImage.status !== Image.Ready
            icon: root.kindGlyphs[preview.item?.kind] ?? "apps"
            implicitSize: Math.round(preview.height * 0.26)
            color: Looks.colors.subfg
        }
    }

    component ActionButton: WButton {
        id: action
        property var item
        readonly property var plan: root.actionOf(action.item)
        text: action.plan.text
        enabled: typeof action.plan.run === "function"
        horizontalPadding: Looks.dp(14)
        font.pixelSize: Looks.font.pixelSize.normal
        colBackground: action.plan.accent ? Looks.colors.accent : Looks.settings.tile
        colBackgroundHover: action.plan.accent ? Looks.colors.accentHover : Looks.settings.tileHover
        colBackgroundActive: action.plan.accent ? Looks.colors.accentActive : Looks.settings.tilePressed
        colForeground: action.plan.accent ? Looks.colors.accentFg : Looks.colors.fg
        border.width: action.plan.accent ? 0 : 1
        border.color: Looks.settings.stroke
        onClicked: action.plan.run()
    }

    component ItemCard: ClippingRectangle {
        id: card
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredWidth: Looks.dp(250)
        implicitHeight: cardColumn.implicitHeight
        radius: Looks.settings.radiusXLarge
        color: cardHover.hovered ? Looks.settings.tileHover : Looks.settings.tile
        border.width: 1
        border.color: Looks.settings.stroke

        HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.openId = card.modelData.id }

        ColumnLayout {
            id: cardColumn
            width: card.width
            spacing: 0
            Preview {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(card.width * 10 / 16)
                item: card.modelData
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Looks.dp(14)
                spacing: Looks.dp(2)
                WText {
                    Layout.fillWidth: true
                    text: card.modelData.name
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Looks.font.weight.strong
                    elide: Text.ElideRight
                }
                WText {
                    Layout.fillWidth: true
                    text: [Translation.tr(Hub.kindLabel(card.modelData.kind)), Array.from(card.modelData.authors ?? []).join(", ")]
                        .filter(part => part.length > 0).join(" · ")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                    elide: Text.ElideRight
                }
                WText {
                    id: summary
                    Layout.fillWidth: true
                    Layout.topMargin: Looks.dp(4)
                    Layout.preferredHeight: Math.ceil(summaryMetrics.lineSpacing * 2)
                    text: card.modelData.summary ?? ""
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.fg1
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignTop
                    FontMetrics { id: summaryMetrics; font: summary.font }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Looks.dp(10)
                    spacing: Looks.dp(6)
                    WText {
                        Layout.fillWidth: true
                        text: root.whereOf(card.modelData)
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: Array.from(card.modelData.permissions ?? [])
                        delegate: FluentIcon {
                            required property string modelData
                            icon: root.permissionGlyphs[modelData] ?? "shield"
                            implicitSize: Looks.dp(16)
                            color: Looks.colors.accent
                        }
                    }
                    ActionButton {
                        item: card.modelData
                    }
                }
            }
        }
    }

    component ItemPage: ColumnLayout {
        id: page
        property var item
        spacing: Looks.dp(12)

        WBorderlessButton {
            implicitHeight: Looks.dp(32)
            contentItem: RowLayout {
                spacing: Looks.dp(8)
                FluentIcon { icon: "arrow-left"; implicitSize: Looks.dp(16) }
                WText { text: Translation.tr("Hub"); font.pixelSize: Looks.font.pixelSize.normal }
            }
            onClicked: root.openId = ""
        }

        WSettingsCard {
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Looks.dp(6)
                Layout.bottomMargin: Looks.dp(6)
                spacing: Looks.dp(18)
                Preview {
                    Layout.preferredWidth: Math.round(Math.min(Looks.dp(360), page.width * 0.5))
                    Layout.preferredHeight: Math.round(Layout.preferredWidth * 10 / 16)
                    Layout.alignment: Qt.AlignTop
                    radius: Looks.settings.radiusLarge
                    item: page.item
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Looks.dp(4)
                    WText {
                        Layout.fillWidth: true
                        text: page.item?.name ?? ""
                        font.pixelSize: Looks.font.pixelSize.xlarger
                        font.weight: Looks.font.weight.stronger
                        wrapMode: Text.WordWrap
                    }
                    WText {
                        Layout.fillWidth: true
                        text: Translation.tr("By %1").arg(Array.from(page.item?.authors ?? []).join(", "))
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.subfg
                    }
                    WText {
                        Layout.fillWidth: true
                        Layout.topMargin: Looks.dp(6)
                        text: page.item?.summary ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        wrapMode: Text.WordWrap
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: Looks.dp(10)
                        spacing: Looks.dp(8)
                        ActionButton {
                            item: page.item
                        }
                        WBorderedButton {
                            visible: Boolean(page.item?.installed) && Hub.stateOf(page.item) !== "removing"
                            text: Translation.tr("Remove")
                            onClicked: Hub.remove(page.item.id)
                        }
                        WBorderedButton {
                            visible: String(page.item?.page ?? "").length > 0
                            text: Translation.tr("See its files")
                            onClicked: Qt.openUrlExternally(page.item.page)
                        }
                    }
                }
            }
        }

        WText {
            Layout.fillWidth: true
            Layout.leftMargin: Looks.dp(4)
            visible: text.length > 0
            text: page.item?.description ?? ""
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.fg1
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }

        WSettingsCard {
            title: Translation.tr("About it")
            icon: "info"
            Repeater {
                model: [
                    { icon: "desktop", label: Translation.tr("Where"), value: root.whereOf(page.item) },
                    { icon: "apps", label: Translation.tr("Works in"), value: Hub.familyNames(page.item) },
                    { icon: "arrow-sync", label: Translation.tr("Version"), value: page.item?.installed && page.item.installed !== page.item.version
                        ? Translation.tr("%1 (you have %2)").arg(page.item.version).arg(page.item.installed) : String(page.item?.version ?? "") },
                    { icon: "schedule", label: Translation.tr("Updated"), value: String(page.item?.updated ?? "") },
                    { icon: "library", label: Translation.tr("License"), value: String(page.item?.license ?? "") },
                    { icon: "server", label: Translation.tr("Size"), value: page.item?.size ? Hub.sizeText(page.item.size) : "" },
                    { icon: "globe-shield", label: Translation.tr("From"), value: String(page.item?.sourceName || page.item?.source || "") }
                ].filter(row => row.value.length > 0)
                delegate: WSettingsRow {
                    required property var modelData
                    enableSettingsSearch: false
                    icon: modelData.icon
                    label: modelData.label
                    description: modelData.value
                }
            }
        }

        WSettingsCard {
            title: Array.from(page.item?.permissions ?? []).length > 0 ? Translation.tr("What it can do") : Translation.tr("Nothing beyond the shell")
            icon: "shield"
            description: Array.from(page.item?.permissions ?? []).length === 0
                ? Translation.tr("It only draws inside the shell: it runs no commands, reaches no websites and reads no files of yours.") : ""
            Repeater {
                model: Array.from(page.item?.permissions ?? [])
                delegate: WSettingsRow {
                    required property string modelData
                    enableSettingsSearch: false
                    icon: root.permissionGlyphs[modelData] ?? "shield"
                    label: Translation.tr(Hub.permissionText[modelData] ?? modelData)
                }
            }
        }
    }
}
