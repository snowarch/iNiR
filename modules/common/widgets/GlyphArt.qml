pragma ComponentBehavior: Bound

// A picture as glowing glyphs. `picture` is any item (a wallpaper, a cover, a video), or `source` names one of the
// built-in subjects (GlyphArt.js DEMOS) or "word". The picture is reduced to one texel per glyph cell; GlyphStats
// reads the whole of it (background to cut, levels), GlyphCompose decides every cell, GlyphArt.frag draws them and
// the screen over them. `settings` is every option of GlyphArt.js, as Glyphs.settings() returns them.
// With `settings.motion` a still picture is alive the way Afterglyph's is (shimmer, a gentle sway, slow camera
// moves, rings of light, moving grain), only while it is seen (`live`); without it a picture is drawn once.
// A port of winchxyz/afterglyph (MIT) to the GPU.

import QtQuick
import "GlyphArt.js" as Glyphs

Item {
    id: root

    property Item picture: null
    // The picture is only an input: never painted by itself.
    property bool hidePicture: false
    property string source: "picture"
    property string word: ""
    property var settings: Glyphs.settings(function () { return undefined })
    // The shell's own inks for the "theme" palette: dark, middle, light, stroke.
    property var theme: ["#3b37d6", "#7f8cff", "#e8ebff", "#63e6b4"]
    // Opaque over what is under it; off, only the glyphs and their glow are drawn.
    property bool plate: true
    property real radius: 0
    // Off hides every glyph (a picture not ready yet).
    property bool shown: true
    // Off, it never moves whatever the settings say (a surface that is covered).
    property bool live: true
    // The picture moves by itself (a video, a GIF): it is read at the glyphs' pace, never at its own frame rate.
    property bool animated: false
    // Kept as one texture between its own frames: a surface that redraws for other reasons (a desktop under its
    // widgets) blits it instead of running the screen pass again.
    property bool cached: false
    // A GlyphAtlas to share; without one it paints its own.
    property Item atlas: null
    property string fontFamily: "monospace"

    readonly property var demo: Glyphs.demo(root.source)
    readonly property bool ownSubject: root.demo !== null || root.source === "word"
    readonly property real cellWidth: Math.max(4, Number(root.settings.cell) || 10)
    readonly property int columns: Math.max(1, Math.min(480, Math.round(root.width / root.cellWidth)))
    readonly property int rows: Math.max(1, Math.min(300, Math.round(root.height / (root.cellWidth * 9 / 7))))
    readonly property var inks: Glyphs.inks(root.settings.palette, root.theme,
        [root.settings.c1, root.settings.c2, root.settings.c3])
    readonly property Item sheet: root.atlas ?? ownAtlas.item
    readonly property var set: Glyphs.charset(root.settings.charset, root.sheet?.counts)
    readonly property real pace: root.settings.speed / 100

    // What moves, and how often it needs a new frame: the shimmer re-rolls 7 times a second, the rest is smooth.
    readonly property bool turning: root.demo !== null && root.settings.turn
    readonly property bool smoothMotion: root.settings.rain > 0 || root.settings.glitch > 0 || root.settings.drift > 0
        || root.settings.camera || root.settings.sway || root.settings.pulse || root.turning
    readonly property bool seen: root.live && root.visible && root.shown
    readonly property bool moving: root.seen && root.settings.motion && (root.smoothMotion || root.settings.shimmer > 0)
    readonly property real sway: root.moving && root.settings.sway
        ? (0.7 * Math.sin(root.clock * 0.7) + 0.3 * Math.sin(root.clock * 1.9 + 1)) * Math.PI / 180 : 0
    property real clock: 0
    property real grow: 1
    // Counts every new drawing while it moves: what copies it (a widget's frosted glass) copies again on each.
    property int frame: 0
    // It is drawing new frames by itself (motion, a video or GIF read, the intro).
    readonly property bool ticking: ticker.running

    Timer {
        id: ticker
        interval: root.smoothMotion ? 66 : Math.max(66, Math.round(1000 / (7 * Math.max(1, root.settings.shimmer / 100))))
        repeat: true
        running: root.moving || (root.animated && root.seen) || growing.running
        onTriggered: {
            if (root.moving) root.clock += interval / 1000 * root.pace
            if (root.animated) cells.scheduleUpdate()
            root.frame++
        }
    }
    onSettingsChanged: root.frame++

    // A new picture comes in the way `settings.intro` says, once.
    function appear(): void {
        growing.stop()
        if (root.settings.intro === "off") {
            root.grow = 1
            return
        }
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
        duration: 2600 / Math.max(0.25, root.pace)
        easing.type: Easing.OutCubic
    }

    Loader {
        id: ownAtlas
        active: root.atlas === null
        sourceComponent: GlyphAtlas {
            custom: root.settings.charset === "custom" ? root.settings.custom : ""
            family: root.fontFamily
        }
    }

    // A built-in subject, drawn at a few samples a cell.
    Loader {
        id: subject
        active: root.ownSubject
        width: Math.min(640, root.columns * 3)
        height: Math.min(480, root.rows * 4)
        sourceComponent: root.demo !== null ? formComponent : wordComponent
    }
    Component {
        id: formComponent
        ShaderEffect {
            readonly property vector4d view: Qt.vector4d(root.demo?.form < 0 ? 8 : (root.demo?.form ?? 0),
                root.turning ? root.clock * 0.5 : 0.6,
                Math.sin(root.clock * 1.6) * (root.demo?.breath ?? 0),
                root.width / Math.max(1, root.height))
            fragmentShader: Qt.resolvedUrl("GlyphForms.frag.qsb")
        }
    }
    Component {
        id: wordComponent
        GlyphWord {
            word: root.word
            family: root.fontFamily
        }
    }

    // Four by four texels a cell, mipmapped: the shaders read its third level, one texel that is the average of the
    // whole cell. One texel a cell read a 4K frame at a single point and the glyphs flickered with every detail.
    // Redrawn only when the picture itself changes.
    ShaderEffectSource {
        id: cells
        sourceItem: root.ownSubject ? subject.item : root.picture
        hideSource: root.ownSubject || root.hidePicture
        textureSize: Qt.size(root.columns * 4, root.rows * 4)
        smooth: true
        mipmap: true
        live: !root.animated
    }

    ShaderEffect {
        id: statsStage
        width: 2
        height: 1
        blending: false
        readonly property vector4d mode: Qt.vector4d(
            ["auto", "none", "dark", "light"].indexOf(root.settings.subject), (root.settings.invert ? 1 : 0) + (root.source === "word" ? 0.25 : 0),
            root.settings.cut / 100 * 0.55, root.settings.cut / 100 * 1.45)
        readonly property var picture: cells
        fragmentShader: Qt.resolvedUrl("GlyphStats.frag.qsb")
    }
    ShaderEffectSource {
        id: stats
        sourceItem: statsStage
        hideSource: true
        smooth: false
        textureSize: Qt.size(2, 1)
    }

    ShaderEffect {
        id: composeStage
        width: root.columns
        height: root.rows
        blending: false
        readonly property vector4d grid: Qt.vector4d(root.columns, root.rows, root.set[0],
            ["off", "two", "four"].indexOf(root.settings.mirror))
        readonly property vector4d chars: Qt.vector4d(root.set[1], root.set[2], root.settings.strokes / 100,
            root.settings.shimmer / 100)
        readonly property vector4d tone: Qt.vector4d(root.inks === null ? 1 : 0, root.settings.contrast / 100,
            root.settings.sat / 100, root.settings.invert ? 1 : 0)
        readonly property vector4d hue: Qt.vector4d(root.settings.hue / 360, root.settings.rainbow / 100,
            root.settings.drift / 100, root.settings.rain / 100)
        readonly property vector4d cut: Qt.vector4d(root.settings.cut / 100 * 0.55, root.settings.cut / 100 * 1.45,
            root.settings.outline ? 1 : 0, ["off", "grow", "scan", "type", "centre", "dissolve"].indexOf(root.settings.intro))
        readonly property vector4d clock: Qt.vector4d(root.clock, !root.shown ? 0 : root.grow >= 1 ? 2 : root.grow,
            root.settings.camera && root.settings.motion ? 1 + (Glyphs.cameraAt(root.clock) - 0.6) * 0.875 : 1,
            root.width / Math.max(1, root.height))
        readonly property vector4d extra: Qt.vector4d(root.settings.pulse && root.settings.motion ? 1 : 0, 0, 0, 0)
        readonly property color low: root.inks?.ramp[0] ?? "black"       // literal: unused with the picture's colours
        readonly property color mid: root.inks?.ramp[1] ?? "black"
        readonly property color high: root.inks?.ramp[2] ?? "black"
        readonly property color accent: root.inks?.accent ?? "#c9cede"   // literal: the outline over a picture's colours
        readonly property var picture: cells
        readonly property var stats: stats
        fragmentShader: Qt.resolvedUrl("GlyphCompose.frag.qsb")
    }
    ShaderEffectSource {
        id: composed
        sourceItem: composeStage
        hideSource: true
        smooth: true
        mipmap: true
        textureSize: Qt.size(root.columns, root.rows)
    }

    ShaderEffect {
        anchors.fill: parent
        layer.enabled: root.cached
        readonly property vector4d box: Qt.vector4d(width, height, root.radius, width / root.columns)
        readonly property vector4d grid: Qt.vector4d(root.columns, root.rows, root.settings.paper ? 1 : 0, root.plate ? 1 : 0)
        readonly property vector4d screen: Qt.vector4d(root.settings.glow / 100, root.settings.scan / 100,
            root.settings.grain / 100, root.settings.fringe / 100)
        readonly property vector4d warp: Qt.vector4d(root.settings.curve / 100, root.settings.glitch / 100, root.clock, root.sway)
        readonly property color back: root.settings.back
        readonly property var cells: composed
        readonly property var atlas: root.sheet?.texture ?? null
        fragmentShader: Qt.resolvedUrl("GlyphArt.frag.qsb")
    }
}
