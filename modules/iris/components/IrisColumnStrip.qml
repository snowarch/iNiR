pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.pieces

// One workspace of Niri as Niri lays it: its tiled columns in order, widths from `tile_size` against the
// output's width, stacked tiles splitting the height. Niri does not publish the strip's view offset, so a
// strip wider than this item slides to keep the focused column in view. No captures: every tile is an app
// icon and, when wide enough, a name. The columns are rebuilt only when the layout changes, never when a
// title does, so a terminal that retitles itself every second does not rebuild its tiles.
Item {
    id: root

    property int workspaceId: -1
    property var windows: []
    property string outputName: ""
    property bool active: false
    // The largest app icon a tile shows, in density-scaled pixels; a taller strip asks for more.
    property real maxIcon: 22
    // Name a tile by its window's title (the app when it has none) instead of by its app.
    property bool preferTitles: false
    // Show every column, narrowed together to fit, instead of sliding a strip wider than this item.
    property bool fit: false
    // The tile the keyboard is on, ringed in the accent (the focused window is tinted).
    property int cursorWindowId: -1
    readonly property real d: IrisStyle.density
    readonly property real outputWidth: Math.max(1, Number(NiriService.outputs?.[root.outputName]?.logical?.width ?? 1920))
    readonly property real unit: root.width / root.outputWidth
    readonly property real gap: Math.round(4 * root.d)
    // While a card or Orbit holds the keyboard nothing is focused for Niri: the workspace's last focused window stands in.
    readonly property int lastFocusedId: root.active ? Number(NiriService.workspaces?.[root.workspaceId]?.active_window_id ?? -1) : -1

    readonly property var windowMap: {
        const map = {}
        for (const window of root.windows) if (window.workspace_id === root.workspaceId) map[window.id] = window
        return map
    }
    function isFocused(window: var): bool {
        return (window?.is_focused ?? false) || (window !== undefined && window?.id === root.lastFocusedId)
    }
    function nameOf(window: var): string {
        const id = String(window?.app_id ?? "")
        const app = AppSearch.lookupDesktopEntry(id)?.name ?? id
        if (!root.preferTitles) return app
        const title = String(window?.title ?? "").trim()
        return title.length > 0 ? title : app
    }

    // What decides the shape of the strip: which windows, in which column and row, how wide, who is focused, how wide the item is.
    readonly property string layoutKey: {
        const parts = [Math.round(root.width), root.lastFocusedId, root.fit]
        for (const window of root.windows) {
            if (window.workspace_id !== root.workspaceId || window.is_floating) continue
            const pos = window.layout?.pos_in_scrolling_layout
            const size = window.layout?.tile_size
            parts.push(window.id + ":" + (Array.isArray(pos) ? pos[0] + "." + pos[1] : "-") + ":" + (Array.isArray(size) ? Math.round(size[0]) : "-")
                + (window.is_focused ? "f" : ""))
        }
        return parts.join("|")
    }
    property var columns: []
    function rebuild(): void {
        const grouped = {}
        for (const window of root.windows) {
            if (window.workspace_id !== root.workspaceId || window.is_floating) continue
            const pos = window.layout?.pos_in_scrolling_layout
            const column = Array.isArray(pos) ? Number(pos[0]) : 1
            if (!grouped[column]) grouped[column] = { index: column, width: 0, tiles: [] }
            const size = window.layout?.tile_size
            grouped[column].width = Math.max(grouped[column].width, Array.isArray(size) ? Number(size[0]) : root.outputWidth / 2)
            grouped[column].tiles.push({ id: window.id, row: Array.isArray(pos) ? Number(pos[1]) : 1, focused: root.isFocused(window) })
        }
        const list = Object.values(grouped).sort((a, b) => a.index - b.index)
        const minimum = Math.round(30 * root.d)
        let squeeze = 1
        if (root.fit && list.length > 0) {
            const natural = list.reduce((sum, column) => sum + Math.max(minimum, column.width * root.unit - root.gap) + root.gap, 0) - root.gap
            if (natural > root.width) squeeze = Math.max(0.1, (root.width - root.gap * (list.length - 1)) / (natural - root.gap * (list.length - 1)))
        }
        let x = 0
        for (const column of list) {
            column.tiles.sort((a, b) => a.row - b.row)
            column.focused = column.tiles.some(tile => tile.focused)
            column.x = x
            column.w = Math.max(minimum, Math.round((column.width * root.unit - root.gap) * squeeze))
            x += column.w + root.gap
        }
        root.columns = list
    }
    onLayoutKeyChanged: root.rebuild()
    Component.onCompleted: root.rebuild()

    readonly property real total: root.columns.length > 0
        ? root.columns[root.columns.length - 1].x + root.columns[root.columns.length - 1].w : 0
    readonly property real offset: {
        if (root.total <= root.width) return 0
        const focus = root.columns.find(column => column.focused) ?? root.columns[root.columns.length - 1]
        return Math.max(0, Math.min(root.total - root.width, focus.x + focus.w - root.width))
    }

    signal windowActivated(int windowId)
    signal windowMiddleClicked(int windowId)

    clip: true

    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.radiusRow
        color: IrisStyle.fillQuiet
        visible: root.columns.length === 0
        IrisText {
            anchors.centerIn: parent
            text: Translation.tr("Empty")
            role: IrisText.Meta
        }
    }
    Repeater {
        model: root.columns
        Item {
            id: columnItem
            required property var modelData
            x: columnItem.modelData.x - root.offset
            width: columnItem.modelData.w
            height: root.height
            Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Repeater {
                model: columnItem.modelData.tiles
                MouseArea {
                    id: tileTap
                    required property var modelData
                    required property int index
                    readonly property var window: root.windowMap[tileTap.modelData.id] ?? ({})
                    readonly property int count: columnItem.modelData.tiles.length
                    readonly property bool focused: tileTap.modelData.focused
                    readonly property bool cursor: tileTap.modelData.id === root.cursorWindowId
                    x: 0
                    y: tileTap.index * (root.height + root.gap) / tileTap.count
                    width: columnItem.width
                    height: (root.height + root.gap) / tileTap.count - root.gap
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: String(tileTap.window.title ?? tileTap.window.app_id ?? "")
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) root.windowMiddleClicked(tileTap.modelData.id)
                        else root.windowActivated(tileTap.modelData.id)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(IrisStyle.radiusRow, height / 2)
                        color: tileTap.focused ? IrisStyle.tintFill(IrisStyle.accent)
                            : tileTap.containsMouse || tileTap.cursor ? IrisStyle.fillHover : IrisStyle.fill
                        border.width: tileTap.cursor ? 2 : tileTap.focused ? 1 : 0
                        border.color: IrisStyle.accent
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                        Row {
                            anchors.centerIn: parent
                            spacing: Math.round(6 * root.d)
                            SmartAppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: IrisPieces.appIcon(String(tileTap.window.app_id ?? ""))
                                fallback: "application-x-executable"
                                iconSize: Math.max(10, Math.min(Math.round(root.maxIcon * root.d), tileTap.height - Math.round(8 * root.d), tileTap.width - Math.round(8 * root.d)))
                            }
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: tileTap.width > Math.round(96 * root.d)
                                width: Math.min(implicitWidth, tileTap.width - Math.round(44 * root.d))
                                text: root.nameOf(tileTap.window)
                                font.pixelSize: IrisStyle.typeFootnote
                                color: tileTap.focused ? IrisStyle.text : IrisStyle.subtext
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
