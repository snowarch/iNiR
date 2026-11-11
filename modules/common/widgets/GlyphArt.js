.pragma library

// Everything GlyphArt knows that is not drawing: the glyph atlas, the character sets, the palettes, the looks and
// the list of options a person can tune. The wallpaper effect, the Afterglyph widget and every Settings page read
// this one file. A port of winchxyz/afterglyph (MIT): its glyphs, sets, palettes and looks, value for value.

// ---------------------------------------------------------------------------------------------- the atlas
// 8 tiles a row, each a 7x9 unit cell drawn at 4 px a unit. Slots: 0-25 symbols, 32-41 digits, 44-48 shade blocks,
// 50-57 halftone dots, then the three text sets, each sorted from light to heavy when it is painted.
var UNIT = 4
var TILE_W = 28
var TILE_H = 36
var ATLAS_COLS = 8
var ATLAS_ROWS = 28
var SLOT_ASCII = 64
var SLOT_DENSE = 80
var SLOT_CUSTOM = 160

var ASCII = ".:-=+*#%@"
var DENSE = ".'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"

// The 5x7 digits, as runs [x, y, length] of lit pixels.
var DIGITS = [
    ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    ["01110", "10001", "10001", "01111", "00001", "00010", "01100"]
]

function uniqueChars(text, limit) {
    var seen = {}, out = []
    var chars = Array.from(String(text || ""))
    for (var i = 0; i < chars.length && out.length < limit; i++) {
        var ch = chars[i]
        if (ch === " " || ch === "\n" || ch === "\t" || seen[ch]) continue
        seen[ch] = true
        out.push(ch)
    }
    return out
}

