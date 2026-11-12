import QtQuick
import QtQuick.Shapes

// The iNiR mark: one strip up the left leg, folded into the N (its other face shows), up the short leg that is the i.
// Families pass their own ink and accent, so it follows the scheme, light or dark.
Item {
    id: root
    property real implicitSize: 48
    property color ink: "#f1efe9"
    property color accent: "#ffb224"
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // drawn on a 320 box: the 512 artwork's mark spans 96..416
    readonly property real u: Math.min(width, height) / 320

    Shape {
        width: 320 * root.u
        height: 320 * root.u
        anchors.centerIn: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: root.ink
            PathPolyline { path: [Qt.point(0, 320 * root.u), Qt.point(0, 0), Qt.point(80 * root.u, 0), Qt.point(80 * root.u, 320 * root.u)] }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.accent
            PathPolyline { path: [Qt.point(0, 0), Qt.point(80 * root.u, 0), Qt.point(320 * root.u, 320 * root.u), Qt.point(240 * root.u, 320 * root.u)] }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.ink
            PathPolyline { path: [Qt.point(240 * root.u, 320 * root.u), Qt.point(240 * root.u, 118 * root.u), Qt.point(320 * root.u, 118 * root.u), Qt.point(320 * root.u, 320 * root.u)] }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.ink
            PathPolyline { path: [Qt.point(240 * root.u, 0), Qt.point(320 * root.u, 0), Qt.point(320 * root.u, 80 * root.u), Qt.point(240 * root.u, 80 * root.u)] }
        }
    }
}
