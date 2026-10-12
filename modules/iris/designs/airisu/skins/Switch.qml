import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's switch (SYSTEM.md §6): a printed rocker, two cells marked with the marks every power switch carries, a ring
// for off and a bar for on (IEC 60417), drawn with compass and rule. On, the bar's cell is a solid ink plate with the bar
// reversed out; off, the ring's cell is the next sheet. The plate does not slide: it stops in the other cell (a 90 ms
// detent). The host keeps the toggle, the keys and the name.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: root.host?.pressed ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property real cell: Math.round(root.width / 2)
    readonly property real mark: Math.round(Math.min(root.cell, root.height) * 0.42)
    readonly property int stroke: Math.max(2, Math.round(2 * Airisu.d))

    APrint {
        id: plate
        width: root.cell
        height: root.height
        x: root.on ? root.width - root.cell : 0
        Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        die: "rect"
        pressed: root.pressed
        // Only "on" is inked; off is the bare cell with its ring in full ink, so the cell never sits on its own colour.
        fill: root.available && root.on ? Airisu.ink : "transparent"
        under: Airisu.inkUnder
        AScreen { anchors.fill: parent; visible: !root.available; pigment: Airisu.inkThird; density: 25 }
    }
    // The die's rule is printed last, over the plate, so the cell never eats the frame.
    ADie {
        anchors.fill: parent
        stroke: root.available ? Airisu.inkSecond : Airisu.inkThird
        strokeWidth: Airisu.hair
        dashed: !root.available
    }
    // The ring, off.
    Shape {
        x: Math.round((root.cell - root.mark) / 2)
        y: Math.round((root.height - root.mark) / 2)
        width: root.mark
        height: root.mark
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: !root.on && root.available ? Airisu.ink : Airisu.inkThird
            strokeWidth: root.stroke
            PathAngleArc {
                centerX: root.mark / 2; centerY: root.mark / 2
                radiusX: (root.mark - root.stroke) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
    }
    // The bar, on.
    Rectangle {
        x: Math.round(root.width - root.cell + (root.cell - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: root.stroke
        height: root.mark
        color: root.on && root.available ? Airisu.reverse : Airisu.inkThird
    }
    ATombo {
        anchors.fill: parent
        shown: root.hovered && root.available
        focusMarks: root.host?.keyed ?? false
    }
}
