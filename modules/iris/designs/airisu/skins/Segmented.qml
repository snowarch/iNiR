pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's segmented (board Components): positions that click into place like a mechanical selector. A 1 px iron frame,
// fillets between the positions, the chosen one on the gofun plate in the wide face. It does not slide: it snaps in
// 90 ms with a pixel of throw.
Item {
    id: root
    property Item host
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    function slotX(i: int): real { return root.host ? root.host.slotX(i) - root.host.inset : 0 }
    readonly property real span: root.width

    Rectangle { anchors.fill: parent; color: "transparent"; border.width: Airisu.line; border.color: Airisu.fillet }
    Rectangle {
        visible: root.chosen >= 0
        x: root.slotX(Math.max(0, root.chosen))
        width: root.slotX(Math.max(0, root.chosen) + 1) - x
        height: root.height
        color: Airisu.gofun
        Behavior on x { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
        Behavior on width { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift } }
    }
    Repeater {
        model: root.options
        Item {
            id: position
            required property var modelData
            required property int index
            readonly property bool chosen: root.chosen === position.index
            readonly property string label: Translation.tr(String(position.modelData.label ?? ""))
            readonly property string glyph: String(position.modelData.glyph ?? "")
            x: root.slotX(position.index)
            width: root.slotX(position.index + 1) - x
            height: root.height
            readonly property color ink: position.chosen ? Airisu.inkOnGofun : Airisu.data
            Rectangle { visible: position.index > 0 && !position.chosen && root.chosen !== position.index - 1; width: Airisu.line; height: parent.height; color: Airisu.fillet }
            MaterialSymbol {
                visible: root.host?.glyphOnly ?? false
                anchors.centerIn: parent
                text: position.glyph
                fill: position.chosen ? 1 : 0
                iconSize: Math.round(16 * Airisu.d)
                color: position.ink
            }
            Column {
                visible: !(root.host?.glyphOnly ?? false)
                anchors.centerIn: parent
                width: parent.width - Math.round(10 * Airisu.d)
                spacing: Math.round(2 * Airisu.d)
                MaterialSymbol {
                    visible: (root.host?.pictured ?? false) && position.glyph.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: position.glyph
                    fill: position.chosen ? 1 : 0
                    iconSize: Math.round(19 * Airisu.d)
                    color: position.ink
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(6 * Airisu.d)
                    Rectangle {
                        visible: String(position.modelData.swatch ?? "").length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(10 * Airisu.d); height: width
                        color: position.modelData.swatch ?? "transparent"
                        border.width: Airisu.line; border.color: Airisu.fillet
                    }
                    AText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, position.width - Math.round(14 * Airisu.d))
                        horizontalAlignment: Text.AlignHCenter
                        voice: "wide"
                        size: (root.host?.pictured ?? false) ? IrisStyle.typeFootnote : IrisStyle.typeMeta
                        font.weight: position.chosen ? Font.ExtraBold : Font.DemiBold
                        font.letterSpacing: 0
                        text: position.label
                        color: position.ink
                    }
                }
            }
        }
    }
}
