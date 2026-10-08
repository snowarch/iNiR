pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: shapeRoot
    readonly property real naturalWidth: Math.round(440 * shapeRoot.d)
    readonly property real naturalHeight: Math.round(260 * shapeRoot.d)
    readonly property bool notch: shapeRoot.opt("iris.bar.notch", false)
    readonly property bool dockNotch: shapeRoot.opt("iris.dock.notch", false)
    readonly property real rest: IrisFrame.islandBand
    readonly property real gap: shapeRoot.notch ? 0 : Math.round(14 * shapeRoot.d)
    readonly property real dockThick: IrisFrame.dockBand
    readonly property real dockGap: shapeRoot.dockNotch ? 0 : Math.round(14 * shapeRoot.d)
    readonly property real bubble: Math.round(shapeRoot.rest * 0.86)
    readonly property var resting: ({ x: Math.round(34 * shapeRoot.d), y: shapeRoot.gap, width: Math.round(150 * shapeRoot.d), height: shapeRoot.rest })
    readonly property var bubbleAt: ({ x: shapeRoot.resting.x + shapeRoot.resting.width + Math.round(6 * shapeRoot.d),
        y: shapeRoot.gap + (shapeRoot.rest - shapeRoot.bubble) / 2, width: shapeRoot.bubble, height: shapeRoot.bubble })
    readonly property var opened: ({ x: Math.round(width - 34 * shapeRoot.d - 190 * shapeRoot.d), y: shapeRoot.gap, width: Math.round(190 * shapeRoot.d), height: Math.round(104 * shapeRoot.d) })
    readonly property var docked: ({ x: Math.round(width / 2 - 120 * shapeRoot.d), y: height - shapeRoot.dockThick - shapeRoot.dockGap,
        width: Math.round(240 * shapeRoot.d), height: shapeRoot.dockThick })
    readonly property real openCorner: Math.min(shapeRoot.opened.height / 2,
        IrisStyle.openedRadius(IrisStyle.barShape, Math.max(IrisStyle.radius, 30 * shapeRoot.d)))
    function shapeName(shape: string): string {
        return Translation.tr(({ round: "Round", squircle: "Squircle", square: "Square" })[shape] ?? "Auto")
    }
    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: {
            const deep = Math.max(8, IrisStyle.fuseDeep * 2), f = IrisStyle.fuseDeep
            const out = []
            if (shapeRoot.notch) out.push({ x: -2 * f, y: -deep, width: width + 4 * f, height: deep, radius: 0, fuse: f, id: "edge", paints: true })
            const join = shapeRoot.notch ? "edge" : ""
            const fuse = shapeRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse
            out.push(Object.assign({ radius: IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.barShape, shapeRoot.notch), shapeRoot.rest),
                fuse: fuse, id: "island", joins: join, paints: true }, shapeRoot.resting))
            out.push(Object.assign({ radius: IrisStyle.pieceRadius(shapeRoot.bubble), fuse: IrisStyle.fuse, id: "satellite", joins: "island", paints: true }, shapeRoot.bubbleAt))
            out.push(Object.assign({ radius: shapeRoot.openCorner, fuse: fuse, id: "open", joins: join, paints: true }, shapeRoot.opened))
            if (shapeRoot.dockNotch) out.push({ x: -2 * f, y: height, width: width + 4 * f, height: deep, radius: 0, fuse: f, id: "dockEdge", paints: true })
            out.push(Object.assign({ radius: IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.dockShape, shapeRoot.dockNotch), shapeRoot.dockThick),
                fuse: shapeRoot.dockNotch ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "dock", joins: shapeRoot.dockNotch ? "dockEdge" : "", paints: true }, shapeRoot.docked))
            return out
        }
    }
    IrisClock {
        x: shapeRoot.resting.x + (shapeRoot.resting.width - width) / 2
        y: shapeRoot.resting.y + (shapeRoot.resting.height - height) / 2
        pixelSize: IrisStyle.typeHeadline
        separatorColor: IrisStyle.secondaryAccent
    }
    Column {
        x: shapeRoot.opened.x + IrisStyle.concentricPad(shapeRoot.openCorner, 16 * shapeRoot.d)
        y: shapeRoot.opened.y + IrisStyle.concentricPad(shapeRoot.openCorner, 16 * shapeRoot.d)
        spacing: Math.round(8 * shapeRoot.d)
        Rectangle { width: Math.round(96 * shapeRoot.d); height: Math.round(10 * shapeRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fillHover }
        Rectangle { width: Math.round(140 * shapeRoot.d); height: Math.round(10 * shapeRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fill }
        Row {
            spacing: Math.round(8 * shapeRoot.d)
            Repeater { model: 3; Rectangle { required property int index; width: Math.round(40 * shapeRoot.d); height: Math.round(30 * shapeRoot.d); radius: IrisStyle.radiusTile; color: IrisStyle.fillQuiet } }
        }
    }
    Row {
        x: shapeRoot.docked.x + Math.round((shapeRoot.docked.width - width) / 2)
        y: shapeRoot.docked.y + Math.round((shapeRoot.docked.height - height) / 2)
        spacing: Math.round(10 * shapeRoot.d)
        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: IrisFrame.dockIcon * 0.8; height: width
                radius: IrisStyle.iconRadius(width)
                color: index === 2 ? IrisStyle.fillActive : IrisStyle.fillHover
            }
        }
    }
    Caption {
        glyph: "rounded_corner"
        text: Translation.tr("Island shape") + " · " + shapeRoot.shapeName(IrisStyle.barShape) + "   " + Translation.tr("Dock shape") + " · " + shapeRoot.shapeName(IrisStyle.dockShape)
    }
}
