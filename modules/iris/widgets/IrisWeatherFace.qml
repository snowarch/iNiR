pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

// The weather as SekaiPop's card builds it, in iRiS: a plate (the conditions over the temperature, today's high and low
// beside it, the sky as a disc, the place on a tab), three gauges (humidity as a tank that fills, the wind as a dial
// whose arrow points where it blows, UV as five dots) and the forecast as a melody of the next hours or a list of days.
// Pointing at an hour reads it out on the plate's top line.
IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetWeather")

    readonly property bool ready: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property string glyph: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
    readonly property color sky: IrisStyle.skyLight(root.glyph)
    // The town, not its province: "Avellaneda, Bueno…" told less than "Avellaneda".
    readonly property string city: root.widget.showLocation && Weather.showVisibleCity
        ? String(Weather.visibleCity).split(",")[0].trim() : ""
    readonly property string condition: IrisFaceData.capitalized(String(Weather.data?.description ?? ""))
    readonly property string high: root.degrees(Weather.data?.tempMax)
    readonly property string low: root.degrees(Weather.data?.tempMin)
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, 6)
    readonly property var days: Array.from(Weather.data?.forecast ?? []).slice(0, 5)
    readonly property var lows: root.days.map(day => Number(day.loVal)).filter(Number.isFinite)
    readonly property var highs: root.days.map(day => Number(day.hiVal)).filter(Number.isFinite)
    readonly property real weekLow: root.lows.length > 0 ? Math.min(...root.lows) : 0
    readonly property real weekHigh: root.highs.length > 0 ? Math.max(...root.highs) : 1
    readonly property real humidity: Math.max(0, Math.min(100, parseFloat(String(Weather.data?.humidity ?? "0")) || 0))
    readonly property string windSpeed: String(Weather.data?.wind ?? "").replace(/[^0-9.]/g, "")
    readonly property string windUnit: String(Weather.data?.wind ?? "").replace(/[0-9.\s]/g, "")
    // Where the wind blows to, clockwise from up: the reading says where it comes from.
    readonly property real windTo: (({ N: 0, NNE: 22.5, NE: 45, ENE: 67.5, E: 90, ESE: 112.5, SE: 135, SSE: 157.5, S: 180,
        SSW: 202.5, SW: 225, WSW: 247.5, W: 270, WNW: 292.5, NW: 315, NNW: 337.5 })[String(Weather.data?.windDir ?? "N").toUpperCase()] ?? 0) + 180
    readonly property real uv: Math.max(0, parseFloat(String(Weather.data?.uv ?? "0")) || 0)
    readonly property string uvWord: root.uv < 3 ? Translation.tr("Low") : root.uv < 6 ? Translation.tr("Moderate")
        : root.uv < 8 ? Translation.tr("High") : root.uv < 11 ? Translation.tr("Very high") : Translation.tr("Extreme")
    readonly property bool showDays: String(root.widget.irisOption("forecast", "hours")) === "days"
    // What the pointer reads out on the top line ("" = the conditions).
    property string readout: ""

    function degrees(value: var): string {
        const text = String(value ?? "").trim()
        if (text.length === 0 || text.startsWith("--"))
            return ""
        return text.replace(/°[CF]$/, "°").replace(/([0-9])$/, "$1°")
    }
    function tempOf(value: var): real { return parseFloat(String(value ?? "")) }

    light: root.ready ? root.sky : "transparent"

    // The sky as a disc: a soft wash of its own colour with the glyph inside.
    component Disc: Rectangle {
        property real side: root.dp(34)
        width: side
        height: side
        radius: side / 2
        color: Qt.alpha(root.sky, 0.2)
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.glyph
            fill: 1
            iconSize: Math.round(parent.side * 0.56)
            color: root.sky
        }
    }

    // The conditions over the temperature, the high and low beside it.
    component Plate: ColumnLayout {
        id: plate
        property real figure: 44
        spacing: 0
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.readout.length > 0 ? root.readout
                : Weather.stale ? (!Network.online ? Translation.tr("Offline · %1").arg(Weather.updatedLabel)
                    : Translation.tr("Updated %1").arg(Weather.updatedLabel))
                : root.condition
            color: root.readout.length > 0 ? root.ink : Weather.stale ? root.inkTertiary : root.inkSecondary
            size: 12.5
            weight: Font.DemiBold
        }
        RowLayout {
            spacing: root.dp(8)
            FaceFigure {
                face: root
                text: root.widget.temperatureText
                size: plate.figure
            }
            ColumnLayout {
                visible: root.high.length > 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Repeater {
                    model: [{ glyph: "arrow_upward", text: root.high }, { glyph: "arrow_downward", text: root.low }]
                    RowLayout {
                        id: extreme
                        required property var modelData
                        spacing: root.dp(1)
                        MaterialSymbol {
                            text: extreme.modelData.glyph
                            iconSize: root.px(12)
                            color: root.inkTertiary
                        }
                        FaceText {
                            face: root
                            text: extreme.modelData.text
                            size: 12.5
                            weight: Font.DemiBold
                            color: root.inkSecondary
                            font.family: root.fontNumbers
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }
    }

    // The place on a tab.
    component Place: Rectangle {
        visible: root.city.length > 0
        implicitWidth: placeRow.implicitWidth + root.dp(14)
        implicitHeight: root.dp(22)
        radius: height / 2
        color: root.fillQuiet
        RowLayout {
            id: placeRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - root.dp(14))
            spacing: root.dp(3)
            MaterialSymbol {
                text: "location_on"
                fill: 1
                iconSize: root.px(12)
                color: root.accent
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                text: root.city
                size: 11.5
                weight: Font.DemiBold
            }
        }
    }

    // One gauge on its own tile: a glyph and a word on top, the instrument, the value under it.
    component Gauge: Rectangle {
        id: gauge
        property string glyph: ""
        property string word: ""
        property string value: ""
        property string unit: ""
        property bool wide: false
        default property alias instrument: slot.data
        radius: root.innerRadius
        color: root.fillQuiet
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.dp(gauge.wide ? 10 : 6)
            spacing: root.dp(4)
            RowLayout {
                Layout.alignment: gauge.wide ? Qt.AlignLeft : Qt.AlignHCenter
                spacing: root.dp(3)
                MaterialSymbol {
                    text: gauge.glyph
                    fill: 1
                    iconSize: root.px(12)
                    color: root.inkSecondary
                }
                FaceText {
                    face: root
                    visible: gauge.wide
                    text: gauge.word
                    size: 11
                    weight: Font.DemiBold
                    color: root.inkSecondary
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(8)
                Item {
                    id: slot
                    Layout.fillWidth: !gauge.wide
                    Layout.fillHeight: true
                    Layout.preferredWidth: gauge.wide ? root.dp(34) : -1
                }
                ColumnLayout {
                    visible: gauge.wide
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    FaceFigure {
                        face: root
                        text: gauge.value
                        size: 22
                    }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: gauge.unit
                        size: 11
                        color: root.inkSecondary
                    }
                }
            }
            FaceText {
                face: root
                visible: !gauge.wide
                Layout.alignment: Qt.AlignHCenter
                text: gauge.value + (gauge.unit.length > 0 && gauge.unit.length <= 1 ? gauge.unit : "")
                size: 13
                weight: Font.DemiBold
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
    }

    component Humidity: Gauge {
        glyph: "water_drop"
        word: Translation.tr("Humidity")
        value: String(Math.round(root.humidity))
        unit: "%"
        // A tank that fills from the bottom.
        Rectangle {
            anchors.centerIn: parent
            width: root.dp(16)
            height: Math.min(parent.height, root.dp(46))
            radius: width / 2
            color: root.fill
            clip: true
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(parent.width * 0.5, parent.height * root.humidity / 100)
                radius: parent.radius
                color: root.inked(IrisStyle.identity.sky)
                Behavior on height { enabled: root.moving; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Wind: Gauge {
        glyph: "air"
        word: Translation.tr("Wind")
        value: root.windSpeed.length > 0 ? root.windSpeed : "0"
        unit: root.windUnit
        // A dial whose arrow turns to where the wind goes.
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, root.dp(40))
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, root.dp(1.5))
            border.color: root.hairline
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: Math.max(1, root.dp(1.5))
                    height: root.dp(4)
                    color: root.inkTertiary
                    x: (parent.width - width) / 2
                    y: 0
                    transform: Rotation { origin.x: width / 2; origin.y: parent.height / 2; angle: index * 90 }
                }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "navigation"
                fill: 1
                iconSize: Math.round(parent.width * 0.5)
                color: root.inked(IrisStyle.identity.teal)
                rotation: root.windTo
                Behavior on rotation { enabled: root.moving; RotationAnimation { duration: 520; direction: RotationAnimation.Shortest; easing.type: Easing.OutBack } }
            }
        }
    }

    component Uv: Gauge {
        id: uvGauge
        glyph: "wb_sunny"
        word: Translation.tr("UV index")
        value: String(Math.round(root.uv))
        unit: root.uvWord
        // Five dots, one per two points of the index.
        Column {
            anchors.centerIn: parent
            spacing: root.dp(3)
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    readonly property bool lit: root.uv > (4 - index) * 2 + 0.5 || (index === 4 && root.uv > 0)
                    width: root.dp(uvGauge.wide ? 9 : 8)
                    height: width
                    radius: width / 2
                    color: lit ? root.inked(index < 2 ? IrisStyle.identity.red : index < 3 ? IrisStyle.identity.orange : IrisStyle.identity.yellow) : root.fill
                    Behavior on color { enabled: root.moving; ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                }
            }
        }
    }

    // The next hours as a melody: a note on a line that rises and falls with the temperature.
    component Melody: Item {
        id: melody
        readonly property var temps: root.hours.map(hour => root.tempOf(hour.temp))
        readonly property var known: melody.temps.filter(Number.isFinite)
        readonly property real hi: melody.known.length > 0 ? Math.max(...melody.known) : 1
        readonly property real lo: melody.known.length > 0 ? Math.min(...melody.known) : 0
        readonly property real pitch: root.hours.length > 0 ? melody.width / root.hours.length : 0
        readonly property real laneTop: root.dp(30)
        readonly property real laneBottom: melody.height - root.dp(32)
        function xOf(i: int): real { return melody.pitch * (i + 0.5) }
        function yOf(i: int): real {
            const t = melody.temps[i]
            const span = Math.max(1, melody.hi - melody.lo)
            return melody.laneBottom - (Number.isFinite(t) ? (t - melody.lo) / span : 0.5) * (melody.laneBottom - melody.laneTop)
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.sky, 0.85)
                strokeWidth: Math.max(1.5, root.dp(2))
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.hours.map((_, i) => Qt.point(melody.xOf(i), melody.yOf(i))) }
            }
        }
        Repeater {
            model: root.hours
            Item {
                id: note
                required property var modelData
                required property int index
                readonly property bool now: note.index === 0
                readonly property string glyph: Icons.getWeatherIcon(note.modelData.code, note.modelData.isNight) ?? "cloud"
                readonly property string hour: note.now ? Translation.tr("Now") : String(note.modelData.label).slice(0, 5)
                x: note.index * melody.pitch
                width: melody.pitch
                height: melody.height
                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    text: note.glyph
                    fill: 1
                    iconSize: root.px(16)
                    color: IrisStyle.skyLight(note.glyph)
                }
                FaceText {
                    face: root
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: melody.yOf(note.index) - height - root.dp(5)
                    text: root.degrees(note.modelData.temp)
                    size: 11.5
                    weight: Font.DemiBold
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
                Rectangle {
                    x: (parent.width - width) / 2
                    y: melody.yOf(note.index) - height / 2
                    width: root.dp(hoverNote.hovered ? 11 : 8)
                    height: width
                    radius: width / 2
                    color: note.now ? root.accent : root.sky
                    border.width: Math.max(1, root.dp(1.5))
                    border.color: root.knockout
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    implicitWidth: hourText.implicitWidth + root.dp(note.now ? 12 : 0)
                    implicitHeight: hourText.implicitHeight + root.dp(4)
                    width: implicitWidth
                    height: implicitHeight
                    radius: height / 2
                    color: note.now ? root.accent : "transparent"
                    FaceText {
                        id: hourText
                        face: root
                        anchors.centerIn: parent
                        text: note.hour
                        size: 11
                        weight: note.now ? Font.DemiBold : Font.Medium
                        color: note.now ? root.onFill(root.accent) : root.inkSecondary
                        font.features: ({ "tnum": 1 })
                    }
                }
                HoverHandler {
                    id: hoverNote
                    onHoveredChanged: {
                        if (hoverNote.hovered)
                            root.readout = Translation.tr("%1 · %2 · %3").arg(note.hour).arg(root.degrees(note.modelData.temp))
                                .arg(IrisFaceData.capitalized(Weather.describeWeather(note.modelData.code, note.modelData.isNight)))
                        else if (root.readout.length > 0)
                            root.readout = ""
                    }
                }
            }
        }
    }

    // The days as a list: weather, low, the day's range on the week's scale, high.
    component Days: ColumnLayout {
        spacing: 0
        Repeater {
            model: root.days
            RowLayout {
                id: day
                required property var modelData
                required property int index
                readonly property string glyph: Icons.getWeatherIcon(day.modelData.code, false) ?? "cloud"
                readonly property real span: Math.max(1, root.weekHigh - root.weekLow)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(8)
                FaceText {
                    face: root
                    Layout.preferredWidth: root.contentWidth * 0.2
                    text: day.index === 0 ? Translation.tr("Today") : IrisFaceData.capitalized(day.modelData.dayName)
                    size: 12.5
                    weight: Font.DemiBold
                }
                MaterialSymbol {
                    Layout.preferredWidth: root.px(20)
                    text: day.glyph
                    fill: 1
                    iconSize: root.px(16)
                    color: IrisStyle.skyLight(day.glyph)
                }
                FaceText {
                    face: root
                    Layout.preferredWidth: root.px(28)
                    horizontalAlignment: Text.AlignRight
                    text: root.degrees(day.modelData.lo)
                    color: root.inkSecondary
                    size: 12.5
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.dp(5)
                    radius: height / 2
                    color: root.fill
                    Rectangle {
                        x: parent.width * (Number(day.modelData.loVal) - root.weekLow) / day.span
                        width: Math.max(parent.height, parent.width * (Number(day.modelData.hiVal) - Number(day.modelData.loVal)) / day.span)
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: root.inked(IrisStyle.identity.sky) }
                            GradientStop { position: 1; color: root.inked(IrisStyle.identity.orange) }
                        }
                    }
                }
                FaceText {
                    face: root
                    Layout.preferredWidth: root.px(28)
                    text: root.degrees(day.modelData.hi)
                    size: 12.5
                    weight: Font.DemiBold
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    // Hours / Days, a capsule with a sliding thumb, and the refresh key.
    component Keys: RowLayout {
        spacing: root.dp(6)
        Rectangle {
            id: views
            readonly property real cell: root.dp(54)
            implicitWidth: views.cell * 2 + root.dp(4)
            implicitHeight: root.dp(24)
            radius: height / 2
            color: root.fillQuiet
            Rectangle {
                x: root.dp(2) + (root.showDays ? views.cell : 0)
                y: root.dp(2)
                width: views.cell
                height: parent.height - root.dp(4)
                radius: height / 2
                color: root.fillActive
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
            Repeater {
                model: [{ id: "hours", text: Translation.tr("Hourly") }, { id: "days", text: Translation.tr("Days") }]
                Item {
                    id: view
                    required property var modelData
                    required property int index
                    readonly property bool chosen: (view.modelData.id === "days") === root.showDays
                    x: root.dp(2) + view.index * views.cell
                    width: views.cell
                    height: views.height
                    FaceText {
                        face: root
                        anchors.centerIn: parent
                        text: view.modelData.text
                        size: 11
                        weight: view.chosen ? Font.DemiBold : Font.Medium
                        color: view.chosen ? root.ink : root.inkSecondary
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.widget.setIrisOption("forecast", view.modelData.id)
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            implicitWidth: root.dp(24)
            implicitHeight: root.dp(24)
            radius: height / 2
            color: refreshArea.containsMouse ? root.fillHover : root.fillQuiet
            MaterialSymbol {
                id: refreshGlyph
                anchors.centerIn: parent
                text: "refresh"
                iconSize: root.px(14)
                color: root.inkSecondary
                RotationAnimation on rotation {
                    id: spin
                    running: false
                    from: 0
                    to: 360
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { spin.restart(); Weather.fetchWeather() }
            }
        }
    }

    ColumnLayout {
        visible: !root.ready
        anchors.centerIn: parent
        width: parent.width
        spacing: root.dp(6)
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "cloud_off"
            iconSize: root.px(28)
            color: root.inkTertiary
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !Weather.enabled ? Translation.tr("Weather is off")
                : !Network.online ? Network.offlineReason
                : Translation.tr("Looking for the sky…")
            color: root.inkSecondary
            size: 12.5
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
    }

    // Small: the plate on its own.
    Item {
        visible: root.ready && root.small
        anchors.fill: parent
        Plate {
            anchors.left: parent.left
            anchors.right: smallDisc.left
            anchors.rightMargin: root.dp(4)
            anchors.top: parent.top
            figure: 40
        }
        Disc {
            id: smallDisc
            anchors.right: parent.right
            anchors.top: parent.top
            side: root.dp(32)
        }
        Place {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.min(implicitWidth, parent.width)
        }
    }

    // Medium: the plate, then the three gauges.
    RowLayout {
        visible: root.ready && root.medium
        anchors.fill: parent
        spacing: root.dp(10)
        Item {
            Layout.preferredWidth: root.contentWidth * 0.44
            Layout.fillHeight: true
            Plate {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                figure: 42
            }
            Place {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: Math.min(implicitWidth, parent.width)
            }
            Disc {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                side: root.dp(28)
                visible: root.city.length === 0
            }
        }
        Humidity { Layout.fillWidth: true; Layout.fillHeight: true }
        Wind { Layout.fillWidth: true; Layout.fillHeight: true }
        Uv { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    // Large: plate, gauges, then the forecast with its keys.
    ColumnLayout {
        visible: root.ready && root.large
        anchors.fill: parent
        spacing: root.dp(10)
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(10)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: root.dp(6)
                Plate { Layout.fillWidth: true; figure: 50 }
                Place { Layout.maximumWidth: root.contentWidth * 0.6 }
            }
            Disc {
                Layout.alignment: Qt.AlignTop
                side: root.dp(56)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.dp(70)
            Layout.maximumHeight: root.dp(70)
            spacing: root.dp(8)
            Humidity { wide: true; Layout.fillWidth: true; Layout.fillHeight: true }
            Wind { wide: true; Layout.fillWidth: true; Layout.fillHeight: true }
            Uv { wide: true; Layout.fillWidth: true; Layout.fillHeight: true }
        }
        Keys { Layout.fillWidth: true }
        Melody {
            visible: !root.showDays
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        Days {
            visible: root.showDays
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
