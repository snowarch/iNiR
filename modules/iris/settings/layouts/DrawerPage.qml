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

// One area as Drawer lays it, built once and kept by Drawer's AreaPool: its title, sentence and live stage on a plate to
// the left (Home: the welcome), its groups set across as many columns as the drawer is wide. The groups are dealt to
// the columns in reading order, each column about as long as the others, and the columns scroll together.
Item {
    id: page
    required property string area
    property Item host
    property real shift: 0
    transform: Translate { x: page.shift }

    readonly property real d: Number(page.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * page.d) }
    readonly property var entry: IrisOptions.sectionById(page.area) ?? ({})
    readonly property bool home: page.area === "general"
    readonly property bool live: page.visible && page.area === String(page.host?.section ?? "")

    // ── The plate: the area's name, its sentence and its stage; Home's is the welcome.
    Column {
        id: plate
        // Home's welcome needs a little more than a stage to say who and how long up.
        width: Math.round(page.home ? Math.max(page.u(380), Math.min(page.u(440), page.width * 0.26))
            : Math.max(page.u(280), Math.min(page.u(360), page.width * 0.22)))
        spacing: page.u(10)
        IrisText {
            visible: !page.home
            width: parent.width
            elide: Text.ElideRight
            text: Translation.tr(String(page.entry.title ?? ""))
            color: IrisStyle.text
            font.family: IrisStyle.fontTitle
            font.pixelSize: page.u(40)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: page.u(24)
            font.weight: Font.Bold
            font.letterSpacing: -Math.round(page.u(40) * 0.015)
        }
        IrisText {
            visible: !page.home
            width: parent.width
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: Translation.tr(String(page.entry.subtitle ?? ""))
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeBody
        }
        Loader {
            active: page.home
            visible: active
            width: parent.width
            sourceComponent: IrisWallpaperCard { width: plate.width; screen: page.QsWindow.window?.screen ?? GlobalStates.focusedScreen }
        }
        ClippingRectangle {
            id: stagePlate
            readonly property bool staged: !page.home && stage.available
            visible: stagePlate.staged
            width: parent.width
            // What the drawer leaves under the words: the stage never pushes the actions out of the plate.
            height: stagePlate.staged ? Math.round(Math.max(page.u(110), Math.min(width * 0.6, page.height - y - page.u(56)))) : 0
            radius: IrisStyle.radiusSheet
            color: IrisStyle.readingCard
            IrisGroupPreview {
                id: stage
                anchors.fill: parent
                anchors.margins: page.u(10)
                radius: Math.max(IrisStyle.radiusRow, IrisStyle.radiusSheet - page.u(10))
                standIn: true
                captionOutside: true
                playing: page.live && stagePlate.staged
                section: page.home ? "" : page.area
                niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                niriRevision: IrisNiri.revision
                group: ""
            }
        }
        Flow {
            width: parent.width
            spacing: page.u(6)
            Repeater {
                model: page.live && !page.home ? (page.host?.pageActions ?? []) : []
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
    }

    // ── The columns.
    readonly property int gap: page.u(28)
    readonly property int columns: Math.max(1, Math.floor((cols.width + page.gap) / (page.u(340) + page.gap)))
    // The area's groups dealt to the columns in order, each closing once it holds its share of what is left.
    property var split: []
    function plan(): void {
        const groups = []
        for (const spec of IrisOptions.settings) {
            if (spec.section !== page.area || !IrisOptions.shown(spec)) continue
            const key = String(spec.group ?? "")
            let group = groups.find(entry => entry.key === key)
            if (!group) { group = { key: key, weight: 1.4 }; groups.push(group) }
            group.weight += IrisOptions.foldsAway(spec) ? 0.15 : spec.description ? 1.5 : 1
        }
        const count = Math.min(page.columns, Math.max(1, groups.length))
        const out = []
        let column = [], held = 0, left = groups.reduce((sum, group) => sum + group.weight, 0)
        for (const group of groups) {
            const share = left / (count - out.length)
            if (column.length > 0 && count - out.length > 1 && held + group.weight / 2 > share) {
                out.push(column)
                left -= held
                column = []
                held = 0
            }
            column.push(group.key)
            held += group.weight
        }
        if (column.length > 0) out.push(column)
        page.split = out
    }
    onColumnsChanged: Qt.callLater(page.plan)
    Component.onCompleted: page.plan()

    // Whole once every column is: the pool turns to the page only then.
    property bool whole: false
    function weigh(): void {
        // An area with nothing shown is whole as it stands.
        let built = columnRepeater.count === page.split.length
        for (let i = 0; built && i < columnRepeater.count; i++) built = columnRepeater.itemAt(i)?.whole === true
        page.whole = built
    }
    onSplitChanged: Qt.callLater(page.weigh)

    Rectangle {
        id: cols
        x: plate.width + page.u(32)
        width: page.width - x
        height: page.height
        radius: IrisStyle.radiusSheet
        color: IrisStyle.glassy ? IrisStyle.readingSidebar : "transparent"
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: IrisStyle.glassy ? page.u(8) : 0
            contentHeight: columnRow.implicitHeight + page.u(16)
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.vertical: IrisScrollBar {}
            Row {
                id: columnRow
                spacing: page.gap
                Repeater {
                    id: columnRepeater
                    model: page.split
                    onCountChanged: Qt.callLater(page.weigh)
                    AreaRows {
                        required property var modelData
                        width: Math.floor((flick.width - page.gap * (page.split.length - 1)) / Math.max(1, page.split.length))
                        section: page.area
                        host: page.host
                        voice: "drawer"
                        live: page.live
                        welcome: false
                        only: modelData
                        groupFill: "transparent"
                        onWholeChanged: Qt.callLater(page.weigh)
                        onReveal: row => page.reveal(row)
                    }
                }
            }
        }
    }

    function targets(): var {
        let out = []
        for (let i = 0; i < columnRepeater.count; i++) out = out.concat(columnRepeater.itemAt(i)?.targets() ?? [])
        return out
    }
    // Asked from outside (a link, the CLI): the column scrolls the group's head to its top.
    function showGroup(wanted: string): void {
        const lower = wanted.toLowerCase()
        const target = page.targets().find(entry => entry.key === wanted || entry.key.toLowerCase() === lower
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
