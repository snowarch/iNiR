import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's level (the Control Center's volume, brightness, microphone; SYSTEM.md §6): a graduated rule with its name
// and its figure over it, as a gauge's face sets them. Upright, the rule stands up the cell with the figure at its head
// and the glyph at its foot. Muted, the rule goes to the third ink and the figure says so. The host (IrisCapsuleSlider)
// keeps the drag, the wheel and the pocket under the glyph that mutes.
Item {
    id: root
    property Item host
    readonly property real value: root.host?.shownValue ?? 0
    readonly property bool vertical: root.host?.vertical ?? false
    readonly property bool muted: root.host?.muted ?? false
    readonly property bool held: root.host?.held ?? false
    readonly property string label: String(root.host?.label ?? "")
    readonly property string figure: root.muted ? Translation.tr("Muted") : String(Math.round(root.value * 100))
    readonly property int rule: Math.round(16 * Airisu.d)

    MaterialSymbol {
        id: glyph
        x: root.vertical ? Math.round((root.width - width) / 2) : 0
        y: root.vertical ? root.height - height - Airisu.u(1) : 0
        text: root.host?.icon ?? ""
        fill: 1
        iconSize: Math.round(16 * Airisu.d)
        color: root.muted ? Airisu.inkThird : Airisu.ink
    }
    AText {
        id: name
        visible: !root.vertical && root.label.length > 0
        anchors.left: glyph.right
        anchors.leftMargin: Airisu.u(1.5)
        anchors.verticalCenter: glyph.verticalCenter
        width: Math.min(implicitWidth, root.width - glyph.width - figureText.width - Airisu.u(5))
        size: IrisStyle.typeLabel
        font.weight: Font.DemiBold
        text: root.label
    }
    AText {
        id: figureText
        x: root.vertical ? Math.round((root.width - width) / 2) : root.width - width
        y: root.vertical ? Airisu.u(1) : Math.round(glyph.y + (glyph.height - height) / 2)
        size: root.muted ? IrisStyle.typeMeta : IrisStyle.typeHeadline
        font.weight: root.muted ? Font.Medium : Font.Bold
        font.features: { "tnum": 1 }
        text: root.figure
        color: root.muted ? Airisu.inkSecond : Airisu.ink
    }
    ARuler {
        visible: !root.vertical
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.rule
        value: root.value
        held: root.held
        available: !root.muted && (root.host?.enabled ?? true)
    }
    // Upright: the same rule turned to stand, between the figure and the glyph.
    Item {
        visible: root.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        y: figureText.y + figureText.height + Airisu.u(1.5)
        width: root.rule
        height: Math.max(0, glyph.y - y - Airisu.u(1.5))
        ARuler {
            width: parent.height
            height: parent.width
            anchors.centerIn: parent
            rotation: -90
            value: root.value
            held: root.held
            available: !root.muted && (root.host?.enabled ?? true)
        }
    }
    ATombo {
        anchors.fill: parent
        shown: (root.host?.hovered ?? false) && !root.held
    }
}
