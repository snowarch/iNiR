pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's visualizer: a mixing desk's spectrum meter. Columns of lit segments in ink rise with each band, the top fifth
// of every column is the seal's zone, printed as its under plate and lit in shu when a band reaches it (loud is what is
// live); what plays is a ruby in the data face's capitals over it. Still, the columns rest on their first segment. The
// engine's widget keeps the audio.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var points: Array.from(root.widget?.printPoints ?? [])
    readonly property bool live: root.widget?.printLive ?? false
    readonly property int columns: root.small ? 10 : 20
    readonly property var player: MprisController.activePlayer

    // A band's level, the points folded into as many columns as are printed.
    function level(i: int): real {
        if (!root.live || root.points.length === 0) return 0
        const per = root.points.length / root.columns
        let peak = 0
        for (let k = Math.floor(i * per); k < Math.floor((i + 1) * per); ++k) peak = Math.max(peak, Number(root.points[k] ?? 0))
        return Math.max(0, Math.min(1, peak))
    }

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "music"
    }
    AText {
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        voice: "mono"
        size: IrisStyle.typeCaption
        color: stock.inkSecond
        text: root.player ? [String(root.player.trackArtist ?? ""), String(root.player.trackTitle ?? "")].filter(t => t.length > 0).join(" · ")
            : Translation.tr("Nothing playing")
    }
    Item {
        id: desk
        x: root.pad
        y: root.pad + root.dp(20)
        width: root.width - 2 * root.pad
        height: root.height - y - root.pad
        readonly property real seg: Math.max(4, root.dp(8))
        readonly property real gap: Math.max(1, root.dp(2))
        readonly property int segments: Math.max(4, Math.floor((desk.height + desk.gap) / (desk.seg + desk.gap)))
        readonly property int zone: Math.max(1, Math.round(desk.segments * 0.2))
        readonly property real pitch: (desk.width + desk.gap) / root.columns
        Repeater {
            model: root.columns
            Item {
                id: column
                required property int index
                readonly property int lit: Math.max(1, Math.round(root.level(column.index) * desk.segments))
                x: Math.round(column.index * desk.pitch)
                width: Math.max(2, Math.round(desk.pitch - desk.gap))
                height: desk.height
                Repeater {
                    model: desk.segments
                    Rectangle {
                        required property int index
                        readonly property bool loud: index >= desk.segments - desk.zone
                        readonly property bool on: index < column.lit
                        width: column.width
                        height: desk.seg
                        y: desk.height - (index + 1) * (desk.seg + desk.gap) + desk.gap
                        color: loud ? (on ? Airisu.seal : Airisu.underPlate(Airisu.seal)) : on ? stock.ink : Airisu.slot
                        antialiasing: false
                    }
                }
            }
        }
    }
}
