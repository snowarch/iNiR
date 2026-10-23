pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.background.widgets
import qs.modules.iris.style
import qs.modules.iris.settings
import qs.modules.iris.widgets
import qs.modules.iris.components

// The shelf: every widget as its own picture, by aisle, found by name. Pulled onto the card a widget lands at the size it
// will have; a click puts it on a free spot. One already out is dimmed with a check, a click finds it, a right click
// puts it back. The pictures are the widgets' own (DesktopEditStage), the last look on disk for the ones not out.
Item {
    id: root

    required property string outputName
    required property Item ghostLayer
    readonly property real d: IrisStyle.density

    readonly property real pad: Math.round(16 * root.d)
    readonly property real headHeight: Math.round(30 * root.d)
    readonly property real headGap: Math.round(14 * root.d)
    readonly property real pictureHeight: Math.round(112 * root.d)
    readonly property real nameGap: Math.round(7 * root.d)
    readonly property real nameHeight: Math.round(18 * root.d)
    readonly property real tileGap: Math.round(14 * root.d)
    readonly property real fullHeight: root.pad + root.headHeight + root.headGap + root.pictureHeight + root.nameGap
        + root.nameHeight + root.pad
    property real bodyRadius: IrisStyle.radius

    readonly property var entries: {
        const list = IrisFaceData.galleryEntries.concat(IrisFaceData.otherEntries).map(entry => IrisSearch.prepare({
            key: entry.key, glyph: entry.glyph, name: entry.label, english: entry.english, tint: entry.tint,
            words: entry.key + " " + DesktopWidgetIdentity.keywordsOf(entry.key), category: DesktopWidgetIdentity.categoryOf(entry.key) }))
        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : []))
            list.push(IrisSearch.prepare({ key: "custom." + custom.id, glyph: custom.icon || "widgets", name: custom.name,
                english: custom.name, tint: DesktopWidgetIdentity.customTint, words: "custom hub", category: "decor" }))
        return list
    }
    readonly property var categoryNames: ({ all: "All", today: "Today", media: "Media", system: "System", notes: "Notes", decor: "Decor" })
    readonly property var categories: ["all"].concat(DesktopWidgetIdentity.categoryOrder
        .filter(id => root.entries.some(entry => entry.category === id)))
        .map(id => ({ value: id, label: root.categoryNames[id] }))
    property string category: "all"

    // ── Finding a widget ──
    // The query searches every aisle. ↓/Tab and ↑ move along what matches, ↵ takes it, Escape clears, then lets go.
    readonly property string query: GlobalStates.widgetSearchText.trim()
    readonly property bool searching: root.query.length > 0 || searchInput.activeFocus
    readonly property var shown: {
        if (root.query.length === 0)
            return root.entries.filter(entry => root.category === "all" || entry.category === root.category)
        const hits = []
        root.entries.forEach((entry, order) => {
            const score = IrisSearch.score(root.query, entry)
            if (score > 0) hits.push({ entry: entry, score: score, order: order })
        })
        hits.sort((a, b) => b.score - a.score || a.order - b.order)
        return hits.map(hit => hit.entry)
    }
    property int highlight: 0
    onQueryChanged: { root.highlight = 0; tiles.contentX = 0 }
    onCategoryChanged: tiles.contentX = 0
    function openSearch(): void { searchInput.forceActiveFocus() }
    function escapeSearch(): void {
        if (GlobalStates.widgetSearchText.length > 0) GlobalStates.widgetSearchText = ""
        else { searchInput.focus = false; GlobalStates.widgetSearchOpen = false }
    }
    function move(step: int): void {
        root.highlight = Math.max(0, Math.min(root.shown.length - 1, root.highlight + step))
        const tile = tileRow.children.find(child => child.index === root.highlight)
        if (tile) tiles.reveal(tile)
    }
    function takeHighlighted(): void {
        const tile = tileRow.children.find(child => child.index === root.highlight)
        if (tile) root.use(tile)
    }
    Connections {
        target: GlobalStates
        function onWidgetSearchOpenChanged(): void { if (GlobalStates.widgetSearchOpen) root.openSearch() }
        function onWidgetSearchCommand(verb: string): void {
            if (verb === "next") root.move(1)
            else if (verb === "previous") root.move(-1)
            else if (verb === "take") root.takeHighlighted()
        }
    }
    Component.onCompleted: if (GlobalStates.widgetSearchOpen) root.openSearch()

    // The last looks on disk, read once per arranging; a widget with none shows its glyph.
    FolderListModel {
        id: savedFolder
        folder: "file://" + DesktopEditStage.pictureDir
        nameFilters: ["*.png"]
        showDirs: false
        onStatusChanged: if (savedFolder.status === FolderListModel.Ready) root.readSaved()
        onCountChanged: if (savedFolder.status === FolderListModel.Ready) root.readSaved()
    }
    property var saved: ({})
    function readSaved(): void {
        const out = {}
        for (let i = 0; i < savedFolder.count; i++) out[savedFolder.get(i, "fileName")] = true
        root.saved = out
    }
    function savedUrl(key: string): string {
        const path = DesktopEditStage.savedPicture(key)
        return root.saved[path.slice(path.lastIndexOf("/") + 1)] ? "file://" + path : ""
    }

    // ── Taking a widget out and putting it back ──
    function enabledOf(key: string): bool {
        return DesktopWidgetLayout.enabled(root.outputName, key, Config.getNestedValue("background.widgets." + key + ".enable", false))
    }
    function screenRect(item: Item): rect {
        const at = item.mapToItem(null, 0, 0)
        return Qt.rect(at.x, at.y, item.width, item.height)
    }
    function use(tile: Item): void {
        if (tile.on) {
            GlobalStates.selectDesktopWidget(root.outputName + "::" + tile.key)
            return
        }
        DesktopEditStage.arrive(root.outputName, tile.key, null, root.screenRect(tile.picture))
    }
    function putBack(tile: Item): void {
        if (!tile.on)
            return
        if (GlobalStates.selectedDesktopWidget === root.outputName + "::" + tile.key)
            GlobalStates.clearDesktopWidgetSelection()
        DesktopEditStage.depart(root.outputName, tile.key, root.screenRect(tile.picture))
    }

    // Where each picture sits on screen, for a widget taken away from the desktop to shrink into. A picture scrolled
    // out of view gives the nearest end of the row.
    function publishTiles(): void {
        const view = root.screenRect(tiles)
        const out = {}
        for (const child of tileRow.children) {
            if (!child.key) continue
            const r = root.screenRect(child.picture)
            out[child.key] = Qt.rect(Math.max(view.x, Math.min(view.x + view.width - r.width, r.x)), r.y, r.width, r.height)
        }
        DesktopEditStage.tiles = out
    }
    Timer { id: publishTimer; interval: 120; onTriggered: root.publishTiles() }
    onShownChanged: publishTimer.restart()
    onWidthChanged: publishTimer.restart()
    onYChanged: publishTimer.restart()
    Component.onDestruction: { DesktopEditStage.tiles = ({}); DesktopEditStage.carry = null }

    // ── Carrying a picture onto the card ──
    property Item carried: null
    readonly property bool carrying: root.carried !== null
    property point carryAt: Qt.point(0, 0)
    readonly property var card: DesktopEditStage.cardFor(root.outputName, root.ghostLayer.width, root.ghostLayer.height)
    readonly property rect cardRect: Qt.rect(root.card.x, root.card.y, root.ghostLayer.width * root.card.s, root.ghostLayer.height * root.card.s)
    readonly property bool overCard: root.carrying && !root.contains(root.mapFromItem(root.ghostLayer, root.carryAt.x, root.carryAt.y))
        && root.carryAt.x >= root.cardRect.x && root.carryAt.x <= root.cardRect.x + root.cardRect.width
        && root.carryAt.y >= root.cardRect.y && root.carryAt.y <= root.cardRect.y + root.cardRect.height
    function lift(tile: Item, at: point): void {
        root.carried = tile
        DesktopArrange.begin(root.outputName, root.outputName + "::" + tile.key)
        root.carryAt = at
        const r = root.screenRect(tile.picture)
        ghost.place(r.x, r.y, r.width, r.height, false)
        ghost.ride = true
    }
    function carry(at: point): void { root.carryAt = at }
    // Over the card the carried picture is pulled onto the desktop's lines like a widget carried there (DesktopArrange),
    // and the desktop draws where it will land; it lands exactly there.
    property var carryPlan: null
    function planCarry(): void {
        if (!root.overCard) {
            if (root.carryPlan !== null) {
                root.carryPlan = null
                DesktopEditStage.carry = null
            }
            return
        }
        const tile = root.carried
        const w = tile.logicalWidth
        const h = tile.logicalHeight
        const p = DesktopArrange.snap(root.outputName, root.outputName + "::" + tile.key, (root.carryAt.x - root.card.x) / root.card.s - w / 2,
            (root.carryAt.y - root.card.y) / root.card.s - h / 2, w, h, false, "")
        root.carryPlan = { x: p.x, y: p.y, width: w, height: h }
        DesktopEditStage.carry = { output: root.outputName, key: tile.key, width: w, height: h, plan: root.carryPlan }
    }
    onCarryAtChanged: root.planCarry()
    onOverCardChanged: root.planCarry()
    function drop(): void {
        const tile = root.carried
        if (root.overCard) {
            const ghostRect = Qt.rect(ghost.x, ghost.y, ghost.width, ghost.height)
            const plan = root.carryPlan
            const spot = plan ? DesktopArrange.end(root.outputName, root.outputName + "::" + tile.key, plan.x, plan.y, plan.width, plan.height, false, "") : null
            const at = spot ? { x: spot.x, y: spot.y, exact: true }
                : { x: (root.carryAt.x - root.card.x) / root.card.s, y: (root.carryAt.y - root.card.y) / root.card.s }
            root.carryPlan = null
            DesktopEditStage.carry = null
            // One already out slides from its place to the drop while the picture in hand dissolves over it.
            const glide = tile.on
            ghost.ride = false
            root.carried = null
            if (glide) ghostFade.restart()
            else ghost.visible = false
            DesktopEditStage.arrive(root.outputName, tile.key, at, glide ? null : ghostRect, glide)
            return
        }
        // Back onto its shelf.
        DesktopArrange.cancel()
        ghost.ride = false
        root.carried = null
        const r = root.screenRect(tile.picture)
        ghost.place(r.x, r.y, r.width, r.height, true)
        ghost.homing = true
    }

    // ── Head: aisles, search, the widgets' Settings ──
    IrisSegmented {
        id: aisles
        x: root.pad
        y: root.pad + Math.round((root.headHeight - height) / 2)
        width: Math.min(aisles.fitWidth, root.width - 2 * root.pad - searchBox.width - settingsButton.width - Math.round(20 * root.d))
        options: root.categories
        current: root.query.length > 0 ? "" : root.category
        accessibleName: Translation.tr("Widget kinds")
        onPicked: value => {
            GlobalStates.widgetSearchText = ""
            root.category = value
        }
    }

    Rectangle {
        id: searchBox
        anchors.right: settingsButton.left
        anchors.rightMargin: Math.round(8 * root.d)
        y: root.pad
        width: Math.round(240 * root.d)
        height: root.headHeight
        radius: IrisStyle.capsule(height)
        color: searchInput.activeFocus ? IrisStyle.fillActive : IrisStyle.fillQuiet
        border.width: searchInput.activeFocus ? 1 : 0
        border.color: IrisStyle.accent
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        MaterialSymbol {
            id: searchGlyph
            anchors.left: parent.left
            anchors.leftMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            iconSize: Math.round(16 * root.d)
            color: IrisStyle.muted
        }
        TextInput {
            id: searchInput
            anchors.left: searchGlyph.right
            anchors.leftMargin: Math.round(6 * root.d)
            anchors.right: clearGlyph.visible ? clearGlyph.left : parent.right
            anchors.rightMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: GlobalStates.widgetSearchText
            onTextEdited: GlobalStates.widgetSearchText = searchInput.text
            color: IrisStyle.text
            selectionColor: IrisStyle.tintFillHover(IrisStyle.accent)
            selectedTextColor: IrisStyle.text
            font.family: IrisStyle.fontMain
            font.pixelSize: IrisStyle.typeMeta
            clip: true
            Accessible.name: Translation.tr("Search widgets")
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) root.move(1)
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) root.move(-1)
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.takeHighlighted()
                else if (event.key === Qt.Key_Escape) root.escapeSearch()
                else return
                event.accepted = true
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                text: Translation.tr("Search widgets")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
        }
        MaterialSymbol {
            id: clearGlyph
            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            visible: GlobalStates.widgetSearchText.length > 0
            text: "close"
            iconSize: Math.round(14 * root.d)
            color: IrisStyle.muted
            TapHandler { onTapped: { GlobalStates.widgetSearchText = ""; searchInput.forceActiveFocus() } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        TapHandler { onTapped: searchInput.forceActiveFocus() }
        HoverHandler { cursorShape: Qt.IBeamCursor }
    }

    IrisIconButton {
        id: settingsButton
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: root.pad + Math.round((root.headHeight - height) / 2)
        implicitWidth: root.headHeight
        materialIcon: "tune"
        iconSize: Math.round(16 * root.d)
        Accessible.name: Translation.tr("Widget settings")
        onClicked: GlobalStates.openSettingsAt("widgets")
    }

    // ── The row of pictures ──
    Flickable {
        id: tiles
        x: root.pad
        y: root.pad + root.headHeight + root.headGap
        width: root.width - 2 * root.pad
        height: root.pictureHeight + root.nameGap + root.nameHeight
        contentWidth: tileRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        onContentXChanged: publishTimer.restart()
        function reveal(tile: Item): void {
            const left = tile.x
            const right = tile.x + tile.width
            if (left < tiles.contentX) tiles.contentX = left
            else if (right > tiles.contentX + tiles.width) tiles.contentX = right - tiles.width
        }
        Behavior on contentX {
            enabled: !tiles.dragging && !tiles.flicking && !wheelSettle.running
            NumberAnimation { duration: IrisStyle.duration(260); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }
        Timer { id: wheelSettle; interval: 160 }
        // The wheel scrolls the row sideways.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y
                const step = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0
                    ? (Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y) ? event.pixelDelta.x : event.pixelDelta.y)
                    : delta / 120 * Math.round(180 * root.d)
                wheelSettle.restart()
                tiles.contentX = Math.max(0, Math.min(tiles.contentWidth - tiles.width, tiles.contentX - step))
            }
        }

        Row {
            id: tileRow
            spacing: root.tileGap
            height: tiles.height
            Repeater {
                model: root.shown
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property string key: tile.modelData.key
                    readonly property bool on: root.enabledOf(tile.key)
                    readonly property var live: DesktopEditStage.pictures[tile.key] ?? null
                    readonly property bool pictured: (tile.live !== null || saved.status === Image.Ready) && !probe.blank
                    readonly property real aspect: probe.blank ? 1 : tile.live && tile.live.height > 0 ? tile.live.width / tile.live.height
                        : saved.status === Image.Ready && saved.sourceSize.height > 0 ? saved.sourceSize.width / saved.sourceSize.height : 1
                    readonly property real logicalWidth: tile.live ? tile.live.width : saved.status === Image.Ready ? saved.sourceSize.width : Math.round(180 * root.d)
                    readonly property real logicalHeight: tile.live ? tile.live.height : saved.status === Image.Ready ? saved.sourceSize.height : Math.round(180 * root.d)
                    readonly property string pictureUrl: tile.live ? tile.live.url : saved.status === Image.Ready ? saved.source : ""
                    readonly property Item picture: plate
                    readonly property bool highlighted: root.searching && root.highlight === tile.index
                    width: Math.max(plate.width, nameText.implicitWidth)
                    height: tileRow.height
                    opacity: root.carried === tile ? 0.35 : 1
                    onXChanged: publishTimer.restart()

                    // A picture with nothing in it (a visualizer with no sound) is no picture: its glyph stands in. Read
                    // at 8x8, then wiped, so it never shows.
                    Canvas {
                        id: probe
                        z: -1
                        width: 8
                        height: 8
                        property bool blank: false
                        readonly property string url: tile.live ? tile.live.url : saved.status === Image.Ready ? saved.source.toString() : ""
                        onUrlChanged: if (probe.url.length > 0) probe.loadImage(probe.url)
                        onImageLoaded: probe.requestPaint()
                        onPaint: {
                            const ctx = probe.getContext("2d")
                            if (probe.url.length === 0 || !probe.isImageLoaded(probe.url))
                                return
                            ctx.clearRect(0, 0, 8, 8)
                            ctx.drawImage(probe.url, 0, 0, 8, 8)
                            const data = ctx.getImageData(0, 0, 8, 8).data
                            let alpha = 0
                            for (let i = 3; i < data.length; i += 4)
                                alpha += data[i]
                            probe.blank = alpha < 64 * 6
                            ctx.clearRect(0, 0, 8, 8)
                            probe.unloadImage(probe.url)
                        }
                    }

                    // The widget's last look on disk, read once; a live picture covers it while the widget is out.
                    Image {
                        id: saved
                        visible: false
                        asynchronous: true
                        cache: false
                        source: root.savedUrl(tile.key)
                    }

                    Rectangle {
                        id: plate
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(Math.max(0.72, Math.min(2.6, tile.aspect)) * root.pictureHeight)
                        height: root.pictureHeight
                        radius: IrisStyle.concentric(root.bodyRadius, root.pad, Math.round(10 * root.d))
                        color: tileHover.hovered || tile.highlighted ? IrisStyle.fillActive : IrisStyle.fillQuiet
                        border.width: tile.highlighted ? 1 : 0
                        border.color: IrisStyle.accent
                        scale: tilePress.pressed && !root.carrying ? IrisStyle.pressScale(0.96) : 1
                        Behavior on width { NumberAnimation { duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(tilePress.pressed ? 80 : 200); easing.type: IrisStyle.feedbackEasing } }
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: Math.round(8 * root.d)
                            visible: tile.pictured
                            source: tile.pictureUrl
                            fillMode: Image.PreserveAspectFit
                            asynchronous: tile.live === null
                            cache: false
                            smooth: true
                            mipmap: true
                            opacity: tile.on ? 0.45 : 1
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                        }
                        // Never seen yet: its glyph stands in.
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !tile.pictured
                            text: tile.modelData.glyph
                            iconSize: Math.round(40 * root.d)
                            fill: 1
                            color: tile.modelData.tint
                            opacity: tile.on ? 0.45 : 1
                        }

                        // Add, or already out.
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Math.round(6 * root.d)
                            width: Math.round(20 * root.d)
                            height: width
                            radius: IrisStyle.capsule(width)
                            color: tile.on ? IrisStyle.raised : IrisStyle.accent
                            border.width: tile.on ? 1 : 0
                            border.color: IrisStyle.hairline
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: tile.on ? "check" : "add"
                                iconSize: Math.round(14 * root.d)
                                font.weight: Font.DemiBold
                                color: tile.on ? IrisStyle.text : IrisStyle.inkOnAccent
                            }
                        }
                    }

                    IrisText {
                        id: nameText
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.pictureHeight + root.nameGap
                        width: Math.min(implicitWidth, Math.max(plate.width, Math.round(96 * root.d)))
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name
                        color: tile.on ? IrisStyle.muted : IrisStyle.subtext
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.Medium)
                        elide: Text.ElideRight
                    }

                    HoverHandler { id: tileHover; cursorShape: root.carrying ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                    MouseArea {
                        id: tilePress
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // Once a picture is lifted the row may not take the drag for a scroll.
                        preventStealing: root.carrying
                        property point pressAt: Qt.point(0, 0)
                        property bool lifted: false
                        Accessible.role: Accessible.Button
                        Accessible.name: tile.on ? Translation.tr("%1, on the desktop").arg(tile.modelData.name)
                            : Translation.tr("Add %1").arg(tile.modelData.name)
                        onPressed: mouse => { tilePress.pressAt = Qt.point(mouse.x, mouse.y); tilePress.lifted = false }
                        onPositionChanged: mouse => {
                            const at = tilePress.mapToItem(root.ghostLayer, mouse.x, mouse.y)
                            if (!root.carrying && (mouse.buttons & Qt.LeftButton)) {
                                const dx = mouse.x - tilePress.pressAt.x
                                const dy = mouse.y - tilePress.pressAt.y
                                if (Math.abs(dy) > 6 * root.d && Math.abs(dy) >= Math.abs(dx) * 0.6) {
                                    tilePress.lifted = true
                                    root.lift(tile, at)
                                }
                            }
                            if (root.carried === tile) root.carry(at)
                        }
                        onReleased: { if (root.carried === tile) root.drop() }
                        onCanceled: { if (root.carried === tile) root.drop() }
                        onClicked: mouse => {
                            if (tilePress.lifted) return
                            if (mouse.button === Qt.RightButton) root.putBack(tile)
                            else root.use(tile)
                        }
                    }
                }
            }
        }
    }

    IrisText {
        anchors.centerIn: tiles
        visible: root.shown.length === 0
        text: Translation.tr("No widget is called “%1”").arg(root.query)
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeBody
    }

    // The picture in hand: the size it will have on the card, a tile's size back over the shelf.
    Item {
        id: ghost
        parent: root.ghostLayer
        z: 100
        visible: false
        property bool ride: false
        property bool homing: false
        readonly property Item tile: root.carried
        readonly property real targetWidth: root.overCard ? ghost.logicalWidth * root.card.s : ghost.tileWidth
        readonly property real targetHeight: root.overCard ? ghost.logicalHeight * root.card.s : ghost.tileHeight
        property real logicalWidth: 0
        property real logicalHeight: 0
        property real tileWidth: 0
        property real tileHeight: 0
        property string url: ""
        property string glyph: ""
        property color tint: "transparent"
        function place(x: real, y: real, w: real, h: real, home: bool): void {
            if (!home) {
                const tile = root.carried
                ghost.logicalWidth = tile.logicalWidth
                ghost.logicalHeight = tile.logicalHeight
                ghost.tileWidth = w
                ghost.tileHeight = h
                ghost.url = tile.pictured ? tile.pictureUrl : ""
                ghost.glyph = tile.modelData.glyph
                ghost.tint = tile.modelData.tint
                ghost.x = x
                ghost.y = y
                ghost.width = w
                ghost.height = h
                ghost.visible = true
                return
            }
            homeX.to = x
            homeY.to = y
            homeW.to = w
            homeH.to = h
            homeAnim.restart()
        }
        // Follows the pointer, its centre on it, and changes size as it crosses from the shelf to the card.
        Binding { target: ghost; property: "x"; value: root.carryAt.x - ghost.width / 2; when: ghost.ride; restoreMode: Binding.RestoreNone }
        Binding { target: ghost; property: "y"; value: root.carryAt.y - ghost.height / 2; when: ghost.ride; restoreMode: Binding.RestoreNone }
        Binding { target: ghost; property: "width"; value: ghost.targetWidth; when: ghost.ride; restoreMode: Binding.RestoreNone }
        Binding { target: ghost; property: "height"; value: ghost.targetHeight; when: ghost.ride; restoreMode: Binding.RestoreNone }
        Behavior on width { enabled: ghost.ride; NumberAnimation { duration: IrisStyle.duration(180); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on height { enabled: ghost.ride; NumberAnimation { duration: IrisStyle.duration(180); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        ParallelAnimation {
            id: homeAnim
            NumberAnimation { id: homeX; target: ghost; property: "x"; duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
            NumberAnimation { id: homeY; target: ghost; property: "y"; duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
            NumberAnimation { id: homeW; target: ghost; property: "width"; duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
            NumberAnimation { id: homeH; target: ghost; property: "height"; duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
            onFinished: { ghost.visible = false; ghost.homing = false }
        }
        SequentialAnimation {
            id: ghostFade
            NumberAnimation { target: ghost; property: "fade"; from: 1; to: 0; duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing }
            ScriptAction { script: { ghost.visible = false; ghost.fade = 1 } }
        }
        property real fade: 1
        opacity: (root.overCard || ghost.homing || ghostFade.running ? 1 : 0.8) * ghost.fade

        Image {
            anchors.fill: parent
            visible: ghost.url.length > 0
            source: ghost.url
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        Rectangle {
            anchors.fill: parent
            visible: ghost.url.length === 0
            radius: Math.min(width, height) * 0.18
            color: IrisStyle.raised
            border.width: 1
            border.color: IrisStyle.hairlineStrong
            MaterialSymbol {
                anchors.centerIn: parent
                text: ghost.glyph
                iconSize: Math.round(Math.min(parent.width, parent.height) * 0.36)
                fill: 1
                color: ghost.tint
            }
        }
    }
}
