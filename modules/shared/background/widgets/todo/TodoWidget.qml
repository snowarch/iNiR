pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
AbstractBackgroundWidget {
    id: root

    configEntryName: "todo"
    familyOptions: [
        { key: "showCompleted", raw: true, label: Translation.tr("Show completed"), icon: "task_alt", fallback: true }
    ]

    visibleWhenLocked: false
    needsColText: true
    draggable: GlobalStates.widgetEditMode && !GlobalStates.screenLocked && !root.locked
    resizeMinWidth: 240
    resizeMinHeight: 220
    resizeMaxWidth: 560
    resizeMaxHeight: 720

    property string mode: "list"
    property string editingText: ""
    property bool clearCompletedArmed: false

    readonly property bool instrument: String(root._readConfigKey("style") ?? "card") === "instrument"
    readonly property bool instrumentRules: Boolean(root._readConfigKey("instrumentRules") ?? true)
    readonly property bool showCompleted: Boolean(root._readConfigKey("showCompleted") ?? true)
    readonly property int pendingCount: Todo.list.filter(item => !item.done).length
    readonly property int completedCount: Todo.list.length - root.pendingCount
    readonly property var taskEntries: Todo.list.map((item, originalIndex) => ({
        content: item.content,
        done: item.done,
        originalIndex: originalIndex
    }))
    readonly property var visibleTaskEntries: root.showCompleted
        ? root.taskEntries : root.taskEntries.filter(item => !item.done)
    // With no plate under it (Instrument, or the card turned off) it reads on the wallpaper: sampled ink.
    readonly property color ink: root.widgetInk
    readonly property color inkMuted: root.widgetHasSurface
        ? ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.62) : root.widgetInkMuted
    readonly property color signal: root.widgetAccentVisible

    readonly property color primaryFace: root.widgetSemanticContainer(root.widgetPrimaryRole)
    readonly property color primaryInk: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
    readonly property color secondaryFace: root.widgetSemanticContainer(root.widgetSecondaryRole)
    readonly property color secondaryInk: root.widgetSemanticOnContainer(root.widgetSecondaryRole)
    readonly property real inset: Math.round(12 * root.scaleFactor)
    // medium holds two whole rows under its head: at 48 the second missed its room by 4 px and the card said
    // "2 tasks left" over one
    readonly property real itemHeight: Math.round((root.isSmall ? 36 : !root.isLarge ? 44 : 48) * root.scaleFactor)
    readonly property real taskFontSize: Math.round((root.isSmall ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal) * root.scaleFactor)

    function openNewTask(): void {
        root.editingText = ""
        root.mode = "edit"
        Qt.callLater(() => taskInput.forceActiveFocus())
    }

    function closeEditor(): void {
        root.mode = "list"
        taskFocusSink.forceActiveFocus()
    }

    function saveAndBack(): void {
        const text = root.editingText.trim()
        if (text.length > 0)
            Todo.addTask(text)
        root.closeEditor()
    }

    function requestClearCompleted(): void {
        if (!root.clearCompletedArmed) {
            root.clearCompletedArmed = true
            clearCompletedTimeout.restart()
            return
        }
        clearCompletedTimeout.stop()
        root.clearCompletedArmed = false
        Todo.clearCompleted()
    }

    Timer {
        id: clearCompletedTimeout
        interval: 3000
        repeat: false
        onTriggered: root.clearCompletedArmed = false
    }

    // every task wears one tone: a colour per position said nothing, and the add key is the one primary
    function taskFace(index: int): color {
        return root.secondaryFace
    }

    function taskInk(index: int): color {
        return root.secondaryInk
    }

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void {
            if (GlobalStates.widgetEditMode && root.mode === "edit")
                root.closeEditor()
        }
        function onScreenLockedChanged(): void {
            if (GlobalStates.screenLocked && root.mode === "edit")
                root.closeEditor()
        }
    }

    Item {
        id: taskFocusSink
        focus: false
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                shown: !root.familyFaced && !root.instrument
                    && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
            }
        }
    }

    Item {
        id: stage
        visible: !root.familyFaced
        anchors.fill: parent
        anchors.margins: root.inset

        // Preserve both pages through the fade. Collapsing the entire stage
        // while visibility bindings change immediately produces a blank flash.
        ColumnLayout {
            id: listPage
            anchors.fill: parent
            opacity: root.mode === "list" ? 1 : 0
            visible: opacity > 0
            enabled: root.mode === "list" && !GlobalStates.widgetEditMode
            Behavior on opacity {
                enabled: root.animationsActive
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            spacing: Math.round(9 * root.scaleFactor)

            RowLayout {
                id: listHead
                Layout.fillWidth: true
                spacing: Math.round(6 * root.scaleFactor)

                // its texts fill too: a nested layout is never wider than its children allow, which left the keys mid-card
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    InstrumentLabel {
                        Layout.fillWidth: true
                        visible: root.instrument
                        text: Translation.tr("Tasks / Ledger")
                        color: root.widgetAccentVisible
                        scaleFactor: root.scaleFactor
                        strong: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.instrument
                        text: root.pendingCount === 0 ? Translation.tr("All clear") : Translation.tr("%1 open").arg(root.pendingCount)
                        color: root.ink
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(22 * root.scaleFactor)
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.instrument
                        text: Translation.tr("Tasks")
                        color: root.ink
                        font.family: root.widgetTitleFamily
                        font.pixelSize: Math.round((root.isSmall ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.huge)
                            * root.widgetTitleScale * root.scaleFactor)
                        font.weight: root.widgetTitleWeight
                        font.letterSpacing: root.widgetTitleTracking
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.instrument && (root.pendingCount > 0 || root.completedCount > 0)
                        text: root.pendingCount === 0 && root.completedCount > 0
                            ? Translation.tr("All done · %1 completed").arg(root.completedCount)
                            : root.pendingCount === 1
                            ? Translation.tr("1 task left")
                            : Translation.tr("%1 tasks left").arg(root.pendingCount)
                        color: root.inkMuted
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        font.letterSpacing: root.instrument
                            ? Math.round(1.2 * root.scaleFactor) : 0
                        font.capitalization: root.instrument && !root.familyDesign ? Font.AllUppercase : Font.MixedCase
                    }
                }

                RippleButton {
                    visible: root.completedCount > 0 && !root.isSmall
                    Layout.preferredWidth: Math.round((root.instrument ? 30 : 34) * root.scaleFactor)
                    Layout.preferredHeight: Math.round((root.instrument ? 30 : 34) * root.scaleFactor)
                    buttonRadius: root.instrument ? root.widgetControlRadius : Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(root.ink, 0.1)
                    colRipple: ColorUtils.applyAlpha(root.ink, 0.16)
                    releaseAction: () => root.requestClearCompleted()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.clearCompletedArmed ? "delete_forever" : "delete_sweep"
                        iconSize: Math.round(18 * root.scaleFactor)
                        color: root.clearCompletedArmed ? Appearance.colors.colError : root.inkMuted
                    }
                    StyledToolTip {
                        text: root.clearCompletedArmed
                            ? Translation.tr("Click again to clear completed")
                            : Translation.tr("Clear completed")
                    }
                }

                RippleButton {
                    Layout.preferredWidth: Math.round((root.instrument ? 34 : 38) * root.scaleFactor)
                    Layout.preferredHeight: Math.round((root.instrument ? 34 : 38) * root.scaleFactor)
                    buttonRadius: root.instrument ? root.widgetControlRadius : Appearance.rounding.full
                    colBackground: root.instrument
                        ? ColorUtils.applyAlpha(root.signal, 0.14) : root.primaryFace
                    colBackgroundHover: root.instrument
                        ? ColorUtils.applyAlpha(root.signal, 0.22)
                        : ColorUtils.mix(root.primaryFace, root.primaryInk, 0.9)
                    colRipple: ColorUtils.applyAlpha(root.instrument ? root.signal : root.primaryInk, 0.22)
                    releaseAction: () => root.openNewTask()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "add"
                        iconSize: Math.round(19 * root.scaleFactor)
                        color: root.instrument ? root.signal : root.primaryInk
                    }
                    StyledToolTip { text: Translation.tr("Add task") }
                }
            }

            StyledListView {
                id: todoList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Math.round(6 * root.scaleFactor)
                model: root.visibleTaskEntries

                delegate: SwipeDelegate {
                    id: taskRow
                    required property var modelData
                    required property int index
                    HoverHandler { id: taskHover }
                    // Instrument: no colored pills — quiet rows over the
                    // wallpaper, separated by hairline rules.
                    readonly property color rowInk: root.instrument
                        ? root.ink : root.taskInk(taskRow.index)

                    width: todoList.width
                    // small wraps a task to two lines instead of cutting its words
                    implicitHeight: root.isSmall
                        ? Math.max(root.itemHeight, taskText.implicitHeight + Math.round(14 * root.scaleFactor)) : root.itemHeight
                    // whole rows only: a half row under the plate's edge read as cut
                    visible: taskRow.y + taskRow.height <= todoList.contentY + todoList.height + 1
                    padding: 0
                    background: null
                    clip: true

                    contentItem: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(Appearance.rounding.normal, height / 2)
                            color: root.instrument
                                ? "transparent" : root.taskFace(taskRow.index)
                            opacity: taskRow.modelData.done ? 0.56 : 1
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            visible: root.instrument && root.instrumentRules
                                && taskRow.index < Todo.list.length - 1
                            height: Math.max(1, Math.round(1 * root.scaleFactor))
                            color: ColorUtils.applyAlpha(root.ink, 0.1)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round((root.isSmall ? 6 : 10) * root.scaleFactor)
                            anchors.rightMargin: Math.round((root.isSmall ? 8 : 12) * root.scaleFactor)
                            spacing: Math.round((root.isSmall ? 5 : 9) * root.scaleFactor)

                            InstrumentLabel {
                                visible: root.instrument
                                Layout.alignment: Qt.AlignVCenter
                                text: String(taskRow.index + 1).padStart(2, "0")
                                color: root.inkMuted
                                scaleFactor: root.scaleFactor
                            }
                            RippleButton {
                                Layout.preferredWidth: Math.round((root.isSmall ? 22 : 26) * root.scaleFactor)
                                Layout.preferredHeight: Math.round((root.isSmall ? 22 : 26) * root.scaleFactor)
                                Layout.alignment: Qt.AlignVCenter
                                buttonRadius: root.instrument ? Math.round(4 * root.scaleFactor) : Appearance.rounding.full
                                colBackground: taskRow.modelData.done
                                    ? ColorUtils.applyAlpha(root.instrument
                                        ? root.signal : rowInk, 0.16)
                                    : "transparent"
                                colBackgroundHover: ColorUtils.applyAlpha(
                                    root.instrument ? root.signal : rowInk, 0.12)
                                colRipple: ColorUtils.applyAlpha(
                                    root.instrument ? root.signal : rowInk, 0.16)
                                releaseAction: () => {
                                    if (taskRow.modelData.done)
                                        Todo.markUnfinished(taskRow.modelData.originalIndex)
                                    else
                                        Todo.markDone(taskRow.modelData.originalIndex)
                                }
                                contentItem: Item {
                                    anchors.fill: parent
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.round((root.instrument ? 16 : 20) * root.scaleFactor)
                                        height: width
                                        radius: root.instrument ? Math.round(3 * root.scaleFactor) : Appearance.rounding.full
                                        // Instrument check: a hairline circle that
                                        // signals completion in accent ink.
                                        color: root.instrument && taskRow.modelData.done
                                            ? ColorUtils.applyAlpha(root.signal, 0.18) : "transparent"
                                        border.width: Math.max(1, Math.round(2 * root.scaleFactor))
                                        border.color: root.instrument
                                            ? (taskRow.modelData.done
                                                ? root.signal
                                                : ColorUtils.applyAlpha(root.ink, 0.34))
                                            : rowInk
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: taskRow.modelData.done
                                            text: "check"
                                            iconSize: Math.round(15 * root.scaleFactor)
                                            color: root.instrument ? root.signal : rowInk
                                        }
                                    }
                                }
                            }

                            StyledText {
                                id: taskText
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: taskRow.modelData.content
                                color: rowInk
                                elide: Text.ElideRight
                                wrapMode: root.isSmall ? Text.Wrap : Text.NoWrap
                                maximumLineCount: root.isSmall ? 2 : 1
                                font.pixelSize: root.taskFontSize
                                font.strikeout: taskRow.modelData.done
                            }

                            RippleButton {
                                Layout.preferredWidth: Math.round(28 * root.scaleFactor)
                                Layout.preferredHeight: Math.round(28 * root.scaleFactor)
                                Layout.alignment: Qt.AlignVCenter
                                // It takes room only while it shows: a hidden key kept the task's words short.
                                visible: taskRow.modelData.done || taskHover.hovered
                                opacity: taskRow.modelData.done ? 0.78 : 0.58
                                buttonRadius: root.widgetControlRadius
                                colBackground: "transparent"
                                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.12)
                                colRipple: ColorUtils.applyAlpha(Appearance.colors.colError, 0.2)
                                releaseAction: () => Todo.deleteItem(taskRow.modelData.originalIndex)
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: Math.round(17 * root.scaleFactor)
                                    color: taskRow.modelData.done
                                        ? root.inkMuted : Appearance.colors.colError
                                }
                                StyledToolTip { text: Translation.tr("Delete task") }
                            }
                        }
                    }

                    swipe.right: Rectangle {
                        width: Math.round(64 * root.scaleFactor)
                        anchors.right: parent.right
                        height: parent.height
                        radius: Math.min(Appearance.rounding.normal, height / 2)
                        color: Appearance.colors.colError
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: Math.round(19 * root.scaleFactor)
                            color: Appearance.colors.colOnError
                        }
                        SwipeDelegate.onClicked: Todo.deleteItem(taskRow.modelData.originalIndex)
                    }
                }

                WidgetBlank {
                    anchors.fill: parent
                    visible: root.visibleTaskEntries.length === 0
                    widget: root
                    icon: "task_alt"
                    title: Translation.tr("All done")
                    detail: Todo.list.length > 0 && !root.showCompleted
                        ? Translation.tr("Finished tasks are hidden") : Translation.tr("Add a task with +")
                }
            }
        }

        ColumnLayout {
            id: editPage
            anchors.fill: parent
            opacity: root.mode === "edit" ? 1 : 0
            visible: opacity > 0
            enabled: root.mode === "edit" && !GlobalStates.widgetEditMode
            Behavior on opacity {
                enabled: root.animationsActive
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            spacing: Math.round(10 * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true

                RippleButton {
                    Layout.preferredWidth: Math.round(34 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(34 * root.scaleFactor)
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(root.ink, 0.08)
                    colRipple: ColorUtils.applyAlpha(root.ink, 0.12)
                    releaseAction: () => root.closeEditor()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        iconSize: Math.round(18 * root.scaleFactor)
                        color: root.ink
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("New task")
                    color: root.ink
                    font.family: root.widgetTitleFamily
                    font.pixelSize: Math.round(Appearance.font.pixelSize.large
                        * root.widgetTitleScale * root.scaleFactor)
                    font.weight: root.widgetTitleWeight
                    font.letterSpacing: root.widgetTitleTracking
                }

                RippleButton {
                    Layout.preferredWidth: Math.round(38 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(38 * root.scaleFactor)
                    enabled: root.editingText.trim().length > 0
                    opacity: enabled ? 1 : 0.45
                    buttonRadius: Appearance.rounding.full
                    colBackground: root.instrument
                        ? ColorUtils.applyAlpha(root.signal, 0.18) : root.primaryFace
                    colBackgroundHover: root.instrument
                        ? ColorUtils.applyAlpha(root.signal, 0.28)
                        : ColorUtils.mix(root.primaryFace, root.primaryInk, 0.9)
                    colRipple: ColorUtils.applyAlpha(root.instrument ? root.signal : root.primaryInk, 0.16)
                    releaseAction: () => root.saveAndBack()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "check"
                        iconSize: Math.round(19 * root.scaleFactor)
                        color: root.instrument ? root.signal : root.primaryInk
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: root.instrument
                    ? "transparent" : ColorUtils.applyAlpha(root.primaryFace, 0.74)
                border.width: root.instrument && !taskInput.activeFocus
                    ? Math.max(1, Math.round(1 * root.scaleFactor)) : 0
                border.color: ColorUtils.applyAlpha(root.ink, 0.16)

                TextArea {
                    cursorDelegate: TextCursor {}
                    id: taskInput
                    QQC.ContextMenu.menu: null
                    QQC.ContextMenu.onRequested: position => TextEditMenu.open(taskInput, position)
                    anchors.fill: parent
                    anchors.margins: Math.round(10 * root.scaleFactor)
                    text: root.editingText
                    wrapMode: TextArea.Wrap
                    placeholderText: Translation.tr("Type your task…")
                    color: root.primaryInk
                    selectionColor: root.widgetAccent
                    selectedTextColor: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                    background: null
                    onTextChanged: root.editingText = text
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && (event.modifiers & Qt.ControlModifier)) {
                            root.saveAndBack()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeEditor()
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}
