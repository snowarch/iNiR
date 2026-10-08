pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: fuseRoot
    readonly property real naturalWidth: Math.round(620 * fuseRoot.d)
    readonly property real naturalHeight: Math.round(300 * fuseRoot.d)
    readonly property real melt: Number(fuseRoot.opt("iris.appearance.theme.melt", 0))
    readonly property real corners: Number(fuseRoot.opt("iris.appearance.theme.shape", 100))
    readonly property real bubble: IrisFrame.islandBand
    property real t: 0
    Loop on t { running: fuseRoot.playing; rest: 900 }
    readonly property var island: ({ x: Math.round(width / 2 - 90 * fuseRoot.d), y: Math.round(24 * fuseRoot.d), width: Math.round(180 * fuseRoot.d), height: fuseRoot.bubble })
    readonly property var satellite: ({ x: fuseRoot.island.x + fuseRoot.island.width + Math.round(6 * fuseRoot.d), y: fuseRoot.island.y, width: fuseRoot.bubble, height: fuseRoot.bubble })
    readonly property real cardTop: fuseRoot.island.y + fuseRoot.island.height + Math.round(40 * fuseRoot.d) * (1 - fuseRoot.t) - IrisStyle.weld * fuseRoot.t
    readonly property var card: ({ x: Math.round(width / 2 - 130 * fuseRoot.d), y: fuseRoot.cardTop, width: Math.round(260 * fuseRoot.d), height: Math.round(150 * fuseRoot.d) })
    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: [
            Object.assign({ radius: fuseRoot.bubble / 2, fuse: IrisStyle.fuse, id: "island", paints: true }, fuseRoot.island),
            Object.assign({ radius: IrisStyle.pieceRadius(fuseRoot.bubble), fuse: IrisStyle.fuse, id: "satellite", joins: "island", paints: true }, fuseRoot.satellite),
            Object.assign({ radius: IrisStyle.radiusSheet, fuse: IrisStyle.fuseDeep, id: "card", joins: "island", paints: true }, fuseRoot.card)
        ]
    }
    IrisClock {
        x: fuseRoot.island.x + (fuseRoot.island.width - width) / 2
        y: fuseRoot.island.y + (fuseRoot.island.height - height) / 2
        pixelSize: IrisStyle.typeHeadline
        separatorColor: IrisStyle.secondaryAccent
    }
    Column {
        x: fuseRoot.card.x + IrisStyle.concentricPad(IrisStyle.radiusSheet, 14 * fuseRoot.d)
        y: fuseRoot.card.y + IrisStyle.concentricPad(IrisStyle.radiusSheet, 14 * fuseRoot.d)
        spacing: Math.round(8 * fuseRoot.d)
        Rectangle { width: Math.round(120 * fuseRoot.d); height: Math.round(10 * fuseRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fillHover }
        Rectangle { width: Math.round(170 * fuseRoot.d); height: Math.round(10 * fuseRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fill }
        Row {
            spacing: Math.round(8 * fuseRoot.d)
            Repeater { model: 3; Rectangle { required property int index; width: Math.round(46 * fuseRoot.d); height: Math.round(34 * fuseRoot.d); radius: IrisStyle.radiusTile; color: IrisStyle.fillQuiet } }
        }
    }
    Caption {
        glyph: "join_inner"
        text: (fuseRoot.melt > 0 ? Translation.tr("Fusion %1%").arg(Math.round(fuseRoot.melt)) : Translation.tr("Crisp joins"))
            + " · " + Translation.tr("corners %1%").arg(Math.round(fuseRoot.corners))
    }
}
