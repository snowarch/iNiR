pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's desk clock (SYSTEM.md §6, §7; board 07), printed in flat inks on the widget's stock. Digital, the time is the
// figure in large Archivo SemiExpanded on the foot, with the date set over it as ruby. Analog, it is a date stamp (消印)
// struck at this minute: the time in the band, the weekday over it and the date in figures under it. Wide, the stamp
// stands beside the sky it was struck under.
// Settings › Widgets (Material, Opacity, Tint, Face, Seconds, size) keep their meaning through `face` and `AStock`.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    readonly property bool large: root.face?.large ?? false
    readonly property bool analog: root.face?.analog ?? false
    readonly property date now: root.face?.now ?? new Date()
    readonly property bool ticking: (root.face?.seconds ?? false) && (root.face?.moving ?? false)
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: Airisu.u(root.small ? 3 : 4)
    readonly property string ruby: [String(root.face?.weekday ?? ""), String(root.face?.longDate ?? "")]
        .filter(part => part.length > 0).join(" · ")

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }

    // ── Digital: the date as ruby, the time under it as large as the stock takes, both on the foot.
    AText {
        id: time
        visible: !root.analog
        readonly property real room: root.width - 2 * root.pad
        readonly property real tall: root.height - 2 * root.pad - rubyLine.implicitHeight - Airisu.m
        readonly property real nominal: root.px(root.small ? 56 : root.large ? 168 : 104)
        x: root.pad - Math.round(time.size * 0.04)
        y: Math.round(root.height - root.pad - time.size * 0.86)
        width: time.room + Math.round(time.size * 0.04)
        elide: Text.ElideNone
        voice: "figure"
        lean: Airisu.lean
        size: Math.max(IrisStyle.typeTitle, Math.floor(Math.min(time.nominal * time.room / Math.max(1, measure.advanceWidth),
            time.tall / 0.86, time.nominal)))
        color: stock.ink
        text: String(root.face?.timeText ?? "")
        TextMetrics {
            id: measure
            font.family: Airisu.figureFace
            font.weight: Font.ExtraBold
            font.features: ({ "tnum": 1 })
            font.pixelSize: time.nominal
            font.letterSpacing: -Math.round(time.nominal * 0.03)
            text: time.text
        }
    }
    AText {
        id: rubyLine
        visible: !root.analog
        x: root.pad
        y: Math.round(time.y + time.size * 0.12 - implicitHeight)
        width: Math.min(implicitWidth, root.width - 2 * root.pad)
        size: root.px(root.small ? IrisStyle.typeCaption : IrisStyle.typeLabel)
        font.weight: Font.Medium
        font.letterSpacing: Math.round(size * 0.04)
        color: stock.inkSecond
        text: root.ruby
    }

    // ── Beside the stamp, when the widget is wide: the sky the stamp was struck under, or, with no forecast, the day
    // in words (the stamp prints it in figures).
    Column {
        id: beside
        readonly property real room: root.width - stamp.x - stamp.width - root.pad - Airisu.u(5)
        readonly property bool weather: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
        readonly property string temp: String(Weather.data?.temp ?? "")
        readonly property string figure: beside.temp.replace(/°?[CF]$/, "")
        visible: root.analog && !root.small && beside.room >= root.dp(72)
        x: stamp.x + stamp.width + Airisu.u(5)
        y: Math.round((root.height - height) / 2)
        width: beside.room
        spacing: 0
        AText {
            width: Math.min(implicitWidth, beside.width)
            size: root.px(IrisStyle.typeLabel)
            font.weight: Font.Medium
            color: stock.inkSecond
            text: beside.weather ? String(Weather.data?.description ?? "") : String(root.face?.weekday ?? "")
        }
        Row {
            AText {
                id: besideFigure
                readonly property real nominal: Math.round(stamp.r * 0.42)
                width: Math.min(implicitWidth, beside.width - unit.implicitWidth)
                voice: "figure"
                lean: Airisu.lean
                size: Math.max(IrisStyle.typeHeadline, Math.floor(Math.min(besideFigure.nominal,
                    besideFigure.nominal * beside.width / Math.max(1, besideMeasure.advanceWidth))))
                color: stock.ink
                text: beside.weather ? beside.figure : String(root.face?.longDate ?? "")
                TextMetrics {
                    id: besideMeasure
                    font.family: Airisu.figureFace
                    font.weight: Font.ExtraBold
                    font.pixelSize: besideFigure.nominal
                    text: besideFigure.text
                }
            }
            AText {
                id: unit
                visible: beside.weather
                anchors.baseline: besideFigure.baseline
                size: root.px(IrisStyle.typeLabel)
                font.weight: Font.Bold
                color: stock.ink
                text: beside.temp.slice(beside.figure.length)
            }
        }
    }

    // ── Analog: the date stamp (丸型日付印), struck now. A heavy ring and a fine one; across the middle the band ruled
    // from rim to rim, the time set in it where a post office sets the date; the weekday in the upper segment and the
    // date in figures in the lower one, as the stamp's own line. While seconds run they stand after the time in shu, the
    // one live thing. No hands: a stamp tells the minute it was struck. A segment's line is cut whole inside the fine
    // ring or left off, the weekday first, then the date; the band always carries the time.
    Item {
        id: stamp
        visible: root.analog
        readonly property real side: Math.floor(root.small ? Math.min(root.width, root.height) - 2 * root.pad
            : Math.min(root.height - 2 * root.pad, root.width * 0.56))
        width: stamp.side
        height: stamp.side
        x: root.small ? Math.round((root.width - width) / 2) : root.pad
        y: Math.round((root.height - height) / 2)
        readonly property real r: stamp.side / 2
        readonly property real heavy: Math.max(2, Math.round(stamp.r * 0.05))
        readonly property real fine: Math.max(1, Math.round(stamp.r * 0.018))
        readonly property real inner: stamp.r * 0.85
        // Half the band's height, and where the band's rules cut the inner ring.
        readonly property real b: Math.round(stamp.r * 0.23)
        readonly property real rule: Math.max(1, Math.round(stamp.heavy * 0.6))
        readonly property real innerX: Math.sqrt(Math.max(0, stamp.inner * stamp.inner - stamp.b * stamp.b))
        readonly property real rimX: Math.sqrt(Math.max(0, Math.pow(stamp.r - stamp.heavy / 2, 2) - stamp.b * stamp.b))
        // How wide a line may run whose far edge sits `far` from the middle: the fine ring's chord there, a ring's
        // breadth in. A segment's line also keeps clear of the band's rule.
        function chord(far: real): real {
            const room = stamp.inner - 2 * stamp.fine
            return far >= room ? 0 : 2 * Math.sqrt(room * room - far * far)
        }
        function holds(line: Item, middle: real): bool {
            return line.implicitHeight / 2 <= middle - stamp.b - stamp.rule
                && line.implicitWidth <= stamp.chord(middle + line.implicitHeight / 2)
        }
        readonly property bool dateFits: stamp.holds(stampDate, stamp.b + stamp.r * 0.21)
        readonly property bool weekdayFits: stamp.dateFits && stamp.holds(weekdayLine, stamp.b + stamp.r * 0.2)

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // The rim.
            ShapePath {
                fillColor: "transparent"
                strokeColor: stock.ink
                strokeWidth: stamp.heavy
                startX: stamp.r; startY: stamp.heavy / 2
                PathArc { x: stamp.r; y: stamp.side - stamp.heavy / 2; radiusX: stamp.r - stamp.heavy / 2; radiusY: stamp.r - stamp.heavy / 2 }
                PathArc { x: stamp.r; y: stamp.heavy / 2; radiusX: stamp.r - stamp.heavy / 2; radiusY: stamp.r - stamp.heavy / 2 }
            }
            // The fine ring, broken by the band.
            ShapePath {
                fillColor: "transparent"
                strokeColor: stock.ink
                strokeWidth: stamp.fine
                startX: stamp.r - stamp.innerX; startY: stamp.r - stamp.b
                PathArc { x: stamp.r + stamp.innerX; y: stamp.r - stamp.b; radiusX: stamp.inner; radiusY: stamp.inner }
                PathMove { x: stamp.r + stamp.innerX; y: stamp.r + stamp.b }
                PathArc { x: stamp.r - stamp.innerX; y: stamp.r + stamp.b; radiusX: stamp.inner; radiusY: stamp.inner }
            }
            // The band's rules, rim to rim.
            ShapePath {
                fillColor: "transparent"
                strokeColor: stock.ink
                strokeWidth: stamp.rule
                startX: stamp.r - stamp.rimX; startY: stamp.r - stamp.b
                PathLine { x: stamp.r + stamp.rimX; y: stamp.r - stamp.b }
                PathMove { x: stamp.r - stamp.rimX; y: stamp.r + stamp.b }
                PathLine { x: stamp.r + stamp.rimX; y: stamp.r + stamp.b }
            }
        }

        // The upper segment: the weekday, spaced as a stamp's lettering is cut.
        AText {
            id: weekdayLine
            visible: stamp.weekdayFits
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(stamp.r - stamp.b - stamp.r * 0.2 - height / 2)
            elide: Text.ElideNone
            size: Math.max(IrisStyle.typeCaption, Math.round(stamp.r * 0.13))
            font.weight: Font.Bold
            font.letterSpacing: Math.round(size * 0.12)
            font.capitalization: Font.AllUppercase
            color: stock.ink
            text: String(root.face?.weekday ?? "")
        }
        // The band: the time, as large as the band holds, the seconds after it in shu while they run.
        Row {
            id: struck
            anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(stamp.r - bandTime.height / 2 + bandTime.size * 0.04)
            spacing: Math.round(bandTime.size * 0.06)
            readonly property real room: 2 * stamp.innerX - 2 * stamp.heavy
            // Solved at the nominal size, so the band never measures what it sizes. The seconds come along only while
            // the time and they, both at their floors, still fit the band; otherwise the band carries the time alone.
            function fitted(width: real): int {
                return Math.max(IrisStyle.typeCaption, Math.floor(Math.min(bandTime.nominal, bandTime.nominal * struck.room / Math.max(1, width))))
            }
            readonly property int withSeconds: struck.fitted(bandMeasure.advanceWidth + secondsMeasure.advanceWidth + bandTime.nominal * 0.06)
            readonly property int secondsSize: Math.max(IrisStyle.typeCaption, Math.round(struck.withSeconds * 0.4))
            readonly property bool secondsFit: root.ticking
                && bandMeasure.advanceWidth * struck.withSeconds / bandTime.nominal + Math.round(struck.withSeconds * 0.06)
                    + secondsMeasure.advanceWidth * struck.secondsSize / secondsMeasure.font.pixelSize <= struck.room
            AText {
                id: bandTime
                readonly property real nominal: Math.floor(stamp.b * 2 * 0.86 / 0.74)
                voice: "figure"
                lean: Airisu.lean
                size: struck.secondsFit ? struck.withSeconds : struck.fitted(bandMeasure.advanceWidth)
                color: stock.ink
                text: String(root.face?.timeText ?? "")
                TextMetrics {
                    id: bandMeasure
                    font.family: Airisu.figureFace
                    font.weight: Font.ExtraBold
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: bandTime.nominal
                    font.letterSpacing: -Math.round(bandTime.nominal * 0.03)
                    text: bandTime.text
                }
                TextMetrics {
                    id: secondsMeasure
                    font.family: Airisu.figureFace
                    font.weight: Font.ExtraBold
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: Math.round(bandTime.nominal * 0.4)
                    text: "00"
                }
            }
            AText {
                id: seconds
                visible: struck.secondsFit
                anchors.baseline: bandTime.baseline
                voice: "figure"
                lean: Airisu.lean
                size: struck.secondsSize
                color: stock.vivid
                text: String(root.now.getSeconds()).padStart(2, "0")
            }
        }
        // The lower segment: the date in figures, day · month · year, as the stamp's band would carry it.
        AText {
            id: stampDate
            visible: stamp.dateFits
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(stamp.r + stamp.b + stamp.r * 0.21 - height / 2)
            elide: Text.ElideNone
            voice: "figure"
            size: Math.max(IrisStyle.typeCaption, Math.round(stamp.r * 0.15))
            color: stock.ink
            text: Translation.locale.toString(root.now, "d·MM·yy")
        }
    }
}
