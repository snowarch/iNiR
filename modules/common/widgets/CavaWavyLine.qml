import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Canvas {
    id: root
    property list<var> points // Input from Cava
    property color color: Appearance.m3colors.m3primary
    property real lineWidth: 3
    property real amplitudeScale: 1.0

    // Animation loop to drive the wave phase even if cava points are static (though cava is usually live)
    property real phase: 0
    
    // Smoothed points for nicer curve
    property var smoothPoints: []
    property int smoothing: 2

    onPointsChanged: root.requestPaint()
    
    // Timer for continuous animation if needed (e.g. for phase shift)
    Timer {
        interval: 32 // ~30fps
        running: parent.visible
        repeat: true
        onTriggered: {
            root.phase += 0.1
            root.requestPaint()
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var points = root.points;
        var n = points.length;
        // Fallback to sine wave if no cava points or player paused
        if (n < 2) {
            // Draw a flat line or simple sine if we want "alive" look when silent
            // For now, draw flat line
            ctx.beginPath();
            ctx.moveTo(0, height / 2);
            ctx.lineTo(width, height / 2);
            ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.3);
            ctx.lineWidth = 1;
            ctx.stroke();
            return;
        }

        // Smoothing
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

        ctx.beginPath();
        var centerY = height / 2;
        var maxVal = 1000.0; // Cava max value usually
        
        // Draw Catmull-Rom spline or simple line through points
        // Mapped to width
        
        ctx.moveTo(0, centerY); // Start at left center
        
        for (var i = 0; i < n; ++i) {
            var x = (i / (n - 1)) * width;
            // Map magnitude to amplitude (up and down from center)
            // Use phase to make it wave-like even with static magnitude
            // But cava gives magnitude. Let's just map magnitude to Y offset.
            
            var magnitude = (root.smoothPoints[i] / maxVal) * (height / 2) * root.amplitudeScale;
            // Alternating up/down for wave effect? 
            // Cava gives positive magnitudes.
            // Let's multiply by sin(x + phase) to make it look like a wave that is shaped by cava magnitude
            
            var waveCarrier = Math.sin(i * 0.5 + root.phase); 
            var y = centerY + magnitude * waveCarrier * 3; // *3 for visibility
            
            ctx.lineTo(x, y);
        }
        
        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
