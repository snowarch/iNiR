import QtQuick
import QtQuick.Shapes

// ❯❯ — AIRISU's chevrons, drawn (never a font glyph): two arrows in the seal, the second at half strength. When
// `running`, the strength steps from one to the other on the roll beat, a lap light rather than a spinner.
Row {
    id: root
    property bool running: false
    property color colour: Airisu.seal
    property int phase: 0
    spacing: Math.round(2 * Airisu.d)
    Timer { interval: 440; repeat: true; running: root.running && root.visible; onTriggered: root.phase = 1 - root.phase }
    Repeater {
        model: 2
        Shape {
            required property int index
            width: Math.round(10 * Airisu.d)
            height: Math.round(16 * Airisu.d)
            opacity: index === (root.running ? root.phase : 0) ? 1 : 0.5
            Behavior on opacity { enabled: root.running; NumberAnimation { duration: Airisu.whip } }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.colour
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: width / 2; y: 0 }
                PathLine { x: width; y: height / 2 }
                PathLine { x: width / 2; y: height }
                PathLine { x: 0; y: height }
                PathLine { x: width / 2; y: height / 2 }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
