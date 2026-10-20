import QtQuick
import QtQuick.Shapes

// Crop marks (トンボ): how AIRISU says a piece is under the pointer or the keyboard. Four marks stand outside the die's
// box at the corners, `gap` away, each an angle pointing out of the piece; they never touch it and never close round
// it. They come in from twice the gap in one detent, so the piece reads as being registered, not lit.
Item {
    id: root
    property bool shown: false
    property color color: Airisu.ink
    property int gap: Airisu.m
    property int arm: Math.max(3, Math.min(2 * Airisu.m, Math.round(Math.min(root.width, root.height) / 3)))
    property real stroke: Airisu.hair

    property real reach: root.shown ? root.gap : 2 * root.gap
    Behavior on reach {
        enabled: Airisu.moving
        NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
    }

    Loader {
        active: root.shown
        sourceComponent: Shape {
            id: marks
            readonly property real g: root.reach
            readonly property real a: root.arm
            readonly property real w: root.width
            readonly property real h: root.height
            // Half a stroke in, so a hairline lands on whole pixels.
            readonly property real o: root.stroke % 2 === 1 ? 0.5 : 0
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root.stroke
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                PathMultiline {
                    paths: {
                        const g = marks.g, a = marks.a, w = marks.w, h = marks.h, o = marks.o
                        return [
                            [Qt.point(-g - a, -g + o), Qt.point(-g + o, -g + o), Qt.point(-g + o, -g - a)],
                            [Qt.point(w + g + a, -g + o), Qt.point(w + g - o, -g + o), Qt.point(w + g - o, -g - a)],
                            [Qt.point(-g - a, h + g - o), Qt.point(-g + o, h + g - o), Qt.point(-g + o, h + g + a)],
                            [Qt.point(w + g + a, h + g - o), Qt.point(w + g - o, h + g - o), Qt.point(w + g - o, h + g + a)]
                        ]
                    }
                }
            }
        }
    }
}
