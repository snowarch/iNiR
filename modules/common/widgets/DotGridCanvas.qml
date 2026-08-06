pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common

// Engineering dot grid — the visual language of the desktop-widget edit mode
// (Background.qml editGridOverlay): accent dots at grid intersections, quiet
// enough to read as a drafting surface rather than a pattern. Reuse it wherever
// a surface means "layout/editing space" so edit contexts share one look.
Canvas {
    id: root

    property int gridSize: 32
    property real dotRadius: 1.4
    property real dotAlpha: 0.10
    property color dotColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.colors.colPrimary

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (width <= 0 || height <= 0)
            return;
        const gs = root.gridSize;
        ctx.fillStyle = Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, root.dotAlpha);
        const cols = Math.floor(width / gs) + 1;
        const rows = Math.floor(height / gs) + 1;
        for (let r = 0; r < rows; ++r) {
            for (let c = 0; c < cols; ++c) {
                ctx.beginPath();
                ctx.arc(c * gs, r * gs, root.dotRadius, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }
    onWidthChanged: if (available) requestPaint()
    onHeightChanged: if (available) requestPaint()
    onDotColorChanged: if (available) requestPaint()
    onVisibleChanged: if (visible && available) requestPaint()
    Component.onCompleted: requestPaint()
}
