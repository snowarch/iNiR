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

AbstractBackgroundWidget {
    id: root

    configEntryName: "todo"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 300, contentHeight: 276,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.14, borderWidth: 1, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 120, y: 180
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 300)
        * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 276)
        * root.scaleFactor)

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

    Item {
        id: taskFocusSink
        focus: false
    }

    WidgetSurface {
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
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    Item {
        id: stage
        anchors.fill: parent
        anchors.margins: root.inset

        transform: Scale {
            id: flipScale
            origin.x: stage.width / 2
            origin.y: stage.height / 2
            xScale: 1
        }

        states: [
            State { name: "list"; when: root.mode === "list" },
            State { name: "edit"; when: root.mode === "edit" }
        ]

        transitions: Transition {
            enabled: Appearance.animationsEnabled
            SequentialAnimation {
                NumberAnimation {
                    target: flipScale
                    property: "xScale"
                    from: 1; to: 0
                    duration: Appearance.calcEffectiveDuration(120)
                    easing.type: Easing.InQuad
                }
                PropertyAction { target: listPage; property: "visible" }
                PropertyAction { target: editPage; property: "visible" }
                NumberAnimation {
                    target: flipScale
                    property: "xScale"
                    from: 0; to: 1
                    duration: Appearance.calcEffectiveDuration(150)
                    easing.type: Easing.OutQuad
                }
            }
        }

        ColumnLayout {
            id: listPage
            anchors.fill: parent
            visible: root.mode === "list"
            spacing: Math.round(9 * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.scaleFactor)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Translation.tr("Todo")
                        color: root.widgetSurfaceInk
                        font.pixelSize: Math.round(Appearance.font.pixelSize.huge * root.scaleFactor)
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: Todo.list.filter(item => !item.done).length === 1
                            ? Translation.tr("1 task left")
                            : Translation.tr("%1 tasks left").arg(Todo.list.filter(item => !item.done).length)
                        color: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.62)
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    }
                }

                RippleButton {
                    Layout.preferredWidth: Math.round(38 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(38 * root.scaleFactor)
                    buttonRadius: Appearance.rounding.full
                    colBackground: root.primaryFace
                    colBackgroundHover: ColorUtils.mix(root.primaryFace, root.primaryInk, 0.9)
                    colRipple: ColorUtils.applyAlpha(root.primaryInk, 0.16)
                    releaseAction: () => root.openNewTask()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "add"
                        iconSize: Math.round(19 * root.scaleFactor)
                        color: root.primaryInk
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
                model: Todo.list

                delegate: SwipeDelegate {
                    id: taskRow
                    required property var modelData
                    required property int index

                    width: todoList.width
                    implicitHeight: root.itemHeight
                    padding: 0
                    background: null
                    clip: true

                    contentItem: Rectangle {
                        radius: Math.min(Appearance.rounding.normal, height / 2)
                        color: root.taskFace(taskRow.index)
                        opacity: taskRow.modelData.done ? 0.56 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(10 * root.scaleFactor)
                            anchors.rightMargin: Math.round(12 * root.scaleFactor)
                            spacing: Math.round(9 * root.scaleFactor)

                            RippleButton {
                                Layout.preferredWidth: Math.round(26 * root.scaleFactor)
                                Layout.preferredHeight: Math.round(26 * root.scaleFactor)
                                Layout.alignment: Qt.AlignVCenter
                                buttonRadius: Appearance.rounding.full
                                colBackground: taskRow.modelData.done
                                    ? ColorUtils.applyAlpha(root.taskInk(taskRow.index), 0.16)
                                    : "transparent"
                                colBackgroundHover: ColorUtils.applyAlpha(root.taskInk(taskRow.index), 0.12)
                                colRipple: ColorUtils.applyAlpha(root.taskInk(taskRow.index), 0.16)
                                releaseAction: () => {
                                    if (taskRow.modelData.done)
                                        Todo.markUnfinished(taskRow.index)
                                    else
                                        Todo.markDone(taskRow.index)
                                }
                                contentItem: Item {
                                    anchors.fill: parent
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.round(20 * root.scaleFactor)
                                        height: width
                                        radius: Appearance.rounding.full
                                        color: "transparent"
                                        border.width: Math.max(1, Math.round(2 * root.scaleFactor))
                                        border.color: root.taskInk(taskRow.index)
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: taskRow.modelData.done
                                            text: "check"
                                            iconSize: Math.round(15 * root.scaleFactor)
                                            color: root.taskInk(taskRow.index)
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: taskRow.modelData.content
                                color: root.taskInk(taskRow.index)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                                font.strikeout: taskRow.modelData.done
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
                        SwipeDelegate.onClicked: Todo.deleteItem(taskRow.index)
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: Todo.list.length === 0
                    text: Translation.tr("Nothing pending")
                    color: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.55)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                }
            }
        }

        ColumnLayout {
            id: editPage
            anchors.fill: parent
            visible: root.mode === "edit"
            spacing: Math.round(10 * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true

                RippleButton {
                    Layout.preferredWidth: Math.round(34 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(34 * root.scaleFactor)
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.08)
                    colRipple: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.12)
                    releaseAction: () => root.closeEditor()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        iconSize: Math.round(18 * root.scaleFactor)
                        color: root.widgetSurfaceInk
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("New task")
                    color: root.widgetSurfaceInk
                    font.pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                    font.weight: Font.DemiBold
                }

                RippleButton {
                    Layout.preferredWidth: Math.round(38 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(38 * root.scaleFactor)
                    enabled: root.editingText.trim().length > 0
                    opacity: enabled ? 1 : 0.45
                    buttonRadius: Appearance.rounding.full
                    colBackground: root.primaryFace
                    colBackgroundHover: ColorUtils.mix(root.primaryFace, root.primaryInk, 0.9)
                    colRipple: ColorUtils.applyAlpha(root.primaryInk, 0.16)
                    releaseAction: () => root.saveAndBack()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "check"
                        iconSize: Math.round(19 * root.scaleFactor)
                        color: root.primaryInk
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: ColorUtils.applyAlpha(root.primaryFace, 0.74)
                border.width: taskInput.activeFocus ? Math.max(1, Math.round(2 * root.scaleFactor)) : 0
                border.color: root.widgetAccent

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
