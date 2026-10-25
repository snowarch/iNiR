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
    readonly property real pageWidth: boardBox.width
    readonly property real need: 0
    readonly property string voice: "console"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    // its tiles are the rows: the engine builds its own only for a search or a page
    readonly property color groupFill: "transparent"
    readonly property string searchHint: Translation.tr("Search")

    readonly property bool windowed: Boolean(root.host?.windowed ?? true)
    readonly property real pad: root.u(root.windowed ? 18 : 24)
    readonly property real gap: root.u(10)
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property bool paged: Number(root.host?.advancedPage ?? -1) >= 0
    readonly property int current: Math.max(0, root.sections.findIndex(entry => entry.id === root.section))
    readonly property var area: root.host?.currentSection ?? ({})
    readonly property var shownArea: IrisOptions.sectionById(pool.shown) ?? root.area
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    readonly property color plate: IrisStyle.glassy ? IrisStyle.readingCard : IrisStyle.fillQuiet
    readonly property real label: Math.max(10, IrisStyle.typeCaption)
    function clusterName(index: int): string { return Translation.tr(String(root.host?.clusterNames?.[index] ?? "")) }

    // Keys reach the page in front: its tiles, its cursor.
    readonly property int cursor: Number(pool.shownItem?.cursor ?? -1)
    function takeKey(event: var): bool {
        const page = pool.shown === root.section ? pool.shownItem : null
        if (page?.takeKey) return page.takeKey(event)
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) { root.host.stepSection(event.key === Qt.Key_Left ? -1 : 1); return true }
        return false
    }
    function release(): bool { return pool.shownItem?.release?.() ?? false }
    readonly property bool drawsRows: true

    // ── The areas.
    Flickable {
        id: nav
        x: root.pad
        y: root.pad
        width: root.u(2 * 104 + 6)
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
                    // Nothing's settings list: names in the mono face, two a line, no plates at rest; the open one is
                    // the white key, the pointer a quiet one. A grid of grey squares read as nothing in particular.
                    Grid {
                        columns: 2
                        columnSpacing: root.u(6)
                        rowSpacing: root.u(2)
                        Repeater {
                            model: cluster.modelData.areas
                            MouseArea {
                                id: key
                                required property var modelData
                                readonly property bool on: key.modelData.id === root.section && !root.searching
                                readonly property bool noted: Number(root.noteCounts[key.modelData.id] ?? 0) > 0
                                readonly property bool found: !root.searching || (root.host?.matchedSections?.has(key.modelData.id) ?? false)
                                width: root.u(104)
                                height: root.u(32)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                opacity: key.found ? 1 : 0.35
                                Accessible.role: Accessible.PageTab
                                Accessible.name: Translation.tr(String(key.modelData.title ?? ""))
                                Accessible.checked: key.on
                                onClicked: root.host.selectSection(key.modelData.id)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: IrisStyle.fieldChamfer ? 0 : IrisStyle.capsule(height)
                                    color: key.on ? IrisStyle.text : key.containsMouse ? IrisStyle.fillQuiet : "transparent"
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                                }
                                MaterialSymbol {
                                    x: root.u(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String(key.modelData.icon ?? "settings")
                                    iconSize: root.u(15)
                                    fill: key.on ? 1 : 0
                                    color: key.on ? IrisStyle.surfaceOpaque : IrisStyle.subtext
                                }
                                Mono {
                                    x: root.u(32)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - x - root.u(key.noted ? 16 : 8)
                                    elide: Text.ElideRight
                                    text: Translation.tr(String(IrisOptions.shortTitles[key.modelData.id] ?? key.modelData.title ?? ""))
                                    color: key.on ? IrisStyle.surfaceOpaque : IrisStyle.text
                                }
                                Rectangle {
                                    visible: key.noted
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.u(9)
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
    }

    // ── The area's head: its Dot title and what it is, then the search, the layouts, the way out.
    Item {
        id: head
        x: nav.x + nav.width + root.u(26)
        y: root.pad
        width: root.width - x - root.pad
        height: root.u(root.windowed ? 60 : 70)
        // The name over what the area is, both the width up to the controls: side by side they split it, and an area
        // like Screenshots & Recording lost both ends.
        DotTitle {
            id: title
            y: Math.round((parent.height - title.height - (blurb.visible ? blurb.implicitHeight : 0)) / 2)
            text: root.searching ? Translation.tr("Search") : Translation.tr(String(root.shownArea.title ?? ""))
            size: root.u(root.windowed ? 34 : 44)
            fit: Math.max(root.u(120), controls.x - root.u(24))
        }
        IrisText {
            id: blurb
            anchors.top: title.bottom
            anchors.topMargin: -root.u(4)
            width: Math.max(0, Math.min(implicitWidth, controls.x - root.u(24)))
            elide: Text.ElideRight
            visible: !root.searching && text.length > 0
            text: Translation.tr(String(root.shownArea.subtitle ?? ""))
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

    // ── The board: the area, a page of the pool.
    Item {
        id: boardBox
        x: head.x
        y: head.y + head.height + root.u(12)
        width: head.width
        height: root.height - y - root.pad
        AreaPool {
            id: pool
            anchors.fill: parent
            current: root.searching ? pool.shown : root.section
            hidden: root.searching || root.paged
            settled: Boolean(root.host?.bodySettled ?? true)
            urlFor: id => Qt.resolvedUrl("ConsolePage.qml")
            propsFor: id => ({ host: root.host })
            order: root.sections.map(entry => entry.id)
            distance: root.u(22)
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

    component Mono: IrisText {
        font.family: IrisStyle.fontMono
        font.pixelSize: root.label
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(root.label * 0.08)
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
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(width); color: key.containsMouse ? IrisStyle.fillHover : root.plate }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.text }
    }
}
