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

// One area as Pocket holds it, built once and kept by Pocket's AreaPool: its title large over its live stage, then its
// groups as cards down one column. The whole page scrolls as one, the way a phone's settings page does.
Item {
    id: page
    required property string area
    property Item host
    property real shift: 0
    transform: Translate { x: page.shift }

    readonly property real d: Number(page.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * page.d) }
    readonly property var entry: IrisOptions.sectionById(page.area) ?? ({})
    // The page in front: only then do writes reach its rows and its stage plays.
    readonly property bool live: page.visible && (page.area === String(page.host?.section ?? "") || page.area === "general")
    readonly property bool whole: rows.whole
    readonly property bool staged: page.area !== "general" && stage.available

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight + page.u(28)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: IrisScrollBar {}
        onContentYChanged: spyPace.restart()

        Column {
            id: column
            x: page.u(16)
            width: page.width - 2 * page.u(16)
            spacing: page.u(12)
            Column {
                width: parent.width
                topPadding: page.u(4)
                spacing: page.u(2)
                IrisText {
                    width: parent.width
                    elide: Text.ElideRight
                    // Home's own groups read as General: Home is the column you came from.
                    text: page.area === "general" ? Translation.tr("General") : Translation.tr(String(page.entry.title ?? ""))
                    color: IrisStyle.text
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: page.u(30)
                    font.weight: Font.Bold
                    font.letterSpacing: -Math.round(page.u(30) * 0.01)
                }
                IrisText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: page.area === "general" ? Translation.tr("Language, time, startup and the shell itself")
                        : Translation.tr(String(page.entry.subtitle ?? ""))
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeBody
                }
            }
            ClippingRectangle {
                visible: page.staged
                width: parent.width
                height: page.staged ? Math.round(Math.min(page.u(230), width * 0.56)) : 0
                radius: IrisStyle.radiusSheet
                color: IrisStyle.readingCard
                IrisGroupPreview {
                    id: stage
                    anchors.fill: parent
                    anchors.margins: page.u(10)
                    radius: Math.max(IrisStyle.radiusRow, IrisStyle.radiusSheet - page.u(10))
                    standIn: true
                    captionOutside: true
                    playing: page.live && page.staged
                    section: page.area === "general" ? "" : page.area
                    niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                    niriRevision: IrisNiri.revision
                    group: page.stageGroup
                }
            }
            IrisText {
                visible: page.staged && stage.caption.length > 0
                x: page.u(4)
                width: parent.width - x
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: stage.caption
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
            // What can be done to the area (rehearse, customize, restore) as capsules under its stage.
            Flow {
                width: parent.width
                spacing: page.u(6)
                visible: actions.count > 0
                Repeater {
                    id: actions
                    model: page.live && page.area !== "general" ? (page.host?.pageActions ?? []) : []
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
            AreaRows {
                id: rows
                width: parent.width
                section: page.area
                host: page.host
                voice: "pocket"
                live: page.live
                reading: page.reading
                // Home's pinned rows and welcome lead Home itself; General's page holds the rest.
                welcome: false
                skip: page.area === "general" ? ["Every day"] : []
                onReveal: row => page.reveal(row)
            }
        }
    }

    // ── The group being read: the head that has reached the upper fifth, for the stage to point at.
    property string reading: ""
    readonly property string stageGroup: page.reading.length > 0 && stage.sceneFor(page.area, page.reading).length > 0 ? page.reading : ""
    Timer { id: spyPace; interval: 90; onTriggered: page.spy() }
    function spy(): void {
        const targets = rows.targets()
        if (targets.length === 0) { page.reading = ""; return }
        let found = targets[0].key
        if (flick.contentY >= 1) {
            for (const target of targets) {
                const top = target.item.mapToItem(flick.contentItem, 0, 0).y - flick.contentY
                if (top > flick.height * 0.25) break
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
        if (target) page.glideTo(target.item.mapToItem(flick.contentItem, 0, 0).y - page.u(8))
    }
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
