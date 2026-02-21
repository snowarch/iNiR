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
    property int duration: 3000
    property bool playing: progress > 0 && progress < 1.0

    function spawn(x, y) {
        if (x !== undefined && y !== undefined) {
            // Use provided coordinates (assumed screen-global or relative to window)
            // To be safe, we map them to 0.0 - 1.0 range
            centerX = x / width
            centerY = y / height
        } else {
            // Default to center
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
        property real progress: root.progress
        property point center: Qt.point(root.centerX, root.centerY)
        property real aspect: width / height

        fragmentShader: "AndroidSparkle.qsb"
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
