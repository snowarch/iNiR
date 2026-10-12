import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's count (SYSTEM.md §6, badge): a station number, the disc on a Japanese platform sign with its figure set
// solid inside a heavy ring. It is printed on the stock, so it cuts itself out of the icon it sits on, and it is never
// the seal: the dock's one live thing is the focused window. A count that is not yet read is a fact, not a warning.
Item {
    id: root
    property Item host
    readonly property string figure: String(root.host?.figure ?? "")
    readonly property real ring: Math.max(Airisu.strong, Math.round(root.width * 0.12))

    // The disc, cut with the compass; the ring is the ink, the face the stock.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Airisu.ground
        border.width: root.ring
        border.color: Airisu.ink
    }
    AText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(root.height * 0.03)
        font.weight: Font.Bold
        size: Math.round((root.figure.length > 1 ? 0.5 : 0.6) * root.height)
        text: root.figure
        color: Airisu.ink
    }
}
