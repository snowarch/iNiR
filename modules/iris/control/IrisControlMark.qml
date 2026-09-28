pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Rectangle {
    id: root
    property string glyph: "remove"
    property string label: ""
    property bool danger: false
    property bool draggable: false
    readonly property bool active: area.containsMouse || area.pressed
    readonly property real d: IrisStyle.density
    signal activated()
    signal dragged(point point)
    signal dropped()
    signal hoveredOver(bool hovered)

    z: 30
    width: Math.round(22 * root.d)
    height: width
    radius: width / 2
    color: root.active ? (root.danger ? IrisStyle.danger : IrisStyle.accent) : IrisStyle.surfaceHighestOpaque
    border.width: 1
    border.color: IrisStyle.border
    scale: area.pressed ? IrisStyle.pressScale(0.9) : 1
    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
    Accessible.role: Accessible.Button
    Accessible.name: root.label

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: 1
        iconSize: Math.round((root.glyph === "remove" ? 15 : 12) * root.d)
        color: root.active ? (root.danger ? IrisStyle.onDanger : IrisStyle.onAccent) : IrisStyle.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -Math.round(4 * root.d)
        hoverEnabled: true
        cursorShape: root.draggable ? Qt.SizeFDiagCursor : Qt.PointingHandCursor
        preventStealing: true
        property bool moved: false
        property point origin: Qt.point(0, 0)
        onContainsMouseChanged: root.hoveredOver(area.containsMouse)
        onPressed: mouse => {
            area.moved = false
            area.origin = Qt.point(mouse.x, mouse.y)
        }
        onPositionChanged: mouse => {
            if (!area.pressed || !root.draggable) return
            if (!area.moved && Math.hypot(mouse.x - area.origin.x, mouse.y - area.origin.y) < 4 * root.d) return
            area.moved = true
            root.dragged(area.mapToItem(root, mouse.x, mouse.y))
        }
        onReleased: {
            if (area.moved) root.dropped()
            else root.activated()
            area.moved = false
        }
        onCanceled: {
            if (area.moved) root.dropped()
            area.moved = false
        }
    }
}
