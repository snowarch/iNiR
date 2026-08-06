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
        showTemp: false, showDisk: false, showLabels: true,
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
    readonly property bool _active: Config.getNestedValue("background.widgets.systemMonitor.enable", false)
    readonly property string displayMode: Config.getNestedValue("background.widgets.systemMonitor.displayMode", "bars")
    readonly property bool showCpu: Config.getNestedValue("background.widgets.systemMonitor.showCpu", true)
    readonly property bool showMemory: Config.getNestedValue("background.widgets.systemMonitor.showMemory", true)
    readonly property bool showGpu: Config.getNestedValue("background.widgets.systemMonitor.showGpu", true)
    readonly property bool showTemp: Config.getNestedValue("background.widgets.systemMonitor.showTemp", false)
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
            case "disk": return root.diskColor;
            default: return root.cpuColor;
        }
    }

    function _getDisplayText(key: string): string {
        if (key === "temp") return ResourceUsage.maxTemp + "°C";
        return Math.round(root._getValue(key) * 100) + "%";
    }

    function _tileShape(key: string): int {
        switch (key) {
            case "cpu": return MaterialShape.Shape.Gem;
            case "mem": return MaterialShape.Shape.Cookie4Sided;
            case "gpu": return MaterialShape.Shape.Cookie12Sided;
            case "temp": return MaterialShape.Shape.Sunny;
            case "disk": return MaterialShape.Shape.Clover4Leaf;
            default: return MaterialShape.Shape.Cookie12Sided;
        }
    }

    // Real M3 tonal container roles, one family per metric.
    function _tileRole(key: string): var {
        const c = Appearance.colors;
        switch (key) {
            case "mem": return { bg: c.colSecondaryContainer, ink: c.colOnSecondaryContainer,
                badge: c.colSecondary, onBadge: c.colOnSecondary };
            case "gpu": return { bg: c.colTertiaryContainer, ink: c.colOnTertiaryContainer,
                badge: c.colTertiary, onBadge: c.colOnTertiary };
            case "temp": return { bg: c.colErrorContainer, ink: c.colOnErrorContainer,
                badge: c.colError, onBadge: c.colOnError };
            case "disk": return { bg: c.colSurfaceContainerHighest, ink: c.colOnSurface,
                badge: c.colTertiary, onBadge: c.colOnTertiary };
            default: return { bg: c.colPrimaryContainer, ink: c.colOnPrimaryContainer,
                badge: c.colPrimary, onBadge: c.colOnPrimary };
        }
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

    // Shared desktop-widget identity (AbstractBackgroundWidget) so every metric reads
    // as the same wallpaper-generated family across all widgets.
    // Display variants: clamped against the plate/region actually behind them.
    readonly property color cpuColor: root.widgetRoleColor(root.widgetAccent, 4.0, 0.45)
    readonly property color memColor: root.widgetRoleColor(root.widgetAccent2, 4.0, 0.45)
    readonly property color gpuColor: root.widgetRoleColor(root.widgetAccent3, 4.0, 0.45)
    readonly property color tempColor: root.widgetRoleColor(root.widgetSignal, 3.0, 0.50)
    readonly property color diskColor: root.widgetRoleColor(
        ColorUtils.mix(root.widgetAccent2, root.widgetAccent3, 0.55), 3.0, 0.42)

    readonly property real _mixedRegionStrength: root.widgetHasSurface ? 0
        : Math.max(0, Math.min(1, (root.regionBrightnessSpread - 0.08) / 0.20))
    readonly property color _labelInk: root.widgetHasSurface
        ? root.widgetInkMuted
        : ColorUtils.applyAlpha(root.widgetInk, 0.88)
    readonly property int _labelStyle: root.widgetHasSurface ? Text.Normal : Text.Outline
    readonly property color _labelKeyline: root._opposingKeyline(root.widgetInk, 0.26)

    function _opposingKeyline(ink: color, baseAlpha: real): color {
        const lightInk = ColorUtils.relativeLuminance(ink) >= 0.42;
        const opposite = lightInk ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1);
        return ColorUtils.applyAlpha(opposite,
            Math.min(0.72, baseAlpha + root._mixedRegionStrength * 0.34));
    }

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
                        color: ColorUtils.applyAlpha(barRow._liveColor, root.trackAlpha)
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
                    color: root._labelInk
                    style: root._labelStyle
                    styleColor: root._labelKeyline
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
                        color: root._getColor(modelData.key)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: root._getDisplayText(modelData.key)
                        color: root._getColor(modelData.key)
                        style: root._labelStyle
                        styleColor: root._opposingKeyline(color, 0.24)
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
                color: ColorUtils.applyAlpha(root._labelInk, 0.72)
                style: root._labelStyle
                styleColor: root._labelKeyline
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
                color: ColorUtils.applyAlpha(root.widgetInk, 0.06)
            }
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showCpu ? ResourceUsage.cpuUsageHistory : []
            color: root.cpuColor
            fillOpacity: root.graphFillOpacity + 0.05
            alignment: Graph.Alignment.Right
            visible: root.showCpu
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showMemory ? ResourceUsage.memoryUsageHistory : []
            color: root.memColor
            fillOpacity: root.graphFillOpacity
            alignment: Graph.Alignment.Right
            visible: root.showMemory
        }

        Graph {
            anchors.fill: parent
            anchors.topMargin: parent._legendH
            values: root.showGpu ? ResourceUsage.gpuUsageHistory : []
            color: root.gpuColor
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
                        colSecondary: ColorUtils.applyAlpha(ringCol._liveColor, root.trackAlpha + 0.04)
                    }

                    // Percentage/value inside the ring
                    StyledText {
                        anchors.centerIn: parent
                        text: ringCol.modelData.key === "temp" ? ResourceUsage.maxTemp + "°" : Math.round(ringCol._animatedValue * 100)
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
                        color: root._labelInk
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: ringCol.modelData.label
                        color: root._labelInk
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
                color: ColorUtils.applyAlpha(textChip._liveColor, root.trackAlpha)

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
                        color: root._labelInk
                        style: root._labelStyle
                        styleColor: root._labelKeyline
                        font {
                            pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            family: Appearance.font.family.main
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root._getDisplayText(textChip.modelData.key)
                        color: textChip._liveColor
                        style: root._labelStyle
                        styleColor: root._opposingKeyline(textChip._liveColor, 0.34)
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
                color: tile.role.bg

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
            color: ColorUtils.applyAlpha(root.widgetAccent, 0.16)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "monitor_heart"
                iconSize: Math.round(24 * root.scaleFactor)
                color: root.widgetAccentVisible
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Translation.tr("Select a metric")
            color: root.widgetInkMuted
            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
        }
    }
}
