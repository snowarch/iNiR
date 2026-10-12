import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's card header (board Components › CABECERA DE TARJETA): the group's name wide in capitals, the body stripe
// after it, the count in mono at the far right, a 2 px gofun rule under everything. The host is Settings' group head.
Item {
    id: root
    property Item host
    readonly property string title: root.host?.title ?? ""
    readonly property int count: root.host?.count ?? 0
    implicitHeight: name.implicitHeight + Math.round(10 * Airisu.d) + rule.height

    AText {
        id: name
        width: Math.min(implicitWidth, root.width - stripe.width - count.implicitWidth - Math.round(40 * Airisu.d))
        voice: "wide"
        size: IrisStyle.typeTitleLarge
        font.weight: Font.Black
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0
        text: root.title
    }
    AStripe {
        id: stripe
        anchors.left: name.right
        anchors.leftMargin: Math.round(14 * Airisu.d)
        anchors.verticalCenter: name.verticalCenter
        width: Math.round(56 * Airisu.d)
        height: Math.round(9 * Airisu.d)
        single: true
    }
    AText {
        id: count
        visible: root.count > 1 && !(root.host?.children?.[1]?.visible ?? false)
        anchors.right: parent.right
        anchors.baseline: name.baseline
        voice: "mono"
        color: Airisu.quiet
        text: Translation.tr("%1 settings").arg((root.count < 10 ? "0" : "") + root.count)
    }
    Rectangle {
        id: rule
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(2, Math.round(2 * Airisu.d))
        color: Airisu.gofun
    }
}
