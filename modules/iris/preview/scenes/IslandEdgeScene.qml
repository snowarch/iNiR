pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.bar.island as IslandParts
import qs.modules.iris.preview.parts

PreviewScene {
    id: edgeRoot
    readonly property real naturalWidth: Math.round(640 * edgeRoot.d)
    readonly property real naturalHeight: Math.round(320 * edgeRoot.d)
    readonly property string edge: IrisFrame.islandEdge
    readonly property bool vertical: edgeRoot.edge === "left" || edgeRoot.edge === "right"
    readonly property bool notch: edgeRoot.opt("iris.bar.notch", false)
    readonly property string layout: String(edgeRoot.opt("iris.bar.layout", "island"))
    readonly property bool spans: edgeRoot.layout === "full" || (edgeRoot.layout === "menubar" && !edgeRoot.vertical)
    readonly property real thick: IrisFrame.islandBand
    readonly property real span: edgeRoot.vertical ? height : width
    // A spanning bar that floats keeps its gap on every side (IrisFrame.islandMargin is 0 with the notch).
    readonly property real length: edgeRoot.spans ? edgeRoot.span - 2 * (IrisFrame.band + IrisFrame.islandMargin)
        : Math.round(edgeRoot.thick * (edgeRoot.vertical ? 3.2 : 3.6))
    readonly property real along: edgeRoot.spans ? IrisFrame.band + IrisFrame.islandMargin
        : edgeRoot.layout === "left" ? IrisFrame.band + Math.round(20 * edgeRoot.d)
        : edgeRoot.layout === "right" ? edgeRoot.span - edgeRoot.length - IrisFrame.band - Math.round(20 * edgeRoot.d)
        : Math.round((edgeRoot.span - edgeRoot.length) / 2)
    readonly property real inset: IrisFrame.band + IrisFrame.islandMargin
    property real t: 0
    Loop on t { running: edgeRoot.playing }
    readonly property real depth: -edgeRoot.thick - 4 + (edgeRoot.inset + edgeRoot.thick + 4) * edgeRoot.t
    function place(along: real, length: real, depth: real, thick: real): var {
        const across = edgeRoot.edge === "bottom" ? height - depth - thick : edgeRoot.edge === "right" ? width - depth - thick : depth
        return edgeRoot.vertical ? { x: across, y: along, width: thick, height: length } : { x: along, y: across, width: length, height: thick }
    }
    readonly property var island: edgeRoot.place(edgeRoot.along, edgeRoot.length, edgeRoot.depth, edgeRoot.thick)
    readonly property real bubble: Math.round(edgeRoot.thick * 0.86)
    readonly property var satellites: edgeRoot.spans ? [] : [
        edgeRoot.place(edgeRoot.along - Math.round(6 * edgeRoot.d) - edgeRoot.bubble, edgeRoot.bubble, edgeRoot.depth + (edgeRoot.thick - edgeRoot.bubble) / 2, edgeRoot.bubble),
        edgeRoot.place(edgeRoot.along + edgeRoot.length + Math.round(6 * edgeRoot.d), edgeRoot.bubble, edgeRoot.depth + (edgeRoot.thick - edgeRoot.bubble) / 2, edgeRoot.bubble)
    ]
    function edgeBody(): var {
        const deep = Math.max(8, IrisStyle.fuseDeep * 2), f = IrisStyle.fuseDeep
        switch (edgeRoot.edge) {
        case "bottom": return { x: -2 * f, y: height, width: width + 4 * f, height: deep }
        case "left": return { x: -deep, y: -2 * f, width: deep, height: height + 4 * f }
        case "right": return { x: width, y: -2 * f, width: deep, height: height + 4 * f }
        default: return { x: -2 * f, y: -deep, width: width + 4 * f, height: deep }
        }
    }
    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: {
            const out = []
            const clear = edgeRoot.layout === "menubar" && !edgeRoot.vertical && String(edgeRoot.opt("iris.bar.strip", "clear")) === "clear"
            if (edgeRoot.notch || clear) out.push(Object.assign({ radius: 0, fuse: IrisStyle.fuseDeep, id: "edge", paints: true }, edgeRoot.edgeBody()))
            if (!clear) out.push(Object.assign({ radius: edgeRoot.spans ? (edgeRoot.notch ? 0 : IrisStyle.pieceRadius(edgeRoot.thick))
                : IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.barShape, edgeRoot.notch), edgeRoot.thick),
                fuse: edgeRoot.spans && !edgeRoot.vertical ? Math.round(16 * edgeRoot.d) : edgeRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse,
                id: "island", joins: edgeRoot.notch ? "edge" : "", paints: true }, edgeRoot.island))
            if (edgeRoot.layout === "menubar" && !edgeRoot.vertical) {
                const height = IrisFrame.islandFullBand
                const width = Math.round(height * 4.2)
                out.push(Object.assign({ radius: IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.barShape, true), height), fuse: clear ? IrisStyle.fuseEdge : Math.round(32 * edgeRoot.d),
                    id: "islandnotch", joins: clear ? "edge" : "island", paints: true },
                    edgeRoot.place((edgeRoot.span - width) / 2, width, edgeRoot.depth, height)))
            }
            edgeRoot.satellites.forEach((sat, i) => out.push(Object.assign({ radius: IrisStyle.pieceRadius(edgeRoot.bubble), fuse: IrisStyle.fuse,
                id: "satellite" + i, joins: "island", paints: true }, sat)))
            return out
        }
    }
    IrisClock {
        visible: !edgeRoot.vertical
        opacity: edgeRoot.t
        x: edgeRoot.island.x + (edgeRoot.island.width - width) / 2
        y: edgeRoot.island.y + (edgeRoot.island.height - height) / 2
        pixelSize: IrisStyle.typeHeadline
        separatorColor: IrisStyle.secondaryAccent
    }
    IslandParts.IslandStackedClock {
        visible: edgeRoot.vertical
        opacity: edgeRoot.t
        x: edgeRoot.island.x + (edgeRoot.island.width - width) / 2
        y: edgeRoot.island.y + (edgeRoot.island.height - height) / 2
        pixelSize: IrisStyle.typeHeadline
        accent: IrisStyle.secondaryAccent
    }
    Caption {
        anchors.leftMargin: edgeRoot.edge === "left" ? edgeRoot.inset + edgeRoot.thick + Math.round(14 * edgeRoot.d) : Math.round(14 * edgeRoot.d)
        glyph: ({ top: "vertical_align_top", bottom: "vertical_align_bottom", left: "align_horizontal_left", right: "align_horizontal_right" })[edgeRoot.edge] ?? "pill"
        text: Translation.tr(({ top: "Top edge", bottom: "Bottom edge", left: "Left edge", right: "Right edge" })[edgeRoot.edge] ?? "")
            + " · " + (edgeRoot.layout === "menubar" ? Translation.tr("a menu bar with a notch") : edgeRoot.spans ? Translation.tr("a bar across it") : edgeRoot.notch ? Translation.tr("melts into it") : Translation.tr("floats off it"))
    }
}
