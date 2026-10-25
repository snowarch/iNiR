pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common.functions
import qs.modules.iris.style

IrisWidgetFace {
    id: root
    // A Design may print its own vitals (AIRISU's chart recorder).
    designFace: IrisDesign.skin("widgetVitals")

    readonly property var resources: Array.from(root.widget._resourceModel ?? [])
    readonly property var loads: root.resources.filter(entry => ["cpu", "mem", "gpu"].includes(entry.key))
    readonly property var heats: root.resources.filter(entry => ["temp", "gpuTemp"].includes(entry.key))
    readonly property bool hasDisk: root.resources.some(entry => entry.key === "disk")
    // the one picked in the widget's options, else the first load
    readonly property string leadKey: String(root.widget.irisOption("lead", "auto"))
    readonly property var leadEntry: root.resources.find(entry => entry.key === root.leadKey)
        ?? root.loads[0] ?? root.heats[0] ?? root.resources[0] ?? null
    readonly property var rest: root.resources.filter(entry => entry !== root.leadEntry)
    readonly property bool leadTrends: root.leadEntry !== null && root.leadEntry.key !== "disk"

    function level(key: string): real {
        return Math.max(0, Math.min(1, Number(root.widget._getValue(key)) || 0))
    }
    // One accent for every reading, as the Day has one light; a reading past 85 % earns the danger colour. Nothing keeps
    // its ink levels and the signal for the alarm.
    function tint(key: string): color {
        if (root.level(key) >= 0.85)
            return root.danger
        if (root.nothing)
            return root.ink
        return root.accent
    }
    function name(entry: var): string {
        return entry.key === "temp" ? Translation.tr("CPU heat")
            : entry.key === "gpuTemp" ? Translation.tr("GPU heat")
            : entry.key === "mem" ? Translation.tr("Memory")
            : entry.key === "cpu" ? Translation.tr("Processor")
            : entry.key === "gpu" ? Translation.tr("Graphics") : entry.label
    }
    function figure(key: string): string {
        return String(root.widget._getDisplayText(key)).replace(/[%°C]/g, "")
    }
    function unit(key: string): string {
        return key === "temp" || key === "gpuTemp" ? "°C" : "%"
    }
    // A smooth line through the points that never overshoots them (monotone cubic, Fritsch-Carlson), as SVG;
    // `floor` closes it down to the bottom edge for the fill under it.
    function curve(points: var, floor: real): string {
        const n = points.length
        if (n < 2)
            return ""
        const d = [], m = []
        for (let i = 0; i < n - 1; i++)
            d.push((points[i + 1].y - points[i].y) / Math.max(0.001, points[i + 1].x - points[i].x))
        m.push(d[0])
        for (let i = 1; i < n - 1; i++)
            m.push(d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2)
        m.push(d[n - 2])
        for (let i = 0; i < n - 1; i++) {
            if (d[i] === 0) { m[i] = 0; m[i + 1] = 0; continue }
            const a = m[i] / d[i], b = m[i + 1] / d[i], h = a * a + b * b
            if (h > 9) { const t = 3 / Math.sqrt(h); m[i] = t * a * d[i]; m[i + 1] = t * b * d[i] }
        }
        let path = floor >= 0 ? `M ${points[0].x} ${floor} L ${points[0].x} ${points[0].y}` : `M ${points[0].x} ${points[0].y}`
        for (let i = 0; i < n - 1; i++) {
            const dx = (points[i + 1].x - points[i].x) / 3
            path += ` C ${points[i].x + dx} ${points[i].y + m[i] * dx} ${points[i + 1].x - dx} ${points[i + 1].y - m[i + 1] * dx} ${points[i + 1].x} ${points[i + 1].y}`
        }
        return floor >= 0 ? path + ` L ${points[n - 1].x} ${floor} Z` : path
    }
    function history(key: string): var {
        const values = key === "cpu" ? ResourceUsage.cpuUsageHistory
            : key === "mem" ? ResourceUsage.memoryUsageHistory
            : key === "gpu" ? ResourceUsage.gpuUsageHistory
            : key === "temp" ? ResourceUsage.cpuTempHistory
            : key === "gpuTemp" ? ResourceUsage.gpuTempHistory : []
        return Array.from(values ?? []).slice(-40)
    }

    function short(entry: var): string {
        return entry.key === "cpu" ? Translation.tr("CPU") : entry.key === "mem" ? Translation.tr("RAM")
            : entry.key === "gpu" ? Translation.tr("GPU") : root.name(entry)
    }

    // A trend, not a level: the line spans its own recent range (at least 10 points of it), so a steady 38 °C reads as
    // a calm line in the middle instead of a flat stroke on the floor. Drawn as the Day draws the sun: a line with the
    // fade under it from its own top, on a hairline floor, no dot at its end.
    component Trace: Item {
        id: trace
        required property string key
        property real stroke: root.dp(2)
        readonly property var samples: root.history(trace.key).map(value => Math.max(0, Math.min(1, Number(value) || 0)))
        readonly property real low: Math.min(...trace.samples)
        readonly property real high: Math.max(...trace.samples)
        readonly property real span: Math.max(0.10, trace.high - trace.low)
        readonly property real base: (trace.low + trace.high) / 2 - trace.span / 2
        readonly property real floor: trace.height - 1
        readonly property var line: trace.samples.map((value, i) => Qt.point(
            trace.width * i / Math.max(1, trace.samples.length - 1),
            trace.floor - trace.stroke - (value - trace.base) / trace.span * (trace.floor - trace.stroke * 2)))
        readonly property real crest: trace.line.length ? Math.min(...trace.line.map(p => p.y)) : 0
        readonly property color tint: root.tint(trace.key)
        Rectangle {
            width: parent.width
            height: 1
            y: trace.floor
            color: root.hairline
        }
        Shape {
            anchors.fill: parent
            visible: trace.samples.length >= 2 && trace.high > 0.005
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: trace.crest; x2: 0; y2: trace.floor
                    GradientStop { position: 0; color: ColorUtils.applyAlpha(trace.tint, 0.26) } // iris-literal: the Day's fade, 26 % at the top of the line to nothing
                    GradientStop { position: 1; color: ColorUtils.applyAlpha(trace.tint, 0) }
                }
                PathSvg { path: root.curve(trace.line, trace.floor) }
            }
            ShapePath {
                strokeColor: trace.tint
                strokeWidth: trace.stroke
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathSvg { path: root.curve(trace.line, -1) }
            }
        }
    }

    // A reading in the figure face, its unit a step down; ink, or the danger colour past 85 %.
    component Reading: Row {
        id: reading
        required property string key
        property real figureSize: 24
        spacing: root.dp(2)
        FaceFigure {
            id: number
            face: root
            text: root.figure(reading.key)
            size: reading.figureSize
            tone: root.level(reading.key) >= 0.85 ? root.danger : root.ink
        }
        FaceText {
            face: root
            anchors.baseline: number.baseline
            text: root.unit(reading.key)
            size: Math.max(11, Math.round(reading.figureSize * 0.42))
            weight: Font.DemiBold
            color: root.inkSecondary
        }
    }

    // One of the rest: its name, in large its own trend, its reading at the end.
    component Line: ColumnLayout {
        id: line
        required property var entry
        property bool rule: true
        property bool traced: false
        spacing: root.dp(root.large ? 8 : 4)
        Rectangle {
            visible: line.rule
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: root.dp(10)
            FaceText {
                face: root
                Layout.fillWidth: !line.traced
                Layout.preferredWidth: line.traced ? root.contentWidth * 0.26 : -1
                text: root.large ? root.name(line.entry) : root.short(line.entry)
                color: root.inkSecondary
                size: 13
            }
            Trace {
                visible: line.traced
                key: line.entry.key
                Layout.fillWidth: true
                Layout.preferredHeight: root.dp(22)
                stroke: root.dp(1.5)
            }
            Reading {
                key: line.entry.key
                figureSize: root.large ? 17 : 15
            }
        }
    }

    // The disk leads only alone: its fill is the drawn value.
    component Capacity: Item {
        implicitHeight: root.dp(8)
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.capsule(height)
            color: root.fillQuiet
            Rectangle {
                width: Math.max(parent.height, parent.width * root.level("disk"))
                height: parent.height
                radius: parent.radius
                color: root.tint("disk")
            }
        }
    }

    FaceText {
        face: root
        visible: root.resources.length === 0
        anchors.centerIn: parent
        text: Translation.tr("Choose what to watch")
        color: root.inkTertiary
        size: 12.5
    }

    // Small: the lead reading over its trend, the next one beside its name at the foot.
    ColumnLayout {
        visible: root.small && root.leadEntry !== null
        anchors.fill: parent
        spacing: root.dp(2)
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "monitor_heart"
            text: root.leadEntry ? root.name(root.leadEntry) : ""
        }
        Reading { key: root.leadEntry?.key ?? "cpu"; figureSize: 34 }
        Trace {
            visible: root.leadTrends
            key: root.leadEntry?.key ?? "cpu"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dp(6)
        }
        Capacity { visible: !root.leadTrends; Layout.fillWidth: true; Layout.topMargin: root.dp(8) }
        Item { visible: !root.leadTrends; Layout.fillHeight: true }
        FaceAside {
            face: root
            visible: root.rest.length > 0
            Layout.topMargin: root.dp(6)
            label: root.rest.length > 0 ? root.short(root.rest[0]) : ""
            value: root.rest.length > 0 ? root.figure(root.rest[0].key) : ""
            unit: root.rest.length > 0 ? root.unit(root.rest[0].key) : ""
            tone: root.rest.length > 0 && root.level(root.rest[0].key) >= 0.85 ? root.danger : root.ink
        }
    }

    // Medium: the lead and its trend on the left, the rest as facts; large: the lead's trend across the face, then the
    // rest, each load with its own trend.
    GridLayout {
        visible: !root.small && root.leadEntry !== null
        anchors.fill: parent
        columns: root.medium ? 2 : 1
        columnSpacing: root.dp(18)
        rowSpacing: root.dp(10)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: root.dp(2)
            FaceHeader {
                face: root
                Layout.fillWidth: true
                glyph: "monitor_heart"
                text: root.leadEntry ? root.name(root.leadEntry) : ""
            }
            Reading { key: root.leadEntry?.key ?? "cpu"; figureSize: root.large ? 44 : 36 }
            Trace {
                visible: root.leadTrends
                key: root.leadEntry?.key ?? "cpu"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: root.dp(6)
            }
            Capacity { visible: !root.leadTrends; Layout.fillWidth: true; Layout.topMargin: root.dp(8) }
            Item { visible: !root.leadTrends; Layout.fillHeight: true }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: root.medium ? Qt.AlignVCenter : Qt.AlignBottom
            spacing: root.dp(root.large ? 8 : 4)
            Repeater {
                model: root.small ? [] : root.rest.slice(0, root.medium ? 5 : 6)
                Line {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    entry: modelData
                    rule: root.large || index > 0
                    traced: root.large && ["cpu", "mem", "gpu", "temp", "gpuTemp"].includes(modelData.key)
                }
            }
        }
    }
}
