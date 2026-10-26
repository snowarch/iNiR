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

// Folio: Apple's System Settings read as a sheet. An index of ink glyphs down the left (General first, then the clusters
// under their Label heads; the open one an inverted capsule, a signal dot where something needs you). The page is an
// area: its title and one sentence, its live stage held still, its groups beside it, scrolled as Classic's.
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
    readonly property bool drawsRows: true
    readonly property string searchHint: Translation.tr("Search, or say what to change")

    readonly property bool compact: root.width < root.u(1200)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property bool paged: Number(root.host?.advancedPage ?? -1) >= 0
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    function clusterName(index: int): string { return Translation.tr(String(root.host?.clusterNames?.[index] ?? "")) }

    // ── The index.
    Rectangle {
        id: index
        x: root.u(8)
        y: root.u(8)
        // As wide as the longest area name in its open weight (a translation runs longer), within a third more.
        readonly property real widest: {
            Translation.activeTranslations
            return Math.max(0, ...root.sections.map(entry => indexType.advanceWidth(Translation.tr(String(entry.title ?? "")))))
        }
        FontMetrics { id: indexType; font.family: IrisStyle.fontRead; font.pixelSize: IrisStyle.typeBody; font.weight: IrisStyle.weight(Font.DemiBold) }
        width: Math.min(root.u(root.compact ? 280 : 320), Math.max(root.u(root.compact ? 216 : 244), Math.ceil(index.widest) + root.u(92)))
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
                // The open area stays in view: a link or a turn to one below the fold scrolls the index to it.
                onTargetChanged: {
                    const top = pill.target - root.u(36), bottom = pill.target + pill.height + root.u(8)
                    let to = indexFlick.contentY
                    if (top < to) to = Math.max(0, top)
                    else if (bottom > to + indexFlick.height) to = Math.min(indexFlick.contentHeight - indexFlick.height, bottom - indexFlick.height)
                    if (Math.abs(to - indexFlick.contentY) < 1) return
                    indexScroll.to = to
                    indexScroll.restart()
                }
                NumberAnimation { id: indexScroll; target: indexFlick; property: "contentY"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
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
                                font.weight: IrisStyle.weight(Font.Medium)
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
                                font.weight: key.lit > 0.5 ? IrisStyle.weight(Font.DemiBold) : IrisStyle.weight(Font.Normal)
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

    // ── The page: the area, a page of the pool.
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

        Item {
            id: body
            y: head.y + head.height + root.u(18)
            width: page.width
            height: page.height - y - root.u(16)

            AreaPool {
                id: pool
                anchors.fill: parent
                // A search or a shared page borrows the body; the area under it stays as it was.
                current: root.searching ? pool.shown : root.section
                hidden: root.searching || root.paged
                settled: Boolean(root.host?.bodySettled ?? true)
                urlFor: id => Qt.resolvedUrl("FolioPage.qml")
                propsFor: id => ({ host: root.host })
                order: root.sections.map(entry => entry.id)
                distance: root.u(26)
                onArrived: id => {
                    if (root.wantedGroup.length > 0 && id === root.section) {
                        pool.shownItem?.showGroup?.(root.wantedGroup)
                        root.wantedGroup = ""
                    }
                }
            }

            // A search's results or a shared page (the Hub) on their own sheet.
            Rectangle {
                visible: root.searching || root.paged
                anchors.fill: parent
                radius: IrisStyle.radiusSheet
                color: IrisStyle.glassy ? IrisStyle.readingSidebar : "transparent"
                Item {
                    id: rowsSlot
                    anchors.fill: parent
                    anchors.leftMargin: IrisStyle.glassy ? root.u(6) : -root.u(12)
                    anchors.rightMargin: IrisStyle.glassy ? root.u(6) : 0
                    anchors.topMargin: IrisStyle.glassy ? root.u(6) : 0
                }
            }
        }
    }

    // A group asked for by name lands once its area's page stands.
    property string wantedGroup: ""
    function showGroup(key: string): void {
        if (pool.shown === root.section && pool.shownItem?.showGroup) pool.shownItem.showGroup(key)
        else root.wantedGroup = key
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
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: key.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.text }
    }
}
