import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A date stamp (消印): AIRISU's disc for a moment, the only curve the system keeps. Two rings, the outer one heavy, a band
// across the middle between two rules with the date in the figures' face, what was stamped over it and the time under
// it, all in one ink, the whole stamp turned a few degrees as a hand lands it.
// Every line is cut whole inside the fine ring or not at all: lettering never goes under 9 px, so where a line runs past
// the ring's chord at its far edge the stamp lets it go, the line over first, then the one under; with no room for the
// date there is no stamp (`drawn` false), and whoever places it gives the room back.
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
    readonly property real inner: r * 0.86
    readonly property int letter: Math.max(9, Math.round(r * 0.13))
    // How wide a line may run whose far edge sits `far` from the middle: the fine ring's chord there, a ring's breadth in.
    function chord(far: real): real {
        const room = root.inner - 2 * root.light
        return far >= room ? 0 : 2 * Math.sqrt(room * room - far * far)
    }
    readonly property real reach: root.band / 2 + root.r * 0.06
    readonly property bool dateFits: root.date.length > 0 && dateLine.implicitHeight <= root.band
        && dateLine.implicitWidth <= root.chord(root.band / 2)
    readonly property bool underFits: root.dateFits && root.under.length > 0
        && underLine.implicitWidth <= root.chord(root.reach + underLine.implicitHeight)
    readonly property bool overFits: root.underFits && root.over.length > 0
        && overLine.implicitWidth <= root.chord(root.reach + overLine.implicitHeight)
    readonly property bool drawn: root.dateFits

    Item {
        anchors.fill: parent
        visible: root.drawn
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
                PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.inner; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            // The band's two rules, cut to the inner ring.
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.colour
                strokeWidth: root.light * 1.5
                capStyle: ShapePath.FlatCap
                PathMultiline {
                    paths: {
                        const cx = root.width / 2, cy = root.height / 2, ri = root.inner, h = root.band / 2
                        const half = Math.sqrt(Math.max(0, ri * ri - h * h))
                        return [[Qt.point(cx - half, cy - h), Qt.point(cx + half, cy - h)], [Qt.point(cx - half, cy + h), Qt.point(cx + half, cy + h)]]
                    }
                }
            }
        }
        AText {
            id: overLine
            visible: root.overFits
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height / 2 - root.reach - height)
            elide: Text.ElideNone
            voice: "mono"
            size: root.letter
            font.weight: Font.Bold
            color: root.colour
            text: root.over
        }
        AText {
            id: dateLine
            anchors.centerIn: parent
            elide: Text.ElideNone
            voice: "figure"
            size: Math.max(9, Math.round(root.band * 0.62))
            color: root.colour
            text: root.date
        }
        AText {
            id: underLine
            visible: root.underFits
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height / 2 + root.reach)
            elide: Text.ElideNone
            voice: "data"
            size: root.letter
            font.weight: Font.Bold
            color: root.colour
            text: root.under
        }
    }
}
