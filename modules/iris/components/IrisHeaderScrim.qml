import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

Rectangle {
    id: root

    property bool hangs: false
    property real solidTop: 0
    property real navBand: 0
    property bool topJoin: false
    property real joinDepth: 0
    property real unit: IrisStyle.density
    property real meltTop: 1
    property real meltFade: 1
    property real meltVeil: 1

    readonly property real edge: root.hangs ? root.solidTop / Math.max(1, root.height) : 0
    readonly property real topFade: root.hangs ? (root.solidTop + 30 * root.unit + root.navBand * 0.5) / Math.max(1, root.height) : 0.001
    readonly property real topAlpha: 0.12 * root.meltVeil // iris-literal: hero fade ramp
    readonly property real midAlpha: IrisStyle.wallpaperVeil * root.meltVeil
    readonly property real midAt: Math.min(0.8, 0.42 + (1 - root.meltFade) * 0.38)
    readonly property real solidAlpha: root.topAlpha
    readonly property real shoulderEnd: root.topJoin ? Math.min(0.6, root.joinDepth / Math.max(1, root.height)) : 0
    readonly property real solidEnd: root.shoulderEnd + (root.edge - root.shoulderEnd) * root.meltTop
    readonly property real joinRamp: root.topJoin ? Math.min(0.9, root.shoulderEnd / 0.45) : 0.001
    readonly property real rampEnd: Math.max(root.solidEnd + 0.001, root.joinRamp + (root.topFade - root.joinRamp) * root.meltTop)
    readonly property real maskSolidEnd: root.hangs ? root.solidEnd : 0
    readonly property real maskRampEnd: root.hangs ? root.rampEnd : 0.001 + 0.08 * root.meltTop

    gradient: Gradient {
        GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, root.solidAlpha) }
        GradientStop { position: root.solidEnd; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, root.solidAlpha) }
        GradientStop { position: root.rampEnd; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, root.topAlpha) }
        GradientStop { position: root.midAt; color: ColorUtils.applyAlpha(IrisStyle.surfaceOpaque, root.midAlpha) }
        GradientStop { position: 1; color: IrisStyle.bodyScrim }
    }
}
