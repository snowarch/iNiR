import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// The graduated rule (目盛, SYSTEM.md §6): a tick every two modules and a long one every fifth, standing on a base line.
// What the value has covered is printed in full ink on a base line twice as heavy, the rest in the third ink; the value
// itself is a notch over the rule, a downward triangle that runs along it, the seal while it is held. Drawing only: the
// slider that wears it keeps its input.
Item {
    id: root
    property real value: 0
    property bool hovered: false
    property bool held: false
    property bool available: true
    property bool keyed: false
    readonly property real v: Math.max(0, Math.min(1, root.value))
    readonly property int notchSize: Math.max(4, Math.round(5 * Airisu.d))
    readonly property int ruleHeight: Math.max(6, root.height - root.notchSize - Airisu.hair)
    readonly property real span: Math.max(1, root.width - Airisu.hair)
    // Whole fifths, so the long ticks stand at the same places on every rule of a page.
    readonly property int count: Math.max(5, Math.floor(root.span / (2 * Airisu.m) / 5) * 5)
    readonly property real at: Math.round(root.v * root.span)
    readonly property color lit: root.available ? Airisu.ink : Airisu.inkThird

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.ruleHeight
        Repeater {
            model: root.count + 1
            Rectangle {
                required property int index
                readonly property bool major: index % 5 === 0
                x: Math.round(index * root.span / root.count)
                anchors.bottom: parent.bottom
                width: Airisu.hair
                height: major ? root.ruleHeight : Math.round(root.ruleHeight * 0.45)
                color: x <= root.at ? root.lit : Airisu.inkThird
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Airisu.hair; color: Airisu.inkThird }
        Rectangle { anchors.bottom: parent.bottom; width: root.at + Airisu.hair; height: Airisu.strong; color: root.lit }
    }
    Shape {
        width: root.notchSize * 2
        height: root.notchSize
        x: Math.round(root.at + Airisu.hair / 2 - root.notchSize)
        visible: root.available
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.held || root.keyed ? Airisu.seal : Airisu.ink
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0; startY: 0
            PathLine { x: root.notchSize * 2; y: 0 }
            PathLine { x: root.notchSize; y: root.notchSize }
            PathLine { x: 0; y: 0 }
        }
    }
}
