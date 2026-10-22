import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

// The family's paper (DESIGN.md S3): an 8 px grid of ink dots at 6-8 %, behind a stage, a preview or an empty state,
// never behind text. Painted once per size or ink, not per frame.
Canvas {
    id: root

    property real pitch: Math.round(8 * IrisStyle.density)
    property real dotSize: Math.max(1.5, Math.round(2 * IrisStyle.density * 2) / 2)
    property color ink: IrisStyle.paperDot

    renderStrategy: Canvas.Cooperative
    onPitchChanged: requestPaint()
    onDotSizeChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = root.ink
        const step = Math.max(2, root.pitch)
        // Centred, so the grid sits even against every edge of whatever it lines.
        const ox = ((width % step) + step) / 2 % step
        const oy = ((height % step) + step) / 2 % step
        const r = root.dotSize / 2
        ctx.beginPath()
        for (let y = oy; y < height; y += step)
            for (let x = ox; x < width; x += step) {
                ctx.moveTo(x + r, y)
                ctx.arc(x, y, r, 0, 2 * Math.PI)
            }
        ctx.fill()
    }
}
