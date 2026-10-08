pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: joinRoot
    readonly property real naturalWidth: Math.round(640 * joinRoot.d)
    readonly property real naturalHeight: Math.round(300 * joinRoot.d)
    readonly property bool along: String(joinRoot.opt("iris.appearance.theme.placement", "auto")) === "along"
    readonly property real air: IrisFrame.bodyAir
    readonly property real bubble: IrisFrame.islandBand
    readonly property var island: ({ x: Math.round(width / 2 - 170 * joinRoot.d), y: IrisFrame.band, width: Math.round(150 * joinRoot.d), height: joinRoot.bubble })
    readonly property var origin: ({ x: joinRoot.island.x + joinRoot.island.width + Math.round(6 * joinRoot.d), y: IrisFrame.band, width: joinRoot.bubble, height: joinRoot.bubble })
    readonly property var card: joinRoot.along
        ? ({ x: joinRoot.origin.x + joinRoot.origin.width + IrisStyle.weld, y: IrisFrame.band, width: Math.round(200 * joinRoot.d), height: Math.round(130 * joinRoot.d) })
        : ({ x: joinRoot.origin.x + joinRoot.origin.width / 2 - Math.round(100 * joinRoot.d), y: joinRoot.origin.y + joinRoot.origin.height + IrisStyle.weld, width: Math.round(200 * joinRoot.d), height: Math.round(130 * joinRoot.d) })
    readonly property var neighbour: ({ x: joinRoot.card.x + joinRoot.card.width + joinRoot.air, y: joinRoot.card.y + (joinRoot.along ? 0 : Math.round(20 * joinRoot.d)), width: Math.round(120 * joinRoot.d), height: Math.round(100 * joinRoot.d) })
    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: {
            const deep = Math.max(8, IrisStyle.fuseDeep * 2)
            const sheet = IrisStyle.radiusSheet
            return [
                { x: -2 * IrisStyle.fuseDeep, y: -deep - 1 + IrisFrame.band, width: joinRoot.width + 4 * IrisStyle.fuseDeep, height: deep, radius: 0, fuse: IrisStyle.fuseDeep, id: "edge", paints: true },
                Object.assign({ radius: joinRoot.bubble / 2, fuse: IrisStyle.fuseEdge, id: "island", joins: "edge", paints: true }, joinRoot.island),
                Object.assign({ radius: IrisStyle.pieceRadius(joinRoot.bubble), fuse: IrisStyle.fuse, id: "origin", joins: "island", paints: true }, joinRoot.origin),
                Object.assign({ radius: sheet, fuse: IrisStyle.fuse, id: "card", joins: "origin", paints: true }, joinRoot.card),
                Object.assign({ radius: sheet, fuse: IrisStyle.fuse, id: "neighbour", paints: true }, joinRoot.neighbour)
            ]
        }
    }
    MaterialSymbol { x: joinRoot.origin.x + (joinRoot.origin.width - width) / 2; y: joinRoot.origin.y + (joinRoot.origin.height - height) / 2; text: "partly_cloudy_day"; fill: 1; iconSize: Math.round(18 * joinRoot.d); color: IrisStyle.identity.sky }
    IrisClock { x: joinRoot.island.x + (joinRoot.island.width - width) / 2; y: joinRoot.island.y + (joinRoot.island.height - height) / 2; pixelSize: IrisStyle.typeHeadline; separatorColor: IrisStyle.secondaryAccent }
    Rectangle {
        visible: joinRoot.air > 0
        x: joinRoot.card.x + joinRoot.card.width
        y: joinRoot.neighbour.y + joinRoot.neighbour.height / 2
        width: joinRoot.air; height: 2
        color: IrisStyle.accent
    }
    Caption {
        glyph: joinRoot.along ? "swap_horiz" : "south"
        text: (joinRoot.along ? Translation.tr("Opens along the edge") : Translation.tr("Opens away from the edge"))
            + " · " + Translation.tr("air %1 px").arg(Math.round(joinRoot.air / joinRoot.d))
    }
}
