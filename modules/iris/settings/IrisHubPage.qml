pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// The community hub in iRiS Settings. Hub owns the catalogue and the installs; this page shows them
// as reading cards with their pictures, and opens one item as a page of its own. Widgets go to the
// Island when they have a module for it; iRiS themes apply through IrisThemes like a saved one.
Flickable {
    id: root

    readonly property real d: IrisStyle.density
    property string kind: ""
    property bool installedOnly: false
    property string query: ""
    property string openId: ""

    readonly property var shown: Hub.items.filter(item => Hub.matches(item, root.kind, root.query, root.installedOnly))
    readonly property var opened: root.openId.length > 0 ? Hub.find(root.openId) : null
    readonly property real columnWidth: Math.min(root.width - Math.round(32 * root.d), Math.round(680 * root.d))
    readonly property real cardWidth: Math.floor((root.columnWidth - Math.round(12 * root.d)) / 2)

    readonly property var permissionGlyphs: ({ process: "terminal", network: "public", files: "folder_open", inject: "code" })
    readonly property var kindGlyphs: ({ widget: "widgets", theme: "palette", "iris-theme": "style", webapp: "language" })

    boundsBehavior: Flickable.StopAtBounds
    clip: true
    contentHeight: pageColumn.implicitHeight + Math.round(40 * root.d)
    ScrollBar.vertical: IrisScrollBar {}

    Component.onCompleted: {
        Hub.ensureLoaded()
        if (Hub.requestedId.length > 0)
            root.openId = Hub.takeRequest()
    }
    Connections {
        target: Hub
        function onRequestedIdChanged(): void {
            if (Hub.requestedId.length > 0)
                root.openId = Hub.takeRequest()
        }
    }
    onOpenIdChanged: root.contentY = 0

    function actionOf(item: var): var {
        switch (Hub.stateOf(item)) {
        case "installing": return { text: Translation.tr("Installing…"), busy: true }
        case "updating": return { text: Translation.tr("Updating…"), busy: true }
        case "removing": return { text: Translation.tr("Removing…"), busy: true }
        case "failed": return { text: Translation.tr("Try again"), danger: true, run: () => item.installed ? Hub.update(item.id) : Hub.install(item.id) }
        case "update": return { text: Translation.tr("Update"), strong: true, run: () => Hub.update(item.id) }
        case "conflict": return { text: Translation.tr("Name taken") }
        case "incompatible": return { text: Translation.tr("Needs iNiR %1").arg(item.minInir) }
        case "get": return { text: Translation.tr("Get"), strong: true, run: () => Hub.install(item.id) }
        }
        if (item.kind === "iris-theme") {
            if (IrisThemes.activeId === item.id)
                return { text: Translation.tr("In use") }
            return { text: Translation.tr("Apply"), run: () => root.applyTheme(item.id) }
        }
        if (item.kind === "widget" && Hub.fits(item, "iris")) {
            if (Hub.widgetInUse(item.id, "iris"))
                return { text: Translation.tr("In use") }
            return { text: Translation.tr("Use"), run: () => Hub.useWidget(item.id, "iris") }
        }
        return { text: Translation.tr("Installed") }
    }
    function whereOf(item: var): string {
        return Hub.fits(item, "iris") ? Hub.whereText(item, "iris") : Translation.tr("For %1").arg(Hub.familyNames(item))
    }
    function applyTheme(id: string): void {
        const theme = IrisThemes.find(id)
        if (theme)
            IrisThemes.choose(theme)
    }

    ColumnLayout {
        id: pageColumn
        width: root.columnWidth
        x: Math.round((root.width - width) / 2)
        y: Math.round(18 * root.d)
        spacing: Math.round(16 * root.d)

        // ── Identity, search, kinds ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * root.d)
            Rectangle {
                implicitWidth: Math.round(40 * root.d)
                implicitHeight: implicitWidth
                radius: IrisStyle.iconRadius(width)
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.tileTop(IrisStyle.identity.pink) }
                    GradientStop { position: 1; color: IrisStyle.identity.pink }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "storefront"
                    fill: 1
                    iconSize: Math.round(22 * root.d)
                    color: IrisStyle.onTint
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                    text: Translation.tr("Made by people who use iNiR")
                }
                IrisText {
                    Layout.fillWidth: true
                    role: IrisText.Meta
                    elide: Text.ElideRight
                    text: !Hub.loaded ? Translation.tr("Reading the hub…")
                        : !Hub.online ? Translation.tr("Offline · the list from the last time the hub answered")
                        : Hub.error.length > 0 ? Translation.tr("The hub didn't answer · the list from the last time it did")
                        : Hub.updates > 0 ? Translation.tr("%1 updates waiting").arg(Hub.updates)
                        : Translation.tr("%1 in the hub · %2 installed").arg(Hub.items.length).arg(Hub.items.filter(item => item.installed).length)
                }
            }
            IrisButton {
                visible: Hub.updates > 0
                emphasized: true
                text: Translation.tr("Update all")
                onClicked: Hub.updateAll()
            }
            IrisIconButton {
                materialIcon: "refresh"
                enabled: !Hub.loading
                onClicked: Hub.refresh(true)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.opened === null
            implicitHeight: Math.round(34 * root.d)
            radius: height / 2
            color: searchField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
            border.width: searchField.activeFocus ? 1 : 0
            border.color: IrisStyle.tintBorder(IrisStyle.accent)
            MaterialSymbol {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                iconSize: Math.round(16 * root.d)
                color: IrisStyle.muted
            }
            TextInput {
                id: searchField
                anchors.left: searchGlyph.right
                anchors.leftMargin: Math.round(6 * root.d)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                color: IrisStyle.text
                selectionColor: IrisStyle.accentContainer
                font.family: IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                clip: true
                onTextChanged: searchDelay.restart()
                Timer { id: searchDelay; interval: 140; onTriggered: root.query = searchField.text }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length === 0
                    text: Translation.tr("Search the hub")
                    color: IrisStyle.muted
                    font.pixelSize: searchField.font.pixelSize
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: root.opened === null
            spacing: Math.round(6 * root.d)
            IrisChip {
                label: Translation.tr("Everything")
                selected: root.kind === ""
                onClicked: root.kind = ""
            }
            Repeater {
                model: Hub.kinds
                delegate: IrisChip {
                    required property var modelData
                    glyph: modelData.icon
                    label: Translation.tr(modelData.label)
                    selected: root.kind === modelData.id
                    onClicked: root.kind = root.kind === modelData.id ? "" : modelData.id
                }
            }
            IrisChip {
                glyph: "download_done"
                label: Translation.tr("Installed")
                selected: root.installedOnly
                onClicked: root.installedOnly = !root.installedOnly
            }
        }

        // ── Empty and unreachable states ──────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(28 * root.d)
            visible: Hub.loaded && root.opened === null && root.shown.length === 0
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.query.length > 0 ? "search_off" : Hub.items.length === 0 ? "cloud_off" : "download_done"
                iconSize: Math.round(36 * root.d)
                color: IrisStyle.textTertiary
            }
            IrisText {
                Layout.alignment: Qt.AlignHCenter
                text: root.query.length > 0 ? Translation.tr("Nothing matches “%1”").arg(root.query)
                    : Hub.items.length === 0 ? Translation.tr("The hub didn't answer. Check your connection and try again")
                    : root.installedOnly ? Translation.tr("Nothing installed from the hub yet")
                    : Translation.tr("Nothing here yet")
            }
            IrisButton {
                Layout.alignment: Qt.AlignHCenter
                visible: Hub.items.length === 0
                text: Translation.tr("Try again")
                onClicked: Hub.refresh(true)
            }
        }

        // ── The shelf ─────────────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            visible: root.opened === null
            spacing: Math.round(12 * root.d)
            Repeater {
                model: root.shown
                delegate: ItemCard {}
            }
        }

        // ── One item ──────────────────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            active: root.opened !== null
            visible: active
            sourceComponent: ItemPage {
                item: root.opened
            }
        }

        // ── Sources ───────────────────────────────────────────────────
        Heading {
            visible: root.opened === null && Hub.loaded
            text: Translation.tr("Sources")
        }
        Rectangle {
            Layout.fillWidth: true
            visible: root.opened === null && Hub.loaded
            implicitHeight: sourceColumn.implicitHeight + Math.round(16 * root.d)
            radius: IrisStyle.radiusTile
            color: IrisStyle.readingCard
            ColumnLayout {
                id: sourceColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(8 * root.d)
                spacing: Math.round(2 * root.d)
                Repeater {
                    model: Hub.sources
                    delegate: RowLayout {
                        id: sourceRow
                        required property var modelData
                        readonly property bool extra: Hub.extraSources.includes(modelData.source)
                        Layout.fillWidth: true
                        Layout.leftMargin: Math.round(8 * root.d)
                        Layout.minimumHeight: Math.round(40 * root.d)
                        spacing: Math.round(10 * root.d)
                        MaterialSymbol {
                            text: sourceRow.modelData.error ? "error" : sourceRow.extra ? "folder_special" : "verified"
                            fill: 1
                            iconSize: Math.round(18 * root.d)
                            color: sourceRow.modelData.error ? IrisStyle.danger : IrisStyle.accent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            IrisText {
                                Layout.fillWidth: true
                                text: sourceRow.modelData.name || sourceRow.modelData.source
                                font.pixelSize: IrisStyle.typeLabel
                                elide: Text.ElideMiddle
                            }
                            IrisText {
                                Layout.fillWidth: true
                                role: IrisText.Meta
                                text: sourceRow.modelData.error && sourceRow.modelData.count === 0 ? Translation.tr("Didn't answer")
                                    : Translation.tr("%1 items · %2").arg(sourceRow.modelData.count).arg(sourceRow.modelData.source)
                                elide: Text.ElideMiddle
                            }
                        }
                        IrisIconButton {
                            visible: sourceRow.extra
                            materialIcon: "delete"
                            onClicked: Hub.removeSource(sourceRow.modelData.source)
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(4 * root.d)
                    implicitHeight: Math.round(34 * root.d)
                    radius: IrisStyle.radiusRow
                    color: sourceInput.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                    TextInput {
                        id: sourceInput
                        anchors.left: parent.left
                        anchors.right: addSource.left
                        anchors.leftMargin: Math.round(12 * root.d)
                        anchors.rightMargin: Math.round(8 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeLabel
                        clip: true
                        onAccepted: addSource.clicked()
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: sourceInput.text.length === 0
                            text: Translation.tr("Address of an index.json, or a folder")
                            color: IrisStyle.muted
                            font.pixelSize: sourceInput.font.pixelSize
                        }
                    }
                    IrisButton {
                        id: addSource
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(2 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        quiet: true
                        text: Translation.tr("Add")
                        enabled: sourceInput.text.trim().length > 0
                        onClicked: {
                            Hub.addSource(sourceInput.text)
                            sourceInput.text = ""
                        }
                    }
                }
            }
        }
        IrisText {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(16 * root.d)
            Layout.rightMargin: Math.round(16 * root.d)
            Layout.topMargin: Math.round(-8 * root.d)
            visible: root.opened === null && Hub.loaded
            role: IrisText.Meta
            wrapMode: Text.WordWrap
            text: Translation.tr("Everything in the official hub is reviewed before it is published. Other sources are not: add only the ones you trust.")
        }
    }

    // ── Pieces ────────────────────────────────────────────────────────

    component Heading: IrisText {
        Layout.leftMargin: Math.round(16 * root.d)
        Layout.bottomMargin: Math.round(-8 * root.d)
        color: IrisStyle.muted
        font.family: IrisStyle.fontTitle
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }

    component Preview: ClippingRectangle {
        id: preview
        property var item
        color: IrisStyle.fillQuiet
        IrisImage {
            id: previewImage
            anchors.fill: parent
            source: preview.item?.previewUrl ?? ""
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                enabled: IrisStyle.motionEnabled
                NumberAnimation { duration: IrisStyle.duration(180) }
            }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: previewImage.status !== Image.Ready
            text: root.kindGlyphs[preview.item?.kind] ?? "extension"
            fill: 1
            iconSize: Math.round(preview.height * 0.28)
            color: IrisStyle.textTertiary
        }
    }

    component ActionButton: IrisButton {
        id: action
        property var item
        readonly property var plan: root.actionOf(action.item)
        text: action.plan.text
        emphasized: Boolean(action.plan.strong)
        danger: Boolean(action.plan.danger)
        quiet: typeof action.plan.run !== "function"
        enabled: typeof action.plan.run === "function"
        onClicked: action.plan.run()
    }

    component ItemCard: ClippingRectangle {
        id: card
        required property var modelData
        width: root.cardWidth
        height: cardColumn.implicitHeight
        radius: IrisStyle.radiusTile
        color: cardHover.hovered ? IrisStyle.fillHover : IrisStyle.readingCard

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
                Layout.margins: Math.round(12 * root.d)
                spacing: Math.round(2 * root.d)
                IrisText {
                    Layout.fillWidth: true
                    text: card.modelData.name
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    role: IrisText.Meta
                    text: [Translation.tr(Hub.kindLabel(card.modelData.kind)), Array.from(card.modelData.authors ?? []).join(", ")]
                        .filter(part => part.length > 0).join(" · ")
                    elide: Text.ElideRight
                }
                IrisText {
                    id: summary
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(4 * root.d)
                    Layout.preferredHeight: Math.ceil(summaryMetrics.lineSpacing * 2)
                    text: card.modelData.summary ?? ""
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeLabel
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignTop
                    FontMetrics { id: summaryMetrics; font: summary.font }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(8 * root.d)
                    spacing: Math.round(6 * root.d)
                    IrisText {
                        Layout.fillWidth: true
                        role: IrisText.Meta
                        font.pixelSize: IrisStyle.typeFootnote
                        text: root.whereOf(card.modelData)
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: Array.from(card.modelData.permissions ?? [])
                        delegate: MaterialSymbol {
                            required property string modelData
                            text: root.permissionGlyphs[modelData] ?? "shield"
                            iconSize: Math.round(16 * root.d)
                            color: IrisStyle.secondaryAccent
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
        spacing: Math.round(16 * root.d)

        IrisButton {
            quiet: true
            text: Translation.tr("‹ Hub")
            onClicked: root.openId = ""
        }
        Preview {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(page.width * 9 / 16)
            radius: IrisStyle.radiusCard
            item: page.item
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * root.d)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(2 * root.d)
                IrisText {
                    Layout.fillWidth: true
                    text: page.item?.name ?? ""
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeTitleLarge
                    font.weight: IrisStyle.weight(Font.Bold)
                    wrapMode: Text.WordWrap
                }
                IrisText {
                    Layout.fillWidth: true
                    role: IrisText.Meta
                    text: Translation.tr("By %1").arg(Array.from(page.item?.authors ?? []).join(", "))
                }
            }
            IrisButton {
                visible: Boolean(page.item?.installed) && Hub.stateOf(page.item) !== "removing"
                danger: true
                quiet: true
                text: Translation.tr("Remove")
                onClicked: Hub.remove(page.item.id)
            }
            ActionButton {
                item: page.item
            }
        }
        IrisText {
            Layout.fillWidth: true
            text: page.item?.summary ?? ""
            wrapMode: Text.WordWrap
        }
        IrisText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: page.item?.description ?? ""
            color: IrisStyle.textSecondary
            font.pixelSize: IrisStyle.typeLabel
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }

        Heading { text: Translation.tr("About it") }
        InfoCard {
            rows: [
                { label: Translation.tr("Where"), value: root.whereOf(page.item) },
                { label: Translation.tr("Works in"), value: Hub.familyNames(page.item) },
                { label: Translation.tr("Version"), value: page.item?.installed && page.item.installed !== page.item.version
                    ? Translation.tr("%1 (you have %2)").arg(page.item.version).arg(page.item.installed) : String(page.item?.version ?? "") },
                { label: Translation.tr("Updated"), value: String(page.item?.updated ?? "") },
                { label: Translation.tr("License"), value: String(page.item?.license ?? "") },
                { label: Translation.tr("Size"), value: page.item?.size ? Hub.sizeText(page.item.size) : "" },
                { label: Translation.tr("From"), value: String(page.item?.sourceName || page.item?.source || "") }
            ].filter(row => row.value.length > 0)
        }

        Heading { text: Array.from(page.item?.permissions ?? []).length > 0 ? Translation.tr("What it can do") : Translation.tr("Nothing beyond the shell") }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: permissionColumn.implicitHeight + Math.round(16 * root.d)
            radius: IrisStyle.radiusTile
            color: IrisStyle.readingCard
            ColumnLayout {
                id: permissionColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(8 * root.d)
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    Layout.margins: Math.round(8 * root.d)
                    visible: Array.from(page.item?.permissions ?? []).length === 0
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeLabel
                    wrapMode: Text.WordWrap
                    text: Translation.tr("It only draws inside the shell: it runs no commands, reaches no websites and reads no files of yours.")
                }
                Repeater {
                    model: Array.from(page.item?.permissions ?? [])
                    delegate: RowLayout {
                        id: permissionRow
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.minimumHeight: Math.round(36 * root.d)
                        Layout.leftMargin: Math.round(8 * root.d)
                        spacing: Math.round(10 * root.d)
                        MaterialSymbol {
                            text: root.permissionGlyphs[permissionRow.modelData] ?? "shield"
                            fill: 1
                            iconSize: Math.round(18 * root.d)
                            color: IrisStyle.secondaryAccent
                        }
                        IrisText {
                            Layout.fillWidth: true
                            font.pixelSize: IrisStyle.typeLabel
                            text: Translation.tr(Hub.permissionText[permissionRow.modelData] ?? permissionRow.modelData)
                        }
                    }
                }
            }
        }

        IrisButton {
            visible: String(page.item?.page ?? "").length > 0
            quiet: true
            text: Translation.tr("See its files")
            onClicked: Qt.openUrlExternally(page.item.page)
        }
    }

    component InfoCard: Rectangle {
        id: infoCard
        property var rows: []
        Layout.fillWidth: true
        implicitHeight: infoColumn.implicitHeight
        radius: IrisStyle.radiusTile
        color: IrisStyle.readingCard
        Column {
            id: infoColumn
            width: parent.width
            Repeater {
                model: infoCard.rows
                Item {
                    id: infoRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: Math.round(40 * root.d)
                    IrisText {
                        id: infoLabel
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(16 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: infoRow.modelData.label
                        font.pixelSize: IrisStyle.typeLabel
                    }
                    IrisText {
                        anchors.left: infoLabel.right
                        anchors.leftMargin: Math.round(16 * root.d)
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(16 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: infoRow.modelData.value
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeLabel
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(16 * root.d)
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        visible: infoRow.index < infoCard.rows.length - 1
                        color: IrisStyle.hairline
                    }
                }
            }
        }
    }
}