// Paints the whole atlas on a Canvas context, white ink on nothing, and returns how many glyphs each text set got
// ({ ascii, dense, custom }): a set is a ramp of that many slots from its first one, light to heavy.
function paintAtlas(g, custom, family) {
    g.setTransform(1, 0, 0, 1, 0, 0)
    g.clearRect(0, 0, ATLAS_COLS * TILE_W, ATLAS_ROWS * TILE_H)
    g.fillStyle = "white"
    g.strokeStyle = "white"
    g.lineCap = "round"
    g.lineJoin = "round"

    function at(slot, draw) {
        g.save()
        g.translate((slot % ATLAS_COLS) * TILE_W, Math.floor(slot / ATLAS_COLS) * TILE_H)
        g.scale(UNIT, UNIT)
        g.beginPath(); g.rect(0, 0, 7, 9); g.clip()
        draw()
        g.restore()
    }
    function line(w, p) {
        g.lineWidth = w
        g.beginPath()
        g.moveTo(p[0], p[1])
        for (var i = 2; i < p.length; i += 2) g.lineTo(p[i], p[i + 1])
        g.stroke()
    }
    function oval(cx, cy, rx, ry, fill, w) {
        g.beginPath()
        g.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
        if (fill) g.fill()
        else { g.lineWidth = w; g.stroke() }
    }
    var thin = 0.85, bold = 1.55

    at(1, function () { oval(3.5, 4.5, 0.75, 0.75, true) })                                            // dot
    at(2, function () { line(thin, [1.3, 4.5, 5.7, 4.5]) })                                            // dash
    at(3, function () { line(thin + 0.2, [1.1, 3.3, 5.9, 3.3]); line(thin + 0.2, [1.1, 5.7, 5.9, 5.7]) })   // equals
    at(4, function () { line(thin, [3.5, 0.9, 3.5, 8.1]) })                                            // bar
    at(5, function () { line(thin + 0.15, [2.3, 0.9, 2.3, 8.1]); line(thin + 0.15, [4.7, 0.9, 4.7, 8.1]) }) // double bar
    at(6, function () { line(thin, [5.7, 1.0, 1.3, 8.0]) })                                            // slash
    at(7, function () { line(thin, [1.3, 1.0, 5.7, 8.0]) })                                            // backslash
    at(8, function () { line(bold, [5.5, 1.3, 1.5, 7.7]) })                                            // bold slash
    at(9, function () { line(bold, [1.5, 1.3, 5.5, 7.7]) })                                            // bold backslash
    at(10, function () {                                                                               // tilde
        g.lineWidth = thin; g.beginPath(); g.moveTo(1.2, 5); g.bezierCurveTo(2.6, 2.6, 4.4, 6.6, 5.8, 4); g.stroke()
    })
    at(11, function () { line(thin, [1.8, 2.8, 5.2, 6.4]); line(thin, [5.2, 2.8, 1.8, 6.4]) })         // cross
    at(12, function () { line(thin, [1.5, 4.5, 5.5, 4.5]); line(thin, [3.5, 2.4, 3.5, 6.6]) })         // plus
    at(13, function () { line(thin, [1.1, 5.0, 2.3, 7.4, 3.9, 1.7, 6.0, 1.7]) })                       // root
    at(14, function () {                                                                               // pi
        line(thin, [1.1, 2.6, 5.9, 2.6]); line(thin, [2.4, 2.6, 2.2, 7.2]); line(thin, [4.6, 2.6, 4.8, 7.2])
    })
    at(15, function () {                                                                               // delta
        g.lineWidth = thin; g.beginPath(); g.moveTo(3.5, 1.8); g.lineTo(5.8, 7.0); g.lineTo(1.2, 7.0); g.closePath(); g.stroke()
    })
    at(16, function () { g.lineWidth = thin; g.beginPath(); g.roundedRect(1.5, 1.2, 4, 6.6, 1.7, 1.7); g.stroke() })  // zero
    at(17, function () { oval(3.5, 4.5, 2.1, 2.9, false, 1.35) })                                      // ring
    at(18, function () { oval(3.5, 4.5, 2.2, 3.0, false, 1.3); oval(3.5, 4.5, 0.85, 0.85, true) })     // eye
    at(19, function () { oval(3.5, 4.5, 2.5, 3.2, true) })                                             // disc
    at(20, function () { g.fillRect(0.7, 0.7, 5.6, 7.6) })                                             // block
    at(21, function () { g.fillRect(2.1, 0.7, 2.8, 7.6) })                                             // upright bar
    at(22, function () { g.fillRect(0.7, 3.1, 5.6, 2.8) })                                             // level bar
    at(23, function () { oval(3.5, 2.9, 0.7, 0.7, true); oval(3.5, 6.1, 0.7, 0.7, true) })             // colon
    at(24, function () { line(thin, [1.1, 7.6, 5.9, 7.6]) })                                           // low line
    at(25, function () { line(thin, [1.1, 1.4, 5.9, 1.4]) })                                           // high line

    for (var d = 0; d < 10; d++) (function (digit) {
        at(32 + digit, function () {
            for (var y = 0; y < 7; y++) for (var x = 0; x < 5; x++)
                if (DIGITS[digit][y].charAt(x) === "1") g.fillRect(1 + x - 0.04, 1 + y - 0.04, 1.08, 1.08)
        })
    })(d)

    var shades = [
        function (x, y) { return (x % 4 === 0 && y % 4 === 0) || (x % 4 === 2 && y % 4 === 2) },
        function (x, y) { return x % 2 === 0 && y % 2 === 0 },
        function (x, y) { return (x + y) % 2 === 0 },
        function (x, y) { return !(x % 2 === 1 && y % 2 === 1) },
        function () { return true }
    ]
    for (var s = 0; s < shades.length; s++) (function (index) {
        at(44 + index, function () {
            for (var y = 0; y < 9; y++) for (var x = 0; x < 7; x++)
                if (shades[index](x, y)) g.fillRect(x - 0.02, y - 0.02, 1.04, 1.04)
        })
    })(s)

    var dots = [0.6, 1.0, 1.4, 1.8, 2.3, 2.8, 3.4, 4.1]
    for (var k = 0; k < dots.length; k++) (function (index) {
        at(50 + index, function () { oval(3.5, 4.5, dots[index], dots[index] * 1.12, true) })
    })(k)

    // A text set: every character drawn once to weigh its ink, then again in order, lightest first.
    function textSet(first, chars) {
        g.font = "bold 29px " + (family || "monospace")
        g.textAlign = "center"
        g.textBaseline = "middle"
        function put(slot, ch) {
            var x = (slot % ATLAS_COLS) * TILE_W, y = Math.floor(slot / ATLAS_COLS) * TILE_H
            g.clearRect(x, y, TILE_W, TILE_H)
            g.save()
            g.beginPath(); g.rect(x, y, TILE_W, TILE_H); g.clip()
            g.fillText(ch, x + TILE_W / 2, y + TILE_H / 2 + 1)
            g.restore()
            return [x, y]
        }
        var weighed = []
        for (var i = 0; i < chars.length; i++) {
            var where = put(first, chars[i])
            var data = g.getImageData(where[0], where[1], TILE_W, TILE_H).data
            var ink = 0
            for (var o = 3; o < data.length; o += 4) ink += data[o]
            if (ink > 0) weighed.push([chars[i], ink])
        }
        weighed.sort(function (a, b) { return a[1] - b[1] })
        var x0 = (first % ATLAS_COLS) * TILE_W, y0 = Math.floor(first / ATLAS_COLS) * TILE_H
        g.clearRect(x0, y0, TILE_W, TILE_H)
        for (var n = 0; n < weighed.length; n++) put(first + n, weighed[n][0])
        return weighed.length
    }
    return {
        ascii: textSet(SLOT_ASCII, Array.from(ASCII)),
        dense: textSet(SLOT_DENSE, uniqueChars(DENSE, 64)),
        custom: textSet(SLOT_CUSTOM, uniqueChars(custom, 64))
    }
}

