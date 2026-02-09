import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:"

Item {
    id: root
    property int margin: 10

    Component.onCompleted: ResourceUsage.ensureRunning()
    Component.onDestruction: ResourceUsage.stop()

    // Style tokens
    readonly property color colText: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0
    readonly property color colBorder: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property int borderWidth: Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
    readonly property real radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 10

        // Header with refresh button
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("System Monitor")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: root.colText
            }

            RippleButton {
                implicitWidth: 28; implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer1Hover
                onClicked: ResourceUsage.ensureRunning()
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 16; color: root.colTextSecondary }
                StyledToolTip { text: Translation.tr("Refresh") }
            }
        }

        // Scrollable content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: root.radius
            color: root.colBg
            border.width: root.borderWidth
            border.color: root.colBorder
            clip: true

            Flickable {
                anchors.fill: parent
                contentHeight: statsColumn.implicitHeight + 20
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: statsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 14

                    // CPU Section
                    SysStatCard {
                        icon: "memory"
                        title: "CPU"
                        valueText: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                        subText: ResourceUsage.maxAvailableCpuString
                        graphValues: ResourceUsage.cpuUsageHistory
                        graphColor: Appearance.colors.colPrimary
                        showGraph: true
                    }

                    // RAM Section
                    SysStatCard {
                        icon: "memory_alt"
                        title: "RAM"
                        valueText: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
                        subText: formatBytes(ResourceUsage.memoryUsed * 1024) + " / " + formatBytes(ResourceUsage.memoryTotal * 1024)
                        graphValues: ResourceUsage.memoryUsageHistory
                        graphColor: Appearance.colors.colSecondary
                        showGraph: true
                    }

                    // Swap Section (only if swap exists)
                    SysStatCard {
                        visible: ResourceUsage.swapTotal > 1024
                        icon: "swap_horiz"
                        title: "Swap"
                        valueText: Math.round(ResourceUsage.swapUsedPercentage * 100) + "%"
                        subText: formatBytes(ResourceUsage.swapUsed * 1024) + " / " + formatBytes(ResourceUsage.swapTotal * 1024)
                        graphValues: ResourceUsage.swapUsageHistory
                        graphColor: Appearance.colors.colTertiary
                        showGraph: true
                    }

                    // Disk Section
                    SysStatCard {
                        icon: "hard_drive"
                        title: Translation.tr("Disk")
                        valueText: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%"
                        subText: formatBytes(ResourceUsage.diskUsed) + " / " + formatBytes(ResourceUsage.diskTotal)
                        progressValue: ResourceUsage.diskUsedPercentage
                        progressColor: ResourceUsage.diskUsedPercentage > 0.9 ? Appearance.colors.colError : Appearance.colors.colPrimary
                        showGraph: false
                    }

                    // Temperature Section (only if sensors detected)
                    SysStatCard {
                        visible: ResourceUsage.cpuTemp > 0 || ResourceUsage.gpuTemp > 0
                        icon: "thermostat"
                        title: Translation.tr("Temperature")
                        valueText: ResourceUsage.maxTemp + "°C"
                        subText: {
                            let parts = []
                            if (ResourceUsage.cpuTemp > 0) parts.push("CPU: " + ResourceUsage.cpuTemp + "°C")
                            if (ResourceUsage.gpuTemp > 0) parts.push("GPU: " + ResourceUsage.gpuTemp + "°C")
                            return parts.join(" • ")
                        }
                        progressValue: ResourceUsage.tempPercentage
                        progressColor: ResourceUsage.maxTemp >= ResourceUsage.tempWarningThreshold
                            ? Appearance.colors.colError
                            : ResourceUsage.maxTemp >= 60
                                ? Appearance.colors.colWarning ?? "#FFA500"
                                : Appearance.colors.colPrimary
                        showGraph: false
                    }

                    // Network Section
                    NetworkStats {}
                }
            }
        }
    }

    // Helper function
    function formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    // ═══════════════════════════════════════════
    // INLINE COMPONENTS
    // ═══════════════════════════════════════════

    component SysStatCard: ColumnLayout {
        required property string icon
        required property string title
        required property string valueText
        property string subText: ""
        property list<real> graphValues: []
        property color graphColor: Appearance.colors.colPrimary
        property real progressValue: -1
        property color progressColor: Appearance.colors.colPrimary
        property bool showGraph: false

        Layout.fillWidth: true
        spacing: 6

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: icon
                iconSize: 18
                color: graphColor
            }

            StyledText {
                text: title
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.colText
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: valueText
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                font.family: Appearance.font.family.numbers
                color: graphColor
            }
        }

        // Graph (for CPU/RAM/Swap)
        Item {
            visible: showGraph && graphValues.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                    : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1, 0.5)
                    : Appearance.colors.colLayer1
            }

            Graph {
                anchors.fill: parent
                anchors.margins: 2

                property real maxValue: {
                    let max = 0
                    for (let i = 0; i < graphValues.length; i++) {
                        if (graphValues[i] > max) max = graphValues[i]
                    }
                    return max > 0.1 ? max : 1
                }

                values: {
                    let res = []
                    for (let i = 0; i < graphValues.length; i++) {
                        res.push(graphValues[i] / maxValue)
                    }
                    return res
                }

                color: graphColor
                fillOpacity: 0.25
                alignment: Graph.Alignment.Right
            }
        }

        // Progress bar (for Disk/Temp)
        StyledProgressBar {
            visible: !showGraph && progressValue >= 0
            Layout.fillWidth: true
            value: progressValue
            highlightColor: progressColor
            trackColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colSecondaryContainer
        }

        // Subtext
        StyledText {
            visible: subText !== ""
            Layout.fillWidth: true
            text: subText
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.colTextSecondary
        }
    }

    component NetworkStats: ColumnLayout {
        id: netStats
        Layout.fillWidth: true
        spacing: 6

        property string rxSpeed: "0 B/s"
        property string txSpeed: "0 B/s"
        property real lastRx: 0
        property real lastTx: 0
        property real lastTime: 0

        Timer {
            running: GlobalStates.sidebarRightOpen
            interval: 2000
            repeat: true
            triggeredOnStart: true
            onTriggered: netProc.running = true
        }

        Process {
            id: netProc
            command: ["/usr/bin/cat", "/proc/net/dev"]
            running: false
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => {
                    const lines = data.split("\n")
                    let totalRx = 0, totalTx = 0
                    for (const line of lines) {
                        if (line.includes(":") && !line.includes("lo:")) {
                            const parts = line.split(/\s+/).filter(p => p)
                            if (parts.length >= 10) {
                                totalRx += parseInt(parts[1]) || 0
                                totalTx += parseInt(parts[9]) || 0
                            }
                        }
                    }

                    const now = Date.now()
                    if (netStats.lastTime > 0) {
                        const dt = (now - netStats.lastTime) / 1000
                        if (dt > 0) {
                            netStats.rxSpeed = netStats.formatSpeed((totalRx - netStats.lastRx) / dt)
                            netStats.txSpeed = netStats.formatSpeed((totalTx - netStats.lastTx) / dt)
                        }
                    }
                    netStats.lastRx = totalRx
                    netStats.lastTx = totalTx
                    netStats.lastTime = now
                }
            }
        }

        function formatSpeed(bytesPerSec) {
            if (bytesPerSec < 1024) return bytesPerSec.toFixed(0) + " B/s"
            if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        }

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "swap_vert"
                iconSize: 18
                color: Appearance.colors.colTertiary
            }

            StyledText {
                text: Translation.tr("Network")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.colText
            }

            Item { Layout.fillWidth: true }
        }

        // Speed indicators
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            RowLayout {
                spacing: 4
                MaterialSymbol { text: "arrow_downward"; iconSize: 14; color: Appearance.colors.colPrimary }
                StyledText {
                    text: rxSpeed
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.numbers
                    color: root.colText
                }
            }

            RowLayout {
                spacing: 4
                MaterialSymbol { text: "arrow_upward"; iconSize: 14; color: Appearance.colors.colSecondary }
                StyledText {
                    text: txSpeed
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.numbers
                    color: root.colText
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
