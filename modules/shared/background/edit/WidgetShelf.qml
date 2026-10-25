pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

// The shelf every family arranges the desktop with: each widget as its own picture, by aisle, found by name. Pulled onto
// the card a widget is pulled onto the desktop's lines (DesktopArrange) and lands exactly where the desktop drew it; a
// click puts it on a free spot. One already out is dimmed with a check: a click finds it, a pull slides it, a right click
// puts it back. The pictures are the widgets' own (DesktopEditStage), the last look on disk for the ones not out.
// A family gives its face (colours, type, motion and its head: aisles, search, settings) and the entries it offers.
Item {
    id: root

    required property string outputName
    required property Item ghostLayer
    required property QtObject face
    // { key, glyph, name, english, tint, words, category }, in the family's order.
    property var entries: []
    readonly property real d: root.face.d

    readonly property real pad: Math.round(12 * root.d)
    readonly property real headHeight: Math.round(32 * root.d)
    readonly property real headGap: Math.round(10 * root.d)
    readonly property real pictureHeight: Math.round(76 * root.d)
    readonly property real nameGap: Math.round(5 * root.d)
    readonly property real nameHeight: Math.round(15 * root.d)
    readonly property real tileGap: Math.round(10 * root.d)
    readonly property real fullHeight: root.pad + root.headHeight + root.headGap + root.pictureHeight + root.nameGap
        + root.nameHeight + root.pad

    readonly property var categoryNames: ({ all: Translation.tr("All"), today: Translation.tr("Today"), media: Translation.tr("Media"),
        system: Translation.tr("System"), notes: Translation.tr("Notes"), decor: Translation.tr("Decor") })
    readonly property var categories: ["all"].concat(DesktopWidgetRegistry.categoryOrder
        .filter(id => root.entries.some(entry => entry.category === id)))
        .map(id => ({ value: id, label: root.categoryNames[id] }))
    property string category: "all"

    // ── Pages: the widgets, then what the family offers beside them (its Island or bar, the Dock, the look) and the
    // saved desktops. A family lists them as { value, label } and draws its own (face.pageOf(value)); Presets is shared.
    property var pages: [{ value: "widgets", label: Translation.tr("Widgets") }, { value: "presets", label: Translation.tr("Presets") }]
    property string page: "widgets"
    readonly property bool onWidgets: root.page === "widgets"
    // A new page comes in from the side of the tab it was picked from, as the segmented thumb travels.
    property real pageShift: 0
    function goTo(page: string): void {
        if (page === root.page) return
        const from = root.pages.findIndex(entry => entry.value === root.page)
        const to = root.pages.findIndex(entry => entry.value === page)
        if (page !== "widgets") GlobalStates.widgetSearchText = ""
        root.naming = ""
        root.page = page
        shiftAnim.stop()
        root.pageShift = (to > from ? 1 : -1) * Math.round(36 * root.d)
        shiftAnim.start()
    }
    NumberAnimation {
        id: shiftAnim
        target: root
        property: "pageShift"
        to: 0
        duration: root.face.duration(300)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.face.morphCurve
    }

    // ── Finding a widget ──
    // The query searches every aisle. ↓/Tab and ↑ move along what matches, ↵ takes it, Escape clears, then lets go.
    readonly property string query: GlobalStates.widgetSearchText.trim()
    property bool searchFocused: false
    // A saved desktop being named takes the keys the same way: Escape gives the name up, Ctrl+Z edits the text.
    property string naming: ""
    readonly property bool searching: root.query.length > 0 || root.searchFocused || root.naming.length > 0
    readonly property var shown: {
        if (root.query.length === 0)
            return root.entries.filter(entry => root.category === "all" || entry.category === root.category)
        const hits = []
        root.entries.forEach((entry, order) => {
            const score = root.face.score(root.query, entry)
            if (score > 0) hits.push({ entry: entry, score: score, order: order })
        })
        hits.sort((a, b) => b.score - a.score || a.order - b.order)
        return hits.map(hit => hit.entry)
    }
    property int highlight: 0
    onQueryChanged: { root.highlight = 0; tiles.contentX = 0 }
    onCategoryChanged: tiles.contentX = 0
    function pick(category: string): void {
        GlobalStates.widgetSearchText = ""
        root.category = category
    }
    function openSearch(): void { headLoader.item?.focusSearch() }
    function escapeSearch(): void {
        if (root.naming.length > 0) root.naming = ""
        else if (GlobalStates.widgetSearchText.length > 0) GlobalStates.widgetSearchText = ""
        else { headLoader.item?.dropSearch(); GlobalStates.widgetSearchOpen = false }
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
            DesktopArrange.ping(root.outputName, root.outputName + "::" + tile.key)
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
    // Over the card the picture is pulled onto the desktop's lines like a widget carried there, and the desktop draws
    // where it will land; it lands exactly there.
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

    // ── Head: the family's aisles, search and settings ──
    Loader {
        id: headLoader
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.headHeight
        sourceComponent: root.face.head
        onLoaded: headLoader.item.shelf = root
    }
    Component.onCompleted: if (GlobalStates.widgetSearchOpen) Qt.callLater(root.openSearch)

    // ── The row of pictures ──
    Flickable {
        id: tiles
        visible: root.onWidgets
        transform: Translate { x: root.onWidgets ? root.pageShift : 0 }
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
            NumberAnimation { duration: root.face.duration(260); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve }
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
                        radius: root.face.plateRadius
                        color: tileHover.hovered || tile.highlighted ? root.face.fillActive : root.face.fillQuiet
                        border.width: tile.highlighted ? 1 : 0
                        border.color: root.face.accent
                        scale: tilePress.pressed && !root.carrying ? root.face.pressScale(0.96) : 1
                        Behavior on width { NumberAnimation { duration: root.face.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve } }
                        Behavior on scale { NumberAnimation { duration: root.face.duration(tilePress.pressed ? 80 : 200); easing.type: root.face.feedbackEasing } }
                        Behavior on color { ColorAnimation { duration: root.face.duration(110); easing.type: root.face.feedbackEasing } }

                        // Read straight at the size it shows: a smooth downscale keeps the widget's type sharp, where a
                        // full-size picture through mipmaps came out blurred.
                        Image {
                            id: tilePicture
                            readonly property real dpr: tilePicture.Window.window?.devicePixelRatio ?? 1
                            anchors.fill: parent
                            anchors.margins: Math.round(8 * root.d)
                            visible: tile.pictured
                            source: tile.pictureUrl
                            sourceSize: Qt.size(Math.ceil(tilePicture.width * tilePicture.dpr), Math.ceil(tilePicture.height * tilePicture.dpr))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: tile.live === null
                            cache: false
                            smooth: true
                            opacity: tile.on ? 0.45 : 1
                            Behavior on opacity { NumberAnimation { duration: root.face.duration(160); easing.type: root.face.feedbackEasing } }
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
                            radius: width / 2
                            color: tile.on ? root.face.raised : root.face.accent
                            border.width: tile.on ? 1 : 0
                            border.color: root.face.hairline
                            Behavior on color { ColorAnimation { duration: root.face.duration(160); easing.type: root.face.feedbackEasing } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: tile.on ? "check" : "add"
                                iconSize: Math.round(14 * root.d)
                                font.weight: Font.DemiBold
                                color: tile.on ? root.face.ink : root.face.inkOnAccent
                            }
                        }
                    }

                    StyledText {
                        id: nameText
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.pictureHeight + root.nameGap
                        width: Math.min(implicitWidth, Math.max(plate.width, Math.round(96 * root.d)))
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name
                        color: tile.on ? root.face.muted : root.face.subtext
                        font.family: root.face.fontMain
                        font.pixelSize: root.face.typeMeta
                        font.weight: root.face.weight(Font.Medium)
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

    // The family's own pages and the saved desktops, where the pictures were.
    Loader {
        id: pageLoader
        x: tiles.x
        y: tiles.y
        width: tiles.width
        height: tiles.height
        active: !root.onWidgets
        transform: Translate { x: root.pageShift }
        sourceComponent: root.page === "presets" ? presetsPage : root.face.pageOf?.(root.page) ?? null
    }

    StyledText {
        anchors.centerIn: tiles
        visible: root.onWidgets && root.shown.length === 0
        text: Translation.tr("No widget is called “%1”").arg(root.query)
        color: root.face.muted
        font.family: root.face.fontMain
        font.pixelSize: root.face.typeBody
    }

    // The picture in hand: the size it will have on the card, a tile's size back over the shelf.
    Item {
        id: ghost
        parent: root.ghostLayer
        z: 100
        visible: false
        property bool ride: false
        property bool homing: false
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
        Behavior on width { enabled: ghost.ride; NumberAnimation { duration: root.face.duration(180); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve } }
        Behavior on height { enabled: ghost.ride; NumberAnimation { duration: root.face.duration(180); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve } }
        ParallelAnimation {
            id: homeAnim
            NumberAnimation { id: homeX; target: ghost; property: "x"; duration: root.face.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve }
            NumberAnimation { id: homeY; target: ghost; property: "y"; duration: root.face.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve }
            NumberAnimation { id: homeW; target: ghost; property: "width"; duration: root.face.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve }
            NumberAnimation { id: homeH; target: ghost; property: "height"; duration: root.face.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: root.face.morphCurve }
            onFinished: { ghost.visible = false; ghost.homing = false }
        }
        SequentialAnimation {
            id: ghostFade
            NumberAnimation { target: ghost; property: "fade"; from: 1; to: 0; duration: root.face.duration(200); easing.type: root.face.feedbackEasing }
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
        }
        Rectangle {
            anchors.fill: parent
            visible: ghost.url.length === 0
            radius: Math.min(width, height) * 0.18
            color: root.face.raised
            border.width: 1
            border.color: root.face.hairlineStrong
            MaterialSymbol {
                anchors.centerIn: parent
                text: ghost.glyph
                iconSize: Math.round(Math.min(parent.width, parent.height) * 0.36)
                fill: 1
                color: ghost.tint
            }
        }
    }

    // ── Saved desktops: save this one, wear one (Undo takes it back), rename or remove it in place. ──
    Component {
        id: presetsPage
        Flickable {
            id: presetRow
            readonly property real plateWidth: Math.round(root.pictureHeight * 16 / 9)
            readonly property string worn: { Config.revision; return DesktopPresets.wornId() }
            property string confirming: ""
            contentWidth: presetContent.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y
                    presetRow.contentX = Math.max(0, Math.min(presetRow.contentWidth - presetRow.width, presetRow.contentX - delta / 120 * Math.round(180 * root.d)))
                }
            }
            Row {
                id: presetContent
                spacing: root.tileGap
                height: presetRow.height

                // Save this desktop: a plate with nothing in it yet.
                Item {
                    width: presetRow.plateWidth
                    height: presetRow.height
                    Rectangle {
                        id: savePlate
                        width: parent.width
                        height: root.pictureHeight
                        radius: root.face.plateRadius
                        color: saveArea.containsMouse ? root.face.fillActive : "transparent"
                        border.width: 1
                        border.color: root.face.hairlineStrong
                        scale: saveArea.pressed ? root.face.pressScale(0.96) : 1
                        Behavior on scale { NumberAnimation { duration: root.face.duration(saveArea.pressed ? 80 : 200); easing.type: root.face.feedbackEasing } }
                        Behavior on color { ColorAnimation { duration: root.face.duration(110); easing.type: root.face.feedbackEasing } }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: Math.round(28 * root.d)
                            color: root.face.ink
                        }
                        MouseArea {
                            id: saveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: Translation.tr("Save this desktop")
                            onClicked: root.naming = DesktopPresets.save("")
                        }
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.pictureHeight + root.nameGap
                        text: Translation.tr("Save this desktop")
                        color: root.face.subtext
                        font.family: root.face.fontMain
                        font.pixelSize: root.face.typeMeta
                        font.weight: root.face.weight(Font.Medium)
                    }
                }

                Repeater {
                    // Factory desktops first (worn, never renamed or removed), then the ones the person saved.
                    model: ScriptModel { values: DesktopPresets.factory.concat(DesktopPresets.presets); objectProp: "id" }
                    delegate: Item {
                        id: preset
                        required property var modelData
                        readonly property bool worn: presetRow.worn === preset.modelData.id
                        readonly property bool confirming: presetRow.confirming === preset.modelData.id
                        readonly property bool factory: DesktopPresets.isFactory(preset.modelData.id)
                        width: presetRow.plateWidth
                        height: presetRow.height

                        Rectangle {
                            id: presetPlate
                            width: parent.width
                            height: root.pictureHeight
                            radius: root.face.plateRadius
                            color: root.face.fillQuiet
                            border.width: preset.worn ? Math.max(1, Math.round(1.5 * root.d)) : 0
                            border.color: root.face.ink
                            scale: wearArea.pressed ? root.face.pressScale(0.96) : 1
                            Behavior on scale { NumberAnimation { duration: root.face.duration(wearArea.pressed ? 80 : 200); easing.type: root.face.feedbackEasing } }
                            // The desktop it saves: this wallpaper under its widgets, where they stood.
                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: Math.round(5 * root.d)
                                radius: Math.max(0, presetPlate.radius - Math.round(5 * root.d))
                                color: "transparent"
                                Image {
                                    anchors.fill: parent
                                    source: Wallpapers.effectiveWallpaperUrl
                                    sourceSize: Qt.size(Math.round(presetRow.plateWidth * 2), Math.round(root.pictureHeight * 2))
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    opacity: wearArea.containsMouse || preset.worn ? 0.9 : 0.6
                                    Behavior on opacity { NumberAnimation { duration: root.face.duration(160); easing.type: root.face.feedbackEasing } }
                                }
                                Repeater {
                                    model: DesktopPresets.placesOn(preset.modelData.id, root.outputName)
                                    Rectangle {
                                        required property var modelData
                                        x: Math.round(modelData.x * parent.width)
                                        y: Math.round(modelData.y * parent.height)
                                        readonly property real share: modelData.size === "small" ? 0.75 : modelData.size === "large" ? 1.4 : 1
                                        width: Math.round(parent.width * 0.1 * share)
                                        height: Math.round(parent.height * 0.14 * share)
                                        radius: Math.round(3 * root.d)
                                        color: Qt.rgba(1, 1, 1, 0.82)
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.25)
                                    }
                                }
                            }
                            MouseArea {
                                id: wearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: Translation.tr("Wear %1").arg(preset.modelData.name)
                                onClicked: { presetRow.confirming = ""; DesktopPresets.wear(preset.modelData.id) }
                                onDoubleClicked: if (!preset.factory) root.naming = preset.modelData.id
                            }
                            // Worn: a check where a widget shows it is out.
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Math.round(6 * root.d)
                                width: Math.round(20 * root.d)
                                height: width
                                radius: width / 2
                                color: root.face.accent
                                scale: preset.worn && !keys.shown ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: root.face.duration(200); easing.type: root.face.feedbackEasing } }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: Math.round(14 * root.d)
                                    font.weight: Font.DemiBold
                                    color: root.face.inkOnAccent
                                }
                            }
                            // Rename and remove, at the corner while the pointer is over it; remove asks once.
                            Row {
                                id: keys
                                readonly property bool shown: !preset.factory && (wearArea.containsMouse || renameKey.hovered || removeKey.hovered || preset.confirming)
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Math.round(6 * root.d)
                                spacing: Math.round(4 * root.d)
                                opacity: keys.shown ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: root.face.duration(140); easing.type: root.face.feedbackEasing } }
                                CornerKey {
                                    id: renameKey
                                    glyph: "edit"
                                    name: Translation.tr("Rename")
                                    onActivated: root.naming = preset.modelData.id
                                }
                                CornerKey {
                                    id: removeKey
                                    glyph: preset.confirming ? "delete_forever" : "delete"
                                    name: preset.confirming ? Translation.tr("Remove %1").arg(preset.modelData.name) : Translation.tr("Remove")
                                    warn: preset.confirming
                                    onActivated: {
                                        if (preset.confirming) { presetRow.confirming = ""; DesktopPresets.remove(preset.modelData.id) }
                                        else presetRow.confirming = preset.modelData.id
                                    }
                                }
                            }
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.pictureHeight + root.nameGap
                            width: Math.min(implicitWidth, parent.width)
                            visible: root.naming !== preset.modelData.id
                            text: preset.confirming ? Translation.tr("Remove?") : preset.modelData.name
                            color: preset.worn ? root.face.ink : root.face.subtext
                            font.family: root.face.fontMain
                            font.pixelSize: root.face.typeMeta
                            font.weight: root.face.weight(preset.worn ? Font.DemiBold : Font.Medium)
                            elide: Text.ElideRight
                        }
                        TextInput {
                            id: nameInput
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.pictureHeight + root.nameGap
                            width: parent.width
                            visible: root.naming === preset.modelData.id
                            horizontalAlignment: TextInput.AlignHCenter
                            color: root.face.ink
                            selectionColor: root.face.fillActive
                            selectedTextColor: root.face.ink
                            font.family: root.face.fontMain
                            font.pixelSize: root.face.typeMeta
                            font.weight: root.face.weight(Font.DemiBold)
                            Accessible.name: Translation.tr("Name")
                            onVisibleChanged: if (visible) { text = preset.modelData.name; forceActiveFocus(); selectAll() }
                            onAccepted: { DesktopPresets.rename(preset.modelData.id, text); root.naming = "" }
                            onActiveFocusChanged: if (!activeFocus && visible) { DesktopPresets.rename(preset.modelData.id, text); root.naming = "" }
                            Keys.onEscapePressed: event => { root.naming = ""; event.accepted = true }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.bottom
                                anchors.topMargin: Math.round(2 * root.d)
                                height: 1
                                color: root.face.accent
                            }
                        }
                    }
                }

                // Nothing saved yet: what this row is for, once.
                StyledText {
                    visible: DesktopPresets.presets.length === 0
                    height: root.pictureHeight
                    verticalAlignment: Text.AlignVCenter
                    width: Math.min(implicitWidth, Math.round(360 * root.d))
                    wrapMode: Text.WordWrap
                    text: Translation.tr("Save how this desktop looks and wear it again whenever you like.")
                    color: root.face.muted
                    font.family: root.face.fontMain
                    font.pixelSize: root.face.typeBody
                }
            }
        }
    }

    component CornerKey: Rectangle {
        id: key
        property string glyph: ""
        property string name: ""
        property bool warn: false
        readonly property bool hovered: keyArea.containsMouse
        signal activated()
        width: Math.round(22 * root.d)
        height: width
        radius: width / 2
        color: key.warn ? root.face.danger : keyArea.containsMouse ? root.face.fillActive : root.face.raised
        border.width: key.warn ? 0 : 1
        border.color: root.face.hairline
        Behavior on color { ColorAnimation { duration: root.face.duration(110); easing.type: root.face.feedbackEasing } }
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: Math.round(14 * root.d)
            color: key.warn ? root.face.inkOnAccent : root.face.ink
        }
        MouseArea {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: key.name
            onClicked: key.activated()
        }
    }
}
