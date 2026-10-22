pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.settings

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

    readonly property bool windowed: Boolean(root.host?.windowed ?? true)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var room: root.host?.room ?? ({ x: 0, y: 0, width: root.width, height: root.height })
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property int noteTotal: Object.keys(root.noteCounts).reduce((sum, id) => sum + Number(root.noteCounts[id] ?? 0), 0)
    function neighbour(step: int): var { return root.sections[root.current + step] ?? null }
    function tint(entry: var, alpha: real): color { const c = entry?.tint ?? IrisStyle.accent; return Qt.rgba(c.r, c.g, c.b, alpha) }

    // The head hangs from the top edge when the Island is a body there; anywhere else it floats like the cards.
    readonly property bool hangs: !root.windowed && IrisFrame.islandEdge === "top" && !IrisFrame.islandSpans
    readonly property real gap: root.u(24)
    readonly property rect headRect: {
        if (root.windowed) return Qt.rect(0, 0, root.width, root.u(60))
        const w = Math.min(root.u(860), root.room.width)
        return Qt.rect(Math.round((root.width - w) / 2), root.hangs ? 0 : root.room.y, w, root.u(64))
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

    // The bodies IrisSettings draws and blurs, one per card; the head melts into a wall past the top edge.
    readonly property var panes: {
        if (root.windowed) return []
        const out = []
        const h = root.headRect
        if (root.hangs) out.push({ id: "deckWall", edge: true, x: h.x - root.u(120), y: -root.u(200), width: h.width + root.u(240), height: root.u(200), radius: 0 })
        out.push({ id: "deckHead", joins: root.hangs ? "deckWall" : "", fuse: root.hangs ? root.u(28) : 0,
            x: h.x, y: h.y, width: h.width, height: h.height, radius: root.hangs ? root.u(30) : h.height / 2 })
        const c = root.cardRect
        out.push({ id: "deckCard", x: c.x, y: c.y, width: c.width, height: c.height, radius: root.u(30) })
        for (const step of root.steps) {
            const r = root.sideRect(step)
            out.push({ id: "deckSide" + step, x: r.x, y: r.y, width: r.width, height: r.height, radius: root.u(30) })
        }
        return out
    }

    // ── The head: back, the search, every area as a tick, the notes, the layouts, the way out.
    Item {
        id: head
        x: root.headRect.x
        y: root.headRect.y
        width: root.headRect.width
        height: root.headRect.height
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.u(root.hangs ? 34 : 14)
            anchors.rightMargin: root.u(root.hangs ? 34 : 14)
            anchors.topMargin: root.u(root.hangs ? 6 : 0)
            spacing: root.u(12)
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
                            color: index === root.current ? IrisStyle.accent : Number(root.noteCounts[modelData.id] ?? 0) > 0 ? IrisStyle.danger
                                : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.2)
                        }
                    }
                }
            }
            IrisText {
                visible: ticks.visible
                textFormat: Text.StyledText
                text: "<font color='" + IrisStyle.text + "'>" + String(root.current + 1).padStart(2, "0") + "</font>/" + String(root.sections.length).padStart(2, "0")
                color: IrisStyle.textTertiary
                font.family: IrisStyle.fontMono
                font.pixelSize: IrisStyle.typeCaption
                font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.1)
            }
            MouseArea {
                id: notePill
                visible: root.noteTotal > 0
                Layout.preferredHeight: root.u(32)
                Layout.preferredWidth: noteRow.implicitWidth + root.u(24)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: root.noteTotal === 1 ? Translation.tr("1 note") : Translation.tr("%1 notes").arg(root.noteTotal)
                onClicked: root.host.openNote()
                Rectangle { anchors.fill: parent; radius: height / 2; color: Qt.rgba(IrisStyle.danger.r, IrisStyle.danger.g, IrisStyle.danger.b, notePill.containsMouse ? 0.24 : 0.15) }
                Row {
                    id: noteRow
                    anchors.centerIn: parent
                    spacing: root.u(6)
                    MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "error"; iconSize: root.u(17); color: IrisStyle.danger }
                    IrisText { anchors.verticalCenter: parent.verticalCenter; text: String(root.noteTotal); color: IrisStyle.text; font.pixelSize: IrisStyle.typeLabel; font.weight: Font.DemiBold }
                }
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
        x: root.cardRect.x
        y: root.cardRect.y
        width: root.cardRect.width
        height: root.cardRect.height
        readonly property real inset: root.u(root.windowed ? 8 : 12)
        Rectangle {
            visible: root.windowed
            anchors.fill: parent
            radius: root.u(22)
            color: Qt.rgba(0, 0, 0, IrisStyle.light ? 0.04 : 0.15)
            border.width: 1
            border.color: IrisStyle.hairline
        }
        Rectangle {
            id: hero
            x: card.inset
            y: card.inset
            width: card.width - 2 * card.inset
            height: root.u(root.windowed ? 170 : Math.min(280, card.height * 0.3 / root.d))
            radius: root.u(20)
            color: IrisStyle.readingCard
            clip: true
            IrisGroupPreview {
                id: stage
                anchors.fill: parent
                anchors.leftMargin: Math.round(parent.width * 0.3)
                visible: stage.available
                section: root.host?.searching ? "" : root.section
                group: String(root.host?.leadGroup ?? "")
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(IrisStyle.surfaceOpaque.r, IrisStyle.surfaceOpaque.g, IrisStyle.surfaceOpaque.b, 0.92) }
                    GradientStop { position: 0.34; color: Qt.rgba(IrisStyle.surfaceOpaque.r, IrisStyle.surfaceOpaque.g, IrisStyle.surfaceOpaque.b, 0.7) }
                    GradientStop { position: 0.55; color: "transparent" }
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
                        text: Translation.tr(String(root.area.title ?? ""))
                        color: IrisStyle.text
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: root.u(root.windowed ? 36 : 44)
                        font.weight: Font.DemiBold
                        font.letterSpacing: -Math.round(root.u(44) * 0.02)
                    }
                    IrisText {
                        width: hero.width * 0.36
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
                model: root.host?.tellingRows(5, "") ?? []
                Chip {
                    required property var modelData
                    readonly property bool on: modelData.kind !== "switch" || root.host.answerOf(modelData) === Translation.tr("On")
                    text: modelData.kind === "switch"
                        ? Translation.tr(String(modelData.label)) + (on ? "" : " · " + Translation.tr("Off"))
                        : "<font color='" + IrisStyle.text + "'>" + root.host.answerOf(modelData) + "</font>  " + Translation.tr(String(modelData.label))
                    onClicked: root.host.landOn(String(modelData.path))
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
            height: card.height - y - root.u(4)
            clip: true
        }
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
        x: side.box.x
        y: side.box.y
        width: side.box.width
        height: side.box.height
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(side.entry?.title ?? ""))
        onClicked: root.host.selectSection(side.entry.id)
        Column {
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
            Rectangle {
                visible: side.near && neighbourStage.available
                width: parent.width
                height: root.u(190)
                radius: root.u(18)
                color: IrisStyle.readingCard
                clip: true
                IrisGroupPreview { id: neighbourStage; anchors.fill: parent; section: side.near ? String(side.entry?.id ?? "") : ""; playing: false }
            }
            Repeater {
                model: side.near && side.entry ? root.host.tellingRows(5, side.entry.id) : []
                Item {
                    required property var modelData
                    width: parent.width
                    height: root.u(42)
                    IrisText { anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.6; elide: Text.ElideRight
                        text: Translation.tr(String(parent.modelData.label)); color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeLabel }
                    IrisText { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; width: Math.min(implicitWidth, parent.width * 0.38); elide: Text.ElideRight
                        text: root.host.answerOf(parent.modelData); color: IrisStyle.text; font.pixelSize: IrisStyle.typeLabel; font.weight: Font.Medium }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: IrisStyle.hairline }
                }
            }
        }
        IrisText {
            visible: side.near
            x: root.u(24)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u(22)
            text: side.step < 0 ? "←  " + Translation.tr("or click") : Translation.tr("click or") + "  →"
            color: IrisStyle.textTertiary
            font.family: IrisStyle.fontMono
            font.pixelSize: IrisStyle.typeCaption
            font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.14)
            font.capitalization: Font.AllUppercase
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
        Rectangle {
            anchors.fill: parent
            radius: root.u(20)
            color: spine.near ? IrisStyle.fillQuiet : Qt.rgba(0, 0, 0, IrisStyle.light ? 0.03 : 0.15)
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
