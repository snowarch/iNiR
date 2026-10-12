import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's section mark in a list (SYSTEM.md §4, the catalogue's index tab, ツメ): the section's name reversed out of a
// tab in its line colour, as a catalogue colours the tab of each section on its fore-edge; a section with no line (the
// top hit, the suggestions, the clipboard) has its tab in the ink. The tab stands on the list's left rule, at the foot
// of the room the engine keeps for the head, so the chosen row under it reads as the leaf it opens.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property var tint: root.host?.tint ?? null
    readonly property bool lined: root.tint !== null && root.tint !== undefined
    readonly property color plate: root.lined ? root.tint : Airisu.ink
    readonly property real d: Airisu.d
    implicitHeight: Airisu.u(5)

    Rectangle {
        x: Math.round(8 * root.d)
        anchors.bottom: parent.bottom
        width: Math.min(parent.width - x, label.implicitWidth + 2 * Airisu.u(2))
        height: Airisu.u(5)
        color: root.plate
        AText {
            id: label
            x: Airisu.u(2)
            width: parent.width - 2 * Airisu.u(2)
            anchors.verticalCenter: parent.verticalCenter
            size: IrisStyle.typeFootnote
            font.weight: Font.Bold
            color: root.lined ? IrisStyle.onTintFor(root.tint) : Airisu.reverse
            text: root.title
        }
    }
}
