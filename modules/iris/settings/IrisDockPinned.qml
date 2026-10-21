pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Dock › Apps: the pinned apps in their Dock order (dock.pinnedApps, shared with Material). Drag a row to
// move it; with a row in focus, Alt and the arrows move it and Delete unpins it. The order is written once, on drop.
Item {
    id: root

    property var spec: ({})
    readonly property real d: IrisStyle.settingsDensity
    readonly property var pinned: (Config.options?.dock?.pinnedApps ?? []).map(String)
    readonly property real rowHeight: Math.round(52 * root.d)
    property int dragFrom: -1
    property int dragTo: -1
    // The pin the keyboard was on: a move or an unpin rebuilds its row, and the focus goes back to it (or, after an
    // unpin, to the one that took its place) instead of falling out of the list after the first press.
    property string keyed: ""

    implicitHeight: Math.max(1, root.pinned.length) * root.rowHeight

    // Where a row sits while another is dragged: the ones it passes step aside.
    function slotOf(index: int): int {
        if (root.dragFrom < 0 || index === root.dragFrom) return index
        if (root.dragFrom < root.dragTo && index > root.dragFrom && index <= root.dragTo) return index - 1
        if (root.dragFrom > root.dragTo && index >= root.dragTo && index < root.dragFrom) return index + 1
        return index
    }
    function move(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || to >= root.pinned.length) return
        const next = root.pinned.slice()
        const moved = next.splice(from, 1)[0]
        next.splice(to, 0, moved)
        Config.setNestedValue("dock.pinnedApps", next)
        root.refocus(moved)
    }
    function unpin(id: string): void {
        const at = root.pinned.indexOf(id)
        const rest = root.pinned.filter(value => value !== id)
        Config.setNestedValue("dock.pinnedApps", rest)
        if (root.keyed === id) root.refocus(rest[Math.min(at, rest.length - 1)] ?? "")
    }
    function refocus(id: string): void {
        root.keyed = id
        Qt.callLater(() => {
            for (let i = 0; i < rows.count; i++) {
                const item = rows.itemAt(i)
                if (item && item.modelData === root.keyed) { item.forceActiveFocus(); return }
            }
        })
    }

    IrisText {
        visible: root.pinned.length === 0
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: Translation.tr("Nothing pinned. Right-click an app in the Dock to keep it there.")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeBody
        elide: Text.ElideRight
    }

    Repeater {
        id: rows
        model: ScriptModel { values: root.pinned }
        Item {
            id: row
            required property string modelData
            required property int index
            // The Dock's own answer for the id (AppSearch.lookupDesktopEntry finds "code" by its Exec), so a pin reads
            // here as it does there. One whose app is gone keeps its place with a generic icon until it is unpinned.
            readonly property var who: AppSearch.appIdentity(row.modelData, "")
            readonly property string name: row.who.name
            readonly property bool dragged: root.dragFrom === row.index
            property real dragY: 0

            width: root.width
            height: root.rowHeight
            y: row.dragged ? row.dragY : root.slotOf(row.index) * root.rowHeight
            z: row.dragged ? 2 : 1
            Behavior on y {
                enabled: !row.dragged
                NumberAnimation { duration: 180; easing.type: IrisStyle.feedbackEasing }
            }

            activeFocusOnTab: true
            Accessible.role: Accessible.ListItem
            Accessible.name: row.who.installed ? row.name : row.name + ", " + Translation.tr("Not installed")
            onActiveFocusChanged: if (activeFocus) root.keyed = row.modelData
            Keys.onPressed: event => {
                if ((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                    root.move(row.index, row.index + (event.key === Qt.Key_Up ? -1 : 1))
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete) {
                    root.unpin(row.modelData)
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.radiusTile
                color: IrisStyle.fill
                opacity: row.dragged ? 1 : row.activeFocus ? 0.6 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: IrisStyle.feedbackEasing } }
            }
            Rectangle {
                visible: !row.dragged && root.dragFrom < 0 && row.index < root.pinned.length - 1
                anchors.left: mark.left
                anchors.leftMargin: mark.width + Math.round(12 * root.d)
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: IrisStyle.hairline
            }

            MaterialSymbol {
                id: handle
                anchors.left: parent.left
                anchors.leftMargin: Math.round(4 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: "drag_indicator"
                iconSize: Math.round(20 * root.d)
                color: IrisStyle.muted
            }
            IrisImage {
                id: mark
                anchors.left: handle.right
                anchors.leftMargin: Math.round(8 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(32 * root.d)
                height: width
                source: row.who.icon
                fillMode: Image.PreserveAspectFit
                opacity: row.who.installed ? 1 : 0.45
            }
            IrisText {
                anchors.left: mark.right
                anchors.leftMargin: Math.round(12 * root.d)
                anchors.right: gone.visible ? gone.left : remove.left
                anchors.rightMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: row.name
                color: row.who.installed ? IrisStyle.text : IrisStyle.muted
                font.pixelSize: IrisStyle.typeBody
                elide: Text.ElideRight
            }
            IrisText {
                id: gone
                visible: !row.who.installed
                anchors.right: remove.left
                anchors.rightMargin: Math.round(8 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Not installed")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }

            MouseArea {
                anchors.left: parent.left
                anchors.right: remove.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                property real grab: 0
                onPressed: mouse => {
                    row.forceActiveFocus()
                    grab = mouse.y
                    row.dragY = row.y
                    root.dragTo = row.index
                    root.dragFrom = row.index
                }
                onPositionChanged: mouse => {
                    if (!pressed) return
                    const top = row.mapToItem(root, 0, mouse.y).y - grab
                    row.dragY = Math.max(0, Math.min((root.pinned.length - 1) * root.rowHeight, top))
                    root.dragTo = Math.round(row.dragY / root.rowHeight)
                }
                onReleased: {
                    const from = root.dragFrom, to = root.dragTo
                    root.dragFrom = -1
                    root.dragTo = -1
                    root.move(from, to)
                }
                onCanceled: { root.dragFrom = -1; root.dragTo = -1 }
            }

            IrisIconButton {
                id: remove
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                materialIcon: "close"
                Accessible.name: Translation.tr("Unpin")
                onClicked: root.unpin(row.modelData)
            }
        }
    }
}
