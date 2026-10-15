pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The community hub in Material Settings. The shelf leads with one featured item, then what works in
// Material, then what works in the other families; an item's page leads with its picture and its
// action. Hub owns the catalogue and the installs; this page only presents them.
ContentPage {
    id: root
    settingsPageIndex: 29
    settingsPageName: Translation.tr("Hub")

    property string kind: ""
    property bool installedOnly: false
    property string query: ""
    property string openId: ""
    property real shelfScroll: 0

    readonly property string family: Hub.family
    readonly property var shown: Hub.items.filter(item => Hub.matches(item, root.kind, root.query, root.installedOnly))
    readonly property var opened: root.openId.length > 0 ? Hub.find(root.openId) : null
    readonly property bool browsing: root.kind === "" && root.query === "" && !root.installedOnly
    readonly property var featured: root.browsing ? Hub.featuredFor(root.family) : null
    readonly property var forHere: root.shown.filter(item => Hub.fits(item, root.family) && item.id !== root.featured?.id)
    readonly property var forOthers: root.shown.filter(item => !Hub.fits(item, root.family))

    // Cards are laid out from the page width: as many columns of at least minCard as fit, up to four.
    readonly property int gap: 16
    readonly property real minCard: 236
    readonly property real usable: Math.max(0, root.width - 2 * root._horizontalMargin)
    readonly property int columns: Math.max(1, Math.min(4, Math.floor((root.usable + root.gap) / (root.minCard + root.gap))))
    readonly property real cardWidth: Math.floor((root.usable - (root.columns - 1) * root.gap) / root.columns)

    readonly property var permissionGlyphs: ({ process: "terminal", network: "public", files: "folder_open", inject: "code" })
    readonly property var kindGlyphs: ({ widget: "widgets", theme: "palette", "iris-theme": "style", webapp: "language" })
    readonly property var familyNames: ({ material: "Material", iris: "iRiS", waffle: "Waffle" })

    Component.onCompleted: {
        Hub.ensureLoaded()
        if (Hub.requestedId.length > 0)
            root.openItem(Hub.takeRequest())
    }
    Connections {
        target: Hub
        function onRequestedIdChanged(): void {
            if (Hub.requestedId.length > 0)
                root.openItem(Hub.takeRequest())
        }
    }


    // An item's page opens at its top; going back returns to where the shelf was.
    function openItem(id: string): void {
        if (root.openId.length === 0)
            root.shelfScroll = root.contentY
        root.openId = id
        root.contentY = 0
    }
    function closeItem(): void {
        root.openId = ""
        root.contentY = root.shelfScroll
    }
    function searchFor(text: string): void {
        root.closeItem()
        searchInput.text = text
        root.query = text
        root.contentY = 0
    }

    // What the main button says and does for an item in this family.
    function actionOf(item: var): var {
        switch (Hub.stateOf(item)) {
        case "installing": return { text: Translation.tr("Installing…"), icon: "downloading", busy: true }
        case "updating": return { text: Translation.tr("Updating…"), icon: "downloading", busy: true }
        case "removing": return { text: Translation.tr("Removing…"), icon: "delete", busy: true }
        case "failed": return { text: Translation.tr("Try again"), icon: "refresh", tone: "error", run: () => item.installed ? Hub.update(item.id) : Hub.install(item.id) }
        case "update": return { text: Translation.tr("Update"), icon: "upgrade", tone: "primary", run: () => Hub.update(item.id) }
        case "conflict": return { text: Translation.tr("Name taken"), icon: "block", tone: "off" }
        case "incompatible": return { text: Translation.tr("Needs iNiR %1").arg(item.minInir), icon: "block", tone: "off" }
        case "get": return { text: Translation.tr("Get"), icon: "download", tone: Hub.fits(item, root.family) ? "primary" : "tonal", run: () => Hub.install(item.id) }
        }
        if (item.kind === "theme" && Hub.fits(item, root.family))
            return { text: Translation.tr("Apply"), icon: "format_paint", tone: "tonal", run: () => Hub.useTheme(item.id) }
        if (item.kind === "widget" && Hub.fits(item, root.family) && root.family !== "waffle") {
            if (Hub.widgetInUse(item.id, root.family))
                return { text: Translation.tr("On your desktop"), icon: "check", tone: "off" }
            return { text: Translation.tr("Add to desktop"), icon: "add_to_home_screen", tone: "tonal", run: () => Hub.useWidget(item.id, root.family) }
        }
        return { text: Translation.tr("Installed"), icon: "check", tone: "off" }
    }
    function whereOf(item: var): string {
        return Hub.fits(item, root.family) ? Hub.whereText(item, root.family) : Translation.tr("For %1").arg(Hub.familyNames(item))
    }
    function authorsOf(item: var): string {
        return Array.from(item?.authors ?? []).join(", ")
    }
    // Other families an item works in, by name: "iRiS", "iRiS · Waffle".
    function otherFamilies(item: var): string {
        return Array.from(item?.families ?? []).filter(name => name !== root.family).map(name => root.familyNames[name] ?? name).join(" · ")
    }

    // ── Search, filters ───────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.opened === null
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // The search bar also says how much there is to search, and holds the refresh.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Appearance.rounding.full
                color: searchInput.activeFocus ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                border.width: searchInput.activeFocus ? 2 : 0
                border.color: Appearance.colors.colPrimary
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                TapHandler { onTapped: searchInput.forceActiveFocus() }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 6
                    spacing: 12
                    MaterialSymbol {
                        text: "search"
                        iconSize: Appearance.font.pixelSize.huge
                        color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    StyledTextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        clip: true
                        onTextChanged: searchDelay.restart()
                        Keys.onEscapePressed: event => {
                            if (text.length === 0) {
                                event.accepted = false
                                return
                            }
                            text = ""
                        }
                        Timer { id: searchDelay; interval: 140; onTriggered: root.query = searchInput.text.trim() }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            visible: searchInput.text.length === 0
                            text: !Hub.loaded ? Translation.tr("Reading the hub…")
                                : Hub.items.length > 0 ? Translation.tr("Search %1 widgets, themes and web apps").arg(Hub.items.length)
                                : Translation.tr("Search the hub")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                    }
                    IconToolbarButton {
                        visible: searchInput.text.length > 0
                        implicitWidth: 36
                        implicitHeight: 36
                        iconSize: 20
                        text: "close"
                        onClicked: searchInput.text = ""
                        StyledToolTip { text: Translation.tr("Clear") }
                    }
                    Rectangle {
                        implicitWidth: 1
                        implicitHeight: 24
                        color: Appearance.colors.colOutlineVariant
                    }
                    IconToolbarButton {
                        id: refreshButton
                        implicitWidth: 36
                        implicitHeight: 36
                        iconSize: 20
                        text: "refresh"
                        enabled: !Hub.loading
                        onClicked: Hub.refresh(true)
                        StyledToolTip {
                            text: Hub.checkedAt > 0
                                ? Translation.tr("Checked %1 · check again").arg(Qt.formatTime(new Date(Hub.checkedAt), "hh:mm"))
                                : Translation.tr("Check the hub now")
                        }
                        RotationAnimator on rotation {
                            running: Hub.loading && refreshButton.visible && Appearance.animationsEnabled
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) refreshButton.rotation = 0
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                visible: Hub.updates > 0
                implicitHeight: 48
                horizontalPadding: 18
                buttonRadius: Appearance.rounding.full
                materialIcon: "upgrade"
                mainText: Translation.tr("Update all (%1)").arg(Hub.updates)
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentColor: Appearance.colors.colOnPrimary
                onClicked: Hub.updateAll()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            FilterChip {
                text: Translation.tr("Everything")
                selected: root.kind === "" && !root.installedOnly
                onClicked: {
                    root.kind = ""
                    root.installedOnly = false
                }
            }
            Repeater {
                model: Hub.kinds.filter(entry => Hub.items.some(item => item.kind === entry.id))
                delegate: FilterChip {
                    required property var modelData
                    text: Translation.tr(modelData.label)
                    chipIcon: modelData.icon
                    selected: root.kind === modelData.id
                    onClicked: root.kind = root.kind === modelData.id ? "" : modelData.id
                }
            }
            FilterChip {
                visible: Hub.items.some(item => item.installed)
                text: Translation.tr("Installed")
                chipIcon: "download_done"
                selected: root.installedOnly
                onClicked: root.installedOnly = !root.installedOnly
            }
        }

        // Offline or unreachable: the shelf still shows what was loaded last.
        NoticeBox {
            Layout.fillWidth: true
            visible: Hub.loaded && (!Hub.online || Hub.error.length > 0)
            materialIcon: Hub.online ? "cloud_off" : "wifi_off"
            text: !Hub.online ? Translation.tr("You're offline: this is the list from the last time the hub answered")
                : Hub.items.length > 0 ? Translation.tr("The hub didn't answer: this is the list from the last time it did")
                : Translation.tr("The hub didn't answer. Check your connection and try again")
        }
    }

    // ── Loading: the shelf's shape, quiet ─────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: !Hub.loaded
        columns: root.columns
        columnSpacing: root.gap
        rowSpacing: root.gap
        Repeater {
            model: root.columns * 2
            delegate: Rectangle {
                id: ghost
                required property int index
                Layout.preferredWidth: root.cardWidth
                implicitHeight: Math.round(root.cardWidth * 10 / 16) + 104
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2
                Rectangle {
                    width: parent.width
                    height: Math.round(root.cardWidth * 10 / 16)
                    topLeftRadius: parent.radius
                    topRightRadius: parent.radius
                    color: Appearance.colors.colLayer3
                }
                Column {
                    x: 16
                    y: Math.round(root.cardWidth * 10 / 16) + 18
                    spacing: 10
                    Rectangle { width: ghost.width * 0.5; height: 12; radius: 6; color: Appearance.colors.colLayer3 }
                    Rectangle { width: ghost.width * 0.32; height: 9; radius: 4.5; color: Appearance.colors.colLayer3 }
                    Rectangle { width: ghost.width * 0.78; height: 9; radius: 4.5; color: Appearance.colors.colLayer3 }
                }
                SequentialAnimation on opacity {
                    running: ghost.visible && Appearance.animationsEnabled
                    loops: Animation.Infinite
                    PauseAnimation { duration: ghost.index * 90 }
                    NumberAnimation { from: 1; to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.55; to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    MaterialPlaceholderMessage {
        Layout.fillWidth: true
        Layout.topMargin: 32
        shown: Hub.loaded && root.opened === null && root.shown.length === 0
        visible: shown
        icon: root.query.length > 0 ? "search_off" : root.installedOnly ? "download_done" : "storefront"
        text: root.query.length > 0 ? Translation.tr("Nothing matches “%1”").arg(root.query)
            : root.installedOnly ? Translation.tr("Nothing installed from the hub yet")
            : Hub.items.length === 0 && Hub.error.length > 0 ? Translation.tr("The hub didn't answer")
            : Translation.tr("Nothing here yet")
        explanation: root.query.length > 0 ? Translation.tr("Try a shorter word, or look through everything")
            : root.installedOnly ? Translation.tr("What you get from the hub shows up here, with its updates")
            : ""
        actionIcon: root.browsing ? "refresh" : "filter_alt_off"
        actionText: root.browsing ? (Hub.error.length > 0 ? Translation.tr("Try again") : "") : Translation.tr("See everything")
        helpfulAction: Action {
            text: root.browsing ? Translation.tr("Try again") : Translation.tr("See everything")
            onTriggered: {
                if (root.browsing) {
                    Hub.refresh(true)
                    return
                }
                searchInput.text = ""
                root.query = ""
                root.kind = ""
                root.installedOnly = false
            }
        }
    }

    // ── The shelf ─────────────────────────────────────────────────────
    FeaturedCard {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: Hub.loaded && root.opened === null && root.featured !== null
        item: root.featured
    }

    Shelf {
        visible: Hub.loaded && root.opened === null && root.forHere.length > 0
        title: root.browsing ? Translation.tr("For %1").arg(root.familyNames[root.family] ?? root.family) : ""
        items: root.forHere
    }

    Shelf {
        visible: Hub.loaded && root.opened === null && root.forOthers.length > 0
        title: Translation.tr("For other families")
        caption: Translation.tr("They do their part once you switch to the family they were made for")
        items: root.forOthers
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
        Layout.topMargin: 12
        visible: root.opened === null && Hub.loaded
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
                    buttonRadius: Appearance.rounding.full
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
        property bool zoomed: false
        color: Appearance.colors.colLayer3
        Image {
            id: previewImage
            anchors.fill: parent
            source: preview.item?.previewUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Math.ceil(preview.width * 1.5)
            sourceSize.height: Math.ceil(preview.height * 1.5)
            opacity: status === Image.Ready ? 1 : 0
            scale: preview.zoomed ? 1.035 : 1
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.OutCubic }
            }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: previewImage.status !== Image.Ready
            text: root.kindGlyphs[preview.item?.kind] ?? "extension"
            iconSize: Math.round(preview.height * 0.28)
            fill: 1
            color: Appearance.colors.colOutlineVariant
        }
    }

    // The main button, the same everywhere; `compact` is the card's size.
    component ActionButton: RippleButtonWithIcon {
        id: action
        property var item
        property bool compact: false
        // On a card a fresh "Get" is tonal: a shelf of filled buttons has no focal point.
        readonly property var plan: {
            const plan = root.actionOf(action.item)
            if (action.compact && plan.tone === "primary" && Hub.stateOf(action.item) === "get")
                plan.tone = "tonal"
            return plan
        }
        readonly property bool quiet: action.plan.tone === "off" || action.plan.busy === true
        implicitHeight: action.compact ? 32 : 44
        horizontalPadding: action.quiet ? (action.compact ? 4 : 8) : (action.compact ? 14 : 20)
        buttonRadius: Appearance.rounding.full
        materialIcon: action.plan.icon ?? ""
        mainText: action.plan.text
        enabled: typeof action.plan.run === "function"
        colBackground: action.plan.tone === "primary" ? Appearance.colors.colPrimary
            : action.plan.tone === "error" ? Appearance.colors.colErrorContainer
            : action.plan.tone === "tonal" ? Appearance.colors.colSecondaryContainer
            : "transparent"
        colBackgroundHover: action.plan.tone === "primary" ? Appearance.colors.colPrimaryHover
            : action.plan.tone === "error" ? Appearance.colors.colErrorContainerHover
            : action.plan.tone === "tonal" ? Appearance.colors.colSecondaryContainerHover
            : "transparent"
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

    // A titled group of cards.
    component Shelf: ColumnLayout {
        id: shelf
        property string title: ""
        property string caption: ""
        property var items: []
        Layout.fillWidth: true
        Layout.topMargin: 14
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            visible: shelf.title.length > 0
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: shelf.title
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                visible: shelf.caption.length > 0
                text: shelf.caption
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.columns
            columnSpacing: root.gap
            rowSpacing: root.gap
            Repeater {
                model: shelf.items
                delegate: ItemCard {}
            }
        }
    }

    // A card on the shelf: the picture first, then name, kind and author, two lines of summary,
    // and a quiet action. The page behind it has the rest.
    component ItemCard: ClippingRectangle {
        id: card
        required property var modelData
        readonly property bool here: Hub.fits(card.modelData, root.family)
        Layout.preferredWidth: root.cardWidth
        Layout.alignment: Qt.AlignTop
        implicitHeight: cardColumn.implicitHeight
        radius: Appearance.rounding.normal
        color: cardHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.openItem(card.modelData.id) }

        ColumnLayout {
            id: cardColumn
            width: card.width
            spacing: 0

            Preview {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(card.width * 10 / 16)
                item: card.modelData
                zoomed: cardHover.hovered
                opacity: card.here ? 1 : 0.82
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 12
                Layout.topMargin: 14
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        Layout.fillWidth: true
                        text: card.modelData.name
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    // Kind and author, then what it may do; plain positions, since the line elides to make room.
                    Item {
                        id: metaRow
                        Layout.fillWidth: true
                        implicitHeight: metaText.implicitHeight
                        StyledText {
                            id: metaText
                            width: Math.min(implicitWidth, metaRow.width - (marks.width > 0 ? marks.width + 6 : 0))
                            text: [Translation.tr(Hub.kindName(card.modelData.kind)), root.authorsOf(card.modelData)]
                                .filter(part => part.length > 0).join(" · ")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                        Row {
                            id: marks
                            x: metaText.width + 6
                            anchors.verticalCenter: metaText.verticalCenter
                            spacing: 4
                            Repeater {
                                model: Array.from(card.modelData.permissions ?? [])
                                delegate: MaterialSymbol {
                                    id: permissionMark
                                    required property string modelData
                                    text: root.permissionGlyphs[modelData] ?? "shield"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colTertiary
                                    HoverHandler { id: permissionHover }
                                    StyledToolTip {
                                        text: Translation.tr(Hub.permissionText[permissionMark.modelData] ?? "")
                                        extraVisibleCondition: permissionHover.hovered
                                    }
                                }
                            }
                        }
                    }
                }

                ActionButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: card.here || Hub.stateOf(card.modelData) !== "get"
                    compact: true
                    item: card.modelData
                }
                // Made for another family: say which instead of offering it.
                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !card.here && Hub.stateOf(card.modelData) === "get"
                    text: root.otherFamilies(card.modelData)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                }
            }

            StyledText {
                id: summaryText
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 8
                Layout.bottomMargin: 16
                Layout.preferredHeight: Math.ceil(summaryMetrics.height * 2 + 2)
                text: card.modelData.summary ?? ""
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: ColorUtils.mix(Appearance.colors.colOnLayer1, Appearance.colors.colSubtext, 0.4)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
                FontMetrics { id: summaryMetrics; font: summaryText.font }
            }
        }
    }

    // The first thing on the shelf: one item, large, with its action at hand.
    component FeaturedCard: ClippingRectangle {
        id: hero
        property var item
        readonly property bool stacked: hero.width < 640
        readonly property real pictureWidth: hero.stacked ? hero.width - 24 : Math.round((hero.width - 24) * 0.56)
        implicitHeight: hero.stacked ? heroText.implicitHeight + Math.round(hero.pictureWidth * 10 / 16) + 36
            : Math.max(heroText.implicitHeight + 24, Math.round(hero.pictureWidth * 10 / 16) + 24)
        radius: Appearance.rounding.large
        color: heroHover.hovered ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        HoverHandler { id: heroHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.openItem(hero.item.id) }

        Preview {
            id: heroPicture
            x: hero.stacked ? 12 : hero.width - width - 12
            y: 12
            width: hero.pictureWidth
            height: Math.round(width * 10 / 16)
            radius: Appearance.rounding.normal
            item: hero.item
            zoomed: heroHover.hovered
        }

        ColumnLayout {
            id: heroText
            x: hero.stacked ? 28 : 32
            y: hero.stacked ? heroPicture.height + 28 : Math.round((hero.height - height) / 2)
            width: hero.stacked ? hero.width - 56 : hero.width - hero.pictureWidth - 12 - 32 - 28
            spacing: 6

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: "kid_star"
                    iconSize: Appearance.font.pixelSize.small
                    fill: 1
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.8
                }
                StyledText {
                    text: hero.item?.featured === true ? Translation.tr("Featured") : Translation.tr("New in the hub")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    font.capitalization: Font.AllUppercase
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.8
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: hero.item?.name ?? ""
                font.family: Appearance.font.family.title
                font.pixelSize: Math.round(Appearance.font.pixelSize.hugeass * 1.35)
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimaryContainer
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: hero.item?.summary ?? ""
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.86
                wrapMode: Text.WordWrap
            }
            StyledText {
                Layout.fillWidth: true
                text: [Translation.tr(Hub.kindName(hero.item?.kind ?? "")), Translation.tr("by %1").arg(root.authorsOf(hero.item))].join(" · ")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.7
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.topMargin: 10
                spacing: 8
                ActionButton {
                    item: hero.item
                }
                RippleButtonWithIcon {
                    implicitHeight: 44
                    horizontalPadding: 16
                    buttonRadius: Appearance.rounding.full
                    materialIcon: "arrow_forward"
                    mainText: Translation.tr("Details")
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.08)
                    contentColor: Appearance.colors.colOnPrimaryContainer
                    onClicked: root.openItem(hero.item.id)
                }
            }
        }
    }

    // An item's page: who made it and the action, its picture, the facts in one strip, what it
    // is and does, then more of the same kind.
    component ItemPage: ColumnLayout {
        id: page
        property var item
        readonly property bool wide: page.width >= 760
        readonly property var related: Hub.items.filter(other => other.id !== page.item?.id && other.kind === page.item?.kind)
            .sort((a, b) => Number(Hub.fits(b, root.family)) - Number(Hub.fits(a, root.family)))
            .slice(0, root.columns)
        readonly property var permissions: Array.from(page.item?.permissions ?? [])
        spacing: 20

        // Back, and where this is.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconToolbarButton {
                text: "arrow_back"
                onClicked: root.closeItem()
                StyledToolTip { text: Translation.tr("Back to the hub") }
            }
            StyledText {
                text: Translation.tr("Hub")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                TapHandler { onTapped: root.closeItem() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            MaterialSymbol {
                text: "chevron_right"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: Translation.tr(Hub.kindLabel(page.item?.kind ?? ""))
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                TapHandler {
                    onTapped: {
                        root.kind = page.item.kind
                        root.closeItem()
                        root.contentY = 0
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        // Who made it, and what to do with it.
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignTop
                text: page.item?.icon || root.kindGlyphs[page.item?.kind] || "extension"
                iconSize: 30
                padding: 14
                fill: 1
                shape: MaterialShape.Shape.Cookie9Sided
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: page.item?.name ?? ""
                    font.family: Appearance.font.family.title
                    font.pixelSize: Math.round(Appearance.font.pixelSize.hugeass * 1.25)
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("by %1").arg(root.authorsOf(page.item))
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colPrimary
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: [Translation.tr(Hub.kindName(page.item?.kind ?? "")), root.whereOf(page.item)].join(" · ")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: Boolean(page.item?.installed) && Hub.stateOf(page.item) !== "removing"
                implicitHeight: 44
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                materialIcon: "delete"
                mainText: Translation.tr("Remove")
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.08)
                contentColor: Appearance.colors.colError
                onClicked: Hub.remove(page.item.id)
            }
            ActionButton {
                Layout.alignment: Qt.AlignVCenter
                item: page.item
            }
        }

        // Its picture, as large as the page allows without towering over it.
        Preview {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: page.width
            Layout.preferredHeight: Math.round(Layout.preferredWidth * 9 / 16)
            radius: Appearance.rounding.large
            item: page.item
        }

        // The facts, in one strip.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: factsRow.implicitHeight + 28
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            RowLayout {
                id: factsRow
                anchors.fill: parent
                anchors.margins: 14
                spacing: 0
                Repeater {
                    model: [
                        { label: Translation.tr("Version"), value: String(page.item?.version ?? ""),
                          note: page.item?.installed && page.item.installed !== page.item.version ? Translation.tr("you have %1").arg(page.item.installed) : "" },
                        { label: Translation.tr("Size"), value: page.item?.size ? Hub.sizeText(page.item.size) : "" },
                        { label: Translation.tr("Updated"), value: page.item?.updated ? Qt.formatDate(new Date(page.item.updated + "T12:00:00"), "d MMM yyyy") : "" },
                        { label: Translation.tr("License"), value: String(page.item?.license ?? "") },
                        { label: Translation.tr("Works in"), value: Hub.familyNames(page.item) }
                    ].filter(fact => fact.value.length > 0)
                    delegate: RowLayout {
                        id: fact
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 0
                        Rectangle {
                            visible: fact.index > 0
                            implicitWidth: 1
                            Layout.fillHeight: true
                            color: Appearance.colors.colOutlineVariant
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: fact.modelData.value
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: fact.modelData.note || fact.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: fact.modelData.note ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // What it is, beside what it can do. Side by side when there is room.
        GridLayout {
            Layout.fillWidth: true
            columns: page.wide ? 2 : 1
            columnSpacing: 28
            rowSpacing: 20

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 10
                StyledText {
                    text: Translation.tr("About")
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.fillWidth: true
                    text: page.item?.description || page.item?.summary || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    visible: Array.from(page.item?.tags ?? []).length > 0
                    Repeater {
                        model: Array.from(page.item?.tags ?? [])
                        delegate: FilterChip {
                            required property string modelData
                            text: modelData
                            chipIcon: "tag"
                            onClicked: root.searchFor(modelData)
                        }
                    }
                }
                RippleButtonWithIcon {
                    Layout.topMargin: 4
                    visible: String(page.item?.page ?? "").length > 0
                    buttonRadius: Appearance.rounding.full
                    horizontalPadding: 14
                    materialIcon: "code"
                    mainText: Translation.tr("Source and setup guide")
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2
                    contentColor: Appearance.colors.colPrimary
                    onClicked: Qt.openUrlExternally(page.item.page)
                }
            }

            Rectangle {
                Layout.fillWidth: !page.wide
                Layout.preferredWidth: page.wide ? 320 : -1
                Layout.alignment: Qt.AlignTop
                implicitHeight: trustColumn.implicitHeight + 36
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: trustColumn
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    InfoLine {
                        glyph: "place_item"
                        title: Translation.tr("Where it shows")
                        text: root.whereOf(page.item)
                    }
                    InfoLine {
                        glyph: page.permissions.length > 0 ? "shield" : "verified_user"
                        title: page.permissions.length > 0 ? Translation.tr("What it can do") : Translation.tr("Nothing beyond the shell")
                        text: page.permissions.length > 0 ? "" : Translation.tr("It only draws inside the shell: it runs no commands, reaches no websites and reads no files of yours.")
                        tint: page.permissions.length > 0 ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
                    }
                    Repeater {
                        model: page.permissions
                        delegate: RowLayout {
                            id: permission
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 36
                            spacing: 10
                            MaterialSymbol {
                                text: root.permissionGlyphs[permission.modelData] ?? "shield"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colTertiary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr(Hub.permissionText[permission.modelData] ?? permission.modelData)
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colOnLayer1
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    InfoLine {
                        glyph: "dns"
                        title: Translation.tr("From")
                        text: String(page.item?.sourceName || page.item?.source || "")
                    }
                }
            }
        }

        Shelf {
            visible: page.related.length > 0
            Layout.topMargin: 8
            title: Translation.tr("More %1").arg(Translation.tr(Hub.kindLabel(page.item?.kind ?? "")).toLowerCase())
            items: page.related
        }
    }

    // A fact on an item's page: glyph, a short title, and a line under it.
    component InfoLine: RowLayout {
        id: line
        property string glyph: ""
        property string title: ""
        property string text: ""
        property color tint: Appearance.colors.colSubtext
        Layout.fillWidth: true
        visible: line.title.length > 0
        spacing: 14
        MaterialSymbol {
            Layout.alignment: Qt.AlignTop
            text: line.glyph
            iconSize: Appearance.font.pixelSize.huge
            color: line.tint
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: line.title
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                wrapMode: Text.WordWrap
            }
            StyledText {
                Layout.fillWidth: true
                visible: line.text.length > 0
                text: line.text
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }
}
