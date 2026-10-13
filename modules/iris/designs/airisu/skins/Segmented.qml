pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's segmented (SYSTEM.md §6): the boxes of a printed form, ruled in the third ink, one per choice. The chosen box
// is the chosen plate (gofun at night, sumi by day) with its words reversed out; it stops in the next box (one detent)
// instead of sliding. The pointer lays its coat on one box, a press carries that box's words a hair, the keyboard flags
// the box it is on, and boxes that cannot be taken are ruled dashed. The host keeps the picking.
Item {
    id: root
    property Item host
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    readonly property int hoveredIndex: root.host?.hoveredIndex ?? -1
    readonly property int pressedIndex: root.host?.pressedIndex ?? -1
    readonly property int focusedIndex: root.host?.focusedIndex ?? -1
    readonly property bool available: root.host?.enabled ?? true
    readonly property bool glyphOnly: root.host?.glyphOnly ?? false
    readonly property bool pictured: root.host?.pictured ?? false
    readonly property color rule: Airisu.inkThird
    // The boxes run edge to edge: the host's inset is for its own thumb.
    function edge(i: int): real {
        if (!root.host) return 0
        return i <= 0 ? 0 : i >= root.options.length ? root.width : root.host.slotX(i)
    }

    Rectangle {
        visible: root.chosen >= 0
        x: root.edge(Math.max(0, root.chosen))
        width: root.edge(Math.max(0, root.chosen) + 1) - x
        height: root.height
        Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        Behavior on width { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        color: root.available ? Airisu.chosen : Airisu.cell
    }
    ADie {
        anchors.fill: parent
        stroke: root.rule
        strokeWidth: Airisu.hair
        dashed: !root.available
    }
    Repeater {
        model: Math.max(0, root.options.length - 1)
        Rectangle {
            required property int index
            x: Math.round(root.edge(index + 1))
            width: Airisu.hair
            height: root.height
            color: root.rule
        }
    }
    Repeater {
        model: root.options
        Item {
            id: box
            required property var modelData
            required property int index
            readonly property bool chosen: root.chosen === box.index
            readonly property string label: Translation.tr(String(box.modelData.label ?? ""))
            readonly property string glyph: String(box.modelData.glyph ?? "")
            readonly property string swatch: String(box.modelData.swatch ?? "")
            readonly property color ink: box.chosen ? (root.available ? Airisu.inkOnChosen : Airisu.ink)
                : root.available ? Airisu.inkSecond : Airisu.inkThird
            readonly property int run: root.pressedIndex === box.index && root.available ? Airisu.hair : 0
            x: root.edge(box.index)
            width: root.edge(box.index + 1) - x
            height: root.height

            AKey {
                anchors.fill: parent
                cut: 0
                lacquer: "transparent"
                coat: root.pressedIndex === box.index ? Airisu.slotPress : Airisu.slotCoat
                hovered: root.hoveredIndex === box.index && !box.chosen
                pressed: root.pressedIndex === box.index && !box.chosen
                keyed: root.focusedIndex === box.index
                available: root.available
                flag: box.chosen ? Airisu.inkOnChosen : Airisu.seal
            }
            MaterialSymbol {
                visible: root.glyphOnly
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: box.run
                anchors.verticalCenterOffset: box.run
                text: box.glyph
                fill: box.chosen ? 1 : 0
                iconSize: Math.round(16 * Airisu.d)
                color: box.ink
            }
            Column {
                visible: !root.glyphOnly
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: box.run
                anchors.verticalCenterOffset: box.run
                width: parent.width - 2 * Airisu.m
                spacing: Airisu.u(0.5)
                MaterialSymbol {
                    visible: root.pictured && box.glyph.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: box.glyph
                    fill: box.chosen ? 1 : 0
                    iconSize: Math.round(20 * Airisu.d)
                    color: box.ink
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Airisu.u(1.5)
                    Rectangle {
                        visible: box.swatch.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: Airisu.u(2.5)
                        height: width
                        color: box.swatch.length > 0 ? box.swatch : "transparent"
                        border.width: box.chosen ? Airisu.hair : 0
                        border.color: box.ink
                    }
                    AText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, box.width - 3 * Airisu.m - (box.swatch.length > 0 ? 4 * Airisu.m : 0))
                        horizontalAlignment: Text.AlignHCenter
                        size: root.pictured ? IrisStyle.typeFootnote : IrisStyle.typeMeta
                        font.family: root.host?.fontFor ? root.host.fontFor(box.modelData) : Airisu.textFace
                        font.weight: box.chosen ? Font.Bold : Font.Medium
                        text: box.label
                        color: box.ink
                    }
                }
            }
        }
    }
}
