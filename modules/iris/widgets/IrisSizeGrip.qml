pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs
import qs.modules.iris.style

Item {
    id: root

    required property var widget
    readonly property real d: IrisStyle.density
    readonly property real plateRadius: root.widget.widgetCardRadius * root.widget.scaleFactor
    readonly property real stroke: Math.max(2, Math.round(3 * root.d))
    readonly property real gap: Math.round(5 * root.d)
    readonly property real bend: root.plateRadius + root.gap + root.stroke / 2
    readonly property real tail: Math.round((area.containsMouse || root.active ? 8 : 3) * root.d)
    readonly property real arm: root.bend + root.stroke + Math.round(8 * root.d)
    readonly property real line: root.arm - root.stroke / 2
    readonly property bool active: area.pressed
    property real reachWidth: 0
    property real reachHeight: 0

    function sizeOf(name: string): var {
        const unit = root.widget.irisUnit
        const gutter = root.widget.irisGutter
        return Qt.size(name === "small" ? unit : unit * 2 + gutter, name === "large" ? unit * 2 + gutter : unit)
    }
    function nearest(width: real, height: real): string {
        let best = root.widget.irisSize
        let bestDistance = Infinity
        for (const size of root.widget.irisSizes) {
            const target = root.sizeOf(size)
            const distance = Math.pow(width - target.width, 2) + Math.pow(height - target.height, 2)
            if (distance < bestDistance) {
                bestDistance = distance
                best = size
            }
        }
        return best
    }

    x: root.widget.width + root.gap + root.stroke - root.arm
    y: root.widget.height + root.gap + root.stroke - root.arm
    width: root.arm
    height: root.arm

    Rectangle {
        id: reach
        parent: root.parent
        z: root.z - 1
        visible: opacity > 0
        opacity: root.active ? 1 : 0
        width: Math.max(root.sizeOf("small").width, root.reachWidth)
        height: Math.max(root.sizeOf("small").height, root.reachHeight)
        radius: root.plateRadius
        color: "transparent"
        border.width: Math.max(1, Math.round(1.5 * root.d))
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: area.containsMouse || root.active ? 1 : 0.78
        Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: IrisStyle.plateShadow
            shadowBlur: 0.4
            shadowVerticalOffset: 1
        }

        ShapePath {
            strokeWidth: root.stroke
            strokeColor: root.active ? IrisStyle.accent : IrisStyle.text
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.line
            startY: root.line - root.bend - root.tail
            PathLine { x: root.line; y: root.line - root.bend }
            PathArc {
                x: root.line - root.bend
                y: root.line
                radiusX: root.bend
                radiusY: root.bend
            }
            PathLine { x: root.line - root.bend - root.tail; y: root.line }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -Math.round(8 * root.d)
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeFDiagCursor
        property real startX: 0
        property real startY: 0
        property string startSize: ""

        onPressed: mouse => {
            const point = area.mapToItem(root.widget.parent, mouse.x, mouse.y)
            area.startX = point.x
            area.startY = point.y
            area.startSize = root.widget.irisSize
            root.reachWidth = root.widget.width
            root.reachHeight = root.widget.height
            GlobalStates.selectDesktopWidget(root.widget.editInstanceKey)
            root.widget._resizePreviewValues = ({ "iris.size": area.startSize })
            root.widget._irisSizing = true
        }
        onPositionChanged: mouse => {
            if (!area.pressed)
                return
            const point = area.mapToItem(root.widget.parent, mouse.x, mouse.y)
            const start = root.sizeOf(area.startSize)
            root.reachWidth = start.width + point.x - area.startX
            root.reachHeight = start.height + point.y - area.startY
            const size = root.nearest(root.reachWidth, root.reachHeight)
            if (size !== root.widget.irisSize)
                root.widget._resizePreviewValues = ({ "iris.size": size })
        }
        onReleased: root.widget.commitIrisSize(root.widget.irisSize)
        onCanceled: root.widget.commitIrisSize(area.startSize)
    }
}
