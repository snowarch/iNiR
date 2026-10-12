import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.components
import "../components"

// AIRISU's notice mark, for a notification that brings no icon of its own (the shell's, a battery, an unknown sender):
// a square printed with the notice's sign, like the pictogram plate on a station board, the sign in the ink. A critical
// one is the caution plate. It stands on the stock, so it reads when it sits on a picture's corner. The colour of the
// notice's line is the banner's band, never the mark's: one mark per fact. The engine decides what the sign is.
Item {
    id: root
    property Item host
    readonly property bool critical: root.host?.critical ?? false
    readonly property bool insignia: (root.host?.fromShell ?? false) && !root.critical
    readonly property var semantic: root.host?.semantic ?? ({ glyph: "notifications", battery: -1 })
    readonly property bool battery: root.semantic.battery >= 0 && !root.insignia
    readonly property color ink: root.critical ? Airisu.inkOnCaution : Airisu.ink

    ADie {
        anchors.fill: parent
        kind: "rect"
        fill: root.critical ? Airisu.caution : Airisu.ground
        stroke: root.critical ? "transparent" : Airisu.ink
        strokeWidth: root.critical ? 0 : Airisu.hair
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