// How the shader reads a character set: [mode, first slot, slots]. Modes: 0 mixed symbols, 1 lines only, 2 a ramp
// from nothing to the heaviest, 3 any of them at random.
function charset(name, counts) {
    switch (String(name || "signal")) {
    case "lines": return [1, 0, 0]
    case "blocks": return [2, 44, 5]
    case "dots": return [2, 50, 8]
    case "digits": return [3, 32, 10]
    case "binary": return [3, 32, 2]
    case "ascii": return counts && counts.ascii > 0 ? [2, SLOT_ASCII, counts.ascii] : [0, 0, 0]
    case "dense": return counts && counts.dense > 0 ? [2, SLOT_DENSE, counts.dense] : [0, 0, 0]
    case "custom": return counts && counts.custom > 0 ? [2, SLOT_CUSTOM, counts.custom] : [0, 0, 0]
    default: return [0, 0, 0]
    }
}

// ---------------------------------------------------------------------------------------------- palettes
// Three inks from dark to light, the colour of a stroke in the shade, and the name a readout prints.
var PALETTES = {
    night:    { ramp: ["#3b37d6", "#7f8cff", "#e8ebff"], accent: "#63e6b4", label: "NIGHT-BLUE" },
    phosphor: { ramp: ["#0c7a3e", "#39e27d", "#e2ffe9"], accent: "#b8ffd0", label: "PHOSPHOR" },
    amber:    { ramp: ["#a34a00", "#ffa62b", "#fff1d0"], accent: "#ffd27a", label: "AMBER" },
    rose:     { ramp: ["#8a1c5a", "#ff5fa2", "#ffe3ef"], accent: "#7fd4ff", label: "ROSE" },
    mono:     { ramp: ["#666c80", "#c9cede", "#ffffff"], accent: "#ffffff", label: "SILVER" },
    cyber:    { ramp: ["#5a1bd6", "#ff3df0", "#b8f7ff"], accent: "#36f0ff", label: "CYBER" },
    vapor:    { ramp: ["#2a6cff", "#ff71ce", "#fffb96"], accent: "#05ffa1", label: "VAPOR" },
    sunset:   { ramp: ["#7a1f5c", "#ff6a3d", "#ffe9a8"], accent: "#ffd166", label: "SUNSET" },
    ice:      { ramp: ["#1f5fae", "#7fe3ff", "#ffffff"], accent: "#c9f4ff", label: "ICE" },
    gold:     { ramp: ["#7a5a12", "#f2c14e", "#fff7dc"], accent: "#ffe9a3", label: "GOLD" },
    forest:   { ramp: ["#14532d", "#5fd38d", "#f3ffd9"], accent: "#d6ff8a", label: "FOREST" },
    thermal:  { ramp: ["#2b0a6b", "#ff3b30", "#fff34d"], accent: "#ff9f1c", label: "THERMAL" },
    blood:    { ramp: ["#5a0a0a", "#ff2d2d", "#ffd9d9"], accent: "#ff8a8a", label: "BLOOD" }
}

