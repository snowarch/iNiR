pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: bubRoot
    readonly property real naturalWidth: Math.round(760 * bubRoot.d)
    readonly property real naturalHeight: Math.round(300 * bubRoot.d)
    readonly property bool snap: bubRoot.opt("iris.bubbles.snap", true)
    readonly property bool attach: bubRoot.opt("iris.bubbles.attach", true)
    readonly property bool cluster: bubRoot.opt("iris.bubbles.cluster", true)
    readonly property bool opensIsland: String(bubRoot.opt("iris.bubbles.opens", "card")) === "island"
    readonly property bool joined: bubRoot.opt("iris.appearance.surfaces.cards.joinOrigin", false)
    readonly property real size: IrisFrame.pieceBand
    readonly property real gap: bubRoot.attach ? 0 : Math.round(Math.max(0, Math.min(64, Number(bubRoot.opt("iris.bubbles.edgeGap", 20)))) * bubRoot.d)
    readonly property real split: bubRoot.cluster ? 0 : Math.round(6 * bubRoot.d)
    readonly property real pad: bubRoot.cluster ? Math.round(4 * bubRoot.d) : 0
    readonly property point home: Qt.point(width - IrisFrame.band - bubRoot.gap - bubRoot.pad - bubRoot.size, IrisFrame.band + bubRoot.gap + bubRoot.pad)
    readonly property point slot: Qt.point(bubRoot.home.x - bubRoot.size - bubRoot.split, bubRoot.home.y)
    readonly property point start: Qt.point(Math.round(width * 0.3), Math.round(height * 0.5))
    readonly property point drop: Qt.point(bubRoot.slot.x - Math.round(34 * bubRoot.d), bubRoot.slot.y + Math.round(46 * bubRoot.d))
    property int step: 0
    readonly property bool grabbed: bubRoot.step === 1
    readonly property bool settled: bubRoot.step >= 2 && bubRoot.step <= 5
    readonly property bool open: bubRoot.step === 4 || bubRoot.step === 5
    readonly property point rest: bubRoot.settled ? (bubRoot.snap ? bubRoot.slot : bubRoot.drop) : bubRoot.start
    property real bx: bubRoot.rest.x
    property real by: bubRoot.rest.y
    Behavior on bx { enabled: !bubRoot.grabbed; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
    Behavior on by { enabled: !bubRoot.grabbed; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
    Binding { when: bubRoot.grabbed; bubRoot.bx: bubPointer.x - bubRoot.size / 2 + bubPointer.width / 2 }
    Binding { when: bubRoot.grabbed; bubRoot.by: bubPointer.y - bubRoot.size / 2 + bubPointer.height / 2 }
    readonly property bool together: bubRoot.cluster && bubRoot.settled && bubRoot.snap
    readonly property bool framed: bubRoot.attach && bubRoot.settled && bubRoot.snap
    property real openness: bubRoot.open ? 1 : 0
    Behavior on openness { NumberAnimation { duration: bubRoot.open ? IrisStyle.emergeDuration : IrisStyle.recedeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: bubRoot.open ? IrisStyle.emergeCurve : IrisStyle.recedeCurve } }
    readonly property real islandW: Math.round(150 * bubRoot.d + (340 - 150) * bubRoot.d * (bubRoot.opensIsland ? bubRoot.openness : 0))
    readonly property real islandH: Math.round(IrisFrame.islandBand + (130 * bubRoot.d - IrisFrame.islandBand) * (bubRoot.opensIsland ? bubRoot.openness : 0))
    readonly property var card: ({
        x: Math.round(Math.max(IrisFrame.band + 8 * bubRoot.d, Math.min(bubRoot.width - IrisFrame.band - 230 * bubRoot.d, bubRoot.bx + bubRoot.size / 2 - 115 * bubRoot.d))),
        y: Math.round(bubRoot.by + bubRoot.size + (bubRoot.joined ? IrisStyle.weld : IrisFrame.bodyAir)),
        width: Math.round(230 * bubRoot.d),
        height: Math.max(1, Math.round(120 * bubRoot.d * bubRoot.openness))
    })

    Timer {
        running: bubRoot.playing
        interval: 900
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            bubRoot.step = (bubRoot.step + 1) % 7
            if (bubRoot.step === 1 || bubRoot.step === 3) bubPointer.click()
        }
        onRunningChanged: if (!running) bubRoot.step = 2
    }

    Field.IrisField {
        anchors.fill: parent
        shapes: {
            const out = []
            const s = bubRoot.size
            out.push({ x: (bubRoot.width - bubRoot.islandW) / 2, y: IrisFrame.band, width: bubRoot.islandW, height: bubRoot.islandH,
                radius: Math.min(bubRoot.islandH / 2, IrisStyle.radius), fuse: IrisStyle.fuseEdge, id: "island", joins: "frame", paints: true })
            if (bubRoot.together) {
                const w = bubRoot.home.x + s - bubRoot.bx + 2 * bubRoot.pad
                out.push({ x: bubRoot.bx - bubRoot.pad, y: bubRoot.home.y - bubRoot.pad, width: w, height: s + 2 * bubRoot.pad,
                    radius: IrisStyle.pieceRadius(s + 2 * bubRoot.pad), fuse: bubRoot.framed ? IrisStyle.fuseEdge : IrisStyle.fuse,
                    id: "plate", joins: bubRoot.framed ? "frame" : "", paints: true })
            } else {
                out.push({ x: bubRoot.home.x, y: bubRoot.home.y, width: s, height: s, radius: IrisStyle.pieceRadius(s),
                    fuse: bubRoot.attach ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "resident", joins: bubRoot.attach ? "frame" : "", paints: true })
                out.push({ x: bubRoot.bx, y: bubRoot.by, width: s, height: s, radius: IrisStyle.pieceRadius(s),
                    fuse: bubRoot.framed ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "carried", joins: bubRoot.framed ? "frame" : "", paints: true })
            }
            if (!bubRoot.opensIsland && bubRoot.openness > 0.01)
                out.push(Object.assign({ radius: Math.min(IrisStyle.radiusSheet, bubRoot.card.height / 2), fuse: IrisStyle.fuseDeep,
                    id: "card", joins: bubRoot.joined ? (bubRoot.together ? "plate" : "carried") : "", paints: true }, bubRoot.card))
            return out
        }
    }

    IrisClock {
        x: (bubRoot.width - width) / 2
        y: IrisFrame.band + (IrisFrame.islandBand - height) / 2
        opacity: 1 - (bubRoot.opensIsland ? bubRoot.openness : 0)
        pixelSize: IrisStyle.typeHeadline
        separatorColor: IrisStyle.secondaryAccent
    }
    MaterialSymbol {
        x: bubRoot.home.x + (bubRoot.size - width) / 2
        y: bubRoot.home.y + (bubRoot.size - height) / 2
        text: "partly_cloudy_day"; fill: 1
        iconSize: Math.round(bubRoot.size * 0.46)
        color: IrisStyle.identity.sky
    }
    MaterialSymbol {
        x: bubRoot.bx + (bubRoot.size - width) / 2
        y: bubRoot.by + (bubRoot.size - height) / 2
        scale: bubRoot.grabbed ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        text: "volume_up"; fill: 1
        iconSize: Math.round(bubRoot.size * 0.46)
        color: IrisStyle.identity.indigo
    }

    ColumnLayout {
        visible: bubRoot.openness > 0.02
        opacity: IrisStyle.ramp(bubRoot.openness, IrisStyle.dropRise, IrisStyle.dropSpan)
        x: bubRoot.opensIsland ? (bubRoot.width - bubRoot.islandW) / 2 + Math.round(18 * bubRoot.d) : bubRoot.card.x + Math.round(16 * bubRoot.d)
        y: bubRoot.opensIsland ? IrisFrame.band + Math.round(16 * bubRoot.d) : bubRoot.card.y + Math.round(14 * bubRoot.d)
        width: (bubRoot.opensIsland ? bubRoot.islandW : bubRoot.card.width) - Math.round(32 * bubRoot.d)
        spacing: Math.round(10 * bubRoot.d)
        RowLayout {
            spacing: Math.round(8 * bubRoot.d)
            MaterialSymbol { text: "volume_up"; fill: 1; iconSize: Math.round(18 * bubRoot.d); color: IrisStyle.identity.indigo }
            IrisText { text: Translation.tr("Sound"); font.weight: IrisStyle.weight(Font.DemiBold) }
        }
        Level { value: 0.62; tint: IrisStyle.identity.indigo }
        IrisText { text: Translation.tr("Speakers"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
    }

    Pointer {
        id: bubPointer
        grabbing: bubRoot.grabbed
        travel: bubRoot.step === 1 ? 820 : 560
        x: bubRoot.step === 0 ? bubRoot.start.x + bubRoot.size * 0.55
            : bubRoot.step === 1 ? bubRoot.drop.x + bubRoot.size / 2 - width / 2
            : bubRoot.step === 2 ? bubRoot.drop.x + bubRoot.size * 0.9
            : bubRoot.step === 6 ? bubRoot.width * 0.45
            : bubRoot.rest.x + bubRoot.size * 0.55
        y: bubRoot.step === 0 ? bubRoot.start.y + bubRoot.size * 0.55
            : bubRoot.step === 1 ? bubRoot.drop.y + bubRoot.size / 2 - height / 2
            : bubRoot.step === 2 ? bubRoot.drop.y + bubRoot.size * 1.4
            : bubRoot.step === 6 ? bubRoot.height * 0.72
            : bubRoot.rest.y + bubRoot.size * 0.55
    }

    Caption {
        glyph: ["near_me", "back_hand", bubRoot.snap ? "select" : "pan_tool", "touch_app", bubRoot.opensIsland ? "pill" : "web_asset", bubRoot.opensIsland ? "pill" : "web_asset", "undo"][bubRoot.step]
        text: [Translation.tr("A bubble floats over the desktop"),
            Translation.tr("Drag it towards a corner"),
            !bubRoot.snap ? Translation.tr("Snap off: it stays where you let go")
                : (bubRoot.attach ? Translation.tr("Snaps onto the frame") : Translation.tr("Snaps %1 px from the edges").arg(Math.round(bubRoot.gap / bubRoot.d)))
                    + (bubRoot.cluster ? " · " + Translation.tr("grouped into a bar") : ""),
            Translation.tr("Tap it"),
            bubRoot.opensIsland ? Translation.tr("Opens the Island") : bubRoot.joined ? Translation.tr("Grows its card, joined to it") : Translation.tr("Grows its card"),
            bubRoot.opensIsland ? Translation.tr("Opens the Island") : bubRoot.joined ? Translation.tr("Grows its card, joined to it") : Translation.tr("Grows its card"),
            Translation.tr("And back")][bubRoot.step]
    }
}
