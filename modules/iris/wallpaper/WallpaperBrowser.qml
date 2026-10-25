pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Browser: everything in its place, as Photos does it. Where to look down the side (your folders, favourites, the
// web), a grid of what is there, and an inspector with the chosen one large, its facts and every way on from it.
Item {
    id: root

    required property var engine
    required property var host
    property real maxWidth: 1600
    property real maxHeight: 900
    readonly property real d: IrisStyle.density
    readonly property real pad: IrisStyle.concentricPad(IrisStyle.radiusPanel, Math.round(14 * root.d))
    readonly property real gap: Math.round(12 * root.d)

    readonly property real bodyWidth: Math.round(Math.max(1040 * root.d, Math.min(1520 * root.d, root.maxWidth * 0.74)))
    readonly property real bodyHeight: Math.round(Math.max(560 * root.d, Math.min(900 * root.d, root.maxHeight * 0.8)))
    readonly property real sideWidth: Math.round(212 * root.d)
    readonly property real inspectorWidth: Math.round(Math.min(360 * root.d, root.bodyWidth * 0.25))
    readonly property real innerRadius: IrisStyle.concentric(IrisStyle.radiusPanel, root.pad, IrisStyle.radiusRow)

    implicitWidth: root.bodyWidth
    implicitHeight: root.bodyHeight

    function focusSearch(): void { search.focusField() }
    function reveal(): void { grid.positionViewAtIndex(root.engine.selectedIndex, GridView.Contain) }
    function navigate(event): bool {
        const step = event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Left ? -1
            : event.key === Qt.Key_Down ? grid.columns : event.key === Qt.Key_Up ? -grid.columns
            : event.key === Qt.Key_PageDown ? grid.columns * grid.rowsShown : event.key === Qt.Key_PageUp ? -grid.columns * grid.rowsShown : 0
        if (step !== 0) { root.engine.move(step); root.reveal(); return true }
        if (event.key === Qt.Key_Home && root.engine.query.length === 0) { root.engine.select(0); root.reveal(); return true }
        if (event.key === Qt.Key_End && root.engine.query.length === 0) { root.engine.select(root.engine.count - 1); root.reveal(); return true }
        return root.host.commonKey(event)
    }
    Connections {
        target: root.engine
        function onListGenerationChanged(): void { grid.contentY = 0 }
    }

    // ── The side: where to look ──────────────────────────────────────────
    component SideRow: MouseArea {
        id: row
        property string glyph: ""
        property string label: ""
        property string count: ""
        property bool chosen: false
        Layout.fillWidth: true
        implicitHeight: Math.round(32 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: row.label
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.capsule(height)
            color: row.chosen ? IrisStyle.tintFill(IrisStyle.accent) : row.pressed ? IrisStyle.fillActive
                : row.containsMouse ? IrisStyle.fillHover : ColorUtils.applyAlpha(IrisStyle.fillHover, 0)
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }
        MaterialSymbol {
            id: rowGlyph
            anchors.left: parent.left
            anchors.leftMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: row.glyph
            fill: row.chosen ? 1 : 0
            iconSize: Math.round(17 * root.d)
            color: row.chosen ? IrisStyle.accent : IrisStyle.subtext
        }
        IrisText {
            anchors.left: rowGlyph.right
            anchors.leftMargin: Math.round(10 * root.d)
            anchors.right: rowCount.left
            anchors.rightMargin: Math.round(6 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            elide: Text.ElideRight
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(row.chosen ? Font.DemiBold : Font.Medium)
        }
        IrisText {
            id: rowCount
            anchors.right: parent.right
            anchors.rightMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: row.count
            color: IrisStyle.subtext
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.Bold)
        }
    }
    component SideHead: IrisText {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(10 * root.d)
        Layout.leftMargin: Math.round(10 * root.d)
        Layout.bottomMargin: Math.round(2 * root.d)
        color: IrisStyle.subtext
        font.pixelSize: IrisStyle.typeMeta
        font.weight: IrisStyle.weight(Font.DemiBold)
    }

    Flickable {
        id: side
        x: root.pad
        y: root.pad
        width: root.sideWidth
        height: root.height - 2 * root.pad
        contentHeight: sideColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: sideColumn
            width: side.width
            spacing: Math.round(2 * root.d)
            SideHead { Layout.topMargin: Math.round(2 * root.d); text: Translation.tr("Library") }
            Repeater {
                model: root.engine.places
                SideRow {
                    id: placeRow
                    required property var modelData
                    glyph: placeRow.modelData.glyph
                    label: placeRow.modelData.label
                    count: placeRow.chosen && root.engine.count > 0 ? String(root.engine.count) : ""
                    chosen: root.engine.source === "library" && root.engine.folderPath === placeRow.modelData.path
                    onClicked: root.engine.openFolder(placeRow.modelData.path)
                }
            }
            SideRow {
                visible: root.engine.source === "library" && !root.engine.places.some(place => place.path === root.engine.folderPath)
                glyph: "folder_open"
                label: root.engine.folderName
                count: root.engine.count > 0 ? String(root.engine.count) : ""
                chosen: true
            }
            SideRow {
                glyph: "favorite"
                label: Translation.tr("Favourites")
                count: Wallpapers.favorites.length > 0 ? String(Wallpapers.favorites.length) : ""
                chosen: root.engine.source === "favorites"
                onClicked: root.engine.setSource("favorites", "")
            }
            SideHead { visible: root.engine.onlineSources.length > 0; text: Translation.tr("On the web") }
            Repeater {
                model: root.engine.onlineSources
                SideRow {
                    id: webRow
                    required property var modelData
                    glyph: webRow.modelData.glyph
                    label: webRow.modelData.label
                    chosen: root.engine.source === webRow.modelData.id
                    onClicked: root.engine.setSource(webRow.modelData.id, "")
                }
            }
        }
    }

    // ── The middle: what is there ────────────────────────────────────────
    ColumnLayout {
        id: middle
        x: side.x + side.width + root.gap
        y: root.pad
        width: inspector.x - x - root.gap
        height: root.height - 2 * root.pad
        spacing: Math.round(10 * root.d)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)
            Row {
                visible: root.engine.source === "library" && (root.engine.canGoBack || root.engine.canGoForward)
                spacing: Math.round(2 * root.d)
                WallpaperGlyphButton {
                    glyph: "chevron_left"
                    enabled: root.engine.canGoBack
                    Accessible.name: Translation.tr("Back")
                    onClicked: root.engine.goBack()
                }
                WallpaperGlyphButton {
                    glyph: "chevron_right"
                    enabled: root.engine.canGoForward
                    Accessible.name: Translation.tr("Forward")
                    onClicked: root.engine.goForward()
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: root.engine.source === "library" ? root.engine.folderName : root.engine.sourceInfo.label
                    elide: Text.ElideRight
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeTitle
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.engine.source === "library" ? root.engine.folderPath.replace(root.engine.homePath, "~")
                        : root.engine.online && root.engine.onlineTotal > 0 ? Translation.tr("%1 wallpapers").arg(root.engine.compact(root.engine.onlineTotal)) : ""
                    elide: Text.ElideMiddle
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                }
            }
            WallpaperGlyphButton {
                visible: root.engine.source === "library"
                glyph: "push_pin"
                selected: root.engine.pinned
                Accessible.name: root.engine.pinned ? Translation.tr("Unpin this folder") : Translation.tr("Pin this folder")
                onClicked: root.engine.togglePin()
            }
            WallpaperSearch {
                id: search
                Layout.preferredWidth: Math.round(260 * root.d)
                engine: root.engine
                navigate: event => root.navigate(event)
            }
            WallpaperOrder { engine: root.engine }
            WallpaperLayoutSwitch { layout: "browser" }
        }

        WallpaperContext {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            visible: (root.engine.source === "library" && root.engine.libraryFolders.length > 0 && root.engine.query.length === 0)
                || root.engine.online || (root.engine.source === "favorites" && root.engine.kindsPresent.length > 0)
            engine: root.engine
            trail: false
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.engine.online && (root.engine.filtersShaped || root.engine.ranged)
            WallpaperFilters {
                Layout.fillWidth: true
                engine: root.engine
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.engine.source === "library" && root.engine.kindsPresent.length > 0
            spacing: Math.round(6 * root.d)
            Repeater {
                model: root.engine.source === "library" ? root.engine.kindsPresent : []
                IrisChip {
                    id: kindChip
                    required property var modelData
                    glyph: kindChip.modelData.glyph
                    label: kindChip.modelData.label
                    selected: root.engine.kind === kindChip.modelData.id
                    quiet: !kindChip.selected
                    implicitHeight: Math.round(28 * root.d)
                    onClicked: root.engine.kind = kindChip.modelData.id
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property int columns: Math.max(2, Math.floor(width / (196 * root.d)))
            readonly property int rowsShown: Math.max(1, Math.floor(height / cellHeight))
            cellWidth: Math.floor(width / grid.columns)
            cellHeight: Math.round(grid.cellWidth * 0.66)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: Math.round(cellHeight * 3)
            model: ScriptModel {
                values: root.engine.entries
                objectProp: "key"
            }
            currentIndex: root.engine.selectedIndex
            onContentYChanged: if (root.engine.online && contentY + height > contentHeight - cellHeight * 2) root.engine.loadMore()
            ScrollBar.vertical: IrisScrollBar {}
            highlightFollowsCurrentItem: false
            highlight: Item {
                id: ring
                readonly property Item at: grid.currentItem
                readonly property bool travels: IrisStyle.motionEnabled && root.host.armed && ring.at !== null
                z: 2
                x: ring.at ? ring.at.x : 0
                y: ring.at ? ring.at.y : 0
                width: grid.cellWidth
                height: grid.cellHeight
                opacity: ring.at !== null && root.engine.count > 0 ? 1 : 0
                Behavior on x { enabled: ring.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Behavior on y { enabled: ring.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(2 * root.d)
                    radius: IrisStyle.fieldChamfer ? 0 : root.innerRadius + Math.round(4 * root.d)
                    color: "transparent"
                    border.width: Math.max(2, Math.round(2.5 * root.d))
                    border.color: IrisStyle.accent
                }
            }
            delegate: MouseArea {
                id: tile
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: root.engine.titleOf(tile.modelData)
                onClicked: root.engine.select(tile.index)
                onDoubleClicked: root.engine.apply(tile.modelData)
                WallpaperCard {
                    anchors.fill: parent
                    anchors.margins: Math.round(6 * root.d)
                    engine: root.engine
                    entry: tile.modelData
                    radius: root.innerRadius
                    markScale: 0.85
                    playing: tile.containsMouse && root.engine.playMotion && root.engine.opened
                    scale: tile.pressed ? IrisStyle.pressScale(0.97) : tile.containsMouse ? 1.02 : 1
                    Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                }
            }
            WallpaperEmpty {
                anchors.centerIn: parent
                width: parent.width - 60 * root.d
                visible: root.engine.count === 0
                picker: root.engine
            }
        }
    }

    // ── The side on the right: the chosen one ────────────────────────────
    Rectangle {
        id: inspector
        x: root.width - root.pad - width
        y: root.pad
        width: root.inspectorWidth
        height: root.height - 2 * root.pad
        radius: root.innerRadius
        color: IrisStyle.readingCard

        Flickable {
            id: inspectorFlick
            anchors.fill: parent
            anchors.margins: Math.round(14 * root.d)
            contentHeight: inspectorColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ColumnLayout {
                id: inspectorColumn
                width: inspectorFlick.width
                spacing: Math.round(12 * root.d)
                WallpaperCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(width / 1.6)
                    engine: root.engine
                    entry: root.engine.selected
                    radius: IrisStyle.concentric(root.innerRadius, Math.round(14 * root.d), IrisStyle.radiusRow)
                    sharp: root.engine.warm && root.engine.selected !== null
                    playing: root.engine.opened && root.engine.playMotion
                    marks: false
                    visible: root.engine.selected !== null
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: root.engine.selected !== null
                    text: root.engine.titleOf(root.engine.selected)
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeHeadline
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                WallpaperFacts {
                    Layout.fillWidth: true
                    engine: root.engine
                    entry: root.engine.selected
                }
                WallpaperActions {
                    Layout.fillWidth: true
                    engine: root.engine
                    targets: false
                }
                IrisSegmented {
                    Layout.fillWidth: true
                    visible: root.engine.overviewTargetable
                    implicitHeight: Math.round(32 * root.d)
                    accessibleName: Translation.tr("Apply to")
                    options: [{ value: "main", label: Translation.tr("Desktop") }, { value: "backdrop", label: Translation.tr("Overview") }]
                    current: root.engine.targetsOverview ? "backdrop" : "main"
                    onPicked: value => root.engine.targetOverview(value === "backdrop")
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.engine.status
                    wrapMode: Text.Wrap
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeMeta
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: IrisStyle.hairline
                    visible: details.visible
                }
                WallpaperDetails {
                    id: details
                    Layout.fillWidth: true
                    visible: root.engine.selected !== null
                    engine: root.engine
                    column: true
                }
            }
        }
    }
}
