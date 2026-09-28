pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "systemMonitor"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", displayMode: "bars",
        barCount: 32, barSpacing: 2, trackAlpha: 0.08,
        fillOpacity: 0.7, graphFillOpacity: 0.3,
        showCpu: true, showMemory: true, showGpu: true,
        showTemp: false, showGpuTemp: false, showDisk: false, showLabels: true,
        contentWidth: 320, contentHeight: 120, dim: 0,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, x: 50, y: 400
    })

    widgetSurfaceEnabled: root.displayMode !== "instrument" && root.displayMode !== "tiles"
    readonly property int meterColumns: Math.max(1, Math.min(root._resourceModel.length,
        Math.floor((root.implicitWidth + 10 * root.scaleFactor) / (110 * root.scaleFactor))))
    readonly property int meterRows: Math.ceil(root._resourceModel.length / root.meterColumns)
    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round(Number(root._readConfigKey("contentWidth") ?? 320) * scaleFactor)
    implicitHeight: {
        if (root.irisFaced)
            return root.irisFaceHeight;
        const stored = Math.round(Number(root._readConfigKey("contentHeight") ?? 120) * scaleFactor);
        if (root.displayMode === "tiles")
            return Math.max(stored, root._tilesMinHeight);
        if (root.displayMode === "instrument")
            return Math.max(stored, Math.round((root.meterRows * 110 + 20) * root.scaleFactor));
        return stored;
    }

    visibleWhenLocked: false
    needsColText: true
    irisFace: Component { IrisVitalsFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    irisOptions: [
        { key: "showCpu", raw: true, label: Translation.tr("CPU"), icon: "memory", fallback: true },
        { key: "showMemory", raw: true, label: Translation.tr("Memory"), icon: "storage", fallback: true },
        { key: "showGpu", raw: true, label: Translation.tr("GPU"), icon: "developer_board", fallback: true },
        { key: "showTemp", raw: true, label: Translation.tr("CPU heat"), icon: "thermostat", fallback: false },
        { key: "showGpuTemp", raw: true, label: Translation.tr("GPU heat"), icon: "device_thermostat", fallback: false },
        { key: "showDisk", raw: true, label: Translation.tr("Disk"), icon: "hard_drive", fallback: false }
    ]
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: root.displayMode === "tiles" ? 100
        : root.displayMode === "instrument" ? 150 : 120
    resizeMinHeight: root.displayMode === "tiles" ? 100
        : root.displayMode === "instrument" ? 150 : 60

    // ── Popover: mode + resource toggles ──
    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14

            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.displayMode
                    model: [
                        { label: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { label: Translation.tr("Graph"), icon: "show_chart", value: "graph" },
                        { label: Translation.tr("Rings"), icon: "donut_large", value: "rings" },
                        { label: Translation.tr("Text"), icon: "text_fields", value: "text" },
                        { label: Translation.tr("Tiles"), icon: "grid_view", value: "tiles" },
                        { label: Translation.tr("Instrument"), icon: "equalizer", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("displayMode", value)
                }
            }

            WidgetQuickSection {
                title: Translation.tr("Metrics")
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 4
                    Repeater {
                        model: [
                            { label: Translation.tr("CPU"), icon: "memory", key: "showCpu", fallback: true },
                            { label: Translation.tr("RAM"), icon: "storage", key: "showMemory", fallback: true },
                            { label: Translation.tr("GPU"), icon: "developer_board", key: "showGpu", fallback: true },
                            { label: Translation.tr("Disk"), icon: "hard_drive", key: "showDisk", fallback: false },
                            { label: Translation.tr("CPU temp"), icon: "thermostat", key: "showTemp", fallback: false },
                            { label: Translation.tr("GPU temp"), icon: "device_thermostat", key: "showGpuTemp", fallback: false }
                        ]
                        WidgetQuickToggle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.maximumWidth: Number.POSITIVE_INFINITY
                            implicitWidth: 150
                            iconName: modelData.icon
                            label: modelData.label
                            checked: Boolean(root._readConfigKey(modelData.key) ?? modelData.fallback)
                            enabled: !checked || root._resourceModel.length > 1
                            onToggled: root._setOutputValue(modelData.key, !checked)
                        }
                    }
                }
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "label"
                    label: Translation.tr("Labels")
                    checked: root.showLabels
                    onToggled: root._setOutputValue("showLabels", !root.showLabels)
                }
            }
        }
    }

    // ── Config properties ──
    // The loader already represents the effective per-output enabled state.
    // Rechecking the global base here breaks output-local overrides and can
    // leave a visible monitor without ResourceUsage keep-alive.
    readonly property bool _active: root.visible
    readonly property string displayMode: root._readConfigKey("displayMode") ?? "bars"
    readonly property bool showCpu: root._readConfigKey("showCpu") ?? true
    readonly property bool showMemory: root._readConfigKey("showMemory") ?? true
    readonly property bool showGpu: root._readConfigKey("showGpu") ?? true
    readonly property bool showTemp: root._readConfigKey("showTemp") ?? false
    readonly property bool showGpuTemp: root._readConfigKey("showGpuTemp") ?? false
    readonly property bool showDisk: root._readConfigKey("showDisk") ?? false
    readonly property bool showLabels: root._readConfigKey("showLabels") ?? true
    readonly property real trackAlpha: root._readConfigKey("trackAlpha") ?? 0.08
    readonly property real fillOpacity: root._readConfigKey("fillOpacity") ?? 0.7
    readonly property real graphFillOpacity: root._readConfigKey("graphFillOpacity") ?? 0.3

    // ── Static resource model (metadata only — no live values) ──
    readonly property var _resourceModel: {
        const items = [];
        if (root.showCpu) items.push({ icon: "memory", label: Translation.tr("CPU"), key: "cpu" });
        if (root.showMemory) items.push({ icon: "storage", label: Translation.tr("RAM"), key: "mem" });
        if (root.showGpu) items.push({ icon: "developer_board", label: Translation.tr("GPU"), key: "gpu" });
        if (root.showTemp) items.push({ icon: "thermostat", label: Translation.tr("CPU"), key: "temp" });
        if (root.showGpuTemp) items.push({ icon: "device_thermostat", label: Translation.tr("GPU"), key: "gpuTemp" });
        if (root.showDisk) items.push({ icon: "hard_drive", label: Translation.tr("Disk"), key: "disk" });
        return items;
    }

    // Live value accessor — delegates use this to read current value
    function _getValue(key: string): real {
        switch (key) {
            case "cpu": return ResourceUsage.cpuUsage;
            case "mem": return ResourceUsage.memoryUsedPercentage;
            case "gpu": return ResourceUsage.gpuUsage;
            case "temp": return Math.min(ResourceUsage.cpuTemp / 100, 1.0);
            case "gpuTemp": return ResourceUsage.gpuTempPercentage;
            case "disk": return ResourceUsage.diskUsedPercentage;
            default: return 0;
        }
    }

    function _getColor(key: string): color {
        switch (key) {
            case "cpu": return root.cpuColor;
            case "mem": return root.memColor;
            case "gpu": return root.gpuColor;
            case "temp": return root.tempColor;
            case "gpuTemp": return root.gpuTempColor;
            case "disk": return root.diskColor;
            default: return root.cpuColor;
        }
    }

    function _getDisplayText(key: string): string {
        if (key === "temp") return ResourceUsage.cpuTemp + "°C";
        if (key === "gpuTemp") return ResourceUsage.gpuTemp + "°C";
        return Math.round(root._getValue(key) * 100) + "%";
    }

    function _tileShape(key: string): int {
        // iRiS keeps glyph badges plain round; expressive shapes are Material's.
        if (root.widgetIris) return MaterialShape.Shape.Circle
        switch (key) {
            case "cpu": return MaterialShape.Shape.Gem;
            case "mem": return MaterialShape.Shape.Cookie4Sided;
            case "gpu": return MaterialShape.Shape.Cookie12Sided;
            case "temp": return MaterialShape.Shape.Sunny;
            case "gpuTemp": return MaterialShape.Shape.Cookie9Sided;
            case "disk": return MaterialShape.Shape.Clover4Leaf;
            default: return MaterialShape.Shape.Cookie12Sided;
        }
    }

    // Tiles are the reference composition: each resource is a semantic role pair
    // (container + badge). The same selected slots feed every other monitor mode.
    function _tileRole(key: string): var {
        const role = key === "mem" ? root.widgetSecondaryRole
            : key === "gpu" ? root.widgetTertiaryRole
            // Heat is only a signal when it is one: a cool reading in the alarm colour reads as a fault.
            : key === "temp" || key === "gpuTemp" ? (root._metricSeverity(key) >= 2 ? root.widgetSignalRole
                : root._metricSeverity(key) === 1 ? "warning" : root.widgetSurfaceRole)
            : key === "disk" ? root.widgetSurfaceRole
            : root.widgetPrimaryRole;
        const set = root.widgetSemanticSet(role);
        if (key === "disk") {
            const accent = root.widgetSemanticSet(root.widgetTertiaryRole);
            return { bg: set.container, ink: set.onContainer,
                badge: accent.color, onBadge: accent.onColor };
        }
        return { bg: set.container, ink: set.onContainer,
            badge: set.color, onBadge: set.onColor };
    }

    readonly property real _tileUnit: Math.round(96 * root.scaleFactor)
    readonly property real _tileGap: Math.round(10 * root.scaleFactor)

    // Width determines both column and row counts.
    readonly property int _tileColumns: {
        const count = Math.max(1, root._resourceModel.length);
        const fit = Math.floor((root.width + root._tileGap) / (root._tileUnit + root._tileGap));
        return Math.max(1, Math.min(count, fit));
    }
    readonly property int _tileRows: Math.ceil(
        Math.max(1, root._resourceModel.length) / Math.max(1, root._tileColumns))
    readonly property real _tilesMinHeight: root._tileRows * root._tileUnit
        + (root._tileRows - 1) * root._tileGap + root._innerMargin * 2

    // ── Style tokens ──
    readonly property real cardRadius: root.widgetCardRadius
    readonly property int _innerMargin: Appearance.angelEverywhere || Appearance.inirEverywhere ? 6 : 2

    // Rings/bars/text reuse the same categorical palette as Tiles. The wallpaper
    // already generated these semantic roles, so position analysis must not invent
    // a second hue. Threshold state only overrides that base role when a metric is
    // actually caution/warning.
    function _metricBaseColor(key: string): color {
        return root._tileRole(key).badge;
    }
    readonly property color _metricNormal: root._metricBaseColor("cpu")
    readonly property color _metricCaution: root.widgetSemanticColor("warning")
    readonly property color _metricWarning: root.widgetSignal

    // Telemetry text is neutral information, not another accent. Select between
    // the generated on-surface and inverse-on-surface roles according to the real
    // backdrop polarity; do not saturate or re-hue either token. This keeps the
    // labels consistent with the shell's text hierarchy while the metric arc owns
    // the accent color.
    readonly property color _metricLightInk: Appearance.m3colors.darkmode
        ? Appearance.colors.colOnLayer0 : Appearance.m3colors.m3inverseOnSurface
    readonly property color _metricDarkInk: Appearance.m3colors.darkmode
        ? Appearance.m3colors.m3inverseOnSurface : Appearance.colors.colOnLayer0
    readonly property color _metricText: root.forceLightInk ? root._metricLightInk
        : root.forceDarkInk ? root._metricDarkInk
        : root.widgetHasSurface
            ? (root.widgetPlateIsDark ? root._metricLightInk : root._metricDarkInk)
            : (root.regionIsBright ? root._metricDarkInk : root._metricLightInk)
    readonly property color _metricSubtext: ColorUtils.applyAlpha(root._metricText, 0.66)

    // The track is the background of the metric, not an outline. Keep it in the
    // exact same semantic color family as the active arc and let the existing
    // Track opacity setting control only its alpha. This restores the original
    // System Monitor composition without reintroducing gray/black helper rings.
    function _metricTrackColor(key: string): color {
        return ColorUtils.applyAlpha(root._metricColor(key), root.trackAlpha);
    }

    // Graph mode needs categorical identity but no severity override: use the
    // exact same generated role that the corresponding Tile badge uses.
    function _graphColor(key: string): color {
        return root._metricBaseColor(key);
    }

    function _metricSeverity(key: string): int {
        const value = root._getValue(key) * 100;
        switch (key) {
        case "temp":
        case "gpuTemp": {
            const caution = Config.options?.bar?.resources?.tempCautionThreshold ?? 65;
            const warning = Config.options?.bar?.resources?.tempWarningThreshold ?? 80;
            return value >= warning ? 2 : value >= caution ? 1 : 0;
        }
        case "cpu":
            return value >= (Config.options?.bar?.resources?.cpuWarningThreshold ?? 90) ? 2 : 0;
        case "mem":
            return value >= (Config.options?.bar?.resources?.memoryWarningThreshold ?? 90) ? 2 : 0;
        case "gpu":
            return value >= (Config.options?.bar?.resources?.gpuWarningThreshold ?? 90) ? 2 : 0;
        case "disk":
            return value >= 90 ? 2 : 0;
        default:
            return 0;
        }
    }

    function _metricColor(key: string): color {
        const severity = root._metricSeverity(key);
        return severity >= 2 ? root._metricWarning
            : severity === 1 ? root._metricCaution
            : root._metricBaseColor(key);
    }

    readonly property color cpuColor: root._metricColor("cpu")
    readonly property color memColor: root._metricColor("mem")
    readonly property color gpuColor: root._metricColor("gpu")
    readonly property color tempColor: root._metricColor("temp")
    readonly property color gpuTempColor: root._metricColor("gpuTemp")
    readonly property color diskColor: root._metricColor("disk")

    // Animation duration for smooth value transitions
    readonly property int _animDuration: Appearance.animation.elementMove.duration
    // Values tick every second: easing them behind windows repaints the desktop for nothing.
    readonly property bool animatesValues: Appearance.animationsEnabled && root.motionActive

    property bool _holdingResourceUsage: false
    function _syncResourceUsage(): void {
        const shouldHold = root._active && root.visible && root.powerActive;
        if (shouldHold && !root._holdingResourceUsage) {
            root._holdingResourceUsage = true;
            ResourceUsage.keepAlive();
        } else if (!shouldHold && root._holdingResourceUsage) {
            root._holdingResourceUsage = false;
            ResourceUsage.releaseKeepAlive();
        }
    }
    on_ActiveChanged: root._syncResourceUsage()
    onVisibleChanged: root._syncResourceUsage()
    onPowerActiveChanged: root._syncResourceUsage()
    Component.onCompleted: root._syncResourceUsage()
    Component.onDestruction: if (root._holdingResourceUsage) {
        root._holdingResourceUsage = false;
        ResourceUsage.releaseKeepAlive();
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        anchors.fill: parent
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
        shown: !root.irisFaced && root.displayMode !== "tiles" && root.displayMode !== "instrument"
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    // ══════════════════════════════════════════════════════════
    // INSTRUMENT MODE — a bank of comparable vertical measurement rails.
    // Values, units and resource identity stay readable without watch faces.
    // ══════════════════════════════════════════════════════════
    Grid {
        anchors.centerIn: parent
        opacity: root.displayMode === "instrument" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "instrument"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        columns: root.meterColumns
        spacing: Math.round(10 * root.scaleFactor)
        move: Transition {
            enabled: root.animateGeometry
            NumberAnimation {
                properties: "x,y"
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: root._resourceModel

            Item {
                id: resourceMeter
                required property var modelData
                readonly property real side: Math.min(
                    (root.height - root._innerMargin * 2 - Math.round(10 * root.scaleFactor) * (root.meterRows - 1)) / Math.max(1, root.meterRows),
                    (root.width - root._innerMargin * 2 - Math.round(10 * root.scaleFactor) * (root.meterColumns - 1))
                        / root.meterColumns)
                readonly property real liveValue: root._getValue(modelData.key)
                readonly property color liveColor: root.widgetRoleColor(root._getColor(modelData.key))

                width: Math.max(40, Math.round(resourceMeter.side))
                height: Math.max(40, Math.round(resourceMeter.side))

                InstrumentScale {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Math.round(8 * root.scaleFactor)
                    anchors.bottomMargin: Math.round(8 * root.scaleFactor)
                    width: Math.round(14 * root.scaleFactor)
                    vertical: true
                    divisions: 20
                    fraction: resourceMeter.liveValue
                    ink: root.widgetInk
                    accent: resourceMeter.liveColor
                    animated: root.animationsActive
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(24 * root.scaleFactor)
                    anchors.topMargin: Math.round(6 * root.scaleFactor)
                    anchors.bottomMargin: Math.round(6 * root.scaleFactor)
                    spacing: Math.round(4 * root.scaleFactor)

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignLeft
                        text: resourceMeter.modelData.icon
                        iconSize: Math.max(14, Math.round(resourceMeter.side * 0.12))
                        color: resourceMeter.liveColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignBottom
                        fontSizeMode: Text.Fit
                        minimumPixelSize: Math.round(14 * root.scaleFactor)
                        text: root._getDisplayText(resourceMeter.modelData.key)
                        color: root.widgetInk
                        font {
                            family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily
                            pixelSize: Math.round(resourceMeter.side * 0.29)
                            weight: Font.Bold
                            features: ({ "tnum": 1 })
                            letterSpacing: -0.5
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.showLabels
                        elide: Text.ElideRight
                        text: resourceMeter.modelData.key === "temp" ? Translation.tr("CPU temp")
                            : resourceMeter.modelData.key === "gpuTemp" ? Translation.tr("GPU temp")
                            : resourceMeter.modelData.label
                        color: root.widgetInkMuted
                        font {
                            family: root.widgetBodyFamily
                            pixelSize: Math.max(10, Math.round(resourceMeter.side * 0.075))
                            weight: Font.DemiBold
                            letterSpacing: Math.round(1.4 * root.scaleFactor)
                            capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // BARS MODE — horizontal fill bars with icon + percentage
    // ══════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._innerMargin
        spacing: Appearance.sizes.spacingSmall ?? 4
        opacity: root.displayMode === "bars" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "bars"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        Repeater {
            model: root._resourceModel

            RowLayout {
                id: barRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Appearance.sizes.spacingSmall ?? 4

                readonly property real _liveValue: root._getValue(modelData.key)
                readonly property color _liveColor: root._getColor(modelData.key)

                MaterialSymbol {
                    visible: root.showLabels
                    text: barRow.modelData.icon
                    iconSize: Appearance.font.pixelSize.small
                    color: barRow._liveColor
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        color: root._metricTrackColor(barRow.modelData.key)
                    }

                    Rectangle {
                        id: barFill
                        property real targetWidth: parent.width * Math.min(1, barRow._liveValue)
                        width: targetWidth
                        height: parent.height
                        radius: Appearance.rounding.verysmall
                        color: barRow._liveColor
                        opacity: root.fillOpacity

                        Behavior on width {
                            enabled: root.animatesValues
                            NumberAnimation { duration: root._animDuration; easing.type: Easing.OutCubic }
                        }
                    }
                }

                StyledText {
                    visible: root.showLabels
                    text: root._getDisplayText(barRow.modelData.key)
                    color: barRow._liveColor
                    font {
                        pixelSize: Appearance.font.pixelSize.smaller
                        family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily
                    }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: barRow.modelData.key === "temp" ? 40 : 32
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // GRAPH MODE — area fills with legend overlay
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        anchors.margins: root._innerMargin
        opacity: root.displayMode === "graph" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "graph"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        readonly property int _legendH: root.showLabels ? 16 : 0

        Row {
            visible: root.showLabels
            z: 1
            spacing: Appearance.sizes.spacingSmall ?? 4
            anchors { top: parent.top; left: parent.left; margins: 2 }

            Repeater {
                model: root._resourceModel
                Row {
                    required property var modelData
                    spacing: 2
                    MaterialSymbol {
                        text: modelData.icon
                        iconSize: Appearance.font.pixelSize.smaller
                        color: root._graphColor(modelData.key)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: root._getDisplayText(modelData.key)
                        color: root._graphColor(modelData.key)
                        font { pixelSize: Appearance.font.pixelSize.smaller; family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Y-axis labels
        Repeater {
            model: [
                { pct: 0, label: "0%" },
                { pct: 0.5, label: "50%" },
                { pct: 1.0, label: "100%" }
            ]
            StyledText {
                required property var modelData
                text: modelData.label
                color: root._metricSubtext
                font { pixelSize: Appearance.font.pixelSize.smaller - 2; family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily }
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: parent._legendH + (parent.height - parent._legendH) * (1.0 - modelData.pct) - height / 2
            }
        }

        // Grid lines at 25/50/75%
        Repeater {
            model: [0.25, 0.50, 0.75]
            Rectangle {
                required property real modelData
                anchors { left: parent.left; right: parent.right }
                y: parent._legendH + (parent.height - parent._legendH) * (1.0 - modelData)
                height: 1
                color: ColorUtils.applyAlpha(root._metricText, 0.06)
            }
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showCpu ? ResourceUsage.cpuUsageHistory : []
            color: root._graphColor("cpu")
            fillOpacity: root.graphFillOpacity + 0.05
            alignment: Graph.Alignment.Right
            visible: root.showCpu
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showMemory ? ResourceUsage.memoryUsageHistory : []
            color: root._graphColor("mem")
            fillOpacity: root.graphFillOpacity
            alignment: Graph.Alignment.Right
            visible: root.showMemory
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showGpuTemp ? ResourceUsage.gpuTempHistory : []
            color: root._graphColor("gpuTemp")
            fillOpacity: root.graphFillOpacity - 0.05
            alignment: Graph.Alignment.Right
            visible: root.showGpuTemp
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showGpu ? ResourceUsage.gpuUsageHistory : []
            color: root._graphColor("gpu")
            fillOpacity: root.graphFillOpacity - 0.05
            alignment: Graph.Alignment.Right
            visible: root.showGpu
        }
    }

    // ══════════════════════════════════════════════════════════
    // RINGS MODE — circular gauges per resource
    // ══════════════════════════════════════════════════════════
    Row {
        anchors.centerIn: parent
        spacing: Appearance.sizes.spacingNormal ?? 8
        opacity: root.displayMode === "rings" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "rings"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        Repeater {
            model: root._resourceModel

            Column {
                id: ringCol
                required property var modelData
                spacing: Appearance.sizes.spacingSmall ?? 4
                readonly property int _ringSize: Math.min(
                    Math.round((root.height - root._innerMargin * 2 - (root.showLabels ? 20 : 0)) * 0.85),
                    Math.round((root.width - root._innerMargin * 2) / Math.max(1, root._resourceModel.length) - (Appearance.sizes.spacingNormal ?? 8))
                )
                readonly property real _liveValue: root._getValue(modelData.key)
                readonly property color _liveColor: root._getColor(modelData.key)
                width: _ringSize

                // Smoothly interpolated value for display
                property real _animatedValue: _liveValue
                Behavior on _animatedValue {
                    enabled: root.animatesValues
                    NumberAnimation { duration: root._animDuration; easing.type: Easing.OutCubic }
                }

                Item {
                    width: ringCol._ringSize
                    height: ringCol._ringSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    CircularProgress {
                        anchors.centerIn: parent
                        implicitSize: parent.width
                        lineWidth: Math.max(3, Math.round(parent.width * 0.09))
                        value: ringCol._animatedValue
                        // `_animatedValue` already owns the transition. Letting
                        // CircularProgress animate `degree` again chained two
                        // full animations per sample and kept five Shape layers
                        // rendering for most of every 3-second polling cycle.
                        enableAnimation: false
                        colPrimary: ringCol._liveColor
                        colSecondary: root._metricTrackColor(ringCol.modelData.key)
                    }

                    // Percentage/value inside the ring
                    StyledText {
                        anchors.centerIn: parent
                        text: ringCol.modelData.key === "temp" ? ResourceUsage.cpuTemp + "°"
                            : ringCol.modelData.key === "gpuTemp" ? ResourceUsage.gpuTemp + "°"
                            : Math.round(ringCol._animatedValue * 100)
                        color: ringCol._liveColor
                        font {
                            pixelSize: Math.max(10, Math.round(ringCol._ringSize * 0.26))
                            family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily
                            weight: Font.DemiBold
                        }
                    }
                }

                // Label below ring
                Row {
                    visible: root.showLabels
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    MaterialSymbol {
                        id: ringLabelIcon
                        text: ringCol.modelData.icon
                        iconSize: Appearance.font.pixelSize.smaller
                        color: root._metricSubtext
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        width: Math.min(
                            implicitWidth,
                            Math.max(0, ringCol._ringSize - ringLabelIcon.implicitWidth - parent.spacing)
                        )
                        text: ringCol.modelData.label
                        color: root._metricSubtext
                        font { pixelSize: Appearance.font.pixelSize.smaller; family: root.widgetBodyFamily }
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // TEXT MODE — compact numeric readout with chip style
    // ══════════════════════════════════════════════════════════
    Flow {
        anchors.centerIn: parent
        spacing: Appearance.sizes.spacingSmall ?? 4
        opacity: root.displayMode === "text" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "text"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        width: parent.width - root._innerMargin * 2

        Repeater {
            model: root._resourceModel

            Rectangle {
                id: textChip
                required property var modelData
                readonly property color _liveColor: root._getColor(modelData.key)
                width: chipRow.implicitWidth + 12
                height: chipRow.implicitHeight + 8
                radius: Appearance.rounding.small
                color: root._metricTrackColor(textChip.modelData.key)

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Appearance.sizes.spacingSmall ?? 4

                    MaterialSymbol {
                        text: textChip.modelData.icon
                        iconSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        color: textChip._liveColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: textChip.modelData.label
                        font.weight: root.widgetLabelWeight
                        color: root._metricSubtext
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            family: root.widgetBodyFamily
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root._getDisplayText(textChip.modelData.key)
                        color: textChip._liveColor
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                            family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily
                            weight: Font.DemiBold
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    GridLayout {
        id: tileGrid
        anchors.fill: parent
        anchors.margins: root._innerMargin
        opacity: root.displayMode === "tiles" && root._resourceModel.length > 0 ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.displayMode === "tiles"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        columnSpacing: root._tileGap
        rowSpacing: root._tileGap
        columns: root._tileColumns

        Repeater {
            model: root._resourceModel

            Rectangle {
                id: tile
                required property var modelData
                readonly property var role: root._tileRole(modelData.key)

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: root.cardRadius
                color: Appearance.regaliaEverywhere ? "transparent" : tile.role.bg

                RegaliaPlate {
                    anchors.fill: parent
                    z: -1
                    visible: Appearance.regaliaEverywhere
                    radius: tile.radius
                    fillColor: tile.role.bg
                    inset: Appearance.regalia.surfaceInset
                    elevated: true
                }

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation {
                        duration: root._animDuration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                StyledRectangularShadow {
                    target: tile
                    z: -2
                    visible: !root.widgetIris && !Appearance.zzzEverywhere && !Appearance.inirEverywhere
                        && !Appearance.regaliaEverywhere
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(tile.height * 0.13)
                    spacing: 0

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignRight
                        visible: tile.height >= 76
                        shape: root._tileShape(tile.modelData.key)
                        color: tile.role.badge
                        colSymbol: tile.role.onBadge
                        text: tile.modelData.icon
                        fill: 1
                        iconSize: Math.max(13, Math.round(tile.height * 0.17))
                        padding: Math.max(5, Math.round(tile.height * 0.055))
                    }

                    Item { Layout.fillHeight: true }

                    StyledText {
                        Layout.fillWidth: true
                        text: root._getDisplayText(tile.modelData.key)
                        color: tile.role.ink
                        elide: Text.ElideRight
                        font {
                            pixelSize: Math.max(14, Math.min(
                                Math.round(Appearance.font.pixelSize.hugeass * root.scaleFactor),
                                Math.round(tile.height * 0.30),
                                Math.round(tile.width * 0.34)))
                            family: root.widgetIris ? IrisStyle.fontMain : root.widgetNumbersFamily
                            weight: Font.Bold
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: -Math.round(tile.height * 0.03)
                        visible: root.showLabels && tile.height >= 62
                        text: tile.modelData.label
                        font.weight: root.widgetLabelWeight
                        color: ColorUtils.applyAlpha(tile.role.ink, 0.62)
                        elide: Text.ElideRight
                        font.pixelSize: Math.max(10, Math.min(
                            Math.round(Appearance.font.pixelSize.small * root.scaleFactor),
                            Math.round(tile.height * 0.14)))
                    }
                }
            }
        }
    }

    Column {
        visible: !root.irisFaced && root._resourceModel.length === 0
        anchors.centerIn: parent
        spacing: Math.round((Appearance.sizes.spacingSmall ?? 8) / 2)

        MaterialShape {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitSize: Math.round(48 * root.scaleFactor)
            shape: MaterialShape.Shape.Ghostish
            color: ColorUtils.applyAlpha(root._metricNormal, 0.16)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "monitor_heart"
                iconSize: Math.round(24 * root.scaleFactor)
                color: root._metricNormal
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Translation.tr("Select a metric")
            color: root._metricSubtext
            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
        }
    }
}
