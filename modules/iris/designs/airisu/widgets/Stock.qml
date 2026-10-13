import QtQuick
import "../components"

// AIRISU's stock for every widget it does not print whole: the urushi panel the widgets it prints stand on (AStock), so
// a widget drawn by iRiS's faces is made of the same lacquer, follows the same Material, Opacity and Tint rows, and its
// type takes the lacquer's ink.
Item {
    id: root
    property var face
    readonly property color ink: stock.ink
    readonly property color accent: stock.vivid
    readonly property color accent2: stock.vivid2

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }
}
