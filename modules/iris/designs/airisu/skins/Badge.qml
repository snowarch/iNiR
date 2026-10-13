import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's count: a small die of message lacquer (what is waiting to be read) with its figure cut out of it, leaning.
// It is never the accent: the dock's one live thing is the focused window, and a count is a fact, not a warning.
Item {
    id: root
    property Item host
    readonly property string figure: String(root.host?.figure ?? "")
    readonly property color face: Airisu.vivid(Airisu.pigment("message"))

    ALacquer {
        anchors.fill: parent
        cut: Math.max(2, Math.round(root.height / 4))
        lacquer: root.face
        moving: false
    }
    AText {
        anchors.centerIn: parent
        voice: "figure"
        size: Math.round((root.figure.length > 1 ? 0.52 : 0.62) * root.height)
        text: root.figure
        color: Airisu.inkOn(root.face)
    }
}
