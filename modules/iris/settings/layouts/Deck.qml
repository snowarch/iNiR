pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.settings
import qs.modules.iris.settings.layouts.deck as Skins // so Quickshell mirrors the skins IrisSkin loads by url

// Deck: StandBy and the Apple TV row. Over the desktop the Island stretches into the head (the area before, the search,
// the area after); the open area is one hero card (its stage under its Dot title, then its rows), the neighbours stand
// back at 92 % on both sides; a dot pager under the card says where you are (the open one a bar, a signal dot where an
// area needs you). Arrows turn and walk it, Enter acts, the wheel turns it. In a window the neighbours are spines.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: card.width
    readonly property real need: 0
    readonly property string voice: "deck"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    // Its groups fold under their heads, the first two open (IrisSettings.groupOpen).
    readonly property bool folds: true
    readonly property string searchHint: Translation.tr("Search")

    readonly property bool windowed: Boolean(root.host?.windowed ?? true)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var room: root.host?.room ?? ({ x: 0, y: 0, width: root.width, height: root.height })
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    function neighbour(step: int): var { return root.sections[root.aim + step] ?? null }

    // ── Travel: one spring carries the whole deck, `pos` is where it stands counted in areas. Presses retarget it and it
    // keeps its speed, so three quick ones glide three cards in one move. Over the desktop the area opens once its card
    // has nearly arrived: the cards it only passed never build their rows.
    property int aim: 0
    // Where the deck stood before: going back and forth between two areas keeps the cards of both.
    property int trail: -1
    property int lastAim: -1
    onAimChanged: { root.trail = root.lastAim; root.lastAim = root.aim }
    readonly property real pos: travel.value
    readonly property real pitch: root.windowed ? Math.round(root.cardRect.width * 0.22) : Math.round(root.cardRect.width * (1 + root.nearScale) / 2 + root.gap)
    readonly property real shift: (root.current - root.pos) * root.pitch
    IrisSpring { id: travel; surface: "settings"; intent: "move"; animate: IrisStyle.motionEnabled }
    function goTo(index: int): void {
        const next = Math.max(0, Math.min(root.sections.length - 1, index))
        if (next === root.aim && next === root.current) return
        // a place several cards off (the pager) is stood at, not glided to: the way there made and broke every card on it
        if (Math.abs(next - root.aim) > 2) root.standAt(next)
        root.aim = next
        travel.to = next
        if (!root.sided) root.host.selectSection(root.sections[next].id)
        else root.arrive()
    }
    function turn(delta: int): void { root.goTo(root.aim + delta) }
    // The area is chosen once the deck stands: chosen halfway, the engine re-read the area and built its page in the
    // frames of the move, and the turn froze and skipped to its end.
    function arrive(): void {
        if (root.dragging || root.aim === root.current || root.moving) return
        const entry = root.sections[root.aim]
        if (entry) root.host.selectSection(entry.id)
    }
    onPosChanged: if (!admit.running) admit.start()
    // While the deck travels nothing is built, read or refitted: the cards carry what they hold, as pictures.
    readonly property bool moving: root.dragging || Math.abs(root.pos - root.aim) > 0.02
    // a beat later: the move can end inside the engine's own section change (a jump), and choosing there looped it
    onMovingChanged: if (!root.moving) { Qt.callLater(root.arrive); admit.start() }
    onCurrentChanged: {
        // Opened from elsewhere (the pager of a shortcut, IPC, search): the deck follows.
        if (root.aim !== root.current) {
            // a place, not a turn: an area several cards off just stands there
            if (Math.abs(root.current - root.pos) > 2) root.standAt(root.current)
            root.aim = root.current
            travel.to = root.current
        }
        root.engaged = false
        root.cursor = -1
        root.place()
        root.land()
    }
    // Stands the deck at a place before aiming there, so the cards held never span the way between.
    function standAt(index: int): void {
        travel.to = index
        travel.jump()
        root.lastAim = index
    }
    Component.onCompleted: { root.standAt(root.current); root.aim = root.current; admit.start() }
    // The open area's page: over the desktop the open card's own (each card holds its page), in a window the pool's.
    property Item heroPage: null
    readonly property Item openPage: root.sided ? root.heroPage : (pool.shown === root.section ? pool.shownItem : null)
    readonly property bool live: root.searching || root.openPage !== null
    // What the hero's pages leave free: the keys at the card's corner, the key bar under the rows while driving.
    readonly property real heroReserve: keys.width + root.u(30)
    readonly property real heroFoot: root.driving ? hintBar.height + root.u(6) : 0
    onLiveChanged: root.land()
    // A group asked for by name lands once its area's page stands.
    property string wantedGroup: ""
    function showGroup(key: string): void {
        if (root.openPage?.showGroup) root.openPage.showGroup(key)
        else root.wantedGroup = key
    }
    function land(): void {
        if (root.wantedGroup.length > 0 && root.openPage) { root.openPage.showGroup?.(root.wantedGroup); root.wantedGroup = "" }
    }

    // ── Driven like a console menu: ◀ ▶ turn the deck, ▲ ▼ walk the head and the rows, ⏎ or Space change the focused
    // row in place (a choice or a range is held: ◀ ▶ then step it, live), Esc lets go.
    property bool driving: false
    property int cursor: -1
    property bool engaged: false
    readonly property bool paged: Number(root.host?.advancedPage ?? -1) >= 0
    // The page asked for is the one the open card already holds (the Hub on System's card): the card stays the page.
    readonly property bool held: root.paged && Number(root.openPage?.heldPage ?? -1) === Number(root.host?.advancedPage ?? -1)
    // A search's results, or a shared page no card holds, take the card's place under the keys.
    readonly property bool slotted: root.searching || (root.paged && !root.held)
    readonly property bool drawsRows: true
    // Where the keys walk: the page in front, or the engine's rows during a search or a shared page.
    readonly property Item stopsRoot: root.slotted ? rowsSlot : (root.openPage?.rowsRoot ?? null)
    readonly property Item flick: {
        root.section
        return root.slotted ? root.findFlick(rowsSlot) : (root.openPage?.flick ?? null)
    }
    function findFlick(item: Item): Item {
        for (const child of item?.children ?? []) {
            if (child.contentY !== undefined && child.contentHeight !== undefined && child.visible) return child
            const deeper = root.findFlick(child)
            if (deeper) return deeper
        }
        return null
    }
    function collect(item: Item, out: var): void {
        for (const child of item?.children ?? []) {
            if (!child.visible || child === ring) continue
            if (child.deckStop === true) { out.push(child); continue }
            if (child.spec !== undefined && typeof child.commit === "function" && ["switch", "choice", "range", "action"].includes(String(child.spec?.kind))) { out.push(child); continue }
            root.collect(child, out)
        }
    }
    function stops(): var {
        const out = []
        if (!root.stopsRoot) return out
        root.collect(root.stopsRoot, out)
        return out.map(item => ({ item: item, y: item.mapToItem(card, 0, 0).y })).sort((a, b) => a.y - b.y).map(entry => entry.item)
    }
    function focused(): Item { return root.cursor >= 0 ? (root.stops()[root.cursor] ?? null) : null }
    // The ring rides inside the row it marks: placed by hand it chased every scroll and late layout of the page and
    // ran past the card (10-25, "las líneas de focus se corren").
    function place(): void {
        const item = root.focused()
        ring.parent = item ?? card
        ring.shown = item !== null
    }
    function reveal(item: Item): void {
        if (!root.flick || !item) return
        const top = item.mapToItem(root.flick.contentItem, 0, 0).y
        const pad = root.u(24)
        const end = Math.max(0, root.flick.contentHeight - root.flick.height)
        let to = root.flick.contentY
        if (top - pad < to) to = top - pad
        else if (top + item.height + pad > to + root.flick.height) to = top + item.height + pad - root.flick.height
        to = Math.max(0, Math.min(end, to))
        if (Math.abs(to - root.flick.contentY) < 1) return
        scrollTo.target = root.flick
        scrollTo.to = to
        scrollTo.restart()
    }
    NumberAnimation { id: scrollTo; property: "contentY"; duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
    Connections { target: root.flick; ignoreUnknownSignals: true; function onContentYChanged(): void { root.place() } }
    Timer { id: replace; interval: 60; onTriggered: { root.place(); root.reveal(root.focused()) } }
    function move(delta: int): void {
        const list = root.stops()
        root.engaged = false
        root.cursor = Math.max(-1, Math.min(list.length - 1, root.cursor + delta))
        root.place()
        root.reveal(root.focused())
    }
    function activate(): void {
        const item = root.focused()
        if (!item) return
        if (item.deckStop === true) { item.toggle(); replace.restart(); return }
        const spec = item.spec
        if (spec.kind === "switch") {
            const on = spec.invert ? !item.value : !!item.value
            item.commit(spec.invert ? on : !on)
        } else if (spec.kind === "action") spec.run()
        else root.engaged = !root.engaged
    }
    function adjust(delta: int): void {
        const item = root.focused()
        const spec = item?.spec
        if (!spec) return
        if (spec.kind === "range") {
            const step = Number(spec.step ?? 1)
            const next = Math.max(spec.min, Math.min(spec.max, Number(item.value) + delta * step))
            item.commit(Number(next.toFixed(4)))
        } else if (spec.kind === "choice") {
            const list = item.choices ?? []
            const at = list.findIndex(entry => IrisOptions.same(entry.value, item.value))
            const next = list[Math.max(0, Math.min(list.length - 1, at + delta))]
            if (next) item.commit(next.value)
        }
    }
    function takeKey(event: var): bool {
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return false
        const key = event.key
        if (key === Qt.Key_Left || key === Qt.Key_Right) {
            const delta = key === Qt.Key_Left ? -1 : 1
            if (root.engaged) root.adjust(delta)
            else root.turn(delta)
            return true
        }
        if (key === Qt.Key_Up || key === Qt.Key_Down) {
            root.driving = true
            root.move(key === Qt.Key_Up ? -1 : 1)
            return true
        }
        if ((key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) && root.cursor >= 0) {
            root.activate()
            return true
        }
        return false
    }
    // Esc lets go of the innermost thing first: a held value, then the focused row, then Settings.
    function release(): bool {
        if (root.engaged) { root.engaged = false; return true }
        if (root.cursor >= 0) { root.cursor = -1; root.place(); return true }
        return false
    }
    // The wheel over the deck's sides turns it, a notch a card (bursts just retarget the spring). Two fingers sideways
    // carry the deck with them and let go onto the nearest card, at the speed they left with.
    property real wheelAcc: 0
    property bool dragging: false
    property real dragPos: 0
    property var dragTrail: []
    Timer { id: wheelRest; interval: 200; onTriggered: root.wheelAcc = 0 }
    Timer { id: swipeRest; interval: 120; onTriggered: root.letGo() }
    function wheel(event: var): void {
        const px = event.pixelDelta.x
        if (px !== 0 && Math.abs(px) >= Math.abs(event.pixelDelta.y)) {
            if (!root.dragging) { root.dragging = true; root.dragPos = root.pos; root.dragTrail = [] }
            const last = root.sections.length - 1
            let next = root.dragPos - px / root.pitch
            // past either end the deck gives a little, like a page pulled past its edge
            if (next < 0 || next > last) next = root.dragPos - 0.3 * px / root.pitch
            root.dragPos = Math.max(-0.4, Math.min(last + 0.4, next))
            root.dragTrail = root.dragTrail.concat([{ t: Date.now(), p: root.dragPos }]).slice(-6)
            travel.to = root.dragPos
            travel.jump()
            swipeRest.restart()
            return
        }
        const delta = event.angleDelta.x !== 0 ? -event.angleDelta.x : -event.angleDelta.y
        if (delta === 0) return
        if (Math.sign(delta) !== Math.sign(root.wheelAcc)) root.wheelAcc = 0
        root.wheelAcc += delta
        wheelRest.restart()
        while (Math.abs(root.wheelAcc) >= 120) {
            const step = Math.sign(root.wheelAcc)
            root.wheelAcc -= 120 * step
            root.turn(step)
        }
    }
    function letGo(): void {
        if (!root.dragging) return
        const trail = root.dragTrail
        const first = trail[0], end = trail[trail.length - 1]
        const span = first && end ? (end.t - first.t) / 1000 : 0
        const speed = span > 0 ? (end.p - first.p) / span : 0
        root.dragging = false
        const target = Math.max(0, Math.min(root.sections.length - 1, Math.round(root.dragPos + speed * 0.12)))
        // keep the fingers' speed: the spring chases from it instead of starting a fresh curve
        travel.start()
        travel.velocity = speed
        travel.chase = travel.params("move").response
        root.aim = target
        travel.to = target
        if (!root.sided) { if (target !== root.current) root.host.selectSection(root.sections[target].id) }
        else root.arrive()
    }
    // The head is the Island stretched: it takes the Island's own place at the top of the screen and grows sideways.
    readonly property real gap: root.u(24)
    readonly property rect headRect: {
        if (root.windowed) return Qt.rect(0, 0, root.width, root.u(60))
        // under the Island, never over it: the resting Island and its side bubbles stay in view
        const w = Math.min(root.u(760), root.room.width)
        return Qt.rect(Math.round((root.width - w) / 2), root.room.y, w, root.u(50))
    }
    readonly property rect cardRect: {
        if (root.windowed) return Qt.rect(deckRow.x + cardSlot.x, deckRow.y, cardSlot.width, deckRow.height)
        const top = root.headRect.y + root.headRect.height + root.u(14)
        const w = Math.round(Math.max(Math.min(root.u(640), root.room.width), Math.min(root.u(820), root.room.width * 0.46)))
        return Qt.rect(Math.round((root.width - w) / 2), top, w, Math.max(0, root.room.y + root.room.height - top))
    }
    readonly property real sideWidth: Math.min(root.u(420), Math.floor((root.width - root.cardRect.width) / 2) - 2 * root.gap - root.u(40))
    readonly property bool sided: !root.windowed && root.sideWidth >= root.u(240)
    // The neighbours are the card itself, smaller (the picker's reel): the same page at 84 % beside it, 72 % two out,
    // centred on its middle. Uniform, so a page laid out once at the card's size scales into every place.
    readonly property real nearScale: 0.84
    readonly property real farScale: 0.72
    readonly property real cardInset: root.u(root.windowed ? 8 : 12)
    function sideRect(step: int): rect {
        const c = root.cardRect
        const s = Math.abs(step) === 1 ? root.nearScale : root.farScale
        const w = Math.round(c.width * s)
        const h = Math.round(c.height * s)
        const near = Math.round(c.width * root.nearScale)
        const x = step === 1 ? c.x + c.width + root.gap
            : step === -1 ? c.x - root.gap - w
            : step > 0 ? c.x + c.width + 2 * root.gap + near
            : c.x - 2 * root.gap - near - w
        return Qt.rect(Math.round(x), Math.round(c.y + (c.height - h) / 2), w, h)
    }
    // Where a card stands `o` areas off the open one: between the slots it slides and resizes on the one spring.
    function slot(k: int): rect {
        if (k === 0) return root.cardRect
        if (Math.abs(k) <= 2) return root.sideRect(k)
        const far = root.sideRect(k < 0 ? -2 : 2)
        return Qt.rect(far.x + Math.sign(k) * (Math.abs(k) - 2) * (far.width + root.gap), far.y, far.width, far.height)
    }
    function rectAt(o: real): rect {
        const lo = Math.floor(o)
        const t = o - lo
        const a = root.slot(lo)
        if (t <= 0) return a
        const b = root.slot(lo + 1)
        return Qt.rect(Math.round(a.x + (b.x - a.x) * t), Math.round(a.y + (b.y - a.y) * t),
            Math.round(a.width + (b.width - a.width) * t), Math.round(a.height + (b.height - a.height) * t))
    }

    // The bodies IrisSettings draws and blurs: the head, the card and each neighbour.
    readonly property var panes: {
        if (root.windowed) return []
        const out = []
        const h = root.headRect
        out.push({ id: "deckHead", x: h.x, y: h.y, width: h.width, height: h.height, radius: h.height / 2 })
        if (!root.sided) {
            const c = root.cardRect
            out.push({ id: "deckCard", x: c.x + root.shift, y: c.y, width: c.width, height: c.height, radius: IrisStyle.fieldChamfer ? 0 : root.u(30) })
            return out
        }
        const p = root.pos
        for (let i = Math.max(0, Math.ceil(p - 2.5)); i <= Math.min(root.sections.length - 1, Math.floor(p + 2.5)); i++) {
            const o = i - p
            if (Math.abs(o) >= 2.5) continue
            const r = root.rectAt(o)
            out.push({ id: "deckArea" + root.sections[i].id, x: r.x, y: r.y, width: r.width, height: r.height,
                radius: IrisStyle.fieldChamfer ? 0 : Math.round(root.u(30) * r.width / Math.max(1, root.cardRect.width)) })
        }
        return out
    }

    // ── The head: the area before, the search, the area after.
    MouseArea {
        id: head
        x: root.headRect.x
        y: root.headRect.y
        width: root.headRect.width
        height: root.headRect.height
        onWheel: wheel => root.wheel(wheel)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.u(8)
            anchors.rightMargin: root.u(8)
            spacing: root.u(10)
            StepKey { step: -1; Layout.preferredWidth: root.u(170) }
            Item { id: searchSlot; Layout.fillWidth: true; Layout.preferredHeight: root.u(34) }
            StepKey { step: 1; Layout.preferredWidth: root.u(170) }
        }
    }

    // ── In a window: the neighbours as spines either side of the card.
    RowLayout {
        id: deckRow
        visible: root.windowed
        x: root.u(10)
        y: root.headRect.height
        width: root.width - root.u(20)
        height: root.height - y - root.u(34)
        spacing: root.u(8)
        Spine { step: -2 }
        Spine { step: -1 }
        Item { id: cardSlot; Layout.fillWidth: true; Layout.fillHeight: true }
        Spine { step: 1 }
        Spine { step: 2 }
    }

    // ── The cards over the desktop: one per area near where the deck stands, each its area's own page.
    // Pages are let in one a beat, nearest first, once the deck stands: while the body opens only the open one, then
    // out to two either side, so a turn of one or two finds every card it brings in already built.
    readonly property real reach: Boolean(root.host?.bodySettled ?? true) ? 3.2 : 0.5
    onReachChanged: admit.start()
    Timer {
        id: admit
        interval: 16
        repeat: true
        onTriggered: {
            // While a run goes on, only a card about to show is let in (in slices): an empty one crossing read as a page
            // that loads late (10-25).
            const reach = root.moving ? Math.min(root.reach, 2.2) : root.reach
            let best = null
            for (let i = 0; i < cards.count; i++) {
                const card = cards.itemAt(i)
                if (card && !card.admitted && card.wanted && card.far < reach && (!best || card.far < best.far)) best = card
            }
            if (best) best.admitted = true
            else admit.stop()
        }
    }
    // Pictures of the cards two or more out are taken again once a look change settles, a card at a time, never in
    // the change's own frame (DeckCard.held).
    readonly property string look: [IrisStyle.surfaceOpaque, IrisStyle.readingCard, IrisStyle.accent, IrisStyle.text,
        IrisStyle.muted, IrisStyle.fill, IrisStyle.hairline, IrisStyle.settingsDensity].join("|")
    property int lookRevision: 0
    onLookChanged: { root.lookRevision++; restale.restart() }
    Timer {
        id: restale
        interval: 1500
        onTriggered: {
            for (let i = 0; i < cards.count; i++) {
                const card = cards.itemAt(i)
                if (card && card.picture.toString() !== "") card.pictureStale = true
            }
            admit.start()
        }
    }
    // The deck holds the cards within two of where it stands (and where it is going, and where it just was): going back
    // and forth between two areas keeps both, and a card made at the edge on the way and broken on the way back was
    // the bulk of a turn's work.
    readonly property int stood: root.trail >= 0 && Math.abs(root.trail - root.aim) <= 2 ? root.trail : root.aim
    readonly property int windowFrom: Math.max(0, Math.floor(Math.min(root.pos, root.aim, root.stood)) - 3)
    readonly property int windowTo: Math.min(root.sections.length - 1, Math.ceil(Math.max(root.pos, root.aim, root.stood)) + 3)
    Repeater {
        id: cards
        model: ScriptModel { values: root.sided ? root.sections.slice(root.windowFrom, root.windowTo + 1) : []; objectProp: "id" }
        DeckCard {}
    }

    // ── The hero: the area's Dot title over its stage, then its rows.
    Item {
        id: card
        x: root.cardRect.x + (root.windowed || root.sided ? 0 : root.shift)
        y: root.cardRect.y
        width: root.cardRect.width
        height: root.cardRect.height
        readonly property real inset: root.cardInset
        clip: true
        transform: Translate { x: root.windowed ? root.shift : 0 }
        Rectangle {
            visible: root.windowed
            anchors.fill: parent
            radius: IrisStyle.fieldChamfer ? 0 : root.u(22)
            color: IrisStyle.glassy ? IrisStyle.readingSidebar : Qt.rgba(0, 0, 0, IrisStyle.light ? 0.04 : 0.15) // iris-literal: the fold sits a step under the card
            border.width: 1
            border.color: IrisStyle.hairline
        }
        // The layouts, the host and the way out ride the card's top corner.
        Row {
            id: keys
            z: 3
            anchors.right: parent.right
            anchors.rightMargin: card.inset + root.u(10)
            y: card.inset + root.u(10)
            spacing: root.u(6)
            LayoutSwitch { host: root.host; voice: "deck"; compact: true }
            RoundKey {
                glyph: root.windowed ? "layers" : "web_asset"
                name: root.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                onClicked: root.host.switchHost()
            }
            RoundKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
        }
        // In a window (no room for neighbours) the hero is a page of the pool; over the desktop the cards hold theirs.
        AreaPool {
            id: pool
            visible: !root.sided
            x: card.inset
            y: card.inset
            // laid out once at the open card's size and scaled with the card while it travels: sized by the card, the
            // page re-laid every row, its stage and its fitted title on each frame of a turn
            width: root.cardRect.width - 2 * card.inset
            height: root.cardRect.height - y - (root.windowed ? root.u(4) : root.u(34))
            scale: root.sided ? card.width / Math.max(1, root.cardRect.width) : 1
            transformOrigin: Item.TopLeft
            current: root.sided ? "" : root.searching ? pool.shown : root.section
            hidden: root.slotted
            // a page asked for mid-travel incubates while the cards move and is finished when they land: built in the
            // frame it was asked for, it stalled the turn halfway (the move then skipped ahead)
            settled: Boolean(root.host?.bodySettled ?? true)
            urlFor: id => Qt.resolvedUrl("DeckPage.qml")
            propsFor: id => ({ host: root.host })
            order: root.sections.map(entry => entry.id)
            distance: 0
            crossing: false
            keepsShown: false
            onArrived: root.land()
        }
        // A search's results or a shared page (the Hub), under the keys.
        Item {
            id: rowsSlot
            visible: root.slotted
            x: card.inset - root.u(4)
            y: keys.y + keys.height + root.u(10)
            width: card.width - 2 * card.inset + root.u(8)
            height: card.height - y - (root.windowed ? root.u(4) : root.u(34))
            clip: true
        }
        // The console focus: the row lifts on a plate ringed in ink; held, its value moves with the arrows.
        Rectangle {
            id: ring
            property bool shown: false
            readonly property bool head: ring.parent?.deckStop === true
            z: 10
            anchors.fill: parent
            anchors.topMargin: ring.head ? 0 : root.u(3)
            anchors.bottomMargin: ring.head ? 0 : root.u(3)
            visible: ring.shown && root.driving
            radius: IrisStyle.fieldChamfer ? 0 : ring.head ? Math.min(height / 2, root.u(16)) : root.u(12)
            color: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.05)
            border.width: Math.max(2, root.u(2))
            border.color: root.engaged ? root.signal : IrisStyle.text
        }
        // The pointer takes over from the keys: a real move (not the hover a scroll sends) drops the ring.
        HoverHandler {
            property point last: Qt.point(-1, -1)
            onPointChanged: {
                const p = point.scenePosition
                if (root.driving && (Math.abs(p.x - last.x) > 3 || Math.abs(p.y - last.y) > 3) && last.x >= 0) root.driving = false
                last = p
            }
        }
        // What the keys do now, like a console's button bar under the rows.
        Rectangle {
            id: hintBar
            visible: root.driving && ring.shown
            x: card.inset
            width: card.width - 2 * card.inset
            height: root.u(34)
            y: card.height - (root.windowed ? card.inset : root.u(36)) - hintBar.height
            radius: IrisStyle.capsule(height)
            color: IrisStyle.fillQuiet
            Row {
                anchors.centerIn: parent
                spacing: root.u(22)
                Repeater {
                    model: {
                        const spec = root.focused()?.spec ?? null
                        const enter = root.engaged ? Translation.tr("done") : root.focused()?.deckStop === true ? (root.focused()?.open ? Translation.tr("fold") : Translation.tr("open"))
                            : spec?.kind === "switch" ? Translation.tr("switch") : Translation.tr("change")
                        return root.engaged ? [["◀ ▶", Translation.tr("change")], ["⏎", enter]]
                            : [["▲ ▼", Translation.tr("move")], ["◀ ▶", Translation.tr("area")], ["⏎", enter]]
                    }
                    Row {
                        required property var modelData
                        spacing: root.u(7)
                        IrisText { text: parent.modelData[0]; color: IrisStyle.text; font.family: IrisStyle.fontMono; font.pixelSize: Math.max(10, IrisStyle.typeCaption); font.weight: Font.DemiBold }
                        IrisText { text: parent.modelData[1]; color: IrisStyle.subtext; font.family: IrisStyle.fontMono; font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                            font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08); font.capitalization: Font.AllUppercase }
                    }
                }
            }
        }
    }

    // ── The dot pager under the card: a dot per area, the open one a bar, a signal dot where an area needs you.
    // Under the pointer a dot says its area; pressed and dragged along, the deck follows (iOS's page dots).
    MouseArea {
        id: pager
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.windowed ? root.height - root.u(24) : root.cardRect.y + root.cardRect.height - root.u(26)
        width: pagerRow.implicitWidth
        height: root.u(14)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property Item pointed: null
        function dotAt(x: real): Item {
            const item = pagerRow.childAt(Math.max(0, Math.min(pagerRow.width - 1, x)), pagerRow.height / 2)
            return item && item.entryId ? item : null
        }
        function go(item: Item): void { if (item) root.goTo(item.index) }
        onWheel: wheel => root.wheel(wheel)
        onPositionChanged: mouse => {
            const item = pager.dotAt(mouse.x)
            if (item) pager.pointed = item
            if (pager.pressed && item && item.index !== root.aim) pager.go(item)
        }
        onExited: pager.pointed = null
        onPressed: mouse => pager.go(pager.dotAt(mouse.x))
        // On its own plate: it stands over the card's last rows.
        Rectangle {
            id: pagerName
            readonly property Item at: pager.pointed
            visible: opacity > 0
            opacity: pager.containsMouse && pagerName.at ? 1 : 0
            x: pagerName.at ? Math.round(pagerName.at.x + pagerName.at.width - root.u(3) - width / 2) : 0
            y: -height - root.u(6)
            width: pagerWord.implicitWidth + root.u(20)
            height: root.u(24)
            radius: height / 2
            color: IrisStyle.surfaceOpaque
            border.width: 1
            border.color: IrisStyle.hairline
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            IrisText {
                id: pagerWord
                anchors.centerIn: parent
                text: pagerName.at ? Translation.tr(String(pagerName.at.modelData.title ?? "")) : ""
                color: IrisStyle.text
                font.family: IrisStyle.fontMono
                font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
            }
        }
        Row {
            id: pagerRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(6)
            Repeater {
                model: root.sections
                Item {
                    id: dot
                    required property var modelData
                    required property int index
                    readonly property string entryId: dot.modelData.id
                    readonly property bool on: dot.index === root.aim
                    readonly property bool noted: Number(root.noteCounts[dot.modelData.id] ?? 0) > 0
                    // A cluster starts a little further off.
                    readonly property bool starts: dot.index > 0 && root.sections[dot.index - 1]?.cluster !== dot.modelData.cluster
                    width: (dot.starts ? root.u(6) : 0) + (dot.on ? root.u(20) : root.u(6))
                    height: root.u(14)
                    Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: dot.on ? root.u(20) : root.u(6)
                        height: root.u(6)
                        radius: height / 2
                        color: dot.on ? IrisStyle.text : dot.noted ? root.signal : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.32)
                        Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
            }
        }
    }

    component RoundKey: MouseArea {
        id: key
        property string glyph
        property string name
        width: root.u(36)
        height: root.u(36)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: key.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.text }
    }
    // The area before or after, named in the Label voice with its arrow.
    component StepKey: MouseArea {
        id: stepKey
        property int step
        readonly property var entry: root.neighbour(stepKey.step)
        Layout.preferredHeight: root.u(34)
        enabled: stepKey.entry !== null
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(stepKey.entry?.title ?? ""))
        onClicked: root.turn(stepKey.step)
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: stepKey.containsMouse ? IrisStyle.fillHover : "transparent" }
        // The full title when it fits beside the arrow, its short word when not (Screenshots & Recording, cut in half).
        readonly property string title: Translation.tr(String(stepKey.entry?.title ?? ""))
        readonly property real room: stepKey.width - root.u(48)
        readonly property bool fits: stepType.advanceWidth(stepKey.title.toUpperCase()) + stepKey.title.length * stepName.font.letterSpacing <= stepKey.room
        FontMetrics { id: stepType; font: stepName.font }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: stepKey.step < 0 ? parent.left : undefined
            anchors.right: stepKey.step > 0 ? parent.right : undefined
            anchors.leftMargin: root.u(12)
            anchors.rightMargin: root.u(12)
            layoutDirection: stepKey.step < 0 ? Qt.LeftToRight : Qt.RightToLeft
            spacing: root.u(8)
            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: stepKey.step < 0 ? "arrow_back" : "arrow_forward"; iconSize: root.u(15); color: IrisStyle.text }
            IrisText {
                id: stepName
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, stepKey.room)
                elide: Text.ElideRight
                text: stepKey.fits ? stepKey.title : Translation.tr(String(IrisOptions.shortTitles[stepKey.entry?.id] ?? stepKey.title))
                color: IrisStyle.text
                font.family: IrisStyle.fontMono
                font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
            }
        }
    }

    // A neighbour over the desktop: its Dot name, what it is and its stage, standing back.
    // A value as a neighbour card shows it: its name, and the answer read through the distance.
    // A card over the desktop: its area's own page, laid out once at the open card's size and scaled to where the card
    // stands (the wallpaper picker's reel). A turn only moves and scales finished pages: nothing is read, built or
    // swapped on the way, and the card that lands is already the page you get. Until its page is built the card shows
    // the page's own head at the page's own place, so the page comes in over it without a line moving.
    component DeckCard: Item {
        id: deck
        required property var modelData
        readonly property var entry: deck.modelData
        readonly property int at: root.sections.findIndex(entry => entry.id === deck.modelData.id)
        readonly property real o: deck.at - root.pos
        readonly property real far: Math.abs(deck.o)
        readonly property bool hero: deck.at === root.current
        readonly property rect box: root.rectAt(deck.o)
        readonly property real s: deck.box.width / Math.max(1, root.cardRect.width)
        property bool admitted: false
        // Two or more out a card is a picture of its page and the page is let go: seven live pages all restyled on a
        // colour change (a palette change held the GUI ~280 ms with Deck open, ~60 in Classic, 10-25). ±1 stay pages,
        // so a turn of one lands on a page; a jump lands on a picture of the very page the hero then builds.
        readonly property bool held: deck.hero || deck.far < 1.5
        property url picture: ""
        property var shot: null
        property bool pictureStale: false
        readonly property bool wanted: deck.held || deck.picture.toString() === "" || deck.pictureStale
        property bool shooting: false
        readonly property bool standing: !root.moving
        onStandingChanged: deck.shoot()
        // a closed Settings keeps its window hidden: nothing can be shot there, so the shot waits for it to show
        readonly property bool shown: deck.QsWindow.window?.visible ?? false
        onShownChanged: deck.shoot()
        onHeldChanged: if (deck.held) admit.start(); else deck.shoot()
        function shoot(): void {
            if (deck.held || deck.shooting || !deck.ready || root.moving || !deck.shown) return
            const item = page.item
            const revision = root.lookRevision
            deck.shooting = item.grabToImage(result => {
                deck.shooting = false
                if (deck.held || root.moving || page.item !== item) return
                deck.shot = result  // the url lives only as long as its result
                deck.picture = result.url
                deck.pictureStale = revision !== root.lookRevision  // shot across a look change: taken again
                deck.admitted = false
            }, Qt.size(Math.ceil(plane.width * IrisStyle.deviceRatio), Math.ceil(plane.height * IrisStyle.deviceRatio)))
        }
        readonly property bool ready: page.status === Loader.Ready && page.item !== null && page.item.whole !== false
        readonly property int notes: Number(root.noteCounts[deck.entry?.id] ?? 0)
        x: deck.box.x
        y: deck.box.y
        width: deck.box.width
        height: deck.box.height
        visible: deck.box.x + deck.box.width > 0 && deck.box.x < root.width
        clip: true
        // quieter the further it stands; in a search the neighbours step back, their areas are not what was asked for
        opacity: Math.min(1, (root.searching && !deck.hero ? 0.3 : 1)
            * (deck.far <= 1 ? 1 - 0.3 * deck.far : Math.max(0.3, 0.7 - 0.3 * (deck.far - 1)))
            * (catcher.containsMouse && !root.moving ? 1.2 : 1))
        Behavior on opacity { enabled: !root.moving; NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        function claim(): void { if (deck.hero) root.heroPage = deck.ready ? page.item : null }
        onHeroChanged: deck.claim()
        onReadyChanged: { deck.claim(); deck.shoot() }
        Component.onDestruction: if (root.heroPage !== null && root.heroPage === page.item) root.heroPage = null
        Item {
            id: plane
            x: Math.round(root.cardInset * deck.s)
            y: Math.round(root.cardInset * deck.s)
            width: root.cardRect.width - 2 * root.cardInset
            height: root.cardRect.height - root.cardInset - root.u(34)
            scale: deck.s
            transformOrigin: Item.TopLeft
            // Shrunk glyphs drawn straight aliased ("Squirclo", "Lcft"): a card off the front is its full-size picture
            // brought down by the edit card's tent of taps (memory: edit card sharpness).
            layer.enabled: deck.s < 0.995 && deck.visible
            layer.smooth: true
            layer.effect: ShaderEffect {
                readonly property vector2d size: Qt.vector2d(plane.width, plane.height)
                readonly property real corner: 0
                readonly property real chamfer: 0
                readonly property real edge: 1
                readonly property vector2d reach: Qt.vector2d(0.2 / Math.max(0.2, deck.s) * IrisStyle.devicePx / Math.max(1, plane.width),
                    0.2 / Math.max(0.2, deck.s) * IrisStyle.devicePx / Math.max(1, plane.height))
                fragmentShader: Qt.resolvedUrl("../../../shared/background/edit/CardPicture.frag.qsb")
            }
            // DeckPage's head, line for line: its plate, its Dot title, its line. Only while the page is not there yet:
            // the open card hides its page for a search or a shared page (the Hub), and the head stood over those.
            Item {
                anchors.fill: parent
                visible: page.opacity < 1 && !page.givenUp && deck.picture.toString() === ""
                Rectangle {
                    width: parent.width
                    height: Math.round(Math.min(root.u(300), plane.height * 0.36))
                    radius: IrisStyle.fieldChamfer ? 0 : root.u(18)
                    color: IrisStyle.readingCard
                }
                DotTitle {
                    id: standTitle
                    x: root.u(22)
                    y: root.u(20)
                    text: Translation.tr(String(deck.entry?.title ?? ""))
                    size: root.u(40)
                    fit: plane.width - x - root.heroReserve
                }
                IrisText {
                    x: standTitle.x
                    anchors.top: standTitle.bottom
                    anchors.topMargin: root.u(8)
                    width: plane.width - 2 * x
                    elide: Text.ElideRight
                    text: Translation.tr(String(deck.entry?.subtitle ?? ""))
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeMeta
                }
            }
            Image {
                anchors.fill: parent
                visible: deck.picture.toString() !== "" && page.opacity < 1 && !page.givenUp
                source: deck.picture
                cache: false
                smooth: false
            }
            Loader {
                id: page
                anchors.fill: parent
                active: deck.admitted
                // the open card's page, asked for while the deck stands, builds in that frame (a jump lands on it whole);
                // every other one in slices between frames
                asynchronous: !(deck.hero && !root.moving && Boolean(root.host?.bodySettled ?? true))
                readonly property bool givenUp: deck.hero && root.slotted
                opacity: deck.ready && !page.givenUp ? 1 : 0
                // given up for a search or the Hub it goes at once: fading, it stood under the results for its 180 ms
                Behavior on opacity { enabled: !page.givenUp; NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
                visible: opacity > 0
                enabled: deck.hero && !root.moving
                sourceComponent: DeckPage { area: String(deck.entry?.id ?? ""); host: root.host }
            }
        }
        Rectangle {
            visible: deck.notes > 0 && !deck.hero
            x: Math.round((root.cardInset + root.u(12)) * deck.s)
            y: Math.round((root.cardInset + root.u(12)) * deck.s)
            width: root.u(7)
            height: width
            radius: width / 2
            color: root.signal
        }
        // A card beside the open one is a way there, not a page to use: a click turns to it.
        MouseArea {
            id: catcher
            anchors.fill: parent
            visible: !deck.hero
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr(String(deck.entry?.title ?? ""))
            onClicked: root.goTo(deck.at)
            onWheel: wheel => root.wheel(wheel)
        }
    }
    component Spine: MouseArea {
        id: spine
        property int step
        readonly property var entry: root.neighbour(spine.step)
        readonly property bool near: Math.abs(spine.step) === 1
        visible: spine.entry !== null
        Layout.fillHeight: true
        Layout.preferredWidth: root.u(spine.near ? 54 : 44)
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(spine.entry?.title ?? ""))
        onClicked: root.turn(spine.step)
        onWheel: wheel => root.wheel(wheel)
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.fieldChamfer ? 0 : root.u(20)
            color: spine.near ? IrisStyle.fillQuiet : "transparent"
            border.width: 1
            border.color: IrisStyle.hairline
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.u(16)
            spacing: root.u(14)
            MaterialSymbol { anchors.horizontalCenter: parent.horizontalCenter; text: String(spine.entry?.icon ?? ""); iconSize: root.u(19); color: spine.near ? IrisStyle.text : IrisStyle.muted }
            Rectangle { visible: Number(root.noteCounts[spine.entry?.id] ?? 0) > 0; anchors.horizontalCenter: parent.horizontalCenter; width: root.u(6); height: width; radius: width / 2; color: root.signal }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: spineName.implicitHeight
                height: spineName.implicitWidth
                IrisText {
                    id: spineName
                    anchors.centerIn: parent
                    rotation: -90
                    text: Translation.tr(String(spine.entry?.title ?? ""))
                    color: spine.near ? IrisStyle.text : IrisStyle.subtext
                    font.family: IrisStyle.fontMono
                    font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
                }
            }
        }
    }
}
