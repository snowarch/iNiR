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
import qs.modules.iris.settings.layouts.pocket as Skins // so Quickshell mirrors the skins IrisSkin loads by url

// Pocket: Settings held in one hand. One column you push into and back out of, the way a phone's settings read; over
// the desktop it stands at the room's right edge, so the desktop beside it is the preview. Home is the welcome, what
// you change every day and the areas; an area slides in over it and slides back out. A wide window keeps Home as a
// column and shows the area beside it.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: root.split ? root.width - home.width : root.width
    readonly property real need: 0
    readonly property string voice: "pocket"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    readonly property bool drawsRows: true
    readonly property string searchHint: Translation.tr("Search settings")

    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property bool paged: Number(root.host?.advancedPage ?? -1) >= 0
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    readonly property real pad: root.u(16)
    // A window twice a column wide keeps Home beside the area, as a tablet's settings do.
    readonly property bool split: root.width >= root.u(860)

    // Home is General: its pinned rows lead Home, its own groups are a page of their own you push into.
    property bool generalOpen: false
    onSectionChanged: if (root.section !== "general") root.generalOpen = false
    readonly property string area: root.section === "general" ? (root.generalOpen ? "general" : "") : root.section
    // How deep the column stands: 0 Home, 1 an area, 2 a search or a shared page (the Hub) over either.
    readonly property int level: root.searching || root.paged ? 2 : root.area.length > 0 ? 1 : 0
    function back(): void {
        if (root.searching || root.paged) root.host.selectSection(root.paged ? "general" : root.section)
        else if (root.generalOpen) root.generalOpen = false
        else root.host.selectSection("general")
    }
    // Esc steps back out of an area before it closes Settings; a search or a page is the engine's to leave.
    function release(): bool {
        if (root.level !== 1 || root.split) return false
        root.back()
        return true
    }
    function open(id: string): void {
        if (id === "general") { root.generalOpen = true; if (root.section !== "general") root.host.selectSection("general") }
        else root.host.selectSection(id)
    }

    // ── The bar: the way back, the search, the close.
    RowLayout {
        id: bar
        x: root.pad
        y: root.u(14)
        width: root.width - 2 * root.pad
        height: root.u(38)
        spacing: root.u(8)
        BarKey {
            id: backKey
            visible: !root.split && root.level > 0
            glyph: "chevron_left"
            label: root.level === 2 && root.area.length > 0 ? Translation.tr(String(IrisOptions.sectionById(root.area)?.title ?? ""))
                : Translation.tr("Settings")
            onClicked: root.back()
        }
        Item { id: searchSlot; Layout.fillWidth: true; Layout.preferredHeight: root.u(36) }
        BarKey {
            glyph: root.host?.windowed ? "layers" : "web_asset"
            name: root.host?.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
            onClicked: root.host.switchHost()
        }
        BarKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
    }

    Item {
        id: stack
        y: bar.y + bar.height + root.u(10)
        width: root.width
        height: root.height - y
        clip: true

        // ── Home: the welcome, every day, the areas.
        Item {
            id: home
            width: root.split ? Math.min(root.u(470), Math.round(stack.width * 0.4)) : stack.width
            height: stack.height
            x: root.split || root.level === 0 ? 0 : -Math.round(stack.width * 0.3)
            opacity: root.split || root.level === 0 ? 1 : 0
            visible: opacity > 0
            Behavior on x { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
            Behavior on opacity { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.morphDuration * 0.6; easing.type: Easing.OutCubic } }

            Flickable {
                id: homeFlick
                anchors.fill: parent
                contentHeight: homeColumn.implicitHeight + root.u(24)
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: IrisScrollBar {}
                ColumnLayout {
                    id: homeColumn
                    x: root.pad
                    width: home.width - 2 * root.pad
                    spacing: root.u(10)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: root.u(4)
                        Layout.bottomMargin: root.u(2)
                        IrisText {
                            Layout.fillWidth: true
                            text: Translation.tr("Settings")
                            elide: Text.ElideRight
                            color: IrisStyle.text
                            font.family: IrisStyle.fontTitle
                            font.pixelSize: root.u(30)
                            font.weight: IrisStyle.weight(Font.Bold)
                            font.letterSpacing: -Math.round(root.u(30) * 0.01)
                        }
                        LayoutSwitch { host: root.host; voice: "pocket"; compact: true }
                    }
                    AreaRows {
                        Layout.fillWidth: true
                        section: "general"
                        host: root.host
                        voice: "pocket"
                        live: home.visible && root.level < 2
                        only: ["Every day"]
                    }
                    Repeater {
                        // General first on a card of its own, then the clusters under their names.
                        model: [{ cluster: -1, ids: ["general"] }].concat([0, 1, 2, 3, 4].map(at => ({ cluster: at,
                            ids: root.sections.filter(entry => entry.cluster === at).map(entry => entry.id) })).filter(entry => entry.ids.length > 0))
                        ColumnLayout {
                            id: cluster
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: root.u(8)
                            spacing: root.u(6)
                            IrisText {
                                visible: cluster.modelData.cluster >= 0
                                Layout.leftMargin: root.u(16)
                                text: Translation.tr(String(root.host?.clusterNames?.[cluster.modelData.cluster] ?? ""))
                                color: IrisStyle.muted
                                font.pixelSize: IrisStyle.typeMeta
                                font.weight: IrisStyle.weight(Font.DemiBold)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: areaList.implicitHeight
                                radius: IrisStyle.radiusTile
                                color: IrisStyle.readingCard
                                Column {
                                    id: areaList
                                    width: parent.width
                                    Repeater {
                                        model: cluster.modelData.ids
                                        AreaKey {
                                            required property string modelData
                                            required property int index
                                            width: areaList.width
                                            areaId: modelData
                                            first: index === 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── An area, pushed over Home.
        Item {
            id: pageView
            readonly property bool shown: root.split ? !root.searching && !root.paged : root.level === 1
            x: root.split ? home.width : pageView.shown ? 0 : root.level > 1 ? -Math.round(stack.width * 0.3) : stack.width
            width: stack.width - (root.split ? home.width : 0)
            height: stack.height
            opacity: pageView.shown ? 1 : root.level > 1 ? 0 : 1
            visible: pageView.shown || pageMove.running || fadeMove.running
            Behavior on x { enabled: IrisStyle.motionEnabled && !root.split; NumberAnimation { id: pageMove; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
            Behavior on opacity { enabled: IrisStyle.motionEnabled; NumberAnimation { id: fadeMove; duration: IrisStyle.morphDuration * 0.6; easing.type: Easing.OutCubic } }

            AreaPool {
                id: pool
                anchors.fill: parent
                // Split, Home's own pinned rows never repeat beside it: General shows its groups.
                current: root.area.length > 0 ? root.area : root.split ? "general" : pool.shown
                hidden: !pageView.visible
                settled: Boolean(root.host?.bodySettled ?? true)
                urlFor: id => Qt.resolvedUrl("PocketPage.qml")
                propsFor: id => ({ host: root.host })
                order: root.sections.map(entry => entry.id)
                distance: root.u(26)
                onArrived: id => {
                    if (root.wantedGroup.length > 0 && id === root.area) {
                        pool.shownItem?.showGroup?.(root.wantedGroup)
                        root.wantedGroup = ""
                    }
                }
            }
        }

        // ── A search's results, or a shared page (the Hub), over whatever stood.
        Item {
            id: sheet
            readonly property bool shown: root.searching || root.paged
            x: root.split ? home.width : sheet.shown ? 0 : stack.width
            width: stack.width - (root.split ? home.width : 0)
            height: stack.height
            visible: sheet.shown || sheetMove.running
            Behavior on x { enabled: IrisStyle.motionEnabled && !root.split; NumberAnimation { id: sheetMove; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
            Item {
                id: rowsSlot
                anchors.fill: parent
                anchors.leftMargin: root.u(4)
                anchors.rightMargin: root.u(4)
            }
        }
    }

    // A group asked for by name lands once its area's page stands.
    property string wantedGroup: ""
    function showGroup(key: string): void {
        if (pool.shown === root.area && pool.shownItem?.showGroup) pool.shownItem.showGroup(key)
        else root.wantedGroup = key
    }

    // An area on Home's list: its glyph on a tile of its colour, its name, a signal dot when it needs you.
    component AreaKey: MouseArea {
        id: key
        property string areaId
        property bool first: false
        readonly property var entry: key.areaId === "general" ? ({ title: "General", icon: "tune", tint: IrisStyle.identity.gray })
            : (IrisOptions.sectionById(key.areaId) ?? ({}))
        readonly property bool on: root.split && root.area === key.areaId
        readonly property int noted: Number(root.noteCounts[key.areaId] ?? 0)
        readonly property color tint: key.entry.tint ?? IrisStyle.accent
        height: root.u(48)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(String(key.entry.title ?? ""))
        onClicked: root.open(key.areaId)
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.u(4)
            radius: IrisStyle.radiusRow
            color: key.on ? IrisStyle.fill : key.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        }
        Rectangle {
            visible: !key.first
            x: root.u(56)
            width: parent.width - x
            height: 1
            color: IrisStyle.hairline
        }
        Rectangle {
            id: tile
            x: root.u(14)
            anchors.verticalCenter: parent.verticalCenter
            width: root.u(30)
            height: width
            radius: IrisStyle.fieldChamfer ? 0 : root.u(9)
            color: Qt.rgba(key.tint.r, key.tint.g, key.tint.b, IrisStyle.light ? 0.16 : 0.2)
            MaterialSymbol {
                anchors.centerIn: parent
                text: String(key.entry.icon ?? "settings")
                iconSize: root.u(18)
                fill: key.on ? 1 : 0
                color: root.host?.tintInk ? root.host.tintInk(key.tint) : key.tint
            }
        }
        IrisText {
            x: tile.x + tile.width + root.u(12)
            anchors.verticalCenter: parent.verticalCenter
            width: chevron.x - x - root.u(key.noted > 0 ? 22 : 8)
            elide: Text.ElideRight
            text: Translation.tr(String(key.entry.title ?? ""))
            color: IrisStyle.text
            font.pixelSize: IrisStyle.typeBody
            font.weight: key.on ? Font.DemiBold : Font.Medium
        }
        Rectangle {
            visible: key.noted > 0
            anchors.right: chevron.left
            anchors.rightMargin: root.u(8)
            anchors.verticalCenter: parent.verticalCenter
            width: root.u(7)
            height: width
            radius: width / 2
            color: root.signal
        }
        MaterialSymbol {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: root.u(12)
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            iconSize: root.u(20)
            color: IrisStyle.textTertiary
        }
    }

    // A key on the bar: a glyph in a capsule, with the name of where it leads when it has one (the way back).
    component BarKey: MouseArea {
        id: key
        property string glyph
        property string name
        property string label: ""
        Layout.preferredWidth: key.label.length > 0 ? Math.min(root.u(160), keyLabel.implicitWidth + root.u(46)) : root.u(36)
        Layout.preferredHeight: root.u(36)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.label.length > 0 ? key.label : key.name
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: key.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
        MaterialSymbol {
            id: keyGlyph
            x: key.label.length > 0 ? root.u(8) : (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            text: key.glyph
            iconSize: root.u(key.label.length > 0 ? 20 : 18)
            color: IrisStyle.text
        }
        IrisText {
            id: keyLabel
            visible: key.label.length > 0
            x: keyGlyph.x + keyGlyph.width + root.u(2)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - x - root.u(12))
            elide: Text.ElideRight
            text: key.label
            color: IrisStyle.text
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
    }
}
