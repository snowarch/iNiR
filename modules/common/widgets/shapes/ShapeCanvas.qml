import QtQuick
import qs.modules.common
import "shapes/morph.js" as Morph

Canvas {
    id: root
    property color color: Appearance.colors.colPrimary
    // Outline pass. A filled plate cannot express "focused" on a surface whose
    // own fill is transparent — it just becomes a solid blob. Stroke lets the
    // same silhouette be drawn as a ring instead.
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property var roundedPolygon: null
    property bool polygonIsNormalized: true
    // Aspect-aware polygons can keep their own bounds and fit them to the
    // canvas. When their source aspect matches this canvas, scaling is uniform.
    property bool fitToCanvas: false

    // Internals: size
    property var bounds: roundedPolygon.calculateBounds()
    implicitWidth: bounds[2] - bounds[0]
    implicitHeight: bounds[3] - bounds[1]

    // Internals: anim
    property var prevRoundedPolygon: null
    property double progress: 1
    property var morph: new Morph.Morph(roundedPolygon, roundedPolygon)
    // Material 3 Expressive fast spatial: the 1.67 overshoot is the whole point —
    // the shape springs past its target and settles. Honour reduced motion here
    // so every consumer inherits it instead of overriding the animation (and
    // losing the overshoot) just to get a duration gate.
    property Animation animation: NumberAnimation {
        duration: Appearance.animationsEnabled ? 350 : 0
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
    }
    
    onRoundedPolygonChanged: {
        delete root.morph
        root.morph = new Morph.Morph(root.prevRoundedPolygon ?? root.roundedPolygon, root.roundedPolygon)
        morphBehavior.enabled = false;
        root.progress = 0
        morphBehavior.enabled = true;
        root.progress = 1
        root.prevRoundedPolygon = root.roundedPolygon
    }

    Behavior on progress {
        id: morphBehavior
        animation: root.animation
    }

    // A Canvas repaints its fill instantly, so a cookie face jumped between
    // hover/selected colours while every rectangular surface in the shell eased
    // into them. Match the shell.
    Behavior on color {
        enabled: Appearance.animationsEnabled
        animation: ColorAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    onProgressChanged: requestPaint()
    onColorChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.fillStyle = root.color
        ctx.clearRect(0, 0, width, height)
        if (!root.morph) return
        const cubics = root.morph.asCubics(root.progress)
        if (cubics.length === 0) return

        ctx.save()
        let scaleX = 1
        let scaleY = 1
        if (root.fitToCanvas) {
            const bounds = root.roundedPolygon.calculateBounds()
            const boundsWidth = Math.max(0.0001, bounds[2] - bounds[0])
            const boundsHeight = Math.max(0.0001, bounds[3] - bounds[1])
            scaleX = root.width / boundsWidth
            scaleY = root.height / boundsHeight
            ctx.scale(scaleX, scaleY)
            ctx.translate(-bounds[0], -bounds[1])
        } else {
            const size = Math.min(root.width, root.height)
            const offsetX = root.width / 2 - size / 2
            const offsetY = root.height / 2 - size / 2
            ctx.translate(offsetX, offsetY)
            if (root.polygonIsNormalized) {
                ctx.scale(size, size)
                scaleX = scaleY = size
            }
        }

        ctx.beginPath()
        ctx.moveTo(cubics[0].anchor0X, cubics[0].anchor0Y)
        for (const cubic of cubics) {
            ctx.bezierCurveTo(
                cubic.control0X, cubic.control0Y,
                cubic.control1X, cubic.control1Y,
                cubic.anchor1X, cubic.anchor1Y
            )
        }
        ctx.closePath()
        ctx.fill()
        if (root.strokeWidth > 0 && root.strokeColor.a > 0) {
            // The path is drawn in polygon space, so the transform would scale the
            // pen too. Divide it back out to keep the ring an even device width.
            ctx.strokeStyle = root.strokeColor
            ctx.lineWidth = root.strokeWidth / Math.max(0.0001, (scaleX + scaleY) / 2)
            ctx.stroke()
        }
        ctx.restore()
    }
}
