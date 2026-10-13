import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's button: a key (AKey). The primary action is a key of the accent's lacquer (the danger's, when it destroys);
// the chosen one wears the chosen plate; any other is a tag, its die ruled in the second ink of what it sits on (a key of
// the body's next coat read as a grey key that cannot be taken), and a quiet one is its words alone. The pointer and the
// keyboard bring the key's crop marks, a press its register. One that cannot be taken is ruled dashed. Its words are cut out of the lacquer
// in the lacquer's own ink.
Item {
    id: root
    property Item host
    readonly property bool emphasized: root.host?.emphasized ?? false
    readonly property bool danger: root.host?.danger ?? false
    readonly property bool selected: root.host?.selected ?? false
    readonly property bool quiet: root.host?.quiet ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property string text: String(root.host?.text ?? "")
    // What a quiet key's coat is laid on, when the caller sits it on a coloured panel (`skinData.under`).
    readonly property color under: root.host?.skinData?.under ?? Airisu.ground
    readonly property bool tag: !root.quiet && (!root.available || !(root.emphasized || root.selected))
    readonly property color lacquer: !root.available || root.tag ? "transparent"
        : root.emphasized ? (root.danger ? Airisu.danger : Airisu.seal)
        : root.selected ? IrisStyle.selectionFill : "transparent"
    readonly property color ink: !root.available ? Airisu.inkThirdOn(root.under)
        : root.emphasized || root.selected ? Airisu.inkOn(root.lacquer)
        : root.danger ? Airisu.danger : Airisu.inkOn(root.under)
    // How far a press carries the content; the host moves its own by it.
    readonly property int shift: key.shift

    AKey {
        id: key
        anchors.fill: parent
        lacquer: root.lacquer
        under: root.under
        hovered: root.host?.hovered ?? false
        pressed: root.host?.down ?? false
        keyed: root.host?.visualFocus ?? false
        available: root.available
    }
    ADie {
        visible: root.tag
        x: root.shift
        y: root.shift
        width: parent.width
        height: parent.height
        kind: "chamfer"
        cut: key.cut
        stroke: root.available ? Airisu.inkSecondOn(root.under) : Airisu.inkThirdOn(root.under)
        strokeWidth: Airisu.hair
        dashed: !root.available
    }
    AText {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.shift
        anchors.verticalCenterOffset: root.shift
        width: Math.min(implicitWidth, root.width - 4 * Airisu.m)
        horizontalAlignment: Text.AlignHCenter
        visible: root.text.length > 0
        size: IrisStyle.typeLabel
        font.weight: root.emphasized || root.selected ? Font.Bold : Font.DemiBold
        text: root.text
        color: root.ink
    }
}
