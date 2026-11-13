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

// The game as it runs: frames per second over the shape of its frame times (a stutter is a spike you can see), the
// four loads beneath; opened up, every sensor, each core and the session MangoHud reports.
StyledOverlayWidget {
    id: root
    resizable: false

    readonly property var g: GamePerformanceService
    readonly property bool detailed: root.persistentStateEntry?.detailed ?? false
    readonly property bool live: root.g.telemetryState === "live"
    property bool _holding: false
    property QtObject resourceMonitor: ResourceUsageMonitor { target: root }

    // overlay.gamePerformance keeps its own plate opacity (Settings), the tool's own slider still wins once pinned.
    panelOpacityOverride: {
        const own = Config.options?.overlay?.gamePerformance ?? ({})
        if (own.transparentBackground === true) return 0
        const v = Number(own.backgroundOpacity ?? -1)
        return isFinite(v) && v >= 0 ? Math.min(1, v) : -1
    }

    titlebarActionSymbol: root.detailed ? "unfold_less" : "unfold_more"
    titlebarActionTooltip: root.detailed ? Translation.tr("Show less") : Translation.tr("Show details")
    onTitlebarActionClicked: {
        const e = root.persistentStateEntry
        e.detailed = !root.detailed
        // Each view takes its own natural size.
        e.width = 0
        e.height = 0
    }

    function hold(): void {
        if (root.visible === root._holding) return
        root._holding = root.visible
        if (root._holding) root.g.acquire(root)
        else root.g.release(root)
    }
    onVisibleChanged: root.hold()
    Component.onCompleted: root.hold()
    Component.onDestruction: if (root._holding) root.g.release(root)

    function ok(v: real): bool { return isFinite(v) && v >= 0 }
    function pct(v: real): string { return root.ok(v) ? Math.round(v) + "%" : "--" }
    function deg(v: real): string { return root.ok(v) && v > 0 ? Math.round(v) + "°" : "" }
    function gb(v: real): string { return root.ok(v) ? v.toFixed(1) + " GB" : "--" }
    function hot(t: real): bool { return root.ok(t) && t >= ResourceUsage.tempWarningThreshold }

    readonly property string statusText: {
        switch (root.g.telemetryState) {
        case "live": return Translation.tr("Live MangoHud telemetry")
        case "logging-not-configured": return Translation.tr("MangoHud logging is not active")
        case "mangohud-missing": return Translation.tr("MangoHud is not installed")
        default: return Translation.tr("No game selected")
        }
    }
    readonly property string statusDetail: root.g.gameDetected
        ? Translation.tr("Launch with MangoHud logging to enable FPS and frametime")
        : Translation.tr("Focus a game to see how it runs")

    readonly property var loads: [
        { label: Translation.tr("CPU"), value: root.pct(root.g.cpuLoad), bar: root.g.cpuLoad / 100, detail: root.deg(root.g.cpuTemp), hot: root.hot(root.g.cpuTemp) },
        { label: Translation.tr("GPU"), value: root.pct(root.g.gpuLoad), bar: root.g.gpuLoad / 100, detail: root.deg(root.g.gpuTemp), hot: root.hot(root.g.gpuTemp) },
        { label: Translation.tr("VRAM"), value: root.gb(root.g.vramUsedGb), bar: root.ok(root.g.vramUsagePercent) ? root.g.vramUsagePercent / 100 : -1, detail: "", hot: false },
        { label: Translation.tr("RAM"), value: root.gb(root.g.ramUsedGb), bar: root.g.ramTotalGb > 0 ? root.g.ramUsedGb / root.g.ramTotalGb : -1, detail: "", hot: false }
    ]
    // Only what this machine reports.
    readonly property var sensors: [
        { label: Translation.tr("CPU clock"), v: root.g.cpuFrequencyMhz, text: Math.round(root.g.cpuFrequencyMhz) + " MHz" },
        { label: Translation.tr("CPU power"), v: root.g.cpuPower, text: Math.round(root.g.cpuPower) + " W" },
        { label: Translation.tr("GPU clock"), v: root.g.gpuCoreClockMhz, text: Math.round(root.g.gpuCoreClockMhz) + " MHz" },
        { label: Translation.tr("Memory clock"), v: root.g.gpuMemoryClockMhz, text: Math.round(root.g.gpuMemoryClockMhz) + " MHz" },
        { label: Translation.tr("GPU power"), v: root.g.gpuPower, text: Math.round(root.g.gpuPower) + " W" },
        { label: Translation.tr("GPU voltage"), v: root.g.gpuVoltage, text: Number(root.g.gpuVoltage).toFixed(2) + " V" },
        { label: Translation.tr("Game memory"), v: root.g.processMemoryGb, text: root.gb(root.g.processMemoryGb) },
        { label: Translation.tr("Swap"), v: root.g.swapTotalGb > 0 ? root.g.swapUsedGb : -1, text: root.gb(root.g.swapUsedGb) },
        { label: Translation.tr("Disk"), v: root.g.diskUsagePercent, text: root.pct(root.g.diskUsagePercent) }
    ].filter(s => root.ok(s.v) && s.v > 0)
    readonly property var session: [
        { label: Translation.tr("Graphics API"), text: String(root.g.graphicsApi ?? "") },
        { label: Translation.tr("Wine / Proton"), text: String(root.g.wineProtonVersion ?? "") },
        { label: Translation.tr("Resolution"), text: String(root.g.gameResolution ?? "") },
        { label: Translation.tr("Frame pacing"), text: root.ok(root.g.framePacingJitterMs) ? Translation.tr("%1 ms").arg(root.g.framePacingJitterMs.toFixed(1)) : "" },
        { label: Translation.tr("MangoHud"), text: String(root.g.mangoHudVersion ?? "") }
    ].filter(s => s.text.length > 0 && s.text !== "--")
    readonly property string rig: [root.g.cpuName, root.g.gpuName, root.g.gpuDriver, root.g.kernelVersion]
        .map(s => String(s ?? "")).filter(s => s.length > 0 && s !== "--").join("  ·  ")

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round((root.detailed ? 360 : 320) * root.d)
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Math.round(8 * root.d)

            // What is being measured.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                Rectangle {
                    implicitWidth: Math.round(7 * root.d)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: root.live ? OverlayLook.colSuccess : OverlayLook.colFaint
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.g.gameDetected && String(root.g.gameName ?? "").length > 0 ? root.g.gameName : Translation.tr("System")
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeBody
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: GameMode.active
                    implicitWidth: modeLabel.implicitWidth + Math.round(14 * root.d)
                    implicitHeight: Math.round(20 * root.d)
                    radius: height / 2
                    color: OverlayLook.colToggle
                    StyledText {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: Translation.tr("Game mode")
                        color: OverlayLook.colOnToggle
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                        font.weight: Font.DemiBold
                    }
                }
            }

            // Frames: the figure over the shape of the frame times.
            Rectangle {
                id: trace
                Layout.fillWidth: true
                implicitHeight: Math.round(104 * root.d)
                radius: OverlayLook.roundingNormal
                color: OverlayLook.colRecessed
                layer.enabled: root.live
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: trace.width
                        height: trace.height
                        radius: trace.radius
                    }
                }

                Graph {
                    anchors.fill: parent
                    visible: root.live
                    values: root.g.frametimeGraphValues
                    points: root.g.historyLength
                    alignment: Graph.Alignment.Right
                    color: OverlayLook.colPrimary
                    fillOpacity: 0.22
                }

                Column {
                    visible: root.live
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Math.round(12 * root.d)
                    Row {
                        spacing: Math.round(5 * root.d)
                        StyledText {
                            id: fpsFigure
                            text: Math.round(root.g.fps)
                            color: OverlayLook.colOnLayer1
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: Math.round(OverlayLook.typeFigure * 1.2)
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            anchors.baseline: fpsFigure.baseline
                            text: Translation.tr("fps")
                            color: OverlayLook.colSubtext
                            font.family: OverlayLook.fontMain
                            font.pixelSize: OverlayLook.typeLabel
                        }
                    }
                    StyledText {
                        text: Translation.tr("avg %1 · min %2 · max %3").arg(Math.round(root.g.averageFps)).arg(Math.round(root.g.minimumFps)).arg(Math.round(root.g.maximumFps))
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: OverlayLook.typeMeta
                    }
                }
                StyledText {
                    visible: root.live
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(12 * root.d)
                    text: Translation.tr("%1 ms").arg(Number(root.g.frametime).toFixed(1))
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: OverlayLook.typeLabel
                    font.weight: Font.DemiBold
                }

                // No frames to draw: what is missing and how to get it.
                Column {
                    visible: !root.live
                    anchors.centerIn: parent
                    width: parent.width - Math.round(32 * root.d)
                    spacing: Math.round(3 * root.d)
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.g.gameDetected ? "query_stats" : "sports_esports"
                        iconSize: Math.round(24 * root.d)
                        color: OverlayLook.colFaint
                    }
                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.statusText
                        color: OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: root.statusDetail
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                }
            }

            // The four loads.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * root.d)
                Repeater {
                    model: root.loads
                    Column {
                        id: load
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: Math.round(3 * root.d)
                        Row {
                            width: parent.width
                            StyledText {
                                width: parent.width - loadDetail.width
                                elide: Text.ElideRight
                                text: load.modelData.label
                                color: OverlayLook.colSubtext
                                font.family: OverlayLook.fontMain
                                font.pixelSize: OverlayLook.typeFootnote
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                id: loadDetail
                                text: load.modelData.detail
                                color: load.modelData.hot ? OverlayLook.colError : OverlayLook.colFaint
                                font.family: OverlayLook.fontNumbers
                                font.pixelSize: OverlayLook.typeFootnote
                            }
                        }
                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: load.modelData.value
                            color: OverlayLook.colOnLayer1
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: OverlayLook.typeBody
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            width: parent.width
                            height: Math.round(3 * root.d)
                            radius: height / 2
                            color: OverlayLook.colRecessed
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, load.modelData.bar))
                                height: parent.height
                                radius: height / 2
                                color: load.modelData.hot ? OverlayLook.colError : OverlayLook.colPrimary
                                Behavior on width { NumberAnimation { duration: FamilyStyle.moveDuration; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            // Opened up: every sensor, each core, the session.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(2 * root.d)
                visible: root.detailed
                implicitHeight: 1
                color: OverlayLook.colHairline
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.detailed && root.sensors.length > 0
                columns: 3
                columnSpacing: Math.round(10 * root.d)
                rowSpacing: Math.round(8 * root.d)
                Repeater {
                    model: root.detailed ? root.sensors : []
                    Column {
                        id: sensor
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: Math.round(1 * root.d)
                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: sensor.modelData.label
                            color: OverlayLook.colSubtext
                            font.family: OverlayLook.fontMain
                            font.pixelSize: OverlayLook.typeFootnote
                        }
                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: sensor.modelData.text
                            color: OverlayLook.colOnLayer1
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: OverlayLook.typeMeta
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // Each core as a column of its load.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.detailed && root.g.cpuCoreLoads.length > 0
                spacing: Math.round(4 * root.d)
                StyledText {
                    text: Translation.tr("Cores") + "  ·  " + root.g.cpuCoreLoads.length
                    color: OverlayLook.colSubtext
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeFootnote
                }
                Row {
                    id: cores
                    Layout.fillWidth: true
                    readonly property real barHeight: Math.round(30 * root.d)
                    spacing: 2
                    readonly property int n: Math.max(1, root.g.cpuCoreLoads.length)
                    Repeater {
                        model: root.detailed ? root.g.cpuCoreLoads : []
                        Rectangle {
                            id: core
                            required property real modelData
                            width: (cores.width - (cores.n - 1) * cores.spacing) / cores.n
                            height: cores.barHeight
                            radius: Math.min(3, width / 2)
                            color: OverlayLook.colRecessed
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(1, parent.height * Math.max(0, Math.min(1, core.modelData / 100)))
                                radius: parent.radius
                                color: core.modelData >= 90 ? OverlayLook.colError : OverlayLook.colPrimary
                                Behavior on height { NumberAnimation { duration: FamilyStyle.moveDuration; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.detailed && root.g.gameDetected && root.session.length > 0
                columns: 2
                columnSpacing: Math.round(10 * root.d)
                rowSpacing: Math.round(3 * root.d)
                Repeater {
                    model: root.detailed ? root.session : []
                    StyledText {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 0
                        text: modelData.label
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                }
                Repeater {
                    model: root.detailed ? root.session : []
                    StyledText {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 1
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: modelData.text
                        color: OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.detailed && root.rig.length > 0
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.rig
                color: OverlayLook.colFaint
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeFootnote
            }
        }
    }
}
