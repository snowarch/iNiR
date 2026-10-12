import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's timer key (the Island's tools): a box of a printed form with the minutes set large in it, the share of the
// hour it takes run as a graduated rule along its foot, like the dial of a darkroom timer read flat. The one that runs
// is the seal; one that cannot be taken while a countdown runs is printed as a screen, never faded. The pointer brings
// the crop marks and a press runs the box out of register; dragging and the wheel still set the minutes (the engine).
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
    readonly property int shift: root.pressed && root.available ? Airisu.registration : 0
    readonly property color ink: root.running ? Airisu.inkOnSeal : root.available ? Airisu.ink : Airisu.inkThird

    APrint {
        id: box
        anchors.fill: parent
        die: "rect"
        pressed: root.pressed && root.available
        fill: root.running ? Airisu.seal : "transparent"
        under: root.running ? Airisu.sealUnder : Airisu.inkUnder
        stroke: root.running ? "transparent" : root.available ? Airisu.ink : Airisu.inkThird
        strokeWidth: root.running ? 0 : Airisu.hair
        dashed: !root.available

        AScreen {
            anchors.fill: parent
            anchors.margins: Airisu.hair
            visible: !root.available
            pigment: Airisu.inkThird
            density: 10
        }
        AText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Airisu.m
            visible: root.figure.length > 0
            voice: "figure"
            size: IrisStyle.typeTitleLarge
            text: root.figure
            color: root.ink
        }
        MaterialSymbol {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Airisu.m
            visible: root.glyph.length > 0
            text: root.glyph
            fill: root.running ? 1 : 0
            iconSize: Math.round(22 * Airisu.d)
            color: root.ink
        }
        // The share of the hour: a rule of ticks every five minutes, the travelled part in solid ink.
        Item {
            visible: root.figure.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Airisu.m
            height: Airisu.u(1.5)
            Repeater {
                model: 13
                Rectangle {
                    required property int index
                    x: Math.round(index * (parent.width - width) / 12)
                    anchors.bottom: parent.bottom
                    width: Airisu.hair
                    height: index % 3 === 0 ? parent.height : Math.round(parent.height / 2)
                    color: root.available ? Airisu.inkSecond : Airisu.inkThird
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: Math.round(parent.width * Math.max(0, Math.min(1, root.share)))
                height: Airisu.strong
                color: root.ink
            }
        }
    }
    ATombo {
        anchors.fill: parent
        shown: root.hovered && root.available && !root.pressed
        focusMarks: root.host?.visualFocus ?? false
        air: Airisu.hair
        length: Airisu.m
    }
}
