pragma ComponentBehavior: Bound

// A picture as glowing glyphs. `picture` is any item (a wallpaper, a cover, a video): it is read at one texel per
// 7x9 glyph cell and GlyphArt.frag picks and inks each cell's glyph on the GPU, in one pass. At rest nothing runs:
// a still picture is drawn once, a moving one once per frame it changes, and the only animation is `appear()`.
// After winchxyz/afterglyph (MIT).

import QtQuick
import "GlyphArt.js" as Glyphs

Item {
    id: root

    required property Item picture
    // The picture is only an input: never painted by itself.
    property bool hidePicture: false
    property string lookName: "signal"
    // Screen px per glyph pixel: 1 is a 7x9 cell.
    property int glyphPixel: 1
    property real glowAmount: 1
    // Opaque over what is under it; off, only the glyphs and their glow are drawn.
    property bool plate: true
    property real radius: 0
    // The "theme" look inks with this.
    property color accent: "white"      // literal: replaced by the owner's accent
    // 0 hides every glyph (a picture not ready yet).
    property bool shown: true

    readonly property int unit: Math.max(1, root.glyphPixel)
    readonly property int columns: Math.max(1, Math.floor(root.width / (Glyphs.CELL_W * root.unit)))
    readonly property int rows: Math.max(1, Math.floor(root.height / (Glyphs.CELL_H * root.unit)))
    readonly property var make: Glyphs.look(root.lookName)
    readonly property bool themed: root.lookName === "theme"
    property real grow: 1

    // The picture grows in from its foot, once.
    function appear(): void {
        growing.stop()
        root.grow = 0
        growing.start()
    }
    function settle(): void {
        growing.stop()
        root.grow = 1
    }
    NumberAnimation {
        id: growing
        target: root
        property: "grow"
        to: 1
        duration: 1400
        easing.type: Easing.OutCubic
    }

    // One texel per cell: the smooth reduction is the average each cell needs, and the smallest mip is the picture's
    // mean, which the shader exposes by. Redrawn only when the picture itself changes.
    ShaderEffectSource {
        id: cells
        sourceItem: root.picture
        hideSource: root.hidePicture
        textureSize: Qt.size(root.columns, root.rows)
        smooth: true
        mipmap: true
    }

    // The glyphs, painted once: one row of 7x9 cells.
    Canvas {
        id: sheet
        width: Glyphs.GLYPHS.length * Glyphs.CELL_W
        height: Glyphs.CELL_H
        onPaint: Glyphs.paintAtlas(getContext("2d"))
        onPainted: atlasTexture.scheduleUpdate()
    }
    ShaderEffectSource {
        id: atlasTexture
        sourceItem: sheet
        hideSource: true
        live: false
        smooth: false
        textureSize: Qt.size(sheet.width, sheet.height)
    }

    ShaderEffect {
        anchors.fill: parent
        readonly property vector4d box: Qt.vector4d(width, height, root.radius, root.unit)
        readonly property vector4d grid: Qt.vector4d(root.columns, root.rows, Glyphs.GLYPHS.length, root.make.paper ? 1 : 0)
        readonly property vector4d make: Qt.vector4d(root.shown ? root.grow : 0, root.make.glow * root.glowAmount,
            root.make.fringe, root.make.scan)
        readonly property vector4d tone: Qt.vector4d(root.make.own, root.make.contrast, root.make.strokes,
            root.plate || root.make.paper ? 1 : 0)
        readonly property color low: root.themed ? Qt.darker(root.accent, 2.2) : root.make.low
        readonly property color mid: root.themed ? root.accent : root.make.mid
        readonly property color high: root.themed ? Qt.lighter(root.accent, 1.7) : root.make.high
        readonly property color plate: root.make.plate
        readonly property var picture: cells
        readonly property var atlas: atlasTexture
        fragmentShader: Qt.resolvedUrl("GlyphArt.frag.qsb")
    }
}
