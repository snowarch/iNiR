import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.components
import "../components"

// AIRISU's notice mark, for a notification that brings no icon of its own (the shell's, a battery, an unknown sender):
// a die of lacquer in the notice's pigment with its sign cut out of it: the shell's own in its accent with the insignia,
// a battery and a message in theirs, a critical one in the caution's. The engine decides what the sign is.
Item {
    id: root
    property Item host
    readonly property bool critical: root.host?.critical ?? false
    readonly property bool insignia: (root.host?.fromShell ?? false) && !root.critical
    readonly property var semantic: root.host?.semantic ?? ({ glyph: "notifications", battery: -1 })
    readonly property bool battery: root.semantic.battery >= 0 && !root.insignia
    // A critical one is set into the caution's lacquer as a deeper coat, so on a critical banner it is an inlay and not a
    // second plate of the same colour.
    readonly property color face: root.critical ? Airisu.coat(Airisu.pigment("caution"))
        : root.insignia ? Airisu.lacquerOf(Airisu.seal)
        : Airisu.lacquerOf(Airisu.pigment(root.battery ? "energy" : "message"))
    readonly property color ink: Airisu.inkOn(root.face)

    ALacquer {
        anchors.fill: parent
        cut: Airisu.cutFor(root.height)
        lacquer: root.face
        moving: false
    }
    IrisMark {
        visible: root.insignia
        anchors.centerIn: parent
        implicitSize: Math.round(root.width * 0.62)
        color: Airisu.seal
    }
    IrisBatteryMark {
        visible: root.battery
        anchors.centerIn: parent
        markHeight: Math.round(root.width * 0.3)
        level: root.semantic.battery
        tint: root.ink
        frame: root.ink
    }
    MaterialSymbol {
        visible: !root.insignia && !root.battery
        anchors.centerIn: parent
        text: root.critical ? "priority_high" : root.semantic.glyph
        fill: 1
        iconSize: Math.round(root.width * 0.5)
        color: root.ink
    }
}
