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
    defaultConfig: ({ placementStrategy: "free", vizType: "bars", barCount: 48, barSpacing: 2, barRadius: 2, barMinHeight: 1, contentWidth: 304, contentHeight: 104, dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true, showBorder: true, colorMode: "auto", x: 100, y: 100 })

    implicitWidth: Math.round((Config.getNestedValue("background.widgets.visualizer.contentWidth", 304)) * scaleFactor)
    implicitHeight: Math.round((Config.getNestedValue("background.widgets.visualizer.contentHeight", 104)) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })

    readonly property string vizType: Config.getNestedValue("background.widgets.visualizer.vizType", "bars")
    readonly property int waveOpacity: Config.getNestedValue("background.widgets.visualizer.waveOpacity", -1)

    editPopoverContent: Component {
        Row {
            spacing: 8
            // Mode toggle icon
            MaterialSymbol {
                text: Config.getNestedValue("background.widgets.visualizer.vizType", "bars") === "wave" ? "graphic_eq" : "equalizer"
                iconSize: 16
                color: Appearance.colors.colPrimary
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const current = Config.getNestedValue("background.widgets.visualizer.vizType", "bars");
                        Config.setNestedValue("background.widgets.visualizer.vizType", current === "bars" ? "wave" : "bars");
                    }
                }
            }
            // Mode label
            StyledText {
                text: Config.getNestedValue("background.widgets.visualizer.vizType", "bars") === "wave" ? "Wave" : "Bars"
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.7)
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const current = Config.getNestedValue("background.widgets.visualizer.vizType", "bars");
                        Config.setNestedValue("background.widgets.visualizer.vizType", current === "bars" ? "wave" : "bars");
                    }
                }
            }
            // Separator
            Rectangle { width: 1; height: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12); anchors.verticalCenter: parent.verticalCenter }
            // Bar count (bars mode)
            StyledText {
                visible: Config.getNestedValue("background.widgets.visualizer.vizType", "bars") === "bars"
                text: Translation.tr("Count")
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.5)
                font.pixelSize: Appearance.font.pixelSize.smaller
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledSpinBox {
                visible: Config.getNestedValue("background.widgets.visualizer.vizType", "bars") === "bars"
                from: 8; to: 128; stepSize: 4
                value: Config.getNestedValue("background.widgets.visualizer.barCount", 48)
                onValueModified: Config.setNestedValue("background.widgets.visualizer.barCount", value)
            }
            // Wave opacity (wave mode)
            StyledText {
                visible: Config.getNestedValue("background.widgets.visualizer.vizType", "bars") === "wave"
                text: Translation.tr("Opacity")
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.5)
                font.pixelSize: Appearance.font.pixelSize.smaller
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledSpinBox {
                visible: Config.getNestedValue("background.widgets.visualizer.vizType", "bars") === "wave"
                from: 5; to: 100; stepSize: 5
                value: {
                    const v = Config.getNestedValue("background.widgets.visualizer.waveOpacity", -1);
                    return v >= 0 ? v : (Config.options?.appearance?.cava?.waveOpacity ?? 30);
                }
                onValueModified: Config.setNestedValue("background.widgets.visualizer.waveOpacity", value)
            }
        }
    }

    readonly property bool _active: Config.getNestedValue("background.widgets.visualizer.enable", false)

    // ── Dim factor (0..1) ──────────────────────────────────────
    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.visualizer.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // ── 5-style tokens ─────────────────────────────────────────
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBorder: Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Dimmed text color for overlay
    property color dimTextColor: ColorUtils.mix(root.colText, Qt.rgba(0, 0, 0, 1), dimFactor)

    CavaProcess {
        id: cavaProcess
        active: root._active
    }

    // ── Card background ────────────────────────────────────────
    WidgetSurface {
        id: cardBg
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.colText
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
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
        colorLow: Appearance.angelEverywhere ? Appearance.angel.colSecondaryContainer
            : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondaryContainer
            : Appearance.colors.colSecondaryContainer
        colorMed: Appearance.angelEverywhere ? Appearance.angel.colPrimary
            : Appearance.inirEverywhere ? Appearance.inir.colPrimary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
            : Appearance.colors.colPrimary
        colorHigh: Appearance.angelEverywhere ? Appearance.angel.colTertiary
            : Appearance.inirEverywhere ? Appearance.inir.colTertiary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
            : Appearance.colors.colTertiary
        opacity: 1.0 - dimFactor * 0.6
    }

    WaveVisualizer {
        visible: root.vizType === "wave"
        anchors.fill: parent
        anchors.margins: Appearance.angelEverywhere || Appearance.inirEverywhere ? 4 : 0
        points: cavaProcess.points
        live: root._active
        fillOpacity: (root.waveOpacity >= 0 ? root.waveOpacity : (Config.options?.appearance?.cava?.waveOpacity ?? 30)) / 100
        color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
            : Appearance.inirEverywhere ? Appearance.inir.colPrimary
            : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
            : Appearance.colors.colPrimary
        opacity: 1.0 - dimFactor * 0.6
    }
}
