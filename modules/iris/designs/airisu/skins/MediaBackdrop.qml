import QtQuick
import Quickshell
import qs.modules.iris.style
import "../components"

// AIRISU's cover behind a player (the Control Center's, a media card's): not the picture again, but the record's own
// lacquer, the colour its cover is printed in, laid where the cover would be blurred; a new record repaints it at 45°.
// The owner keeps where it sits and whether it shows.
Item {
    id: root
    property Item host
    readonly property string source: String(root.host?.source ?? "")
    ColorQuantizer {
        id: quantizer
        source: root.source
        depth: 2
        rescaleSize: 24
    }
    ALacquer {
        anchors.fill: parent
        cut: 0
        lacquer: Airisu.lacquerOf(Airisu.recordPigment(IrisStyle.artTintOf(quantizer.colors)))
    }
}
