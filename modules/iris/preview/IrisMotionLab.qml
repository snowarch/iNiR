pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field

Item {
    id: root

    property string mode: "card"
    property bool playing: true
    property bool open: false
    readonly property real d: IrisStyle.density
    readonly property real pad: Math.round(14 * root.d)

    implicitHeight: Math.round(196 * root.d)
    clip: true

    IrisPreviewStage {
        anchors.fill: parent
    }

    Timer {
        interval: Math.max(700, IrisStyle.emergeDuration + 1100)
        running: root.playing && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.open = !root.open
    }

    readonly property real pieceSize: Math.round((root.height > 320 * root.d ? 38 : 30) * root.d)
    readonly property real cardWidth: Math.min(Math.round((root.height > 320 * root.d ? 280 : 200) * root.d),
        root.width - 2 * root.pad - root.pieceSize - 2 * root.plateGap - IrisFrame.bodyAir)
    readonly property real cardHeight: Math.round((root.height > 320 * root.d ? 180 : 132) * root.d)
    readonly property real sceneLeft: Math.max(root.pad, Math.round((root.width - root.cardWidth - IrisFrame.bodyAir
        - root.pieceSize - 2 * root.plateGap) / 2))
    readonly property real plateGap: Math.round(6 * root.d)
    readonly property var plate: ({
        x: root.sceneLeft + root.cardWidth + IrisFrame.bodyAir,
        y: root.height / 2 - root.pieceSize - 1.5 * root.plateGap,
        width: root.pieceSize + 2 * root.plateGap,
        height: 2 * root.pieceSize + 3 * root.plateGap
    })
    readonly property var piece: ({
        x: root.plate.x + root.plateGap,
        y: root.plate.y + 2 * root.plateGap + root.pieceSize,
        width: root.pieceSize,
        height: root.pieceSize,
        radius: root.pieceSize / 2,
        obstacle: root.plate
    })
    readonly property var placement: ({ sideways: true, towardsLeft: true, towardsUp: false })
    readonly property real cardAir: IrisStyle.cardJoins ? -IrisStyle.weld : Math.max(IrisFrame.bodyAir, IrisStyle.cardGap)

    IrisSpring {
        id: islandSpring
        surface: "island"
        to: root.open && root.mode === "island" ? 1 : 0
        minimum: 0
    }
    readonly property real p: islandSpring.value
    readonly property real band: Math.round(10 * root.d)
    readonly property bool atBottom: IrisFrame.islandEdge === "bottom"
    readonly property real restW: Math.round(116 * root.d)
    readonly property real restH: Math.round(30 * root.d)
    readonly property real openW: Math.min(root.width - 2 * root.pad, Math.round(236 * root.d))
    readonly property real openH: Math.round(128 * root.d)
    readonly property var island: {
        const w = root.restW + (root.openW - root.restW) * root.p
        const h = root.restH + (root.openH - root.restH) * root.p
        const r = root.restH / 2 + (Math.min(IrisStyle.radius, root.openH / 2) - root.restH / 2) * Math.min(1, root.p)
        const gap = root.band + (IrisFrame.notch ? 0 : Math.round(6 * root.d))
        return { x: Math.round((root.width - w) / 2), y: root.atBottom ? Math.round(root.height - gap - h) : gap,
            width: Math.round(w), height: Math.round(h), radius: r }
    }
    IrisSpring {
        id: satelliteSpring
        surface: "island"
        to: root.mode === "island" && root.p < IrisStyle.contentFall ? 1 : 0
        minimum: 0
    }
    readonly property real satelliteOffset: Math.round(6 * root.d) + (IrisFrame.notch ? Math.round(IrisStyle.fuseEdge / 4) : 0)

    Field.IrisField {
        anchors.fill: parent
        framed: false
        shapes: {
            void (card.x + card.y + card.width + card.height + card.progress)
            if (root.mode === "island") {
                const out = [{ x: -40, y: root.atBottom ? root.height - root.band : -40, width: root.width + 80, height: root.band + 40, radius: 0, id: "edge" }]
                const i = root.island
                out.push({ x: i.x, y: i.y, width: i.width, height: i.height, radius: i.radius, id: "island",
                    fuse: IrisFrame.notch ? IrisStyle.fuseEdge : IrisStyle.fuse, joins: IrisFrame.notch ? "edge" : "" })
                const s = Math.round(root.restH * satelliteSpring.value)
                if (s > 1) {
                    const size = root.restH - Math.round(6 * root.d)
                    out.push({ x: i.x + i.width - size + (root.satelliteOffset + size) * satelliteSpring.value,
                        y: (root.atBottom ? i.y + i.height - root.restH : i.y) + (root.restH - size) / 2, width: size, height: size, radius: size / 2,
                        id: "satellite", fuse: IrisStyle.fuse, joins: "island" })
                }
                return out
            }
            const out = [{ x: root.plate.x, y: root.plate.y, width: root.plate.width, height: root.plate.height,
                radius: root.plate.width / 2, id: "plate" }]
            const body = card.bodyRect
            if (card.progress > 0 && body.width > 1) {
                const joinOrigin = IrisStyle.cardJoins
                const joinRise = joinOrigin ? IrisStyle.ramp(card.progress, 0.08, 0.3) : 0
                out.push({ x: body.x, y: body.y, width: body.width, height: body.height, radius: body.radius,
                    paints: true, fuse: Math.round(IrisStyle.fuseDeep * joinRise), id: "card",
                    joins: joinRise > 0 ? "plate" : "" })
            }
            return out
        }
    }

    Repeater {
        model: root.mode === "card" ? 2 : 0
        MaterialSymbol {
            required property int index
            x: root.plate.x + root.plateGap + (root.pieceSize - width) / 2
            y: root.plate.y + root.plateGap + index * (root.pieceSize + root.plateGap) + (root.pieceSize - height) / 2
            text: index === 0 ? "partly_cloudy_day" : "volume_up"
            iconSize: Math.round(16 * root.d)
            color: index === 1 && root.open ? IrisStyle.accent : IrisStyle.textSecondary
        }
    }

    IrisMorphSurface {
        id: card
        visible: root.mode === "card"
        motionSurface: "cards"
        open: root.open && root.mode === "card"
        origin: root.piece
        color: IrisStyle.bodySurface
        radius: IrisStyle.surfaceRadius("cards", IrisStyle.radiusSheet)
        width: root.cardWidth
        height: root.cardHeight
        x: root.plate.x - width - root.cardAir
        y: {
            const cy = root.piece.y + root.pieceSize / 2
            const straight = root.pieceSize / 2 + radius
            const wanted = Math.max(root.pad / 2, Math.min(root.height - height - root.pad / 2, cy - height / 2))
            return Math.max(cy + straight - height, Math.min(cy - straight, wanted))
        }

        Column {
            anchors.fill: parent
            anchors.margins: Math.round(14 * root.d)
            spacing: Math.round(9 * root.d)
            Row {
                spacing: Math.round(8 * root.d)
                MaterialSymbol { text: "volume_up"; iconSize: Math.round(16 * root.d); color: IrisStyle.accent }
                Rectangle { width: Math.round(70 * root.d); height: Math.round(8 * root.d); radius: height / 2; color: IrisStyle.fill; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle { width: parent.width; height: Math.round(22 * root.d); radius: height / 2; color: IrisStyle.fill
                Rectangle { width: parent.width * 0.62; height: parent.height; radius: height / 2; color: IrisStyle.fillStrong }
            }
            Rectangle { width: parent.width * 0.8; height: Math.round(7 * root.d); radius: height / 2; color: IrisStyle.fillQuiet }
            Rectangle { width: parent.width * 0.55; height: Math.round(7 * root.d); radius: height / 2; color: IrisStyle.fillQuiet }
        }
    }

    Item {
        visible: root.mode === "island"
        x: root.island.x
        y: root.island.y
        width: root.island.width
        height: root.island.height
        IrisText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: (root.atBottom ? 1 : -1) * (parent.height - root.restH) / 2
            opacity: 1 - IrisStyle.ramp(root.p, 0, IrisStyle.contentFall)
            text: "22:43"
            font.family: IrisStyle.fontNumbers
            font.weight: IrisStyle.weight(Font.Bold)
            font.pixelSize: Math.round(13 * root.d)
        }
        Column {
            x: Math.round(14 * root.d)
            y: root.atBottom ? Math.round(14 * root.d) : parent.height - Math.round(14 * root.d) - root.openH + 2 * Math.round(14 * root.d)
            width: parent.width - 2 * Math.round(14 * root.d)
            spacing: Math.round(9 * root.d)
            opacity: IrisStyle.contentAt(root.p)
            IrisText { text: "22:43"; font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.Bold); font.pixelSize: Math.round(26 * root.d) }
            Rectangle { width: parent.width * 0.7; height: Math.round(7 * root.d); radius: height / 2; color: IrisStyle.fill }
            Rectangle { width: parent.width * 0.5; height: Math.round(7 * root.d); radius: height / 2; color: IrisStyle.fillQuiet }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(8 * root.d)
        spacing: Math.round(6 * root.d)
        IrisIconButton {
            materialIcon: root.playing ? "pause" : "play_arrow"
            onClicked: root.playing = !root.playing
            Accessible.name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
        }
        IrisIconButton {
            materialIcon: root.open ? "close_fullscreen" : "open_in_full"
            onClicked: { root.playing = false; root.open = !root.open }
            Accessible.name: Translation.tr("Open or close")
        }
    }
}
