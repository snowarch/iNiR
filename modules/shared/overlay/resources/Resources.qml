pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.overlay

// The machine at a glance: the chosen meter large with its trace, all four beneath to pick from.
StyledOverlayWidget {
    id: root

    property QtObject resourceMonitor: ResourceUsageMonitor { target: root }
    readonly property int selected: Math.max(0, Math.min(root.metrics.length - 1, Persistent.states.overlay.resources?.tabIndex ?? 0))
    readonly property var current: root.metrics[root.selected]

    function gb(kb: real): string { return (kb / (1024 * 1024)).toFixed(1) }
    function percent(v: real): string { return isFinite(v) ? Math.round(v * 100) + "%" : "--" }
    readonly property var metrics: [
        {
            glyph: "planner_review",
            label: Translation.tr("CPU"),
            value: ResourceUsage.cpuUsage,
            history: ResourceUsage.cpuUsageHistory,
            total: ResourceUsage.maxAvailableCpuString,
            detail: ResourceUsage.cpuTemp > 0 ? Translation.tr("Temp: %1°C").arg(ResourceUsage.cpuTemp) : "",
            hot: ResourceUsage.cpuTemp >= ResourceUsage.tempWarningThreshold
        },
        {
            glyph: "memory_alt",
            label: Translation.tr("GPU"),
            value: ResourceUsage.gpuUsage,
            history: ResourceUsage.gpuUsageHistory,
            total: ResourceUsage.maxAvailableGpuString,
            detail: ResourceUsage.gpuTemp > 0 ? Translation.tr("Temp: %1°C").arg(ResourceUsage.gpuTemp) : "",
            hot: ResourceUsage.gpuTemp >= ResourceUsage.tempWarningThreshold
        },
        {
            glyph: "memory",
            label: Translation.tr("RAM"),
            value: ResourceUsage.memoryUsedPercentage,
            history: ResourceUsage.memoryUsageHistory,
            total: ResourceUsage.maxAvailableMemoryString,
            detail: Translation.tr("Used: %1 GB").arg(root.gb(ResourceUsage.memoryUsed)),
            hot: false
        },
        {
            glyph: "swap_horiz",
            label: Translation.tr("Swap"),
            value: ResourceUsage.swapUsedPercentage,
            history: ResourceUsage.swapUsageHistory,
            total: ResourceUsage.maxAvailableSwapString,
            detail: Translation.tr("Used: %1 GB").arg(root.gb(ResourceUsage.swapUsed)),
            hot: false
        }
    ]

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(300 * root.d)
        implicitHeight: Math.round(220 * root.d)

        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(8 * root.d)

            // The chosen meter: its figure over its trace.
            Rectangle {
                id: trace
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: OverlayLook.roundingNormal
                color: OverlayLook.colRecessed
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: trace.width
                        height: trace.height
                        radius: trace.radius
                    }
                }

                // The trace lives under the figure, so a high value never runs into the text.
                Graph {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.top: readout.bottom
                    anchors.topMargin: Math.round(6 * root.d)
                    values: root.current.history
                    points: ResourceUsage.historyLength
                    alignment: Graph.Alignment.Right
                    color: OverlayLook.colPrimary
                    fillOpacity: 0.22
                }

                Column {
                    id: readout
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Math.round(12 * root.d)
                    spacing: 0
                    Row {
                        spacing: Math.round(6 * root.d)
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.current.glyph
                            iconSize: Math.round(16 * root.d)
                            fill: 1
                            color: OverlayLook.colPrimary
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.current.label
                            color: OverlayLook.colSubtext
                            font.family: OverlayLook.fontMain
                            font.pixelSize: OverlayLook.typeMeta
                            font.weight: Font.DemiBold
                        }
                    }
                    StyledText {
                        text: root.percent(root.current.value)
                        color: OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: OverlayLook.typeFigure
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: [Translation.tr("of %1").arg(root.current.total), root.current.detail].filter(s => s.length > 0).join("  ·  ")
                        color: root.current.hot ? OverlayLook.colError : OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                    }
                }
            }

            // All four, to pick from.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(4 * root.d)
                Repeater {
                    model: root.metrics
                    MouseArea {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool chosen: cell.index === root.selected
                        Layout.fillWidth: true
                        implicitHeight: Math.round(46 * root.d)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: cell.modelData.label
                        Accessible.checked: cell.chosen
                        onClicked: Persistent.states.overlay.resources.tabIndex = cell.index

                        Rectangle {
                            anchors.fill: parent
                            radius: OverlayLook.roundingSmall
                            color: cell.chosen ? OverlayLook.colToggle : cell.containsMouse ? OverlayLook.colLayer2Hover : "transparent"
                            Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
                        }
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Math.round(8 * root.d)
                            anchors.rightMargin: Math.round(8 * root.d)
                            spacing: Math.round(3 * root.d)
                            Row {
                                width: parent.width
                                StyledText {
                                    width: parent.width - cellValue.width
                                    elide: Text.ElideRight
                                    text: cell.modelData.label
                                    color: cell.chosen ? OverlayLook.colOnToggle : OverlayLook.colSubtext
                                    font.family: OverlayLook.fontMain
                                    font.pixelSize: OverlayLook.typeFootnote
                                    font.weight: Font.DemiBold
                                }
                                StyledText {
                                    id: cellValue
                                    text: root.percent(cell.modelData.value)
                                    color: cell.modelData.hot ? OverlayLook.colError : cell.chosen ? OverlayLook.colOnToggle : OverlayLook.colOnLayer1
                                    font.family: OverlayLook.fontNumbers
                                    font.features: ({ "tnum": 1 })
                                    font.pixelSize: OverlayLook.typeMeta
                                    font.weight: Font.DemiBold
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: Math.round(3 * root.d)
                                radius: height / 2
                                color: OverlayLook.colRecessed
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, cell.modelData.value))
                                    height: parent.height
                                    radius: height / 2
                                    color: cell.modelData.hot ? OverlayLook.colError : OverlayLook.colPrimary
                                    Behavior on width { NumberAnimation { duration: FamilyStyle.moveDuration; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
