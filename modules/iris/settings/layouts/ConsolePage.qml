pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings

// One area as Console's board, built once and kept by Console's AreaPool: each group a run of tiles (switch 1x1, range
// 2x1 with its dot scrubber, a short choice 2x1, anything else a full-width tile holding its row), fine-tuning behind a
// dashed More tile. Arrows walk the tiles by where they stand, Enter acts or holds a range or a choice for ◀ ▶.
Item {
    id: root
    required property string area
    property Item host
    property real shift: 0
    transform: Translate { y: root.shift }

    readonly property real d: Number(root.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * root.d) }
    readonly property string section: root.area
    readonly property bool live: root.visible && root.area === String(root.host?.section ?? "")
    readonly property real gap: root.u(10)
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    readonly property color plate: IrisStyle.glassy ? IrisStyle.readingCard : IrisStyle.fillQuiet
    readonly property real label: Math.max(10, IrisStyle.typeCaption)

    // ── The area as tiles: every row it shows, by group; fine-tuning waits behind a group's More tile.
    property var groups: []
    property bool stale: true
    function refresh(): void {
        const out = []
        for (const spec of IrisOptions.settings) {
            if (spec.section !== root.section || !IrisOptions.shown(spec)) continue
            const key = String(spec.group ?? "")
            let group = out.find(entry => entry.key === key)
            if (!group) { group = { key: key, rows: [] }; out.push(group) }
            group.rows.push(spec)
        }
        root.groups = out
        root.stale = false
    }
    Timer { id: soon; interval: 0; onTriggered: root.refresh() }
    function touch(): void { if (root.live) soon.restart(); else root.stale = true }
    Connections { target: Config; function onRevisionChanged(): void { root.touch() } }
    Connections { target: IrisNiri; function onRevisionChanged(): void { root.touch() } }
    onLiveChanged: {
        if (!root.live) { root.cursor = -1; root.engaged = false }
        else if (root.stale) root.refresh()
    }
    Component.onCompleted: root.refresh()
    property var opened: ({})
    function folded(group: var): var { return group.rows.filter(spec => IrisOptions.foldsAway(spec)) }
    // How the groups lie on the board: a short group (up to three units, no full-width row) stands beside the next one,
    // a later short one moves up to fill a line, and what no group can fill goes to the line's last group, its tiles
    // wider. A lone switch followed by a full-width group left three units of air.
    readonly property var plan: {
        const opened = root.opened
        const items = root.groups.map(group => {
            const tuned = root.folded(group)
            const open = opened[root.section + "/" + group.key] === true
            const folds = tuned.length >= 2 && tuned.length < group.rows.length
            const shown = folds && !open ? group.rows.filter(spec => !tuned.includes(spec)) : group.rows
            const cells = shown.map(spec => root.unitsOf(root.shape(spec))).concat(folds ? [1] : [])
            const units = cells.reduce((sum, size) => sum + size, 0)
            const brief = units <= 3 && !shown.some(spec => root.shape(spec) === "row")
            // Inside a full-width group the last tile of a line short of the edge takes the rest of it.
            if (!brief) {
                let fill = 0
                cells.forEach((size, at) => {
                    if (fill + size > 4) { cells[at - 1] += 4 - fill; fill = 0 }
                    fill = (fill + size) % 4
                })
                if (fill > 0) cells[cells.length - 1] += 4 - fill
            }
            // A switch left alone on its line reads as its row, what it does said beside it, not an empty plate.
            const whole = shown.map((spec, at) => cells[at] === 4 && root.shape(spec) === "switch")
            return { key: group.key, group: group, tuned: tuned, open: open, folds: folds, shown: shown, units: units,
                cells: cells, whole: whole, brief: brief, span: 4 }
        })
        const out = []
        let line = []
        const close = () => {
            const fill = line.reduce((sum, item) => sum + item.span, 0)
            if (line.length > 0 && fill < 4) line[line.length - 1].span += 4 - fill
            line = []
        }
        while (items.length > 0) {
            const fill = line.reduce((sum, item) => sum + item.span, 0)
            let at = fill === 0 ? 0 : items.findIndex(item => item.brief && item.units <= 4 - fill)
            if (at < 0) { close(); at = 0 }
            const item = items.splice(at, 1)[0]
            if (!item.brief) { close(); out.push(item); continue }
            item.span = item.units
            line.push(item)
            out.push(item)
            if (fill + item.units >= 4) line = []
        }
        close()
        return out
    }
    function unitsOf(kind: string): int { return kind === "switch" ? 1 : kind === "row" ? 4 : 2 }
    function shape(spec: var): string {
        if (spec.kind === "switch") return "switch"
        if (spec.kind === "range" && Number.isFinite(Number(spec.min)) && Number.isFinite(Number(spec.max))) return "range"
        if (spec.kind === "choice" && !spec.cards) {
            const choices = IrisOptions.choicesOf(spec)
            if (choices.length >= 2 && choices.length <= 4 && choices.every(entry => Translation.tr(String(entry.label ?? "")).length <= 9)) return "choice"
        }
        return "row"
    }


    // ── Keys: arrows walk the tiles by where they stand, Enter acts, a held range or choice moves with ◀ ▶.
    property int cursor: -1
    property bool engaged: false
    function stops(): var {
        const out = []
        const walk = item => { for (const child of item?.children ?? []) { if (!child.visible) continue; if (child.consoleStop === true) out.push(child); else walk(child) } }
        walk(boardColumn)
        return out
    }
    function focused(): Item { return root.cursor >= 0 ? (root.stops()[root.cursor] ?? null) : null }
    function moveBy(dx: int, dy: int): void {
        const list = root.stops()
        if (list.length === 0) return
        if (root.cursor < 0) { root.cursor = 0; root.reveal(list[0]); return }
        const from = list[root.cursor].mapToItem(boardColumn, list[root.cursor].width / 2, list[root.cursor].height / 2)
        let best = -1, bestScore = Infinity
        list.forEach((item, at) => {
            if (at === root.cursor) return
            const p = item.mapToItem(boardColumn, item.width / 2, item.height / 2)
            const ax = p.x - from.x, ay = p.y - from.y
            const along = dx !== 0 ? ax * dx : ay * dy
            if (along <= 2) return
            const across = dx !== 0 ? Math.abs(ay) : Math.abs(ax)
            const score = along + across * 3
            if (score < bestScore) { bestScore = score; best = at }
        })
        if (best >= 0) { root.cursor = best; root.reveal(list[best]) }
    }
    function reveal(item: Item): void {
        const top = item.mapToItem(boardColumn, 0, 0).y
        const end = Math.max(0, boardFlick.contentHeight - boardFlick.height)
        let to = boardFlick.contentY
        if (top - root.gap < to) to = top - root.gap
        else if (top + item.height + root.gap > to + boardFlick.height) to = top + item.height + root.gap - boardFlick.height
        scrollTo.to = Math.max(0, Math.min(end, to))
        scrollTo.restart()
    }
    NumberAnimation { id: scrollTo; target: boardFlick; property: "contentY"; duration: IrisStyle.duration(220); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
    function takeKey(event: var): bool {
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return false
        const key = event.key
        const item = root.focused()
        if (key === Qt.Key_Left || key === Qt.Key_Right) {
            const delta = key === Qt.Key_Left ? -1 : 1
            if (root.engaged && item) item.adjust(delta)
            else if (root.cursor < 0) root.host.stepSection(delta)
            else root.moveBy(delta, 0)
            return true
        }
        if (key === Qt.Key_Up || key === Qt.Key_Down) {
            root.engaged = false
            root.moveBy(0, key === Qt.Key_Up ? -1 : 1)
            return true
        }
        if ((key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) && item) {
            if (typeof item.adjust === "function" && item.holds) root.engaged = !root.engaged
            else item.act()
            return true
        }
        return false
    }
    function release(): bool {
        if (root.engaged) { root.engaged = false; return true }
        if (root.cursor >= 0) { root.cursor = -1; return true }
        return false
    }


    // ── The board.
    Flickable {
        id: boardFlick
        anchors.fill: parent
        contentHeight: boardColumn.implicitHeight + root.gap
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: IrisScrollBar {}
        Column {
            id: board
            width: boardFlick.width
            Flow {
                id: boardColumn
                width: parent.width
                spacing: root.gap
                readonly property real unit: Math.floor((width - 3 * root.gap) / 4)
                function span(units: int): real { return units * boardColumn.unit + (units - 1) * root.gap }
                Repeater {
                    model: ScriptModel { objectProp: "key"; values: root.plan }
                    Column {
                        id: group
                        required property var modelData
                        required property int index
                        readonly property var tuned: group.modelData.tuned
                        readonly property bool open: group.modelData.open
                        readonly property bool folds: group.modelData.folds
                        readonly property var shown: group.modelData.shown
                        // A group widened to close its line spreads its tiles over the width it got.
                        readonly property real unit: group.modelData.brief
                            ? (boardColumn.span(group.modelData.span) - (group.modelData.units - 1) * root.gap) / group.modelData.units : boardColumn.unit
                        function span(units: int): real { return Math.floor(units * group.unit + (units - 1) * root.gap) }
                        width: group.modelData.brief ? boardColumn.span(group.modelData.span) : boardColumn.width
                        spacing: root.gap
                        bottomPadding: root.u(8)
                        Mono {
                            visible: group.modelData.key.length > 0
                            width: parent.width
                            elide: Text.ElideRight
                            text: Translation.tr(group.modelData.key)
                            color: IrisStyle.textTertiary
                        }
                        Flow {
                            id: flow
                            width: parent.width
                            spacing: root.gap
                            readonly property real unit: group.unit
                            Repeater {
                                model: ScriptModel { values: group.shown; objectProp: "modelKey" }
                                Loader {
                                    id: cell
                                    required property var modelData
                                    required property int index
                                    readonly property string kind: group.modelData.whole[cell.index] ? "row" : root.shape(cell.modelData)
                                    width: cell.kind === "row" ? flow.width : group.span(group.modelData.cells[cell.index] ?? root.unitsOf(cell.kind))
                                    // The first group comes with the page, the rest in the frames after it (Classic's way).
                                    asynchronous: group.index > 0
                                    sourceComponent: cell.kind === "switch" ? switchTile : cell.kind === "range" ? rangeTile : cell.kind === "choice" ? choiceTile : rowTile
                                    onLoaded: item.spec = cell.modelData
                                }
                            }
                            Tile {
                                visible: group.folds
                                width: group.span(group.modelData.cells[group.modelData.cells.length - 1] ?? 1)
                                caption: group.open ? Translation.tr("Less") : Translation.tr("More")
                                text: group.open ? Translation.tr("Fold") : Translation.tr("%1 more").arg(group.tuned.length)
                                dashed: true
                                function act(): void {
                                    const next = Object.assign({}, root.opened)
                                    next[root.section + "/" + group.modelData.key] = !group.open
                                    root.opened = next
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Tiles.
    component Tile: MouseArea {
        id: tile
        property var spec: null
        property bool on: false
        property bool dashed: false
        property string caption: ""
        property string text: ""
        readonly property bool consoleStop: true
        readonly property bool focusedHere: root.focused() === tile
        readonly property bool noted: { Config.revision; return tile.spec?.note && (tile.spec?.locked?.() || tile.spec?.warns === true) ? String(tile.spec.note() ?? "").length > 0 : false }
        function act(): void {}
        height: root.u(88)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: tile.text
        onClicked: { root.cursor = root.stops().indexOf(tile); tile.act() }
        // On is said by an ink ring and the switch's own knob, not a white plate: a page of ons stays a page.
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.fieldChamfer ? 0 : root.u(20)
            color: tile.dashed ? "transparent" : tile.containsMouse ? IrisStyle.fillHover : root.plate
            border.width: tile.dashed ? 1 : tile.on ? Math.max(1, root.u(1.5)) : 0
            border.color: tile.dashed ? IrisStyle.hairlineStrong : IrisStyle.text
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        }
        // The key focus: a ring of ink, of signal while a value is held.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -root.u(3)
            radius: IrisStyle.fieldChamfer ? 0 : root.u(23)
            visible: tile.focusedHere
            color: "transparent"
            border.width: Math.max(2, root.u(2))
            border.color: root.engaged ? root.signal : IrisStyle.text
        }
        Rectangle {
            visible: tile.noted
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.u(14)
            width: root.u(6)
            height: width
            radius: width / 2
            color: root.signal
        }
        Mono {
            x: root.u(16)
            y: root.u(14)
            width: parent.width - root.u(40)
            elide: Text.ElideRight
            text: tile.caption
            color: tile.on ? IrisStyle.text : IrisStyle.muted
        }
        IrisText {
            x: root.u(16)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u(14)
            width: parent.width - root.u(32)
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            text: tile.text
            color: IrisStyle.text
            font.pixelSize: IrisStyle.typeBody
            font.weight: Font.DemiBold
        }
    }
    Component {
        id: switchTile
        Tile {
            id: sw
            readonly property bool lit: { Config.revision; IrisNiri.revision; const v = !!IrisOptions.currentValue(sw.spec ?? {}); return sw.spec?.invert ? !v : v }
            on: sw.lit
            // The switch says on or off, so the corner is the switch's: an ON caption beside it said it twice.
            text: Translation.tr(String(sw.spec?.label ?? ""))
            Accessible.role: Accessible.CheckBox
            Accessible.checked: sw.lit
            function act(): void { IrisOptions.commit(sw.spec, sw.spec.invert ? sw.lit : !sw.lit) }
            // S4's switch in small: hairline ring and hollow knob off, ink track and paper knob on, the knob springs over.
            Rectangle {
                id: mini
                x: root.u(16)
                y: root.u(14)
                width: root.u(34)
                height: root.u(20)
                radius: IrisStyle.capsule(height)
                color: sw.lit ? IrisStyle.text : "transparent"
                border.width: sw.lit ? 0 : 1
                border.color: IrisStyle.ringInk
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                Rectangle {
                    width: root.u(14)
                    height: width
                    radius: IrisStyle.capsule(width)
                    anchors.verticalCenter: parent.verticalCenter
                    x: sw.lit ? parent.width - width - root.u(3) : root.u(3)
                    color: sw.lit ? IrisStyle.surfaceOpaque : "transparent"
                    border.width: sw.lit ? 0 : 1
                    border.color: IrisStyle.ringInk
                    Behavior on x { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.25 } }
                }
            }
        }
    }
    Component {
        id: rangeTile
        Tile {
            id: range
            readonly property bool holds: true
            readonly property real lo: Number(range.spec?.min ?? 0)
            readonly property real hi: Number(range.spec?.max ?? 1)
            readonly property real step: Number(range.spec?.step ?? 1)
            property real dragged: NaN
            readonly property real value: { Config.revision; IrisNiri.revision; return Number.isFinite(range.dragged) ? range.dragged : Number(IrisOptions.currentValue(range.spec ?? {})) }
            readonly property string said: range.spec ? Translation.tr(IrisOptions.rangeText(range.spec, range.value)) : ""
            // The figure is the Dot number; its unit, when it has one, is a Label beside it.
            readonly property string figure: (range.said.match(/^[−-]?[\d.,]+/) ?? [range.said])[0]
            readonly property string unit: range.said.slice(range.figure.length).trim()
            readonly property int dots: 15
            readonly property real fraction: range.hi > range.lo ? Math.max(0, Math.min(1, (range.value - range.lo) / (range.hi - range.lo))) : 0
            readonly property int knob: Math.round(range.fraction * (range.dots - 1))
            caption: Translation.tr(String(range.spec?.label ?? ""))
            Accessible.role: Accessible.Slider
            Accessible.name: range.caption
            function snap(raw: real): real {
                const snapped = range.lo + Math.round((raw - range.lo) / range.step) * range.step
                return Number(Math.max(range.lo, Math.min(range.hi, snapped)).toFixed(4))
            }
            function adjust(delta: int): void { IrisOptions.commit(range.spec, range.snap(range.value + delta * range.step)) }
            function act(): void {}
            MouseArea {
                id: scrub
                x: root.u(16)
                y: root.u(42)
                width: parent.width * 0.62 - x
                height: root.u(34)
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function at(x: real): real { return range.snap(range.lo + Math.max(0, Math.min(1, x / width)) * (range.hi - range.lo)) }
                onPressed: mouse => { root.cursor = root.stops().indexOf(range); range.dragged = scrub.at(mouse.x) }
                onPositionChanged: mouse => { if (pressed) range.dragged = scrub.at(mouse.x) }
                onReleased: { IrisOptions.commit(range.spec, range.dragged); range.dragged = NaN }
                onCanceled: range.dragged = NaN
                Repeater {
                    model: range.dots
                    Rectangle {
                        required property int index
                        readonly property bool here: index === range.knob
                        readonly property real size: root.u(here ? 14 : 6)
                        x: Math.round(index / (range.dots - 1) * (scrub.width - root.u(14)) + root.u(7) - size / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: size
                        height: size
                        radius: size / 2
                        color: here || index < range.knob ? IrisStyle.text : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.2)
                        Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.u(16)
                anchors.verticalCenter: scrub.verticalCenter
                spacing: root.u(6)
                DotTitle { anchors.bottom: parent.bottom; text: range.figure; size: root.u(30) }
                Mono { anchors.bottom: parent.bottom; visible: range.unit.length > 0; text: range.unit; color: IrisStyle.muted }
            }
        }
    }
    Component {
        id: choiceTile
        Tile {
            id: choice
            readonly property bool holds: true
            readonly property var options: IrisOptions.choicesOf(choice.spec ?? {})
            readonly property var now: { Config.revision; IrisNiri.revision; return IrisOptions.currentValue(choice.spec ?? {}) }
            caption: Translation.tr(String(choice.spec?.label ?? ""))
            function adjust(delta: int): void {
                const at = choice.options.findIndex(entry => IrisOptions.same(entry.value, choice.now))
                const next = choice.options[Math.max(0, Math.min(choice.options.length - 1, at + delta))]
                if (next) IrisOptions.commit(choice.spec, next.value)
            }
            IrisSegmented {
                x: root.u(12)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.u(14)
                width: parent.width - root.u(24)
                voice: "console"
                accessibleName: choice.caption
                options: choice.options.map(entry => ({ label: Translation.tr(String(entry.label ?? "")), value: entry.value }))
                current: choice.now
                onPicked: value => IrisOptions.commit(choice.spec, value)
            }
        }
    }
    // Anything that is not one value: its row, whole, on a full-width tile.
    Component {
        id: rowTile
        Rectangle {
            id: rowPlate
            property var spec: null
            // A keyboard stop like any tile: Enter switches or runs it; a choice or a range is held and ◀ ▶ step it.
            readonly property bool consoleStop: rowPlate.spec !== null
            readonly property bool holds: ["choice", "range"].includes(String(rowPlate.spec?.kind))
            readonly property bool focusedHere: root.focused() === rowPlate
            function act(): void {
                const spec = rowPlate.spec
                if (!spec) return
                if (spec.kind === "switch") { const v = !!IrisOptions.currentValue(spec); IrisOptions.commit(spec, !v) }
                else if (spec.kind === "action" && typeof spec.run === "function") spec.run()
                else rowItem.forceActiveFocus(Qt.TabFocusReason)
            }
            function adjust(delta: int): void {
                const spec = rowPlate.spec
                if (spec?.kind === "choice") {
                    const list = IrisOptions.choicesOf(spec)
                    const at = list.findIndex(entry => IrisOptions.same(entry.value, IrisOptions.currentValue(spec)))
                    const next = list[Math.max(0, Math.min(list.length - 1, at + delta))]
                    if (next) IrisOptions.commit(spec, next.value)
                } else if (spec?.kind === "range") {
                    const step = Number(spec.step ?? 1)
                    const next = Math.max(Number(spec.min), Math.min(Number(spec.max), Number(IrisOptions.currentValue(spec)) + delta * step))
                    IrisOptions.commit(spec, Number(next.toFixed(4)))
                }
            }
            radius: IrisStyle.fieldChamfer ? 0 : root.u(20)
            color: root.plate
            height: Math.max(root.u(64), rowItem.implicitHeight + root.u(8))
            Rectangle {
                anchors.fill: parent
                anchors.margins: -root.u(3)
                radius: IrisStyle.fieldChamfer ? 0 : root.u(23)
                visible: rowPlate.focusedHere
                color: "transparent"
                border.width: Math.max(2, root.u(2))
                border.color: root.engaged ? root.signal : IrisStyle.text
            }
            IrisSetting {
                id: rowItem
                visible: rowPlate.spec !== null
                x: root.u(4)
                y: root.u(4)
                width: parent.width - root.u(8)
                spec: rowPlate.spec ?? ({ kind: "text", label: "" })
                voice: "console"
                last: true
            }
        }
    }

    component Mono: IrisText {
        font.family: IrisStyle.fontMono
        font.pixelSize: root.label
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(root.label * 0.08)
    }
}
