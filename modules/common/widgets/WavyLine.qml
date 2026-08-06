pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Item {
    id: root

    property real amplitudeMultiplier: 0.5
    property real frequency: 6
    property color color: Appearance.colors.colPrimary
    property real lineWidth: 4
    property real fullLength: width
    property bool animate: false

    // Date.now() / 400 advanced the old Canvas phase by 2.5 rad/s.
    // One full 2π cycle therefore took about 2513 ms. Moving a cached wave
    // texture by exactly one wavelength preserves that motion and appearance
    // without repainting every point of the Canvas on every frame.
    property int phaseDuration: 2513

    readonly property real wavelength: root.frequency > 0
        ? Math.max(1, root.fullLength / root.frequency)
        : Math.max(1, root.width)

    clip: true

    function requestPaint(): void {
        waveCanvas.requestPaint()
    }

    Canvas {
        id: waveCanvas
        height: root.height
        // Paint the complete track once; the parent clips progress changes.
        width: Math.max(1, root.fullLength) + root.wavelength + root.lineWidth
        x: 0

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const amplitude = root.lineWidth * root.amplitudeMultiplier
            const safeLength = Math.max(1, root.fullLength)
            const centerY = height / 2

            ctx.strokeStyle = root.color
            ctx.lineWidth = root.lineWidth
            ctx.lineCap = "round"
            ctx.beginPath()

            let firstPoint = true
            for (let px = ctx.lineWidth / 2; px <= width - ctx.lineWidth / 2; px += 1) {
                const waveY = centerY + amplitude
                    * Math.sin(root.frequency * 2 * Math.PI * px / safeLength)
                if (firstPoint) {
                    ctx.moveTo(px, waveY)
                    firstPoint = false
                } else {
                    ctx.lineTo(px, waveY)
                }
            }
            ctx.stroke()
        }

        NumberAnimation on x {
            from: 0
            to: -root.wavelength
            duration: root.phaseDuration
            loops: Animation.Infinite
            running: root.animate && root.visible
                && root.width > 0 && root.height > 0 && root.frequency > 0
            easing.type: Easing.Linear
        }
    }

    onAnimateChanged: {
        if (!root.animate)
            waveCanvas.x = 0
    }

    Connections {
        target: root
        function onAmplitudeMultiplierChanged() { waveCanvas.requestPaint() }
        function onFrequencyChanged() {
            waveCanvas.x = 0
            waveCanvas.requestPaint()
        }
        function onColorChanged() { waveCanvas.requestPaint() }
        function onLineWidthChanged() { waveCanvas.requestPaint() }
        function onFullLengthChanged() {
            waveCanvas.x = 0
            waveCanvas.requestPaint()
        }
        function onHeightChanged() { waveCanvas.requestPaint() }
    }
}
