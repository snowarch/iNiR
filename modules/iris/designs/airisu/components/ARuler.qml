import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// The graduated rule (目盛, a carpenter's square, SYSTEM.md §6): a tick every module and a long one every fifth, standing
// on a base line. What the value has covered is printed in full ink and the rest in the third ink; the value itself is a
// notch over the rule, a downward triangle that runs along it (the seal while held). A value past `safe` (a boost)
// prints its excess in the caution plate. Each layer of ticks is one tiled cell, so a rule costs four images whatever
// its length. Drawing only: the slider that wears it keeps its input.
Item {
    id: root
    property real value: 0
    property bool held: false
    property bool available: true
    property bool notch: true
    property real safe: 1
    readonly property real v: Math.max(0, Math.min(1, root.value))
    readonly property int pitch: Airisu.m
    readonly property int notchSize: Math.max(5, Math.round(5 * Airisu.d))
    readonly property int ruleHeight: Math.max(6, root.height - (root.notch ? root.notchSize + Airisu.u(0.5) : 0))
    readonly property int tick: Math.max(3, Math.round(root.ruleHeight * 0.45))
    readonly property real at: Math.round(root.v * root.width)
    readonly property real safeAt: Math.round(Math.max(0, Math.min(1, root.safe)) * root.width)
    readonly property color lit: root.available ? Airisu.ink : Airisu.inkThird
    implicitHeight: Math.round(16 * Airisu.d)

    // One tick layer: a rule every pitch, a long one every fifth; `colour` and how far it runs.
    component Ticks: Item {
        id: ticks
        property color colour
        property real from: 0
        property real to: root.width
        x: ticks.from
        width: Math.max(0, ticks.to - ticks.from)
        height: root.ruleHeight
        clip: true
        Image {
            x: -ticks.from
            width: root.width
            height: root.ruleHeight
            source: Airisu.svgCell(5 * root.pitch, root.ruleHeight,
                `<rect x='0' y='0' width='${Airisu.hair}' height='${root.ruleHeight}'/>`
                + [1, 2, 3, 4].map(i => `<rect x='${i * root.pitch}' y='${root.ruleHeight - root.tick}' width='${Airisu.hair}' height='${root.tick}'/>`).join(""),
                ticks.colour)
            fillMode: Image.Tile
            smooth: false
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
        }
    }

    Item {
        id: ruler
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.ruleHeight
        Ticks { colour: Airisu.inkThird; from: root.at }
        Ticks { colour: root.lit; to: Math.min(root.at, root.safeAt) }
        Ticks { colour: Airisu.caution; from: root.safeAt; to: Math.max(root.safeAt, root.at); visible: root.at > root.safeAt }
        // The base line, and the covered part of it twice as heavy.
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Airisu.hair; color: Airisu.inkThird }
        Rectangle { anchors.bottom: parent.bottom; width: root.at; height: Airisu.strong; color: root.lit }
    }
    Shape {
        visible: root.notch
        width: root.notchSize * 2
        height: root.notchSize
        x: Math.round(Math.max(-root.notchSize, Math.min(root.width - root.notchSize, root.at - root.notchSize)))
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.held ? Airisu.seal : root.lit
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: root.notchSize * 2; y: 0 }
            PathLine { x: root.notchSize; y: root.notchSize }
            PathLine { x: 0; y: 0 }
        }
    }
}
