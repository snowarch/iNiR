pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import qs.services.deferred

// The player boundary plays the same role as the artwork boundary in the
// standalone Organic Visualizer. The shared Organic field starts at that radius;
// the player itself is drawn above it and occludes everything inside.
Item {
    id: root

    property var visualizerPoints: []
    property bool active: false
    property bool audioActive: false
    property color playerColor: Appearance.colors.colPrimary
    property real cardRadius: 0
    property var albumPalette: []
    property var accentPalette: []
    readonly property var silentPoints: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    readonly property real reachAmount: Config.getNestedValue(
        "background.widgets.mediaControls.organicReach", 35) / 100
    readonly property string paletteMode: Config.getNestedValue(
        "background.widgets.mediaControls.visualizerPaletteMode", "cava")
    readonly property color playerHighlight: ColorUtils.mix(
        root.playerColor, Appearance.colors.colOnLayer0, 0.28)
    readonly property color playerDepth: ColorUtils.mix(
        root.playerColor, Appearance.colors.colLayer0, 0.34)
    readonly property var palette: root.paletteMode === "player"
        ? (root.albumPalette.length > 0
            ? root.albumPalette
            : [root.playerHighlight, root.playerColor, root.playerDepth])
        : root.paletteMode === "accent"
            ? (root.accentPalette.length > 0
                ? root.accentPalette
                : [root.playerHighlight, root.playerColor, root.playerDepth])
            : CavaTheme.visualizerColors
    readonly property color primaryVisualColor: root.palette.length > 0
        ? root.palette[0] : root.playerColor

    // Active Reach controls both available excursion and how much of Organic's
    // resting body is exposed, matching the standalone artwork/blob relation.
    // Paused Media retreats under the card so it never becomes a static border.
    readonly property real normalizedReach: Math.max(0, Math.min(1,
        (root.reachAmount - 0.2) / 1.2))
    property real edgeBaseRadius: root.audioActive
        ? (0.49 - root.normalizedReach * 0.11) : 0.555
    Behavior on edgeBaseRadius {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.calcEffectiveDuration(260)
            easing.type: Easing.OutCubic
        }
    }

    readonly property real baseSpan: Math.min(root.width, Math.min(root.height, 220))
    readonly property real reach: Math.max(18, Math.min(132,
        root.baseSpan * (0.08 + Math.max(0.2, Math.min(1.4, root.reachAmount)) * 0.54)))
    // User-facing Reach controls visible excursion. Keep a separate transparent
    // render margin so deformation/glow can decay before hitting texture bounds.
    readonly property real geometryMargin: root.reach * 1.08
    readonly property real mediaGlow: Config.getNestedValue(
        "background.widgets.mediaControls.organicGlow", 100) / 100
    readonly property real renderPadding: Math.max(52,
        root.reach * (0.82 + Math.max(0, Math.min(1, root.mediaGlow)) * 0.55))
    readonly property real renderMargin: root.geometryMargin + root.renderPadding
    visible: root.active

    Item {
        id: field
        x: -root.renderMargin
        y: -root.renderMargin
        width: root.width + root.renderMargin * 2
        height: root.height + root.renderMargin * 2

        AudioVisualizerLayer {
            anchors.fill: parent
            // Keep Organic alive for idle motion while letting the audio envelope
            // decay instead of freezing the last Cava frame when playback pauses.
            points: root.audioActive ? root.visualizerPoints : root.silentPoints
            active: root.active
            visualizerType: "organic"
            normalizationCeiling: CavaService.normalizationCeiling
            spectrumColors: root.palette
            spectrumColor: root.primaryVisualColor

            // Same renderer as the standalone Visualizer, but with an independent
            // response profile so tuning Media never mutates the Visualizer widget.
            smoothing: Config.getNestedValue("background.widgets.mediaControls.visualizerSmoothing", 2)
            frequencyProfile: Config.getNestedValue(
                "background.widgets.mediaControls.visualizerFrequencyProfile", "flat")
            accentStrength: Config.getNestedValue(
                "background.widgets.mediaControls.visualizerAccentStrength", 70) / 100
            fillRatio: Config.getNestedValue(
                "background.widgets.mediaControls.organicRange", 20) / 100
            organicSensitivity: Config.getNestedValue(
                "background.widgets.mediaControls.organicSensitivity", 35) / 100
            organicPulse: Config.getNestedValue(
                "background.widgets.mediaControls.organicPulse", 150) / 100
            organicCompression: Config.getNestedValue(
                "background.widgets.mediaControls.organicCompression", 0) / 100
            organicMotionSpeed: Config.getNestedValue(
                "background.widgets.mediaControls.organicMotionSpeed", 250) / 100
            organicIdleMotion: Config.getNestedValue(
                "background.widgets.mediaControls.organicIdleMotion", 40) / 100
            organicGlow: root.mediaGlow
            organicOpacity: Config.getNestedValue(
                "background.widgets.mediaControls.organicOpacity", 100) / 100

            organicOverscan: 1.0
            organicPresentationScale: 1.0
            organicPresentationMode: 2.0
            organicStretchToHost: true
            organicHollowAmount: 0.0
            organicEdgeBaseRadius: root.edgeBaseRadius
            organicEdgeCardHalf: Qt.vector2d(
                root.width / Math.max(1, field.width),
                root.height / Math.max(1, field.height))
            organicEdgeReachHalf: Qt.vector2d(
                (root.width + root.geometryMargin * 2) / Math.max(1, field.width),
                (root.height + root.geometryMargin * 2) / Math.max(1, field.height))
            organicEdgeCornerRadius: root.cardRadius * 2 / Math.max(1, field.height)
            organicEdgeDirections: Qt.vector4d(1, 1, 1, 1)
        }
    }
}
