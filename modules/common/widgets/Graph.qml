import QtQuick
import qs.modules.common
import qs.modules.common.functions

/*
 * Simple one value line graph
 */
Canvas {
    id: root

    enum Alignment { Left, Right }

    required property list<real> values
    property int points: values.length
    property color color: Appearance.colors.colPrimary
    property real fillOpacity: 0.5
    property real lineWidth: 2
    property bool smooth: true
    property var alignment: Graph.Alignment.Left

    onValuesChanged: root.requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!root.values || root.values.length < 2)
            return

        var n = root.points
        var dx = width / (n - 1)

        // Build point array, skipping gaps
        var pts = []
        for (var i = 0; i < n; ++i) {
            var vi = (root.alignment === Graph.Alignment.Right) ? root.values.length - n + i : i
            if (vi < 0 || vi >= root.values.length) continue
            pts.push({ x: i * dx, y: height - root.values[vi] * height })
        }
        if (pts.length < 2) return

        ctx.strokeStyle = root.color
        ctx.fillStyle = ColorUtils.transparentize(root.color, 1 - root.fillOpacity)
        ctx.lineWidth = root.lineWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.moveTo(pts[0].x, height)
        ctx.lineTo(pts[0].x, pts[0].y)

        if (root.smooth && pts.length > 2) {
            // Monotone cubic interpolation for smooth curves
            for (var j = 1; j < pts.length; ++j) {
                var cpx = (pts[j - 1].x + pts[j].x) / 2
                ctx.bezierCurveTo(cpx, pts[j - 1].y, cpx, pts[j].y, pts[j].x, pts[j].y)
            }
        } else {
            for (var k = 1; k < pts.length; ++k)
                ctx.lineTo(pts[k].x, pts[k].y)
        }
        ctx.stroke()
        ctx.lineTo(pts[pts.length - 1].x, height)
        ctx.fill()
    }
}
