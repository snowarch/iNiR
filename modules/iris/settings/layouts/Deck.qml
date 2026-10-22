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
    readonly property bool home: root.section === "home" && !root.searching
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var room: root.host?.room ?? ({ x: 0, y: 0, width: root.width, height: root.height })
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    function neighbour(step: int): var { return root.sections[root.current + step] ?? null }

    // ── Travel: a new area slides in from where its card stood, the whole deck moving one pitch with the morph curve.
    property real shift: 0
    property int was: -1
    readonly property real pitch: root.windowed ? Math.round(root.cardRect.width * 0.22) : Math.round((root.cardRect.width + root.sideWidth) / 2 + root.gap)
    onCurrentChanged: {
        if (root.was >= 0 && root.was !== root.current) {
            const delta = root.current - root.was
            travel.from = Math.sign(delta) * Math.min(Math.abs(delta), 2) * root.pitch
            travel.restart()
        }
        root.was = root.current
        root.engaged = false
        root.cursor = -1
        if (root.driving) enterRows.restart()
    }
    Component.onCompleted: root.was = root.current
    NumberAnimation { id: travel; target: root; property: "shift"; to: 0; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
    // The rows of a new area build in slices: the focus lands once they stand.
    Timer { id: enterRows; interval: 260; onTriggered: { root.cursor = root.stops().length > 0 ? 0 : -1; root.place() } }

    // ── Driven like a console menu: ◀ ▶ turn the deck, ▲ ▼ walk the head and the rows, ⏎ or Space change the focused
    // row in place (a choice or a range is held: ◀ ▶ then step it, live), Esc lets go.
    property bool driving: false
    property int cursor: -1
    property bool engaged: false
    readonly property Item flick: {
        root.section
        return root.findFlick(rowsSlot)
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
        root.collect(rowsSlot, out)
        return out.map(item => ({ item: item, y: item.mapToItem(rowsSlot, 0, 0).y })).sort((a, b) => a.y - b.y).map(entry => entry.item)
    }
    function focused(): Item { return root.cursor >= 0 ? (root.stops()[root.cursor] ?? null) : null }
    function place(): void {
        const item = root.focused()
        if (!item) { ring.shown = false; return }
        const at = item.mapToItem(rowsSlot, 0, 0)
        const out = item.deckStop === true ? root.u(10) : -root.u(2)
        ring.x = at.x - out
        ring.y = at.y + (item.deckStop === true ? 0 : root.u(3))
        ring.width = item.width + 2 * out
        ring.height = item.height - (item.deckStop === true ? 0 : root.u(6))
        ring.shown = true
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
            root.driving = true
            const delta = key === Qt.Key_Left ? -1 : 1
            if (root.engaged) root.adjust(delta)
            else root.host.stepSection(delta)
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
    function release(): bool {
        if (!root.engaged) return false
        root.engaged = false
        return true
    }
    // The wheel over the deck's sides turns it, a notch a card.
    property real wheelAcc: 0
    Timer { id: wheelRest; interval: 320 }
    function wheel(event: var): void {
        const delta = event.angleDelta.x !== 0 ? -event.angleDelta.x : -event.angleDelta.y
        root.wheelAcc += delta
        if (wheelRest.running || Math.abs(root.wheelAcc) < 60) return
        root.host.stepSection(root.wheelAcc > 0 ? 1 : -1)
        root.wheelAcc = 0
        wheelRest.restart()
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
    // The neighbours stand back: 92 % of the card, centred on its middle.
    function sideRect(step: int): rect {
        const c = root.cardRect
        const near = Math.abs(step) === 1
        const w = near ? root.sideWidth : root.u(260)
        const h = Math.round(c.height * (near ? 0.92 : 0.84))
        const inner = c.x - root.gap - root.sideWidth
        const x = step === -1 ? inner : step === 1 ? c.x + c.width + root.gap
            : step < 0 ? inner - root.gap - w : c.x + c.width + 2 * root.gap + root.sideWidth
        return Qt.rect(Math.round(x), Math.round(c.y + (c.height - h) / 2), w, h)
    }
    readonly property var steps: root.sided ? [-2, -1, 1, 2].filter(step => root.neighbour(step) !== null) : []

    // The bodies IrisSettings draws and blurs: the head, the card and each neighbour.
    readonly property var panes: {
        if (root.windowed) return []
        const out = []
        const h = root.headRect
        out.push({ id: "deckHead", x: h.x, y: h.y, width: h.width, height: h.height, radius: h.height / 2 })
        const c = root.cardRect
        out.push({ id: "deckCard", x: c.x + root.shift, y: c.y, width: c.width, height: c.height, radius: IrisStyle.fieldChamfer ? 0 : root.u(30) })
        for (const step of root.steps) {
            const r = root.sideRect(step)
            out.push({ id: "deckSide" + step, x: r.x + root.shift, y: r.y, width: r.width, height: r.height, radius: IrisStyle.fieldChamfer ? 0 : root.u(28) })
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

    // ── The neighbours over the desktop.
    Repeater {
        model: root.steps
        SideCard { required property int modelData; step: modelData }
    }

    // ── The hero: the area's Dot title over its stage, then its rows; or Home.
    Item {
        id: card
        x: root.cardRect.x + (root.windowed ? 0 : root.shift)
        y: root.cardRect.y
        width: root.cardRect.width
        height: root.cardRect.height
        readonly property real inset: root.u(root.windowed ? 8 : 12)
        clip: root.windowed
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
        ClippingRectangle {
            id: hero
            visible: !root.home && !root.searching
            x: card.inset
            y: card.inset
            width: card.width - 2 * card.inset
            height: Math.round(Math.min(root.u(300), card.height * 0.36))
            radius: IrisStyle.fieldChamfer ? 0 : root.u(root.windowed ? 22 : 30) - card.inset
            color: IrisStyle.readingCard
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: wheel => root.wheel(wheel) }
            DotTitle {
                id: dotTitle
                x: root.u(22)
                y: root.u(20)
                text: Translation.tr(String(root.area.title ?? ""))
                size: root.u(root.windowed ? 34 : 40)
                fit: keys.x - card.inset - x - root.u(16)
            }
            IrisText {
                id: heroLine
                x: dotTitle.x
                anchors.top: dotTitle.bottom
                anchors.topMargin: root.u(8)
                width: hero.width - 2 * x
                elide: Text.ElideRight
                text: Translation.tr(String(root.area.subtitle ?? ""))
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisGroupPreview {
                id: stage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: stageLine.top
                anchors.top: heroLine.bottom
                anchors.margins: root.u(12)
                anchors.bottomMargin: root.u(8)
                radius: IrisStyle.fieldChamfer ? 0 : Math.max(IrisStyle.radiusRow, hero.radius - root.u(12))
                visible: stage.available
                standIn: true
                captionOutside: true
                section: root.searching || root.home ? "" : root.section
                niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                niriRevision: IrisNiri.revision
                group: String(root.host?.leadGroup ?? "")
            }
            // What the stage shows now, under it instead of on it.
            IrisText {
                id: stageLine
                x: root.u(16)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.u(10)
                width: hero.width - 2 * x
                height: stage.caption.length > 0 ? implicitHeight : 0
                elide: Text.ElideRight
                text: stage.caption
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
        }
        Home {
            visible: root.home
            height: card.height - y - root.u(root.windowed ? 8 : 34)
            x: card.inset + root.u(6)
            y: keys.y + keys.height + root.u(14)
            width: card.width - 2 * x
            host: root.host
            voice: "deck"
        }
        Item {
            id: rowsSlot
            visible: !root.home
            x: card.inset - root.u(4)
            y: root.searching ? keys.y + keys.height + root.u(10) : hero.y + hero.height + root.u(10)
            width: card.width - 2 * card.inset + root.u(8)
            height: card.height - y - (root.windowed ? root.u(4) : root.u(34)) - (hintBar.visible ? hintBar.height + root.u(6) : 0)
            clip: true
            // The console focus: the row lifts on a plate ringed in ink; held, its value moves with the arrows.
            Rectangle {
                id: ring
                property bool shown: false
                z: 10
                visible: ring.shown && root.driving
                radius: IrisStyle.fieldChamfer ? 0 : root.u(16)
                color: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.05)
                border.width: Math.max(2, root.u(2))
                border.color: root.engaged ? root.signal : IrisStyle.text
                Behavior on y { NumberAnimation { duration: IrisStyle.duration(160); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Behavior on height { NumberAnimation { duration: IrisStyle.duration(160); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
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
    MouseArea {
        id: pager
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.windowed ? root.height - root.u(24) : root.cardRect.y + root.cardRect.height - root.u(26)
        width: pagerRow.implicitWidth
        height: root.u(14)
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => root.wheel(wheel)
        onClicked: mouse => {
            const item = pagerRow.childAt(mouse.x, pagerRow.height / 2)
            if (item && item.entryId) root.host.selectSection(item.entryId)
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
                    readonly property bool on: dot.index === root.current
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
        onClicked: root.host.stepSection(stepKey.step)
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: stepKey.containsMouse ? IrisStyle.fillHover : "transparent" }
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
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, stepKey.width - root.u(48))
                elide: Text.ElideRight
                text: Translation.tr(String(stepKey.entry?.title ?? ""))
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
    component SideCard: MouseArea {
        id: side
        property int step
        readonly property var entry: root.neighbour(side.step)
        readonly property bool near: Math.abs(side.step) === 1
        readonly property rect box: root.sideRect(side.step)
        readonly property real shown: Math.min(side.box.x + side.box.width, root.width) - Math.max(side.box.x, 0)
        readonly property int notes: Number(root.noteCounts[side.entry?.id] ?? 0)
        x: side.box.x + root.shift
        y: side.box.y
        width: side.box.width
        height: side.box.height
        clip: true
        opacity: side.near ? 0.78 : 0.5
        onWheel: wheel => root.wheel(wheel)
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(side.entry?.title ?? ""))
        onClicked: root.host.selectSection(side.entry.id)
        Column {
            x: (side.box.x < 0 ? -side.box.x : 0) + root.u(22)
            y: root.u(24)
            width: Math.max(0, side.shown - root.u(44))
            spacing: root.u(10)
            Row {
                spacing: root.u(8)
                DotTitle {
                    text: Translation.tr(String(side.entry?.title ?? ""))
                    size: root.u(side.near ? 28 : 22)
                    fit: side.shown - root.u(70)
                    color: IrisStyle.subtext
                }
                Rectangle { visible: side.notes > 0; anchors.top: parent.top; width: root.u(6); height: width; radius: width / 2; color: root.signal }
            }
            IrisText {
                visible: side.near
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: Translation.tr(String(side.entry?.subtitle ?? ""))
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisGroupPreview {
                id: sideStage
                visible: side.near && available
                width: parent.width
                height: root.u(200)
                radius: IrisStyle.fieldChamfer ? 0 : root.u(18)
                standIn: true
                captionOutside: true
                section: side.near && side.entry?.id !== "home" ? String(side.entry?.id ?? "") : ""
                playing: false
            }
            // Its first values, as the card would show them, read through the distance.
            Column {
                id: sideRows
                readonly property int fit: Math.max(0, Math.min(12, Math.floor((side.height - root.u(370)) / root.u(44))))
                readonly property var rows: { Config.revision; return side.near && side.entry && side.entry.id !== "home" && sideRows.fit > 0 ? (root.host?.tellingRows(sideRows.fit, side.entry.id) ?? []) : [] }
                visible: sideRows.rows.length > 0
                width: parent.width
                topPadding: root.u(6)
                opacity: 0.72
                Repeater {
                    model: sideRows.rows
                    Item {
                        id: sideRow
                        required property var modelData
                        required property int index
                        width: sideRows.width
                        height: root.u(44)
                        Rectangle { visible: sideRow.index > 0; width: parent.width; height: 1; color: IrisStyle.hairline }
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.6
                            elide: Text.ElideRight
                            text: Translation.tr(String(sideRow.modelData.label ?? ""))
                            color: IrisStyle.subtext
                            font.pixelSize: IrisStyle.typeMeta
                        }
                        IrisText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.38)
                            elide: Text.ElideRight
                            text: { Config.revision; return root.host?.answerOf(sideRow.modelData) ?? "" }
                            color: IrisStyle.text
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }
                    }
                }
            }
        }
    }

    // A neighbour in a window: a spine with its glyph, a signal dot for notes, its name read upwards.
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
        onClicked: root.host.selectSection(spine.entry.id)
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
