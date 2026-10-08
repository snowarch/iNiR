pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common.functions
import qs.modules.iris.style

// Native borders keep the curve antialiased; the light is faded downward by a smooth vertical mask, never a
// ring mask (that pixelated every corner).
Item {
    id: root
    property real radius: 0
    readonly property real lineWidth: Math.max(1, Math.round(IrisStyle.glassEdgeWidth * IrisStyle.density))
    readonly property bool shown: IrisStyle.glassEdgeLight > 0 || IrisStyle.glassEdgeLine > 0
    visible: root.shown

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: IrisStyle.glassEdgeLine > 0 ? root.lineWidth : 0
        border.color: ColorUtils.applyAlpha(IrisStyle.glassEdgeColour, IrisStyle.glassEdgeLine)
    }

    Rectangle {
        anchors.fill: parent
        visible: IrisStyle.glassEdgeLight > IrisStyle.glassEdgeLine
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.lineWidth
        border.color: ColorUtils.applyAlpha(IrisStyle.glassEdgeColour, IrisStyle.glassEdgeLight)
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: litFade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Rectangle {
        id: litFade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }
}
