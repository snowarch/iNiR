pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "todo"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 300, contentHeight: 276,
        widgetScale: 100, widgetOpacity: 100, style: "card", instrumentRules: true,
        showCompleted: true,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.14, borderWidth: 1, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 120, y: 180
    })

    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round(Number(root._readConfigKey("contentWidth") ?? 300)
        * root.scaleFactor)
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.round(Number(root._readConfigKey("contentHeight") ?? 276)
        * root.scaleFactor)
    irisFace: Component { IrisTodoFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    irisOptions: [
        { key: "showCompleted", raw: true, label: Translation.tr("Show completed"), icon: "task_alt", fallback: true }
    ]

    visibleWhenLocked: false
    needsColText: true
    draggable: GlobalStates.widgetEditMode && !GlobalStates.screenLocked && !root.locked
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
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
    widgetSurfaceEnabled: !root.instrument
    // Instrument reads on the wallpaper: sampled ink instead of surface ink.
    readonly property color ink: root.instrument ? root.widgetInk : root.widgetSurfaceInk
    readonly property color inkMuted: root.instrument
        ? root.widgetInkMuted : ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.62)
    readonly property color signal: root.widgetAccentVisible

    readonly property color primaryFace: root.widgetSemanticContainer(root.widgetPrimaryRole)
    readonly property color primaryInk: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
    readonly property color secondaryFace: root.widgetSemanticContainer(root.widgetSecondaryRole)
    readonly property color secondaryInk: root.widgetSemanticOnContainer(root.widgetSecondaryRole)
    readonly property color tertiaryFace: root.widgetSemanticContainer(root.widgetTertiaryRole)
    readonly property color tertiaryInk: root.widgetSemanticOnContainer(root.widgetTertiaryRole)
    readonly property real inset: Math.round(12 * root.scaleFactor)
    readonly property real itemHeight: Math.round(48 * root.scaleFactor)

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

    function taskFace(index: int): color {
        switch (index % 3) {
        case 0: return root.tertiaryFace
        case 1: return root.secondaryFace
        default: return root.primaryFace
        }
    }

    function taskInk(index: int): color {
        switch (index % 3) {
        case 0: return root.tertiaryInk
        case 1: return root.secondaryInk
        default: return root.primaryInk
        }
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

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.instrument ? "instrument" : "card"
                    model: [
                        { label: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                        { label: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Show")
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "done_all"
                    label: Translation.tr("Finished tasks")
                    checked: root.showCompleted
                    onToggled: root._setOutputValue("showCompleted", !root.showCompleted)
                }
                WidgetQuickToggle {
                    visible: root.instrument
                    Layout.fillWidth: true
                    iconName: "horizontal_rule"
                    label: Translation.tr("Row rules")
                    checked: root.instrumentRules
                    onToggled: root._setOutputValue("instrumentRules", !root.instrumentRules)
                }
            }
        }
    }

    Item {
        id: taskFocusSink
        focus: false
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        anchors.fill: parent
        regionBrightness: root.regionBrightness
        surfaceRadius: root.cornerRadiusOverride >= 0
            ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        shown: !root.irisFaced && !root.instrument
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    Item {
        id: stage
        visible: !root.irisFaced
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
                Layout.fillWidth: true
                spacing: Math.round(6 * root.scaleFactor)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    InstrumentLabel {
                        visible: root.instrument
                        text: Translation.tr("Tasks / Ledger")
                        color: root.widgetAccentVisible
                        scaleFactor: root.scaleFactor
                        strong: true
                    }
                    StyledText {
                        visible: root.instrument
                        text: root.pendingCount === 0 ? Translation.tr("All clear") : Translation.tr("%1 open").arg(root.pendingCount)
                        color: root.ink
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(22 * root.scaleFactor)
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                    }
                    StyledText {
                        visible: !root.instrument
                        text: Translation.tr("Todo")
                        color: root.ink
                        font.family: root.widgetTitleFamily
                        font.pixelSize: Math.round(Appearance.font.pixelSize.huge
                            * root.widgetTitleScale * root.scaleFactor)
                        font.weight: root.widgetTitleWeight
                        font.letterSpacing: root.widgetTitleTracking
                    }
                    StyledText {
                        visible: !root.instrument
                        text: root.pendingCount === 0 && root.completedCount > 0
                            ? Translation.tr("All done · %1 completed").arg(root.completedCount)
                            : root.pendingCount === 1
                            ? Translation.tr("1 task left")
                            : Translation.tr("%1 tasks left").arg(root.pendingCount)
                        color: root.inkMuted
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        font.letterSpacing: root.instrument
                            ? Math.round(1.2 * root.scaleFactor) : 0
                        font.capitalization: root.instrument && !root.widgetIris ? Font.AllUppercase : Font.MixedCase
                    }
                }

                RippleButton {
                    visible: root.completedCount > 0
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
                    implicitHeight: root.itemHeight
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
                            anchors.leftMargin: Math.round(10 * root.scaleFactor)
                            anchors.rightMargin: Math.round(12 * root.scaleFactor)
                            spacing: Math.round(9 * root.scaleFactor)

                            InstrumentLabel {
                                visible: root.instrument
                                Layout.alignment: Qt.AlignVCenter
                                text: String(taskRow.index + 1).padStart(2, "0")
                                color: root.inkMuted
                                scaleFactor: root.scaleFactor
                            }
                            RippleButton {
                                Layout.preferredWidth: Math.round(26 * root.scaleFactor)
                                Layout.preferredHeight: Math.round(26 * root.scaleFactor)
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
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: taskRow.modelData.content
                                color: rowInk
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                                font.strikeout: taskRow.modelData.done
                            }

                            RippleButton {
                                Layout.preferredWidth: Math.round(28 * root.scaleFactor)
                                Layout.preferredHeight: Math.round(28 * root.scaleFactor)
                                Layout.alignment: Qt.AlignVCenter
                                enabled: taskRow.modelData.done || taskHover.hovered
                                opacity: taskRow.modelData.done ? 0.78
                                    : taskHover.hovered ? 0.58 : 0
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

                StyledText {
                    anchors.centerIn: parent
                    visible: root.visibleTaskEntries.length === 0
                    text: Todo.list.length > 0 && !root.showCompleted
                        ? Translation.tr("No pending tasks") : Translation.tr("Nothing pending")
                    color: root.inkMuted
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
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
                    id: taskInput
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
