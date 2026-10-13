import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's level (the Control Center's volume, brightness, microphone): a meter (メーター) on a lacquer panel, its level
// a ladder of steps (ASteps) that rise from the start. The glyph and name stand at the start, the figure at the end.
// The pointer lifts the panel a rung. Upright, the steps climb from the foot. The host (IrisCapsuleSlider) keeps the drag, the wheel and the pocket
// under the glyph that mutes.
Item {
    id: root
    property Item host
    readonly property real value: Math.max(0, Math.min(1, Number(root.host?.shownValue ?? 0)))
    readonly property bool vertical: root.host?.vertical ?? false
    readonly property bool muted: root.host?.muted ?? false
    readonly property bool held: root.host?.held ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property string icon: String(root.host?.icon ?? "")
    readonly property string label: String(root.host?.label ?? "")
    readonly property string figure: root.muted ? Translation.tr("Muted") : String(Math.round(root.value * 100))
    readonly property string subject: root.muted || !root.available ? "system"
        : /mic/.test(root.icon) ? "message"
        : /volume|speaker|headphone|music|audio/.test(root.icon) ? "music" : "display"
    readonly property color panel: Airisu.lacquerOf(Airisu.pigment(root.subject))
    readonly property color ink: root.available ? Airisu.inkOn(root.panel) : Airisu.inkThirdOn(root.panel)
    readonly property int pad: Airisu.u(3)
    // Tall enough, the words stand over the steps; slim, everything is one line and the steps run between them.
    readonly property bool stacked: !root.vertical && root.height >= Math.round(44 * Airisu.d)
    readonly property real span: root.vertical ? root.height : root.width

    ALacquer {
        anchors.fill: parent
        cutTopRight: !root.vertical
        cutBottomLeft: !root.vertical
        cutTopLeft: root.vertical
        cutBottomRight: root.vertical
        lacquer: root.hovered && !root.held && root.available ? Airisu.step(root.panel, Airisu.hoverStep) : root.panel
    }

    MaterialSymbol {
        id: glyph
        x: root.vertical ? Math.round((root.width - width) / 2) : root.pad
        y: root.vertical ? root.height - height - root.pad : root.stacked ? root.pad : Math.round((root.height - height) / 2)
        text: root.icon
        fill: 1
        iconSize: Math.round(18 * Airisu.d)
        color: root.muted ? Airisu.inkSecondOn(root.panel) : root.ink
    }
    AText {
        id: name
        visible: root.stacked && root.label.length > 0
        anchors.left: glyph.right
        anchors.leftMargin: Airisu.u(2)
        anchors.verticalCenter: glyph.verticalCenter
        width: Math.min(implicitWidth, root.width - glyph.width - figureText.width - 2 * root.pad - Airisu.u(5))
        size: IrisStyle.typeLabel
        font.weight: Font.Bold
        text: root.label
        color: root.ink
    }
    AText {
        id: figureText
        x: root.vertical ? Math.round((root.width - width) / 2) : root.width - width - root.pad
        y: root.vertical ? root.pad : root.stacked ? glyph.y + Math.round((glyph.height - height) / 2) : Math.round((root.height - height) / 2)
        voice: root.muted ? "text" : "figure"
        lean: root.muted ? 0 : Airisu.lean
        size: root.muted ? IrisStyle.typeMeta : IrisStyle.typeTitle
        font.weight: root.muted ? Font.Bold : Font.ExtraBold
        text: root.figure
        color: root.muted ? Airisu.inkSecondOn(root.panel) : root.ink
    }

    // The steps, laid along the length (turned to climb when upright).
    ASteps {
        id: lane
        // Where the steps run, in the lane's own (unturned) frame.
        readonly property real start: root.vertical ? root.pad + glyph.height + Airisu.u(2)
            : root.stacked ? root.pad : root.pad + glyph.width + Airisu.u(3)
        readonly property real end: root.vertical ? root.height - root.pad - figureText.height - Airisu.u(2)
            : root.stacked ? root.width - root.pad : root.width - root.pad - figureText.width - Airisu.u(3)
        readonly property real across: root.vertical ? root.width - 2 * root.pad
            : root.stacked ? root.height - glyph.y - glyph.height - Airisu.u(2) - root.pad : Math.round(root.height * 0.42)
        width: Math.max(0, lane.end - lane.start)
        height: lane.across
        x: root.vertical ? Math.round((root.width - width) / 2) : lane.start
        y: root.vertical ? Math.round((root.height - height) / 2) : root.stacked ? root.height - root.pad - height : Math.round((root.height - height) / 2)
        rotation: root.vertical ? -90 : 0
        value: root.value
        muted: root.muted
        available: root.available
        ink: root.ink
        quiet: Airisu.inkThirdOn(root.panel)
    }
}