// The inks a palette setting means: null keeps the picture's own colours. `theme` is the shell's
// [dark, middle, light, stroke] and `own` the person's three colours.
function inks(name, theme, own) {
    var key = String(name || "source")
    if (key === "source") return null
    if (key === "theme") return theme && theme.length >= 4 ? { ramp: [theme[0], theme[1], theme[2]], accent: theme[3], label: "THEME" } : PALETTES.night
    if (key === "custom") return { ramp: [own[0], own[1], own[2]], accent: own[2], label: "CUSTOM" }
    return PALETTES[key] || null
}

// ---------------------------------------------------------------------------------------------- options
// Every value a person can set, in the units the config holds (whole numbers; a percent where the engine wants a
// factor). `look: true` marks what a look decides: choosing a look writes those, and each can be tuned after.
var OPTIONS = [
    { key: "charset",  look: true, kind: "choice", fallback: "signal", group: "Characters", label: "Characters",
      choices: [["signal", "Mixed symbols"], ["ascii", "Classic ASCII"], ["dense", "Full ASCII"], ["dots", "Halftone dots"],
                ["blocks", "Shade blocks"], ["lines", "Lines only"], ["digits", "Digits"], ["binary", "Binary"],
                ["custom", "Your own characters"]] },
    { key: "custom",   kind: "text", fallback: " .oO0@#", group: "Characters", label: "Your characters", when: ["charset", "custom"] },
    { key: "cell",     kind: "range", fallback: 12, min: 5, max: 28, step: 1, unit: "px", group: "Characters", label: "Character size" },
    { key: "strokes",  look: true, kind: "range", fallback: 100, min: 0, max: 200, step: 5, unit: "%", group: "Characters", label: "Edge lines" },
    { key: "shimmer",  look: true, kind: "range", fallback: 30, min: 0, max: 300, step: 10, unit: "%", group: "Characters", label: "Shimmer" },
    { key: "rain",     look: true, kind: "range", fallback: 0, min: 0, max: 100, step: 5, unit: "%", group: "Characters", label: "Digit rain" },
    { key: "outline",  look: true, kind: "switch", fallback: true, group: "Characters", label: "Thin outline around the subject" },

    { key: "palette",  look: true, kind: "choice", fallback: "source", group: "Colour", label: "Colours",
      choices: [["source", "From the picture"], ["theme", "Your theme"], ["night", "Night blue"], ["phosphor", "Phosphor"],
                ["amber", "Amber"], ["rose", "Rose"], ["mono", "Silver"], ["cyber", "Cyber"], ["vapor", "Vapor"],
                ["sunset", "Sunset"], ["ice", "Ice"], ["gold", "Gold"], ["forest", "Forest"], ["thermal", "Thermal"],
                ["blood", "Blood"], ["custom", "Your own three colours"]] },
    { key: "c1",       look: true, kind: "colour", fallback: "#3a1c8f", group: "Colour", label: "Dark colour", when: ["palette", "custom"] },
    { key: "c2",       look: true, kind: "colour", fallback: "#ff5fd2", group: "Colour", label: "Middle colour", when: ["palette", "custom"] },
    { key: "c3",       look: true, kind: "colour", fallback: "#fff3b0", group: "Colour", label: "Light colour", when: ["palette", "custom"] },
    { key: "back",     look: true, kind: "colour", fallback: "#020205", group: "Colour", label: "Backdrop" },
    { key: "sat",      look: true, kind: "range", fallback: 150, min: 0, max: 260, step: 5, unit: "%", group: "Colour", label: "Vividness", when: ["palette", "source"] },
    { key: "contrast", look: true, kind: "range", fallback: 115, min: 40, max: 250, step: 5, unit: "%", group: "Colour", label: "Contrast" },
    { key: "hue",      look: true, kind: "range", fallback: 0, min: 0, max: 360, step: 5, unit: "°", group: "Colour", label: "Hue shift" },
    { key: "rainbow",  look: true, kind: "range", fallback: 0, min: 0, max: 200, step: 5, unit: "%", group: "Colour", label: "Rainbow" },
    { key: "drift",    look: true, kind: "range", fallback: 0, min: 0, max: 300, step: 10, unit: "%", group: "Colour", label: "Colour drift" },

    { key: "glow",     look: true, kind: "range", fallback: 60, min: 0, max: 200, step: 5, unit: "%", group: "Screen", label: "Glow" },
    { key: "scan",     look: true, kind: "range", fallback: 0, min: 0, max: 100, step: 5, unit: "%", group: "Screen", label: "Scanlines" },
    { key: "grain",    look: true, kind: "range", fallback: 30, min: 0, max: 400, step: 10, unit: "%", group: "Screen", label: "Grain" },
    { key: "fringe",   look: true, kind: "range", fallback: 30, min: 0, max: 400, step: 10, unit: "%", group: "Screen", label: "Lens fringe" },
    { key: "curve",    look: true, kind: "range", fallback: 0, min: 0, max: 100, step: 5, unit: "%", group: "Screen", label: "Screen curve" },
    { key: "glitch",   look: true, kind: "range", fallback: 0, min: 0, max: 100, step: 5, unit: "%", group: "Screen", label: "Glitch" },
    { key: "paper",    look: true, kind: "switch", fallback: false, group: "Screen", label: "Ink on paper" },
    { key: "mirror",   look: true, kind: "choice", fallback: "off", group: "Screen", label: "Mirror",
      choices: [["off", "Off"], ["two", "Left to right"], ["four", "Four ways"]] },

    { key: "subject",  kind: "choice", fallback: "auto", group: "Subject", label: "Background",
      choices: [["auto", "Decide by itself"], ["none", "Keep the whole picture"], ["dark", "Remove a dark background"],
                ["light", "Remove a light background"]] },
    { key: "cut",      kind: "range", fallback: 16, min: 3, max: 60, step: 1, unit: "%", group: "Subject", label: "Cut strength" },
    { key: "invert",   kind: "switch", fallback: false, group: "Subject", label: "Swap light and dark" },

    { key: "motion",   kind: "switch", fallback: true, group: "Motion", label: "Keep it moving" },
    { key: "intro",    kind: "choice", fallback: "grow", group: "Motion", label: "A new picture",
      choices: [["off", "Is simply there"], ["grow", "Grows from its base"], ["scan", "Scans from the top"],
                ["type", "Types out, row by row"], ["centre", "Spreads from the centre"], ["dissolve", "Fades in at random"]] },
    { key: "speed",    kind: "range", fallback: 100, min: 25, max: 200, step: 5, unit: "%", group: "Motion", label: "Speed" },
    { key: "sway",     kind: "switch", fallback: true, group: "Motion", label: "Gentle sway", when: ["motion", true] },
    { key: "camera",   kind: "switch", fallback: true, group: "Motion", label: "Slow camera moves", when: ["motion", true] },
    { key: "pulse",    kind: "switch", fallback: true, group: "Motion", label: "Rings of light", when: ["motion", true] },
    { key: "turn",     kind: "switch", fallback: true, group: "Motion", label: "Objects turn by themselves", when: ["motion", true] }
]

