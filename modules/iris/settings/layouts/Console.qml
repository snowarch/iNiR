pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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

// Console (Consola), Nothing's way: monochrome, one red. The area's name in dot type over a grid of round keys, one per
// area in its clusters (the open one the ink, a red dot where an area has a note); beside it the area as widgets: where
// its piece sits on a screen of dots, its lead figure big in dots over a dot scrubber, its shapes as tiles, its switches
// as quick-settings tiles, its pinned apps in grey with the missing one ringed in red. The engine's rows hold the rest.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: rowsPanel.width
    readonly property real need: 0
    readonly property string voice: "console"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    readonly property color groupFill: "transparent"

    readonly property bool windowed: Boolean(root.host?.windowed ?? true)
    readonly property real pad: root.u(root.windowed ? 20 : 28)
    readonly property real gap: root.u(root.windowed ? 10 : 12)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property int noteTotal: Object.keys(root.noteCounts).reduce((sum, id) => sum + Number(root.noteCounts[id] ?? 0), 0)
    readonly property var notes: root.host?.notesHere ?? []
    function clusterName(index: int): string { return Translation.tr(String(root.host?.clusterNames?.[index] ?? "")) }
    // One fill for every widget: over glass the reading plate, so the wallpaper never reaches the type.
    readonly property color plate: IrisStyle.glassy ? IrisStyle.readingCard : IrisStyle.fillQuiet
    readonly property color dim: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.18)

    // ── What the area's widgets show, read from its own specs (never the engine's entries: those leave out what we claim).
    readonly property var areaSpecs: {
        Config.revision
        return IrisOptions.settings.filter(spec => spec.section === root.section && !spec.mirror && spec.path && IrisOptions.shown(spec)
            && !(spec.locked && spec.locked()) && spec.path !== "iris.appearance.settingsLayout")
    }
    readonly property var essentials: root.areaSpecs.filter(spec => !IrisOptions.fineTune(spec))
    readonly property var edgeSpec: root.essentials.find(spec => spec.kind === "choice"
        && ["top", "bottom", "left", "right"].every(side => IrisOptions.choicesOf(spec).some(entry => entry.value === side))) ?? null
    // The lead figure: an essential range first, else the first fine-tuned one (the Dock's icon size).
    readonly property var rangeSpec: {
        const ranged = spec => spec.kind === "range" && Number.isFinite(Number(spec.min)) && Number.isFinite(Number(spec.max))
        return root.essentials.find(ranged) ?? root.areaSpecs.find(ranged) ?? null
    }
    readonly property var tileSpec: root.essentials.find(spec => spec.kind === "choice" && spec !== root.edgeSpec
        && IrisOptions.choicesOf(spec).length >= 3 && IrisOptions.choicesOf(spec).length <= 4) ?? null
    readonly property var chipSpec: root.tileSpec ? (root.essentials.find(spec => spec.kind === "choice" && spec !== root.edgeSpec && spec !== root.tileSpec
        && IrisOptions.choicesOf(spec).length >= 2 && IrisOptions.choicesOf(spec).length <= 5
        && IrisOptions.choicesOf(spec).every(entry => Translation.tr(String(entry.label ?? "")).length <= 10)) ?? null) : null
    readonly property var switchSpecs: root.essentials.filter(spec => spec.kind === "switch")
    readonly property var pinSpec: { Config.revision; return IrisOptions.settings.find(spec => spec.section === root.section && String(spec.view ?? "").endsWith("IrisDockPinned.qml") && IrisOptions.shown(spec)) ?? null }
    readonly property bool pins: root.pinSpec !== null
    // The engine leaves out of the rows what a widget already shows.
    readonly property var claims: {
        if (root.host?.searching ?? false) return []
        return [root.edgeSpec, root.rangeSpec, root.tileSpec, root.chipSpec].filter(spec => spec !== null).concat(root.toggles)
    }

    // ── The widgets' grid: six columns over the desktop, four in a window.
    readonly property real columnWidth: board.width
    readonly property int cols: root.windowed ? 4 : 6
    function spanWidth(span: int): real { return Math.floor((root.columnWidth - (root.cols - 1) * root.gap) / root.cols * span + (span - 1) * root.gap) }
    readonly property var tops: [root.edgeSpec ? "edge" : "", root.rangeSpec ? "range" : "", root.tileSpec ? "tiles" : ""].filter(kind => kind.length > 0)
    function topSpan(index: int): int {
        if (!root.windowed) return 6 / root.tops.length
        return root.tops.length === 1 || index === 2 ? 4 : 2
    }
    readonly property real shapeHeight: root.u(root.windowed ? 52 : 64)
    readonly property real capHeight: root.u(root.windowed ? 16 : 20) + IrisStyle.typeCaption + root.u(root.windowed ? 26 : 30)
    readonly property real tilesNeed: root.capHeight + root.shapeHeight + (root.chipSpec ? root.u(24) + IrisStyle.typeCaption + root.u(root.windowed ? 28 : 32) : 0)
    // The screen and the scrubber want room; shapes alone only what they hold.
    readonly property real topHeight: root.tops.length === 0 ? 0
        : root.tops.some(kind => kind !== "tiles") ? root.u(root.windowed ? 196 : 232) : root.tilesNeed
    // In a window the shapes lie in one row under the other two: their widget only as tall as that row.
    readonly property real tileStrip: root.tilesNeed
    function topHeightOf(index: int): real { return root.windowed && root.tops.length === 3 && index === 2 ? root.tileStrip : root.topHeight }
    readonly property real topBlock: root.tops.length === 0 ? 0 : root.windowed && root.tops.length === 3 ? root.topHeight + root.tileStrip + root.gap : root.topHeight
    readonly property bool noteWidget: root.pins || root.notes.length > 0
    readonly property real noteHeight: root.noteWidget ? root.u(root.windowed ? 72 : 88) : 0
    readonly property int tileCols: root.windowed ? 3 : 4
    readonly property real tileHeight: root.u(root.windowed ? 46 : 58)
    // Switch tiles take what the screen spares: never more than the rows keep below them.
    readonly property int toggleRows: {
        const spare = board.height * 0.78 - root.topBlock - root.noteHeight - (root.topBlock > 0 ? root.gap : 0) - (root.noteWidget ? root.gap : 0)
        const fit = Math.floor((spare - root.u(56) + root.gap) / (root.tileHeight + root.gap))
        return Math.max(0, Math.min(2, fit, Math.ceil(root.switchSpecs.length / root.tileCols)))
    }
    readonly property var toggles: root.switchSpecs.slice(0, root.toggleRows * root.tileCols)
    property real rangeDragged: NaN
    readonly property string rangeSaid: {
        Config.revision
        if (!root.rangeSpec) return ""
        const value = Number.isFinite(root.rangeDragged) ? root.rangeDragged : Number(IrisOptions.currentValue(root.rangeSpec))
        return Translation.tr(IrisOptions.rangeText(root.rangeSpec, value))
    }

    // A new area rises into place under the head.
    property int was: -1
    onCurrentChanged: {
        if (root.was >= 0 && root.was !== root.current && IrisStyle.motionEnabled) areaIn.restart()
        root.was = root.current
    }
    Component.onCompleted: root.was = root.current
    ParallelAnimation {
        id: areaIn
        NumberAnimation { target: boardShift; property: "y"; from: root.u(18); to: 0; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        NumberAnimation { targets: [board, rowsSlot, place]; property: "opacity"; from: 0; to: 1; duration: IrisStyle.duration(240); easing.type: IrisStyle.feedbackEasing }
    }

    // ── The head: the area in dot type, where it sits, the search, the layouts, the notes, the way out.
    Item {
        id: head
        x: root.pad
        y: root.u(root.windowed ? 18 : 24)
        width: root.width - 2 * root.pad
        height: root.u(root.windowed ? 50 : 64)
        Skins.DotMatrix {
            id: title
            anchors.bottom: parent.bottom
            text: Translation.tr(String(root.area.title ?? ""))
            pitch: root.u(root.windowed ? 6 : 9)
            fit: Math.max(root.u(120), controls.x - root.u(260))
        }
        IrisText {
            id: place
            anchors.left: title.right
            anchors.leftMargin: root.u(20)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u(1)
            width: Math.max(0, Math.min(implicitWidth, controls.x - x - root.u(20)))
            elide: Text.ElideRight
            text: Translation.tr(String(root.area.subtitle ?? ""))
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeLabel
        }
        Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(10)
            Item { id: searchSlot; width: root.u(root.windowed ? 150 : 220); height: root.u(40) }
            LayoutSwitch { host: root.host; voice: "console"; compact: root.windowed }
            MouseArea {
                id: notePill
                visible: root.noteTotal > 0
                width: root.u(40)
                height: width
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: root.noteTotal === 1 ? Translation.tr("1 note") : Translation.tr("%1 notes").arg(root.noteTotal)
                onClicked: root.host.openNote()
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: notePill.containsMouse ? Qt.rgba(IrisStyle.danger.r, IrisStyle.danger.g, IrisStyle.danger.b, 0.14) : "transparent"
                    border.width: Math.max(1, root.u(1.5))
                    border.color: IrisStyle.danger
                }
                MaterialSymbol { anchors.centerIn: parent; text: "priority_high"; iconSize: root.u(19); color: IrisStyle.danger }
            }
            RoundKey {
                glyph: root.windowed ? "layers" : "web_asset"
                name: root.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                onClicked: root.host.switchHost()
            }
            RoundKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
        }
    }

    // ── Every area as a round key, in its clusters; the keys shrink until every cluster fits the height.
    readonly property var clusterSizes: { const out = {}; for (const entry of root.sections) out[entry.cluster ?? 0] = (out[entry.cluster ?? 0] ?? 0) + 1; return Object.values(out) }
    readonly property real keyHeight: {
        const rows = root.clusterSizes.reduce((sum, n) => sum + Math.ceil(n / 4), 0)
        const heads = root.clusterSizes.length * (root.u(16) + 2 * navColumn.spacing)
        const each = (nav.height - heads) / Math.max(1, rows) - root.u(4)
        return Math.max(root.u(root.windowed ? 44 : 50), Math.min(root.u(root.windowed ? 58 : 72), Math.floor(each)))
    }
    Flickable {
        id: nav
        x: root.pad
        y: head.y + head.height + root.u(root.windowed ? 16 : 22)
        width: root.u(root.windowed ? 220 : 276)
        height: root.height - y - root.pad
        contentHeight: navColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Column {
            id: navColumn
            width: nav.width
            spacing: root.u(root.windowed ? 4 : 6)
            Repeater {
                model: {
                    const out = []
                    for (const entry of root.sections) {
                        const at = Number(entry.cluster ?? 0)
                        let cluster = out.find(c => c.index === at)
                        if (!cluster) { cluster = { index: at, areas: [] }; out.push(cluster) }
                        cluster.areas.push(entry)
                    }
                    return out.sort((a, b) => a.index - b.index)
                }
                Column {
                    id: cluster
                    required property var modelData
                    width: navColumn.width
                    spacing: root.u(root.windowed ? 4 : 6)
                    Item {
                        width: parent.width
                        height: root.u(16)
                        IrisText {
                            id: clusterName
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.clusterName(cluster.modelData.index)
                            color: IrisStyle.muted
                            font.family: IrisStyle.fontMono
                            font.pixelSize: IrisStyle.typeCaption
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.16)
                        }
                        DottedRule { x: clusterName.width + root.u(10); width: parent.width - x; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Grid {
                        columns: 4
                        rowSpacing: root.u(4)
                        Repeater {
                            model: cluster.modelData.areas
                            MouseArea {
                                id: key
                                required property var modelData
                                readonly property bool on: key.modelData.id === root.section
                                readonly property bool noted: Number(root.noteCounts[key.modelData.id] ?? 0) > 0
                                width: navColumn.width / 4
                                height: root.keyHeight
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: Translation.tr(String(key.modelData.title ?? ""))
                                Accessible.checked: key.on
                                onClicked: root.host.selectSection(key.modelData.id)
                                Rectangle {
                                    id: disc
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(root.u(root.windowed ? 40 : 50), root.keyHeight - root.u(root.windowed ? 16 : 18))
                                    height: width
                                    radius: width / 2
                                    color: key.on ? IrisStyle.text : key.containsMouse ? IrisStyle.fillHover : root.plate
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: String(key.modelData.icon ?? "settings")
                                        iconSize: root.u(root.windowed ? 18 : 21)
                                        color: key.on ? IrisStyle.surfaceOpaque : IrisStyle.text
                                    }
                                }
                                Rectangle {
                                    visible: key.noted
                                    x: disc.x + disc.width - width
                                    y: disc.y + root.u(1)
                                    width: root.u(7)
                                    height: width
                                    radius: width / 2
                                    color: IrisStyle.danger
                                }
                                IrisText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: parent.width - root.u(2)
                                    fontSizeMode: Text.HorizontalFit
                                    minimumPixelSize: Math.max(8, IrisStyle.typeCaption - 3)
                                    horizontalAlignment: Text.AlignHCenter
                                    // A key says the first word of its area: "Bubbles", not "Bubbles & Cards".
                                    text: Translation.tr(String(key.modelData.title ?? "")).split(/\s+/)[0]
                                    color: key.on ? IrisStyle.text : key.containsMouse ? IrisStyle.subtext : IrisStyle.muted
                                    font.family: IrisStyle.fontMono
                                    font.pixelSize: IrisStyle.typeCaption
                                    font.weight: key.on ? Font.DemiBold : Font.Medium
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.06)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── The area as widgets, the rows under them.
    Item {
        id: board
        transform: Translate { id: boardShift }
        x: nav.x + nav.width + root.u(root.windowed ? 18 : 28)
        y: nav.y
        width: root.width - x - root.pad
        height: nav.height
        visible: !(root.host?.searching ?? false)

        Flow {
            id: widgets
            width: board.width
            spacing: root.gap
            Repeater {
                model: root.tops
                Widget {
                    id: top
                    required property string modelData
                    required property int index
                    width: root.spanWidth(root.topSpan(top.index))
                    height: root.topHeightOf(top.index)
                    caption: top.modelData === "edge" ? root.edgeSpec?.label ?? "" : top.modelData === "range" ? root.rangeSpec?.label ?? "" : root.tileSpec?.label ?? ""
                    note: top.modelData === "range" ? root.rangeSaid : ""
                    Loader {
                        anchors.fill: parent.body
                        sourceComponent: top.modelData === "edge" ? edgeWidget : top.modelData === "range" ? rangeWidget : tilesWidget
                    }
                }
            }
            Widget {
                visible: root.toggles.length > 0
                width: root.spanWidth(root.cols)
                height: root.u(56) + root.toggleRows * root.tileHeight + (root.toggleRows - 1) * root.gap
                caption: [...new Set(root.toggles.map(spec => Translation.tr(String(spec.group ?? ""))))].join("  ·  ")
                Grid {
                    anchors.fill: parent.body
                    columns: root.tileCols
                    spacing: root.gap
                    Repeater {
                        model: root.toggles
                        Tile {
                            id: toggle
                            required property var modelData
                            readonly property bool lit: { Config.revision; const v = !!IrisOptions.currentValue(toggle.modelData); return toggle.modelData.invert ? !v : v }
                            width: Math.floor((root.spanWidth(root.cols) - root.u(root.windowed ? 36 : 44) - (root.tileCols - 1) * root.gap) / root.tileCols)
                            height: root.tileHeight
                            on: toggle.lit
                            glyph: IrisOptions.groupGlyphs[String(toggle.modelData.group ?? "")] ?? String(root.area.icon ?? "settings")
                            label: Translation.tr(String(toggle.modelData.label ?? ""))
                            onClicked: IrisOptions.commit(toggle.modelData, toggle.modelData.invert ? toggle.lit : !toggle.lit)
                        }
                    }
                }
            }
            Widget {
                visible: root.noteWidget
                width: root.spanWidth(root.cols)
                height: root.noteHeight
                caption: String(root.pinSpec?.label ?? "")
                Loader { anchors.fill: parent.body; sourceComponent: pinsWidget }
            }
        }

        // The engine's rows, on one more widget: groups read under their mono heads.
        Rectangle {
            id: rowsPanel
            readonly property bool used: (root.host?.entries?.length ?? 0) > 0
            y: widgets.height > 0 ? widgets.height + root.gap : 0
            width: board.width
            height: Math.max(0, board.height - y)
            visible: rowsPanel.used
            radius: root.u(root.windowed ? 24 : 28)
            color: root.plate
        }
    }
    Item {
        id: rowsSlot
        x: board.x + root.u(6)
        y: ((root.host?.searching ?? false) ? board.y : board.y + rowsPanel.y + root.u(4)) + boardShift.y
        width: board.width - root.u(12)
        height: (root.host?.searching ?? false) ? board.height : Math.max(0, rowsPanel.height - root.u(8))
        clip: true
    }

    // ── Widgets.
    component Widget: Rectangle {
        id: widget
        property string caption: ""
        property string note: ""
        readonly property alias body: body
        radius: root.u(root.windowed ? 24 : 28)
        color: root.plate
        IrisText {
            id: cap
            x: root.u(root.windowed ? 18 : 22)
            y: root.u(root.windowed ? 16 : 20)
            width: parent.width - 2 * x - (capNote.visible ? capNote.width + root.u(12) : 0)
            elide: Text.ElideRight
            text: Translation.tr(widget.caption)
            color: IrisStyle.muted
            font.family: IrisStyle.fontMono
            font.pixelSize: IrisStyle.typeCaption
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.16)
        }
        IrisText {
            id: capNote
            visible: widget.note.length > 0
            anchors.right: parent.right
            anchors.rightMargin: cap.x
            anchors.verticalCenter: cap.verticalCenter
            text: widget.note
            color: IrisStyle.text
            font.family: IrisStyle.fontMono
            font.pixelSize: IrisStyle.typeCaption
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.12)
        }
        Item {
            id: body
            x: cap.x
            y: cap.y + cap.height + root.u(12)
            width: widget.width - 2 * cap.x
            height: widget.height - y - root.u(root.windowed ? 14 : 18)
        }
    }
    component Tile: MouseArea {
        id: tile
        property bool on: false
        property string glyph: ""
        property string label: ""
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.CheckBox
        Accessible.name: tile.label
        Accessible.checked: tile.on
        Rectangle {
            anchors.fill: parent
            radius: root.u(root.windowed ? 16 : 20)
            color: tile.on ? IrisStyle.text : tile.containsMouse ? IrisStyle.fillHover : "transparent"
            border.width: tile.on ? 0 : 1
            border.color: IrisStyle.hairlineStrong
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        }
        Row {
            x: root.u(root.windowed ? 12 : 16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(12)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: tile.glyph
                iconSize: root.u(root.windowed ? 17 : 20)
                color: tile.on ? IrisStyle.surfaceOpaque : IrisStyle.muted
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, tile.width - root.u(root.windowed ? 52 : 64))
                elide: Text.ElideRight
                text: tile.label
                color: tile.on ? IrisStyle.surfaceOpaque : IrisStyle.subtext
                font.pixelSize: root.windowed ? IrisStyle.typeMeta : IrisStyle.typeLabel
                font.weight: tile.on ? Font.Medium : Font.Normal
            }
        }
    }
    component Chips: Flow {
        id: chips
        property var spec: null
        spacing: root.u(6)
        readonly property var current: { Config.revision; return chips.spec ? IrisOptions.currentValue(chips.spec) : null }
        Repeater {
            model: chips.spec ? IrisOptions.choicesOf(chips.spec) : []
            MouseArea {
                id: chip
                required property var modelData
                readonly property bool on: IrisOptions.same(chip.modelData.value, chips.current)
                width: chipText.implicitWidth + root.u(22)
                height: root.u(root.windowed ? 28 : 32)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.RadioButton
                Accessible.name: chipText.text
                Accessible.checked: chip.on
                onClicked: IrisOptions.commit(chips.spec, chip.modelData.value)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: chip.on ? IrisStyle.text : "transparent"
                    border.width: chip.on ? 0 : 1
                    border.color: chip.containsMouse ? IrisStyle.muted : IrisStyle.hairlineStrong
                }
                IrisText {
                    id: chipText
                    anchors.centerIn: parent
                    text: Translation.tr(String(chip.modelData.label ?? ""))
                    color: chip.on ? IrisStyle.surfaceOpaque : IrisStyle.muted
                    font.family: IrisStyle.fontMono
                    font.pixelSize: IrisStyle.typeCaption
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.1)
                }
            }
        }
    }
    component DottedRule: Canvas {
        id: rule
        height: 2
        readonly property color ink: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.22)
        onWidthChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = rule.ink
            for (let x = 0; x < width; x += 4) ctx.fillRect(x, 0, 1, 1)
        }
    }

    // Where the area's piece sits: the screen as dots, the piece on its edge with a red line under it; the edges as keys.
    Component {
        id: edgeWidget
        Item {
            id: edge
            readonly property string at: { Config.revision; return root.edgeSpec ? String(IrisOptions.currentValue(root.edgeSpec)) : "" }
            readonly property string side: ["top", "bottom", "left", "right"].includes(edge.at) ? edge.at : "bottom"
            readonly property bool across: edge.side === "top" || edge.side === "bottom"
            Item {
                id: screen
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(0, (edge.height - edgeChips.height - root.u(12) - height) / 2)
                height: Math.min(edge.height - edgeChips.height - root.u(14), edge.width * 9 / 16)
                width: Math.round(height * 16 / 9)
                Canvas {
                    id: grid
                    anchors.fill: parent
                    readonly property color ink: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.2)
                    readonly property real pitch: root.u(9)
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onInkChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = grid.ink
                        for (let y = grid.pitch; y < height - 2; y += grid.pitch)
                            for (let x = grid.pitch; x < width - 2; x += grid.pitch) {
                                ctx.beginPath(); ctx.arc(x, y, 1.1, 0, 2 * Math.PI); ctx.fill()
                            }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: root.u(16)
                    color: "transparent"
                    border.width: 1
                    border.color: IrisStyle.hairlineStrong
                }
                // The piece: a dark capsule of white dots on its edge.
                Rectangle {
                    id: piece
                    readonly property int count: 8
                    readonly property real dot: root.u(8)
                    width: edge.across ? piece.count * (piece.dot + root.u(5)) + root.u(11) : piece.dot + root.u(12)
                    height: edge.across ? piece.dot + root.u(12) : piece.count * (piece.dot + root.u(5)) + root.u(11)
                    x: edge.across ? (screen.width - width) / 2 : edge.side === "left" ? root.u(10) : screen.width - width - root.u(10)
                    y: !edge.across ? (screen.height - height) / 2 : edge.side === "top" ? root.u(10) : screen.height - height - root.u(10)
                    radius: Math.min(width, height) / 2
                    color: IrisStyle.surfaceOpaque
                    border.width: 1
                    border.color: IrisStyle.hairlineStrong
                    Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                    Behavior on y { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                    Grid {
                        anchors.centerIn: parent
                        columns: edge.across ? piece.count : 1
                        spacing: root.u(5)
                        Repeater {
                            model: piece.count
                            Rectangle { width: piece.dot; height: piece.dot; radius: piece.dot / 2; color: IrisStyle.text }
                        }
                    }
                }
                Rectangle {
                    color: IrisStyle.danger
                    radius: root.u(1.5)
                    width: edge.across ? screen.width - root.u(48) : root.u(3)
                    height: edge.across ? root.u(3) : screen.height - root.u(40)
                    x: edge.across ? root.u(24) : edge.side === "left" ? -root.u(1) : screen.width - width + root.u(1)
                    y: !edge.across ? root.u(20) : edge.side === "top" ? -root.u(1) : screen.height - height + root.u(1)
                }
            }
            Chips { id: edgeChips; spec: root.edgeSpec; width: edge.width; anchors.bottom: parent.bottom }
        }
    }

    // The area's lead range as a large dot scrubber: click or drag along it; its value reads in the caption.
    Component {
        id: rangeWidget
        Item {
            id: range
            readonly property var spec: root.rangeSpec
            readonly property real lo: Number(range.spec?.min ?? 0)
            readonly property real hi: Number(range.spec?.max ?? 1)
            readonly property real step: Number(range.spec?.step ?? 1)
            readonly property real value: { Config.revision; return Number.isFinite(root.rangeDragged) ? root.rangeDragged : Number(IrisOptions.currentValue(range.spec)) }
            readonly property int dots: root.windowed ? 13 : 17
            readonly property real fraction: range.hi > range.lo ? Math.max(0, Math.min(1, (range.value - range.lo) / (range.hi - range.lo))) : 0
            readonly property int knob: Math.round(range.fraction * (range.dots - 1))
            function valueAt(x: real): real {
                const f = Math.max(0, Math.min(1, x / scrub.width))
                const raw = range.lo + f * (range.hi - range.lo)
                const snapped = range.lo + Math.round((raw - range.lo) / range.step) * range.step
                return Number(Math.max(range.lo, Math.min(range.hi, snapped)).toFixed(4))
            }
            MouseArea {
                id: scrub
                anchors.verticalCenter: parent.verticalCenter
                width: range.width
                height: root.u(48)
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                Accessible.role: Accessible.Slider
                Accessible.name: Translation.tr(String(range.spec?.label ?? ""))
                onPressed: mouse => root.rangeDragged = range.valueAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) root.rangeDragged = range.valueAt(mouse.x) }
                onReleased: { IrisOptions.commit(range.spec, root.rangeDragged); root.rangeDragged = NaN }
                onCanceled: root.rangeDragged = NaN
                Repeater {
                    model: range.dots
                    Rectangle {
                        required property int index
                        readonly property bool here: index === range.knob
                        readonly property real size: root.u(here ? 22 : index < range.knob ? 11 : 9)
                        x: Math.round(index / (range.dots - 1) * (scrub.width - root.u(22)) + root.u(11) - size / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: size
                        height: size
                        radius: size / 2
                        color: here ? IrisStyle.danger : index < range.knob ? IrisStyle.text : root.dim
                        Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
            }
        }
    }

    // The area's shapes as tiles, the taken one the ink; a short choice under them as keys.
    Component {
        id: tilesWidget
        Item {
            id: tiles
            readonly property var current: { Config.revision; return root.tileSpec ? IrisOptions.currentValue(root.tileSpec) : null }
            readonly property var choices: root.tileSpec ? IrisOptions.choicesOf(root.tileSpec) : []
            Row {
                id: tileRow
                y: 0
                width: tiles.width
                spacing: root.u(10)
                Repeater {
                    model: tiles.choices
                    MouseArea {
                        id: shape
                        required property var modelData
                        readonly property bool on: IrisOptions.same(shape.modelData.value, tiles.current)
                        width: (tileRow.width - (tiles.choices.length - 1) * tileRow.spacing) / tiles.choices.length
                        height: root.shapeHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: shapeName.text
                        Accessible.checked: shape.on
                        onClicked: IrisOptions.commit(root.tileSpec, shape.modelData.value)
                        Rectangle {
                            anchors.fill: parent
                            radius: root.u(root.windowed ? 16 : 20)
                            color: shape.on ? IrisStyle.text : shape.containsMouse ? IrisStyle.fillHover : "transparent"
                            border.width: shape.on ? 0 : 1
                            border.color: IrisStyle.hairlineStrong
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        }
                        // Side by side when the tile is wide, the mark over its name when it is not.
                        Grid {
                            readonly property bool wide: shape.width >= root.u(124)
                            anchors.centerIn: parent
                            columns: wide ? 2 : 1
                            columnSpacing: root.u(8)
                            rowSpacing: root.u(6)
                            horizontalItemAlignment: Grid.AlignHCenter
                            verticalItemAlignment: Grid.AlignVCenter
                            MaterialSymbol {
                                visible: String(shape.modelData.glyph ?? "").length > 0
                                text: String(shape.modelData.glyph ?? "")
                                iconSize: root.u(20)
                                color: shape.on ? IrisStyle.surfaceOpaque : IrisStyle.muted
                            }
                            IrisText {
                                id: shapeName
                                width: Math.min(implicitWidth, shape.width - root.u(parent.wide ? 40 : 10))
                                elide: Text.ElideRight
                                text: Translation.tr(String(shape.modelData.label ?? ""))
                                color: shape.on ? IrisStyle.surfaceOpaque : IrisStyle.muted
                                font.family: IrisStyle.fontMono
                                font.pixelSize: IrisStyle.typeCaption
                                font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.12)
                            }
                        }
                    }
                }
            }
            IrisText {
                id: chipCap
                visible: root.chipSpec !== null
                anchors.bottom: tileChips.top
                anchors.bottomMargin: root.u(10)
                text: Translation.tr(String(root.chipSpec?.label ?? ""))
                color: IrisStyle.muted
                font.family: IrisStyle.fontMono
                font.pixelSize: IrisStyle.typeCaption
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.16)
            }
            Chips { id: tileChips; visible: root.chipSpec !== null; spec: root.chipSpec; width: tiles.width; anchors.bottom: parent.bottom }
        }
    }

    // The area's note on a red dot with what fixes it; the Dock's pinned apps in grey, the one gone ringed in red.
    Component {
        id: pinsWidget
        Item {
            id: pinned
            readonly property var note: root.notes[0] ?? null
            readonly property var apps: { Config.revision; return root.pins ? (Config.options?.dock?.pinnedApps ?? []).map(String) : [] }
            Row {
                id: noteLine
                visible: pinned.note !== null
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(12)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.u(7); height: width; radius: width / 2; color: IrisStyle.danger }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, pinned.width - pinRow.width - root.u(200))
                    elide: Text.ElideRight
                    text: String(pinned.note?.text ?? "")
                    color: IrisStyle.text
                    font.family: IrisStyle.fontMono
                    font.pixelSize: IrisStyle.typeCaption
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.08)
                }
                Repeater {
                    model: pinned.note ? (pinned.note.app ? ["Unpin", "Show"] : ["Show"]) : []
                    MouseArea {
                        id: fix
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: fixText.implicitWidth + root.u(24)
                        height: root.u(28)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: fixText.text
                        onClicked: {
                            if (fix.modelData === "Unpin") Config.setNestedValue("dock.pinnedApps", pinned.apps.filter(id => id !== String(pinned.note.app)))
                            else root.host.landOn(String(pinned.note.path))
                        }
                        Rectangle { anchors.fill: parent; radius: height / 2; color: fix.containsMouse ? IrisStyle.fillHover : "transparent"; border.width: 1; border.color: IrisStyle.hairlineStrong }
                        IrisText {
                            id: fixText
                            anchors.centerIn: parent
                            text: Translation.tr(fix.modelData)
                            color: IrisStyle.text
                            font.family: IrisStyle.fontMono
                            font.pixelSize: IrisStyle.typeCaption
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.12)
                        }
                    }
                }
            }
            Row {
                id: pinRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(root.windowed ? 6 : 10)
                Repeater {
                    model: pinned.apps.slice(0, root.windowed ? 8 : 12)
                    Item {
                        id: app
                        required property string modelData
                        readonly property var who: AppSearch.appIdentity(app.modelData, "")
                        width: root.u(root.windowed ? 40 : 52)
                        height: width
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: app.who.installed ? IrisStyle.fillQuiet : "transparent"
                            border.width: app.who.installed ? 0 : Math.max(1, root.u(1.5))
                            border.color: IrisStyle.danger
                        }
                        Image {
                            id: icon
                            visible: false
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.62)
                            height: width
                            sourceSize: Qt.size(width, height)
                            source: app.who.installed ? String(app.who.icon ?? "") : ""
                            asynchronous: true
                        }
                        MultiEffect { visible: app.who.installed; anchors.fill: icon; source: icon; saturation: -1; contrast: 0.15; brightness: 0.08 }
                        MaterialSymbol { visible: !app.who.installed; anchors.centerIn: parent; text: "question_mark"; iconSize: root.u(20); color: IrisStyle.danger }
                    }
                }
                MouseArea {
                    visible: root.pins
                    width: root.u(root.windowed ? 40 : 52)
                    height: width
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Add")
                    onClicked: root.host.landOn("dock.pinnedApps")
                    Rectangle { anchors.fill: parent; radius: width / 2; color: parent.containsMouse ? IrisStyle.fillHover : "transparent"; border.width: 1; border.color: IrisStyle.hairlineStrong }
                    MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: root.u(20); color: IrisStyle.muted }
                }
            }
        }
    }

    component RoundKey: MouseArea {
        id: key
        property string glyph
        property string name
        width: root.u(40)
        height: width
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        Rectangle { anchors.fill: parent; radius: width / 2; color: key.containsMouse ? IrisStyle.fillHover : root.plate }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(19); color: IrisStyle.text }
    }
}
