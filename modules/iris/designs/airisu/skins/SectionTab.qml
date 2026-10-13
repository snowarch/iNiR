import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's section mark in a list: a catalogue's running head. The section's name in the data face's capitals, a short
// bar of its line's colour before it (none for a section with no line: the top hit, the suggestions, the clipboard). No
// chip: a list of four sections would carry four plates of colour. It stands at the foot of the room the engine keeps
// for the head.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property var tint: root.host?.tint ?? null
    readonly property bool lined: root.tint !== null && root.tint !== undefined
    implicitHeight: Airisu.u(5)

    Row {
        id: head
        x: Math.round(8 * Airisu.d)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Airisu.u(1)
        spacing: Airisu.u(1.5)
        Rectangle {
            visible: root.lined
            anchors.verticalCenter: parent.verticalCenter
            width: Airisu.u(2)
            height: Math.max(2, Math.round(3 * Airisu.d))
            color: root.lined ? root.tint : "transparent"
            antialiasing: false
        }
        AText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            voice: "mono"
            size: IrisStyle.typeCaption
            color: Airisu.inkSecond
            text: root.title
        }
    }
}
