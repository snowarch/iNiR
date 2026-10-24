pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.bar.island

// The day as the sun's path: where the sun is now, the next sunrise or sunset as the figure, the rest as facts.
// A ring, its percentage and the time left all said the same value three times.
IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetDay")

    readonly property real fraction: root.widget.dayFraction
    readonly property real sunriseAt: root.dayShare(Weather.data?.sunrise)
    readonly property real sunsetAt: root.dayShare(Weather.data?.sunset)
    readonly property bool sunKnown: root.sunriseAt >= 0 && root.sunsetAt > root.sunriseAt
    readonly property real sunrise: root.sunKnown ? root.sunriseAt : 6 / 24
    readonly property real sunset: root.sunKnown ? root.sunsetAt : 19 / 24
    readonly property bool daytime: root.fraction >= root.sunrise && root.fraction < root.sunset

    readonly property var sunriseFact: ({ name: Translation.tr("Sunrise"), time: String(Weather.data?.sunrise ?? ""), glyph: "wb_twilight" })
    readonly property var sunsetFact: ({ name: Translation.tr("Sunset"), time: String(Weather.data?.sunset ?? ""), glyph: "wb_twilight" })
    readonly property var next: root.daytime ? root.sunsetFact : root.sunriseFact
    readonly property var other: root.daytime ? root.sunriseFact : root.sunsetFact

    function span(minutes: int): string {
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? Translation.tr("%1 h %2 min").arg(hours).arg(minutes % 60) : Translation.tr("%1 min").arg(minutes)
    }
    readonly property string daylight: root.span(Math.round((root.sunset - root.sunrise) * 1440))
    // Without sun times the figure is the time left: the path still shows where the day is.
    readonly property string figure: root.sunKnown ? root.next.time : root.span(Math.max(0, Math.round((1 - root.fraction) * 1440)))
    readonly property string figureName: root.sunKnown ? root.next.name : Translation.tr("Until midnight")

    function dayShare(text: var): real {
        const minutes = Weather._timeToMinutes(text)
        return minutes < 0 ? -1 : minutes / 1440
    }

    // "06:02 AM" leads as "6:02" with its AM a step down, like a unit.
    readonly property var figureParts: {
        const match = root.figure.match(/^0?(\d{1,2}:\d{2})\s*([AaPp]\.?\s?[Mm]\.?)$/)
        return match ? { main: match[1], suffix: match[2].toUpperCase() } : { main: root.figure, suffix: "" }
    }

    // Altitude as a cosine around solar noon, crossing the horizon at sunrise and sunset. An Item around the Shape:
    // a Shape sizes itself from its paths, and these paths come from its size.
    component SunPath: Item {
        id: path
        readonly property real pad: root.dp(6)
        readonly property real noon: (root.sunrise + root.sunset) / 2
        readonly property real c: Math.cos(Math.PI * (root.sunset - root.sunrise))
        readonly property real amp: (path.height - path.pad * 2) / 2
        readonly property real horizon: path.pad + path.amp * (1 - path.c)
        function yAt(t: real): real { return path.horizon - (Math.cos(2 * Math.PI * (t - path.noon)) - path.c) * path.amp }
        function trace(from: real, to: real): var {
            const steps = Math.max(2, Math.ceil((to - from) * 64))
            const points = []
            for (let i = 0; i <= steps; i++) {
                const t = from + (to - from) * i / steps
                points.push(Qt.point(t * path.width, path.yAt(t)))
            }
            return points
        }
        function svg(points: var, closed: bool): string {
            if (points.length === 0)
                return ""
            let d = "M " + points[0].x + " " + points[0].y
            for (let i = 1; i < points.length; i++)
                d += " L " + points[i].x + " " + points[i].y
            return closed ? d + " Z" : d
        }
        Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: path.pad; x2: 0; y2: path.horizon
                GradientStop { position: 0; color: ColorUtils.applyAlpha(root.warm, 0.26) } // iris-literal: daylight fades from 26 % at noon to nothing at the horizon
                GradientStop { position: 1; color: ColorUtils.applyAlpha(root.warm, 0) }
            }
            PathSvg { path: path.width > 0 ? path.svg(path.trace(root.sunrise, root.sunset), true) : "" }
        }
        ShapePath {
            strokeColor: root.fillActive
            strokeWidth: root.dp(2)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathSvg { path: path.width > 0 ? path.svg(path.trace(0, 1), false) : "" }
        }
        ShapePath {
            strokeColor: root.warm
            strokeWidth: root.dp(2)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathSvg { path: path.width > 0 && root.fraction > 0.004 ? path.svg(path.trace(0, root.fraction), false) : "" }
        }
        }
        Rectangle {
            width: parent.width
            height: 1
            y: Math.round(path.horizon)
            color: root.hairline
        }
        Rectangle {
            readonly property real d: root.dp(10)
            width: d
            height: d
            radius: IrisStyle.capsule(d)
            x: Math.round(root.fraction * path.width - d / 2)
            y: Math.round(path.yAt(root.fraction) - d / 2)
            color: root.daytime ? root.warm : root.ink
            border.width: root.dp(2)
            border.color: root.knockout
        }
    }

    component Hours: RowLayout {
        spacing: 0
        Repeater {
            model: [0, 6, 12, 18, 24]
            FaceText {
                required property int modelData
                required property int index
                face: root
                Layout.fillWidth: true
                horizontalAlignment: index === 0 ? Text.AlignLeft : index === 4 ? Text.AlignRight : Text.AlignHCenter
                text: modelData
                color: root.inkTertiary
                size: 10.5
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
    }

    component Lead: Row {
        property real figureSize: 30
        spacing: root.dp(6)
        FaceFigure {
            id: leadFigure
            face: root
            text: root.figureParts.main
            size: parent.figureSize
        }
        FaceText {
            face: root
            visible: root.figureParts.suffix.length > 0
            anchors.baseline: leadFigure.baseline
            text: root.figureParts.suffix
            color: root.inkSecondary
            size: Math.round(parent.figureSize * 0.45)
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            visible: !root.small
            anchors.baseline: leadFigure.baseline
            text: root.figureName
            color: root.inkSecondary
            size: 14
        }
    }

    component Fact: ColumnLayout {
        id: fact
        property string glyph: ""
        property string label: ""
        property string value: ""
        spacing: root.dp(8)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(8)
            MaterialSymbol {
                text: fact.glyph
                fill: 1
                iconSize: root.px(15)
                color: root.warm
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: fact.label
                color: root.inkSecondary
                size: 13
            }
            FaceText {
                face: root
                text: fact.value
                size: 13
                weight: Font.DemiBold
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(2)
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: root.sunKnown ? root.next.glyph : "timelapse"
            text: root.sunKnown ? root.next.name : Translation.tr("Until midnight")
            tint: root.warm
        }
        Lead { figureSize: 30 }
        SunPath {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dp(6)
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            Layout.topMargin: root.dp(4)
            visible: root.sunKnown
            text: root.other.name + " " + root.other.time
            color: root.inkSecondary
            size: 12
        }
    }

    ColumnLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(2)
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: root.daytime ? "light_mode" : "bedtime"
            text: IrisFaceData.capitalized(Translation.locale.toString(DateTime.clock.date, "dddd d"))
            tint: root.warm
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(10)
            Lead { figureSize: root.large ? 44 : 38 }
            Item { Layout.fillWidth: true }
            // Medium keeps its facts beside the figure; large lists them under the path.
            ColumnLayout {
                visible: root.medium && root.sunKnown
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: root.dp(4)
                spacing: 0
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignRight
                    text: root.other.name + " " + root.other.time
                    color: root.inkSecondary
                    size: 12
                }
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignRight
                    text: Translation.tr("Daylight") + " " + root.daylight
                    color: root.inkTertiary
                    size: 12
                }
            }
        }
        SunPath {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dp(6)
        }
        Hours { Layout.fillWidth: true; Layout.topMargin: root.dp(2) }
        ColumnLayout {
            visible: root.large
            Layout.fillWidth: true
            Layout.topMargin: root.dp(12)
            spacing: root.dp(8)
            Fact {
                visible: root.sunKnown
                Layout.fillWidth: true
                glyph: root.other.glyph
                label: root.other.name
                value: root.other.time
            }
            Fact {
                visible: root.sunKnown
                Layout.fillWidth: true
                glyph: "light_mode"
                label: Translation.tr("Daylight")
                value: root.daylight
            }
            Fact {
                Layout.fillWidth: true
                glyph: "dark_mode"
                label: Translation.tr("Moon")
                value: Weather.moonPhaseName
            }
        }
    }
}
