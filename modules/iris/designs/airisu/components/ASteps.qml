import QtQuick

// A ladder of steps (段): how AIRISU shows a level. A row of blocks on the module, each lit in ink as the level passes
// it, the way a mixing desk's meter lights: a change lands step by step, never as a slide. `rising` makes each step a
// little taller than the last (a third of the lane at the start, all of it at the end); flat, they are all one height.
// The last fifth is the seal's zone, printed as its under plate until the level reaches it and in shu once it does
// (loud is what is live). Muted, the steps keep the level in the third ink; one that cannot be taken sinks them all.
Item {
    id: root
    property real value: 0
    property bool muted: false
    property bool available: true
    property bool rising: true
    property bool zoned: true
    property color ink: Airisu.ink
    property color quiet: Airisu.inkThird
    property color slot: Airisu.slot
    property real gap: Math.max(1, Math.round(2 * Airisu.d))
    property int count: Math.max(6, Math.min(24, Math.round(root.width / Math.max(5, 7 * Airisu.d))))
    readonly property real pitch: (root.width + root.gap) / root.count
    readonly property int lit: Math.round(Math.max(0, Math.min(1, root.value)) * root.count)
    readonly property int zone: root.zoned ? Math.round(root.count * 0.8) : root.count

    Repeater {
        model: root.count
        Rectangle {
            id: block
            required property int index
            readonly property bool on: block.index < root.lit
            readonly property bool loud: block.index >= root.zone
            x: Math.round(block.index * root.pitch)
            width: Math.max(1, Math.round((block.index + 1) * root.pitch - root.gap) - x)
            height: Math.round(root.rising ? root.height * (0.34 + 0.66 * block.index / Math.max(1, root.count - 1)) : root.height)
            y: root.height - height
            antialiasing: false
            color: !root.available ? Airisu.dim
                : root.muted ? (block.on ? root.quiet : root.slot)
                : block.loud ? (block.on ? Airisu.seal : Airisu.underPlate(Airisu.seal))
                : block.on ? root.ink : root.slot
        }
    }
}
