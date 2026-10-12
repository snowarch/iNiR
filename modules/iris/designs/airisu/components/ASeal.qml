import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A sealed button: a plate cut at its upper-right and lower-left corners like the field's bodies. `kind` "seal" is
// the vermilion (live: play, record, confirm), "gofun" the chosen plate, "line" a 1 px outline. Holds a glyph or text.
Item {
    id: root
    property string kind: "seal"
    property string glyph: ""
    property string text: ""
    readonly property color fillColour: root.kind === "seal" ? Airisu.seal : root.kind === "gofun" ? Airisu.gofun : "transparent"
    readonly property color ink: root.kind === "seal" ? Airisu.inkOnSeal : root.kind === "gofun" ? Airisu.inkOnGofun : Airisu.gofun
    readonly property real cut: Math.min(Airisu.cut, height / 3)
    signal clicked()

    implicitWidth: label.visible ? label.implicitWidth + Airisu.pad * 2 : Math.round(48 * Airisu.d)
    implicitHeight: Math.round(48 * Airisu.d)
    scale: tap.pressed ? 0.96 : 1 // iris-literal: a seal is pressed, not bounced
    Behavior on scale { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
    Accessible.role: Accessible.Button
    Accessible.name: root.text || root.glyph

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: hover.hovered && root.kind !== "line" ? Qt.lighter(root.fillColour, 1.08) : root.fillColour // iris-literal: a seal's hover is a step of its own pigment
            strokeColor: root.kind === "line" ? Airisu.fillet : "transparent"
            strokeWidth: root.kind === "line" ? Airisu.line : 0
            startX: 0; startY: 0
            PathLine { x: root.width - root.cut; y: 0 }
            PathLine { x: root.width; y: root.cut }
            PathLine { x: root.width; y: root.height }
            PathLine { x: root.cut; y: root.height }
            PathLine { x: 0; y: root.height - root.cut }
            PathLine { x: 0; y: 0 }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: root.glyph.length > 0 && root.text.length === 0
        text: root.glyph
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.round(root.height * 0.46)
        font.variableAxes: { "FILL": 1, "wght": 600 }
        color: root.ink
    }
    AText {
        id: label
        anchors.centerIn: parent
        visible: root.text.length > 0
        voice: "wide"
        size: IrisStyle.typeLabel
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(IrisStyle.typeLabel * 0.08)
        text: root.text
        color: root.ink
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
}
