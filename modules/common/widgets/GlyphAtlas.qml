pragma ComponentBehavior: Bound

// The sheet of glyphs GlyphArt draws from, painted once (and again when the person's own characters change). One
// can serve any number of GlyphArt in the same window. Never seen by itself.
// After winchxyz/afterglyph (MIT).

import QtQuick
import "GlyphArt.js" as Glyphs

Item {
    id: root

    // The person's own characters, and the font the text sets are written in.
    property string custom: ""
    property string family: "monospace"
    // How many glyphs each text set got: { ascii, dense, custom }.
    property var counts: ({ ascii: 0, dense: 0, custom: 0 })
    readonly property alias texture: sheetTexture

    width: Glyphs.ATLAS_COLS * Glyphs.TILE_W
    height: Glyphs.ATLAS_ROWS * Glyphs.TILE_H
    onCustomChanged: sheet.requestPaint()
    onFamilyChanged: sheet.requestPaint()

    Canvas {
        id: sheet
        anchors.fill: parent
        onPaint: root.counts = Glyphs.paintAtlas(getContext("2d"), root.custom, "\"" + root.family + "\"")
        onPainted: sheetTexture.scheduleUpdate()
    }
    ShaderEffectSource {
        id: sheetTexture
        sourceItem: sheet
        hideSource: true
        live: false
        smooth: true
        mipmap: true
        textureSize: Qt.size(root.width, root.height)
    }
}
