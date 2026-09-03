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
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", vizType: "bars", waveOpacity: -1,
        paletteMode: "cava", barsOrigin: "bottom", waveMode: "fill",
        frequencyProfile: "flat", smoothing: 2, fillRatio: 90, barOpacity: 100,
        organicSensitivity: 25, organicPulse: 150, organicMotionSpeed: 250, organicIdleMotion: 18,
        organicOpacity: 100, organicGlow: 100, organicCoverSize: 51, organicRange: 20,
        organicCompression: 0,
        barCount: 48, barSpacing: 2, barRadius: 2, barMinHeight: 1,
        lineWidth: 2, edgeInset: 0, edgeSoftness: 28, accentStrength: 70,
        contentWidth: 304, contentHeight: 104, dim: 0,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, x: 100, y: 100
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 304) * scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 104) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
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
        if (root.paletteMode === "accent")
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

    editPopoverContent: Component {
        ColumnLayout {
            id: visualizerQuickRoot
            implicitWidth: 360
            readonly property bool narrow: width < 300
            spacing: 10

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Visualizer")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                        { label: Translation.tr("Wave"), icon: "graphic_eq", value: "wave" },
                        { label: Translation.tr("Organic"), icon: "bubble_chart", value: "organic" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        leftmost: index === 0
                        rightmost: index === 2
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.vizType === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.visualizer.vizType", modelData.value)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: visualizerTuning.implicitHeight + 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    id: visualizerTuning
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GridLayout {
                        Layout.fillWidth: true
                        columns: visualizerQuickRoot.narrow ? 2 : 4
                        columnSpacing: 6
                        rowSpacing: 6
                        Repeater {
                            model: [
                                { label: Translation.tr("Cava"), icon: "palette", value: "cava" },
                                { label: Translation.tr("Accent"), icon: "colors", value: "accent" },
                                { label: Translation.tr("Primary"), icon: "format_color_fill", value: "primary" },
                                { label: Translation.tr("Album"), icon: "album", value: "album" }
                            ]
                            SelectionGroupButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                leftmost: true
                                rightmost: true
                                horizontalPadding: 6
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                toggled: root.paletteMode === modelData.value
                                onClicked: Config.setNestedValue(
                                    "background.widgets.visualizer.paletteMode", modelData.value)
                            }
                        }
                    }

                    component VisualizerMetric: ColumnLayout {
                        id: metric
                        required property string labelText
                        required property string configKey
                        required property int minimum
                        required property int maximum
                        property int step: 5
                        property real fallback: minimum
                        property string suffix: "%"
                        readonly property real currentValue: {
                            const stored = Number(Config.getNestedValue(
                                metric.configKey, metric.fallback))
                            return stored >= metric.minimum ? stored : metric.fallback
                        }
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            StyledText {
                                Layout.fillWidth: true
                                text: metric.labelText
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: Math.round(metric.currentValue) + metric.suffix
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.numbers
                                font.weight: Font.DemiBold
                            }
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            from: metric.minimum
                            to: metric.maximum
                            stepSize: metric.step
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: metric.currentValue
                            tooltipContent: Math.round(value) + metric.suffix
                            onMoved: Config.setNestedValue(metric.configKey, Math.round(value))
                        }
                    }

                    GridLayout {
                        visible: root.vizType !== "organic"
                        Layout.fillWidth: true
                        columns: root.vizType === "bars" && !visualizerQuickRoot.narrow ? 4 : 3
                        columnSpacing: 4
                        rowSpacing: 4
                        Repeater {
                            model: root.vizType === "bars" ? [
                                { label: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                                { label: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                                { label: Translation.tr("Center"), icon: "center_focus_strong", value: "center" },
                                { label: Translation.tr("Mirror"), icon: "unfold_more", value: "mirror" }
                            ] : [
                                { label: Translation.tr("Fill"), icon: "waves", value: "fill" },
                                { label: Translation.tr("Line"), icon: "line_weight", value: "line" },
                                { label: Translation.tr("Ribbon"), icon: "unfold_more", value: "ribbon" }
                            ]
                            SelectionGroupButton {
                                required property var modelData
                                required property int index
                                readonly property int groupColumns: root.vizType === "bars"
                                    && !visualizerQuickRoot.narrow ? 4 : 3
                                readonly property int optionCount: root.vizType === "bars" ? 4 : 3
                                Layout.fillWidth: true
                                leftmost: index % groupColumns === 0
                                rightmost: index % groupColumns === groupColumns - 1
                                    || index === optionCount - 1
                                horizontalPadding: 6
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                toggled: root.vizType === "bars"
                                    ? Config.getNestedValue("background.widgets.visualizer.barsOrigin", "bottom") === modelData.value
                                    : Config.getNestedValue("background.widgets.visualizer.waveMode", "fill") === modelData.value
                                onClicked: Config.setNestedValue(root.vizType === "bars"
                                    ? "background.widgets.visualizer.barsOrigin"
                                    : "background.widgets.visualizer.waveMode", modelData.value)
                            }
                        }
                    }

                    GridLayout {
                        visible: root.vizType !== "organic"
                        Layout.fillWidth: true
                        columns: root.quickControlsWide ? 4
                            : visualizerQuickRoot.narrow ? 1 : 2
                        columnSpacing: 16
                        rowSpacing: 4

                        VisualizerMetric {
                            labelText: root.vizType === "bars"
                                ? Translation.tr("Bar count") : Translation.tr("Wave opacity")
                            configKey: root.vizType === "bars"
                                ? "background.widgets.visualizer.barCount"
                                : "background.widgets.visualizer.waveOpacity"
                            minimum: root.vizType === "bars" ? 8 : 5
                            maximum: root.vizType === "bars" ? 128 : 100
                            step: root.vizType === "bars" ? 4 : 5
                            fallback: root.vizType === "bars" ? 48
                                : (Config.options?.appearance?.cava?.waveOpacity ?? 30)
                            suffix: root.vizType === "bars" ? "" : "%"
                        }
                        VisualizerMetric {
                            labelText: Translation.tr("Smoothing")
                            configKey: "background.widgets.visualizer.smoothing"
                            minimum: 0; maximum: 8; step: 1
                            fallback: 2
                            suffix: ""
                        }
                    }

                    GridLayout {
                        visible: root.vizType === "organic"
                        Layout.fillWidth: true
                        columns: root.quickControlsWide ? 4
                            : visualizerQuickRoot.narrow ? 1 : 2
                        columnSpacing: 16
                        rowSpacing: 4

                        VisualizerMetric { labelText: Translation.tr("Sensitivity"); configKey: "background.widgets.visualizer.organicSensitivity"; minimum: 25; maximum: 200 }
                        VisualizerMetric { labelText: Translation.tr("Pulse"); configKey: "background.widgets.visualizer.organicPulse"; minimum: 0; maximum: 150 }
                        VisualizerMetric { labelText: Translation.tr("Compression"); configKey: "background.widgets.visualizer.organicCompression"; minimum: 0; maximum: 100 }
                        VisualizerMetric { labelText: Translation.tr("Motion"); configKey: "background.widgets.visualizer.organicMotionSpeed"; minimum: 20; maximum: 250 }
                        VisualizerMetric { labelText: Translation.tr("Cover"); configKey: "background.widgets.visualizer.organicCoverSize"; minimum: 30; maximum: 90; step: 1 }
                        VisualizerMetric { labelText: Translation.tr("Glow"); configKey: "background.widgets.visualizer.organicGlow"; minimum: 0; maximum: 100 }
                        VisualizerMetric { labelText: Translation.tr("Presence"); configKey: "background.widgets.visualizer.organicOpacity"; minimum: 10; maximum: 100 }
                        VisualizerMetric { labelText: Translation.tr("Idle"); configKey: "background.widgets.visualizer.organicIdleMotion"; minimum: 0; maximum: 100 }
                        VisualizerMetric { labelText: Translation.tr("Range"); configKey: "background.widgets.visualizer.organicRange"; minimum: 20; maximum: 100 }
                    }
                }
            }
        }
    }

    readonly property bool _active: root.visible
        && root.powerActive && MprisController.isPlaying
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
        title: root._activePlayer?.trackTitle ?? ""
        artist: root._activePlayer?.trackArtist ?? ""
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
        regionBrightness: root.regionBrightness
        id: cardBg
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // ── Visualizer rendering ─────────────────────────────────────
    AudioVisualizerLayer {
        id: visualizerLayer
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        points: root.vizType === "organic"
            ? (root._active && cavaProcess.audioSignalActive
                ? cavaProcess.points : root._organicSilentPoints)
            : cavaProcess.points
        active: root.vizType === "organic"
            ? root._organicPresent
            : root._active && cavaProcess.audioSignalActive
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
