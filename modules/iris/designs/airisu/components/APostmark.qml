import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A date stamp (消印): AIRISU's disc for a moment, the only curve the system keeps. Two rings, the outer one heavy, a band
// across the middle between two rules with the date in the figures' face, what was stamped over it and the time under
// it, all in one ink, the whole stamp turned a few degrees as a hand lands it.
Item {
    id: root
    property string over: ""
    property string date: ""
    property string under: ""
    property color colour: Airisu.seal
    property real turn: -8
    readonly property real r: Math.min(width, height) / 2
    readonly property real heavy: Math.max(2, Math.round(r / 22))
    readonly property real light: Math.max(1, Math.round(r / 60))
    readonly property real band: Math.round(r * 0.46)

    Item {
        anchors.fill: parent
        rotation: root.turn
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.colour
                strokeWidth: root.heavy
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r - root.heavy / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.colour
                strokeWidth: root.light
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r * 0.86; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            // The band's two rules, cut to the inner ring.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.colour
                strokeWidth: root.light * 1.5
                capStyle: ShapePath.FlatCap
                PathMultiline {
                    paths: {
                        const cx = root.width / 2, cy = root.height / 2, ri = root.r * 0.86, h = root.band / 2
                        const half = Math.sqrt(Math.max(0, ri * ri - h * h))
                        return [[Qt.point(cx - half, cy - h), Qt.point(cx + half, cy - h)], [Qt.point(cx - half, cy + h), Qt.point(cx + half, cy + h)]]
                    }
                }
            }
        }
        AText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height / 2 - root.band / 2 - height - root.r * 0.06)
            width: Math.min(implicitWidth, root.r * 1.3)
            horizontalAlignment: Text.AlignHCenter
            voice: "mono"
            size: Math.max(9, Math.round(root.r * 0.13))
            font.weight: Font.Bold
            color: root.colour
            text: root.over
        }
        AText {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.r * 1.66)
            horizontalAlignment: Text.AlignHCenter
            voice: "figure"
            size: Math.round(root.band * 0.62)
            color: root.colour
            text: root.date
        }
        AText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height / 2 + root.band / 2 + root.r * 0.06)
            voice: "data"
            size: Math.max(9, Math.round(root.r * 0.13))
            font.weight: Font.Bold
            color: root.colour
            text: root.under
        }
    }
}
