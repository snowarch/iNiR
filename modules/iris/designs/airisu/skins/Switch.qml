import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's switch (SYSTEM.md §6): a slide switch cut square. A ruled slot holds a lever half its length; off, the lever
// rests at the start in the second ink on a slot of one step of ink (a bare slot with a pale lever read as a switch that
// cannot be taken); on, the slot is the seal (what is live) and the lever stands at the
// far end in the seal's ink, so on and off read at a glance with no word. The lever stops in its place (a detent), it
// does not spring. The pointer inks the rule, a press runs the lever a hair out of register, keyboard focus flags the
// corner, and a switch that cannot be taken is ruled dashed. On a chosen row's plate it is printed in that plate's inks.
// The host keeps the toggle, the keys and the name.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: root.host?.pressed ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property bool keyed: root.host?.keyed ?? false
    readonly property bool reversed: root.host?.reversed ?? false
    readonly property int inset: Math.max(2, Math.round(3 * Airisu.d))
    readonly property int run: root.pressed && root.available ? Airisu.hair : 0
    readonly property color slot: !root.on ? (root.available ? Airisu.cell : "transparent")
        : !root.available ? Airisu.cell : root.reversed ? IrisStyle.selectionLabel : Airisu.seal
    readonly property color rule: root.on && root.available ? root.slot
        : !root.available ? Airisu.inkThird : root.hovered || root.keyed ? Airisu.ink : Airisu.inkSecond
    readonly property color lever: !root.available ? Airisu.inkThird
        : root.reversed ? (root.on ? IrisStyle.selectionFill : IrisStyle.selectionDetail)
        : root.on ? Airisu.inkOnSeal : root.hovered ? Airisu.ink : Airisu.inkSecond

    Rectangle {
        anchors.fill: parent
        color: root.slot
    }
    ADie {
        anchors.fill: parent
        stroke: root.rule
        strokeWidth: Airisu.hair
        dashed: !root.available
    }
    Rectangle {
        width: Math.round(root.width / 2) - root.inset
        height: root.height - 2 * root.inset
        x: (root.on ? root.width - root.inset - width : root.inset) + root.run
        y: root.inset + root.run
        Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        color: root.lever
    }
    AKey {
        anchors.fill: parent
        lacquer: "transparent"
        available: false
        keyed: root.keyed
    }
}
