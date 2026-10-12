import QtQuick

// A screen (網点, SYSTEM.md law 1): the second level of a pigment, printed as a pattern of whole pixels instead of a
// transparency. `density` 10 · 25 · 50; `kind` "dot" (an ordered dot) or "line" (a 45° rule). It is one tiled cell,
// drawn once and never animated: a disabled control, a track's travelled part, the frame's paper.
Image {
    id: root
    property color pigment: Airisu.ink
    property int density: 25
    property string kind: "dot"
    readonly property int cell: root.kind === "line" ? (root.density >= 50 ? 2 : root.density >= 25 ? 4 : 8)
        : root.density >= 50 ? 2 : root.density >= 25 ? 2 : 3
    readonly property string pixels: {
        const c = root.cell
        if (root.kind === "line") {
            let out = ""
            for (let i = 0; i < c; i++) out += `<rect x='${c - 1 - i}' y='${i}' width='1' height='1'/>`
            return out
        }
        if (root.density >= 50) return "<rect x='0' y='0' width='1' height='1'/><rect x='1' y='1' width='1' height='1'/>"
        return "<rect x='0' y='0' width='1' height='1'/>"
    }
    source: Airisu.svgCell(root.cell, root.cell, root.pixels, root.pigment)
    fillMode: Image.Tile
    smooth: false
    cache: true
    horizontalAlignment: Image.AlignLeft
    verticalAlignment: Image.AlignTop
}
