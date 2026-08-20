pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", vizType: "bars", waveOpacity: -1,
        paletteMode: "cava", barsOrigin: "bottom", waveMode: "fill",
        frequencyProfile: "flat", smoothing: 2, fillRatio: 90, barOpacity: 100,
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
    // Cava already owns its own palette. Show the shared widget-color presets
    // only when this widget is actually consuming the semantic widget palette.
    semanticPaletteQuickControls: root.paletteMode !== "cava"
    readonly property var spectrumPalette: {
        if (root.paletteMode === "accent")
            return [root.widgetAccentVisible, root.widgetAccent2Visible, root.widgetAccent3Visible]
        if (root.paletteMode === "primary")
            return [root.widgetAccent]
        return CavaTheme.visualizerColors
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 8

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: [
                        { label: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                        { label: Translation.tr("Wave"), icon: "graphic_eq", value: "wave" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.vizType === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.visualizer.vizType", modelData.value)
                    }
                }
            }

            StyledText {
                text: Translation.tr("Palette")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: [
                        { label: Translation.tr("Cava"), icon: "palette", value: "cava" },
                        { label: Translation.tr("Accent"), icon: "colors", value: "accent" },
                        { label: Translation.tr("Primary"), icon: "format_color_fill", value: "primary" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.paletteMode === modelData.value
                        onClicked: Config.setNestedValue(
                            "background.widgets.visualizer.paletteMode", modelData.value)
                    }
                }
            }

            StyledText {
                text: Translation.tr("Shape")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.vizType === "bars" ? 4 : 3
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
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.vizType === "bars"
                            ? Config.getNestedValue(
                                "background.widgets.visualizer.barsOrigin", "bottom") === modelData.value
                            : Config.getNestedValue(
                                "background.widgets.visualizer.waveMode", "fill") === modelData.value
                        onClicked: Config.setNestedValue(root.vizType === "bars"
                            ? "background.widgets.visualizer.barsOrigin"
                            : "background.widgets.visualizer.waveMode", modelData.value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.vizType === "bars" ? Translation.tr("Bar count") : Translation.tr("Wave opacity")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledSpinBox {
                    visible: root.vizType === "bars"
                    from: 8; to: 128; stepSize: 4
                    value: Config.getNestedValue("background.widgets.visualizer.barCount", 48)
                    onValueModified: Config.setNestedValue("background.widgets.visualizer.barCount", value)
                }

                StyledSpinBox {
                    visible: root.vizType === "wave"
                    from: 5; to: 100; stepSize: 5
                    value: {
                        const v = Config.getNestedValue("background.widgets.visualizer.waveOpacity", -1);
                        return v >= 0 ? v : (Config.options?.appearance?.cava?.waveOpacity ?? 30);
                    }
                    onValueModified: Config.setNestedValue("background.widgets.visualizer.waveOpacity", value)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Smoothing")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledSpinBox {
                    from: 0; to: 8; stepSize: 1
                    value: Config.getNestedValue("background.widgets.visualizer.smoothing", 2)
                    onValueModified: Config.setNestedValue(
                        "background.widgets.visualizer.smoothing", value)
                }
            }
        }
    }

    readonly property bool _active: root.visible
        && root.powerActive && MprisController.isPlaying

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
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // ── Visualizer rendering ─────────────────────────────────────
    CavaSpectrum {
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        points: cavaProcess.points
        active: root._active && cavaProcess.audioSignalActive
        threadedRendering: true
        visualizerType: root.vizType
        normalizationCeiling: cavaProcess.normalizationCeiling
        spectrumColors: root.spectrumPalette
        spectrumColor: root.widgetAccentVisible
        spectrumOpacity: (root.vizType === "wave"
            ? (root.waveOpacity >= 0 ? root.waveOpacity
                : (Config.options?.appearance?.cava?.waveOpacity ?? 30))
            : Config.getNestedValue("background.widgets.visualizer.barOpacity", 100)) / 100
        fillRatio: Config.getNestedValue("background.widgets.visualizer.fillRatio", 90) / 100
        pixelsPerBar: Math.max(3, (width + barSpacing)
            / Math.max(4, Config.getNestedValue("background.widgets.visualizer.barCount", 48)))
        barSpacing: Config.getNestedValue("background.widgets.visualizer.barSpacing", 2)
        barMinHeight: Config.getNestedValue("background.widgets.visualizer.barMinHeight", 1)
        barRadius: Config.getNestedValue("background.widgets.visualizer.barRadius", 2)
        barsOrigin: Config.getNestedValue("background.widgets.visualizer.barsOrigin", "bottom")
        smoothing: Config.getNestedValue("background.widgets.visualizer.smoothing", 2)
        waveMode: Config.getNestedValue("background.widgets.visualizer.waveMode", "fill")
        lineWidth: Config.getNestedValue("background.widgets.visualizer.lineWidth", 2)
        edgeInset: Config.getNestedValue("background.widgets.visualizer.edgeInset", 0)
        edgeSoftness: Config.getNestedValue("background.widgets.visualizer.edgeSoftness", 28) / 100
        frequencyProfile: Config.getNestedValue(
            "background.widgets.visualizer.frequencyProfile", "flat")
        accentStrength: Config.getNestedValue(
            "background.widgets.visualizer.accentStrength", 70) / 100
        topLeftRadius: cardBg.surfaceRadius
        topRightRadius: cardBg.surfaceRadius
        bottomLeftRadius: cardBg.surfaceRadius
        bottomRightRadius: cardBg.surfaceRadius
    }
}
