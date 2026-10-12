import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's group head in a Settings page (SYSTEM.md §4, Place = 冊子, a catalogue): a section of the catalogue opens on
// its name set small over a full-width rule, and air does the rest; no card, no count. A group that is one switch keeps
// it on the name's line (the host lays it at the right), so the line is as tall as the switch and the rule runs under both.
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property bool lone: root.host?.lone ?? false
    readonly property real line: Math.max(name.implicitHeight, root.lone ? Number(root.host?.switchHeight ?? 0) : 0)
    implicitHeight: root.line + Airisu.u(2) + Airisu.hair

    AText {
        id: name
        y: Math.round((root.line - implicitHeight) / 2)
        width: parent.width - Airisu.u(16)
        size: IrisStyle.typeLabel
        font.weight: Font.Bold
        text: root.title
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Airisu.hair
        color: Airisu.inkSecond
    }
}
