import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's section mark in a list: the section's name cut out of a small die of its line's lacquer, as a catalogue
// colours the tab of each section; a section with no line (the top hit, the suggestions, the clipboard) wears the
// system's tame. The tab stands at the foot of the room the engine keeps for the head.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property var tint: root.host?.tint ?? null
    readonly property bool lined: root.tint !== null && root.tint !== undefined
    readonly property color face: root.lined ? Airisu.seal : Airisu.vivid(Airisu.pigment("system"))
    implicitHeight: Airisu.u(5)

    ALacquer {
        x: Math.round(8 * Airisu.d)
        anchors.bottom: parent.bottom
        width: Math.min(parent.width - x, label.implicitWidth + 2 * Airisu.u(2))
        height: Airisu.u(5)
        cut: Airisu.cutFor(height)
        lacquer: root.face
        moving: false
        AText {
            id: label
            x: Airisu.u(2)
            width: parent.width - 2 * Airisu.u(2)
            anchors.verticalCenter: parent.verticalCenter
            size: IrisStyle.typeFootnote
            font.weight: Font.Bold
            color: Airisu.inkOn(root.face)
            text: root.title
        }
    }
}
