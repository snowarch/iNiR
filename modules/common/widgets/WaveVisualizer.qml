import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Canvas {
    id: root
    property list<var> points
    property list<var> smoothPoints
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
                        : Appearance.colors.colPrimary
    // Fill alpha — reads global config, consumers can override
    property real fillOpacity: (Config.options?.appearance?.cava?.waveOpacity ?? 30) / 100

    onPointsChanged: () => { root.requestPaint() }
    onFillOpacityChanged: requestPaint()
    onColorChanged: requestPaint()

    anchors.fill: parent
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var points = root.points;
        var maxVal = root.maxVisualizerValue || 1;
        var h = height;
        var w = width;
        var n = points.length;
        if (n < 2) return;

        var smoothWindow = root.smoothing;
        root.smoothPoints = [];
        for (var i = 0; i < n; ++i) {
            var sum = 0, count = 0;
            for (var j = -smoothWindow; j <= smoothWindow; ++j) {
                var idx = Math.max(0, Math.min(n - 1, i + j));
                sum += points[idx];
                count++;
            }
            root.smoothPoints.push(sum / count);
        }
        if (!root.live) root.smoothPoints.fill(0);

        ctx.beginPath();
        ctx.moveTo(0, h);
        for (var i = 0; i < n; ++i) {
            var x = i * w / (n - 1);
            var y = h - (root.smoothPoints[i] / maxVal) * h * 0.9;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.fillOpacity);
        ctx.fill();
    }

    layer.enabled: Appearance.effectsEnabled
    layer.effect: MultiEffect {
        source: root
        saturation: 0.2
        blurEnabled: Appearance.effectsEnabled
        blurMax: 7
        blur: Appearance.effectsEnabled ? 1 : 0
    }
}
