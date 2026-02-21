import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Item {
    id: root
    property color color: Appearance.colors.colPrimary
    property real progress: 0
    property real centerX: 0.5
    property real centerY: 0.5
    property int duration: Config.options?.background?.effects?.ripple?.rippleDuration ?? 3000
    property bool playing: progress > 0 && progress < 1.0

    // Calculate maximum possible distance from the spawn point to any corner
    // to normalize expansion speed.
    readonly property real maxDistance: {
        if (width === 0 || height === 0) return 1.0;
        const aspect = width / height;
        const dx0 = centerX * aspect;
        const dx1 = (1 - centerX) * aspect;
        const dy0 = centerY;
        const dy1 = (1 - centerY);
        
        // Distances to 4 corners in aspect-corrected UV space
        const d1 = Math.sqrt(dx0*dx0 + dy0*dy0);
        const d2 = Math.sqrt(dx1*dx1 + dy0*dy0);
        const d3 = Math.sqrt(dx0*dx0 + dy1*dy1);
        const d4 = Math.sqrt(dx1*dx1 + dy1*dy1);
        
        return Math.max(d1, d2, d3, d4);
    }

    function spawn(x, y) {
        if (x !== undefined && y !== undefined) {
            centerX = x / width
            centerY = y / height
        } else {
            centerX = 0.5
            centerY = 0.5
        }
        anim.restart()
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        visible: root.playing
        
        property color color: root.color
        // The shader has a hardcoded multiplier of 2.5 for progress.
        // We scale our 0-1 progress so that (progress * multiplier) reaches maxDistance at progress=1.
        property real progress: root.progress * (root.maxDistance / 2.5)
        property point center: Qt.point(root.centerX, root.centerY)
        property real aspect: width / height

        fragmentShader: "FluidRipple.qsb"
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1.0
        duration: root.duration
        easing.type: Easing.OutCubic
        onFinished: root.progress = 0
    }
}
