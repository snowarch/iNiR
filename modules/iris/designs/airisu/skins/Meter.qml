import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's level slider (board Components › MEDIDOR): never a capsule. The glyph and the figure in the wide face over
// twenty segments, the last 15 % the red line. It is a gauge: dark until it is touched, it lights segment by segment.
// The host (IrisCapsuleSlider) keeps the drag, the wheel and the pocket; this only draws.
Item {
    id: root
    property Item host
    readonly property real value: root.host?.shownValue ?? 0
    readonly property bool vertical: root.host?.vertical ?? false
    readonly property bool muted: root.host?.muted ?? false

    Rectangle { anchors.fill: parent; color: Airisu.sumi }
    MaterialSymbol {
        id: glyph
        x: root.vertical ? (root.width - width) / 2 : Math.round(12 * Airisu.d)
        y: root.vertical ? root.height - height - Math.round(10 * Airisu.d) : (root.height - height) / 2
        text: root.host?.icon ?? ""
        fill: 1
        iconSize: Math.round(18 * Airisu.d)
        color: root.muted ? Airisu.quiet : Airisu.gofun
    }
    AText {
        id: figure
        visible: !root.vertical
        anchors.right: parent.right
        anchors.rightMargin: Math.round(12 * Airisu.d)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(34 * Airisu.d)
        horizontalAlignment: Text.AlignRight
        voice: "wide"
        size: IrisStyle.typeHeadline
        text: Math.round(root.value * 100)
        color: root.muted ? Airisu.quiet : Airisu.gofun
    }
    AMeter {
        visible: !root.vertical
        interactive: false
        anchors.left: glyph.right
        anchors.leftMargin: Math.round(12 * Airisu.d)
        anchors.right: figure.left
        anchors.rightMargin: Math.round(12 * Airisu.d)
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(Math.min(14, root.height * 0.32) * Airisu.d)
        value: root.muted ? 0 : root.value
    }
    // Upright: the segments stack from the glyph up, the red line at the top.
    Column {
        visible: root.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(10 * Airisu.d)
        anchors.bottom: glyph.top
        anchors.bottomMargin: Math.round(8 * Airisu.d)
        width: Math.round(root.width * 0.46)
        spacing: Math.max(2, Math.round(3 * Airisu.d))
        readonly property int lit: Math.round(root.value * 20)
        Repeater {
            model: 20
            Rectangle {
                required property int index
                readonly property int step: 19 - index
                readonly property bool on: !root.muted && step < parent.lit
                width: parent.width
                height: (parent.height - parent.spacing * 19) / 20
                color: step >= 17 ? (on ? Airisu.seal : Airisu.sealDim) : on ? Airisu.gofun : Airisu.socket
            }
        }
    }
}
