pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The community hub in Material Settings: a shelf of cards with previews, filtered by kind and
// search, and a page per item with what it can do and where it shows. Hub owns the catalogue and
// the installs; this page only presents them.
ContentPage {
    id: root
    settingsPageIndex: 29
    settingsPageName: Translation.tr("Hub")

    property string kind: ""
    property bool installedOnly: false
    property string query: ""
    property string openId: ""

    readonly property string family: Hub.family
    readonly property var shown: Hub.items.filter(item => Hub.matches(item, root.kind, root.query, root.installedOnly))
    readonly property var opened: root.openId.length > 0 ? Hub.find(root.openId) : null
    readonly property int columns: Math.max(1, Math.floor((root.width - 2 * root._horizontalMargin + 14) / 274))

    readonly property var permissionGlyphs: ({ process: "terminal", network: "public", files: "folder_open", inject: "code" })
    readonly property var kindGlyphs: ({ widget: "widgets", theme: "palette", "iris-theme": "style", webapp: "language" })

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

    // What the main button says and does for an item in this family.
    function actionOf(item: var): var {
        switch (Hub.stateOf(item)) {
        case "installing": return { text: Translation.tr("Installing…"), busy: true }
        case "updating": return { text: Translation.tr("Updating…"), busy: true }
        case "removing": return { text: Translation.tr("Removing…"), busy: true }
        case "failed": return { text: Translation.tr("Try again"), icon: "refresh", tone: "error", run: () => item.installed ? Hub.update(item.id) : Hub.install(item.id) }
        case "update": return { text: Translation.tr("Update"), icon: "upgrade", tone: "primary", run: () => Hub.update(item.id) }
        case "conflict": return { text: Translation.tr("Name taken"), icon: "block", tone: "off" }
        case "incompatible": return { text: Translation.tr("Needs iNiR %1").arg(item.minInir), icon: "block", tone: "off" }
        case "get": return { text: Translation.tr("Get"), icon: "download", tone: "primary", run: () => Hub.install(item.id) }
        }
        if (item.kind === "theme" && Hub.fits(item, root.family))
            return { text: Translation.tr("Apply"), icon: "format_paint", tone: "tonal", run: () => Hub.useTheme(item.id) }
        if (item.kind === "widget" && Hub.fits(item, root.family) && root.family !== "waffle") {
            if (Hub.widgetInUse(item.id, root.family))
                return { text: Translation.tr("In use"), icon: "check", tone: "off" }
            return { text: Translation.tr("Use"), icon: "add_to_home_screen", tone: "tonal", run: () => Hub.useWidget(item.id, root.family) }
        }
        return { text: Translation.tr("Installed"), icon: "check", tone: "off" }
    }
    function whereOf(item: var): string {
        return Hub.fits(item, root.family) ? Hub.whereText(item, root.family) : Translation.tr("For %1").arg(Hub.familyNames(item))
    }

    // ── Header: what this is, search, filters ──────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            MaterialShapeWrappedMaterialSymbol {
                text: "storefront"
                iconSize: 26
                padding: 12
                shape: MaterialShape.Shape.Cookie7Sided
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Made by people who use iNiR")
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: !Hub.loaded ? Translation.tr("Reading the hub…")
                        : !Hub.online ? Translation.tr("Offline · the list from the last time the hub answered")
                        : Hub.error.length > 0 ? Translation.tr("The hub didn't answer · the list from the last time it did")
                        : Hub.updates > 0 ? Translation.tr("%1 updates waiting").arg(Hub.updates)
                        : Translation.tr("%1 in the hub · %2 installed").arg(Hub.items.length).arg(Hub.items.filter(item => item.installed).length)
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
            RippleButtonWithIcon {
                visible: Hub.updates > 0
                materialIcon: "upgrade"
                mainText: Translation.tr("Update all (%1)").arg(Hub.updates)
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                onClicked: Hub.updateAll()
            }
            IconToolbarButton {
                text: "refresh"
                enabled: !Hub.loading
                onClicked: Hub.refresh(true)
                StyledToolTip { text: Translation.tr("Check the hub now") }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.opened === null
            implicitHeight: 40
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer1
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                spacing: 8
                MaterialSymbol {
                    text: "search"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                }
                StyledTextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    clip: true
                    onTextChanged: searchDelay.restart()
                    Timer { id: searchDelay; interval: 140; onTriggered: root.query = searchInput.text }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: Translation.tr("Search the hub")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
                IconToolbarButton {
                    visible: searchInput.text.length > 0
                    implicitHeight: 30
                    iconSize: 18
                    text: "close"
                    onClicked: searchInput.text = ""
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: root.opened === null

            FilterChip {
                text: Translation.tr("Everything")
                selected: root.kind === ""
                onClicked: root.kind = ""
            }
            Repeater {
                model: Hub.kinds
                delegate: FilterChip {
                    required property var modelData
                    text: Translation.tr(modelData.label)
                    chipIcon: modelData.icon
                    selected: root.kind === modelData.id
                    onClicked: root.kind = root.kind === modelData.id ? "" : modelData.id
                }
            }
            FilterChip {
                text: Translation.tr("Installed")
                chipIcon: "download_done"
                selected: root.installedOnly
                onClicked: root.installedOnly = !root.installedOnly
            }
        }

        // Offline or unreachable: the list still shows what was loaded last.
        NoticeBox {
            Layout.fillWidth: true
            visible: Hub.loaded && (!Hub.online || Hub.error.length > 0)
            materialIcon: Hub.online ? "cloud_off" : "wifi_off"
            text: !Hub.online ? Translation.tr("You're offline: this is the list from the last time the hub answered")
                : Hub.items.length > 0 ? Translation.tr("The hub didn't answer: this is the list from the last time it did")
                : Translation.tr("The hub didn't answer. Check your connection and try again")
        }
    }

    // ── Loading, empty ────────────────────────────────────────────────
    MaterialLoadingIndicator {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 40
        visible: !Hub.loaded
        loading: visible
    }
    MaterialPlaceholderMessage {
        Layout.fillWidth: true
        Layout.topMargin: 24
        shown: Hub.loaded && root.opened === null && root.shown.length === 0
        visible: shown
        icon: root.installedOnly ? "download_done" : root.query.length > 0 ? "search_off" : "storefront"
        text: root.query.length > 0 ? Translation.tr("Nothing matches “%1”").arg(root.query)
            : root.installedOnly ? Translation.tr("Nothing installed from the hub yet")
            : Translation.tr("Nothing here yet")
        explanation: root.query.length > 0 || root.installedOnly || root.kind.length > 0
            ? Translation.tr("Clear the filters to see everything") : ""
    }

    // ── The shelf ─────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        visible: root.opened === null && root.shown.length > 0
        columns: root.columns
        columnSpacing: 14
        rowSpacing: 14

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
    SettingsCardSection {
        visible: root.opened === null
        expanded: false
        icon: "dns"
        title: Translation.tr("Sources")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Everything in the official hub is reviewed before it is published. Other sources are not: add only the ones you trust.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: Hub.sources
                delegate: RowLayout {
                    id: sourceRow
                    required property var modelData
                    readonly property bool extra: Hub.extraSources.includes(modelData.source)
                    Layout.fillWidth: true
                    spacing: 10
                    MaterialSymbol {
                        text: sourceRow.modelData.error ? "error" : sourceRow.extra ? "folder_special" : "verified"
                        iconSize: Appearance.font.pixelSize.larger
                        color: sourceRow.modelData.error ? Appearance.colors.colError : Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: sourceRow.modelData.name || sourceRow.modelData.source
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideMiddle
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: sourceRow.modelData.error && sourceRow.modelData.count === 0 ? Translation.tr("Didn't answer")
                                : Translation.tr("%1 items · %2").arg(sourceRow.modelData.count).arg(sourceRow.modelData.source)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideMiddle
                        }
                    }
                    IconToolbarButton {
                        visible: sourceRow.extra
                        text: "delete"
                        onClicked: Hub.removeSource(sourceRow.modelData.source)
                        StyledToolTip { text: Translation.tr("Remove this source") }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialTextField {
                    id: sourceField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Address of an index.json, or a folder")
                    onAccepted: addSource.clicked()
                }
                RippleButtonWithIcon {
                    id: addSource
                    materialIcon: "add"
                    mainText: Translation.tr("Add")
                    enabled: sourceField.text.trim().length > 0
                    onClicked: {
                        Hub.addSource(sourceField.text)
                        sourceField.text = ""
                    }
                }
            }
        }
    }

    // ── Pieces ────────────────────────────────────────────────────────

    // The picture of an item: its preview, or its kind's glyph on a quiet plate while there is none.
    component Preview: ClippingRectangle {
        id: preview
        property var item
        color: Appearance.colors.colLayer2
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
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: previewImage.status !== Image.Ready
            text: root.kindGlyphs[preview.item?.kind] ?? "extension"
            iconSize: Math.round(preview.height * 0.3)
            fill: 1
            color: Appearance.colors.colSubtext
        }
    }

    // The main button, the same on a card and on an item's page.
    component ActionButton: RippleButtonWithIcon {
        id: action
        property var item
        readonly property var plan: root.actionOf(action.item)
        materialIcon: action.plan.busy ? "progress_activity" : (action.plan.icon ?? "")
        mainText: action.plan.text
        enabled: typeof action.plan.run === "function"
        colBackground: action.plan.tone === "primary" ? Appearance.colors.colPrimary
            : action.plan.tone === "error" ? Appearance.colors.colErrorContainer
            : action.plan.tone === "tonal" ? Appearance.colors.colSecondaryContainer
            : "transparent"
        colBackgroundHover: action.plan.tone === "primary" ? Appearance.colors.colPrimaryHover
            : action.plan.tone === "tonal" ? Appearance.colors.colSecondaryContainerHover
            : Appearance.colors.colLayer2Hover
        contentColor: action.plan.tone === "primary" ? Appearance.colors.colOnPrimary
            : action.plan.tone === "error" ? Appearance.colors.colOnErrorContainer
            : action.plan.tone === "tonal" ? Appearance.colors.colOnSecondaryContainer
            : Appearance.colors.colSubtext
        onClicked: action.plan.run()
        StyledToolTip {
            text: Hub.stateOf(action.item) === "conflict" ? Translation.tr("A folder with this name is already there and did not come from the hub")
                : Hub.stateOf(action.item) === "failed" ? String(Hub.failures[action.item.id] ?? "")
                : ""
        }
    }

    component ItemCard: ClippingRectangle {
        id: card
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredWidth: 260
        implicitHeight: cardColumn.implicitHeight
        radius: Appearance.rounding.normal
        color: cardHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

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
                Layout.margins: 14
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: card.modelData.name
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: [Translation.tr(Hub.kindLabel(card.modelData.kind)), Array.from(card.modelData.authors ?? []).join(", ")]
                        .filter(part => part.length > 0).join(" · ")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
                StyledText {
                    id: summaryText
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.preferredHeight: Math.ceil(summaryMetrics.lineSpacing * 2)
                    text: card.modelData.summary ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignTop
                    FontMetrics { id: summaryMetrics; font: summaryText.font }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: root.whereOf(card.modelData)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: Array.from(card.modelData.permissions ?? [])
                        delegate: MaterialSymbol {
                            id: permissionMark
                            required property string modelData
                            text: root.permissionGlyphs[modelData] ?? "shield"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colTertiary
                            HoverHandler { id: permissionHover }
                            StyledToolTip {
                                text: Translation.tr(Hub.permissionText[permissionMark.modelData] ?? "")
                                extraVisibleCondition: permissionHover.hovered
                            }
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
        spacing: 16

        RippleButtonWithIcon {
            materialIcon: "arrow_back"
            mainText: Translation.tr("Hub")
            colBackground: "transparent"
            onClicked: root.openId = ""
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Preview {
                Layout.preferredWidth: Math.round(Math.min(440, page.width * 0.55))
                Layout.preferredHeight: Math.round(Layout.preferredWidth * 10 / 16)
                Layout.alignment: Qt.AlignTop
                radius: Appearance.rounding.normal
                item: page.item
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: page.item?.name ?? ""
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("By %1").arg(Array.from(page.item?.authors ?? []).join(", "))
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: page.item?.summary ?? ""
                    font.pixelSize: Appearance.font.pixelSize.normal
                    wrapMode: Text.WordWrap
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 8
                    ActionButton {
                        item: page.item
                    }
                    RippleButtonWithIcon {
                        visible: Boolean(page.item?.installed) && Hub.stateOf(page.item) !== "removing"
                        materialIcon: "delete"
                        mainText: Translation.tr("Remove")
                        colBackground: "transparent"
                        contentColor: Appearance.colors.colError
                        onClicked: Hub.remove(page.item.id)
                    }
                    RippleButtonWithIcon {
                        visible: String(page.item?.page ?? "").length > 0
                        materialIcon: "code"
                        mainText: Translation.tr("Its files")
                        colBackground: "transparent"
                        onClicked: Qt.openUrlExternally(page.item.page)
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: page.item?.description ?? ""
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }

        SettingsGroup {
            Layout.fillWidth: true
            InfoRow { glyph: "place_item"; label: Translation.tr("Where"); value: root.whereOf(page.item) }
            InfoRow { glyph: "family_history"; label: Translation.tr("Works in"); value: Hub.familyNames(page.item) }
            InfoRow {
                glyph: "new_releases"
                label: Translation.tr("Version")
                value: page.item?.installed && page.item.installed !== page.item.version
                    ? Translation.tr("%1 (you have %2)").arg(page.item.version).arg(page.item.installed) : String(page.item?.version ?? "")
            }
            InfoRow { glyph: "event"; label: Translation.tr("Updated"); value: String(page.item?.updated ?? "") }
            InfoRow { glyph: "balance"; label: Translation.tr("License"); value: String(page.item?.license ?? "") }
            InfoRow { glyph: "download"; label: Translation.tr("Size"); value: page.item?.size ? Hub.sizeText(page.item.size) : "" }
            InfoRow { glyph: "dns"; label: Translation.tr("From"); value: String(page.item?.sourceName || page.item?.source || "") }
        }

        SettingsCardSection {
            expanded: true
            collapsible: false
            icon: "shield"
            title: Array.from(page.item?.permissions ?? []).length > 0 ? Translation.tr("What it can do") : Translation.tr("Nothing beyond the shell")

            SettingsGroup {
                StyledText {
                    Layout.fillWidth: true
                    visible: Array.from(page.item?.permissions ?? []).length === 0
                    text: Translation.tr("It only draws inside the shell: it runs no commands, reaches no websites and reads no files of yours.")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: Array.from(page.item?.permissions ?? [])
                    delegate: InfoRow {
                        required property string modelData
                        glyph: root.permissionGlyphs[modelData] ?? "shield"
                        label: Translation.tr(Hub.permissionText[modelData] ?? modelData)
                        tint: Appearance.colors.colTertiary
                        standalone: true
                    }
                }
            }
        }
    }

    // A line of an item's page: glyph, what it is, its value on the right (or the label alone).
    component InfoRow: RowLayout {
        id: info
        property string glyph: ""
        property string label: ""
        property string value: ""
        property color tint: Appearance.colors.colSubtext
        property bool standalone: false
        Layout.fillWidth: true
        visible: info.standalone || info.value.length > 0
        spacing: 12
        MaterialSymbol {
            text: info.glyph
            iconSize: Appearance.font.pixelSize.larger
            color: info.tint
        }
        StyledText {
            Layout.fillWidth: info.value.length === 0
            text: info.label
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
        }
        StyledText {
            Layout.fillWidth: true
            visible: info.value.length > 0
            horizontalAlignment: Text.AlignRight
            text: info.value
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
        }
    }
}
