pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's tasks: a checklist where each line is closed with a seal. How many are left is the hero figure leaning, with
// the list's name as a ruby; each task is a line with its seal box at the start, stamped when it is done (the words then
// go to the third ink and are struck), and parted from the next by a hairline. A key at the foot opens a line to write a
// new one; a right tap on a task takes it away. The engine's face keeps the list and the adding.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var entries: root.face?.entries ?? []
    readonly property bool adding: root.face?.adding ?? false
    readonly property bool empty: root.entries.length === 0 && !root.adding

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "message"
    }
    Row {
        id: head
        x: root.pad
        // With nothing left the count goes and the label sits level with the key.
        y: root.empty ? root.pad + Math.round((root.dp(26) - height) / 2) : root.pad
        spacing: root.dp(6)
        AText {
            id: count
            visible: !root.empty
            voice: "figure"
            lean: Airisu.lean
            size: root.px(root.small ? 34 : 40)
            color: stock.ink
            text: root.face?.pending ?? 0
        }
        AText {
            anchors.baseline: root.empty ? undefined : count.baseline
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: Translation.tr("Tasks")
        }
    }
    // The key that opens a new line.
    Item {
        id: add
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: root.pad
        width: root.dp(26)
        height: width
        AKey {
            id: plate
            anchors.fill: parent
            lacquer: "transparent"
            under: stock.lacquer
            hovered: addHover.hovered
            pressed: addTap.pressed
        }
        ADie {
            x: plate.shift
            y: plate.shift
            width: parent.width
            height: parent.height
            kind: "chamfer"
            cut: Airisu.cutFor(height)
            stroke: stock.inkThird
            strokeWidth: Airisu.hair
        }
        MaterialSymbol {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: plate.shift
            anchors.verticalCenterOffset: plate.shift
            text: "add"
            iconSize: root.px(16)
            color: stock.ink
        }
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr("New task")
        HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: addTap; onTapped: root.face?.beginAdding() }
    }

    ABlank {
        visible: root.empty
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        face: root.face
        stock: stock
        label: Translation.tr("All done")
        line: Translation.tr("Nothing waiting on you")
    }
    Column {
        x: root.pad
        y: head.y + head.height + root.dp(8)
        width: root.width - 2 * root.pad
        Repeater {
            model: root.entries
            Item {
                id: task
                required property var modelData
                required property int index
                width: parent.width
                height: root.dp(24)
                Rectangle {
                    visible: task.index > 0
                    width: parent.width
                    height: Airisu.hair
                    color: stock.inkThird
                    antialiasing: false
                }
                ASeal {
                    id: box
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dp(12)
                    height: width
                    stamped: task.modelData.done
                    rule: stock.inkSecond
                }
                AText {
                    x: box.width + root.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    size: IrisStyle.typeLabel
                    font.weight: Font.Medium
                    font.strikeout: task.modelData.done
                    color: task.modelData.done ? stock.inkThird : stock.ink
                    text: String(task.modelData.content ?? "")
                }
                Accessible.role: Accessible.CheckBox
                Accessible.checked: task.modelData.done
                Accessible.name: String(task.modelData.content ?? "")
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (point, button) => {
                        if (button === Qt.RightButton) Todo.deleteItem(task.modelData.originalIndex)
                        else if (task.modelData.done) Todo.markUnfinished(task.modelData.originalIndex)
                        else Todo.markDone(task.modelData.originalIndex)
                    }
                }
            }
        }
        // The line a new task is written on.
        Item {
            visible: root.adding
            width: parent.width
            height: root.dp(26)
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Airisu.hair; color: stock.ink; antialiasing: false }
            TextInput {
                id: entry
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: stock.ink
                selectionColor: Airisu.seal
                selectedTextColor: Airisu.inkOnSeal
                font.family: Airisu.textFace
                font.pixelSize: IrisStyle.typeLabel
                clip: true
                Keys.onReturnPressed: root.face?.commit(entry.text)
                Keys.onEnterPressed: root.face?.commit(entry.text)
                Keys.onEscapePressed: if (root.face) root.face.adding = false
                onActiveFocusChanged: if (!activeFocus && text.trim().length === 0 && root.face) root.face.adding = false
                AText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entry.text.length === 0
                    size: IrisStyle.typeLabel
                    color: stock.inkThird
                    text: Translation.tr("New task")
                }
            }
            onVisibleChanged: if (visible) { entry.text = ""; focusLater.restart() }
            Timer { id: focusLater; interval: 0; onTriggered: entry.forceActiveFocus() }
        }
    }
}
