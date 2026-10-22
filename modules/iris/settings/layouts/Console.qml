pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings
import qs.modules.iris.settings.layouts.console as Skins // so Quickshell mirrors the skins IrisSkin loads by url

// Console: Nothing's quick settings for the whole shell. The areas are a grid of 1x1 keys under their Label heads (the
// open one inverted, a signal dot where one needs you); the area is its Dot title over its groups, each a run of tiles:
// a switch is a 1x1 tile (on = inverted), a range a 2x1 tile with a dot scrubber and one Dot number, a short choice a
// 2x1 tile with its segmented, anything longer a full-width tile holding its row. Arrows walk the tiles, Enter acts,
// a held range or choice moves with ◀ ▶.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: board.width
    readonly property real need: 0
    readonly property string voice: "console"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    readonly property color groupFill: "transparent"
    readonly property string searchHint: Translation.tr("Search")

    readonly property bool windowed: Boolean(root.host?.windowed ?? true)
    readonly property real pad: root.u(root.windowed ? 18 : 24)
    readonly property real gap: root.u(10)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property bool paged: Number(root.host?.advancedPage ?? -1) >= 0
    readonly property bool home: root.section === "home" && !root.searching
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    readonly property color plate: IrisStyle.glassy ? IrisStyle.readingCard : IrisStyle.fillQuiet
    readonly property real label: Math.max(10, IrisStyle.typeCaption)
    function clusterName(index: int): string { return Translation.tr(String(root.host?.clusterNames?.[index] ?? "")) }
    // A key says its area in one short word: the full title is its accessible name.
    readonly property var shortNames: ({ home: "Home", appearance: "Style", colour: "Colour", wallpaper: "Wall", motion: "Motion", bar: "Island",
        dock: "Dock", bubbles: "Bubbles", desktop: "Desktop", widgets: "Widgets", windows: "Windows", sidebars: "Panels", controlCenter: "Control",
        spotlight: "Search", orbit: "Orbit", capture: "Capture", player: "Music", anime: "Anime", general: "General", notifications: "Alerts",
        sound: "Sound", display: "Display", keyboard: "Keys", battery: "Power", gaming: "Gaming", lock: "Lock", login: "Login", sources: "Sources", system: "Hub" })

    // ── The area as tiles: every row it shows, by group; fine-tuning waits behind a group's More tile.
    readonly property var groups: {
        Config.revision
        IrisNiri.revision
        if (root.home || root.searching) return []
        const out = []
        for (const spec of IrisOptions.settings) {
            if (spec.section !== root.section || spec.mirror || !IrisOptions.shown(spec)) continue
            const key = String(spec.group ?? "")
            let group = out.find(entry => entry.key === key)
            if (!group) { group = { key: key, rows: [] }; out.push(group) }
            group.rows.push(spec)
        }
        return out
    }
    // Everything is drawn here: the engine's rows only hold a search or a page.
    readonly property var claims: root.searching ? [] : IrisOptions.settings.filter(spec => spec.section === root.section)
    property var opened: ({})
    function folded(group: var): var { return group.rows.filter(spec => IrisOptions.fineTune(spec) && !IrisOptions.changed(spec)) }
    function shape(spec: var): string {
        if (spec.kind === "switch") return "switch"
        if (spec.kind === "range" && Number.isFinite(Number(spec.min)) && Number.isFinite(Number(spec.max))) return "range"
        if (spec.kind === "choice" && !spec.cards) {
            const choices = IrisOptions.choicesOf(spec)
            if (choices.length >= 2 && choices.length <= 4 && choices.every(entry => Translation.tr(String(entry.label ?? "")).length <= 9)) return "choice"
        }
        return "row"
    }

    // A new area rises into place; it only moves, it never waits on a fade.
    property int was: -1
    onCurrentChanged: {
        if (root.was >= 0 && root.was !== root.current && IrisStyle.motionEnabled) areaIn.restart()
        root.was = root.current
        root.cursor = -1
        root.engaged = false
        boardFlick.contentY = 0
    }
    Component.onCompleted: root.was = root.current
    NumberAnimation { id: areaIn; target: boardShift; property: "y"; from: root.u(22); to: 0; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }

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

    // ── The areas.
    Flickable {
        id: nav
        x: root.pad
        y: root.pad
        width: root.u(4 * 66 + 3 * 6)
        height: root.height - 2 * root.pad
        contentHeight: navColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Column {
            id: navColumn
            width: nav.width
            spacing: root.u(6)
            Repeater {
                model: {
                    const out = []
                    for (const entry of root.sections) {
                        const at = Number(entry.cluster ?? 0)
                        let cluster = out.find(c => c.index === at)
                        if (!cluster) { cluster = { index: at, areas: [] }; out.push(cluster) }
                        cluster.areas.push(entry)
                    }
                    return out
                }
                Column {
                    id: cluster
                    required property var modelData
                    width: navColumn.width
                    spacing: root.u(6)
                    Mono {
                        visible: cluster.modelData.index >= 0
                        topPadding: root.u(8)
                        text: root.clusterName(cluster.modelData.index)
                        color: IrisStyle.textTertiary
                    }
                    Grid {
                        columns: 4
                        spacing: root.u(6)
                        Repeater {
                            model: cluster.modelData.areas
                            MouseArea {
                                id: key
                                required property var modelData
                                readonly property bool on: key.modelData.id === root.section && !root.searching
                                readonly property bool noted: Number(root.noteCounts[key.modelData.id] ?? 0) > 0
                                readonly property bool found: !root.searching || (root.host?.matchedSections?.has(key.modelData.id) ?? false)
                                width: root.u(66)
                                height: root.u(62)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                opacity: key.found ? 1 : 0.35
                                Accessible.role: Accessible.PageTab
                                Accessible.name: Translation.tr(String(key.modelData.title ?? ""))
                                Accessible.checked: key.on
                                onClicked: root.host.selectSection(key.modelData.id)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: root.u(16)
                                    color: key.on ? IrisStyle.text : key.containsMouse ? IrisStyle.fillHover : root.plate
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                                }
                                MaterialSymbol {
                                    x: root.u(9)
                                    y: root.u(9)
                                    text: String(key.modelData.icon ?? "settings")
                                    iconSize: root.u(18)
                                    fill: key.on ? 1 : 0
                                    color: key.on ? IrisStyle.surfaceOpaque : IrisStyle.text
                                }
                                Rectangle {
                                    visible: key.noted
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: root.u(9)
                                    width: root.u(6)
                                    height: width
                                    radius: width / 2
                                    color: root.signal
                                }
                                Mono {
                                    x: root.u(9)
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: root.u(8)
                                    width: parent.width - root.u(12)
                                    elide: Text.ElideRight
                                    text: Translation.tr(String(root.shortNames[key.modelData.id] ?? key.modelData.title ?? ""))
                                    color: key.on ? IrisStyle.surfaceOpaque : IrisStyle.subtext
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── The area's head: its Dot title and what it is, then the search, the layouts, the way out.
    Item {
        id: head
        x: nav.x + nav.width + root.u(26)
        y: root.pad
        width: root.width - x - root.pad
        height: root.u(58)
        DotTitle {
            id: title
            anchors.bottom: parent.bottom
            text: root.searching ? Translation.tr("Search") : Translation.tr(String(root.area.title ?? ""))
            size: root.u(root.windowed ? 34 : 44)
            fit: Math.max(root.u(120), controls.x - root.u(240))
        }
        IrisText {
            anchors.left: title.right
            anchors.leftMargin: root.u(16)
            anchors.baseline: title.bottom
            anchors.baselineOffset: -root.u(4)
            width: Math.max(0, Math.min(implicitWidth, controls.x - x - root.u(16)))
            elide: Text.ElideRight
            visible: !root.searching
            text: Translation.tr(String(root.area.subtitle ?? ""))
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeMeta
        }
        Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(8)
            Item { id: searchSlot; width: root.u(root.windowed ? 160 : 220); height: root.u(38) }
            LayoutSwitch { host: root.host; voice: "console"; compact: root.windowed }
            RoundKey {
                glyph: root.windowed ? "layers" : "web_asset"
                name: root.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                onClicked: root.host.switchHost()
            }
            RoundKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
        }
    }

    // ── The board.
    Item {
        id: boardBox
        x: head.x
        y: head.y + head.height + root.u(18)
        width: head.width
        height: root.height - y - root.pad
        transform: Translate { id: boardShift }
        Home {
            visible: root.home
            anchors.fill: parent
            host: root.host
            voice: "console"
        }
        Flickable {
            id: boardFlick
            visible: !root.home && !root.searching && !root.paged
            anchors.fill: parent
            contentHeight: boardColumn.implicitHeight + root.gap
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.vertical: IrisScrollBar {}
            Column {
                id: board
                width: boardFlick.width
                Column {
                    id: boardColumn
                    width: parent.width
                    spacing: root.u(18)
                    Repeater {
                        model: root.groups
                        Column {
                            id: group
                            required property var modelData
                            readonly property var tuned: root.folded(group.modelData)
                            readonly property bool open: root.opened[root.section + "/" + group.modelData.key] === true
                            readonly property bool folds: group.tuned.length >= 2 && group.tuned.length < group.modelData.rows.length
                            readonly property var shown: group.folds && !group.open ? group.modelData.rows.filter(spec => !group.tuned.includes(spec)) : group.modelData.rows
                            width: boardColumn.width
                            spacing: root.gap
                            Mono {
                                visible: group.modelData.key.length > 0
                                text: Translation.tr(group.modelData.key)
                                color: IrisStyle.textTertiary
                            }
                            Flow {
                                width: parent.width
                                spacing: root.gap
                                readonly property real unit: Math.floor((width - 3 * root.gap) / 4)
                                Repeater {
                                    model: ScriptModel { values: group.shown; objectProp: "label" }
                                    Loader {
                                        id: cell
                                        required property var modelData
                                        readonly property string kind: root.shape(cell.modelData)
                                        width: cell.kind === "switch" ? parent.unit : cell.kind === "row" ? parent.width : 2 * parent.unit + root.gap
                                        sourceComponent: cell.kind === "switch" ? switchTile : cell.kind === "range" ? rangeTile : cell.kind === "choice" ? choiceTile : rowTile
                                        onLoaded: item.spec = cell.modelData
                                    }
                                }
                                Tile {
                                    visible: group.folds
                                    width: parent.unit
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
    }
    // The engine's rows: a search's results or a page (the Hub).
    Item {
        id: rowsSlot
        visible: root.searching || root.paged
        x: boardBox.x - root.u(6)
        y: boardBox.y
        width: boardBox.width + root.u(12)
        height: boardBox.height
        clip: true
    }

    // ── Tiles.
    component Mono: IrisText {
        font.family: IrisStyle.fontMono
        font.pixelSize: root.label
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(root.label * 0.08)
    }
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
        height: root.u(84)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: tile.text
        onClicked: { root.cursor = root.stops().indexOf(tile); tile.act() }
        Rectangle {
            anchors.fill: parent
            radius: root.u(20)
            color: tile.on ? IrisStyle.text : tile.dashed ? "transparent" : tile.containsMouse ? IrisStyle.fillHover : root.plate
            border.width: tile.dashed ? 1 : 0
            border.color: IrisStyle.hairlineStrong
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        }
        // The key focus: a ring of ink, of signal while a value is held.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -root.u(3)
            radius: root.u(23)
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
            color: tile.on ? Qt.rgba(IrisStyle.surfaceOpaque.r, IrisStyle.surfaceOpaque.g, IrisStyle.surfaceOpaque.b, 0.62) : IrisStyle.muted
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
            color: tile.on ? IrisStyle.surfaceOpaque : IrisStyle.text
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
            caption: sw.lit ? Translation.tr("On") : Translation.tr("Off")
            text: Translation.tr(String(sw.spec?.label ?? ""))
            Accessible.role: Accessible.CheckBox
            Accessible.checked: sw.lit
            function act(): void { IrisOptions.commit(sw.spec, sw.spec.invert ? sw.lit : !sw.lit) }
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
            height: root.u(108)
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
                y: root.u(46)
                width: parent.width * 0.62 - x
                height: root.u(36)
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
            height: root.u(108)
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
            radius: root.u(20)
            color: root.plate
            height: Math.max(root.u(64), rowItem.implicitHeight + root.u(8))
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

    component RoundKey: MouseArea {
        id: key
        property string glyph
        property string name
        width: root.u(38)
        height: width
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        Rectangle { anchors.fill: parent; radius: width / 2; color: key.containsMouse ? IrisStyle.fillHover : root.plate }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.text }
    }
}
