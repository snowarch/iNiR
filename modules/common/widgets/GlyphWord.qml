pragma ComponentBehavior: Bound

// A word as a subject for GlyphArt: heavy letters filled with a gradient that the word itself decides, with light
// and shade over them so the glyphs have something to read. `|` breaks the line. Painted once per word.
// After winchxyz/afterglyph (MIT): its text source.

import QtQuick

Canvas {
    id: root

    property string word: ""
    property string family: "sans-serif"

    onWordChanged: requestPaint()
    onFamilyChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const g = getContext("2d")
        g.reset()
        const lines = String(root.word || "").split("|").map(line => line.trim()).filter(line => line.length > 0)
        if (lines.length === 0 || width < 8 || height < 8) return
        let seed = 0
        for (let i = 0; i < root.word.length; i++) seed = (seed * 31 + root.word.charCodeAt(i)) % 360
        // The largest size at which the longest line fits.
        let size = Math.floor(height * 0.62 / lines.length)
        g.font = "900 " + size + "px \"" + root.family + "\""
        let widest = 1
        for (const line of lines) widest = Math.max(widest, g.measureText(line).width)
        size = Math.max(6, Math.floor(Math.min(size, size * width * 0.82 / widest)))
        g.font = "900 " + size + "px \"" + root.family + "\""
        g.textAlign = "center"
        g.textBaseline = "middle"
        const fill = g.createLinearGradient(0, height * 0.2, width, height * 0.8)
        fill.addColorStop(0, Qt.hsla(seed / 360, 0.85, 0.68, 1))
        fill.addColorStop(0.5, Qt.hsla(((seed + 50) % 360) / 360, 0.9, 0.7, 1))
        fill.addColorStop(1, Qt.hsla(((seed + 110) % 360) / 360, 0.85, 0.66, 1))
        g.fillStyle = fill
        const top = height / 2 - (lines.length - 1) * size * 0.55
        for (let i = 0; i < lines.length; i++) g.fillText(lines[i], width / 2, top + i * size * 1.1)
        // Light from the upper left, shade at the lower right, and fine diagonal lines: only over the letters.
        g.globalCompositeOperation = "source-atop"
        const light = g.createRadialGradient(width * 0.3, height * 0.3, 0, width * 0.3, height * 0.3, width * 0.45)
        light.addColorStop(0, Qt.rgba(1, 1, 1, 0.45))
        light.addColorStop(1, Qt.rgba(1, 1, 1, 0))
        g.fillStyle = light
        g.fillRect(0, 0, width, height)
        const shade = g.createRadialGradient(width * 0.75, height * 0.8, 0, width * 0.75, height * 0.8, width * 0.5)
        shade.addColorStop(0, Qt.rgba(0, 0, 0, 0.14))
        shade.addColorStop(1, Qt.rgba(0, 0, 0, 0))
        g.fillStyle = shade
        g.fillRect(0, 0, width, height)
        g.strokeStyle = Qt.rgba(0, 0, 0, 0.14)
        g.lineWidth = Math.max(1, size * 0.02)
        g.beginPath()
        for (let x = -height; x < width; x += Math.max(4, size * 0.09)) {
            g.moveTo(x, height)
            g.lineTo(x + height, 0)
        }
        g.stroke()
        g.globalCompositeOperation = "source-over"
    }
}
