import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's card head (SYSTEM.md §4, Body = 切符, a ticket torn from its origin): the stub. Where it came from is the
// ruby over what it is now, the live state in full ink; under them the perforation it was torn along. A card with no
// live line is its name alone. The host is a CardHeader and keeps its actions at the right.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property string detail: String(root.host?.detail ?? "")
    readonly property bool twoLines: root.detail.length > 0
    implicitHeight: column.implicitHeight + Airisu.u(2.5) + perforation.height

    Column {
        id: column
        width: parent.width
        spacing: Airisu.u(0.5)
        AText {
            visible: root.twoLines
            width: parent.width
            voice: "ruby"
            text: root.title
        }
        AText {
            width: parent.width
            size: IrisStyle.typeHeadline
            font.weight: Font.Bold
            text: root.twoLines ? root.detail : root.title
        }
    }
    APerforation {
        id: perforation
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
