pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred

// Media-specific host for the shared audio renderers. Wave/Bars are edge
// surfaces; Organic is an ambient layer. They intentionally do not share
// geometry because their visual contracts are different.
Item {
    id: root

    property var visualizerPoints: []
    property bool active: false
    property color playerColor: Appearance.colors.colPrimary
    property real edgeHeight: 35

    readonly property string visualizerType: Config.getNestedValue(
        "background.widgets.mediaControls.visualizerType", "wave")
    readonly property string visualizerPosition: Config.getNestedValue(
        "background.widgets.mediaControls.visualizerPosition", "bottom")
    readonly property string paletteMode: Config.getNestedValue(
        "background.widgets.mediaControls.visualizerPaletteMode", "cava")
    readonly property bool organic: root.visualizerType === "organic"
    readonly property var palette: root.paletteMode === "player" || root.paletteMode === "accent"
        ? [root.playerColor] : CavaTheme.visualizerColors
    readonly property color primaryVisualColor: root.palette.length > 0
        ? root.palette[0] : root.playerColor

    visible: root.visualizerPosition !== "none" && !root.organic

    // Wave and Bars keep the old Media Player contract: the surface touches
    // the requested card edge. No inset/margin is allowed here.
    Item {
        id: spectrumViewport
        visible: !root.organic
        x: 0
        width: root.width
        y: root.visualizerPosition === "top" ? 0
            : root.visualizerPosition === "fill" ? 0
            : Math.max(0, root.height - height)
        height: root.visualizerPosition === "fill"
            ? root.height : Math.min(root.height, root.edgeHeight)
        clip: true

        AudioVisualizerLayer {
            anchors.fill: parent
            points: root.visualizerPoints
            active: root.active
            visualizerType: root.visualizerType
            normalizationCeiling: CavaService.normalizationCeiling
            spectrumColors: root.palette
            spectrumColor: root.primaryVisualColor
            spectrumOpacity: root.visualizerType === "wave"
                ? Config.getNestedValue("background.widgets.mediaControls.visualizerOpacity",
                    Config.options?.appearance?.cava?.waveOpacity ?? 30) / 100
                : Config.getNestedValue("background.widgets.mediaControls.visualizerOpacity", 55) / 100
            smoothing: Config.getNestedValue("background.widgets.mediaControls.visualizerSmoothing", 2)
            frequencyProfile: Config.getNestedValue(
                "background.widgets.mediaControls.visualizerFrequencyProfile", "flat")
            accentStrength: Config.getNestedValue(
                "background.widgets.mediaControls.visualizerAccentStrength", 70) / 100
            fillRatio: Config.getNestedValue(
                "background.widgets.mediaControls.visualizerRange", 88) / 100
            barCount: Config.getNestedValue("background.widgets.mediaControls.visualizerBarCount", 32)
            barSpacing: 2
            barRadius: 2
            barMinHeight: 1
            // Edge modes must originate at the edge. Fill is the intentional
            // centered/mirrored presentation.
            barsOrigin: root.visualizerPosition === "top" ? "top"
                : root.visualizerPosition === "fill" ? "mirror" : "bottom"
            waveMode: "fill"
        }
    }
}
