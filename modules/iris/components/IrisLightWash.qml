pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

Item {
    id: root

    property color light: "transparent"
    property string from: "top"
    property real presence: 1
    // Corner of its own: 0 inside a clip, where rounding it again dims it a pixel early on every curve and leaves a dark rim.
    property real radius: 0
    // How far it reaches is measured from the body's corner, clipped or not.
    property real shapeRadius: root.radius
    readonly property bool across: root.from === "left" || root.from === "right"
    readonly property bool reversed: root.from === "bottom" || root.from === "right"
    readonly property real extent: Math.max(1, root.across ? root.width : root.height)
    readonly property real fall: Math.min(0.7, Math.max(0.12, Math.max(IrisStyle.lightReach, 1.5 * root.shapeRadius) / root.extent))

    visible: IrisStyle.auraStrength > 0 && root.light.a > 0
    opacity: root.presence * Math.min(1, IrisStyle.tweak("lightReach", 0.5, 3))

    // A shader rather than a Rectangle gradient: the same three stops, dithered, so the long faint ramp does not band.
    ShaderEffect {
        anchors.fill: parent
        blending: true
        fragmentShader: Qt.resolvedUrl("IrisLightWash.frag.qsb")
        readonly property color strong: IrisStyle.aura(root.light)
        readonly property color fading: IrisStyle.auraFading(root.light)
        readonly property vector4d ramp: Qt.vector4d(root.fall * 0.45, root.fall, root.across ? 1 : 0, root.reversed ? 1 : 0)
        readonly property vector4d box: Qt.vector4d(Math.max(1, width), Math.max(1, height), root.radius, 0)
    }
}
