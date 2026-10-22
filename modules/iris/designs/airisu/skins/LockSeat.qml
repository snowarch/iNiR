import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's seat for a lock block being carried: a die sunk into the picture where the block can settle, cut like every
// other piece and edged in the media's ink; the one it will settle on is laid in the accent's lacquer across at 45° as the block comes over it.
Item {
    id: root
    property var host
    readonly property bool hot: root.host?.hot ?? false

    ALacquer {
        anchors.fill: parent
        cut: Airisu.cutFor(root.height)
        lacquer: root.hot ? Airisu.chosenOnMedia : IrisStyle.mediaScrim
    }
    // A free seat keeps its die's edge in the media's ink, so it reads on a dark picture as on a bright one.
    ADie {
        anchors.fill: parent
        visible: !root.hot
        kind: "chamfer"
        cut: Airisu.cutFor(root.height)
        stroke: IrisStyle.onMediaTertiary
        strokeWidth: Airisu.hair
    }
}
