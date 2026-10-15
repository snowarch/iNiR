pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    required property string blockId
    required property string label
    required property int targetIndex
    property bool active: false

    visible: active
    z: 500

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["inir-settings-chrome"]
        enabled: root.active
        onDropped: drop => {
            const sourceId = String(drop.source?.blockId ?? "")
            if (sourceId.length > 0 && sourceId !== root.blockId)
                SettingsChromeLayout.moveHeaderBlock(sourceId, root.targetIndex)
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: Appearance.rounding.normal
        color: dropArea.containsDrag
            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
            : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.38)
        border.width: dropArea.containsDrag ? 2 : 0
        border.color: dropArea.containsDrag
            ? Appearance.colors.colPrimary
            : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onPressed: mouse => mouse.accepted = true
        onClicked: mouse => mouse.accepted = true
    }

    Rectangle {
        id: dragHandle
        property string blockId: root.blockId

        x: 5
        y: 4
        width: handleRow.implicitWidth + 12
        height: 24
        radius: Appearance.rounding.full
        color: handleDrag.drag.active || dropArea.containsDrag
            ? Appearance.colors.colPrimary
            : Appearance.colors.colLayer2
        border.width: 0
        z: 10

        Drag.active: handleDrag.drag.active
        Drag.source: dragHandle
        Drag.keys: ["inir-settings-chrome"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Row {
            id: handleRow
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                text: "drag_indicator"
                iconSize: 14
                color: handleDrag.drag.active || dropArea.containsDrag
                    ? Appearance.colors.colOnPrimary
                    : Appearance.colors.colPrimary
            }
            StyledText {
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: handleDrag.drag.active || dropArea.containsDrag
                    ? Appearance.colors.colOnPrimary
                    : Appearance.colors.colOnLayer2
            }
        }

        MouseArea {
            id: handleDrag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: dragHandle
            drag.axis: Drag.XAndYAxis
            onReleased: {
                if (dragHandle.Drag.target)
                    dragHandle.Drag.drop()
                dragHandle.x = 5
                dragHandle.y = 4
            }
            onCanceled: {
                dragHandle.x = 5
                dragHandle.y = 4
            }
        }
    }
}
