pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property Item pillItem: null
    property bool active: false
    property var points: []
    property real normalizationCeiling: 1000
    property real s: 1
    property bool presented: false

    visible: root.presented || root.opacity > 0.001
    opacity: root.presented ? 1 : 0

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.calcEffectiveDuration(root.presented ? 180 : 460)
            easing.type: root.presented ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    function _reconcilePresentation(): void {
        if (root.active) {
            presentationHold.stop()
            root.presented = true
        } else if (root.presented) {
            presentationHold.restart()
        }
    }

    onActiveChanged: root._reconcilePresentation()
    Component.onCompleted: root._reconcilePresentation()

    Timer {
        id: presentationHold
        interval: 700
        repeat: false
        onTriggered: if (!root.active) root.presented = false
    }

    readonly property real wingLength: Math.max(60,
        Config.options?.bar?.visualizer?.pillWingLength ?? 180) * root.s
    readonly property real wingGap: Math.max(0,
        Config.options?.bar?.visualizer?.pillWingGap ?? 12) * root.s
    readonly property string wingMode: {
        const configured = Config.options?.bar?.visualizer?.pillWingMode ?? "bounded"
        return ["bounded", "screen", "bleed"].includes(configured) ? configured : "bounded"
    }
    readonly property real screenPadding: Math.max(0,
        Config.options?.bar?.visualizer?.pillScreenPadding ?? 24) * root.s
    readonly property real underlap: Math.max(0,
        Config.options?.bar?.visualizer?.pillUnderlap ?? 28) * root.s
    readonly property real effectiveUnderlap: Math.min(root.underlap,
        Math.max(0, (root.pillItem?.width ?? 0) / 2))
    readonly property real outerOpacity: 1 - Math.max(0, Math.min(100,
        Config.options?.bar?.visualizer?.pillEdgeFade ?? 92)) / 100
    readonly property real wingHeight: Math.max(24 * root.s,
        Math.min(58 * root.s, root.pillItem?.height ?? 38 * root.s))
    readonly property string visualizerType: Config.options?.bar?.visualizer?.type ?? "bars"
    readonly property string barsOrigin: Config.options?.bar?.visualizer?.barsOrigin ?? "mirror"
    readonly property real density: Math.max(4,
        Config.options?.bar?.visualizer?.density ?? 12) * root.s
    readonly property real gap: Math.max(0,
        Config.options?.bar?.visualizer?.gap ?? 2) * root.s
    readonly property int smoothing: Math.max(0,
        Config.options?.bar?.visualizer?.smoothing ?? 2)
    readonly property string waveMode: Config.options?.bar?.visualizer?.waveMode ?? "ribbon"
    readonly property real lineWidth: Math.max(1,
        Config.options?.bar?.visualizer?.lineWidth ?? 2) * root.s
    readonly property real edgeInset: Math.max(6,
        Config.options?.bar?.visualizer?.edgeInset ?? 6) * root.s
    readonly property real fillRatio: Math.max(0.1,
        Math.min(1, Config.options?.bar?.visualizer?.height ?? 0.6))
    readonly property real spectrumOpacity: Math.max(0,
        Math.min(1, Config.options?.bar?.visualizer?.opacity ?? 0.35))
    readonly property real edgeSoftness: Math.max(0,
        Math.min(1, (Config.options?.bar?.visualizer?.edgeSoftness ?? 36) / 100))
    readonly property string frequencyProfile: Config.options?.bar?.visualizer?.frequencyProfile ?? "flat"
    readonly property real accentStrength: Math.max(0,
        Math.min(1, (Config.options?.bar?.visualizer?.accentStrength ?? 70) / 100))
    readonly property string organicFit: Config.options?.bar?.visualizer?.organicFit ?? "auto"
    readonly property real organicFitScale: organicFit === "aura" ? 1
        : organicFit === "contained" ? 0.72 : 0.82
    readonly property real organicSensitivity: Math.max(0, Math.min(1,
        (Config.options?.bar?.visualizer?.organicSensitivity ?? 42) / 100)) * organicFitScale
    readonly property real organicPulse: Math.max(0, Math.min(1,
        (Config.options?.bar?.visualizer?.organicPulse ?? 55) / 100)) * organicFitScale
    readonly property real organicMotionSpeed: Math.max(0.25, Math.min(1.5,
        (Config.options?.bar?.visualizer?.organicMotionSpeed ?? 80) / 100))
    readonly property real organicIdleMotion: Math.max(0, Math.min(1,
        (Config.options?.bar?.visualizer?.organicIdleMotion ?? 0) / 100))
    readonly property real organicGlow: Math.max(0, Math.min(1,
        (Config.options?.bar?.visualizer?.organicGlow ?? 25) / 100)) * organicFitScale
    readonly property real organicBaseRadius: Math.max(0, Math.min(1,
        (Config.options?.bar?.visualizer?.organicBaseRadius ?? 36) / 100))
    readonly property real outerTaper: Math.max(24 * root.s,
        Math.min(96 * root.s, root.wingHeight * (1.35 + root.edgeSoftness)))

    readonly property real leftOuter: root.wingMode === "bounded"
        ? Math.max(0, (root.pillItem?.x ?? 0) - root.wingGap - root.wingLength)
        : Math.min(root.width / 2, root.screenPadding)
    readonly property real leftInner: root.wingMode === "bleed"
        ? Math.min(root.width, (root.pillItem?.x ?? 0) + root.effectiveUnderlap)
        : Math.max(0, (root.pillItem?.x ?? 0) - root.wingGap)
    readonly property real rightInner: root.wingMode === "bleed"
        ? Math.max(0, (root.pillItem?.x ?? 0) + (root.pillItem?.width ?? 0) - root.effectiveUnderlap)
        : Math.min(root.width, (root.pillItem?.x ?? 0) + (root.pillItem?.width ?? 0) + root.wingGap)
    readonly property real rightOuter: root.wingMode === "bounded"
        ? Math.min(root.width, root.rightInner + root.wingLength)
        : Math.max(root.width / 2, root.width - root.screenPadding)
    readonly property real leftWidth: Math.max(0, root.leftInner - root.leftOuter)
    readonly property real rightWidth: Math.max(0, root.rightOuter - root.rightInner)
    readonly property real requestedSpan: root.wingMode === "bounded"
        ? root.wingLength * 2
        : Math.max(0, root.width - root.screenPadding * 2)
    readonly property int requestedSampleCount: Math.max(50,
        Math.round(root.requestedSpan / Math.max(4, root.density)))

    component Wing: AudioVisualizerLayer {
        y: root.pillItem
            ? root.pillItem.y + (root.pillItem.height - root.wingHeight) / 2 : 0
        height: root.wingHeight
        active: root.visible && width > 4 && root.visualizerType !== "organic"
        threadedRendering: true
        points: active ? root.points : []
        normalizationCeiling: active ? root.normalizationCeiling : 100
        visualizerType: root.visualizerType
        barsOrigin: root.barsOrigin
        pixelsPerBar: root.density
        barSpacing: root.gap
        barRadius: Math.max(1, 2 * root.s)
        barMinHeight: Math.max(1, root.s)
        smoothing: root.smoothing
        waveMode: root.waveMode
        lineWidth: root.lineWidth
        edgeInset: root.edgeInset
        fillRatio: root.fillRatio
        spectrumOpacity: root.spectrumOpacity
        spectrumColor: PillTheme.vermLit
        edgeSoftness: root.edgeSoftness
        frequencyProfile: root.frequencyProfile
        accentStrength: root.accentStrength
    }

    AudioVisualizerLayer {
        id: organicPillAura
        x: root.pillItem?.x ?? 0
        y: root.pillItem?.y ?? 0
        width: root.pillItem?.width ?? 0
        height: root.pillItem?.height ?? 0
        active: root.visible && root.visualizerType === "organic"
            && width > 4 && height > 4
        points: active ? root.points : []
        normalizationCeiling: active ? root.normalizationCeiling : 100
        visualizerType: "organic"
        spectrumColor: PillTheme.vermLit
        spectrumOpacity: root.spectrumOpacity
        fillRatio: root.fillRatio
        smoothing: root.smoothing
        frequencyProfile: root.frequencyProfile
        accentStrength: root.accentStrength
        organicSensitivity: root.organicSensitivity
        organicPulse: root.organicPulse
        organicMotionSpeed: root.organicMotionSpeed
        organicIdleMotion: root.organicIdleMotion
        organicGlow: root.organicGlow
        organicOpacity: root.spectrumOpacity
        organicEdgeAura: root.organicFit !== "contained"
        organicEdgeReach: Math.max(18 * root.s,
            Math.min(root.wingLength * 0.34, 58 * root.s))
        organicBaseRadius: root.organicBaseRadius
        topLeftRadius: height / 2
        topRightRadius: height / 2
        bottomLeftRadius: height / 2
        bottomRightRadius: height / 2
    }

    Wing {
        id: leftWing
        x: root.leftOuter
        width: root.leftWidth
        reverseFrequency: true
        sampleStartRatio: 0
        sampleEndRatio: 1
        startOpacity: root.outerOpacity
        endOpacity: 1
        startTaper: root.outerTaper
        endTaper: 0
    }

    Wing {
        id: rightWing
        x: root.rightInner
        width: root.rightWidth
        sampleStartRatio: 0
        sampleEndRatio: 1
        startOpacity: 1
        endOpacity: root.outerOpacity
        startTaper: 0
        endTaper: root.outerTaper
    }
}
