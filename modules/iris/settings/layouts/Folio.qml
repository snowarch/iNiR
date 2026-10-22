pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.settings
import qs.modules.iris.settings.layouts.folio as Skins // so Quickshell mirrors the skins IrisSkin loads by url

// Folio (Pliego): Settings read as a printed sheet. The areas are a rail of words with the open one set large and the
// others fading out to both sides, a ruler of every area under it in its clusters; the left of the sheet is the area's
// plate (its live stage), what the area holds said in one paragraph and what changed from its defaults; the right is the
// engine's rows, numbered by group. Notes ride the rail as red superscripts and the ruler as red ticks.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: root.width
    readonly property real need: 0
    readonly property string voice: "folio"
    readonly property bool ownsStage: true
    // The sheet is read whole, its groups numbered down the page: no list of groups to open one by one.
    readonly property bool readsWhole: true

    readonly property bool compact: root.width < root.u(1300)
    readonly property real pad: root.u(root.compact ? 28 : 34)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var notes: root.host?.notesHere ?? []
    readonly property int noteTotal: {
        const counts = root.host?.noteCounts ?? {}
        return Object.keys(counts).reduce((sum, id) => sum + Number(counts[id] ?? 0), 0)
    }
    readonly property var clusterNames: root.host?.clusterNames ?? []
    function clusterName(index: int): string { return Translation.tr(String(root.clusterNames[index] ?? "")) }
    readonly property color err: IrisStyle.danger

    // ── The head: where you are, the layouts, the search, the notes, the way out.
    RowLayout {
        id: head
        x: root.pad
        y: root.u(20)
        width: root.width - 2 * root.pad
        height: root.u(38)
        spacing: root.u(12)
        IrisText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            textFormat: Text.StyledText
            font.family: IrisStyle.fontMono
            font.pixelSize: IrisStyle.typeFootnote
            font.letterSpacing: Math.round(IrisStyle.typeFootnote * 0.16)
            font.capitalization: Font.AllUppercase
            color: IrisStyle.textTertiary
            readonly property var cluster: root.sections[root.current]?.cluster ?? 0
            text: Translation.tr("Settings") + "  /  <font color='" + IrisStyle.subtext + "'>"
                + String(Number(root.sections[root.current]?.cluster ?? 0) + 1).padStart(2, "0") + " " + root.clusterName(Number(root.sections[root.current]?.cluster ?? 0))
                + "</font>  /  <font color='" + IrisStyle.subtext + "'>" + Translation.tr(String(root.area.title ?? "")) + "</font>"
        }
        LayoutSwitch { host: root.host; voice: "folio"; compact: root.compact }
        Item {
            id: searchSlot
            Layout.preferredWidth: root.u(root.compact ? 220 : 300)
            Layout.preferredHeight: root.u(36)
        }
        MouseArea {
            id: notePill
            visible: root.noteTotal > 0
            Layout.preferredHeight: root.u(36)
            Layout.preferredWidth: noteRow.implicitWidth + root.u(28)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: noteLabel.text
            onClicked: root.host.openNote()
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.err.r, root.err.g, root.err.b, notePill.containsMouse ? 0.22 : 0.14)
            }
            Row {
                id: noteRow
                anchors.centerIn: parent
                spacing: root.u(8)
                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "error"; iconSize: root.u(17); color: root.err }
                IrisText {
                    id: noteLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.noteTotal === 1 ? Translation.tr("1 note") : Translation.tr("%1 notes").arg(root.noteTotal)
                    color: IrisStyle.text
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: Font.Medium
                }
            }
        }
        RoundKey {
            glyph: root.host?.windowed ? "layers" : "web_asset"
            name: root.host?.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
            onClicked: root.host.switchHost()
        }
        RoundKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
    }

    // ── The rail: every area as a word, the open one large and centred; the ends fade into the sheet. The wheel or a
    // drag reads along it; left alone a moment it comes back to the open area.
    Flickable {
        id: rail
        anchors.top: head.bottom
        anchors.topMargin: root.u(6)
        x: root.pad
        width: root.width - 2 * root.pad
        height: root.u(root.compact ? 70 : 84)
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: words.width + rail.width
        contentHeight: rail.height
        readonly property real big: root.u(root.compact ? 44 : 54)
        readonly property real small: root.u(21)
        readonly property real base: Math.round(rail.height * 0.72)
        readonly property real want: words.chosen ? Math.round(words.chosen.x + words.chosen.width / 2) : 0
        onWantChanged: if (!rail.moving && !railRest.running) railSettle.restart()
        onContentWidthChanged: if (!rail.moving && !railRest.running) railSettle.restart()
        onWidthChanged: if (!rail.moving && !railRest.running) railSettle.restart()
        onMovementEnded: railRest.restart()
        Component.onCompleted: rail.contentX = rail.want
        NumberAnimation { id: railSettle; target: rail; property: "contentX"; to: rail.want; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        Timer { id: railRest; interval: 1600; onTriggered: railSettle.restart() }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y !== 0 ? event.pixelDelta.y
                    : (event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y) / 120 * root.u(90)
                railSettle.stop()
                rail.contentX = Math.max(0, Math.min(rail.contentWidth - rail.width, rail.contentX - delta))
                railRest.restart()
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: railMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        Row {
            id: words
            x: Math.round(rail.width / 2)
            spacing: root.u(root.compact ? 26 : 34)
            height: rail.height
            // itemAt() never says when the Repeater fills in, so a bound `chosen` stayed null and the rail sat at 0.
            property Item chosen: null
            Repeater {
                id: wordRepeater
                model: root.sections
                MouseArea {
                    id: word
                    required property var modelData
                    required property int index
                    readonly property int distance: Math.abs(word.index - root.current)
                    readonly property bool chosen: word.distance === 0 && !(root.host?.searching ?? false)
                    readonly property bool here: word.distance === 0
                    onHereChanged: if (word.here) words.chosen = word
                    Component.onCompleted: if (word.here) words.chosen = word
                    readonly property int noted: Number(root.host?.noteCounts?.[word.modelData.id] ?? 0)
                    readonly property bool found: !(root.host?.searching ?? false) || (root.host?.matchedSections?.has(word.modelData.id) ?? false)
                    width: wordText.implicitWidth + (word.noted > 0 ? sup.implicitWidth + root.u(3) : 0)
                    height: rail.height
                    opacity: !word.found ? 0.14 : word.chosen ? 1 : word.distance <= 1 ? 0.66 : word.distance === 2 ? 0.46 : 0.32
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: wordText.text
                    onClicked: { railRest.stop(); root.host.selectSection(word.modelData.id) }
                    IrisText {
                        id: wordText
                        y: rail.base - wordText.baselineOffset
                        text: Translation.tr(String(word.modelData.title ?? ""))
                        color: word.chosen || word.containsMouse ? IrisStyle.text : IrisStyle.subtext
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: word.chosen ? rail.big : rail.small
                        font.weight: word.chosen ? Font.DemiBold : Font.Normal
                        font.letterSpacing: word.chosen ? -Math.round(rail.big * 0.02) : 0
                    }
                    IrisText {
                        id: sup
                        visible: word.noted > 0
                        x: wordText.width + root.u(3)
                        y: rail.base - (word.chosen ? rail.big : rail.small) * 0.72
                        text: String(word.noted)
                        color: root.err
                        font.family: IrisStyle.fontMono
                        font.pixelSize: IrisStyle.typeFootnote
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: word.chosen
                        anchors.horizontalCenter: wordText.horizontalCenter
                        y: rail.base + root.u(7)
                        width: root.u(6)
                        height: width
                        radius: width / 2
                        color: IrisStyle.accent
                    }
                }
            }
        }
    }
    Rectangle {
        id: railMask
        visible: false
        layer.enabled: true
        width: rail.width
        height: rail.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.16; color: "white" }
            GradientStop { position: 0.84; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ── The ruler: one tick per area in its clusters, the open one in the accent, areas with notes in red.
    Item {
        id: ruler
        anchors.top: rail.bottom
        x: root.pad
        width: root.width - 2 * root.pad
        height: root.u(30)
        readonly property real step: ruler.width / Math.max(1, root.sections.length)
        Rectangle { width: parent.width; height: 1; color: IrisStyle.hairline }
        Repeater {
            model: root.sections
            Item {
                id: tick
                required property var modelData
                required property int index
                readonly property bool starts: tick.index === 0 || root.sections[tick.index - 1]?.cluster !== tick.modelData.cluster
                readonly property bool chosen: tick.index === root.current
                readonly property bool noted: Number(root.host?.noteCounts?.[tick.modelData.id] ?? 0) > 0
                x: Math.round((tick.index + 0.5) * ruler.step)
                Rectangle {
                    x: tick.chosen ? -1 : 0
                    width: tick.chosen ? 3 : 1
                    height: root.u(tick.chosen ? 16 : tick.starts ? 12 : 7)
                    radius: tick.chosen ? 1.5 : 0
                    color: tick.chosen ? IrisStyle.accent : tick.noted ? root.err
                        : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, tick.starts ? 0.44 : 0.22)
                }
                IrisText {
                    visible: tick.starts && !(root.compact && Number(tick.modelData.cluster) >= 5)
                    x: -Math.round(ruler.step / 2) + root.u(4)
                    y: root.u(14)
                    text: root.clusterName(Number(tick.modelData.cluster))
                    color: Number(tick.modelData.cluster) === Number(root.sections[root.current]?.cluster ?? -1) ? IrisStyle.subtext : IrisStyle.textTertiary
                    font.family: IrisStyle.fontMono
                    font.pixelSize: Math.max(9, IrisStyle.typeCaption - 1)
                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.16)
                    font.capitalization: Font.AllUppercase
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const at = Math.max(0, Math.min(root.sections.length - 1, Math.floor(mouse.x / ruler.step)))
                root.host.selectSection(root.sections[at].id)
            }
        }
    }

    // ── The sheet: the plate and what the area says on the left, the rows on the right.
    Item {
        id: body
        anchors.top: ruler.bottom
        anchors.topMargin: root.u(14)
        anchors.bottom: parent.bottom
        x: root.pad
        width: root.width - 2 * root.pad
        readonly property real gap: root.u(root.compact ? 28 : 40)

        // The left of the sheet scrolls on its own when the plate, the sentence and the changes outgrow it.
        Flickable {
            id: leftFlick
            width: Math.round(body.width * (root.compact ? 0.40 : 0.43))
            height: body.height - root.u(14)
            contentHeight: left.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: IrisScrollBar {}
        ColumnLayout {
            id: left
            width: leftFlick.width
            spacing: root.u(root.compact ? 16 : 22)

            // The plate: the area's live stage on a drafting grid.
            Rectangle {
                id: plate
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Math.min(root.u(root.compact ? 300 : 430), leftFlick.height * 0.62))
                radius: IrisStyle.radiusSheet
                color: IrisStyle.readingCard
                border.width: 1
                border.color: IrisStyle.hairline
                clip: true
                Canvas {
                    id: grid
                    anchors.fill: parent
                    opacity: 0.05
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = IrisStyle.text
                        ctx.lineWidth = 1
                        const cell = Math.round(24 * root.d)
                        ctx.beginPath()
                        for (let x = 0.5; x < width; x += cell) { ctx.moveTo(x, 0); ctx.lineTo(x, height) }
                        for (let y = 0.5; y < height; y += cell) { ctx.moveTo(0, y); ctx.lineTo(width, y) }
                        ctx.stroke()
                    }
                }
                IrisText {
                    id: plateCap
                    x: root.u(18)
                    y: root.u(14)
                    textFormat: Text.StyledText
                    text: Translation.tr("Plate") + "  <font color='" + IrisStyle.subtext + "'>" + Translation.tr(String(root.area.title ?? "")) + "</font>  ·  " + Translation.tr("Live")
                    color: IrisStyle.textTertiary
                    font.family: IrisStyle.fontMono
                    font.pixelSize: IrisStyle.typeCaption
                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.18)
                    font.capitalization: Font.AllUppercase
                }
                IrisGroupPreview {
                    id: stage
                    anchors.fill: parent
                    anchors.topMargin: root.u(38)
                    anchors.leftMargin: root.u(18)
                    anchors.rightMargin: root.u(18)
                    anchors.bottomMargin: (plateNote.visible ? root.u(40) : root.u(18)) + (callouts.visible ? root.u(34) : 0) // never on the side picked: that reads the stage's size back
                    visible: stage.available
                    standIn: true
                    section: root.host?.searching ? "" : root.section
                    group: String(root.host?.leadGroup ?? "")
                }
                // An area without a stage shows its mark and what it is for.
                Column {
                    visible: !stage.available
                    anchors.centerIn: parent
                    spacing: root.u(10)
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(root.area.icon ?? "settings")
                        iconSize: root.u(54)
                        color: IrisStyle.subtext
                    }
                    IrisText {
                        width: plate.width - root.u(60)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: Translation.tr(String(root.area.subtitle ?? ""))
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeLabel
                    }
                }
                // Callouts printed beside what they measure: a rule along the stage's subject, the values on the side
                // with room (over a piece at the bottom, under one at the top). A stage with no subject sets them in a
                // line in the plate's margin under it, never over the scene's own caption.
                Item {
                    id: callouts
                    readonly property rect at: stage.subject
                    // The side of the subject with room for the notes: its long sides first (a tall or small piece is read
                    // from beside it), then the others; none with room and they go to the plate's margin.
                    readonly property string side: {
                        const r = callouts.at
                        if (r.width <= 0) return ""
                        const needW = root.u(240), needH = calloutList.count * root.u(26) + root.u(20) // never the grid's own size: its columns follow the side
                        const room = { top: r.y, bottom: stage.height - r.y - r.height, left: r.x, right: stage.width - r.x - r.width }
                        const across = r.height > r.width * 1.4 || r.width < stage.width * 0.3
                        const lr = room.left > room.right ? ["left", "right"] : ["right", "left"]
                        const tb = room.top > room.bottom ? ["top", "bottom"] : ["bottom", "top"]
                        return (across ? lr.concat(tb) : tb.concat(lr)).find(side => room[side] >= (side === "left" || side === "right" ? needW : needH)) ?? ""
                    }
                    readonly property bool pinned: callouts.side.length > 0
                    readonly property bool vertical: callouts.side === "left" || callouts.side === "right"
                    readonly property bool over: callouts.side === "top"
                    readonly property bool leftOf: callouts.side === "left"
                    visible: stage.available && !(root.host?.searching ?? false) && calloutList.count > 0
                    x: stage.x
                    y: stage.y
                    width: stage.width
                    height: stage.height
                    z: 2
                    // The rule: as long as the subject, a tick at each end, set off it by the gap.
                    Item {
                        id: rule
                        visible: callouts.pinned
                        readonly property real off: root.u(6)
                        x: callouts.vertical ? (callouts.leftOf ? callouts.at.x - rule.off - 1 : callouts.at.x + callouts.at.width + rule.off) : callouts.at.x
                        y: callouts.vertical ? callouts.at.y : (callouts.over ? callouts.at.y - rule.off - 1 : callouts.at.y + callouts.at.height + rule.off)
                        width: callouts.vertical ? 1 : callouts.at.width
                        height: callouts.vertical ? callouts.at.height : 1
                        Rectangle { anchors.fill: parent; color: IrisStyle.accent; opacity: 0.8 }
                        Rectangle { x: callouts.vertical ? -root.u(3) : 0; y: callouts.vertical ? 0 : -root.u(3); width: callouts.vertical ? root.u(7) : 1; height: callouts.vertical ? 1 : root.u(7); color: IrisStyle.accent }
                        Rectangle { x: callouts.vertical ? -root.u(3) : parent.width - 1; y: callouts.vertical ? parent.height - 1 : -root.u(3); width: callouts.vertical ? root.u(7) : 1; height: callouts.vertical ? 1 : root.u(7); color: IrisStyle.accent }
                    }
                    Grid {
                        id: calloutColumn
                        columns: callouts.pinned ? 1 : 2
                        rowSpacing: root.u(4)
                        columnSpacing: root.u(10)
                        readonly property real wantX: !callouts.pinned ? 0
                            : callouts.vertical ? (callouts.leftOf ? rule.x - root.u(8) - calloutColumn.width : rule.x + root.u(8))
                            : rule.x
                        readonly property real wantY: !callouts.pinned ? callouts.height + root.u(9)
                            : callouts.vertical ? rule.y + rule.height / 2 - calloutColumn.height / 2
                            : callouts.over ? rule.y - root.u(6) - calloutColumn.height : rule.y + root.u(6)
                        x: !callouts.pinned ? 0 : Math.round(Math.max(root.u(6), Math.min(callouts.width - calloutColumn.width - root.u(6), calloutColumn.wantX)))
                        y: !callouts.pinned ? calloutColumn.wantY : Math.round(Math.max(root.u(6), Math.min(callouts.height - calloutColumn.height - root.u(6), calloutColumn.wantY)))
                        Repeater {
                            id: calloutList
                            model: (root.host?.tellingRows(6, "") ?? []).filter(spec => spec.kind !== "switch" && root.answer(spec).split(" ").length <= 2).slice(0, 2)
                            Rectangle {
                                required property var modelData
                                width: callout.implicitWidth + root.u(14)
                                height: callout.implicitHeight + root.u(8)
                                radius: root.u(4)
                                color: Qt.rgba(IrisStyle.surfaceOpaque.r, IrisStyle.surfaceOpaque.g, IrisStyle.surfaceOpaque.b, 0.82)
                                border.width: 1
                                border.color: Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.5)
                                IrisText {
                                    id: callout
                                    anchors.centerIn: parent
                                    textFormat: Text.StyledText
                                    text: Translation.tr(String(parent.modelData.label ?? "")) + "  <font color='" + IrisStyle.accent + "'>" + root.answer(parent.modelData) + "</font>"
                                    color: IrisStyle.subtext
                                    font.family: IrisStyle.fontMono
                                    font.pixelSize: IrisStyle.typeCaption
                                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.14)
                                    font.capitalization: Font.AllUppercase
                                }
                            }
                        }
                    }
                }
                IrisText {
                    id: plateNote
                    visible: root.notes.length > 0
                    x: root.u(18)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.u(14)
                    width: parent.width - root.u(36)
                    elide: Text.ElideRight
                    text: (root.notes.length === 1 ? Translation.tr("1 note") : Translation.tr("%1 notes").arg(root.notes.length)) + "  ·  " + String(root.notes[0]?.text ?? "")
                    color: root.err
                    font.family: IrisStyle.fontMono
                    font.pixelSize: IrisStyle.typeCaption
                    font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.12)
                    font.capitalization: Font.AllUppercase
                }
            }

            // What the area holds, said once as a sentence: its most telling values, each a link that lands on its row.
            IrisText {
                id: say
                Layout.fillWidth: true
                visible: !(root.host?.searching ?? false) && text.length > 0
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                color: IrisStyle.subtext
                font.family: IrisStyle.fontTitle
                font.pixelSize: root.u(root.compact ? 19 : 23)
                lineHeight: 1.28
                text: {
                    // One that ends on a bare verb ("Media bubble opens", "Tray bubble rests") has no way into the sentence.
                    const bare = spec => /\s(opens|rests|sits|stays|follows|shows|hides|starts|moves|lives|appears|closes|keeps|leads|lands|goes)$/i.test(String(spec.label ?? ""))
                        // and so does an order ("Turn the screen off after"): only "Opens as" reads as "it opens as".
                        || (/\s(as|at|on|in|to|by|from|with|for|into|after|before|under|over)$/i.test(String(spec.label ?? "")) && !/^\S+s\s/.test(String(spec.label ?? "")))
                    const rows = (root.host?.tellingRows(8, "") ?? []).filter(spec => spec.kind === "switch" || (!bare(spec) && root.answer(spec).split(" ").length <= 2)).slice(0, root.compact ? 3 : 4)
                    if (rows.length === 0) return ""
                    const esc = value => String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    const area = Translation.tr(String(root.area.title ?? ""))
                    const link = (spec, words) => "<a style='text-decoration:none; color:" + (IrisOptions.modified(spec) ? IrisStyle.accent : IrisStyle.text)
                        + "; font-weight:500' href='" + encodeURIComponent(String(spec.path)) + "'>" + esc(words) + "</a>"
                    const list = parts => parts.length === 1 ? parts[0]
                        : Translation.tr("%1 and %2").arg(parts.slice(0, -1).reduce((all, part) => Translation.tr("%1, %2").arg(all).arg(part))).arg(parts[parts.length - 1])
                    const on = spec => { const value = IrisOptions.currentValue(spec); return spec.invert ? !value : !!value }
                    // Values are said with their names, switches by name alone, grouped by on and off.
                    const clauses = []
                    // A value that is itself a phrase ("Keep pinned place") never reads mid-sentence: it is left to its row.
                    const twins = root.twins(rows)
                    const named = spec => root.inline(root.named(spec, area, twins))
                    // A label that ends on its preposition ("Opens as") is a verb: "it opens as a sheet", never "the opens as are".
                    const verb = spec => /\s(as|at|on|in|to|by|from|with|for|into|after|before|under|over)$/i.test(String(spec.label ?? ""))
                    const values = rows.filter(spec => spec.kind !== "switch" && root.answer(spec).split(" ").length <= 2)
                        .map(spec => Translation.tr(verb(spec) ? "it %1 %2" : /[^su]s$/.test(String(spec.label ?? "")) ? "the %1 are %2" : "the %1 is %2").arg(esc(named(spec))).arg(link(spec, root.inline(root.answer(spec)))))
                    if (values.length > 0) clauses.push(list(values))
                    const lit = rows.filter(spec => spec.kind === "switch" && on(spec)).map(spec => link(spec, named(spec)))
                    if (lit.length > 0) clauses.push(Translation.tr("with %1 on").arg(list(lit)))
                    const dark = rows.filter(spec => spec.kind === "switch" && !on(spec)).map(spec => link(spec, named(spec)))
                    if (dark.length > 0) clauses.push(Translation.tr("%1 off").arg(list(dark)))
                    return Translation.tr("In %1, %2.").arg(esc(area)).arg(clauses.reduce((all, part) => Translation.tr("%1, %2").arg(all).arg(part)))
                }
                onLinkActivated: link => root.host.landOn(decodeURIComponent(link))
                HoverHandler { cursorShape: say.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }

            // What changed here from the defaults, and what can be done to the page.
            Rectangle {
                id: changes
                readonly property var rows: {
                    Config.revision
                    return (root.host?.entries ?? []).filter(spec => spec.path && IrisOptions.modified(spec)).slice(0, root.compact ? 2 : 3)
                }
                visible: !(root.host?.searching ?? false) && (changes.rows.length > 0 || (root.host?.pageActions?.length ?? 0) > 0)
                Layout.fillWidth: true
                Layout.preferredHeight: changesRow.implicitHeight + root.u(24)
                radius: IrisStyle.radiusTile
                color: IrisStyle.fillQuiet
                border.width: 1
                border.color: IrisStyle.hairline
                Flow {
                    id: changesRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.u(16)
                    anchors.rightMargin: root.u(12)
                    spacing: root.u(14)
                    IrisText {
                        height: root.u(28)
                        verticalAlignment: Text.AlignVCenter
                        text: changes.rows.length > 0 ? Translation.tr("Changed") : Translation.tr("Defaults")
                        color: IrisStyle.textTertiary
                        font.family: IrisStyle.fontMono
                        font.pixelSize: IrisStyle.typeCaption
                        font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.18)
                        font.capitalization: Font.AllUppercase
                    }
                    Repeater {
                        model: changes.rows
                        MouseArea {
                            id: change
                            required property var modelData
                            width: changeText.implicitWidth
                            height: root.u(28)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.scrollToGroup(Translation.tr(String(change.modelData.group ?? "")))
                            IrisText {
                                id: changeText
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.StyledText
                                text: root.named(change.modelData, "", root.twins(changes.rows)) + "  <font color='" + IrisStyle.textTertiary + "'><s>" + root.fallbackOf(change.modelData) + "</s>  →</font>  " + root.answer(change.modelData)
                                color: IrisStyle.subtext
                                font.pixelSize: IrisStyle.typeLabel
                            }
                        }
                    }
                    Repeater {
                        model: root.host?.pageActions ?? []
                        MouseArea {
                            id: act
                            required property var modelData
                            width: actRow.implicitWidth + root.u(16)
                            height: root.u(28)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: String(act.modelData.label ?? "")
                            onClicked: act.modelData.clicked()
                            Rectangle { anchors.fill: parent; radius: height / 2; color: act.containsMouse ? IrisStyle.fillHover : "transparent" }
                            Row {
                                id: actRow
                                anchors.centerIn: parent
                                spacing: root.u(6)
                                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: String(act.modelData.glyph ?? ""); iconSize: root.u(16); color: IrisStyle.text }
                                IrisText { anchors.verticalCenter: parent.verticalCenter; text: String(act.modelData.label ?? ""); color: IrisStyle.text; font.pixelSize: IrisStyle.typeLabel }
                            }
                        }
                    }
                }
            }
        }
        }

        // The rows, on a reading plate over glass: the backdrop never reaches the type.
        Rectangle {
            id: sheet
            x: left.width + body.gap
            width: body.width - x
            height: body.height - root.u(14)
            radius: IrisStyle.radiusSheet
            color: IrisStyle.glassy ? IrisStyle.readingSidebar : "transparent"
            Item {
                id: rowsSlot
                anchors.fill: parent
                anchors.leftMargin: IrisStyle.glassy ? root.u(6) : -root.u(12)
                anchors.rightMargin: IrisStyle.glassy ? root.u(6) : -root.u(12)
                anchors.topMargin: IrisStyle.glassy ? root.u(6) : 0
            }
        }
    }

    function answer(spec: var): string { return root.host.answerOf(spec) }
    // The value a row ships with, said as its answer is.
    function fallbackOf(spec: var): string {
        const value = spec.fallback
        if (spec.kind === "switch") return (spec.invert ? !value : !!value) ? Translation.tr("On") : Translation.tr("Off")
        if (spec.kind === "range") return Translation.tr(IrisOptions.rangeText(spec, value))
        const choice = IrisOptions.choicesOf(spec).find(entry => IrisOptions.same(entry.value, value))
        return choice ? Translation.tr(String(choice.label ?? "")) : String(value ?? "")
    }

    // A row's name inside its own area drops the area's name: "Dock notch" in Dock is the notch.
    // Two groups may hold a row of the same name (Side Panels' two "Alignment"s): those are said with their group.
    function twins(rows: var): var {
        const seen = {}
        for (const spec of rows) { const key = String(spec.label ?? ""); seen[key] = (seen[key] ?? 0) + 1 }
        return Object.keys(seen).filter(key => seen[key] > 1)
    }
    function named(spec: var, area: string, twins: var): string {
        const label = Translation.tr(String(spec.label ?? ""))
        if ((twins ?? []).includes(String(spec.label ?? "")) && spec.group)
            return Translation.tr(String(spec.group)) + " " + root.inline(label)
        return area.length > 0 && label.toLowerCase().startsWith(area.toLowerCase() + " ") ? label.slice(area.length + 1) : label
    }
    // A label or a value read mid-sentence: "Icon size" becomes "icon size"; names and acronyms ("GPU", "Wi-Fi") keep
    // their case, and so does German, where every noun is capitalised.
    function inline(text: string): string {
        if (Translation.languageCode.startsWith("de") || text.length < 2) return text
        const second = text.charAt(1)
        // A name set in title case ("Do Not Disturb") keeps it too.
        if (second !== second.toLocaleLowerCase() || /[A-Z]/.test(text.slice(1).split(" ")[0]) || /\s[A-Z]/.test(text)) return text
        return text.charAt(0).toLocaleLowerCase() + text.slice(1)
    }

    component RoundKey: MouseArea {
        id: key
        property string glyph
        property string name
        Layout.preferredWidth: root.u(36)
        Layout.preferredHeight: root.u(36)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: key.containsMouse ? IrisStyle.fillQuiet : "transparent"
            border.width: 1
            border.color: IrisStyle.hairline
        }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.subtext }
    }
}
