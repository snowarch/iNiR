pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common.functions
import qs.modules.iris.style

Item {
    id: root
    property string source: ""
    property real radius: 0
    property real strength: 0.62
    property real edgeTop: 0
    property real edgeBottom: 0

    readonly property real overscan: 48

    Image {
        id: cover
        anchors.fill: parent
        anchors.margins: -root.overscan
        source: root.source
        sourceSize: Qt.size(160, 160)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    Item {
        id: composed
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        MultiEffect {
            anchors.fill: parent
            anchors.margins: -root.overscan
            source: cover
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            opacity: root.strength
            visible: cover.status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: IrisStyle.veil }
                GradientStop { position: 1; color: IrisStyle.veilHeavy }
            }
        }
        Rectangle {
            visible: root.edgeTop > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.edgeTop
            gradient: Gradient {
                GradientStop { position: 0; color: IrisStyle.bodyScrim }
                GradientStop { position: 0.45; color: IrisStyle.bodyScrim }
                GradientStop { position: 1; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, 0) }
            }
        }
        Rectangle {
            visible: root.edgeBottom > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.edgeBottom
            gradient: Gradient {
                GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, 0) }
                GradientStop { position: 0.55; color: IrisStyle.bodyScrim }
                GradientStop { position: 1; color: IrisStyle.bodyScrim }
            }
        }
    }
    // Hidden layered mask child: an inline ShaderEffectSource crashed Qt on window unload.
    Item {
        id: roundMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.radius > 0
        Rectangle {
            anchors.fill: parent
            radius: root.radius
        }
    }
}
