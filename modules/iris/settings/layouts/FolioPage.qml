pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.settings

// One area as Folio prints it, built once and kept by Folio's AreaPool: its title and sentence across, its live stage
// held still on the left with what it shows and the area's contents under it, its groups on a sheet to the right.
// The rows scroll as Classic's do (a wheel over them that glided head to head stuttered and kept the wheel from
// their sliders, 10-25); the stage follows the group being read.
Item {
    id: page
    required property string area
    property Item host
    property real shift: 0
    transform: Translate { y: page.shift }

    readonly property real d: Number(page.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * page.d) }
    readonly property bool compact: page.width < page.u(900)
    readonly property var entry: IrisOptions.sectionById(page.area) ?? ({})
    // The page in front: only then do writes reach its rows and its stage plays.
    readonly property bool live: page.visible && page.area === String(page.host?.section ?? "")
    readonly property bool whole: rows.whole

    Column {
        id: title
        width: page.width
        spacing: page.u(4)
        IrisText {
            width: parent.width
            elide: Text.ElideRight
            text: Translation.tr(String(page.entry.title ?? ""))
            color: IrisStyle.text
            font.family: IrisStyle.fontTitle
            font.pixelSize: page.u(26)
            font.weight: IrisStyle.weight(Font.DemiBold)
            font.letterSpacing: -Math.round(page.u(26) * 0.01)
        }
        IrisText {
            width: parent.width
            elide: Text.ElideRight
            text: Translation.tr(String(page.entry.subtitle ?? ""))
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeBody
        }
    }

    Item {
        id: areaBox
        y: title.height + page.u(18)
        width: page.width
        height: page.height - y
        readonly property bool staged: stage.available
        readonly property real gap: page.u(page.compact ? 18 : 24)

        ClippingRectangle {
            id: plate
            visible: areaBox.staged
            width: Math.round(areaBox.width * (page.compact ? 0.40 : 0.42))
            height: Math.round(Math.min(areaBox.height, width * 0.78, page.u(440)))
            radius: IrisStyle.radiusSheet
            color: IrisStyle.readingCard
            border.width: 1
            border.color: IrisStyle.hairline
            IrisGroupPreview {
                id: stage
                anchors.fill: parent
                anchors.margins: page.u(12)
                radius: Math.max(IrisStyle.radiusRow, IrisStyle.radiusSheet - page.u(12))
                standIn: true
                captionOutside: true
                playing: page.live
                // Home leads with the welcome over its rows, so its rows get the width.
                section: page.area === "general" ? "" : page.area
                niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                niriRevision: IrisNiri.revision
                group: page.stageGroup
            }
        }

        // Under the stage: what it shows now, what can be done to the area, then the area at a glance.
        Column {
            id: underStage
            visible: areaBox.staged
            y: plate.height + page.u(14)
            width: plate.width
            spacing: page.u(14)
            IrisText {
                visible: stage.caption.length > 0
                x: page.u(4)
                width: parent.width - x
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: stage.caption
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
            Flow {
                width: plate.width
                spacing: page.u(6)
                Repeater {
                    model: page.live ? (page.host?.pageActions ?? []) : []
                    MouseArea {
                        id: act
                        required property var modelData
                        width: actRow.implicitWidth + page.u(22)
                        height: page.u(32)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: String(act.modelData.label ?? "")
                        onClicked: act.modelData.clicked()
                        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: act.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
                        Row {
                            id: actRow
                            anchors.centerIn: parent
                            spacing: page.u(6)
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: String(act.modelData.glyph ?? ""); iconSize: page.u(16); color: IrisStyle.text }
                            IrisText { anchors.verticalCenter: parent.verticalCenter; text: String(act.modelData.label ?? ""); color: IrisStyle.text; font.pixelSize: IrisStyle.typeMeta }
                        }
                    }
                }
            }
            // The area's groups as a book's contents, the one being read marked: a click glides the sheet to it
            // (SekaiPop's jump chips). An "at a glance" of values stood here and said again what the sheet beside it says.
            Column {
                id: contents
                readonly property var heads: rows.blocks.filter(block => String(block.caption ?? "").length > 0)
                readonly property int at: Math.max(0, contents.heads.findIndex(block => String(block.key) === page.reading))
                readonly property int fit: Math.max(0, Math.floor((areaBox.height - plate.height - page.u(150)) / page.u(32)))
                // More groups than room: the list keeps the one being read inside it.
                readonly property int from: Math.max(0, Math.min(contents.heads.length - contents.fit, contents.at - Math.floor(contents.fit / 2)))
                visible: contents.heads.length > 1 && contents.fit >= 2
                width: plate.width
                IrisText {
                    x: page.u(4)
                    bottomPadding: page.u(6)
                    text: Translation.tr("On this page")
                    color: IrisStyle.textTertiary
                    font.family: IrisStyle.fontMono
                    font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                    font.weight: IrisStyle.weight(Font.Medium)
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
                }
                Repeater {
                    model: contents.heads.slice(contents.from, contents.from + contents.fit)
                    MouseArea {
                        id: head
                        required property var modelData
                        readonly property bool on: String(head.modelData.key) === page.reading
                        width: contents.width
                        height: page.u(32)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Link
                        Accessible.name: String(head.modelData.caption)
                        onClicked: page.showGroup(String(head.modelData.key))
                        Rectangle { anchors.fill: parent; radius: IrisStyle.fieldChamfer ? 0 : page.u(10); color: head.containsMouse ? IrisStyle.fillHover : "transparent" }
                        Rectangle {
                            x: page.u(6)
                            anchors.verticalCenter: parent.verticalCenter
                            width: page.u(3)
                            height: head.on ? page.u(16) : page.u(6)
                            radius: width / 2
                            color: head.on ? IrisStyle.accent : IrisStyle.hairlineStrong
                            Behavior on height { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                        }
                        IrisText {
                            x: page.u(18)
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - page.u(6)
                            elide: Text.ElideRight
                            text: String(head.modelData.caption)
                            color: head.on ? IrisStyle.text : IrisStyle.subtext
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: IrisStyle.weight(head.on ? Font.DemiBold : Font.Normal)
                        }
                    }
                }
            }
        }

        // The groups' sheet: rows on the body in solid, on a reading fill over glass (never glass on glass).
        Rectangle {
            id: sheet
            x: areaBox.staged ? plate.width + areaBox.gap : 0
            width: areaBox.width - x
            height: areaBox.height
            radius: IrisStyle.radiusSheet
            color: IrisStyle.glassy ? IrisStyle.readingSidebar : "transparent"
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.leftMargin: IrisStyle.glassy ? page.u(6) : -page.u(12)
                anchors.rightMargin: IrisStyle.glassy ? page.u(6) : 0
                anchors.topMargin: IrisStyle.glassy ? page.u(6) : 0
                contentHeight: rows.implicitHeight + page.u(24)
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: IrisScrollBar {}
                onContentYChanged: spyPace.restart()
                AreaRows {
                    id: rows
                    width: flick.width - page.u(8)
                    section: page.area
                    host: page.host
                    voice: "folio"
                    live: page.live
                    reach: flick.contentY + flick.height * 1.5
                    groupFill: "transparent"
                    reading: page.reading
                    onReveal: row => page.reveal(row)
                }
            }
        }
    }

    // ── The group being read: the head that has reached the upper fifth (at the foot, the last one in view).
    property string reading: ""
    readonly property string stageGroup: page.reading.length > 0 && stage.sceneFor(page.area, page.reading).length > 0 ? page.reading : ""
    Timer { id: spyPace; interval: 90; onTriggered: page.spy() }
    function spy(): void {
        const targets = rows.targets()
        if (targets.length === 0) { page.reading = ""; return }
        let found = targets[0].key
        const atEnd = flick.contentY >= flick.contentHeight - flick.height - 2 && flick.contentY > 0
        if (flick.contentY >= 1) {
            for (const target of targets) {
                const top = target.item.mapToItem(flick.contentItem, 0, 0).y - flick.contentY
                if (top > flick.height * (atEnd ? 0.92 : 0.2)) break
                found = target.key
            }
        }
        page.reading = found
    }
    onLiveChanged: if (page.live) spyPace.restart()

    // Asked from outside (a link, the CLI): put a group's head at the top, or a row a third down, with one glide.
    function showGroup(wanted: string): void {
        const lower = wanted.toLowerCase()
        const target = rows.targets().find(entry => entry.key === wanted || entry.key.toLowerCase() === lower
            || Translation.tr(entry.key).toLowerCase() === lower)
        if (target) {
            page.waiting = ""
            page.glideTo(target.item.mapToItem(flick.contentItem, 0, 0).y - page.u(8))
        } else if (rows.builtUpTo < rows.blocks.length) {
            // A group still waiting below the fold is built first (with the rest), then shown.
            page.waiting = wanted
            rows.builtUpTo = rows.blocks.length
        } else {
            page.waiting = ""
        }
    }
    property string waiting: ""
    onWholeChanged: if (page.whole && page.waiting.length > 0) showSoon.restart()
    Timer { id: showSoon; interval: 120; onTriggered: if (page.waiting.length > 0) page.showGroup(page.waiting) }
    function reveal(row: Item): void { page.glideTo(row.mapToItem(flick.contentItem, 0, 0).y - flick.height * 0.3) }
    function glideTo(y: real): void {
        const to = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y))
        if (Math.abs(to - flick.contentY) < 1) return
        glider.from = flick.contentY
        glider.to = to
        glider.restart()
    }
    NumberAnimation { id: glider; target: flick; property: "contentY"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
}
