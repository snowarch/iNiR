import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's button (board Components): a plate cut with a blade at its upper-right and lower-left corners. Emphasized
// is the vermilion seal (ACEPTAR), chosen the gofun plate, danger kerria amber, a resting one a 1 px iron outline that
// fills with sumi under the pointer, a quiet one nothing until hovered. Text in the wide face, capitals on a seal.
Item {
    id: root
    property Item host
    readonly property bool emphasized: root.host?.emphasized ?? false
    readonly property bool danger: root.host?.danger ?? false
    readonly property bool selected: root.host?.selected ?? false
    readonly property bool quiet: root.host?.quiet ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: root.host?.down ?? root.host?.pressed ?? false
    readonly property string kind: root.danger && root.emphasized ? "amber" : root.emphasized ? "seal"
        : root.selected ? "gofun" : root.quiet ? "quiet" : "line"
    readonly property color plate: root.kind === "amber" ? Airisu.amber : root.kind === "seal" ? Airisu.seal
        : root.kind === "gofun" ? Airisu.gofun : root.hovered || root.pressed ? Airisu.sumi : "transparent"
    readonly property color ink: root.kind === "amber" ? Airisu.inkOnAmber : root.kind === "seal" ? Airisu.inkOnSeal
        : root.kind === "gofun" ? Airisu.inkOnGofun : root.danger ? Airisu.amber : Airisu.gofun
    // A chip is a sticker label, square; small square buttons (a glyph) take a smaller cut, so the blade never eats it.
    readonly property bool chip: root.host?.labelCap !== undefined
    readonly property real cut: root.chip ? 0 : Math.min(Airisu.cut, Math.round(Math.min(width, height) / 4))
    readonly property string text: String(root.host?.text ?? "")

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.pressed && root.kind !== "line" && root.kind !== "quiet" ? Qt.darker(root.plate, 1.08) : root.plate // iris-literal: pressed is a step of the pigment
            strokeColor: root.kind === "line" ? (root.hovered ? Airisu.gofun : Airisu.fillet) : "transparent"
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
    AText {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - Math.round(16 * Airisu.d))
        horizontalAlignment: Text.AlignHCenter
        visible: root.text.length > 0
        // A plate (seal, amber, gofun) speaks in wide capitals; an outline or a quiet button in Archivo.
        readonly property bool plated: root.kind === "seal" || root.kind === "amber" || root.kind === "gofun"
        voice: plated ? "wide" : "body"
        size: IrisStyle.typeLabel
        font.capitalization: plated ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: plated ? Math.round(IrisStyle.typeLabel * 0.08) : 0
        text: root.text
        color: root.ink
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Math.round(3 * Airisu.d)
        color: "transparent"
        border.width: root.host?.visualFocus ? 2 : 0
        border.color: Airisu.gofun
    }
}
