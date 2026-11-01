pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"

    // Under an iRiS Design that prints this widget (AIRISU), the print is its face; elsewhere it draws itself.
    printPart: "widgetVisualizer"
    printKey: "visualizer"
    // What a print reads: the spectrum, whether it is moving, and its ceiling.
    readonly property var printPoints: cavaProcess.points
    readonly property bool printLive: root._active && cavaProcess.audioSignalActive

    visibleWhenLocked: false
    needsColText: true
    resizeMinWidth: 120
    resizeMinHeight: 48

    readonly property string vizType: Config.getNestedValue("background.widgets.visualizer.vizType", "bars")
    readonly property int waveOpacity: Config.getNestedValue("background.widgets.visualizer.waveOpacity", -1)
    readonly property string paletteMode: Config.getNestedValue(
        "background.widgets.visualizer.paletteMode", "cava")
    // Album is artwork-owned, so the shared semantic palette editor is only
    // relevant for the widget semantic color modes.
    semanticPaletteQuickControls: root.paletteMode === "accent"
        || root.paletteMode === "primary"
    readonly property var spectrumPalette: {
        // iRiS draws its widgets from one solved palette; Cava's colours are Material's.
        if (root.paletteMode === "accent" || (root.familyDesign && root.paletteMode === "cava"))
            return [root.widgetAccentVisible, root.widgetAccent2Visible, root.widgetAccent3Visible]
        if (root.paletteMode === "primary")
            return [root.widgetAccent]
        if (root.paletteMode === "album") {
            const colors = albumArtworkQuantizer?.colors ?? []
            if (colors.length > 0)
                return colors
            return [root.widgetAccentVisible, root.widgetAccent2Visible, root.widgetAccent3Visible]
        }
        return CavaTheme.visualizerColors
    }
    readonly property int smoothing: Config.getNestedValue(
        "background.widgets.visualizer.smoothing", 2)
    readonly property string frequencyProfile: Config.getNestedValue(
        "background.widgets.visualizer.frequencyProfile", "flat")
    readonly property real accentStrength: Config.getNestedValue(
        "background.widgets.visualizer.accentStrength", 70) / 100
    readonly property real organicSensitivitySetting: Config.getNestedValue(
        "background.widgets.visualizer.organicSensitivity", 25) / 100
    // Keep the useful low end almost linear, then progressively compress the
    // upper half. The raw 25-200 slider used to multiply deformation linearly,
    // making 100-200 jump far more than the visual control implied.
    readonly property real organicSensitivity: root.organicSensitivitySetting <= 0.4
        ? root.organicSensitivitySetting
        : 0.4 + 0.85 * (1 - Math.exp(-(root.organicSensitivitySetting - 0.4) * 1.4))
    readonly property real organicPulse: Config.getNestedValue(
        "background.widgets.visualizer.organicPulse", 150) / 100
    readonly property real organicCompression: Config.getNestedValue(
        "background.widgets.visualizer.organicCompression", 0) / 100
    readonly property real organicMotionSpeed: Config.getNestedValue(
        "background.widgets.visualizer.organicMotionSpeed", 250) / 100
    readonly property real organicIdleMotion: Config.getNestedValue(
        "background.widgets.visualizer.organicIdleMotion", 18) / 100
    readonly property real organicOpacity: Config.getNestedValue(
        "background.widgets.visualizer.organicOpacity", 100) / 100
    readonly property real organicGlow: Config.getNestedValue(
        "background.widgets.visualizer.organicGlow", 100) / 100
    readonly property real organicCoverSize: Config.getNestedValue(
        "background.widgets.visualizer.organicCoverSize", 51) / 100
    readonly property real organicRange: Config.getNestedValue(
        "background.widgets.visualizer.organicRange", 20) / 100
    // The Organic texture renders larger than the widget so peaks have room.
    // Compensate that overscan when cutting the centre hole: the inner edge
    // should track the artwork itself, not an arbitrary shader-space radius.
    readonly property real organicRenderOverscan: 1.34
    // The original Organic kept roughly 0.075-0.08 radial units of body between
    // the artwork edge and the resting outer contour. Derive the resting radius
    // from the actual cover instead of letting a fixed blob radius make smaller
    // covers look disproportionately thick.
    readonly property real organicBaseRadius: Math.min(0.78,
        root.organicCoverSize / root.organicRenderOverscan + 0.078)
    // Let the Organic body continue underneath the artwork. Matching two
    // antialiased edges exactly leaves a wallpaper-colored seam; underlapping
    // the halo means the cover is always the visual owner of the centre edge.
    readonly property real organicCoverUnderlap: 0.055
    readonly property real organicHollowAmount: Math.max(0, Math.min(1,
        ((root.organicCoverSize - root.organicCoverUnderlap)
            / root.organicRenderOverscan) / 0.565))

    readonly property bool _active: root.visible
        && root.motionActive && MprisController.isPlaying
    readonly property MprisPlayer _activePlayer: MprisController.activePlayer
    readonly property bool _organicPresent: root.visible && root.powerActive
        && root.vizType === "organic" && root._activePlayer !== null
    readonly property string _activeArt: organicArtworkResolver.displaySource
    property string _organicDisplayedArt: ""
    property string _organicDisplayedArtIdentity: ""
    property string _organicPendingArt: ""
    property string _organicPendingArtIdentity: ""
    property real _organicReveal: 1
    readonly property var _organicSilentPoints: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    function _organicArtIdentity(source: string): string {
        const value = source ?? ""
        let marker = value.indexOf("?inir_art=")
        if (marker < 0)
            marker = value.indexOf("&inir_art=")
        return marker >= 0 ? value.slice(0, marker) : value
    }
    readonly property color _organicPrimary: {
        const palette = root.spectrumPalette ?? []
        return palette.length > 0 ? palette[0] : root.widgetAccentVisible
    }
    readonly property color _organicSecondary: {
        const palette = root.spectrumPalette ?? []
        if (palette.length > 2)
            return palette[Math.floor((palette.length - 1) / 2)]
        if (palette.length > 1)
            return palette[1]
        return root._organicPrimary
    }
    readonly property color _organicTertiary: {
        const palette = root.spectrumPalette ?? []
        if (palette.length > 2)
            return palette[palette.length - 1]
        return root._organicSecondary
    }

    MediaArtworkResolver {
        id: organicArtworkResolver
        sourceUrl: (root.vizType === "organic" || root.paletteMode === "album")
            ? MprisController.effectiveArtUrl(root._activePlayer) : ""
        title: MprisController.titleOf(root._activePlayer) ?? ""
        artist: MprisController.artistOf(root._activePlayer) ?? ""
        album: root._activePlayer?.trackAlbum ?? ""
    }

    ColorQuantizer {
        id: albumArtworkQuantizer
        source: root.paletteMode === "album" ? organicArtworkResolver.displaySource : ""
        depth: 2
        rescaleSize: 24
    }

    on_ActiveArtChanged: {
        const next = root._activeArt
        if (next.length === 0)
            return
        const identity = root._organicArtIdentity(next)
        if (root._organicDisplayedArt.length === 0) {
            root._organicDisplayedArt = next
            root._organicDisplayedArtIdentity = identity
            return
        }
        if (identity === root._organicDisplayedArtIdentity) {
            root._organicDisplayedArt = next
            return
        }
        if (organicArtTransition.running
                && identity === root._organicPendingArtIdentity) {
            root._organicPendingArt = next
            return
        }
        root._organicPendingArt = next
        root._organicPendingArtIdentity = identity
        organicArtTransition.restart()
    }

    SequentialAnimation {
        id: organicArtTransition
        NumberAnimation {
            target: root
            property: "_organicReveal"
            to: 0
            duration: Appearance.calcEffectiveDuration(170)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root._organicDisplayedArt = root._organicPendingArt
                root._organicDisplayedArtIdentity = root._organicPendingArtIdentity
            }
        }
        NumberAnimation {
            target: root
            property: "_organicReveal"
            to: 1
            duration: Appearance.calcEffectiveDuration(300)
            easing.type: Easing.OutBack
            easing.overshoot: 1.08
        }
    }

    // ── Style tokens ───────────────────────────────────────────
    readonly property real cardRadius: root.widgetCardRadius

    CavaProcess {
        id: cavaProcess
        active: root._active
        sampleCount: Math.max(50,
            Config.getNestedValue("background.widgets.visualizer.barCount", 48))
    }

    // ── Card background ────────────────────────────────────────
    WidgetSurface {
        visible: !root.familyFaced
        widget: root
        id: cardBg
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        shown: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // ── Visualizer rendering ─────────────────────────────────────
    // The field and the artwork on top of it move out together (LiveLayer): in their own surface, in their own
    // order, so a still widget does not repaint the whole desktop every frame. The card stays in the host, below.
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            LiveLayer {
                visible: !root.familyFaced
                anchors.fill: parent
                live: root.motionActive && (root.vizType === "organic"
                    ? root._organicPresent
                    : root._active && cavaProcess.audioSignalActive)
                content: vizContent
            }
        }
    }

    Component {
        id: vizContent
        Item {
            id: vizDrawn
            property bool drawing: false

            AudioVisualizerLayer {
                id: visualizerLayer
                anchors.fill: parent
                anchors.margins: root.look.clipInset
                points: root.vizType === "organic"
                    ? (root._active && cavaProcess.audioSignalActive
                        ? cavaProcess.points : root._organicSilentPoints)
                    : cavaProcess.points
                active: root.vizType === "organic"
                    ? root._organicPresent
                    : root._active && cavaProcess.audioSignalActive
                animate: root.motionActive && vizDrawn.drawing
                visualizerType: root.vizType
                normalizationCeiling: cavaProcess.normalizationCeiling
                spectrumColors: root.spectrumPalette
                spectrumColor: root.widgetAccentVisible
                spectrumOpacity: (root.vizType === "wave"
                    ? (root.waveOpacity >= 0 ? root.waveOpacity
                        : (Config.options?.appearance?.cava?.waveOpacity ?? 30))
                    : Config.getNestedValue("background.widgets.visualizer.barOpacity", 100)) / 100
                fillRatio: root.vizType === "organic" ? root.organicRange
                    : Config.getNestedValue("background.widgets.visualizer.fillRatio", 90) / 100
                barCount: Config.getNestedValue("background.widgets.visualizer.barCount", 48)
                // A visible plate rounds the box, so bars and waves take its corners; bare, they keep the full
                // rect, and organic keeps its halo overscan either way.
                readonly property real plateRadius: cardBg.shown && root.vizType !== "organic"
                    ? Math.max(0, cardBg.surfaceRadius - anchors.margins) : -1
                topLeftRadius: plateRadius
                topRightRadius: plateRadius
                bottomLeftRadius: plateRadius
                bottomRightRadius: plateRadius
                barSpacing: Config.getNestedValue("background.widgets.visualizer.barSpacing", 2)
                barMinHeight: Config.getNestedValue("background.widgets.visualizer.barMinHeight", 1)
                barRadius: Config.getNestedValue("background.widgets.visualizer.barRadius", 2)
                barsOrigin: Config.getNestedValue("background.widgets.visualizer.barsOrigin", "bottom")
                smoothing: root.smoothing
                waveMode: Config.getNestedValue("background.widgets.visualizer.waveMode", "fill")
                lineWidth: Config.getNestedValue("background.widgets.visualizer.lineWidth", 2)
                edgeInset: Config.getNestedValue("background.widgets.visualizer.edgeInset", 0)
                edgeSoftness: Config.getNestedValue("background.widgets.visualizer.edgeSoftness", 28) / 100
                frequencyProfile: root.frequencyProfile
                accentStrength: root.accentStrength
                organicSensitivity: root.organicSensitivity
                organicPulse: root.organicPulse
                organicCompression: root.organicCompression
                organicMotionSpeed: root.organicMotionSpeed
                organicIdleMotion: root.organicIdleMotion
                organicOpacity: root.organicOpacity
                organicGlow: root.organicGlow
                organicOverscan: root.organicRenderOverscan
                organicBaseRadius: root.organicBaseRadius
                organicHollowAmount: root.organicHollowAmount
            }

            Item {
                id: organicCluster
                anchors.fill: parent
                anchors.margins: Math.round(4 * root.scaleFactor)
                visible: root.vizType === "organic"

                ClippingRectangle {
                    id: organicArtwork
                    readonly property real span: Math.min(organicCluster.width, organicCluster.height)

                    width: Math.round(span * root.organicCoverSize)
                    height: width
                    anchors.centerIn: parent
                    visible: root._organicPresent
                    scale: 0.70 + root._organicReveal * 0.30
                    opacity: 0.18 + root._organicReveal * 0.82
                    radius: width * 0.36
                    color: root.widgetSemanticContainer(root.widgetSurfaceRole)
                    border.width: Math.max(1, Math.round(root.scaleFactor))
                    border.color: ColorUtils.applyAlpha(root._organicPrimary, 0.34)

                    Image {
                        anchors.fill: parent
                        source: root._organicDisplayedArt
                        sourceSize: Qt.size(Math.max(128, Math.ceil(width * 2)),
                            Math.max(128, Math.ceil(height * 2)))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        retainWhileLoading: true
                        cache: true
                        smooth: true
                        mipmap: true
                        visible: status === Image.Ready
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: root._organicDisplayedArt.length === 0
                        text: "music_note"
                        fill: 1
                        iconSize: Math.round(organicArtwork.width * 0.34)
                        color: root.widgetSemanticOnContainer(root.widgetSurfaceRole)
                    }
                }
            }
        }
    }
}
