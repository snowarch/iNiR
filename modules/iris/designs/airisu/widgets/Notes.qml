import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's notes: a page of ruled paper (罫紙) on message's lacquer. Its name as a ruby in the data face's capitals with
// how many words it holds at the end; the engine's widget keeps the writing and the page's rules over it.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property int words: Number(root.face?.words ?? 0)

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "message"
    }
    Item {
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.dp(20)
        AText {
            anchors.verticalCenter: parent.verticalCenter
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: Translation.tr("Notes")
        }
        AText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.words > 0 && !root.small
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkThird
            text: Translation.tr("%1 words").arg(root.words)
        }
    }
    ABlank {
        visible: root.face?.blank ?? false
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        face: root.face
        stock: stock
        label: Translation.tr("Empty")
        line: Translation.tr("Click anywhere on the page to start")
    }
}
