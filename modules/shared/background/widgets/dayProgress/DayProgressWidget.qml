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
    resizeMinHeight: 190
    needsColText: true
    widgetSurfaceEnabled: false

    // ── Tokens ───────────────────────────────────────────────
    // Bare on the wallpaper by design: Lume's ink, and the shadow under the whole dial that iRiS's bare faces wear.
    bareShadow: true
    readonly property color ink: root.widgetInk
    readonly property color inkMuted: root.widgetInkMuted
    readonly property color accent: root.widgetAccentVisible
    // M3's track is the indicator's quiet partner; bare, a veil of the ink is what reads on any wallpaper
    readonly property color track: ColorUtils.applyAlpha(root.ink, 0.24)

    // ── Customization ────────────────────────────────────────
    readonly property string ringStyle: String(root._readConfigKey("style") ?? "ring")
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
    // to the minute: the dial never redraws for a second hand nobody sees
    readonly property real dayFraction: {
        const d = DateTime.clock.date
        return (d.getHours() * 60 + d.getMinutes()) / 1440
    }
    readonly property bool isDaytime: {
        const h = DateTime.clock.date.getHours()
        return h >= 6 && h < 19
    }

    // Medium is wide: the dial keeps the day, the time and what the sun does next sit beside it.
    readonly property bool wide: root.sizeClass === "medium"
    readonly property bool sunUp: Weather.sunState === "day"
    readonly property string sunNext: String((root.sunUp ? Weather.data?.sunset : Weather.data?.sunrise) ?? "")
    readonly property string sunLine: root.sunNext.length > 0
        ? (root.sunUp ? Translation.tr("Sunset") : Translation.tr("Sunrise")) + " " + root.sunNext : ""

    // The day as M3's circular indicator: a thick track, the elapsed day in the accent with a gap at both ends,
    // midnight at the top. Comet: the last three hours lead and the rest of the day steps back. Ticks: one dot
    // an hour, the passed ones lit and the current one larger.
    component DayDial: Item {
        id: dial
        property real thickness: 8
        property bool labels: false
        readonly property real size: Math.min(width, height)
        readonly property real r: size / 2 - thickness
        readonly property real degree: root.dayFraction * 360
        readonly property real labelSize: Math.max(11, Math.round(size * 0.058))
        readonly property real labelRadius: dial.r - dial.thickness / 2 - dial.labelSize * 0.75 - Math.round(4 * root.scaleFactor)

        CircularProgress {
            anchors.centerIn: parent
            visible: root.showArc
            implicitSize: dial.size
            lineWidth: dial.thickness
            value: root.dayFraction
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
            model: dial.labels ? ["00", "06", "12", "18"] : []
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
            // ── Medium: the dial with the sun in it, the time and what the sun does next beside it ──
            Item {
                visible: root.wide
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.scaleFactor)

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
                        text: DateTime.time
                        elide: Text.ElideRight
                        color: root.ink
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(44 * root.scaleFactor * root.textScale)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.showDate
                        text: DateTime.date
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

            // ── Small and large: the whole day around the time ──
            DayDial {
                id: dial
                visible: !root.wide
                anchors.centerIn: parent
                // from the box, not its own size: the inset depends on it
                readonly property bool roomy: Math.min(parent.width, parent.height) >= Math.round(320 * root.scaleFactor)
                width: Math.min(parent.width, parent.height) - 2 * Math.round((roomy ? 16 : 10) * root.scaleFactor)
                height: width
                thickness: Math.round((roomy ? 13 : 9) * root.scaleFactor)
                labels: root.showHourLabels

                ColumnLayout {
                    anchors.centerIn: parent
                    // between the 06 and 18 labels when they show, inside the track when they don't
                    width: dial.labels ? 2 * (dial.labelRadius - dial.labelSize - Math.round(4 * root.scaleFactor))
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
                        text: DateTime.time
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
                        text: DateTime.date
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

}
