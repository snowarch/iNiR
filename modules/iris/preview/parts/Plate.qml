pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.iris.style
import qs.modules.iris.components

Rectangle {
    id: plate
    property string surface: ""
    property int fallbackRadius: IrisStyle.radiusSheet
    property color own: IrisStyle.accent
    readonly property color light: IrisStyle.surfaceLight(plate.surface, plate.own)
    radius: IrisStyle.surfaceRadius(plate.surface, plate.fallbackRadius)
    color: IrisStyle.bodySurface
    border.width: IrisStyle.rim.a > 0 ? 1 : 0
    border.color: IrisStyle.rim
    // A chamfered Design (AIRISU) cuts the body by its die, so a preview wears the same 45° corners as the shell.
    layer.enabled: IrisStyle.fieldChamfer
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: die
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
    IrisCutPlate {
        id: die
        anchors.fill: parent
        visible: false
        layer.enabled: IrisStyle.fieldChamfer
        cutLength: Math.max(2, Math.min(IrisStyle.chamferCut, Math.round(Math.min(width, height) / 4)))
        color: "white" // iris-literal: a mask, never shown
    }
    IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
    IrisLightWash {
        anchors.fill: parent
        radius: plate.radius
        light: plate.light
    }
}
