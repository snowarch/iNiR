pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components

// One workspace of Niri, the way Niri keeps it: a strip. Its columns run left to right, the tiles of a column stack, and
// what floats floats where it floats. The card is as wide as the strip needs (up to `fitWidth`) and as tall as the screen
// is at that scale, so a workspace of one column is a small card and one of six fills the row, and every window of it is
// on the card either way. Windows are pictures (IrisOrbitThumb) on your wallpaper.
Item {
    id: root

    property var screen: null
    property var windows: []
    property real outputWidth: 1920
    property real outputHeight: 1080
    // The box the card may fill at its largest.
    property real fitWidth: 1200
    property real fitHeight: 480
    property int cursorId: -1
    // null = not searching; else { windowId: true } for the windows that match.
    property var matches: null
    property bool previews: true
    property bool interactive: false
    property bool showWallpaper: true
    // "hover": the keyboard's tile and the hovered one; "always": every tile wide enough; "off".
    property string titleMode: "hover"
    property real dimOpacity: 0.22
    readonly property real d: IrisStyle.density
    readonly property real dpr: root.QsWindow.window?.devicePixelRatio ?? 1
    readonly property real gapOut: 16
    // Output pixels per card pixel, and the card's size: set by the arrangement below.
    property real scaleOut: 0.3
    property real cardWidth: 100
    property real cardHeight: 100
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    signal windowClicked(int windowId, int button)
    signal windowHovered(int windowId)
    signal cardClicked()

    readonly property var windowMap: {
        const map = {}
        for (const window of root.windows) map[window.id] = window
        return map
    }

    // What decides the arrangement: the windows, their column and row, their sizes. A title changing is not in it.
    readonly property string layoutKey: {
        const parts = [Math.round(root.fitWidth), Math.round(root.fitHeight), Math.round(root.outputWidth), Math.round(root.outputHeight)]
        for (const window of root.windows) {
            const layout = window.layout ?? ({})
            const pos = layout.pos_in_scrolling_layout, size = layout.tile_size, at = layout.tile_pos_in_workspace_view
            parts.push([window.id, window.is_floating ? 1 : 0, Array.isArray(pos) ? pos.join(".") : "-",
                Array.isArray(size) ? Math.round(size[0]) + "x" + Math.round(size[1]) : "-",
                Array.isArray(at) ? Math.round(at[0]) + "," + Math.round(at[1]) : "-"].join(":"))
        }
        return parts.join("|")
    }
    property var tiles: []
    readonly property bool empty: root.windows.length === 0

    function rebuild(): void {
        const columns = {}
        const floating = []
        for (const window of root.windows) {
            const layout = window.layout ?? ({})
            if (window.is_floating) { floating.push(window); continue }
            const pos = layout.pos_in_scrolling_layout
            const at = Array.isArray(pos) ? Number(pos[0]) : 1
            if (!columns[at]) columns[at] = { index: at, width: 0, tiles: [] }
            const size = layout.tile_size
            columns[at].width = Math.max(columns[at].width, Array.isArray(size) ? Number(size[0]) : root.outputWidth / 2)
            columns[at].tiles.push({ window: window, row: Array.isArray(pos) ? Number(pos[1]) : 1,
                height: Array.isArray(size) ? Number(size[1]) : root.outputHeight })
        }
        const list = Object.values(columns).sort((a, b) => a.index - b.index)
        const g = root.gapOut
        const stripWidth = list.reduce((sum, column) => sum + column.width + g, g)
        // The card is as tall as what Niri actually holds (the edge's struts leave windows short of the screen), so
        // there is no dead band under them; a narrow strip is centred in a card worth looking at.
        let stripHeight = g
        for (const column of list) {
            const heightSum = column.tiles.reduce((sum, tile) => sum + tile.height, 0) + g * (column.tiles.length + 1)
            stripHeight = Math.max(stripHeight, Math.min(root.outputHeight, heightSum))
        }
        for (const window of floating) {
            const at = window.layout?.tile_pos_in_workspace_view, size = window.layout?.tile_size
            if (Array.isArray(at) && Array.isArray(size)) stripHeight = Math.max(stripHeight, Math.min(root.outputHeight, Number(at[1]) + Number(size[1]) + g))
        }
        const contentWidth = list.length === 0 ? root.outputWidth : Math.max(stripWidth, root.outputWidth * 0.6)
        const contentHeight = list.length === 0 ? root.outputHeight : Math.max(root.outputHeight * 0.5, stripHeight)
        const s = Math.min(root.fitWidth / contentWidth, root.fitHeight / contentHeight)
        const shiftX = Math.max(0, (contentWidth - stripWidth) / 2)
        const out = []
        let x = g + shiftX
        for (const column of list) {
            column.tiles.sort((a, b) => a.row - b.row)
            const heightSum = column.tiles.reduce((sum, tile) => sum + tile.height, 0)
            const room = root.outputHeight - g * (column.tiles.length + 1)
            const fit = column.tiles.length > 1 && heightSum > room ? room / heightSum : 1
            let y = g
            for (const tile of column.tiles) {
                const h = tile.height * fit
                out.push({ id: tile.window.id, appId: String(tile.window.app_id ?? ""), floating: false,
                    x: Math.round(x * s), y: Math.round(y * s),
                    w: Math.max(8, Math.round(column.width * s)), h: Math.max(8, Math.round(h * s)) })
                y += h + g
            }
            x += column.width + g
        }
        for (const window of floating) {
            const layout = window.layout ?? ({})
            const at = layout.tile_pos_in_workspace_view, size = layout.tile_size
            if (!Array.isArray(at) || !Array.isArray(size)) continue
            out.push({ id: window.id, appId: String(window.app_id ?? ""), floating: true,
                x: Math.round(Number(at[0]) * s), y: Math.round(Number(at[1]) * s),
                w: Math.max(8, Math.round(Number(size[0]) * s)), h: Math.max(8, Math.round(Number(size[1]) * s)) })
        }
        root.scaleOut = s
        root.cardWidth = Math.max(Math.round(120 * root.d), Math.round(contentWidth * s))
        root.cardHeight = Math.max(Math.round(80 * root.d), Math.round(contentHeight * s))
        root.tiles = out
    }
    onLayoutKeyChanged: root.rebuild()
    Component.onCompleted: root.rebuild()

    // The card itself: the desktop it stands for, under a quiet veil so the pictures lead.
    ClippingRectangle {
        id: face
        anchors.fill: parent
        radius: IrisStyle.radiusCard
        color: IrisStyle.fillQuiet

        Image {
            anchors.fill: parent
            visible: root.showWallpaper
            source: root.showWallpaper ? WallpaperListener.wallpaperUrlForScreen(root.screen) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: true
            sourceSize: Qt.size(Math.max(64, Math.ceil(root.fitWidth * root.dpr / 32) * 32),
                Math.max(64, Math.ceil(root.fitHeight * root.dpr / 32) * 32))
        }
        Rectangle {
            anchors.fill: parent
            color: IrisStyle.veil
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            onClicked: root.cardClicked()
        }

        Repeater {
            model: root.tiles
            IrisOrbitThumb {
                id: tile
                required property var modelData
                readonly property var window: root.windowMap[tile.modelData.id] ?? ({})
                x: tile.modelData.x
                y: tile.modelData.y
                width: tile.modelData.w
                height: tile.modelData.h
                z: tile.cursor ? 3 : tile.modelData.floating ? 2 : 1
                windowId: tile.modelData.id
                appId: tile.modelData.appId
                title: String(tile.window.title ?? "").trim() || tile.modelData.appId
                previews: root.previews
                cornerRadius: Math.max(3, Math.min(IrisStyle.radiusTile, Math.round(Math.min(width, height) * 0.06)))
                // Decoded at the size it has on the largest card, so moving between cards never decodes again.
                decodeSize: Qt.size(Math.max(64, Math.min(1280, Math.ceil(tile.modelData.w * root.dpr / 32) * 32)),
                    Math.max(64, Math.min(1280, Math.ceil(tile.modelData.h * root.dpr / 32) * 32)))
                cursor: root.cursorId === tile.modelData.id
                dimmed: root.matches !== null && root.matches[tile.modelData.id] !== true
                dimOpacity: root.dimOpacity
                titled: root.titleMode === "always" || (root.titleMode === "hover" && (tile.cursor || (tile.hovered && root.interactive)))

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: tile.title
                    onEntered: root.windowHovered(tile.modelData.id)
                    onClicked: mouse => root.windowClicked(tile.modelData.id, mouse.button)
                }
            }
        }

        // A workspace with nothing on it says so, in the card's own middle.
        IrisText {
            anchors.centerIn: parent
            // A neighbour drawn small says it in its caption instead: text under a scale smears.
            visible: root.empty && root.interactive
            text: Translation.tr("Empty")
            color: IrisStyle.onMediaSecondary
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
    }
}
