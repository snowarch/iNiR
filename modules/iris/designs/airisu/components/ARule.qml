import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A rule (定規): how AIRISU draws a setting's range. A row of ticks on the module, every fifth one long, printed in ink as
// far as the value and in the third ink past it, with a die-cut pointer standing over the value. The pointer is the grip:
// it is the ink's at rest and the seal's while a hand holds it (the only shu on the row). The pointer brings the rule's
// crop marks, the keyboard brings them in shu; one that cannot be taken prints every tick in the third ink and drops
// the pointer.
Item {
    id: root
    property real value: 0
    property bool hovered: false
    property bool held: false
    property bool available: true
    property bool keyed: false

    readonly property real pitch: Math.max(4, Math.round(6 * Airisu.d))
    readonly property int count: Math.max(2, Math.floor((root.width - 1) / root.pitch))
    readonly property real step: (root.width - 1) / root.count
    readonly property real foot: Math.round(root.height / 2 + 6 * Airisu.d)
    readonly property real minor: Math.round(4 * Airisu.d)
    readonly property real major: Math.round(8 * Airisu.d)
    readonly property real at: Math.round(Math.max(0, Math.min(1, root.value)) * (root.width - 1))
    // The value moves by a detent unless a hand holds it.
    property real shownAt: root.at
    Behavior on shownAt {
        enabled: Airisu.moving && !root.held
        NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
    }

    function ticks(done: bool): var {
        const out = []
        for (let i = 0; i <= root.count; ++i) {
            const x = Math.round(i * root.step) + 0.5
            if ((x <= root.shownAt + 0.5) !== done) continue
            const len = i % 5 === 0 ? root.major : root.minor
            out.push([Qt.point(x, root.foot), Qt.point(x, root.foot - len)])
        }
        return out
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        ShapePath {
            strokeColor: root.available ? Airisu.ink : Airisu.inkThird
            strokeWidth: Airisu.hair
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathMultiline { paths: root.ticks(true) }
        }
        ShapePath {
            strokeColor: Airisu.inkThird
            strokeWidth: Airisu.hair
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathMultiline { paths: root.ticks(false) }
        }
        // The rule's foot.
        ShapePath {
            strokeColor: Airisu.inkThird
            strokeWidth: Airisu.hair
            fillColor: "transparent"
            startX: 0
            startY: root.foot + 0.5
            PathLine { x: root.width; y: root.foot + 0.5 }
        }
    }
    // The pointer: a die cut to a point, standing over the value.
    Shape {
        id: pointer
        visible: root.available
        readonly property real w: Math.round(10 * Airisu.d)
        readonly property real h: Math.round(7 * Airisu.d)
        x: root.shownAt - w / 2 + 0.5
        y: root.foot - root.major - h - Math.round(2 * Airisu.d)
        width: w
        height: h
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.held ? Airisu.seal : Airisu.ink
            strokeColor: "transparent"
            strokeWidth: 0
            PathPolyline { path: [Qt.point(0, 0), Qt.point(pointer.w, 0), Qt.point(pointer.w / 2, pointer.h), Qt.point(0, 0)] }
        }
    }
    AMarks {
        anchors.fill: parent
        shown: (root.available && root.hovered) || root.keyed
        color: root.keyed ? Airisu.seal : Airisu.marks
    }
}
