pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's segmented (SYSTEM.md §6): the boxes of a printed form. A rule round them and between them; the chosen box is
// a solid ink plate with its words reversed out. The plate does not slide: it stops in the next box (a 90 ms detent).
// The pointer brings the crop marks round one box, the keyboard the seal's. The host keeps the picking and the keys.
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
    // The boxes run edge to edge: the host's inset is for its own thumb.
    function edge(i: int): real {
        if (!root.host) return 0
        return i <= 0 ? 0 : i >= root.options.length ? root.width : root.host.slotX(i)
    }

    ADie {
        anchors.fill: parent
        stroke: root.available ? Airisu.inkSecond : Airisu.inkThird
        strokeWidth: Airisu.hair
        dashed: !root.available
    }
    APrint {
        visible: root.chosen >= 0
        x: root.edge(Math.max(0, root.chosen))
        width: root.edge(Math.max(0, root.chosen) + 1) - x
        height: root.height
        Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        Behavior on width { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        die: "rect"
        pressed: root.pressedIndex >= 0 && root.pressedIndex === root.chosen
        fill: root.available ? Airisu.ink : Airisu.inkThird
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
            readonly property color ink: box.chosen ? Airisu.reverse : root.available ? Airisu.inkSecond : Airisu.inkThird
            readonly property real run: box.chosen && root.pressedIndex === box.index ? Airisu.registration : 0
            x: root.edge(box.index)
            width: root.edge(box.index + 1) - x
            height: root.height

            // The rule between two boxes, gone beside the plate.
            Rectangle {
                visible: box.index > 0 && !box.chosen && root.chosen !== box.index - 1
                width: Airisu.hair
                height: parent.height
                color: root.available ? Airisu.inkSecond : Airisu.inkThird
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
                        border.width: Airisu.hair
                        border.color: box.chosen ? Airisu.reverse : Airisu.rule
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
            ATombo {
                anchors.fill: parent
                shown: root.hoveredIndex === box.index && !box.chosen && root.available
                focusMarks: root.focusedIndex === box.index
            }
        }
    }
}
