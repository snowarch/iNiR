import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// The AIRISU insignia: a kamon disc in the ink with the katakana ア cut out of it, and the hanko seal at the lower
// right in the host's colour (the accent by default). Drawn on a 100-unit grid and scaled to the host's size.
Item {
    id: root
    property Item host: null
    readonly property real size: Math.min(width, height)
    readonly property real unit: root.size / 100

    Shape {
        id: disc
        width: 100
        height: 100
        anchors.centerIn: parent
        scale: root.unit
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: IrisStyle.text
            fillRule: ShapePath.OddEvenFill
            // The disc, then ア's two strokes as holes: the bar turning down at a mitred corner, and the falling
            // stroke that leaves the bar below it and sweeps left.
            PathSvg {
                path: "M 6 50 A 44 44 0 1 0 94 50 A 44 44 0 1 0 6 50 Z "
                    + "M 25 26 L 83.74 26 L 60.83 53.22 L 53.17 46.78 L 62.25 36 L 25 36 Z "
                    + "M 42 43 L 52 43 L 52 58 Q 52 73 37.39 85.68 L 30.61 78.32 Q 42 68 42 58 Z"
            }
        }
    }

    // The hanko: the only colour in the mark, standing just off the disc's lower right.
    Rectangle {
        width: Math.max(2, Math.round(10 * root.unit))
        height: width
        x: Math.round((root.width - root.size) / 2 + 84 * root.unit)
        y: Math.round((root.height - root.size) / 2 + 80 * root.unit)
        // The seal's pigment, unless the host asks for another colour.
        color: !root.host || Qt.colorEqual(root.host.color, IrisStyle.accent) ? IrisStyle.accentFill : root.host.color
        visible: root.size >= 18
    }
}
