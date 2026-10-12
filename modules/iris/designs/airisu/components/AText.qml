import QtQuick
import qs.modules.iris.style

// AIRISU's three voices. `wide`: Archivo SemiExpanded ExtraBold for titles and figures (tracking −4 %); `mono`: data and
// labels in capitals with wide tracking; `body`: Archivo to read. Size from the iRiS ladder.
Text {
    id: root
    property string voice: "body"
    property int size: root.voice === "mono" ? IrisStyle.typeCaption : IrisStyle.typeBody
    color: Airisu.gofun
    font.family: root.voice === "wide" ? Airisu.wide : root.voice === "mono" ? Airisu.mono : Airisu.body
    font.pixelSize: root.size
    font.weight: root.voice === "wide" ? Font.ExtraBold : root.voice === "mono" ? Font.Medium : Font.DemiBold
    font.letterSpacing: root.voice === "mono" ? Math.round(root.size * 0.16) : root.voice === "wide" ? -Math.round(root.size * 0.04) : 0
    font.capitalization: root.voice === "mono" ? Font.AllUppercase : Font.MixedCase
    font.features: root.voice === "wide" ? { "tnum": 1 } : ({})
    elide: Text.ElideRight
    maximumLineCount: 1
    renderType: Text.NativeRendering
}
