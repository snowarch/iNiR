import QtQuick
import qs.modules.iris.style
import "../components"

// The record under AIRISU's media page: the page laid in the record's own lacquer, the colour its cover is printed in
// (the engine's art tint; music's pigment when the cover has none), the way each record wears its own livery. A new record
// repaints it at 45°. It stands a kiss inside the body and is cut by the body's die, so the body's material frames it.
Item {
    id: root
    property var island: null
    readonly property color tint: root.island?.artTint ?? IrisStyle.text
    readonly property color pigment: Airisu.recordPigment(root.tint)
    readonly property int kiss: Airisu.kiss

    ALacquer {
        anchors.fill: parent
        anchors.margins: root.kiss
        cut: Math.max(0, Airisu.chamfer - root.kiss)
        lacquer: Airisu.lacquerOf(root.pigment)
    }
}
