.pragma library

// The glyphs and looks of GlyphArt, the one item that draws a picture as glyph art (the wallpaper effect and the
// Afterglyph widget both draw through it).
//
// A glyph is a 7x9 cell (5x7 of ink inside a one-pixel margin), drawn here as rows of '#'. The shader picks one per
// cell of the picture: the ramp by brightness, a stroke where the picture has an edge, a digit where it is still
// growing in. Order matters: the shader addresses them by index (RAMP, BOLD, THIN, DIGIT, DOT below).

var CELL_W = 7
var CELL_H = 9

var GLYPHS = [
    // 0: nothing
    [".......", ".......", ".......", ".......", ".......", ".......", ".......", ".......", "......."],
    // 1-9: the ramp, light to heavy:  .  -  =  √  π  0  ◎  ●  ■
    [".......", ".......", ".......", ".......", ".......", ".......", "...#...", ".......", "......."],
    [".......", ".......", ".......", ".......", ".#####.", ".......", ".......", ".......", "......."],
    [".......", ".......", ".......", ".#####.", ".......", ".#####.", ".......", ".......", "......."],
    [".......", "...###.", "...#...", "...#...", "...#...", ".#.#...", "..##...", "...#...", "......."],
    [".......", ".......", ".#####.", "..#.#..", "..#.#..", "..#.#..", "..#.#..", ".#..##.", "......."],
    [".......", "..###..", ".#...#.", ".#..##.", ".#.#.#.", ".##..#.", ".#...#.", "..###..", "......."],
    [".......", "..###..", ".#...#.", ".#.#.#.", ".#.#.#.", ".#.#.#.", ".#...#.", "..###..", "......."],
    [".......", "..###..", ".#####.", ".#####.", ".#####.", ".#####.", ".#####.", "..###..", "......."],
    [".......", ".#####.", ".#####.", ".#####.", ".#####.", ".#####.", ".#####.", ".#####.", "......."],
    // 10-13: bold strokes along an edge:  ‖  =  /  \
    [".......", ".##.##.", ".##.##.", ".##.##.", ".##.##.", ".##.##.", ".##.##.", ".##.##.", "......."],
    [".......", ".......", ".#####.", ".#####.", ".......", ".#####.", ".#####.", ".......", "......."],
    [".......", ".....#.", "....##.", "...##..", "..##...", ".##....", ".#.....", ".......", "......."],
    [".......", ".#.....", ".##....", "..##...", "...##..", "....##.", ".....#.", ".......", "......."],
    // 14-17: thin hatching along a texture:  |  ─  /  \
    [".......", "...#...", "...#...", "...#...", "...#...", "...#...", "...#...", "...#...", "......."],
    [".......", ".......", ".......", ".......", ".#####.", ".......", ".......", ".......", "......."],
    [".......", ".....#.", "....#..", "....#..", "...#...", "..#....", "..#....", ".#.....", "......."],
    [".......", ".#.....", "..#....", "..#....", "...#...", "....#..", "....#..", ".....#.", "......."],
    // 18-27: digits, for what is still appearing
    [".......", "..###..", ".#...#.", ".#...#.", ".#...#.", ".#...#.", ".#...#.", "..###..", "......."],
    [".......", "...#...", "..##...", "...#...", "...#...", "...#...", "...#...", "..###..", "......."],
    [".......", "..###..", ".#...#.", ".....#.", "....#..", "...#...", "..#....", ".#####.", "......."],
    [".......", "..###..", ".#...#.", ".....#.", "...##..", ".....#.", ".#...#.", "..###..", "......."],
    [".......", "....#..", "...##..", "..#.#..", ".#..#..", ".#####.", "....#..", "....#..", "......."],
    [".......", ".#####.", ".#.....", ".####..", ".....#.", ".....#.", ".#...#.", "..###..", "......."],
    [".......", "..###..", ".#.....", ".####..", ".#...#.", ".#...#.", ".#...#.", "..###..", "......."],
    [".......", ".#####.", ".....#.", "....#..", "...#...", "...#...", "..#....", "..#....", "......."],
    [".......", "..###..", ".#...#.", ".#...#.", "..###..", ".#...#.", ".#...#.", "..###..", "......."],
    [".......", "..###..", ".#...#.", ".#...#.", ".#...#.", "..####.", ".....#.", "..###..", "......."],
    // 28: the contour's dot, one cell outside the subject
    [".......", ".......", ".......", ".......", "...#...", ".......", ".......", ".......", "......."]
]

// Paints the atlas on a Canvas context: one row of glyphs, white ink on nothing.
function paintAtlas(ctx) {
    ctx.clearRect(0, 0, GLYPHS.length * CELL_W, CELL_H)
    ctx.fillStyle = "white"
    for (var g = 0; g < GLYPHS.length; g++)
        for (var y = 0; y < CELL_H; y++)
            for (var x = 0; x < CELL_W; x++)
                if (GLYPHS[g][y].charAt(x) === "#") ctx.fillRect(g * CELL_W + x, y, 1, 1)
}

// A look: where the colour comes from and how the tube treats it. `own` 1 keeps the picture's colours; 0 inks by
// brightness along low → mid → high. `paper` turns light into ink on a sheet. "theme" takes the shell's accent.
var LOOKS = {
    signal:    { own: 1, strokes: 1.0, glow: 1.0,  fringe: 1.0, scan: 0.0,  contrast: 1.0, paper: false,
                 low: "#3b37d6", mid: "#7f8cff", high: "#e8ebff", plate: "#020205" },   // literal: the look's own palette
    theme:     { own: 0, strokes: 1.0, glow: 1.0,  fringe: 1.0, scan: 0.0,  contrast: 1.0, paper: false,
                 low: "", mid: "", high: "", plate: "#020205" },                        // literal: the tube's black
    phosphor:  { own: 0, strokes: 0.5, glow: 1.25, fringe: 2.0, scan: 0.7,  contrast: 1.0, paper: false,
                 low: "#0c7a3e", mid: "#39e27d", high: "#e2ffe9", plate: "#020205" },   // literal: green phosphor
    amber:     { own: 0, strokes: 0.4, glow: 1.3,  fringe: 2.5, scan: 0.85, contrast: 1.0, paper: false,
                 low: "#a34a00", mid: "#ffa62b", high: "#fff1d0", plate: "#020205" },   // literal: amber phosphor
    blueprint: { own: 0, strokes: 1.5, glow: 0.9,  fringe: 1.0, scan: 0.0,  contrast: 1.0, paper: false,
                 low: "#3b37d6", mid: "#7f8cff", high: "#e8ebff", plate: "#04102a" },   // literal: blueprint blue
    paper:     { own: 0, strokes: 1.0, glow: 0.0,  fringe: 0.0, scan: 0.0,  contrast: 1.2, paper: true,
                 low: "#1b1915", mid: "#1b1915", high: "#1b1915", plate: "#ede6d6" }    // literal: ink and newsprint
}

function look(name) {
    return LOOKS[String(name || "")] || LOOKS.signal
}
