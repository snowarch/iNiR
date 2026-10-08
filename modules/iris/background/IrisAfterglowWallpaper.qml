pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

// Afterglow's grade over whatever the desktop draws (a still picture, its transition, a preview while browsing, a
// video or a GIF), so every wallpaper and every way of reaching one wears the same light. Cost follows motion: the
// capture of the wallpaper, the grade and its cache redraw only when what is under them changes; at rest the desktop
// shows one cached texture, a playing video costs one capture and one grading pass per frame it decodes.
Item {
    id: root

    // What the grade is laid over: Background's wallpaper container. It is hidden from the scene and drawn here.
    property Item source: null
    // A video or GIF changes every frame: the cache would only add a pass, so the grade is drawn directly.
    property bool live: false
    // The grade changed (Background's glass copies follow it; a new picture already tells them).
    signal shown()

    // Mipmapped so the bloom reads a small copy of the same frame (textureLod) instead of decoding or rendering it twice.
    ShaderEffectSource {
        id: capture
        anchors.fill: parent
        sourceItem: root.source
        hideSource: true
        live: true
        mipmap: true
        smooth: true
        visible: false
    }
    ShaderEffect {
        id: graded
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("IrisAfterglowWallpaper.frag.qsb")
        readonly property var source: capture
        readonly property vector4d glowMix: IrisStyle.afterglowMix
        readonly property vector4d glowShadow: IrisStyle.afterglowShadow
        readonly property vector4d glowLight: IrisStyle.afterglowLight
        readonly property vector4d glowBloom: IrisStyle.afterglowBloomInk
        // xy: the drawn size; z: one texel of the bloom's mip level in uv; w: that level.
        readonly property vector4d frame: Qt.vector4d(Math.max(1, root.width), Math.max(1, root.height),
            1.6 * 14 / Math.max(16, root.width), 3.8)
        onGlowMixChanged: root.shown()
        onGlowShadowChanged: root.shown()
        onGlowLightChanged: root.shown()
        onGlowBloomChanged: root.shown()
    }
    // The graded frame, kept: a widget animating elsewhere on the desktop redraws one texture, not the grade.
    ShaderEffectSource {
        id: cache
        anchors.fill: parent
        // Hiding the grade is how the cache stands in for it; a live wallpaper draws the grade itself and the cache rests.
        // (`visible: false` on the grade would leave the cache an empty texture.)
        sourceItem: graded
        hideSource: !root.live
        visible: !root.live
        live: !root.live
    }
}
