pragma Singleton

import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

// AIRISU's own language on top of iRiS's resolved roles (modules/iris/AIRISU.md › Anatomía). Three colours with three
// jobs: chosen is a gofun plate with lacquer ink, live is the vermilion seal, danger is kerria amber. Three voices:
// wide Archivo for titles and figures, mono capitals for data, Archivo for reading.
QtObject {
    id: root
    readonly property real d: IrisStyle.density

    // Colour by job: every value is a resolved role, so Dark, Ink and Light all read.
    readonly property color lacquer: IrisStyle.bodySurface   // 漆黒: the body
    readonly property color sumi: IrisStyle.surfaceHigh       // 墨: a resting tile
    readonly property color gofun: IrisStyle.text             // 胡粉: ink, and the chosen plate
    readonly property color inkOnGofun: IrisStyle.bodySurface    // lacquer ink on the chosen plate
    readonly property color seal: IrisStyle.accentFill        // 朱: what is live
    readonly property color inkOnSeal: IrisStyle.inkOnAccentFill
    readonly property color sealText: IrisStyle.accent        // 朱 as text
    readonly property color amber: IrisStyle.danger           // 山吹: danger (the airisu palette's alert)
    readonly property color inkOnAmber: IrisStyle.onTintFor(IrisStyle.danger)
    readonly property color data: IrisStyle.textSecondary     // mono labels
    readonly property color quiet: IrisStyle.textTertiary
    readonly property color fillet: IrisStyle.hairline        // 鉄: the 1 px rule between parts
    readonly property color socket: IrisStyle.fill            // an unlit meter segment
    // A segment past the safe range when it is not lit: the seal, dimmed into the lacquer.
    readonly property color sealDim: ColorUtils.mix(IrisStyle.accentFill, IrisStyle.bodySurface, 0.42) // iris-literal: AIRISU's 朱 apagado

    // Faces.
    readonly property string wide: "Archivo SemiExpanded"
    readonly property string body: "Archivo"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int line: Math.max(1, Math.round(root.d)) // the 1 px fillet
    readonly property int pad: Math.round(20 * root.d)
    readonly property int gap: Math.round(8 * root.d)
    readonly property int cut: IrisStyle.chamferCut
    // Motion (the concept's time tokens): shift 90 · whip 140 · roll 220 · focus 300 · sweep 420, curve (0.2, 0, 0, 1).
    readonly property int shift: IrisStyle.motionEnabled ? 90 : 0
    readonly property int whip: IrisStyle.motionEnabled ? 140 : 0
    readonly property int roll: IrisStyle.motionEnabled ? 220 : 0
    readonly property var curve: [0.2, 0, 0, 1, 1, 1]
}
