pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services
import qs.services.deferred

// Shared presentation layer for iNiR's internal Cava consumers.
// CavaService owns audio acquisition; this item owns only rendering/response.
Item {
    id: root

    property var points: []
    property bool active: false
    property string visualizerType: "wave" // wave | bars | organic
    property real normalizationCeiling: CavaService.normalizationCeiling
    property var spectrumColors: CavaTheme.visualizerColors
    property color spectrumColor: CavaTheme.primaryColor
    property real spectrumOpacity: 0.45
    property int smoothing: 2
    property string frequencyProfile: "flat"
    property real accentStrength: 0.7
    property real fillRatio: 0.9

    property int barCount: 32
    property real barSpacing: 2
    property real barRadius: 2
    property real barMinHeight: 1
    property string barsOrigin: "mirror"
    property string waveMode: "fill"
    property real lineWidth: 2
    property real edgeInset: 0
    property real edgeSoftness: 0.28

    property real organicSensitivity: 0.75
    property real organicPulse: 0.72
    property real organicCompression: 0.0
    property real organicMotionSpeed: 1.0
    property real organicIdleMotion: 0.16
    property real organicGlow: 0.45
    property real organicOpacity: 0.85
    property real organicOverscan: 1.34
    property real organicPresentationScale: 1.0
    property real organicBaseRadius: 0.510
    property real organicPresentationMode: 0.0
    property real organicHollowAmount: 1.0
    property bool organicStretchToHost: false
    property real organicEdgeBaseRadius: 0.39
    property vector2d organicEdgeCardHalf: Qt.vector2d(0.72, 0.58)
    property vector2d organicEdgeReachHalf: organicEdgeCardHalf
    property real organicEdgeCornerRadius: 0.12
    property vector4d organicEdgeReachScales: Qt.vector4d(1, 1, 1, 1)
    property vector4d organicEdgeDirections: Qt.vector4d(1, 1, 1, 1)

    CavaSpectrum {
        anchors.fill: parent
        visible: root.visualizerType !== "organic"
        points: root.points
        active: root.active
        threadedRendering: true
        visualizerType: root.visualizerType
        normalizationCeiling: root.normalizationCeiling
        spectrumColors: root.spectrumColors
        spectrumColor: root.spectrumColor
        spectrumOpacity: root.spectrumOpacity
        fillRatio: root.fillRatio
        pixelsPerBar: Math.max(3, (width + root.barSpacing) / Math.max(4, root.barCount))
        barSpacing: root.barSpacing
        barMinHeight: root.barMinHeight
        barRadius: root.barRadius
        barsOrigin: root.barsOrigin
        smoothing: root.smoothing
        waveMode: root.waveMode
        lineWidth: root.lineWidth
        edgeInset: root.edgeInset
        edgeSoftness: root.edgeSoftness
        frequencyProfile: root.frequencyProfile
        accentStrength: root.accentStrength
        mirroredStereo: Config.options?.appearance?.cava?.stereo ?? true
    }

    OrganicAudioBlob {
        anchors.fill: parent
        visible: root.visualizerType === "organic"
        active: root.active
        points: root.points
        normalizationCeiling: root.normalizationCeiling
        primaryColor: root.spectrumColors?.length > 0
            ? root.spectrumColors[0] : root.spectrumColor
        secondaryColor: root.spectrumColors?.length > 1
            ? root.spectrumColors[Math.floor((root.spectrumColors.length - 1) / 2)]
            : primaryColor
        tertiaryColor: root.spectrumColors?.length > 2
            ? root.spectrumColors[root.spectrumColors.length - 1]
            : secondaryColor
        smoothing: root.smoothing
        frequencyProfile: root.frequencyProfile
        accentStrength: root.accentStrength
        mirroredStereo: Config.options?.appearance?.cava?.stereo ?? true
        sensitivity: root.organicSensitivity
        amplitude: root.fillRatio
        pulseStrength: root.organicPulse
        compression: root.organicCompression
        motionSpeed: root.organicMotionSpeed
        idleMotion: root.organicIdleMotion
        glowStrength: root.organicGlow
        overscan: root.organicOverscan
        presentationScale: root.organicPresentationScale
        baseRadius: root.organicBaseRadius
        presentationMode: root.organicPresentationMode
        stretchToHost: root.organicStretchToHost
        hollowAmount: root.organicHollowAmount
        edgeBaseRadius: root.organicEdgeBaseRadius
        edgeCardHalf: root.organicEdgeCardHalf
        edgeReachHalf: root.organicEdgeReachHalf
        edgeCornerRadius: root.organicEdgeCornerRadius
        edgeReachScales: root.organicEdgeReachScales
        edgeDirections: root.organicEdgeDirections
        opacity: root.organicOpacity
    }
}
