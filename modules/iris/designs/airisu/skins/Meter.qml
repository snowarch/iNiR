import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's level (the Control Center's volume, brightness, microphone): the whole cell is a lacquer panel in the pigment
// of what it sets (Airisu.pigment: light yamabuki, muted the system's tame, the rest the accent), and the level is that
// pigment at full strength laid across it from the start as far as it goes, its edge at the die's 45°, the way a livery
// is painted. Upright, it is laid from the foot. Its glyph, name and figure are cut out of whichever coat lies under
// each. Nothing else is drawn: no scale, no track, no knob. The host (IrisCapsuleSlider) keeps the drag, the wheel and
// the pocket under the glyph that mutes.
Item {
    id: root
    property Item host
    readonly property real value: root.host?.shownValue ?? 0
    readonly property bool vertical: root.host?.vertical ?? false
    readonly property bool muted: root.host?.muted ?? false
    readonly property bool held: root.host?.held ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property string icon: String(root.host?.icon ?? "")
    readonly property string label: String(root.host?.label ?? "")
    readonly property string figure: root.muted ? Translation.tr("Muted") : String(Math.round(root.value * 100))
    readonly property string subject: root.muted || !root.available ? "system"
        : /bright|light|sunny|contrast/.test(root.icon) ? "caution"
        : /mic/.test(root.icon) ? "message"
        : /volume|speaker|headphone|music|audio/.test(root.icon) ? "music" : ""
    readonly property color pigment: Airisu.pigment(root.subject)
    readonly property color panel: Airisu.lacquerOf(root.pigment)
    readonly property color laid: Airisu.vivid(root.pigment)
    readonly property real span: root.vertical ? root.height : root.width
    readonly property int pad: Airisu.u(3)
    // The ink of whatever coat lies under a mark centred `at` from the start.
    function inkAt(at: real): color { return root.value * root.span > at ? Airisu.inkOn(root.laid) : Airisu.inkOn(root.panel) }
    function secondAt(at: real): color { return root.value * root.span > at ? Airisu.inkSecondOn(root.laid) : Airisu.inkSecondOn(root.panel) }

    Item {
        anchors.centerIn: parent
        width: root.vertical ? root.height : root.width
        height: root.vertical ? root.width : root.height
        rotation: root.vertical ? -90 : 0
        ALacquer {
            anchors.fill: parent
            // Turned to stand, the die's cuts are given back their places on the screen.
            cutTopRight: !root.vertical
            cutBottomLeft: !root.vertical
            cutTopLeft: root.vertical
            cutBottomRight: root.vertical
            lacquer: root.hovered && !root.held ? Airisu.step(root.panel, Airisu.hoverStep) : root.panel
            coat: root.laid
            share: root.value
            travel: root.held ? 0 : Airisu.snap
        }
    }

    MaterialSymbol {
        id: glyph
        x: root.vertical ? Math.round((root.width - width) / 2) : root.pad
        y: root.vertical ? root.height - height - root.pad : Math.round((root.height - height) / 2)
        text: root.icon
        fill: 1
        iconSize: Math.round(18 * Airisu.d)
        color: root.inkAt(root.vertical ? root.pad + height / 2 : root.pad + width / 2)
    }
    AText {
        visible: !root.vertical && root.label.length > 0
        anchors.left: glyph.right
        anchors.leftMargin: Airisu.u(2)
        anchors.verticalCenter: glyph.verticalCenter
        width: Math.min(implicitWidth, root.width - glyph.width - figureText.width - 2 * root.pad - Airisu.u(5))
        size: IrisStyle.typeLabel
        font.weight: Font.Bold
        text: root.label
        color: root.inkAt(x + width / 2)
    }
    AText {
        id: figureText
        x: root.vertical ? Math.round((root.width - width) / 2) : root.width - width - root.pad
        y: root.vertical ? root.pad : Math.round((root.height - height) / 2)
        voice: root.muted ? "text" : "figure"
        size: root.muted ? IrisStyle.typeMeta : IrisStyle.typeTitle
        font.weight: root.muted ? Font.Bold : Font.ExtraBold
        text: root.figure
        color: root.muted ? root.secondAt(root.vertical ? root.height - y - height / 2 : x + width / 2)
            : root.inkAt(root.vertical ? root.height - y - height / 2 : x + width / 2)
    }
}
