import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's card head, set as a sign (表示): where it came from as a ruby in the data face's capitals over what it is now
// in the figure voice, the head's one heavy line; a card with no live line is its name alone in that voice. A hairline
// rule under the head, as long as the card, closes the sign the way a catalogue sets an entry. The host is a CardHeader
// and keeps its actions at the right.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property string detail: String(root.host?.detail ?? "")
    readonly property bool twoLines: root.detail.length > 0
    implicitHeight: column.implicitHeight + Airisu.u(2.5)

    Column {
        id: column
        width: parent.width
        spacing: Airisu.u(0.5)
        AText {
            visible: root.twoLines
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeFootnote
            color: Airisu.inkSecond
            text: root.title
        }
        AText {
            width: parent.width
            voice: "figure"
            size: IrisStyle.typeHeadline
            text: root.twoLines ? root.detail : root.title
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Airisu.hair
        color: Airisu.inkThird
    }
}
