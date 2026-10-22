import QtQuick
import qs.modules.iris.style

// AIRISU's voices (SYSTEM.md §5). `figure`: Archivo SemiExpanded ExtraBold, −3 %, tabular, for figures and page heads
// (only from typeTitle up); `text`: Archivo, everything that is read; `ruby`: the small datum set over the main one
// (Archivo Medium, the second ink), AIRISU's label; `data`: mono, only for values compared column by column; `kana`:
// the bundled Japanese layer, always beside the person's own words. Sizes come from iRiS's ladder. A surface's hero figure
// leans forward by `lean` (`Airisu.lean`), the way a number is painted on a livery: sheared about its middle, so it keeps
// its box, set in curves since a sheared glyph cache blurs.
Text {
    id: root
    property string voice: "text"
    property real lean: 0
    readonly property string v: root.voice === "wide" ? "figure" : root.voice === "body" ? "text" : root.voice
    property int size: root.v === "ruby" ? IrisStyle.typeFootnote : root.v === "data" || root.v === "mono" ? IrisStyle.typeMeta
        : root.v === "figure" ? IrisStyle.typeTitle : IrisStyle.typeBody
    color: root.v === "ruby" ? Airisu.inkSecond : Airisu.ink
    font.family: root.v === "figure" ? Airisu.figureFace : root.v === "data" || root.v === "mono" ? Airisu.dataFace
        : root.v === "kana" ? Airisu.kanaFace : Airisu.textFace
    font.pixelSize: root.size
    font.weight: root.v === "figure" ? Font.ExtraBold : root.v === "ruby" ? Font.Medium
        : root.v === "mono" ? Font.Medium : root.v === "kana" ? Font.Bold : Font.DemiBold
    font.letterSpacing: root.v === "figure" ? -Math.round(root.size * 0.03)
        : root.v === "mono" ? Math.round(root.size * 0.16) : 0
    // `mono` is the label (表示): an area's or a group's name over what it holds, in spaced capitals; never a datum.
    font.capitalization: root.v === "mono" ? Font.AllUppercase : Font.MixedCase
    font.features: root.v === "figure" || root.v === "data" ? { "tnum": 1 } : ({})
    elide: Text.ElideRight
    maximumLineCount: 1
    renderType: root.lean !== 0 ? Text.CurveRendering : Text.NativeRendering
    transform: root.lean !== 0 ? [shear] : []
    Matrix4x4 {
        id: shear
        matrix: Qt.matrix4x4(1, -root.lean, 0, root.lean * root.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }
}
