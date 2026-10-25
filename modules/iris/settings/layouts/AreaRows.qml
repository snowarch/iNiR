pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings

// One area's groups and rows, for a page of the AreaPool: its section never changes. Rows are keyed, so a write never
// rebuilds one under the pointer; a page off screen only marks itself stale and catches up when it shows again.
ColumnLayout {
    id: rows
    required property string section
    property Item host
    property string voice: ""
    // The page shows: config writes reach the rows now; off screen they wait.
    property bool live: true
    // A layout that folds its groups (Deck) opens the first two; the rest wait under their heads, rows unbuilt.
    property bool folds: false
    property color groupFill: IrisStyle.readingCard
    // The group the page reads now, for the head that marks it.
    property string reading: ""
    // A row asked to be seen (a search landing): the page scrolls it into view.
    signal reveal(Item row)

    readonly property real d: IrisStyle.settingsDensity
    spacing: Math.round(6 * rows.d)

    // ── The area's blocks: its groups, a lone row joining the loose block before it.
    property var blocks: []
    property bool stale: true
    function refresh(): void {
        const groups = []
        for (const spec of IrisOptions.settings) {
            if (spec.section !== rows.section || !IrisOptions.shown(spec)) continue
            const key = String(spec.group ?? "")
            let group = groups.find(entry => entry.key === key)
            if (!group) { group = { title: Translation.tr(key), key: key, rows: [] }; groups.push(group) }
            group.rows.push(spec)
        }
        const flat = groups.length > 1 && rows.section !== "system"
        // A group of one row reads as that row; where its label repeats across the area (every widget's "On the
        // desktop") it names nothing, so the row takes its group's name.
        const lone = {}
        for (const group of groups) if (group.rows.length === 1) lone[group.rows[0].label] = (lone[group.rows[0].label] ?? 0) + 1
        for (const group of groups) {
            if (group.rows.length === 1 && lone[group.rows[0].label] > 1 && group.key.length > 0)
                group.rows = [Object.assign({}, group.rows[0], { label: group.key })]
        }
        const out = []
        if (!flat) {
            for (const group of groups) out.push({ title: group.title, caption: "", key: group.key, rows: group.rows, flat: false })
        } else {
            let previous = null
            for (const group of groups) {
                const single = group.rows.length === 1 && group.rows[0].kind !== "list"
                if (single && previous?.loose) { previous.rows = previous.rows.concat(group.rows); continue }
                previous = { title: single ? "​" + group.key : group.title, caption: single ? "" : group.title, key: group.key,
                    rows: group.rows.slice(), loose: single, flat: true }
                out.push(previous)
            }
        }
        rows.blocks = out
        rows.stale = false
    }
    Timer { id: soon; interval: 0; onTriggered: rows.refresh() }
    function touch(): void { if (rows.live) soon.restart(); else rows.stale = true }
    Connections { target: Config; function onRevisionChanged(): void { rows.touch() } }
    Connections { target: IrisNiri; function onRevisionChanged(): void { rows.touch() } }
    onLiveChanged: if (rows.live && rows.stale) rows.refresh()
    Component.onCompleted: rows.refresh()

    // Fine-tune folds opened by hand, by group.
    property var unfolded: ({})
    function fold(key: string): void {
        const next = Object.assign({}, rows.unfolded)
        next[key] = !(next[key] ?? false)
        rows.unfolded = next
    }
    // Deck's open groups beyond the first two.
    property var opened: ({})
    function toggleGroup(key: string): void {
        const next = Object.assign({}, rows.opened)
        next[key] = !(next[key] ?? false)
        rows.opened = next
    }
    // A pending reveal waits a beat, so the row has its height before the page scrolls to it.
    property Item revealing: null
    Timer { id: revealSoon; interval: 120; onTriggered: if (rows.revealing) rows.reveal(rows.revealing) }

    // What the page shows, in order, by group key: the page's wheel and its stage read these.
    function targets(): var {
        const out = []
        for (let i = 0; i < blockRepeater.count; i++) {
            const block = blockRepeater.itemAt(i)?.item
            if (block && block.visible) out.push({ key: String(block.modelData.key ?? ""), item: block })
        }
        return out
    }

    // The first group comes with the page; the rest build in the frames after it, as Classic's blocks do: a turn
    // waited on the whole area before (up to 0.9 s for Deck's widgets in a nest).
    readonly property bool streams: String(rows.host?.landingPath ?? "").length === 0
    Repeater {
        id: blockRepeater
        model: ScriptModel { objectProp: "title"; values: rows.blocks }
        Loader {
            id: slot
            required property var modelData
            required property int index
            Layout.fillWidth: true
            asynchronous: slot.index > 0 && rows.streams
            sourceComponent: ColumnLayout {
                id: block
                readonly property var modelData: slot.modelData
                readonly property int index: slot.index
                spacing: Math.round(6 * rows.d)

                readonly property string key: String(block.modelData.key ?? "")
                readonly property string caption: String(block.modelData.caption ?? "")
                readonly property string tuneKey: rows.section + "/" + block.key
                readonly property var tuned: block.modelData.rows.filter(spec => IrisOptions.foldsAway(spec))
                readonly property bool tunes: block.tuned.length >= 2
                readonly property bool tuneOpen: block.tunes && ((rows.host?.tuneAll ?? false) || (rows.unfolded[block.tuneKey] ?? false))
                readonly property var shownRows: block.tunes && !block.tuneOpen ? block.modelData.rows.filter(spec => !block.tuned.includes(spec)) : block.modelData.rows
                readonly property string landing: String(rows.host?.landingPath ?? "")
                readonly property bool landsInFold: block.landing.length > 0 && block.tuned.some(spec => String(spec.path ?? "") === block.landing)
                onLandsInFoldChanged: if (block.landsInFold && !block.tuneOpen) rows.fold(block.tuneKey)
                // A group that is only a switch is its head: the name and its switch, no card.
                readonly property bool loneSwitch: {
                    Config.revision
                    return block.modelData.flat && block.caption.length > 0 && !block.tunes
                        && block.shownRows.length === 1 && block.shownRows[0].kind === "switch"
                }
                readonly property bool shut: rows.folds && block.index >= 2 && block.caption.length > 0 && !block.loneSwitch
                    && !(rows.opened[block.key] ?? false) && !block.landsInFold && !block.modelData.rows.some(spec => String(spec.path ?? "") === block.landing)
                function partOf(spec: var): string { return String(spec.part ?? "") }
                readonly property var parts: block.shownRows.length === 0 ? [""] : [...new Set(block.shownRows.map(spec => block.partOf(spec)))]

                // The head, in the layout's voice (IrisSkin groupHeader), holding a lone switch on its line.
                Item {
                    id: head
                    readonly property string title: block.caption
                    readonly property int count: block.modelData.rows.length
                    readonly property bool lone: block.loneSwitch
                    readonly property real switchHeight: headSwitch.implicitHeight
                    readonly property bool reading: rows.reading === block.key
                    readonly property int folio: block.index
                    readonly property string glyph: IrisOptions.groupGlyphs[block.key] ?? IrisOptions.sectionById(rows.section)?.icon ?? "settings"
                    readonly property bool deckStop: true
                    readonly property bool folds: rows.folds && block.index >= 2
                    readonly property bool open: !block.shut
                    readonly property string summary: { Config.revision; return block.shut ? (rows.host?.sayGroup(block.modelData.rows) ?? "") : "" }
                    readonly property var notes: (rows.host?.notes?.[rows.section] ?? []).filter(note => String(note.group ?? "") === block.key)
                    function toggle(): void { rows.toggleGroup(block.key) }
                    visible: block.modelData.flat && head.title.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(16 * rows.d)
                    Layout.rightMargin: Math.round(16 * rows.d)
                    Layout.topMargin: Math.round((block.index > 0 ? 18 : 6) * rows.d)
                    Layout.bottomMargin: Math.round(4 * rows.d)
                    implicitHeight: headSkin.active ? (headSkin.item?.implicitHeight ?? 0) : plainHead.implicitHeight
                    IrisSkin { id: headSkin; part: "groupHeader"; host: head; voice: rows.voice }
                    IrisText {
                        id: plainHead
                        visible: !headSkin.active
                        width: parent.width - (head.lone ? headSwitch.width + Math.round(12 * rows.d) : 0)
                        text: head.title
                        color: IrisStyle.text
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: IrisStyle.typeBody
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisSwitch {
                        id: headSwitch
                        visible: head.lone
                        anchors.right: parent.right
                        anchors.top: parent.top
                        on: head.lone && (block.shownRows[0].invert ? !Boolean(IrisOptions.currentValue(block.shownRows[0])) : Boolean(IrisOptions.currentValue(block.shownRows[0])))
                        name: head.title
                        onToggled: IrisOptions.commit(block.shownRows[0], block.shownRows[0].invert ? on : !on)
                    }
                }

                // A shut group (Deck) builds nothing under its head until it opens.
                Repeater {
                    model: ScriptModel { values: block.loneSwitch || block.shut ? [] : block.parts }
                    ColumnLayout {
                        id: part
                        required property string modelData
                        required property int index
                        readonly property var specs: block.shownRows.filter(spec => block.partOf(spec) === part.modelData)
                        readonly property bool lastPart: part.index === block.parts.length - 1
                        Layout.fillWidth: true
                        Layout.topMargin: part.index > 0 ? Math.round(12 * rows.d) : 0
                        spacing: Math.round(6 * rows.d)
                        IrisText {
                            visible: text.length > 0
                            Layout.leftMargin: Math.round(16 * rows.d)
                            text: part.modelData.length > 0 ? Translation.tr(part.modelData) : ""
                            color: IrisStyle.textTertiary
                            font.family: IrisStyle.fontMono
                            font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                            font.weight: Font.Medium
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: partRows.implicitHeight
                            radius: IrisStyle.radiusTile
                            color: IrisStyle.fieldChamfer ? "transparent" : rows.groupFill
                            IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer && rows.groupFill.a > 0; color: rows.groupFill }
                            ColumnLayout {
                                id: partRows
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 0
                                Repeater {
                                    model: ScriptModel { objectProp: "modelKey"; values: part.specs }
                                    IrisSetting {
                                        id: row
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        spec: row.modelData
                                        voice: rows.voice
                                        last: row.index === part.specs.length - 1 && !(part.lastPart && block.tunes)
                                        landing: block.landing.length > 0 && String(row.modelData.path ?? "") === block.landing
                                        onLandingChanged: if (row.landing) { rows.revealing = row; revealSoon.restart() }
                                        Component.onCompleted: if (row.landing) { rows.revealing = row; revealSoon.restart() }
                                    }
                                }
                                FineTune {
                                    visible: part.lastPart && block.tunes
                                    Layout.fillWidth: true
                                    open: block.tuneOpen
                                    names: block.tuned.map(spec => Translation.tr(String(spec.label ?? "")))
                                    onClicked: rows.fold(block.tuneKey)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
