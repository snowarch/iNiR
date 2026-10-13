import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's card head: where it came from set small over what it is now, the live state in full ink and a step heavier;
// a card with no live line is its name alone. Air, not a rule, parts it from what it holds. The host is a CardHeader and
// keeps its actions at the right.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property string detail: String(root.host?.detail ?? "")
    readonly property bool twoLines: root.detail.length > 0
    implicitHeight: column.implicitHeight + Airisu.u(2)

    Column {
        id: column
        width: parent.width
        spacing: Airisu.u(0.5)
        AText {
            visible: root.twoLines
            width: parent.width
            size: IrisStyle.typeFootnote
            font.weight: Font.Bold
            color: Airisu.inkSecond
            text: root.title
        }
        AText {
            width: parent.width
            size: IrisStyle.typeHeadline
            font.weight: Font.Bold
            text: root.twoLines ? root.detail : root.title
        }
    }
}
