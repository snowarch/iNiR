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

// Deck (Baraja): the areas as a deck of cards. Over the desktop the head is the Island grown down from its edge, the
// open area a tall card under it, its neighbours cards on both sides and the far ones half off the screen; in a window
// the neighbours stand as spines beside the card. The card holds the area's live stage, its telling values and its rows.
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
    readonly property string searchHint: Translation.tr("Search, or say what to change")

    readonly property bool windowed: Boolean(root.host?.windowed ?? true)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var room: root.host?.room ?? ({ x: 0, y: 0, width: root.width, height: root.height })
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property int noteTotal: Object.keys(root.noteCounts).reduce((sum, id) => sum + Number(root.noteCounts[id] ?? 0), 0)
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
    function tint(entry: var, alpha: real): color { const c = entry?.tint ?? IrisStyle.accent; return Qt.rgba(c.r, c.g, c.b, alpha) }

    // The head floats over the deck in the room the Island leaves, a capsule like the cards are plates.
    readonly property real gap: root.u(24)
    readonly property rect headRect: {
        if (root.windowed) return Qt.rect(0, 0, root.width, root.u(60))
        const w = Math.min(root.u(820), root.room.width)
        return Qt.rect(Math.round((root.width - w) / 2), root.room.y, w, root.u(60))
    }
    readonly property rect cardRect: {
        if (root.windowed) return Qt.rect(deckRow.x + cardSlot.x, deckRow.y, cardSlot.width, deckRow.height)
        const top = root.headRect.y + root.headRect.height + root.u(20)
        const w = Math.round(Math.max(Math.min(root.u(620), root.room.width), Math.min(root.u(800), root.room.width * 0.46)))
        return Qt.rect(Math.round((root.width - w) / 2), top, w, Math.max(0, root.room.y + root.room.height - top))
    }
    readonly property real sideWidth: Math.min(root.u(404), Math.floor((root.width - root.cardRect.width) / 2) - 2 * root.gap - root.u(60))
    readonly property bool sided: !root.windowed && root.sideWidth >= root.u(240)
    function sideRect(step: int): rect {
        const c = root.cardRect
        const near = Math.abs(step) === 1
        const w = near ? root.sideWidth : root.u(270)
        const h = Math.round(c.height * (near ? 0.86 : 0.71))
        const inner = c.x - root.gap - root.sideWidth
        const x = step === -1 ? inner : step === 1 ? c.x + c.width + root.gap
            : step < 0 ? inner - root.gap - w : c.x + c.width + 2 * root.gap + root.sideWidth
        return Qt.rect(Math.round(x), Math.round(c.y + (c.height - h) / 2), w, h)
    }
    readonly property var steps: root.sided ? [-2, -1, 1, 2].filter(step => root.neighbour(step) !== null) : []

    // The bodies IrisSettings draws and blurs, one per card and the head's capsule.
    readonly property var panes: {
        if (root.windowed) return []
        const out = []
        const h = root.headRect
        out.push({ id: "deckHead", x: h.x, y: h.y, width: h.width, height: h.height, radius: h.height / 2 })
        const c = root.cardRect
        out.push({ id: "deckCard", x: c.x + root.shift, y: c.y, width: c.width, height: c.height, radius: root.u(30) })
        for (const step of root.steps) {
            const r = root.sideRect(step)
            out.push({ id: "deckSide" + step, x: r.x + root.shift, y: r.y, width: r.width, height: r.height, radius: root.u(30) })
        }
        return out
    }

    // ── The head: back, the search, every area as a tick, the notes, the layouts, the way out.
    MouseArea {
        id: head
        x: root.headRect.x
        y: root.headRect.y
        width: root.headRect.width
        height: root.headRect.height
        onWheel: wheel => root.wheel(wheel)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.u(11)
            anchors.rightMargin: root.u(11)
            spacing: root.u(10)
            RoundKey { glyph: "arrow_back"; name: Translation.tr("Back"); onClicked: root.host.goBack() }
            Item { id: searchSlot; Layout.fillWidth: true; Layout.preferredHeight: root.u(40) }
            MouseArea {
                id: ticks
                Layout.preferredWidth: tickRow.implicitWidth
                Layout.preferredHeight: root.u(20)
                visible: root.headRect.width >= root.u(700)
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const at = Math.max(0, Math.min(root.sections.length - 1, Math.floor(mouse.x / (tickRow.implicitWidth / Math.max(1, root.sections.length)))))
                    root.host.selectSection(root.sections[at].id)
                }
                Row {
                    id: tickRow
                    anchors.bottom: parent.bottom
                    spacing: 3
                    Repeater {
                        model: root.sections
                        Rectangle {
                            required property var modelData
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 3
                            height: index === root.current ? root.u(18) : root.u(8)
                            radius: 1.5
                            Behavior on height { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                            color: index === root.current ? IrisStyle.accent : Number(root.noteCounts[modelData.id] ?? 0) > 0 ? IrisStyle.danger
                                : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.2)
                        }
                    }
                }
            }
            MouseArea {
                id: notePill
                visible: root.noteTotal > 0
                Layout.preferredHeight: root.u(38)
                Layout.preferredWidth: root.u(38)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: root.noteTotal === 1 ? Translation.tr("1 note") : Translation.tr("%1 notes").arg(root.noteTotal)
                onClicked: root.host.openNote()
                Rectangle { anchors.fill: parent; radius: height / 2; color: Qt.rgba(IrisStyle.danger.r, IrisStyle.danger.g, IrisStyle.danger.b, notePill.containsMouse ? 0.24 : 0.14) }
                MaterialSymbol { anchors.centerIn: parent; text: "error"; iconSize: root.u(19); color: IrisStyle.danger }
            }
            LayoutSwitch { host: root.host; voice: "deck"; compact: true }
            RoundKey {
                glyph: root.windowed ? "layers" : "web_asset"
                name: root.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                onClicked: root.host.switchHost()
            }
            RoundKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
        }
    }

    // ── In a window: the neighbours as spines either side of the card.
    RowLayout {
        id: deckRow
        visible: root.windowed
        x: root.u(10)
        y: root.headRect.height
        width: root.width - root.u(20)
        height: root.height - y - root.u(10)
        spacing: root.u(8)
        Spine { step: -2 }
        Spine { step: -1 }
        Item { id: cardSlot; Layout.fillWidth: true; Layout.fillHeight: true }
        Spine { step: 1 }
        Spine { step: 2 }
    }

    // ── The neighbours as cards over the desktop.
    Repeater {
        model: root.steps
        SideCard { required property int modelData; step: modelData }
    }

    // ── The open area: its stage, what it says, its rows.
    Item {
        id: card
        x: root.cardRect.x + (root.windowed ? 0 : root.shift)
        y: root.cardRect.y
        width: root.cardRect.width
        height: root.cardRect.height
        readonly property real inset: root.u(root.windowed ? 8 : 12)
        // In a window the card's insides slide within it; over the desktop the card itself travels.
        clip: root.windowed
        transform: Translate { x: root.windowed ? root.shift : 0 }
        Rectangle {
            visible: root.windowed
            anchors.fill: parent
            radius: root.u(22)
            // Over glass the rows get the reading plate, so the wallpaper never reaches the type.
            color: IrisStyle.glassy ? IrisStyle.readingSidebar : Qt.rgba(0, 0, 0, IrisStyle.light ? 0.04 : 0.15) // iris-literal: the fold sits a step under the card
            border.width: 1
            border.color: IrisStyle.hairline
        }
        ClippingRectangle {
            id: hero
            x: card.inset
            y: card.inset
            width: card.width - 2 * card.inset
            height: root.u(root.windowed ? 170 : Math.min(280, card.height * 0.3 / root.d))
            // Concentric with the card it sits in.
            radius: root.u(root.windowed ? 22 : 30) - card.inset
            color: IrisStyle.readingCard
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: wheel => root.wheel(wheel) }
            // The stage keeps clear of the title: full-bleed, Lock's clock and the Control Center sat under its words.
            IrisGroupPreview {
                id: stage
                anchors.fill: parent
                anchors.leftMargin: Math.round(hero.width * 0.42)
                radius: 0
                border.width: 0
                visible: stage.available
                standIn: true
                section: root.host?.searching ? "" : root.section
                niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                niriRevision: IrisNiri.revision
                group: String(root.host?.leadGroup ?? "")
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.4; color: Qt.rgba(IrisStyle.surfaceOpaque.r, IrisStyle.surfaceOpaque.g, IrisStyle.surfaceOpaque.b, 0.6) }
                    GradientStop { position: 0.52; color: "transparent" }
                }
            }
            Row {
                x: root.u(26)
                y: root.u(22)
                spacing: root.u(14)
                Rectangle {
                    width: root.u(root.windowed ? 44 : 52)
                    height: width
                    radius: Math.round(width / 3)
                    color: root.tint(root.area, 0.18)
                    border.width: 1
                    border.color: root.tint(root.area, 0.34)
                    MaterialSymbol { anchors.centerIn: parent; text: String(root.area.icon ?? "settings"); iconSize: Math.round(parent.width / 2); color: root.area.tint ?? IrisStyle.accent }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.u(4)
                    IrisText {
                        id: heroTitle
                        width: Math.round(hero.width * 0.42) - parent.x - root.u(26 + 24)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: root.u(26)
                        text: Translation.tr(String(root.area.title ?? ""))
                        color: IrisStyle.text
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: root.u(root.windowed ? 36 : 44)
                        font.weight: Font.DemiBold
                        font.letterSpacing: -Math.round(root.u(44) * 0.02)
                    }
                    IrisText {
                        width: heroTitle.width
                        wrapMode: Text.WordWrap
                        text: Translation.tr(String(root.area.subtitle ?? ""))
                        color: IrisStyle.subtext
                        font.pixelSize: IrisStyle.typeLabel
                    }
                }
            }
        }
        // What the area holds now, in a few chips, and its notes in red: each lands on its row.
        Flow {
            id: chips
            x: card.inset + root.u(12)
            y: hero.y + hero.height + root.u(14)
            width: card.width - 2 * card.inset - root.u(24)
            spacing: root.u(8)
            visible: !(root.host?.searching ?? false)
            Repeater {
                model: (root.host?.tellingRows(9, "") ?? []).map(spec => ({ spec: spec, text: root.chipOf(spec) })).filter((entry, at, all) => entry.text.length > 0 && all.findIndex(other => other.text === entry.text) === at).slice(0, 5)
                Chip {
                    required property var modelData
                    text: "<font color='" + IrisStyle.text + "'>" + modelData.text + "</font>"
                    onClicked: root.host.landOn(String(modelData.spec.path))
                }
            }
            Repeater {
                model: (root.host?.notesHere ?? []).slice(0, 2)
                Chip {
                    required property var modelData
                    warn: true
                    text: String(modelData.text)
                    onClicked: root.host.landOn(String(modelData.path))
                }
            }
        }
        Item {
            id: rowsSlot
            x: card.inset - root.u(4)
            y: (chips.visible ? chips.y + chips.height : hero.y + hero.height) + root.u(10)
            width: card.width - 2 * card.inset + root.u(8)
            height: card.height - y - root.u(4) - (hintBar.visible ? hintBar.height + root.u(6) : 0)
            clip: true
            // The console focus: the row lifts on a lit plate with the accent's bar at its side; held, arrows flank it.
            Rectangle {
                id: ring
                property bool shown: false
                z: 10
                visible: ring.shown && root.driving
                radius: root.u(16)
                color: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.05)
                border.width: Math.max(2, root.u(2))
                border.color: IrisStyle.accent
                Behavior on y { NumberAnimation { duration: IrisStyle.duration(160); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Behavior on height { NumberAnimation { duration: IrisStyle.duration(160); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Rectangle { x: -1; y: root.u(12); width: root.u(4); height: parent.height - root.u(24); radius: width / 2; color: IrisStyle.accent }
            }
        }
        // What the keys do now, said under the rows like a console's button bar: never over a row's text.
        Rectangle {
            id: hintBar
            visible: root.driving && ring.shown
            x: card.inset
            width: card.width - 2 * card.inset
            height: root.u(34)
            y: card.height - card.inset - hintBar.height
            radius: height / 2
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
                        IrisText {
                            text: parent.modelData[0]
                            color: IrisStyle.accent
                            font.family: IrisStyle.fontMono
                            font.pixelSize: IrisStyle.typeCaption
                            font.weight: Font.DemiBold
                        }
                        IrisText {
                            text: parent.modelData[1]
                            color: IrisStyle.subtext
                            font.family: IrisStyle.fontMono
                            font.pixelSize: IrisStyle.typeCaption
                            font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.12)
                            font.capitalization: Font.AllUppercase
                        }
                    }
                }
            }
        }
    }

    // A chip says a value as you would: "40 px", "Bottom edge", "Hides itself"; a switch that is off says nothing.
    function chipOf(spec: var): string {
        const answer = root.host.answerOf(spec)
        const label = Translation.tr(String(spec.label ?? ""))
        const words = label.split(" ")
        if (spec.kind === "range") return answer
        if (spec.kind === "switch") return answer === Translation.tr("On") && words.length <= 3 ? label : ""
        if (answer.split(" ").length > 2) return ""
        // "Tray bubble rests" + "Top right" has no short way to be said: left to its row.
        if (/\s(opens|rests|sits|stays|follows|shows|hides|starts|moves|lives|appears|closes|keeps|leads|lands|goes)$/i.test(String(spec.label ?? ""))) return ""
        // A one-word label is the noun itself: "Off" alone says nothing, "Glass off" does.
        // "Search the web with" + "Google": the value says it.
        if (/\s(as|at|on|in|to|by|from|with|for|into)$/i.test(label)) return answer
        if (words.length === 1) {
            if (answer.toLowerCase().includes(label.toLowerCase())) return answer
            const plain = [Translation.tr("Off"), Translation.tr("On"), Translation.tr("Auto"), Translation.tr("None")].includes(answer)
            return plain ? label + " " + answer.toLowerCase() : answer + " " + label.toLowerCase()
        }
        const noun = words[words.length - 1].toLowerCase()
        return noun.length > 0 && !answer.toLowerCase().includes(noun) ? answer + " " + noun : answer
    }

    component RoundKey: MouseArea {
        id: key
        property string glyph
        property string name
        Layout.preferredWidth: root.u(38)
        Layout.preferredHeight: root.u(38)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        Rectangle { anchors.fill: parent; radius: height / 2; color: key.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(19); color: IrisStyle.subtext }
    }

    component Chip: MouseArea {
        id: chip
        property string text
        property bool warn: false
        width: Math.min(chipRow.implicitWidth + root.u(24), chips.width)
        height: root.u(30)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.warn ? Qt.rgba(IrisStyle.danger.r, IrisStyle.danger.g, IrisStyle.danger.b, chip.containsMouse ? 0.24 : 0.14)
                : chip.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: root.u(6)
            MaterialSymbol { visible: chip.warn; anchors.verticalCenter: parent.verticalCenter; text: "error"; iconSize: root.u(16); color: IrisStyle.danger }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, chips.width - root.u(48))
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: chip.text
                color: chip.warn ? IrisStyle.text : IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
            }
        }
    }

    // A neighbour over the desktop: its mark, what it is, its stage and its values; the far ones only their mark,
    // name and notes, set in the part of the card the screen shows.
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
        clip: true
        onWheel: wheel => root.wheel(wheel)
        width: side.box.width
        height: side.box.height
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(side.entry?.title ?? ""))
        onClicked: root.host.selectSection(side.entry.id)
        // Taller than the card, its body fades out above the footer; the rest is one click (or a key) away.
        Item {
            id: sideBody
            width: parent.width
            height: parent.height - root.u(16)
            clip: true
            readonly property bool spills: sideColumn.height > sideBody.height - sideColumn.y
            layer.enabled: sideBody.spills
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: sideFade
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        Column {
            id: sideColumn
            readonly property real pad: root.u(side.near ? 24 : 16)
            x: (side.box.x < 0 ? -side.box.x : 0) + pad
            y: root.u(26)
            width: Math.max(0, side.shown - 2 * pad)
            spacing: root.u(side.near ? 8 : 10)
            Rectangle {
                width: root.u(46)
                height: width
                radius: root.u(15)
                color: side.notes > 0 && !side.near ? Qt.rgba(IrisStyle.danger.r, IrisStyle.danger.g, IrisStyle.danger.b, 0.16) : root.tint(side.entry, 0.16)
                MaterialSymbol { anchors.centerIn: parent; text: String(side.entry?.icon ?? ""); iconSize: root.u(22)
                    color: side.notes > 0 && !side.near ? IrisStyle.danger : side.entry?.tint ?? IrisStyle.accent }
            }
            IrisText {
                width: parent.width
                elide: Text.ElideRight
                text: Translation.tr(String(side.entry?.title ?? ""))
                color: IrisStyle.text
                font.family: IrisStyle.fontTitle
                font.pixelSize: root.u(side.near ? 26 : 20)
                font.weight: Font.DemiBold
            }
            IrisText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: side.near || side.notes > 0
                text: side.near ? Translation.tr(String(side.entry?.subtitle ?? ""))
                    : side.notes === 1 ? Translation.tr("1 note") : Translation.tr("%1 notes").arg(side.notes)
                color: side.near ? IrisStyle.muted : IrisStyle.danger
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisGroupPreview {
                id: neighbourStage
                visible: side.near && neighbourStage.available
                width: parent.width
                height: root.u(190)
                radius: root.u(18)
                standIn: true
                section: side.near ? String(side.entry?.id ?? "") : ""
                playing: false
            }
            Repeater {
                model: {
                    const rows = side.near && side.entry ? root.host.tellingRows(5, side.entry.id) : []
                    const count = {}
                    for (const spec of rows) count[spec.label] = (count[spec.label] ?? 0) + 1
                    // Two groups' rows of one name (Side Panels' "Alignment"s) are told apart by their group.
                    return rows.map(spec => ({ spec: spec, label: count[spec.label] > 1 && spec.group
                        ? Translation.tr(String(spec.group)) + " · " + Translation.tr(String(spec.label)) : Translation.tr(String(spec.label)) }))
                }
                Item {
                    required property var modelData
                    width: parent?.width ?? 0
                    height: root.u(42)
                    IrisText { anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.6; elide: Text.ElideRight
                        text: parent.modelData.label; color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeLabel }
                    IrisText { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; width: Math.min(implicitWidth, parent.width * 0.38); elide: Text.ElideRight
                        text: root.host.answerOf(parent.modelData.spec); color: IrisStyle.text; font.pixelSize: IrisStyle.typeLabel; font.weight: Font.Medium }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: IrisStyle.hairline }
                }
            }
        }
        }
        Rectangle {
            id: sideFade
            visible: false
            layer.enabled: true
            width: sideBody.width
            height: sideBody.height
            gradient: Gradient {
                GradientStop { position: 0; color: "white" }
                GradientStop { position: Math.max(0, 1 - root.u(72) / Math.max(1, sideBody.height)); color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // A neighbour in a window: a spine with its mark, a red dot for notes, its name read upwards.
    component Spine: MouseArea {
        id: spine
        property int step
        readonly property var entry: root.neighbour(spine.step)
        readonly property bool near: Math.abs(spine.step) === 1
        visible: spine.entry !== null
        Layout.fillHeight: true
        Layout.preferredWidth: root.u(spine.near ? 58 : 46)
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(spine.entry?.title ?? ""))
        onClicked: root.host.selectSection(spine.entry.id)
        onWheel: wheel => root.wheel(wheel)
        Rectangle {
            anchors.fill: parent
            radius: root.u(20)
            color: spine.near ? IrisStyle.fillQuiet : Qt.rgba(0, 0, 0, IrisStyle.light ? 0.03 : 0.15) // iris-literal: a far spine sits a step under the card
            border.width: 1
            border.color: IrisStyle.hairline
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.u(16)
            spacing: root.u(14)
            MaterialSymbol { anchors.horizontalCenter: parent.horizontalCenter; text: String(spine.entry?.icon ?? ""); iconSize: root.u(20); color: spine.near ? IrisStyle.subtext : IrisStyle.textTertiary }
            Rectangle { visible: Number(root.noteCounts[spine.entry?.id] ?? 0) > 0; anchors.horizontalCenter: parent.horizontalCenter; width: root.u(7); height: width; radius: width / 2; color: IrisStyle.danger }
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
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: root.u(spine.near ? 17 : 15)
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
