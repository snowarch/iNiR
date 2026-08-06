import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Canvas {
    id: root
    property list<var> points
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: CavaTheme.primaryColor
    // Fill alpha — reads global config, consumers can override
    property real fillOpacity: (Config.options?.appearance?.cava?.waveOpacity ?? 30) / 100
    onPointsChanged: () => {
        if (root.visible)
            root.requestPaint()
    }
    onVisibleChanged: {
        if (root.visible)
            root.requestPaint()
    }
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

        var smoothWindow = Math.max(0, root.smoothing);
        var smoothPoints = new Array(n);
        var count = smoothWindow * 2 + 1;
        var sum = 0;
        for (var j = -smoothWindow; j <= smoothWindow; ++j)
            sum += points[Math.max(0, Math.min(n - 1, j))];
        for (var i = 0; i < n; ++i) {
            smoothPoints[i] = sum / count;
            var outgoing = Math.max(0, Math.min(n - 1, i - smoothWindow));
            var incoming = Math.max(0, Math.min(n - 1, i + smoothWindow + 1));
            sum += points[incoming] - points[outgoing];
        }
        if (!root.live) smoothPoints.fill(0);

        ctx.beginPath();
        ctx.moveTo(0, h);
        for (var i = 0; i < n; ++i) {
            var x = i * w / (n - 1);
            var y = h - (smoothPoints[i] / maxVal) * h * 0.9;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.fillOpacity);
        ctx.fill();
    }

    layer.enabled: root.visible && Appearance.effectsEnabled
    layer.effect: MultiEffect {
        source: root
        saturation: 0.2
        blurEnabled: Appearance.effectsEnabled
        blurMax: 7
        blur: Appearance.effectsEnabled ? 1 : 0
    }
}