var GROUPS = ["Characters", "Colour", "Screen", "Subject", "Motion"]

function option(key) {
    for (var i = 0; i < OPTIONS.length; i++) if (OPTIONS[i].key === key) return OPTIONS[i]
    return null
}

// An option is shown when what it depends on holds (`when: [key, value]`).
function shown(spec, read) {
    return !spec.when || read(spec.when[0]) === spec.when[1]
}

// ---------------------------------------------------------------------------------------------- looks
// What each look changes over the base one, in config units.
var LOOKS = [
    ["signal", "Signal", {}],
    ["theme", "Theme", { palette: "theme" }],
    ["terminal", "Terminal", { charset: "ascii", palette: "phosphor", strokes: 50, scan: 70, glow: 125, fringe: 200 }],
    ["matrix", "Matrix", { charset: "digits", palette: "phosphor", strokes: 0, shimmer: 200, glow: 140, outline: false, rain: 100 }],
    ["amber", "Amber CRT", { charset: "dense", palette: "amber", strokes: 40, scan: 85, glow: 130, fringe: 250, grain: 200, curve: 70 }],
    ["blueprint", "Blueprint", { charset: "lines", palette: "night", strokes: 150, glow: 90, shimmer: 50, back: "#04102a" }],
    ["halftone", "Halftone", { charset: "dots", palette: "mono", strokes: 0, shimmer: 0, outline: false, glow: 45, grain: 50 }],
    ["blocks", "Blocks", { charset: "blocks", strokes: 0, shimmer: 30, outline: false, glow: 70, sat: 180 }],
    ["vapor", "Vapor", { palette: "vapor", charset: "ascii", strokes: 80, scan: 40, curve: 50, glow: 120, back: "#12042a" }],
    ["glitch", "Glitch", { palette: "cyber", glitch: 70, fringe: 300, scan: 50, shimmer: 200, glow: 120 }],
    ["prism", "Prism", { rainbow: 100, drift: 100, sat: 220, glow: 115 }],
    ["thermal", "Thermal", { palette: "thermal", charset: "dots", strokes: 0, outline: false, shimmer: 20, glow: 110 }],
    ["gold", "Gold", { palette: "gold", charset: "dense", strokes: 60, glow: 130, back: "#0a0703" }],
    ["kaleido", "Kaleido", { mirror: "four", palette: "cyber", drift: 60, glow: 120 }],
    ["newsprint", "Newsprint", { charset: "dots", strokes: 30, shimmer: 0, glow: 0, paper: true, grain: 200, sat: 120, contrast: 120, outline: false }],
    ["typewriter", "Typewriter", { charset: "dense", palette: "mono", strokes: 0, shimmer: 0, glow: 0, paper: true, grain: 150, contrast: 130, outline: false }]
]

