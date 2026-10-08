pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    property bool adding: false
    readonly property int capacity: root.small ? 3 : root.medium ? 4 : 8
    readonly property var entries: {
        const pending = root.widget.taskEntries.filter(entry => !entry.done)
        const done = root.widget.showCompleted ? root.widget.taskEntries.filter(entry => entry.done) : []
        return pending.concat(done).slice(0, root.capacity)
    }
    readonly property int pending: root.widget.pendingCount

    function beginAdding(): void {
        root.adding = true
    }
    function commit(text: string): void {
        if (text.trim().length > 0)
            Todo.addTask(text.trim())
        root.adding = false
    }

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void { root.adding = false }
    }

    component Task: RowLayout {
        id: task
        required property var modelData
        spacing: root.dp(9)
        HoverHandler { id: taskHover }
        Rectangle {
            Layout.preferredWidth: root.dp(18)
            Layout.preferredHeight: root.dp(18)
            radius: width / 2
            color: task.modelData.done ? root.accent : "transparent"
            border.width: task.modelData.done ? 0 : Math.max(1.5, root.dp(1.6))
            border.color: checkHover.hovered ? root.accent : root.fillActive
            MaterialSymbol {
                anchors.centerIn: parent
                visible: task.modelData.done
                text: "check"
                iconSize: parent.width * 0.78
                color: root.onFill(root.accent)
            }
            HoverHandler { id: checkHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                gesturePolicy: TapHandler.WithinBounds
                onTapped: task.modelData.done ? Todo.markUnfinished(task.modelData.originalIndex)
                    : Todo.markDone(task.modelData.originalIndex)
            }
            Accessible.role: Accessible.CheckBox
            Accessible.checked: task.modelData.done
            Accessible.name: task.modelData.content
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: task.modelData.content
            color: task.modelData.done ? root.inkTertiary : root.ink
            size: 13
            font.strikeout: task.modelData.done
        }
        MaterialSymbol {
            visible: taskHover.hovered && !root.small
            text: "close"
            iconSize: root.px(15)
            color: removeHover.hovered ? root.danger : root.inkTertiary
            HoverHandler { id: removeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Todo.deleteItem(task.modelData.originalIndex) }
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Delete")
        }
    }

    component Tasks: ColumnLayout {
        id: tasks
        spacing: root.dp(7)
        Connections {
            target: root
            function onAddingChanged(): void {
                if (root.adding && tasks.visible)
                    Qt.callLater(() => entry.forceActiveFocus())
                else
                    entry.text = ""
            }
        }
        Repeater {
            model: root.adding ? [] : root.entries
            Task { Layout.fillWidth: true }
        }
        FaceText {
            face: root
            visible: !root.adding && root.entries.length === 0
            Layout.fillWidth: true
            text: Translation.tr("All done")
            color: root.inkTertiary
            size: 12.5
        }
        Rectangle {
            visible: root.adding
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            radius: root.innerRadius
            color: root.fill
            TextInput {
                id: entry
                anchors.fill: parent
                anchors.leftMargin: root.dp(10)
                anchors.rightMargin: root.dp(10)
                verticalAlignment: TextInput.AlignVCenter
                color: root.ink
                selectionColor: root.accent
                selectedTextColor: root.onFill(root.accent)
                font.family: root.fontMain
                font.pixelSize: root.px(13)
                clip: true
                Keys.onReturnPressed: root.commit(entry.text)
                Keys.onEnterPressed: root.commit(entry.text)
                Keys.onEscapePressed: root.adding = false
                onActiveFocusChanged: if (!activeFocus && text.trim().length === 0) root.adding = false
                FaceText {
                    face: root
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entry.text.length === 0
                    text: Translation.tr("New task")
                    color: root.inkTertiary
                    size: 13
                }
            }
        }
    }

    component Count: ColumnLayout {
        spacing: 0
        MaterialSymbol {
            text: "checklist"
            fill: 1
            iconSize: root.px(22)
            color: root.accent
        }
        FaceFigure {
            face: root
            text: root.pending
            size: 38
            color: root.accent
        }
        FaceText {
            face: root
            text: Translation.tr("Tasks")
            size: 13
            weight: Font.DemiBold
        }
    }

    component Add: FaceAction {
        face: root
        glyph: "add"
        name: Translation.tr("New task")
        tint: root.accent
        onActivated: root.beginAdding()
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(8)
        RowLayout {
            Layout.fillWidth: true
            FaceHeader {
                face: root
                Layout.fillWidth: true
                glyph: "checklist"
                text: Translation.tr("Tasks")
            }
            FaceFigure {
                face: root
                text: root.pending
                size: 22
                color: root.accent
            }
        }
        Tasks { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
    }

    RowLayout {
        visible: root.medium
        anchors.fill: parent
        spacing: root.dp(16)
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: root.contentWidth * 0.26
            Layout.fillHeight: true
            Count { Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            Add {}
        }
        Tasks {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
        }
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(10)
        RowLayout {
            Layout.fillWidth: true
            FaceHeader {
                face: root
                Layout.fillWidth: true
                glyph: "checklist"
                text: Translation.tr("Tasks")
            }
            FaceFigure {
                face: root
                text: root.pending
                size: 26
                color: root.accent
            }
        }
        Tasks { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Add {}
            FaceText {
                face: root
                Layout.fillWidth: true
                text: Translation.tr("New task")
                color: root.accent
                size: 13
                weight: Font.DemiBold
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.beginAdding() }
            }
        }
    }
}
