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

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 320) * scaleFactor)
    implicitHeight: {
        const stored = Math.round(Number(root._readConfigKey("contentHeight") ?? 120) * scaleFactor);
        return root.displayMode === "tiles" ? Math.max(stored, root._tilesMinHeight) : stored;
    }

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: root.displayMode === "tiles" ? 100 : 120
    resizeMinHeight: root.displayMode === "tiles" ? 100 : 60

    // ── Popover: mode + resource toggles ──
    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { label: Translation.tr("Graph"), icon: "show_chart", value: "graph" },
                        { label: Translation.tr("Rings"), icon: "donut_large", value: "rings" },
                        { label: Translation.tr("Text"), icon: "text_fields", value: "text" },
                        { label: Translation.tr("Tiles"), icon: "grid_view", value: "tiles" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.displayMode === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.systemMonitor.displayMode", modelData.value)
                    }
                }
            }
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: Translation.tr("CPU"), icon: "memory", key: "showCpu", active: root.showCpu },
                        { label: Translation.tr("RAM"), icon: "storage", key: "showMemory", active: root.showMemory },
                        { label: Translation.tr("GPU"), icon: "developer_board", key: "showGpu", active: root.showGpu },
                        { label: Translation.tr("Temp"), icon: "thermostat", key: "showTemp", active: root.showTemp },
                        { label: Translation.tr("GPU temp"), icon: "device_thermostat", key: "showGpuTemp", active: root.showGpuTemp },
                        { label: Translation.tr("Disk"), icon: "hard_drive", key: "showDisk", active: root.showDisk }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: modelData.active
                        onClicked: Config.setNestedValue("background.widgets.systemMonitor." + modelData.key, !modelData.active)
                    }
                }
            }
        }
    }

    // ── Config properties ──
    // The loader already represents the effective per-output enabled state.
    // Rechecking the global base here breaks output-local overrides and can
    // leave a visible monitor without ResourceUsage keep-alive.
    readonly property bool _active: root.visible
    readonly property string displayMode: Config.getNestedValue("background.widgets.systemMonitor.displayMode", "bars")
    readonly property bool showCpu: Config.getNestedValue("background.widgets.systemMonitor.showCpu", true)
    readonly property bool showMemory: Config.getNestedValue("background.widgets.systemMonitor.showMemory", true)
    readonly property bool showGpu: Config.getNestedValue("background.widgets.systemMonitor.showGpu", true)
    readonly property bool showTemp: Config.getNestedValue("background.widgets.systemMonitor.showTemp", false)
    readonly property bool showGpuTemp: Config.getNestedValue("background.widgets.systemMonitor.showGpuTemp", false)
    readonly property bool showDisk: Config.getNestedValue("background.widgets.systemMonitor.showDisk", false)
    readonly property bool showLabels: Config.getNestedValue("background.widgets.systemMonitor.showLabels", true)
    readonly property real trackAlpha: Config.getNestedValue("background.widgets.systemMonitor.trackAlpha", 0.08)
    readonly property real fillOpacity: Config.getNestedValue("background.widgets.systemMonitor.fillOpacity", 0.7)
    readonly property real graphFillOpacity: Config.getNestedValue("background.widgets.systemMonitor.graphFillOpacity", 0.3)

    // ── Static resource model (metadata only — no live values) ──
    readonly property var _resourceModel: {
        const items = [];
        if (root.showCpu) items.push({ icon: "memory", label: Translation.tr("CPU"), key: "cpu" });
        if (root.showMemory) items.push({ icon: "storage", label: Translation.tr("RAM"), key: "mem" });
        if (root.showGpu) items.push({ icon: "developer_board", label: Translation.tr("GPU"), key: "gpu" });
        if (root.showTemp) items.push({ icon: "thermostat", label: Translation.tr("Temp"), key: "temp" });
        if (root.showGpuTemp) items.push({ icon: "device_thermostat", label: Translation.tr("GPU temp"), key: "gpuTemp" });
        if (root.showDisk) items.push({ icon: "hard_drive", label: Translation.tr("Disk"), key: "disk" });
        return items;
    }

    // Live value accessor — delegates use this to read current value
    function _getValue(key: string): real {
        switch (key) {
            case "cpu": return ResourceUsage.cpuUsage;
            case "mem": return ResourceUsage.memoryUsedPercentage;
            case "gpu": return ResourceUsage.gpuUsage;
            case "temp": return ResourceUsage.tempPercentage;
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
        if (key === "temp") return ResourceUsage.maxTemp + "°C";
        if (key === "gpuTemp") return ResourceUsage.gpuTemp + "°C";
        return Math.round(root._getValue(key) * 100) + "%";
    }

    function _tileShape(key: string): int {
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
            : key === "temp" || key === "gpuTemp" ? root.widgetSignalRole
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
        visible: root.displayMode !== "tiles"
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    // ══════════════════════════════════════════════════════════
    // BARS MODE — horizontal fill bars with icon + percentage
    // ══════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._innerMargin
        spacing: Appearance.sizes.spacingSmall ?? 4
        visible: root.displayMode === "bars"

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
                            enabled: Appearance.animationsEnabled
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
                        family: Appearance.font.family.numbers
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
        visible: root.displayMode === "graph"

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
                        font { pixelSize: Appearance.font.pixelSize.smaller; family: Appearance.font.family.numbers }
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
                font { pixelSize: Appearance.font.pixelSize.smaller - 2; family: Appearance.font.family.numbers }
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
        visible: root.displayMode === "rings"

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

                // Smoothly interpolated value for display
                property real _animatedValue: _liveValue
                Behavior on _animatedValue {
                    enabled: Appearance.animationsEnabled
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
                        text: ringCol.modelData.key === "temp" ? ResourceUsage.maxTemp + "°"
                            : ringCol.modelData.key === "gpuTemp" ? ResourceUsage.gpuTemp + "°"
                            : Math.round(ringCol._animatedValue * 100)
                        color: ringCol._liveColor
                        font {
                            pixelSize: Math.max(10, Math.round(ringCol._ringSize * 0.26))
                            family: Appearance.font.family.numbers
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
                        text: ringCol.modelData.icon
                        iconSize: Appearance.font.pixelSize.smaller
                        color: root._metricSubtext
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: ringCol.modelData.label
                        color: root._metricSubtext
                        font { pixelSize: Appearance.font.pixelSize.smaller; family: Appearance.font.family.main }
                        anchors.verticalCenter: parent.verticalCenter
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
        visible: root.displayMode === "text"
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
                        color: root._metricSubtext
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            family: Appearance.font.family.main
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root._getDisplayText(textChip.modelData.key)
                        color: textChip._liveColor
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                            family: Appearance.font.family.numbers
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
        visible: root.displayMode === "tiles" && root._resourceModel.length > 0
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
                    visible: !Appearance.zzzEverywhere && !Appearance.inirEverywhere
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
                            family: Appearance.font.family.numbers
                            weight: Font.Bold
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: -Math.round(tile.height * 0.03)
                        visible: root.showLabels && tile.height >= 62
                        text: tile.modelData.label
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
        visible: root._resourceModel.length === 0
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
