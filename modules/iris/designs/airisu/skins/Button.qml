import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's button (SYSTEM.md §6, board Piezas). The primary action is the seal: the chamfer die in 朱, its label in the
// seal's ink. The chosen one is a solid ink plate with the label reversed out. Any other is a tag, a rule round a
// rectangle; a quiet one is its label alone. The pointer brings the crop marks, the keyboard the seal's marks, a press
// runs the plate out of register, and an inactive button is printed as a screen, never faded.
Item {
    id: root
    property Item host
    readonly property bool emphasized: root.host?.emphasized ?? false
    readonly property bool danger: root.host?.danger ?? false
    readonly property bool selected: root.host?.selected ?? false
    readonly property bool quiet: root.host?.quiet ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: root.host?.down ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property bool keyed: root.host?.visualFocus ?? false
    readonly property string text: String(root.host?.text ?? "")
    readonly property string kind: root.emphasized ? "seal" : root.selected ? "plate" : root.quiet ? "quiet" : "tag"
    readonly property color ink: root.kind === "seal" ? Airisu.inkOnSeal : root.kind === "plate" ? Airisu.reverse
        : root.danger ? Airisu.danger : root.available ? Airisu.ink : Airisu.inkThird
    // How far the top plate runs out of register while pressed; the host carries its own content by it.
    readonly property int shift: root.pressed && root.available ? Airisu.registration : 0

    APrint {
        id: plate
        anchors.fill: parent
        visible: root.kind !== "quiet"
        die: root.kind === "seal" ? "chamfer" : "rect"
        pressed: root.pressed && root.available
        fill: !root.available ? "transparent" : root.kind === "seal" ? Airisu.seal : root.kind === "plate" ? Airisu.ink : "transparent"
        under: root.kind === "seal" ? Airisu.sealUnder : Airisu.inkUnder
        stroke: root.kind === "tag" ? (root.danger ? Airisu.danger : root.available ? Airisu.ink : Airisu.inkThird) : "transparent"
        strokeWidth: root.kind === "tag" ? Airisu.hair : 0
        dashed: !root.available && root.kind === "tag"
        // An inactive plate is its pigment as a screen.
        AScreen {
            anchors.fill: parent
            visible: !root.available && root.kind !== "tag"
            pigment: root.kind === "seal" ? Airisu.seal : Airisu.ink
            density: 25
        }
        AText {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, root.width - 4 * Airisu.m)
            horizontalAlignment: Text.AlignHCenter
            visible: root.text.length > 0
            size: IrisStyle.typeLabel
            font.weight: root.kind === "seal" || root.kind === "plate" ? Font.Bold : Font.DemiBold
            text: root.text
            color: root.ink
        }
    }
    // A quiet button is its words alone, with the dotted rule of a printed form under them.
    AText {
        id: quietLabel
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.pressed ? Airisu.registration : 0
        anchors.verticalCenterOffset: root.pressed ? Airisu.registration : 0
        width: Math.min(implicitWidth, root.width - 2 * Airisu.m)
        horizontalAlignment: Text.AlignHCenter
        visible: root.kind === "quiet" && root.text.length > 0
        size: IrisStyle.typeLabel
        text: root.text
        color: root.ink
    }
    APerforation {
        visible: quietLabel.visible && root.hovered
        anchors.top: quietLabel.baseline
        anchors.topMargin: Airisu.u(1)
        anchors.left: quietLabel.left
        width: quietLabel.width
        colour: root.ink
    }
    ATombo {
        anchors.fill: parent
        shown: root.hovered && root.available && !root.pressed
        focusMarks: root.keyed
    }
}
