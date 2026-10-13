import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's activity plate on the lock: what is running, its figure set large with its name over it.
// Its mark sits on a die of its subject's lacquer (a recording the accent, being live; a timer time's), and a
// count with an end runs along the foot as a run in the same lacquer, the part gone laid from the left.
Item {
    id: root
    property var host
    readonly property real s: root.host?.textScale ?? 1
    function t(px: real): int { return Math.round(px * root.s) }
    readonly property bool live: root.host?.live ?? false
    readonly property real progress: root.host?.progress ?? -1
    readonly property bool paused: root.host?.glyph === "pause"
    readonly property int pad: Airisu.u(4)
    readonly property int foot: root.progress >= 0 ? Airisu.u(3) : 0
    readonly property color pigment: root.live ? Airisu.sealOnMedia : Airisu.vivid(Airisu.pigment("time"))
    readonly property color lacquer: root.paused ? IrisStyle.mediaScrim : root.pigment
    implicitHeight: root.pad + Math.max(mark.height, words.implicitHeight) + root.foot + root.pad

    Item {
        id: mark
        x: root.pad
        y: root.pad + Math.round((Math.max(mark.height, words.implicitHeight) - mark.height) / 2)
        width: Airisu.u(9)
        height: width
        ALacquer {
            anchors.fill: parent
            cut: Airisu.cutFor(height)
            lacquer: root.lacquer
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.live ? "fiber_manual_record" : root.host?.glyph ?? ""
            fill: 1
            iconSize: Airisu.u(root.live ? 4 : 5)
            color: root.paused ? IrisStyle.onMedia : IrisStyle.onTintFor(Airisu.solid(root.lacquer))
        }
    }
    Column {
        id: words
        x: mark.x + mark.width + Airisu.u(3)
        y: root.pad
        width: parent.width - x - root.pad
        spacing: 0
        AText {
            width: parent.width
            voice: "ruby"
            size: root.t(IrisStyle.typeMeta)
            color: IrisStyle.onMediaSecondary
            text: root.host?.label ?? ""
        }
        AText {
            width: parent.width
            voice: "figure"
            size: root.t(IrisStyle.typeDisplay)
            color: root.paused ? IrisStyle.onMediaSecondary : IrisStyle.onMedia
            text: root.host?.figure ?? ""
        }
    }

    ARun {
        visible: root.progress >= 0
        x: root.pad
        width: parent.width - 2 * root.pad
        height: Airisu.u(1.5)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        slot: IrisStyle.mediaScrim
        pigment: root.paused ? IrisStyle.onMediaSecondary : root.pigment
        value: Math.max(0, Math.min(1, root.progress))
    }
}
