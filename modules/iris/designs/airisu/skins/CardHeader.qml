import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's card head (board Components › CABECERA DE TARJETA, small): the glyph in its line weight, the name wide in
// capitals with the body stripe after it, the live detail in mono under. The host is a CardHeader.
Item {
    id: root
    property Item host
    readonly property string detail: String(root.host?.detail ?? "")
    implicitHeight: Math.max(glyph.height, column.implicitHeight)

    MaterialSymbol {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        text: root.host?.glyph ?? ""
        iconSize: Math.round(18 * Airisu.d)
        fill: 0
        color: Airisu.data
    }
    Column {
        id: column
        anchors.left: glyph.right
        anchors.leftMargin: Math.round(10 * Airisu.d)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(2 * Airisu.d)
        Row {
            spacing: Math.round(10 * Airisu.d)
            width: parent.width
            AText {
                id: name
                width: Math.min(implicitWidth, parent.width - stripe.width - parent.spacing)
                voice: "wide"
                size: IrisStyle.typeLabel
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0
                elide: Text.ElideRight
                text: root.host?.title ?? ""
            }
            AStripe {
                id: stripe
                anchors.verticalCenter: name.verticalCenter
                width: Math.round(22 * Airisu.d)
                height: Math.round(5 * Airisu.d)
                single: true
            }
        }
        AText {
            visible: root.detail.length > 0
            width: parent.width
            voice: "mono"
            color: Airisu.quiet
            elide: Text.ElideRight
            text: root.detail
        }
    }
}
