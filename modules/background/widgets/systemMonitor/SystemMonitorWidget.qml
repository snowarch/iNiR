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
    defaultConfig: ({ placementStrategy: "free", preset: "default", displayMode: "bars", showCpu: true, showMemory: true, showGpu: true, showTemp: false, showDisk: false, showLabels: true, contentWidth: 320, contentHeight: 120, dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true, showBorder: true, colorMode: "auto", x: 50, y: 400 })

    implicitWidth: Math.round((Config.getNestedValue("background.widgets.systemMonitor.contentWidth", 320)) * scaleFactor)
    implicitHeight: Math.round((Config.getNestedValue("background.widgets.systemMonitor.contentHeight", 120)) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })

    // ── Popover: mode + resource toggles ──
    editPopoverContent: Component {
        Column {
            spacing: 6
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: "Bars", icon: "bar_chart", value: "bars" },
                        { label: "Graph", icon: "show_chart", value: "graph" },
                        { label: "Rings", icon: "donut_large", value: "rings" },
                        { label: "Text", icon: "text_fields", value: "text" }
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
                        { label: "CPU", icon: "memory", key: "showCpu", active: root.showCpu },
                        { label: "RAM", icon: "storage", key: "showMemory", active: root.showMemory },
                        { label: "GPU", icon: "developer_board", key: "showGpu", active: root.showGpu },
                        { label: "Temp", icon: "thermostat", key: "showTemp", active: root.showTemp },
                        { label: "Disk", icon: "hard_drive", key: "showDisk", active: root.showDisk }
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

    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.systemMonitor.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // ── Static resource model (metadata only — no live values) ──
    readonly property var _resourceModel: {
        const items = [];
        if (root.showCpu) items.push({ icon: "memory", label: "CPU", key: "cpu" });
        if (root.showMemory) items.push({ icon: "storage", label: "RAM", key: "mem" });
        if (root.showGpu) items.push({ icon: "developer_board", label: "GPU", key: "gpu" });
        if (root.showTemp) items.push({ icon: "thermostat", label: "Temp", key: "temp" });
        if (root.showDisk) items.push({ icon: "hard_drive", label: "Disk", key: "disk" });
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

    // ── Style tokens ──
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property int _innerMargin: Appearance.angelEverywhere || Appearance.inirEverywhere ? 6 : 2

    readonly property color cpuColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
        : Appearance.colors.colPrimary
    readonly property color memColor: Appearance.angelEverywhere ? Appearance.angel.colSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colSecondary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondary
        : Appearance.colors.colSecondary
    readonly property color gpuColor: Appearance.angelEverywhere ? Appearance.angel.colTertiary
        : Appearance.inirEverywhere ? Appearance.inir.colTertiary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
        : Appearance.colors.colTertiary
    readonly property color tempColor: Appearance.inirEverywhere ? Appearance.inir.colError
        : Appearance.colors.colError
    readonly property color diskColor: Appearance.colors.colTertiaryContainer

    // Animation duration for smooth value transitions
    readonly property int _animDuration: 1200

    Component.onCompleted: if (root._active) ResourceUsage.keepAlive()
    Component.onDestruction: if (root._active) ResourceUsage.releaseKeepAlive()
    on_ActiveChanged: {
        if (_active) ResourceUsage.keepAlive();
        else ResourceUsage.releaseKeepAlive();
    }

    // ── Card background ──
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1

    WidgetSurface {
        anchors.fill: parent
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

    // ══════════════════════════════════════════════════════════
    // BARS MODE — horizontal fill bars with icon + percentage
    // ══════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._innerMargin
        spacing: Appearance.sizes.spacingSmall ?? 4
        opacity: 1.0 - root.dimFactor * 0.6
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
                    color: ColorUtils.applyAlpha(root.colText, root.fillOpacity)
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
        opacity: 1.0 - root.dimFactor * 0.6
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
                color: ColorUtils.applyAlpha(root.colText, 0.3)
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
                color: ColorUtils.applyAlpha(root.colText, 0.06)
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
        opacity: 1.0 - root.dimFactor * 0.6
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
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: ringCol.modelData.label
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
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
        opacity: 1.0 - root.dimFactor * 0.6
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
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
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
}
