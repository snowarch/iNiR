import QtQuick
import qs
import qs.modules.common.functions
import qs.modules.iris.style


// What a desktop widget is made of: a panel of coloured lacquer cut with the bodies' die, coloured with the pigment of what the
// widget shows (Settings › Widgets › Material: Tinted lacquers it in the widget's first accent instead), as opaque as
// Opacity says; Glass is the clear lacquer, Transparent sets the type straight on the wall in Lume's ink. The
// widget may lay its second coat on it (`share`). While arranging, a bare widget shows its die dashed so it can be found.
Item {
    id: root
    property var face
    property string subject: ""
    property real share: 0
    property real band: 0
    property int travel: 0

    readonly property bool bare: root.face?.clear ?? false
    readonly property color pigment: (root.face?.material ?? "solid") === "tinted"
        ? (root.face?.accent ?? Airisu.pigment(root.subject)) : Airisu.pigment(root.subject)
    readonly property color lacquer: Airisu.stockOf(root.pigment)
    // Glass is suki-urushi, the clear lacquer: the colour still carries and the wall only shows through it, never a grey
    // film over the picture.
    // Over the face's blurred wall the lacquer is laid whole and glazed, as the Island's head is over its picture.
    readonly property Item frost: (root.face?.glass ?? false) ? (root.face?.frost ?? null) : null
    readonly property real alpha: (root.face?.opaque ?? true) ? (root.face?.strength ?? 1) : root.frost ? 1 : Math.max(0.86, root.face?.veil ?? 1)
    // The inks of whatever is set on the widget: cut from the lacquer, or Lume's on the bare wall.
    readonly property color ink: root.bare ? (root.face?.ink ?? Airisu.ink) : Airisu.inkOn(root.lacquer)
    readonly property color inkSecond: root.bare ? (root.face?.inkSecondary ?? Airisu.inkSecond) : Airisu.inkSecondOn(root.lacquer)
    readonly property color inkThird: root.bare ? (root.face?.inkTertiary ?? Airisu.inkThird) : Airisu.inkThirdOn(root.lacquer)
    readonly property color coat: Airisu.coat(root.pigment)
    // The pigment where nothing is set on it (a run, a hand); on the bare wall the widget's accent as Lume solved it.
    readonly property color vivid: root.bare ? (root.face?.accent ?? Airisu.vivid(root.pigment)) : Airisu.vivid(root.pigment)
    // The material's second pigment, for a widget's second series (ki).
    readonly property color vivid2: root.bare ? (root.face?.accent2 ?? Airisu.vivid(Airisu.pigment("caution"))) : Airisu.vivid(Airisu.pigment("caution"))

    ALacquer {
        anchors.fill: parent
        visible: !root.bare && (root.face?.plated ?? true)
        moving: root.face?.moving ?? false
        texture: root.frost
        glaze: IrisStyle.light ? 0.8 : 0.72 // iris-literal: how much of the blurred wall the clear lacquer lets through
        lacquer: ColorUtils.applyAlpha(root.lacquer, root.alpha)
        coat: ColorUtils.applyAlpha(root.coat, root.alpha)
        share: root.share
        band: root.band
        travel: root.travel
    }
    ADie {
        anchors.fill: parent
        visible: root.bare && GlobalStates.widgetEditMode
        kind: "chamfer"
        cut: Airisu.chamfer
        stroke: root.inkThird
        strokeWidth: Airisu.hair
        dashed: true
    }
}
