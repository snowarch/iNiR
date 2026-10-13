import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's lock plate: the piece of the frosted scene iRiS's lock lays under the player, the card and the chips, cut
// with AIRISU's die (the chamfer) instead of a round corner. Lock › Plates keeps its meaning: Glass is the frosted
// piece under the glass wash with its rule, Tint the scrim alone, Nothing only the rule where the plate asks for one.
Item {
    id: root
    property var host
    readonly property string material: root.host?.material ?? "glass"
    readonly property Item frost: root.host?.frost ?? null
    readonly property bool frosted: root.material === "glass" && root.frost !== null
    readonly property point at: root.host?.at ?? Qt.point(0, 0)
    readonly property real zoom: root.host?.zoom ?? 1
    readonly property real cut: Airisu.cutFor(root.height)

    // The plate's own piece of the frost, the size of the die so it fills it pixel for pixel.
    ShaderEffectSource {
        id: piece
        visible: false
        width: root.width
        height: root.height
        sourceItem: root.frosted ? root.frost : null
        sourceRect: Qt.rect(root.at.x, root.at.y, root.width * root.zoom, root.height * root.zoom)
        hideSource: false
        live: true
    }
    ADie {
        anchors.fill: parent
        visible: root.frosted
        kind: "chamfer"
        cut: root.cut
        texture: piece
    }
    ADie {
        anchors.fill: parent
        visible: root.material !== "none" || (root.host?.outline ?? false)
        kind: "chamfer"
        cut: root.cut
        fill: root.material === "glass" ? IrisStyle.mediaGlass : root.material === "tint" ? IrisStyle.mediaScrim : "transparent"
        stroke: root.material === "none" ? IrisStyle.onMediaFill : IrisStyle.mediaHairline
        strokeWidth: root.material === "tint" ? 0 : Airisu.hair
    }
}
