pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root

    title: Translation.tr("Game Performance")
    panelOpacityOverride: root.gamePerformanceBackgroundOpacity
    titlebarActionSymbol: root.viewButtonIcon()
    titlebarActionTooltip: root.viewButtonTooltip()
    onTitlebarActionClicked: root.cycleViewMode()
    minimumWidth: root.detailedView ? 620 : root.simpleView ? 460
        : root.compactView ? 390 : 360
    minimumHeight: root.detailedView
        ? (GamePerformanceService.gameDetected ? 980 : 720)
        : root.simpleView ? 360 : root.compactView ? 220 : 210

    property bool _holdingTelemetry: false
    readonly property string viewMode: {
        // Keep persisted mode names stable while adding the minimal readout.
        const stored = String(root.persistentStateEntry?.viewMode ?? "")
        if (stored === "minimal" || stored === "simple"
            || stored === "compact" || stored === "detailed")
            return stored
        return root.persistentStateEntry?.detailed ? "detailed" : "minimal"
    }
    readonly property bool minimalView: root.viewMode === "minimal"
    readonly property bool simpleView: root.viewMode === "simple"
    readonly property bool compactView: root.viewMode === "compact"
    readonly property bool detailedView: root.viewMode === "detailed"
    // Keep the reference HUD hues while giving the active theme a visible voice.
    readonly property color minimalGpuAccent: ColorUtils.mix(
        Qt.rgba(0, 0.862745, 0.596078, 1), Appearance.colors.colPrimary, 0.60)
    readonly property color minimalCpuAccent: ColorUtils.mix(
        Qt.rgba(0, 0.662745, 0.909804, 1), Appearance.colors.colSecondary, 0.60)
    readonly property color minimalThreadAccent: ColorUtils.mix(
        Qt.rgba(0.701961, 0.301961, 1, 1), Appearance.colors.colTertiary, 0.60)
    readonly property color minimalFpsAccent: ColorUtils.mix(
        Qt.rgba(1, 0.254902, 0.278431, 1), Appearance.colors.colError, 0.60)
    readonly property real gamePerformanceBackgroundOpacity: {
        const gamePerformance = Config.options?.overlay?.gamePerformance ?? ({})
        if (gamePerformance.transparentBackground === true) return 0
        const localValue = Number(gamePerformance.backgroundOpacity ?? -1)
        const globalValue = Number(Config.options?.overlay?.backgroundOpacity ?? 0.9)
        const value = isFinite(localValue) && localValue >= 0 ? localValue : globalValue
        return Math.max(0, Math.min(1, isFinite(value) ? value : 0.9))
    }

    function syncTelemetry(): void {
        const shouldHold = root.visible
        if (shouldHold && !root._holdingTelemetry) {
            root._holdingTelemetry = true
            GamePerformanceService.acquire()
        } else if (!shouldHold && root._holdingTelemetry) {
            root._holdingTelemetry = false
            GamePerformanceService.release()
        }
    }

    function syncModeGeometry(): void {
        if (!Persistent.ready || !root.persistentStateEntry) return

        switch (root.viewMode) {
        case "minimal":
            root.persistentStateEntry.width = 360
            root.persistentStateEntry.height = 210
            break
        case "simple":
            root.persistentStateEntry.width = 460
            root.persistentStateEntry.height = 360
            break
        case "compact":
            root.persistentStateEntry.width = 390
            root.persistentStateEntry.height = 220
            break
        case "detailed":
            root.persistentStateEntry.width = 620
            root.persistentStateEntry.height = GamePerformanceService.gameDetected ? 980 : 720
            break
        default:
            root.persistentStateEntry.width = 360
            root.persistentStateEntry.height = 210
            break
        }
    }

    function setViewMode(mode: string): void {
        root.persistentStateEntry.viewMode = mode
        root.persistentStateEntry.detailed = mode === "detailed"
        root.syncModeGeometry()
    }

    function cycleViewMode(): void {
        const modes = ["minimal", "simple", "compact", "detailed"]
        const currentIndex = modes.indexOf(root.viewMode)
        root.setViewMode(modes[(currentIndex + 1) % modes.length])
    }

    function viewButtonIcon(): string {
        switch (root.viewMode) {
        case "minimal": return "view_compact"
        case "simple": return "show_chart"
        case "compact": return "analytics"
        case "detailed": return "view_list"
        default: return "view_compact"
        }
    }

    function viewButtonTooltip(): string {
        switch (root.viewMode) {
        case "minimal": return Translation.tr("Switch to simple view")
        case "simple": return Translation.tr("Switch to compact view")
        case "compact": return Translation.tr("Switch to detailed view")
        case "detailed": return Translation.tr("Switch to minimal view")
        default: return Translation.tr("Switch to minimal view")
        }
    }

    function statusText(): string {
        switch (GamePerformanceService.telemetryState) {
        case "live": return Translation.tr("Live MangoHud telemetry")
        case "logging-not-configured": return Translation.tr("MangoHud logging is not active")
        case "mangohud-missing": return Translation.tr("MangoHud is not installed")
        default: return Translation.tr("Focus a game")
        }
    }

    function statusDetail(): string {
        return GamePerformanceService.gameDetected
            ? Translation.tr("Launch with MangoHud logging to enable FPS and frametime")
            : Translation.tr("Focus a game window to start renderer telemetry")
    }

    function percentText(value: real): string {
        return value >= 0 ? Math.round(value) + "%" : "--"
    }

    function temperatureText(value: real): string {
        return value > 0 ? Math.round(value) + " C" : "--"
    }

    function gbText(value: real): string {
        return value >= 0 ? value.toFixed(1) + " GB" : "--"
    }

    function fpsText(value: real): string {
        return value >= 0 ? Math.round(value) + "" : "--"
    }

    function msText(value: real): string {
        return value >= 0 ? value.toFixed(1) + " ms" : "--"
    }

    function mhzText(value: real): string {
        return value > 0 ? Math.round(value) + " MHz" : "--"
    }

    function voltageText(value: real): string {
        return value > 0 ? value.toFixed(2) + " V" : "--"
    }

    function wattsText(value: real): string {
        return value > 0 ? value.toFixed(0) + " W" : "--"
    }

    function coreCountText(): string {
        return GamePerformanceService.cpuCoreCount > 0
            ? GamePerformanceService.cpuCoreCount + " logical cores" : "--"
    }

    function coreAverageText(): string {
        const values = GamePerformanceService.cpuCoreLoads.filter(value => value >= 0)
        if (values.length === 0) return "--"
        let total = 0
        for (const value of values) total += value
        return Math.round(total / values.length) + "% avg"
    }

    function coreLoadText(): string {
        const values = GamePerformanceService.cpuCoreLoads.filter(value => value >= 0)
        if (values.length === 0) return "--"
        let total = 0
        for (const value of values) total += value
        return Math.round(total / values.length) + "%"
    }

    function degreeText(value: real): string {
        return value > 0 ? Math.round(value) + String.fromCharCode(176) : "--"
    }

    function minimalFpsText(value: real): string {
        return value >= 0 ? Math.round(value) + "F" : "--"
    }

    function vramDetailText(): string {
        return GamePerformanceService.vramTotalGb > 0
            ? root.gbText(GamePerformanceService.vramTotalGb) + " total"
            : Translation.tr("System VRAM")
    }

    function framePacingText(): string {
        return GamePerformanceService.framePacingPercent >= 0
            ? root.percentText(GamePerformanceService.framePacingPercent) : "--"
    }

    readonly property color statusColor: GamePerformanceService.telemetryAvailable
        ? Appearance.colors.colPrimary
        : GamePerformanceService.gameDetected
            ? Appearance.colors.colTertiary
            : Appearance.colors.colSubtext

    Component.onCompleted: {
        root.syncTelemetry()
        if (Persistent.ready) Qt.callLater(root.syncModeGeometry)
    }
    onVisibleChanged: root.syncTelemetry()
    Component.onDestruction: if (root._holdingTelemetry) {
        root._holdingTelemetry = false
        GamePerformanceService.release()
    }

    Connections {
        target: GamePerformanceService
        function onGameDetectedChanged(): void {
            if (root.detailedView) root.syncModeGeometry()
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged(): void {
            if (Persistent.ready) root.syncModeGeometry()
        }
    }

    contentItem: OverlayBackground {
        id: surface
        radius: root.contentRadius
        surfaceOpacity: root.gamePerformanceBackgroundOpacity
        property real padding: 12
        implicitWidth: body.implicitWidth + padding * 2
        implicitHeight: body.implicitHeight + padding * 2

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: surface.padding
            spacing: 9

            RowLayout {
                visible: !root.minimalView
                Layout.fillWidth: true
                spacing: 9

                MaterialSymbol {
                    text: "sports_esports"
                    iconSize: 24
                    color: root.statusColor
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: GamePerformanceService.gameDetected
                            ? GamePerformanceService.gameName
                            : Translation.tr("No game selected")
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.statusText()
                        color: root.statusColor
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: GameMode.active
                    radius: height / 2
                    color: Appearance.colors.colSecondaryContainer
                    implicitWidth: modeLabel.implicitWidth + 16
                    implicitHeight: modeLabel.implicitHeight + 8

                    StyledText {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: Translation.tr("GAME MODE")
                        color: Appearance.colors.colOnSecondaryContainer
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Bold
                    }
                }
            }

            ColumnLayout {
                visible: root.minimalView
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1

                MinimalMetric {
                    label: "GPU"
                    value: root.percentText(GamePerformanceService.gpuLoad)
                    detail: root.degreeText(GamePerformanceService.gpuTemp)
                    accent: root.minimalGpuAccent
                }
                MinimalMetric {
                    label: "CPU"
                    value: root.percentText(GamePerformanceService.cpuLoad)
                    detail: root.degreeText(GamePerformanceService.cpuTemp)
                    accent: root.minimalCpuAccent
                }
                MinimalMetric {
                    label: "THR."
                    value: root.coreLoadText()
                    detail: root.degreeText(GamePerformanceService.cpuTemp)
                    accent: root.minimalThreadAccent
                }
                MinimalMetric {
                    label: "FPS"
                    value: root.minimalFpsText(GamePerformanceService.fps)
                    detail: root.minimalFpsText(GamePerformanceService.averageFps)
                    accent: root.minimalFpsAccent
                }
            }

            Rectangle {
                visible: root.simpleView || root.detailedView
                Layout.fillWidth: true
                implicitHeight: GamePerformanceService.gameDetected
                    ? (GamePerformanceService.telemetryAvailable ? 204 : 258) : 76
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 6

                    RowLayout {
                        visible: GamePerformanceService.gameDetected
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        ColumnLayout {
                            Layout.preferredWidth: 74
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            StyledText {
                                text: root.fpsText(GamePerformanceService.fps)
                                font.family: Appearance.font.family.numbers
                                font.pixelSize: Appearance.font.pixelSize.huge
                                font.weight: Font.Bold
                                color: GamePerformanceService.telemetryAvailable
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                text: Translation.tr("FPS")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Bold
                            }
                            StyledText {
                                text: root.msText(GamePerformanceService.frametime)
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                        }

                        SparklinePanel {
                            title: Translation.tr("FPS")
                            values: GamePerformanceService.fpsGraphValues
                            scaleText: GamePerformanceService.telemetryAvailable
                                ? root.percentileText(GamePerformanceService.fpsGraphScale) : ""
                            accent: Appearance.colors.colPrimary
                        }
                        SparklinePanel {
                            title: Translation.tr("FRAME TIME")
                            values: GamePerformanceService.frametimeGraphValues
                            scaleText: GamePerformanceService.telemetryAvailable
                                ? root.msText(GamePerformanceService.frametimeGraphScale) : ""
                            accent: Appearance.colors.colSecondary
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 62
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            PerformanceStat { label: Translation.tr("AVG"); value: root.fpsText(GamePerformanceService.averageFps) }
                            PerformanceStat { label: Translation.tr("MIN"); value: root.fpsText(GamePerformanceService.minimumFps) }
                            PerformanceStat { label: Translation.tr("MAX"); value: root.fpsText(GamePerformanceService.maximumFps) }
                            PerformanceStat { label: Translation.tr("1% LOW"); value: root.fpsText(GamePerformanceService.onePercentLow) }
                        }
                    }

                    RowLayout {
                        visible: GamePerformanceService.gameDetected
                        Layout.fillWidth: true
                        FrameStat { label: Translation.tr("AVG FRAME"); value: root.msText(GamePerformanceService.averageFrametime) }
                        FrameStat { label: Translation.tr("MIN"); value: root.msText(GamePerformanceService.minimumFrametime) }
                        FrameStat { label: Translation.tr("MAX"); value: root.msText(GamePerformanceService.maximumFrametime) }
                        FrameStat { label: Translation.tr("JITTER"); value: root.msText(GamePerformanceService.framePacingJitterMs) }
                        FrameStat { label: Translation.tr("PACE"); value: root.framePacingText() }
                    }

                    StateBanner {
                        visible: !GamePerformanceService.gameDetected
                        message: Translation.tr("Focus a game window")
                        detail: root.statusDetail()
                    }
                    StateBanner {
                        visible: GamePerformanceService.gameDetected && !GamePerformanceService.telemetryAvailable
                        message: root.statusText()
                        detail: root.statusDetail()
                    }
                }
            }

            GridLayout {
                visible: root.compactView
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 6
                rowSpacing: 6

                CompactStat { label: Translation.tr("FPS"); value: root.fpsText(GamePerformanceService.fps); accent: Appearance.colors.colPrimary }
                CompactStat { label: Translation.tr("FRAME"); value: root.msText(GamePerformanceService.frametime); accent: Appearance.colors.colPrimary }
                CompactStat { label: Translation.tr("AVG"); value: root.fpsText(GamePerformanceService.averageFps); accent: Appearance.colors.colSecondary }
                CompactStat { label: Translation.tr("MIN"); value: root.fpsText(GamePerformanceService.minimumFps); accent: Appearance.colors.colSecondary }
                CompactStat { label: Translation.tr("MAX"); value: root.fpsText(GamePerformanceService.maximumFps); accent: Appearance.colors.colSecondary }
                CompactStat { label: Translation.tr("CPU"); value: root.percentText(GamePerformanceService.cpuLoad); accent: Appearance.colors.colPrimary }
                CompactStat { label: Translation.tr("GPU"); value: root.percentText(GamePerformanceService.gpuLoad); accent: Appearance.colors.colSecondary }
                CompactStat { label: Translation.tr("VRAM"); value: root.gbText(GamePerformanceService.vramUsedGb); accent: Appearance.colors.colTertiary }
                CompactStat { label: Translation.tr("RAM"); value: root.gbText(GamePerformanceService.ramUsedGb); accent: Appearance.colors.colTertiary }
            }

            ColumnLayout {
                visible: root.detailedView
                Layout.fillWidth: true
                spacing: 7

                SectionHeader {
                    title: Translation.tr("RIG TELEMETRY")
                    detail: Translation.tr("Live host sensors")
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 7
                    rowSpacing: 7

                    MetricCard {
                        icon: "memory"
                        label: Translation.tr("CPU")
                        value: root.percentText(GamePerformanceService.cpuLoad)
                        detail: root.temperatureText(GamePerformanceService.cpuTemp)
                        progress: GamePerformanceService.cpuLoad
                        accent: Appearance.colors.colPrimary
                    }
                    MetricCard {
                        icon: "speed"
                        label: Translation.tr("CPU FREQ")
                        value: root.mhzText(GamePerformanceService.cpuFrequencyMhz)
                        detail: Translation.tr("Current frequency")
                        accent: Appearance.colors.colPrimary
                    }
                    MetricCard {
                        icon: "developer_board"
                        label: Translation.tr("CPU CORES")
                        value: GamePerformanceService.cpuCoreCount > 0
                            ? GamePerformanceService.cpuCoreCount + "" : "--"
                        detail: Translation.tr("Logical cores")
                        accent: Appearance.colors.colPrimary
                    }
                    MetricCard {
                        icon: "developer_board"
                        label: Translation.tr("GPU")
                        value: root.percentText(GamePerformanceService.gpuLoad)
                        detail: root.temperatureText(GamePerformanceService.gpuTemp)
                        progress: GamePerformanceService.gpuLoad
                        accent: Appearance.colors.colSecondary
                    }
                    MetricCard {
                        icon: "memory"
                        label: Translation.tr("GPU CORE")
                        value: root.mhzText(GamePerformanceService.gpuCoreClockMhz)
                        detail: Translation.tr("Core clock")
                        accent: Appearance.colors.colSecondary
                    }
                    MetricCard {
                        icon: "memory_alt"
                        label: Translation.tr("GPU MEM")
                        value: root.mhzText(GamePerformanceService.gpuMemoryClockMhz)
                        detail: Translation.tr("Memory clock")
                        accent: Appearance.colors.colSecondary
                    }
                    MetricCard {
                        icon: "memory_alt"
                        label: Translation.tr("VRAM")
                        value: root.gbText(GamePerformanceService.vramUsedGb)
                        detail: root.vramDetailText()
                        progress: GamePerformanceService.vramUsagePercent
                        accent: Appearance.colors.colTertiary
                    }
                    MetricCard {
                        icon: "bolt"
                        label: Translation.tr("GPU POWER")
                        value: root.wattsText(GamePerformanceService.gpuPower)
                        detail: Translation.tr("Board draw")
                        accent: Appearance.colors.colSecondary
                    }
                    MetricCard {
                        icon: "storage"
                        label: Translation.tr("RAM")
                        value: root.gbText(GamePerformanceService.ramUsedGb)
                        detail: GamePerformanceService.ramTotalGb > 0
                            ? "/ " + root.gbText(GamePerformanceService.ramTotalGb) : ""
                        progress: GamePerformanceService.ramTotalGb > 0
                            ? GamePerformanceService.ramUsedGb / GamePerformanceService.ramTotalGb * 100 : -1
                        accent: Appearance.colors.colTertiary
                    }
                    MetricCard {
                        icon: "swap_horiz"
                        label: Translation.tr("SWAP")
                        value: root.gbText(GamePerformanceService.swapUsedGb)
                        detail: GamePerformanceService.swapTotalGb > 0
                            ? "/ " + root.gbText(GamePerformanceService.swapTotalGb) : ""
                        progress: GamePerformanceService.swapTotalGb > 0
                            ? GamePerformanceService.swapUsedGb / GamePerformanceService.swapTotalGb * 100 : -1
                        accent: Appearance.colors.colTertiary
                    }
                    MetricCard {
                        icon: "hard_drive"
                        label: Translation.tr("DISK")
                        value: root.percentText(GamePerformanceService.diskUsagePercent)
                        detail: GamePerformanceService.diskTotalGb > 0
                            ? root.gbText(GamePerformanceService.diskUsedGb) + " / "
                                + root.gbText(GamePerformanceService.diskTotalGb) : ""
                        progress: GamePerformanceService.diskUsagePercent
                        accent: Appearance.colors.colTertiary
                    }
                    MetricCard {
                        icon: "memory"
                        label: Translation.tr("GAME RAM")
                        value: root.gbText(GamePerformanceService.processMemoryGb)
                        detail: Translation.tr("Process RSS")
                        accent: Appearance.colors.colTertiary
                    }
                    MetricCard {
                        icon: "bolt"
                        label: Translation.tr("CPU POWER")
                        value: root.wattsText(GamePerformanceService.cpuPower)
                        detail: Translation.tr("Package draw")
                        accent: Appearance.colors.colPrimary
                    }
                    MetricCard {
                        icon: "electric_bolt"
                        label: Translation.tr("VOLTAGE")
                        value: root.voltageText(GamePerformanceService.gpuVoltage)
                        detail: Translation.tr("GPU voltage")
                        accent: Appearance.colors.colSecondary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainer

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: Translation.tr("CPU CORE LOAD")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Bold
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: GamePerformanceService.cpuCoreLoads.length > 0
                                    ? Translation.tr("%1 | %2")
                                        .arg(root.coreCountText()).arg(root.coreAverageText())
                                    : root.coreCountText()
                                horizontalAlignment: Text.AlignRight
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                        }

                        Row {
                            id: coreBars
                            Layout.fillWidth: true
                            spacing: 2

                            Repeater {
                                id: coreBarRepeater
                                model: GamePerformanceService.cpuCoreLoads.length

                                delegate: Rectangle {
                                    required property int index
                                    readonly property real load: GamePerformanceService.cpuCoreLoads[index] ?? -1
                                    width: Math.max(4, (coreBars.width
                                        - Math.max(0, coreBarRepeater.count - 1) * coreBars.spacing)
                                        / Math.max(1, coreBarRepeater.count))
                                    height: 28
                                    radius: 3
                                    color: load >= 0
                                        ? Qt.rgba(Appearance.colors.colPrimary.r,
                                            Appearance.colors.colPrimary.g,
                                            Appearance.colors.colPrimary.b,
                                            0.2 + Math.min(0.8, load / 100))
                                        : Appearance.colors.colLayer2

                                    StyledText {
                                        anchors.centerIn: parent
                                        visible: parent.width >= 22 && parent.load >= 0
                                        text: Math.round(parent.load)
                                        color: Appearance.colors.colOnPrimary
                                        font.family: Appearance.font.family.numbers
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: rigIdentity.implicitHeight + 18
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainer

                    ColumnLayout {
                        id: rigIdentity
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        spacing: 4

                        SectionHeader {
                            title: Translation.tr("RIG DETAILS")
                            detail: GamePerformanceService.distroName
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                InfoLine { label: Translation.tr("CPU"); value: GamePerformanceService.cpuName }
                                InfoLine { label: Translation.tr("Cores"); value: root.coreCountText() }
                                InfoLine { label: Translation.tr("RAM"); value: root.gbText(GamePerformanceService.ramTotalGb) }
                                InfoLine { label: Translation.tr("Display"); value: GamePerformanceService.displayResolution }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                InfoLine { label: Translation.tr("GPU"); value: GamePerformanceService.gpuName }
                                InfoLine { label: Translation.tr("VRAM"); value: root.gbText(GamePerformanceService.vramTotalGb) }
                                InfoLine { label: Translation.tr("Driver"); value: GamePerformanceService.gpuDriver }
                                InfoLine { label: Translation.tr("Kernel"); value: GamePerformanceService.kernelVersion }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: GamePerformanceService.gameDetected
                    Layout.fillWidth: true
                    implicitHeight: sessionInfo.implicitHeight + 18
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainer

                    ColumnLayout {
                        id: sessionInfo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        spacing: 4

                        SectionHeader {
                            title: Translation.tr("GAME SESSION")
                            detail: GamePerformanceService.telemetryAvailable
                                ? Translation.tr("Sample age %1 ms").arg(GamePerformanceService.sampleAgeMs)
                                : Translation.tr("Waiting for MangoHud")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            ColumnLayout {
                                Layout.fillWidth: true
                                InfoLine { label: Translation.tr("Graphics API"); value: GamePerformanceService.graphicsApi }
                                InfoLine { label: Translation.tr("Wine / Proton"); value: GamePerformanceService.wineProtonVersion }
                                InfoLine { label: Translation.tr("Resolution"); value: GamePerformanceService.gameResolution || GamePerformanceService.displayResolution }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                InfoLine { label: Translation.tr("MangoHud"); value: GamePerformanceService.mangoHudVersion }
                                InfoLine { label: Translation.tr("FEX stats"); value: GamePerformanceService.fexStats }
                                InfoLine { label: Translation.tr("Frame pacing"); value: root.msText(GamePerformanceService.framePacingJitterMs) }
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: GamePerformanceService.telemetryAvailable && !root.minimalView
                Layout.fillWidth: true
                text: Translation.tr("PID %1 | %2 | %3")
                    .arg(GamePerformanceService.gamePid)
                    .arg(GamePerformanceService.gameAppId)
                    .arg(Directories.shortHomePath(GamePerformanceService.mangoHudLogDirectory))
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }
        }
    }

    function percentileText(value: real): string {
        return value > 0 ? "0-" + Math.round(value) + " FPS" : ""
    }

    component SectionHeader: RowLayout {
        required property string title
        property string detail: ""
        Layout.fillWidth: true
        spacing: 6

        StyledText {
            text: parent.title
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.detail
            horizontalAlignment: Text.AlignRight
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
            elide: Text.ElideRight
        }
    }

    component MinimalMetric: RowLayout {
        id: metric
        required property string label
        required property string value
        required property string detail
        required property color accent
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 9

        StyledText {
            Layout.preferredWidth: 76
            text: metric.label
            color: metric.accent
            font.family: Appearance.font.family.monospace
            font.pixelSize: 27
            font.weight: Font.Bold
        }
        StyledText {
            Layout.preferredWidth: 94
            text: metric.value
            horizontalAlignment: Text.AlignRight
            color: Appearance.colors.colOnSurface
            font.family: Appearance.font.family.monospace
            font.pixelSize: 27
            font.weight: Font.Medium
        }
        StyledText {
            Layout.fillWidth: true
            text: metric.detail
            horizontalAlignment: Text.AlignRight
            color: Appearance.colors.colOnSurface
            font.family: Appearance.font.family.monospace
            font.pixelSize: 27
            font.weight: Font.Medium
        }
    }

    component StateBanner: Rectangle {
        id: banner
        required property string message
        required property string detail
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 58
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 9

            MaterialSymbol {
                text: "info"
                iconSize: 21
                color: root.statusColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: banner.message
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: banner.detail
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                }
            }
        }
    }

    component SparklinePanel: Rectangle {
        id: panel
        required property string title
        required property var values
        required property color accent
        property string scaleText: ""

        Layout.fillWidth: true
        Layout.minimumWidth: 118
        Layout.fillHeight: true
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1

        StyledText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 5
            text: panel.title
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
        }
        StyledText {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            text: panel.scaleText
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
        Graph {
            anchors.fill: parent
            anchors.margins: 4
            values: panel.values
            points: panel.values.length
            color: panel.accent
            fillOpacity: 0.22
            lineWidth: 2
            alignment: Graph.Alignment.Right
        }
    }

    component PerformanceStat: ColumnLayout {
        required property string label
        required property string value
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            text: parent.label
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
        }
        StyledText {
            text: parent.value
            font.family: Appearance.font.family.numbers
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
        }
    }

    component FrameStat: ColumnLayout {
        required property string label
        required property string value
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            text: parent.label
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
        }
        StyledText {
            text: parent.value
            color: Appearance.colors.colOnSecondaryContainer
            font.family: Appearance.font.family.numbers
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
    }

    component CompactStat: Rectangle {
        required property string label
        required property string value
        property color accent: Appearance.colors.colPrimary

        Layout.fillWidth: true
        implicitHeight: 44
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0
            StyledText {
                text: parent.parent.label
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
            }
            StyledText {
                text: parent.parent.value
                color: parent.parent.accent
                font.family: Appearance.font.family.numbers
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
            }
        }
    }

    component InfoLine: RowLayout {
        required property string label
        required property string value
        Layout.fillWidth: true
        spacing: 7

        StyledText {
            Layout.preferredWidth: 72
            text: parent.label
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
        StyledText {
            Layout.fillWidth: true
            text: parent.value
            color: Appearance.colors.colOnSurface
            font.pixelSize: Appearance.font.pixelSize.smallest
            elide: Text.ElideRight
        }
    }

    component MetricCard: Rectangle {
        id: card
        required property string icon
        required property string label
        required property string value
        property string detail: ""
        property real progress: -1
        property color accent: Appearance.colors.colPrimary

        Layout.fillWidth: true
        implicitHeight: 63
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 7

            MaterialSymbol {
                text: card.icon
                iconSize: 18
                color: card.accent
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: card.label
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Bold
                    }
                    StyledText {
                        text: card.value
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: card.detail
                    visible: text.length > 0
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: card.progress >= 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: height / 2
                    color: Appearance.colors.colSecondaryContainer
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, card.progress / 100))
                        height: parent.height
                        radius: height / 2
                        color: card.accent
                    }
                }
            }
        }
    }
}
