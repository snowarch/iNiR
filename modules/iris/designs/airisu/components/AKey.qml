import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A key, AIRISU's control: a lacquer die that answers by its coat, never by growing, glowing or a ring. The pointer
// lays a coat one step toward the lacquer's ink across it at the die's 45° (one snap), a press lays it a step deeper and
// carries what is printed on it a hair down and right (`shift`, which the host's content follows), keyboard focus inks
// the die's uncut corner as a flag, and a key that cannot be taken keeps no coat. A key with no lacquer (a quiet one) is
// only its coat, laid on the body it sits on.
Item {
    id: root
    property color lacquer: Airisu.groundRaised
    property bool hovered: false
    property bool pressed: false
    property bool keyed: false
    property bool available: true
    property int cut: Airisu.cutFor(root.height)
    property bool cutTopRight: true
    property bool cutBottomLeft: true
    // What the coat is a step of: the lacquer, or what lies under a quiet key.
    property color under: Airisu.ground
    readonly property color stock: root.lacquer.a > 0 ? root.lacquer : root.under
    readonly property color ink: Airisu.inkOn(root.stock)
    property color coat: Airisu.step(root.stock, root.pressed ? Airisu.pressStep : Airisu.hoverStep)
    property color flag: Qt.colorEqual(root.stock, Airisu.seal) ? root.ink : Airisu.seal
    readonly property int shift: root.pressed && root.available ? Airisu.hair : 0
    readonly property int flagSize: Math.max(4, Math.round(Math.min(root.height * 0.36, 10 * Airisu.d)))

    ALacquer {
        anchors.fill: parent
        cut: root.cut
        cutTopRight: root.cutTopRight
        cutBottomLeft: root.cutBottomLeft
        lacquer: root.lacquer
        coat: root.coat
        share: root.available && (root.hovered || root.pressed) ? 1 : 0
        travel: Airisu.snap
    }
    Shape {
        visible: root.keyed
        width: root.flagSize
        height: root.flagSize
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.flag
            strokeColor: "transparent"
            strokeWidth: 0
            PathPolyline { path: [Qt.point(0, 0), Qt.point(root.flagSize, 0), Qt.point(0, root.flagSize), Qt.point(0, 0)] }
        }
    }
}
