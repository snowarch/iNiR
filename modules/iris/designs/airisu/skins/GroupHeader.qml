import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's group head in a Settings page: the group's glyph, as the column shows it, and its name. The group being read
// is set large in the figure voice with its glyph filled in the seal's ink, the others a step over their rows in the
// ink (smaller or greyer than the rows, a head read as a caption), so the eye finds the block in focus the way a
// catalogue sets the entry it is on. The line is always as tall as
// the large setting: the reading moving down a page never moves the rows under it. A group that is one switch keeps it
// on the name's line (the host lays it at the right).
Item {
    id: root
    property Item host
    readonly property string title: String(root.host?.title ?? "")
    readonly property string glyph: String(root.host?.glyph ?? "")
    readonly property bool lone: root.host?.lone ?? false
    readonly property bool reading: root.host?.reading ?? false
    readonly property real line: Math.max(Math.round(IrisStyle.typeTitle * 1.35), root.lone ? Number(root.host?.switchHeight ?? 0) : 0)
    implicitHeight: root.line + Airisu.u(1.5)

    MaterialSymbol {
        id: mark
        visible: root.glyph.length > 0
        anchors.verticalCenter: name.verticalCenter
        text: root.glyph
        fill: root.reading ? 1 : 0
        iconSize: Math.round((root.reading ? 20 : 16) * Airisu.d)
        color: Airisu.sealText
    }
    AText {
        id: name
        x: mark.visible ? Airisu.u(7) : 0
        y: Math.round((root.line - implicitHeight) / 2)
        width: parent.width - x - Airisu.u(16)
        voice: root.reading ? "figure" : "text"
        size: root.reading ? IrisStyle.typeTitle : IrisStyle.typeHeadline
        font.weight: root.reading ? Font.ExtraBold : Font.Bold
        color: Airisu.ink
        text: root.title
    }
}
