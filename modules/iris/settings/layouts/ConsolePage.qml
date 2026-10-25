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
    // Tiles still building in the background: the pool turns to the board once there are none.
    property int building: 0
    readonly property bool whole: root.building <= 0
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
            const cells = shown.map(spec => root.unitsFor(spec)).concat(folds ? [1] : [])
            const units = cells.reduce((sum, size) => sum + size, 0)
            const brief = units <= 3 && !shown.some(spec => root.shape(spec) === "row")
            // Inside a full-width group the last tile of a line short of the edge takes the rest of it.
            // More and a verb keep their one unit: grown to close a line they were wide plates of nothing.
            if (!brief) {
                const rigid = shown.map(spec => root.shape(spec) === "action").concat(folds ? [true] : [])
                const grow = (from, to, by) => { for (let at = to; at >= from; at--) if (!rigid[at]) { cells[at] += by; return } }
                let fill = 0, start = 0
                cells.forEach((size, at) => {
                    if (fill + size > 4) { grow(start, at - 1, 4 - fill); fill = 0; start = at }
                    fill = (fill + size) % 4
                    if (fill === 0) start = at + 1
                })
                if (fill > 0) grow(start, cells.length - 1, 4 - fill)
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
    function unitsOf(kind: string): int { return kind === "switch" || kind === "action" ? 1 : kind === "row" ? 4 : 2 }
    // A switch that says what it does gets the room to say it.
    function unitsFor(spec: var): int { const kind = root.shape(spec); return kind === "switch" && root.told(spec).length > 0 ? 2 : root.unitsOf(kind) }
    function told(spec: var): string { return typeof spec?.description === "string" ? Translation.tr(spec.description) : "" }
    function shape(spec: var): string {
        if (spec.kind === "switch") return "switch"
        if (spec.kind === "range" && Number.isFinite(Number(spec.min)) && Number.isFinite(Number(spec.max))) return "range"
        // A choice is a tile, never a full-width row for one value (10-25: "Look … Apple" held a whole line): a few
        // short names side by side, more of them one name stepped through.
        if (spec.kind === "choice" && !spec.cards && !spec.niri) {
            const names = IrisOptions.choicesOf(spec).map(entry => Translation.tr(String(entry.label ?? "")))
            if (names.length >= 2 && names.length <= 4 && names.every(name => name.length <= 12) && names.join("").length <= 26) return "choice"
            if (names.length >= 2 && names.length <= 12) return "pick"
        }
        if (spec.kind === "action" && typeof spec.run === "function") return "action"
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
    // The tile the keys stand on, set when the cursor moves: a binding that walked the board from every tile re-ran on
    // each tile built, and opening a More froze the page (10-25).
    property Item focusedTile: null
    onCursorChanged: root.focusedTile = root.cursor >= 0 ? (root.stops()[root.cursor] ?? null) : null
    function focused(): Item { return root.focusedTile }
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
        contentHeight: board.implicitHeight + root.gap
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: IrisScrollBar {}
        Column {
            id: board
            width: boardFlick.width
            spacing: root.section === "general" ? root.gap : 0
            Loader {
                active: root.section === "general"
                visible: active
                width: board.width
                sourceComponent: IrisWallpaperCard { screen: root.QsWindow.window?.screen ?? GlobalStates.focusedScreen }
            }
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
                        // The head as the index reads: its number, its name, then a rule to the end of the line.
                        Row {
                            visible: group.modelData.key.length > 0
                            width: parent.width
                            spacing: root.u(10)
                            Mono {
                                id: groupNumber
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(group.index + 1).padStart(2, "0")
                                color: IrisStyle.textTertiary
                            }
                            Mono {
                                id: groupName
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width - groupNumber.width - root.u(40))
                                elide: Text.ElideRight
                                text: Translation.tr(group.modelData.key)
                                color: IrisStyle.subtext
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - groupNumber.width - groupName.width - 2 * parent.spacing)
                                height: 1
                                color: IrisStyle.hairline
                            }
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
                                    sourceComponent: ({ switch: switchTile, range: rangeTile, choice: choiceTile, pick: pickTile, action: actionTile })[cell.kind] ?? rowTile
                                    property bool counted: false
                                    Component.onCompleted: if (cell.asynchronous && cell.status !== Loader.Ready) { cell.counted = true; root.building++ }
                                    Component.onDestruction: if (cell.counted) root.building--
                                    onLoaded: { item.spec = cell.modelData; if (cell.counted) { cell.counted = false; root.building-- } }
                                    onModelDataChanged: if (cell.item) cell.item.spec = cell.modelData
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
        // Room kept at the right of the name for what a tile carries there (steppers, an arrow).
        property real trail: 0
        readonly property bool consoleStop: true
        readonly property bool focusedHere: root.focusedTile === tile
        readonly property bool noted: { Config.revision; return tile.spec?.note && (tile.spec?.locked?.() || tile.spec?.warns === true) ? String(tile.spec.note() ?? "").length > 0 : false }
        function act(): void {}
        height: root.u(88)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: tile.text
        // The pointer leaves the keys' place: a click never rings a tile or keeps Esc and ◀ ▶ for it.
        onClicked: { root.cursor = -1; root.engaged = false; tile.act() }
        // On is said by an ink ring and the switch's own knob, not a white plate: a page of ons stays a page.
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.fieldChamfer ? 0 : root.u(16)
            color: tile.dashed ? "transparent" : tile.containsMouse ? IrisStyle.fillHover : root.plate
            // a hairline at rest, as the index's keys: a plate on glass keeps its edge over any wallpaper
            border.width: tile.dashed || !tile.on ? 1 : Math.max(1, root.u(1.5))
            border.color: tile.dashed ? IrisStyle.hairlineStrong : tile.on ? IrisStyle.text : IrisStyle.hairline
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        }
        // The key focus: a ring of ink, of signal while a value is held.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -root.u(3)
            radius: IrisStyle.fieldChamfer ? 0 : root.u(19)
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
            width: parent.width - root.u(32) - tile.trail
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
        // Read like its row: the name, what it does under it when there is room, the look's own switch at the right
        // (a faint hollow ring said nothing at a glance, 10-25).
        Tile {
            id: sw
            readonly property bool lit: { Config.revision; IrisNiri.revision; const v = !!IrisOptions.currentValue(sw.spec ?? {}); return sw.spec?.invert ? !v : v }
            readonly property string told: root.told(sw.spec)
            on: sw.lit
            Accessible.role: Accessible.CheckBox
            Accessible.name: Translation.tr(String(sw.spec?.label ?? ""))
            Accessible.checked: sw.lit
            function act(): void { IrisOptions.commit(sw.spec, sw.spec.invert ? sw.lit : !sw.lit) }
            Column {
                x: root.u(16)
                y: root.u(14)
                width: parent.width - x - toggle.width - root.u(28)
                spacing: root.u(3)
                IrisText {
                    width: parent.width
                    elide: Text.ElideRight
                    wrapMode: sw.told.length > 0 ? Text.NoWrap : Text.WordWrap
                    maximumLineCount: 2
                    text: Translation.tr(String(sw.spec?.label ?? ""))
                    color: IrisStyle.text
                    font.pixelSize: IrisStyle.typeBody
                    font.weight: Font.DemiBold
                }
                IrisText {
                    width: parent.width
                    visible: sw.told.length > 0
                    text: sw.told
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeMeta
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
            IrisSwitch {
                id: toggle
                anchors.right: parent.right
                anchors.rightMargin: root.u(16)
                y: root.u(14)
                voice: "console"
                on: sw.lit
                name: sw.Accessible.name
                onToggled: sw.act()
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
            property real wheelRest: 0
            WheelIntent { id: rangeWheel; hovered: range.containsMouse }
            onPositionChanged: mouse => rangeWheel.track(mouse.x, mouse.y)
            onWheel: wheel => {
                if (!rangeWheel.take(wheel)) { wheel.accepted = false; return }
                range.wheelRest += (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
                const steps = Math.trunc(range.wheelRest / 120)
                if (steps === 0) return
                range.wheelRest -= steps * 120
                const by = Math.max(range.step, (range.hi - range.lo) / 20)
                IrisOptions.commit(range.spec, range.snap(range.value + steps * by))
            }
            MouseArea {
                id: scrub
                x: root.u(16)
                y: root.u(42)
                width: parent.width * 0.62 - x
                height: root.u(34)
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function at(x: real): real { return range.snap(range.lo + Math.max(0, Math.min(1, x / width)) * (range.hi - range.lo)) }
                onPressed: mouse => { root.cursor = -1; range.dragged = scrub.at(mouse.x) }
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
    // A choice of many: the chosen name, stepped either way (Enter or a click goes on, ◀ ▶ while held).
    Component {
        id: pickTile
        Tile {
            id: pick
            readonly property bool holds: true
            readonly property var options: IrisOptions.choicesOf(pick.spec ?? {})
            readonly property int at: { Config.revision; IrisNiri.revision; const now = IrisOptions.currentValue(pick.spec ?? {}); return pick.options.findIndex(entry => IrisOptions.same(entry.value, now)) }
            caption: Translation.tr(String(pick.spec?.label ?? ""))
            text: pick.at >= 0 ? Translation.tr(String(pick.options[pick.at].label ?? "")) : ""
            trail: root.u(64)
            Accessible.role: Accessible.ComboBox
            function adjust(delta: int): void {
                const next = pick.options[Math.max(0, Math.min(pick.options.length - 1, pick.at + delta))]
                if (next) IrisOptions.commit(pick.spec, next.value)
            }
            function act(): void { const next = pick.options[(pick.at + 1) % pick.options.length]; if (next) IrisOptions.commit(pick.spec, next.value) }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.u(10)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.u(8)
                Step { glyph: "chevron_left"; usable: pick.at > 0; onActed: pick.adjust(-1) }
                Step { glyph: "chevron_right"; usable: pick.at < pick.options.length - 1; onActed: pick.adjust(1) }
            }
            // Its place among the others, as dots under the caption.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.u(16)
                y: root.u(18)
                spacing: root.u(4)
                Repeater {
                    model: pick.options.length
                    Rectangle {
                        required property int index
                        width: root.u(index === pick.at ? 12 : 4)
                        height: root.u(4)
                        radius: height / 2
                        color: index === pick.at ? IrisStyle.text : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.22)
                        Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
            }
        }
    }
    // A verb: its name and where it leads.
    Component {
        id: actionTile
        Tile {
            id: verb
            caption: Translation.tr(String(verb.spec?.label ?? ""))
            text: Translation.tr(String(verb.spec?.button ?? ""))
            trail: root.u(28)
            function act(): void { verb.spec.run() }
            MaterialSymbol {
                anchors.right: parent.right
                anchors.rightMargin: root.u(16)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.u(14)
                text: "arrow_forward"
                iconSize: root.u(18)
                color: IrisStyle.subtext
            }
        }
    }
    component Step: MouseArea {
        id: step
        property string glyph: ""
        property bool usable: true
        signal acted()
        width: root.u(30)
        height: width
        enabled: step.usable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: step.acted()
        Rectangle { anchors.fill: parent; radius: width / 2; color: step.containsMouse ? IrisStyle.fillHover : "transparent" }
        MaterialSymbol { anchors.centerIn: parent; text: step.glyph; iconSize: root.u(20); color: IrisStyle.text; opacity: step.usable ? 1 : 0.25 }
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
            readonly property bool focusedHere: root.focusedTile === rowPlate
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
            radius: IrisStyle.fieldChamfer ? 0 : root.u(16)
            color: root.plate
            border.width: 1
            border.color: IrisStyle.hairline
            height: Math.max(root.u(64), rowItem.implicitHeight + root.u(8))
            Rectangle {
                anchors.fill: parent
                anchors.margins: -root.u(3)
                radius: IrisStyle.fieldChamfer ? 0 : root.u(19)
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
