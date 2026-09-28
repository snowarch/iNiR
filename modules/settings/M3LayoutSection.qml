pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string sectionTitle
    property string sectionKey: ""
    property string orderHint: Translation.tr("Top to bottom")
    property string dragKey: "inir-m3-layout-item"
    property var layout: []
    property var availableWidgets: []
    property var getWidgetName: (id) => id
    property var getWidgetDescription: (id) => ""
    property var getWidgetIcon: (id) => "widgets"
    property var onUpdate: (list) => {}
    property var onMove: (sourceSection, sourceIndex, id, targetSection, targetIndex) => false
    property Item dragOverlay: null
    property int dropIndex: -1
    property string dragSourceSection: ""
    property int dragSourceIndex: -1

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: zoneDrop.containsDrag
        ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.94)
        : Appearance.colors.colLayer0
    border.width: zoneDrop.containsDrag ? 2 : 1
    border.color: zoneDrop.containsDrag
        ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

    function insertionIndexFromY(y: real, sourceSection: string, sourceIndex: int): int {
        let insertion = 0
        for (let i = 0; i < selectedRepeater.count; ++i) {
            const item = selectedRepeater.itemAt(i)
            const rowItem = item?.rowItem
            if (!rowItem || !rowItem.visible)
                continue
            if (sourceSection === root.sectionKey && i === sourceIndex)
                continue
            const center = rowItem.mapToItem(zoneDrop, 0, rowItem.height / 2)
            if (y < center.y)
                return insertion
            insertion++
        }
        return insertion
    }

    function visualDropIndex(): int {
        if (root.dropIndex < 0)
            return -1
        if (root.dragSourceSection === root.sectionKey
                && root.dragSourceIndex >= 0
                && root.dropIndex > root.dragSourceIndex)
            return root.dropIndex + 1
        return root.dropIndex
    }

    function finishDrop(sourceSection: string, sourceIndex: int, id: string, targetIndex: int): void {
        if (sourceSection.length > 0 && root.sectionKey.length > 0 && sourceSection !== root.sectionKey) {
            root.onMove(sourceSection, sourceIndex, id, root.sectionKey, targetIndex)
            return
        }

        const next = root.layout.slice()
        if (sourceIndex < 0 || sourceIndex >= next.length)
            return
        const moved = next.splice(sourceIndex, 1)[0]
        const insertAt = Math.max(0, Math.min(targetIndex, next.length))
        next.splice(insertAt, 0, moved)
        root.onUpdate(next)
    }

    Item {
        id: dragLayer
        anchors.fill: parent
        z: 300
        clip: false
    }

    DropArea {
        id: zoneDrop
        anchors.fill: parent
        keys: [root.dragKey]

        function updateDrop(drag): void {
            const source = drag?.source
            root.dragSourceSection = String(source?.sourceSectionKey ?? "")
            root.dragSourceIndex = Number(source?.sourceIndex ?? -1)
            root.dropIndex = root.insertionIndexFromY(
                drag?.y ?? 0,
                root.dragSourceSection,
                root.dragSourceIndex)
        }

        onEntered: drag => {
            chooser.open = false
            zoneDrop.updateDrop(drag)
        }
        onPositionChanged: drag => zoneDrop.updateDrop(drag)
        onExited: {
            root.dropIndex = -1
            root.dragSourceSection = ""
            root.dragSourceIndex = -1
        }
        onDropped: drop => {
            const source = drop.source
            const targetIndex = root.dropIndex >= 0
                ? root.dropIndex
                : root.insertionIndexFromY(drop.y,
                    String(source?.sourceSectionKey ?? ""),
                    Number(source?.sourceIndex ?? -1))
            if (source)
                root.finishDrop(String(source.sourceSectionKey ?? ""),
                    Number(source.sourceIndex ?? -1),
                    String(source.moduleId ?? ""), targetIndex)
            root.dropIndex = -1
            root.dragSourceSection = ""
            root.dragSourceIndex = -1
        }
    }

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
    }

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol {
                text: root.sectionKey === "left" ? "align_horizontal_left"
                    : root.sectionKey === "right" ? "align_horizontal_right"
                    : "align_horizontal_center"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.sectionTitle
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: zoneDrop.containsDrag ? Translation.tr("Release to place") : root.orderHint
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: zoneDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            RippleButton {
                implicitWidth: 64
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                toggled: chooser.open
                onClicked: chooser.open = !chooser.open
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        text: chooser.open ? "close" : "add"
                        iconSize: Appearance.font.pixelSize.small
                        color: chooser.open ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        text: chooser.open ? Translation.tr("Close") : Translation.tr("Add")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: chooser.open ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                    }
                }
            }
        }

        Item {
            id: dropSurface
            Layout.fillWidth: true
            implicitHeight: Math.max(58, rows.implicitHeight + 8)

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: zoneDrop.containsDrag
                    ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.97)
                    : "transparent"

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }

            ColumnLayout {
                id: rows
                anchors {
                    fill: parent
                    margins: 4
                }
                spacing: 0

                Repeater {
                    id: selectedRepeater
                    model: root.layout.length + 1

                    delegate: ColumnLayout {
                        required property int index
                        readonly property Item rowItem: rowRoot
                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: zoneDrop.containsDrag && root.visualDropIndex() === index ? 14 : 3

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                height: zoneDrop.containsDrag && root.visualDropIndex() === index ? 4 : 1
                                radius: height / 2
                                color: zoneDrop.containsDrag && root.visualDropIndex() === index
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOutlineVariant
                                opacity: zoneDrop.containsDrag && root.visualDropIndex() === index ? 1 : 0.2
                            }

                            Behavior on implicitHeight {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            id: rowRoot
                            visible: index < root.layout.length
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 42 : 0
                            property string moduleId: visible ? String(root.layout[index]) : ""
                            property string sourceSectionKey: root.sectionKey
                            property int sourceIndex: index
                            readonly property bool beingDragged: dragMouse.drag.active
                            readonly property string detail: visible ? String(root.getWidgetDescription(moduleId) ?? "") : ""

                        radius: Appearance.rounding.small
                        color: beingDragged ? Appearance.colors.colLayer2 : "transparent"
                        border.width: beingDragged ? 1 : 0
                        border.color: Appearance.colors.colPrimary
                        scale: beingDragged ? 1.02 : 1
                        opacity: beingDragged ? 0.96 : 1

                        Drag.active: dragMouse.drag.active
                        Drag.source: rowRoot
                        Drag.keys: [root.dragKey]
                        Drag.hotSpot.x: 18
                        Drag.hotSpot.y: height / 2

                        states: State {
                            when: dragMouse.drag.active
                            ParentChange { target: rowRoot; parent: root.dragOverlay ?? dragLayer }
                            PropertyChanges { rowRoot { z: 400; width: root.width - 20 } }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 4
                                rightMargin: 2
                            }
                            spacing: 7

                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 32

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "drag_indicator"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: dragMouse.containsMouse || rowRoot.beingDragged
                                        ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }

                                MouseArea {
                                    id: dragMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    drag.target: rowRoot
                                    drag.axis: Drag.XAndYAxis
                                    onReleased: {
                                        if (rowRoot.Drag.target)
                                            rowRoot.Drag.drop()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colLayer1
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.getWidgetIcon(rowRoot.moduleId)
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: -1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.getWidgetName(rowRoot.moduleId)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: rowRoot.detail.length > 0
                                    text: rowRoot.detail
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colPrimary
                                    elide: Text.ElideRight
                                }
                            }

                            IconToolbarButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                text: "close"
                                onClicked: {
                                    const next = root.layout.slice()
                                    next.splice(rowRoot.sourceIndex, 1)
                                    root.onUpdate(next)
                                }
                            }
                        }

                        }
                    }
                }

                RowLayout {
                    visible: root.layout.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 6
                    Item { Layout.fillWidth: true }
                    MaterialSymbol {
                        text: zoneDrop.containsDrag ? "move_down" : "drag_indicator"
                        iconSize: Appearance.font.pixelSize.small
                        color: zoneDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: zoneDrop.containsDrag ? Translation.tr("Release here") : Translation.tr("Drop a widget here")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: zoneDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Item {
            id: chooser
            property bool open: false
            Layout.fillWidth: true
            visible: open
            implicitHeight: open ? pickerContent.implicitHeight + 12 : 0

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1

                Flow {
                    id: pickerContent
                    anchors {
                        fill: parent
                        margins: 6
                    }
                    spacing: 4

                    Repeater {
                        model: root.availableWidgets
                        delegate: RippleButton {
                            id: option
                            required property var modelData
                            implicitWidth: Math.max(96, Math.min(150, optionLabel.implicitWidth + 44))
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.full
                            onClicked: {
                                const next = root.layout.slice()
                                next.push(modelData.id)
                                root.onUpdate(next)
                                if (modelData.id !== "visualizer" && modelData.id !== "divisor")
                                    chooser.open = false
                            }

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialSymbol {
                                    text: option.modelData.icon ?? "widgets"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    id: optionLabel
                                    text: option.modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                        }
                    }

                    StyledText {
                        visible: root.availableWidgets.length === 0
                        text: Translation.tr("No widgets available")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}
