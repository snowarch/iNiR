pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.control
import qs.modules.iris.style

// Settings › Control Center: what a panel carries, as a list in its own order instead of a wall of numbered chips.
// Each row names the control and what it does; drag one (or Alt and the arrows) to move it, × or Delete to take it
// off. "Add" opens the rest in place, grouped the way the panel thinks of them (Connections, System, Display...).
//   spec.current()  the ids in use, read the way the panel reads them (aliases and old configs resolved)
//   spec.choices    { value, label, glyph, description, category }, every id the list can hold
//   spec.groups     { id, label } in the order the picker shows them; spec.limit caps how many it carries
ColumnLayout {
    id: root

    property var spec: ({})
    readonly property real d: IrisStyle.settingsDensity
    readonly property var picked: { Config.revision; return Array.from(root.spec.current?.() ?? []).map(String) }
    readonly property var choices: Array.from(root.spec.choices ?? [])
    readonly property int limit: Number(root.spec.limit ?? 0)
    readonly property bool full: root.limit > 0 && root.picked.length >= root.limit
    readonly property var rest: root.choices.filter(choice => !root.picked.includes(String(choice.value)))
    readonly property real rowHeight: Math.round(56 * root.d)
    property bool adding: false
    property int dragFrom: -1
    property int dragTo: -1
    // The row the keyboard was on: a move or a removal rebuilds rows, and the focus comes back to it (or to the row
    // that took its place) instead of falling out of the list after the first press.
    property string keyed: ""

    function choiceOf(id: string): var { return root.choices.find(choice => String(choice.value) === id) ?? ({ value: id, label: id }) }
    function write(next: var): void { IrisOptions.commit(root.spec, next) }
    function slotOf(index: int): int {
        if (root.dragFrom < 0 || index === root.dragFrom) return index
        if (root.dragFrom < root.dragTo && index > root.dragFrom && index <= root.dragTo) return index - 1
        if (root.dragFrom > root.dragTo && index >= root.dragTo && index < root.dragFrom) return index + 1
        return index
    }
    function move(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || to >= root.picked.length) return
        const next = root.picked.slice()
        const moved = next.splice(from, 1)[0]
        next.splice(to, 0, moved)
        root.write(next)
        root.refocus(moved)
    }
    function remove(id: string): void {
        const at = root.picked.indexOf(id)
        const next = root.picked.filter(value => value !== id)
        root.write(next)
        if (root.keyed === id) root.refocus(next[Math.min(at, next.length - 1)] ?? "")
    }
    function add(id: string): void {
        if (root.full || root.picked.includes(id)) return
        root.write(root.picked.concat([id]))
        if (root.limit > 0 && root.picked.length + 1 >= root.limit) root.adding = false
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

    spacing: 0

    Item {
        id: list
        Layout.fillWidth: true
        implicitHeight: root.picked.length * root.rowHeight
        visible: root.picked.length > 0

        Repeater {
            id: rows
            model: ScriptModel { values: root.picked }
            Item {
                id: row
                required property string modelData
                required property int index
                readonly property var choice: root.choiceOf(row.modelData)
                readonly property bool dragged: root.dragFrom === row.index
                property real dragY: 0

                width: list.width
                height: root.rowHeight
                y: row.dragged ? row.dragY : root.slotOf(row.index) * root.rowHeight
                z: row.dragged ? 2 : 1
                Behavior on y {
                    enabled: !row.dragged
                    NumberAnimation { duration: 180; easing.type: IrisStyle.feedbackEasing }
                }

                activeFocusOnTab: true
                Accessible.role: Accessible.ListItem
                Accessible.name: Translation.tr(String(row.choice.label))
                Accessible.description: Translation.tr(String(row.choice.description ?? ""))
                onActiveFocusChanged: if (activeFocus) root.keyed = row.modelData
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                        root.move(row.index, row.index + (event.key === Qt.Key_Up ? -1 : 1))
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete) {
                        root.remove(row.modelData)
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
                    visible: !row.dragged && root.dragFrom < 0 && (row.index < root.picked.length - 1 || root.rest.length > 0)
                    anchors.left: glyph.left
                    anchors.leftMargin: glyph.width + Math.round(12 * root.d)
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
                MaterialSymbol {
                    id: glyph
                    anchors.left: handle.right
                    anchors.leftMargin: Math.round(10 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(24 * root.d)
                    horizontalAlignment: Text.AlignHCenter
                    text: String(row.choice.glyph ?? "radio_button_unchecked")
                    iconSize: Math.round(22 * root.d)
                    color: IrisStyle.accent
                }
                Column {
                    anchors.left: glyph.right
                    anchors.leftMargin: Math.round(12 * root.d)
                    anchors.right: remove.left
                    anchors.rightMargin: Math.round(12 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * root.d)
                    IrisText {
                        width: parent.width
                        text: Translation.tr(String(row.choice.label))
                        font.pixelSize: IrisStyle.typeBody
                        elide: Text.ElideRight
                    }
                    IrisText {
                        visible: text.length > 0
                        width: parent.width
                        text: Translation.tr(String(row.choice.description ?? ""))
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                        elide: Text.ElideRight
                    }
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
                        const top = row.mapToItem(list, 0, mouse.y).y - grab
                        row.dragY = Math.max(0, Math.min((root.picked.length - 1) * root.rowHeight, top))
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
                    Accessible.name: Translation.tr("Remove %1").arg(Translation.tr(String(row.choice.label)))
                    onClicked: root.remove(row.modelData)
                }
            }
        }
    }

    // The way in to the rest: a quiet row that opens them in place, or says why it cannot.
    IrisButton {
        visible: root.rest.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.round(48 * root.d)
        quiet: true
        enabled: !root.full
        buttonRadius: IrisStyle.radiusTile
        Accessible.name: Translation.tr("Add")
        onClicked: root.adding = !root.adding
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(4 * root.d)
            anchors.rightMargin: Math.round(8 * root.d)
            spacing: Math.round(10 * root.d)
            MaterialSymbol {
                Layout.preferredWidth: Math.round(20 * root.d) + Math.round(10 * root.d) + Math.round(24 * root.d)
                horizontalAlignment: Text.AlignRight
                text: "add_circle"
                iconSize: Math.round(22 * root.d)
                color: root.full ? IrisStyle.muted : IrisStyle.accent
            }
            IrisText {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(2 * root.d)
                text: root.full ? Translation.tr("Full. Remove one to add another.") : Translation.tr("Add")
                color: root.full ? IrisStyle.muted : IrisStyle.accent
                font.pixelSize: IrisStyle.typeBody
                font.weight: root.full ? IrisStyle.weight(Font.Normal) : IrisStyle.weight(Font.DemiBold)
            }
            MaterialSymbol {
                visible: !root.full
                text: "expand_more"
                rotation: root.adding ? 180 : 0
                iconSize: Math.round(20 * root.d)
                color: IrisStyle.muted
                Behavior on rotation { NumberAnimation { duration: 160; easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }

    // What is left, in the panel's own groups, two across when there is room.
    ColumnLayout {
        id: picker
        visible: root.adding && !root.full && root.rest.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Math.round(4 * root.d)
        Layout.bottomMargin: Math.round(8 * root.d)
        spacing: Math.round(12 * root.d)
        readonly property int across: width >= Math.round(560 * root.d) ? 2 : 1

        Repeater {
            model: picker.visible ? Array.from(root.spec.groups ?? [{ id: "", label: "" }]) : []
            ColumnLayout {
                id: band
                required property var modelData
                readonly property var members: root.rest.filter(choice => !band.modelData.id || String(choice.category ?? "") === band.modelData.id)
                visible: band.members.length > 0
                Layout.fillWidth: true
                spacing: Math.round(4 * root.d)

                IrisText {
                    visible: String(band.modelData.label ?? "").length > 0
                    Layout.leftMargin: Math.round(8 * root.d)
                    text: Translation.tr(String(band.modelData.label ?? ""))
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: picker.across
                    columnSpacing: Math.round(4 * root.d)
                    rowSpacing: Math.round(2 * root.d)
                    Repeater {
                        model: band.members
                        IrisButton {
                            id: option
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: Math.round(52 * root.d)
                            quiet: true
                            buttonRadius: IrisStyle.radiusTile
                            Accessible.name: Translation.tr("Add %1").arg(Translation.tr(String(option.modelData.label)))
                            Accessible.description: Translation.tr(String(option.modelData.description ?? ""))
                            onClicked: root.add(String(option.modelData.value))
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * root.d)
                                anchors.rightMargin: Math.round(8 * root.d)
                                spacing: Math.round(12 * root.d)
                                MaterialSymbol {
                                    Layout.preferredWidth: Math.round(24 * root.d)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: String(option.modelData.glyph ?? "add")
                                    iconSize: Math.round(22 * root.d)
                                    color: IrisStyle.subtext
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(2 * root.d)
                                    IrisText {
                                        Layout.fillWidth: true
                                        text: Translation.tr(String(option.modelData.label))
                                        font.pixelSize: IrisStyle.typeBody
                                        elide: Text.ElideRight
                                    }
                                    IrisText {
                                        visible: text.length > 0
                                        Layout.fillWidth: true
                                        text: Translation.tr(String(option.modelData.description ?? ""))
                                        color: IrisStyle.muted
                                        font.pixelSize: IrisStyle.typeMeta
                                        elide: Text.ElideRight
                                    }
                                }
                                MaterialSymbol {
                                    text: "add"
                                    iconSize: Math.round(18 * root.d)
                                    color: IrisStyle.accent
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