function lookNames() {
    return LOOKS.map(function (l) { return { value: l[0], label: l[1] } })
}

// Everything a look sets, key by key: the base value of each look option, with the look's own over it.
function lookValues(name) {
    var found = null
    for (var i = 0; i < LOOKS.length; i++) if (LOOKS[i][0] === name) found = LOOKS[i]
    if (!found) found = LOOKS[0]
    var out = {}
    for (var k = 0; k < OPTIONS.length; k++) if (OPTIONS[k].look) out[OPTIONS[k].key] = OPTIONS[k].fallback
    for (var key in found[2]) out[key] = found[2][key]
    return out
}

// The settings as a whole from whatever holds them: `read(key)` returns a stored value or undefined.
function settings(read) {
    var out = {}
    for (var i = 0; i < OPTIONS.length; i++) {
        var spec = OPTIONS[i], value = read(spec.key)
        if (value === undefined || value === null) value = spec.fallback
        if (spec.kind === "range") value = Math.max(spec.min, Math.min(spec.max, Number(value) || 0))
        else if (spec.kind === "switch") value = value === true
        else value = String(value)
        out[spec.key] = value
    }
    return out
}

// A look as settings, for a sample of it: the base of everything with the look's values over it.
function lookSettings(name) {
    var values = lookValues(name)
    return settings(function (key) { return values[key] })
}

