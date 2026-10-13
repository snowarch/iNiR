import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's timer key (the Island's tools): a key (AKey) of time's lacquer with its minutes set large and leaning,
// and the share of the hour they take laid along its foot as a run. The one that runs is the pigment at full strength;
// one that cannot be taken while a countdown runs sits half into the stock. Dragging and the wheel still set the minutes
// (the engine); the pointer lays the key's coat and a press carries its figure a hair.
Item {
    id: root
    property Item host
    readonly property var slot: root.host?.skinData ?? ({})
    readonly property string figure: String(root.slot.figure ?? "")
    readonly property string glyph: String(root.slot.glyph ?? "")
    readonly property bool running: root.slot.running ?? false
    readonly property real share: Number(root.slot.share ?? 0)
    readonly property bool available: root.slot.available ?? true
    readonly property bool hovered: root.slot.hovered ?? false
    readonly property bool pressed: root.slot.pressed ?? false
    readonly property color pigment: Airisu.pigment("time")
    readonly property color face: !root.available ? Airisu.dim : root.running ? Airisu.vivid(root.pigment) : Airisu.lacquerOf(root.pigment)
    readonly property color ink: root.available ? Airisu.inkOn(root.face) : Airisu.inkThird
    readonly property int shift: key.shift

    AKey {
        id: key
        anchors.fill: parent
        lacquer: root.face
        hovered: root.hovered
        pressed: root.pressed
        keyed: root.host?.visualFocus ?? false
        available: root.available
    }
    AText {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.shift
        anchors.verticalCenterOffset: -Airisu.m + root.shift
        visible: root.figure.length > 0
        voice: "figure"
        size: IrisStyle.typeTitleLarge
        text: root.figure
        color: root.ink
    }
    MaterialSymbol {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.shift
        anchors.verticalCenterOffset: (root.figure.length > 0 ? -Airisu.m : 0) + root.shift
        visible: root.glyph.length > 0
        text: root.glyph
        fill: root.running ? 1 : 0
        iconSize: Math.round(22 * Airisu.d)
        color: root.ink
    }
    // The share of the hour, laid along the foot.
    ARun {
        visible: root.figure.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Airisu.u(2)
        height: Math.max(3, Math.round(4 * Airisu.d))
        value: Math.max(0, Math.min(1, root.share))
        available: root.available
        pigment: root.running ? root.ink : Airisu.vivid(root.pigment)
        moving: false
    }
}
