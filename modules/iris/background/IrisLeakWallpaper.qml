pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

// Light leak over whatever the desktop draws (a still picture, its transition, a preview while browsing, a video or a
// GIF): the light IrisField exposes the bodies with, laid over the wallpaper as a leak lands on a print, so the bodies'
// rims and the picture catch one light. Cost follows motion: the capture of the wallpaper, the exposure and its cache
// redraw only when what is under them changes; at rest the desktop shows one cached texture, a playing video costs one
// capture and one pass per frame it decodes.
Item {
    id: root

    // What the light is laid over: Background's wallpaper container. It is hidden from the scene and drawn here.
    property Item source: null
    // A video or GIF changes every frame: the cache would only add a pass, so the exposure is drawn directly.
    property bool live: false
    // The size the frame is captured and kept at (0: the item's own). A glass copy grades at its blur's half resolution.
    property size textureSize: Qt.size(0, 0)
    // The graded frame as a texture an effect reads (IrisGlassSource blurs it).
    readonly property Item texture: cache
    // Each mip level of a smaller texture covers twice the pixels: the halation (bloom) reads one level less per halving.
    readonly property real mipLevel: Math.max(0, 3.8 - (root.textureSize.width > 0
        ? Math.log(Math.max(1, root.width) / root.textureSize.width) / Math.LN2 : 0))
    // The picture under it: a new one develops as a Polaroid does (Background binds its path; empty elsewhere).
    property string picture: ""
    // A copy behind glass shows the exposure as it stands: only what is seen first develops (Light leak › Develop).
    property bool develops: true
    // The light changed (Background's glass copies follow it; a new picture already tells them).
    signal shown()

    // A Polaroid developing, 0 to 1: the exposure rises out of a milky ground, the shadows first and the colour last,
    // when the texture comes on and when the picture changes. The cache redraws only while it plays.
    property real developed: 1
    NumberAnimation {
        id: developing
        target: root
        property: "developed"
        from: 0
        to: 1
        duration: IrisStyle.duration(1800)
        easing.type: Easing.OutCubic
        onFinished: root.shown()
    }
    function develop(): void {
        if (root.develops && IrisStyle.leakDevelop && IrisStyle.motionEnabled)
            developing.restart()
    }
    Component.onCompleted: root.develop()
    onPictureChanged: root.develop()
    // Turning Develop on plays it once, so the row shows what it does.
    Connections {
        target: IrisStyle
        function onLeakDevelopChanged(): void { root.develop() }
    }

    // Mipmapped so the halation reads a small copy of the same frame (textureLod) instead of decoding or rendering it twice.
    ShaderEffectSource {
        id: capture
        anchors.fill: parent
        sourceItem: root.source
        hideSource: true
        live: true
        mipmap: true
        smooth: true
        visible: false
        textureSize: root.textureSize
    }
    ShaderEffect {
        id: graded
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("IrisLeakWallpaper.frag.qsb")
        readonly property var source: capture
        // y is how strongly the wallpaper is exposed, not the bodies' light.
        readonly property vector4d leakMix: IrisStyle.leakWallpaperMix
        readonly property vector4d leakGrain: IrisStyle.leakFilm
        readonly property vector4d leakStop0: IrisStyle.leakStop0
        readonly property vector4d leakStop1: IrisStyle.leakStop1
        readonly property vector4d leakStop2: IrisStyle.leakStop2
        readonly property vector4d leakStop3: IrisStyle.leakStop3
        readonly property vector4d leakStop4: IrisStyle.leakStop4
        readonly property vector4d leakCore: IrisStyle.leakCore
        readonly property vector4d leakAt0: IrisStyle.leakAt0
        readonly property vector4d leakAt1: IrisStyle.leakAt1
        readonly property vector4d leakAt2: IrisStyle.leakAt2
        readonly property vector4d leakForm0: IrisStyle.leakForm0
        readonly property vector4d leakForm1: IrisStyle.leakForm1
        readonly property vector4d leakForm2: IrisStyle.leakForm2
        readonly property vector4d leakHue0: IrisStyle.leakHue0
        readonly property vector4d leakHue1: IrisStyle.leakHue1
        readonly property vector4d leakHue2: IrisStyle.leakHue2
        // xy: the drawn size; z: one texel of the halation's mip level in uv; w: that level.
        readonly property vector4d frame: Qt.vector4d(Math.max(1, root.width), Math.max(1, root.height),
            1.6 * 14 / Math.max(16, root.width), root.mipLevel)
        readonly property vector4d film: Qt.vector4d(root.developed, IrisStyle.leakDust, IrisStyle.leakGate, 0)
        onLeakMixChanged: root.shown()
        onLeakGrainChanged: root.shown()
        onLeakStop1Changed: root.shown()
        onLeakAt0Changed: root.shown()
        onFilmChanged: if (!developing.running) root.shown()
    }
    // The exposed frame, kept: a widget animating elsewhere on the desktop redraws one texture, not the exposure.
    ShaderEffectSource {
        id: cache
        anchors.fill: parent
        // Hiding the exposure is how the cache stands in for it; a live wallpaper draws it itself and the cache rests.
        // (`visible: false` on it would leave the cache an empty texture.)
        sourceItem: graded
        hideSource: !root.live
        visible: !root.live
        live: !root.live
        textureSize: root.textureSize
    }
}
