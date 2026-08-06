pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", vizType: "bars", waveOpacity: -1,
        barCount: 48, barSpacing: 2, barRadius: 2, barMinHeight: 1,
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
                        { label: "Bars", icon: "equalizer", value: "bars" },
                        { label: "Wave", icon: "graphic_eq", value: "wave" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.vizType === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.visualizer.vizType", modelData.value)
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
        }
    }

    readonly property bool _active: (Config.options?.background?.widgets?.visualizer?.enable ?? false)
        && root.visible && root.powerActive && MprisController.isPlaying

    // ── Style tokens ───────────────────────────────────────────
    readonly property real cardRadius: root.widgetCardRadius

    CavaProcess {
        id: cavaProcess
        active: root._active
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
    CavaVisualizer {
        visible: root.vizType === "bars"
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        points: cavaProcess.points
        live: root._active
        barCount: Config.getNestedValue("background.widgets.visualizer.barCount", 48)
        barSpacing: Config.getNestedValue("background.widgets.visualizer.barSpacing", 2)
        barMinHeight: Config.getNestedValue("background.widgets.visualizer.barMinHeight", 1)
        barRadius: Config.getNestedValue("background.widgets.visualizer.barRadius", 2)
        colorLow: Appearance.cookieEverywhere ? Appearance.colors.colLayer3
            : Appearance.zzzEverywhere ? Appearance.zzz.chrome
            : Appearance.colors.colSecondaryContainer
        colorMed: root.widgetAccentVisible
        colorHigh: root.widgetAccent3Visible
    }

    WaveVisualizer {
        visible: root.vizType === "wave"
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        points: cavaProcess.points
        live: root._active
        fillOpacity: (root.waveOpacity >= 0 ? root.waveOpacity : (Config.options?.appearance?.cava?.waveOpacity ?? 30)) / 100
        color: root.widgetAccentVisible
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
