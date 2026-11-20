pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "dayProgress"
    resizeMinWidth: 190
    resizeMinHeight: 160
    needsColText: true
    readonly property string ringStyle: String(root._readConfigKey("style") ?? "ring")
    readonly property string progressSpan: String(root._readConfigKey("span") ?? "day")
    readonly property bool isDialStyle: ["ring", "arc", "ticks"].includes(root.ringStyle)
    widgetSurfaceEnabled: !root.isDialStyle

    // ── Tokens ───────────────────────────────────────────────
    // Bare on the wallpaper by design (Lume's ink, and the shadow under the whole face that iRiS's bare faces wear);
    // bars/dots can wear a plate when background is on, and then the shadow steps aside.
    bareShadow: true
    // Bare on the wallpaper the ink is picked among the generated tokens by the contrast it makes with the region
    // under it, as the clock does: colText alone read dark grey on a dark or mid-grey region.
    readonly property color ink: root.widgetHasSurface ? root.widgetInk
        : root.widgetSemanticForeground(root.widgetSurfaceRole, root.accentBackdrop, 4.5)
    readonly property color inkMuted: root.widgetHasSurface ? root.widgetInkMuted : ColorUtils.applyAlpha(root.ink, 0.74)
    readonly property color accent: root.widgetAccentVisible
    // M3's track is the indicator's quiet partner; bare, a veil of the ink is what reads on any wallpaper
    readonly property color track: ColorUtils.applyAlpha(root.ink, 0.24)

    // ── Customization ────────────────────────────────────────
    readonly property bool showArc: root.ringStyle !== "ticks"
    readonly property bool showComet: root.showArc && Boolean(root._readConfigKey("comet") ?? true)
    readonly property bool showIcon: Boolean(root._readConfigKey("showIcon") ?? true)
    readonly property bool showDate: Boolean(root._readConfigKey("showDate") ?? true)
    readonly property bool showHourLabels: Boolean(root._readConfigKey("hourLabels") ?? true)
    // Text emphasis control: 100% keeps the ring-relative defaults.
    readonly property real textScale: {
        const v = Number(root._readConfigKey("fontScale") ?? 100)
        return Math.max(0.6, Math.min(1.8, Number.isFinite(v) ? v / 100 : 1))
    }

    // ── Day state ────────────────────────────────────────────
    // The clock ticks by the minute: nothing redraws for a second hand nobody sees
    readonly property date now: DateTime.clock.date
    readonly property int currentYear: root.now.getFullYear()
    readonly property int daysInYear: {
        const y = root.currentYear
        return ((y % 4 === 0 && y % 100 !== 0) || y % 400 === 0) ? 366 : 365
    }
    readonly property int dayOfYearZeroBased: {
        const y = root.currentYear
        const cur = Date.UTC(y, root.now.getMonth(), root.now.getDate())
        const start = Date.UTC(y, 0, 1)
        return Math.max(0, Math.floor((cur - start) / 86400000))
    }
    readonly property var monthOfDay: {
        const out = []
        const y = root.currentYear
        for (let m = 0; m < 12; m++) {
            const n = new Date(y, m + 1, 0).getDate()
            for (let d = 0; d < n; d++) out.push(m)
        }
        return out
    }

    function boundsOf(kind: string): var {
        const y = root.now.getFullYear()
        const m = root.now.getMonth()
        const d = root.now.getDate()
        const back = (root.now.getDay() - Translation.locale.firstDayOfWeek + 7) % 7
        switch (kind) {
        case "week":
            return [new Date(y, m, d - back), new Date(y, m, d - back + 7)]
        case "month":
            return [new Date(y, m, 1), new Date(y, m + 1, 1)]
        case "year":
            return [new Date(y, 0, 1), new Date(y + 1, 0, 1)]
        default:
            return [new Date(y, m, d), new Date(y, m, d + 1)]
        }
    }

    function fractionOf(kind: string): real {
        const b = root.boundsOf(kind)
        return Math.max(0, Math.min(1, (root.now - b[0]) / Math.max(1, b[1] - b[0])))
    }

    function titleOf(kind: string): string {
        switch (kind) {
        case "week": return Translation.tr("This week")
        case "month": return Translation.locale.toString(root.now, "MMMM")
        case "year": return String(root.currentYear)
        default: return Translation.tr("Today")
        }
    }

    function remainingOf(kind: string): string {
        const mins = Math.floor(Math.max(0, root.boundsOf(kind)[1] - root.now) / 60000)
        if (mins < 60)
            return Translation.tr("%1 min left").arg(mins)
        if (mins < 1440)
            return Translation.tr("%1 h %2 min left").arg(Math.floor(mins / 60)).arg(mins % 60)
        const d = Math.floor(mins / 1440)
        return d === 1 ? Translation.tr("%1 day left").arg(d) : Translation.tr("%1 days left").arg(d)
    }

    readonly property real dayFraction: root.fractionOf("day")
    readonly property real activeFraction: root.fractionOf(root.progressSpan)
    readonly property bool isDaytime: {
        const h = root.now.getHours()
        return h >= 6 && h < 19
    }

    // Medium is wide: the dial keeps the day, the time and what the sun does next sit beside it.
    readonly property bool wide: root.sizeClass === "medium" && root.isDialStyle
    readonly property bool sunUp: Weather.sunState === "day"
    readonly property string sunNext: String((root.sunUp ? Weather.data?.sunset : Weather.data?.sunrise) ?? "")
    readonly property string sunLine: root.sunNext.length > 0
        ? (root.sunUp ? Translation.tr("Sunset") : Translation.tr("Sunrise")) + " " + root.sunNext : ""

    // The day as M3's circular indicator: a thick track, the elapsed span in the accent with a gap at both ends,
    // midnight at the top. Comet: the last stretch leads and the rest steps back. Ticks: one dot an hour, the
    // passed ones lit and the current one larger.
    component DayDial: Item {
        id: dial
        property real thickness: 8
        property bool labels: false
        readonly property real size: Math.min(width, height)
        readonly property real r: size / 2 - thickness
        readonly property real degree: root.activeFraction * 360
        readonly property real labelSize: Math.max(11, Math.round(size * 0.058))
        readonly property real labelRadius: dial.r - dial.thickness / 2 - dial.labelSize * 0.75 - Math.round(4 * root.scaleFactor)

        CircularProgress {
            anchors.centerIn: parent
            visible: root.showArc
            implicitSize: dial.size
            lineWidth: dial.thickness
            value: root.activeFraction
            enableAnimation: false
            colPrimary: root.showComet ? ColorUtils.applyAlpha(root.accent, 0.42) : root.accent
            colSecondary: root.ringStyle === "ring" ? root.track : "transparent"
            gapAngle: root.ringStyle === "ring" ? (dial.thickness + Math.round(4 * root.scaleFactor)) / dial.r * 180 / Math.PI : 0
        }
        Shape {
            anchors.fill: parent
            visible: root.showComet && dial.degree > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.accent
                strokeWidth: dial.thickness
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.r
                    radiusY: dial.r
                    startAngle: -90 + Math.max(0, dial.degree - 45)
                    sweepAngle: Math.min(45, dial.degree)
                }
            }
        }
        Repeater {
            model: root.showArc ? 0 : 24
            Rectangle {
                required property int index
                readonly property real angle: index / 24 * 2 * Math.PI - Math.PI / 2
                readonly property bool now: index === Math.floor(root.dayFraction * 24)
                readonly property bool passed: index < Math.floor(root.dayFraction * 24)
                width: Math.round(dial.thickness * (now ? 1.25 : index % 6 === 0 ? 0.85 : 0.6))
                height: width
                radius: width / 2
                x: dial.width / 2 + Math.cos(angle) * dial.r - width / 2
                y: dial.height / 2 + Math.sin(angle) * dial.r - height / 2
                color: now || passed ? root.accent : root.track
            }
        }
        Repeater {
            model: dial.labels && root.progressSpan === "day" ? ["00", "06", "12", "18"] : []
            StyledText {
                required property string modelData
                required property int index
                readonly property real angle: index * Math.PI / 2 - Math.PI / 2
                x: dial.width / 2 + Math.cos(angle) * dial.labelRadius - width / 2
                y: dial.height / 2 + Math.sin(angle) * dial.labelRadius - height / 2
                text: modelData
                color: root.inkMuted
                font.family: root.widgetNumbersFamily
                font.pixelSize: dial.labelSize
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    component DayIcon: MaterialSymbol {
        visible: root.showIcon
        text: root.isDaytime ? "light_mode" : "bedtime"
        fill: 1
        color: root.accent
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                shown: !root.familyFaced && !root.isDialStyle
                    && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
                surfaceColor: root.widgetInk
            }

            // ── Medium Dial: the dial with the sun in it, the time and what the sun does next beside it ──
            Loader {
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.scaleFactor)
                active: root.isDialStyle && root.wide
                sourceComponent: Item {
                    DayDial {
                        id: wideDial
                        width: parent.height
                        height: parent.height
                        thickness: Math.round(9 * root.scaleFactor)
                        DayIcon {
                            anchors.centerIn: parent
                            iconSize: Math.round(wideDial.size * 0.24)
                        }
                    }
                    ColumnLayout {
                        x: wideDial.width + Math.round(20 * root.scaleFactor)
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(2 * root.scaleFactor)
                        StyledText {
                            Layout.fillWidth: true
                            text: root.progressSpan === "day" ? DateTime.time : root.remainingOf(root.progressSpan)
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 14
                            color: root.ink
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.round(44 * root.scaleFactor * root.textScale)
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: root.showDate
                            text: root.progressSpan === "day" ? DateTime.date : root.titleOf(root.progressSpan)
                            elide: Text.ElideRight
                            color: root.inkMuted
                            font.family: root.widgetBodyFamily
                            font.pixelSize: Math.round(14 * root.scaleFactor * root.textScale)
                            font.weight: Font.Medium
                        }
                        RowLayout {
                            Layout.topMargin: Math.round(10 * root.scaleFactor)
                            Layout.fillWidth: true
                            visible: root.sunLine.length > 0
                            spacing: Math.round(6 * root.scaleFactor)
                            MaterialSymbol {
                                text: root.sunUp ? "wb_twilight" : "wb_sunny"
                                fill: 1
                                iconSize: Math.round(16 * root.scaleFactor)
                                color: root.accent
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.sunLine
                                elide: Text.ElideRight
                                color: root.inkMuted
                                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            // ── Small and Large Dial: the whole span around the readout ──
            Loader {
                anchors.fill: parent
                active: root.isDialStyle && !root.wide
                sourceComponent: Item {
                    DayDial {
                        id: dial
                        anchors.centerIn: parent
                        readonly property bool roomy: Math.min(parent.width, parent.height) >= Math.round(320 * root.scaleFactor)
                        // from the box, not its own size: the inset depends on it
                        width: Math.min(parent.width, parent.height) - 2 * Math.round((roomy ? 16 : 10) * root.scaleFactor)
                        height: width
                        thickness: Math.round((roomy ? 13 : 9) * root.scaleFactor)
                        labels: root.showHourLabels

                        ColumnLayout {
                            anchors.centerIn: parent
                            // between the 06 and 18 labels when they show, inside the track when they don't
                            width: dial.labels && root.progressSpan === "day" ? 2 * (dial.labelRadius - dial.labelSize - Math.round(4 * root.scaleFactor))
                                : 2 * (dial.r - dial.thickness)
                            spacing: 0

                            DayIcon {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.bottomMargin: Math.round(2 * root.scaleFactor)
                                iconSize: Math.round(dial.size * 0.1 * root.textScale)
                            }
                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.progressSpan === "day" ? DateTime.time : root.remainingOf(root.progressSpan)
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 12
                                color: root.ink
                                font.family: root.widgetNumbersFamily
                                font.pixelSize: Math.round(dial.size * 0.2 * root.textScale)
                                font.weight: Font.DemiBold
                                font.features: ({ "tnum": 1 })
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: root.showDate
                                horizontalAlignment: Text.AlignHCenter
                                text: root.progressSpan === "day" ? DateTime.date : root.titleOf(root.progressSpan)
                                elide: Text.ElideRight
                                color: root.inkMuted
                                font.family: root.widgetBodyFamily
                                font.pixelSize: Math.max(11, Math.round(dial.size * 0.068 * root.textScale))
                                font.weight: Font.Medium
                            }
                            StyledText {
                                Layout.fillWidth: true
                                Layout.topMargin: Math.round(6 * root.scaleFactor)
                                visible: dial.roomy && root.sunLine.length > 0
                                horizontalAlignment: Text.AlignHCenter
                                text: root.sunLine
                                elide: Text.ElideRight
                                color: root.accent
                                font.family: root.widgetBodyFamily
                                font.pixelSize: Math.max(11, Math.round(dial.size * 0.045 * root.textScale))
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            // ── Bars: Small keeps Day and Year, Medium all four, Large all four with the date. The bar draws
            // how far; the words say how long is left. ──
            Loader {
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.scaleFactor)
                active: root.ringStyle === "bars"
                sourceComponent: ColumnLayout {
                    id: barsLayout
                    spacing: Math.round((root.isSmall ? 6 : root.isLarge ? 14 : 10) * root.scaleFactor)

                    Repeater {
                        model: root.isSmall ? ["day", "year"] : ["day", "week", "month", "year"]

                        ColumnLayout {
                            id: barItem
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: Math.round(3 * root.scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: root.titleOf(barItem.modelData)
                                    color: root.ink
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.round((root.isSmall ? 11.5 : 13) * root.scaleFactor * root.textScale)
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    text: root.remainingOf(barItem.modelData)
                                    color: root.accent
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.round((root.isSmall ? 11.5 : 13) * root.scaleFactor * root.textScale)
                                    font.weight: Font.Bold
                                    font.features: ({ "tnum": 1 })
                                }
                            }

                            StyledProgressBar {
                                Layout.fillWidth: true
                                valueBarWidth: parent.width
                                valueBarHeight: Math.round((root.isLarge ? 7 : 5) * root.scaleFactor)
                                value: root.fractionOf(barItem.modelData)
                                wavy: true
                                animateWave: false
                                highlightColor: root.accent
                                trackColor: root.track
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.isLarge
                        elide: Text.ElideRight
                        text: DateTime.date
                        color: root.inkMuted
                        font.family: root.widgetBodyFamily
                        font.pixelSize: Math.round(12 * root.scaleFactor * root.textScale)
                    }
                }
            }

            // ── Dots: every day of the year, past days filled, today in accent. Small: the year and what is
            // left; Medium adds the day count; Large adds the date. ──
            Loader {
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.scaleFactor)
                active: root.ringStyle === "dots"
                sourceComponent: ColumnLayout {
                    id: dotsLayout
                    spacing: Math.round(8 * root.scaleFactor)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: String(root.currentYear)
                                color: root.ink
                                font.family: root.widgetNumbersFamily
                                font.pixelSize: Math.round((root.isSmall ? 18 : 22) * root.scaleFactor * root.textScale)
                                font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.remainingOf("year")
                                color: root.accent
                                font.family: root.widgetBodyFamily
                                font.pixelSize: Math.round((root.isSmall ? 12 : 13) * root.scaleFactor * root.textScale)
                                font.weight: Font.DemiBold
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.isSmall
                            elide: Text.ElideRight
                            text: Translation.tr("Day %1 of %2").arg(root.dayOfYearZeroBased + 1).arg(root.daysInYear)
                            color: root.inkMuted
                            font.family: root.widgetBodyFamily
                            font.pixelSize: Math.round(11.5 * root.scaleFactor * root.textScale)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.isLarge
                            elide: Text.ElideRight
                            text: DateTime.date
                            color: root.inkMuted
                            font.family: root.widgetBodyFamily
                            font.pixelSize: Math.round(11.5 * root.scaleFactor * root.textScale)
                        }
                    }

                    Item {
                        id: dotField
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property int cols: {
                            if (width <= 0 || height <= 0) return 20
                            let best = 7
                            let bestPitch = 0
                            for (let c = 7; c <= 60; c++) {
                                const p = Math.min(width / c, height / Math.ceil(root.daysInYear / c))
                                if (p > bestPitch) {
                                    bestPitch = p
                                    best = c
                                }
                            }
                            return best
                        }
                        readonly property real pitch: Math.max(2, Math.min(
                            width / dotField.cols,
                            height / Math.max(1, Math.ceil(root.daysInYear / dotField.cols))))
                        readonly property real offX: (width - dotField.cols * dotField.pitch) / 2
                        readonly property color pastColor: ColorUtils.applyAlpha(root.ink, 0.78)
                        readonly property color evenColor: ColorUtils.applyAlpha(root.ink, 0.14)
                        readonly property color oddColor: ColorUtils.applyAlpha(root.ink, 0.26)

                        // One canvas for all the dots, painted again only when the day, the size or a colour changes
                        Canvas {
                            id: dotCanvas
                            anchors.fill: parent
                            readonly property string paintKey: [root.dayOfYearZeroBased, root.daysInYear, dotField.cols,
                                Math.round(dotField.pitch * 100), width, height, dotField.pastColor, dotField.evenColor,
                                dotField.oddColor, root.accent].join("|")
                            onPaintKeyChanged: dotCanvas.requestPaint()
                            onPaint: {
                                const ctx = dotCanvas.getContext("2d")
                                ctx.clearRect(0, 0, dotCanvas.width, dotCanvas.height)
                                const pitch = dotField.pitch
                                const today = root.dayOfYearZeroBased
                                const small = Math.max(2, Math.round(pitch * 0.64)) / 2
                                const big = Math.max(2, Math.round(pitch)) / 2
                                const batches = [
                                    { color: dotField.pastColor, test: i => i < today },
                                    { color: dotField.evenColor, test: i => i > today && (root.monthOfDay[i] ?? 0) % 2 === 0 },
                                    { color: dotField.oddColor, test: i => i > today && (root.monthOfDay[i] ?? 0) % 2 !== 0 },
                                    { color: root.accent, test: i => i === today }
                                ]
                                for (const batch of batches) {
                                    ctx.fillStyle = batch.color
                                    ctx.beginPath()
                                    for (let i = 0; i < root.daysInYear; i++) {
                                        if (!batch.test(i)) continue
                                        const r = i === today ? big : small
                                        const cx = dotField.offX + (i % dotField.cols) * pitch + pitch / 2
                                        const cy = Math.floor(i / dotField.cols) * pitch + pitch / 2
                                        ctx.moveTo(cx + r, cy)
                                        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                    }
                                    ctx.fill()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