// ---------------------------------------------------------------------------------------------- the demos
// The built-in subjects: a film of an iris growing, and eight objects that turn. `name`, `seed` and `label` are what
// a readout prints; `breath` how much a soft one moves.
var DEMOS = [
    { value: "iris",     label: "Iris",      name: "IRIS",    seed: "35E3", tag: "NIGHT-BLUE", form: -1, breath: 0 },
    { value: "planet",   label: "Planet",    name: "SATURN",  seed: "9A1F", tag: "RINGED-GAS", form: 0, breath: 0 },
    { value: "jelly",    label: "Jellyfish", name: "MEDUSA",  seed: "7C02", tag: "DEEP-PINK",  form: 1, breath: 0.014 },
    { value: "helix",    label: "Helix",     name: "HELIX",   seed: "DNA2", tag: "B-FORM",     form: 2, breath: 0 },
    { value: "knot",     label: "Knot",      name: "TREFOIL", seed: "2B3C", tag: "2-3 TORUS",  form: 3, breath: 0 },
    { value: "heart",    label: "Heart",     name: "HEART",   seed: "C0DE", tag: "CARDIOID",   form: 4, breath: 0.008 },
    { value: "crystal",  label: "Crystal",   name: "QUARTZ",  seed: "51O2", tag: "HEX-PRISM",  form: 5, breath: 0 },
    { value: "amphora",  label: "Amphora",   name: "AMPHORA", seed: "0530", tag: "TERRACOTTA", form: 6, breath: 0 },
    { value: "mushroom", label: "Mushroom",  name: "AMANITA", seed: "F1A6", tag: "FLY-AGARIC", form: 7, breath: 0 }
]

function demo(name) {
    for (var i = 0; i < DEMOS.length; i++) if (DEMOS[i].value === name) return DEMOS[i]
    return null
}

// The camera's slow moves once a picture is in: how close it is `t` seconds after the intro, 0.6 far to 1 close.
var CAMERA = [[0, 0.6], [2, 0.6], [4, 1], [26, 1], [27.5, 0.6], [29.5, 0.8], [44, 0.8], [46, 0.6]]
function cameraAt(t) {
    var tt = ((t % 46) + 46) % 46
    for (var i = 1; i < CAMERA.length; i++) if (tt <= CAMERA[i][0]) {
        var a = CAMERA[i - 1], b = CAMERA[i]
        var x = Math.max(0, Math.min(1, (tt - a[0]) / (b[0] - a[0])))
        return a[1] + (b[1] - a[1]) * x * x * (3 - 2 * x)
    }
    return 0.6
}

// The colours a colour option offers by name: nobody types a hex code. [value, label].
var INKS = [["#020205", "Black"], ["#10131c", "Night"], ["#04102a", "Deep blue"], ["#12042a", "Deep violet"], ["#0a0703", "Umber"],
    ["#3a1c8f", "Indigo"], ["#3b6cff", "Blue"], ["#2fd6c8", "Teal"], ["#63e6b4", "Mint"], ["#9be85a", "Lime"], ["#ffd23f", "Amber"],
    ["#ff8a3c", "Orange"], ["#ff4d5e", "Red"], ["#ff5fd2", "Pink"], ["#b78cff", "Violet"], ["#fff3b0", "Cream"], ["#f4f6ff", "White"]]

// Every option at its factory value, each under `prefix`: what "Restore defaults" writes.
function defaults(prefix) {
    var out = {}
    out[prefix + "look"] = LOOKS[0][0]
    for (var i = 0; i < OPTIONS.length; i++) out[prefix + OPTIONS[i].key] = OPTIONS[i].fallback
    return out
}
// Whether anything left its factory value: `read(key)` returns a stored value or undefined.
function changed(read) {
    for (var i = 0; i < OPTIONS.length; i++) {
        var value = read(OPTIONS[i].key)
        if (value !== undefined && value !== null && String(value) !== String(OPTIONS[i].fallback)) return true
    }
    return false
}

// What choosing a look writes: the look's name and every value it decides, each under `prefix`.
function lookWrites(prefix, name) {
    var values = lookValues(name), out = {}
    out[prefix + "look"] = name
    for (var key in values) out[prefix + key] = values[key]
    return out
}

// The subjects a person picks from besides their own picture: [value, label].
function subjects() {
    return DEMOS.map(function (d) { return { value: d.value, label: d.label } })
}
