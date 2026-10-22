pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.settings
import qs.modules.iris.settings.layouts.folio as Skins // so Quickshell mirrors the skins IrisSkin loads by url

// Folio: Apple's System Settings read as a sheet. An index of ink glyphs down the left (Home first, then the clusters
// under their Label heads; the open one an inverted capsule, a signal dot where something needs you). The page is Home,
// or an area: its title and one sentence, its live stage held still, its groups beside it; the wheel over the groups
// glides from one group's head to the next.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: page.width
    readonly property real need: 0
    readonly property string voice: "folio"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    readonly property string searchHint: Translation.tr("Search, or say what to change")

    readonly property bool compact: root.width < root.u(1200)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool home: root.section === "home" && !root.searching
    readonly property bool searching: root.host?.searching ?? false
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    function clusterName(index: int): string { return Translation.tr(String(root.host?.clusterNames?.[index] ?? "")) }

    // ── The index.
    Rectangle {
        id: index
        x: root.u(8)
        y: root.u(8)
        width: root.u(root.compact ? 216 : 244)
        height: root.height - 2 * root.u(8)
        radius: IrisStyle.fieldChamfer ? 0 : Math.max(root.u(12), IrisStyle.radiusPanel - root.u(8))
        color: IrisStyle.glassy ? IrisStyle.readingSidebar : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, IrisStyle.light ? 0.03 : 0.035) // iris-literal: the index sits a step off the sheet
        Flickable {
            id: indexFlick
            anchors.fill: parent
            anchors.margins: root.u(10)
            contentHeight: indexColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            // The open area's capsule: one pill that slides from key to key; each key's ink follows how much of the pill
            // covers it, so the words turn as the pill arrives instead of before it.
            Rectangle {
                id: pill
                readonly property real target: {
                    indexColumn.implicitHeight
                    const at = root.sections.findIndex(entry => entry.id === root.section)
                    const entry = at >= 0 ? indexRepeater.itemAt(at) : null
                    return entry ? entry.y + entry.keyY : 0
                }
                property bool placed: false
                visible: !root.searching && root.sections.length > 0
                width: indexColumn.width
                height: root.u(34)
                radius: IrisStyle.capsule(height)
                color: IrisStyle.text
                y: pill.target
                Behavior on y { enabled: pill.placed && IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Timer { running: true; interval: 400; onTriggered: pill.placed = true }
            }
            Column {
                id: indexColumn
                width: indexFlick.width
                spacing: root.u(2)
                Repeater {
                    id: indexRepeater
                    model: root.sections
                    Column {
                        id: entry
                        required property var modelData
                        required property int index
                        readonly property bool starts: entry.index > 0 && root.sections[entry.index - 1]?.cluster !== entry.modelData.cluster
                        readonly property real keyY: entry.starts ? root.u(34) : 0
                        width: indexColumn.width
                        Item {
                            visible: entry.starts
                            width: parent.width
                            height: root.u(34)
                            IrisText {
                                x: root.u(12)
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: root.u(6)
                                text: root.clusterName(Number(entry.modelData.cluster))
                                color: IrisStyle.textTertiary
                                font.family: IrisStyle.fontMono
                                font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                                font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
                            }
                        }
                        MouseArea {
                            id: key
                            readonly property bool on: entry.modelData.id === root.section && !root.searching
                            readonly property bool found: !root.searching || (root.host?.matchedSections?.has(entry.modelData.id) ?? false)
                            readonly property int noted: Number(root.noteCounts[entry.modelData.id] ?? 0)
                            readonly property real lit: pill.visible ? Math.max(0, Math.min(1, 1 - Math.abs(pill.y - entry.y - entry.keyY) / key.height)) : 0
                            readonly property color ink: ColorUtils.mix(IrisStyle.surfaceOpaque, IrisStyle.text, key.lit)
                            width: parent.width
                            height: root.u(34)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            opacity: key.found ? 1 : 0.35
                            Accessible.role: Accessible.PageTab
                            Accessible.name: Translation.tr(String(entry.modelData.title ?? ""))
                            Accessible.checked: key.on
                            onClicked: root.host.selectSection(entry.modelData.id)
                            Rectangle {
                                anchors.fill: parent
                                radius: IrisStyle.capsule(height)
                                color: key.containsMouse && key.lit < 0.5 ? IrisStyle.fillHover : "transparent"
                                Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                            }
                            MaterialSymbol {
                                id: glyph
                                x: root.u(12)
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(entry.modelData.icon ?? "settings")
                                iconSize: root.u(18)
                                fill: key.lit > 0.5 ? 1 : 0
                                color: key.ink
                            }
                            IrisText {
                                x: glyph.x + root.u(30)
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - root.u(key.noted > 0 ? 28 : 12)
                                elide: Text.ElideRight
                                text: Translation.tr(String(entry.modelData.title ?? ""))
                                color: key.ink
                                font.pixelSize: IrisStyle.typeBody
                                font.weight: key.lit > 0.5 ? Font.DemiBold : Font.Normal
                            }
                            Rectangle {
                                visible: key.noted > 0
                                anchors.right: parent.right
                                anchors.rightMargin: root.u(14)
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.u(6)
                                height: width
                                radius: width / 2
                                color: root.signal
                            }
                        }
                    }
                }
            }
        }
    }

    // ── The page.
    Item {
        id: page
        x: index.x + index.width + root.u(root.compact ? 20 : 28)
        y: 0
        width: root.width - x - root.u(root.compact ? 20 : 28)
        height: root.height

        RowLayout {
            id: head
            y: root.u(16)
            width: page.width
            height: root.u(38)
            spacing: root.u(10)
            Item { id: searchSlot; Layout.preferredWidth: root.u(root.compact ? 240 : 320); Layout.preferredHeight: root.u(36) }
            Item { Layout.fillWidth: true }
            LayoutSwitch { host: root.host; voice: "folio"; compact: root.compact }
            RoundKey {
                glyph: root.host?.windowed ? "layers" : "web_asset"
                name: root.host?.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                onClicked: root.host.switchHost()
            }
            RoundKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
        }

        // A new area rises in from the side it lies on in the index; the motion only moves, it never waits on opacity.
        property int was: -1
        readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
        onCurrentChanged: {
            if (page.was >= 0 && page.was !== page.current && IrisStyle.motionEnabled) {
                rise.from = (page.current > page.was ? 1 : -1) * root.u(26)
                rise.restart()
            }
            page.was = page.current
        }
        Component.onCompleted: page.was = page.current
        NumberAnimation { id: rise; target: bodyShift; property: "y"; to: 0; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }

        Item {
            id: body
            transform: Translate { id: bodyShift }
            y: head.y + head.height + root.u(18)
            width: page.width
            height: page.height - y

            Home {
                id: homePage
                visible: root.home
                anchors.fill: parent
                anchors.bottomMargin: root.u(16)
                host: root.host
                voice: "folio"
            }

            // The area: its title and sentence across, the stage on the left, its groups on the right.
            Column {
                id: title
                visible: !root.home && !root.searching
                width: body.width
                spacing: root.u(4)
                IrisText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Translation.tr(String(root.area.title ?? ""))
                    color: IrisStyle.text
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: root.u(26)
                    font.weight: Font.DemiBold
                    font.letterSpacing: -Math.round(root.u(26) * 0.01)
                }
                IrisText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Translation.tr(String(root.area.subtitle ?? ""))
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeBody
                }
            }
            Item {
                id: areaBox
                visible: !root.home
                y: root.searching ? 0 : title.height + root.u(18)
                width: body.width
                height: body.height - y - root.u(16)
                readonly property bool staged: !root.searching && stage.available
                readonly property real gap: root.u(root.compact ? 18 : 24)
                ClippingRectangle {
                    id: plate
                    visible: areaBox.staged
                    width: Math.round(areaBox.width * (root.compact ? 0.40 : 0.42))
                    height: Math.round(Math.min(areaBox.height, width * 0.78, root.u(440)))
                    radius: IrisStyle.radiusSheet
                    color: IrisStyle.readingCard
                    border.width: 1
                    border.color: IrisStyle.hairline
                    IrisGroupPreview {
                        id: stage
                        anchors.fill: parent
                        anchors.margins: root.u(12)
                        radius: Math.max(IrisStyle.radiusRow, IrisStyle.radiusSheet - root.u(12))
                        standIn: true
                        captionOutside: true
                        section: root.searching || root.home ? "" : root.section
                        niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                        niriRevision: IrisNiri.revision
                        group: String(root.host?.leadGroup ?? "")
                    }
                }
                // Under the stage: what it shows now, what can be done to the page, then the area at a glance.
                Column {
                    id: underStage
                    visible: areaBox.staged
                    y: plate.height + root.u(14)
                    width: plate.width
                    spacing: root.u(14)
                IrisText {
                    visible: stage.caption.length > 0
                    x: root.u(4)
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
                    spacing: root.u(6)
                    Repeater {
                        model: root.host?.pageActions ?? []
                        MouseArea {
                            id: act
                            required property var modelData
                            width: actRow.implicitWidth + root.u(22)
                            height: root.u(32)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: String(act.modelData.label ?? "")
                            onClicked: act.modelData.clicked()
                            Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: act.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
                            Row {
                                id: actRow
                                anchors.centerIn: parent
                                spacing: root.u(6)
                                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: String(act.modelData.glyph ?? ""); iconSize: root.u(16); color: IrisStyle.text }
                                IrisText { anchors.verticalCenter: parent.verticalCenter; text: String(act.modelData.label ?? ""); color: IrisStyle.text; font.pixelSize: IrisStyle.typeMeta }
                            }
                        }
                    }
                }
                // The area at a glance: its telling values, each a link to its row.
                Column {
                    id: facts
                    readonly property int fit: Math.max(0, Math.min(6, Math.floor((areaBox.height - plate.height - root.u(150)) / root.u(40))))
                    readonly property var rows: { Config.revision; return facts.fit > 0 && !root.home && !root.searching ? (root.host?.tellingRows(facts.fit, root.section) ?? []) : [] }
                    visible: facts.rows.length > 0
                    width: plate.width
                    IrisText {
                        x: root.u(4)
                        bottomPadding: root.u(6)
                        text: Translation.tr("At a glance")
                        color: IrisStyle.textTertiary
                        font.family: IrisStyle.fontMono
                        font.pixelSize: Math.max(10, IrisStyle.typeCaption)
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
                    }
                    Repeater {
                        model: facts.rows
                        MouseArea {
                            id: fact
                            required property var modelData
                            required property int index
                            width: facts.width
                            height: root.u(40)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Link
                            Accessible.name: Translation.tr(String(fact.modelData.label ?? ""))
                            onClicked: root.host.landOn(String(fact.modelData.path ?? ""))
                            Rectangle { anchors.fill: parent; radius: IrisStyle.fieldChamfer ? 0 : root.u(10); color: fact.containsMouse ? IrisStyle.fillHover : "transparent" }
                            Rectangle { visible: fact.index > 0; x: root.u(4); width: parent.width - 2 * x; height: 1; color: IrisStyle.hairline }
                            IrisText {
                                x: root.u(4)
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.6 - x
                                elide: Text.ElideRight
                                text: Translation.tr(String(fact.modelData.label ?? ""))
                                color: IrisStyle.subtext
                                font.pixelSize: IrisStyle.typeMeta
                            }
                            IrisText {
                                anchors.right: parent.right
                                anchors.rightMargin: root.u(4)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width * 0.4)
                                elide: Text.ElideRight
                                text: { Config.revision; return root.host?.answerOf(fact.modelData) ?? "" }
                                color: IrisStyle.text
                                font.pixelSize: IrisStyle.typeMeta
                                font.weight: IrisStyle.weight(Font.DemiBold)
                            }
                        }
                    }
                }
                }
                Rectangle {
                    id: sheet
                    x: areaBox.staged ? plate.width + areaBox.gap : 0
                    width: areaBox.width - x
                    height: areaBox.height
                    radius: IrisStyle.radiusSheet
                    color: IrisStyle.glassy ? IrisStyle.readingSidebar : "transparent"
                    Item {
                        id: rowsSlot
                        anchors.fill: parent
                        anchors.leftMargin: IrisStyle.glassy ? root.u(6) : -root.u(12)
                        anchors.rightMargin: IrisStyle.glassy ? root.u(6) : 0
                        anchors.topMargin: IrisStyle.glassy ? root.u(6) : 0
                    }
                    // The wheel over the groups glides head to head: a group whose head is in view is landed on, a long one
                    // is read through in steps. Clicks pass through to the rows.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        enabled: !root.searching
                        onWheel: wheel => root.glide(wheel)
                    }
                }
            }
        }
    }

    readonly property Item flick: {
        root.section
        return root.findFlick(rowsSlot)
    }
    function findFlick(item: Item): Item {
        for (const child of item?.children ?? []) {
            if (child.contentY !== undefined && child.contentHeight !== undefined && child.visible) return child
            const deeper = root.findFlick(child)
            if (deeper) return deeper
        }
        return null
    }
    property real wheelAcc: 0
    Timer { id: wheelRest; interval: 180 }
    function glide(event: var): void {
        const f = root.flick
        if (!f) { event.accepted = false; return }
        // A touchpad scrolls by pixels as it always does: only notched wheels snap.
        if (event.pixelDelta.y !== 0) { f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY - event.pixelDelta.y)); return }
        root.wheelAcc += event.angleDelta.y
        if (wheelRest.running || Math.abs(root.wheelAcc) < 60) return
        const down = root.wheelAcc < 0
        root.wheelAcc = 0
        wheelRest.restart()
        const end = Math.max(0, f.contentHeight - f.height)
        const now = glideTo.running ? glideTo.to : f.contentY
        const heads = (root.host?.spyTargets() ?? []).map(target => target.item.mapToItem(f.contentItem, 0, 0).y - root.u(8)).sort((a, b) => a - b)
        const next = down ? heads.find(y => y > now + 4) : heads.slice().reverse().find(y => y < now - 4)
        let to = next !== undefined && Math.abs(next - now) <= f.height * 0.85 ? next : now + (down ? 1 : -1) * f.height * 0.6
        to = Math.max(0, Math.min(end, to))
        if (Math.abs(to - f.contentY) < 1) return
        glideTo.target = f
        glideTo.from = f.contentY
        glideTo.to = to
        glideTo.restart()
    }
    NumberAnimation { id: glideTo; property: "contentY"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }

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
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: key.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.text }
    }
}
