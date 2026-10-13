pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's weather widget: a forecast set like a station's board. Where it is as a ruby in the data face's capitals, the
// temperature as the hero figure leaning, the sky's sign and its word under it, the day's range in the data face. Given
// room, the next hours stand beside it as a timetable: each hour's time, a bar as tall as its temperature among them
// (the hour that is now in shu, the only seal on the widget) and its figure; on a large widget the next days follow as
// rows, each a run from its low to its high on the week's scale. The engine's face keeps the data, the size and the stock.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    readonly property bool large: root.face?.large ?? false
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(root.small ? 14 : 16)
    readonly property var hours: root.face?.hours ?? []
    readonly property var days: root.face?.days ?? []
    readonly property var temps: root.hours.map(h => parseFloat(String(h.temp))).filter(Number.isFinite)
    readonly property real low: root.temps.length > 0 ? Math.min(...root.temps) : 0
    readonly property real high: root.temps.length > 0 ? Math.max(...root.temps) : 1

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }

    // ── Now.
    Column {
        id: now
        x: root.pad
        y: root.pad
        width: (root.small ? root.width : Math.round(root.width * 0.42)) - 2 * root.pad
        spacing: root.dp(2)
        AText {
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: String(root.face?.city ?? "").length > 0 ? root.face.city : Translation.tr("Weather")
        }
        AText {
            width: parent.width
            voice: "figure"
            lean: Airisu.lean
            size: root.px(root.large ? 62 : 52)
            color: stock.ink
            text: (root.face?.ready ?? false) ? String(root.face?.widget?.temperatureText ?? "") : "--"
        }
    }
    Column {
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: now.width
        spacing: root.dp(2)
        Row {
            spacing: root.dp(6)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: root.face?.glyph ?? "cloud"
                iconSize: root.px(18)
                fill: 1
                color: stock.ink
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, now.width - root.px(24))
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: stock.ink
                text: root.face?.condition ?? ""
            }
        }
        AText {
            visible: text.length > 0
            width: parent.width
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkThird
            text: root.face?.range ?? ""
        }
    }

    // ── The next hours, as a timetable.
    Row {
        id: timetable
        visible: !root.small && root.hours.length > 0
        x: Math.round(root.width * 0.42) + root.dp(4)
        y: root.pad
        width: root.width - x - root.pad
        height: (root.large ? Math.round(root.height * 0.46) : root.height) - 2 * root.pad
        readonly property real column: timetable.width / Math.max(1, root.hours.length)
        Repeater {
            model: root.hours
            Item {
                id: hour
                required property var modelData
                required property int index
                readonly property real temp: parseFloat(String(hour.modelData.temp))
                readonly property real share: Number.isFinite(hour.temp) && root.high > root.low ? (hour.temp - root.low) / (root.high - root.low) : 0.5
                width: timetable.column
                height: timetable.height
                AText {
                    id: when
                    anchors.horizontalCenter: parent.horizontalCenter
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: hour.index === 0 ? stock.ink : stock.inkThird
                    text: hour.index === 0 ? Translation.tr("Now") : String(hour.modelData.label ?? "").slice(0, 2)
                }
                MaterialSymbol {
                    id: sign
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: when.height + root.dp(4)
                    text: Icons.getWeatherIcon(hour.modelData.code, hour.modelData.isNight) ?? "cloud"
                    iconSize: root.px(15)
                    color: hour.index === 0 ? stock.ink : stock.inkSecond
                }
                AText {
                    id: figure
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    voice: "figure"
                    lean: Airisu.lean
                    size: IrisStyle.typeLabel
                    color: hour.index === 0 ? stock.ink : stock.inkSecond
                    text: String(root.face?.degrees(hour.modelData.temp) ?? "")
                }
                // How warm, as a bar among the hours shown.
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: sign.y + sign.height + root.dp(6)
                    width: Math.max(2, root.dp(3))
                    height: figure.y - y - root.dp(6)
                    Rectangle {
                        anchors.fill: parent
                        color: Airisu.slot
                        antialiasing: false
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(root.dp(3), Math.round(parent.height * (0.18 + 0.82 * hour.share)))
                        color: hour.index === 0 ? Airisu.seal : stock.ink
                        antialiasing: false
                    }
                }
            }
        }
    }

    // ── The next days, each a run on the week's scale.
    Column {
        visible: root.large && root.days.length > 0
        x: timetable.x
        y: timetable.y + timetable.height + root.dp(10)
        width: timetable.width
        spacing: root.dp(4)
        Repeater {
            model: root.days
            Item {
                id: day
                required property var modelData
                readonly property real span: Math.max(1, (root.face?.weekHigh ?? 1) - (root.face?.weekLow ?? 0))
                width: parent.width
                height: root.px(18)
                AText {
                    id: dayName
                    width: root.px(46)
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "mono"
                    size: IrisStyle.typeCaption
                    color: stock.inkSecond
                    text: String(day.modelData.dayName ?? "").slice(0, 3)
                }
                AText {
                    id: lo
                    x: dayName.width
                    width: root.px(32)
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: stock.inkThird
                    text: String(root.face?.degrees(day.modelData.lo) ?? "")
                }
                Item {
                    id: lane
                    x: lo.x + lo.width + root.dp(8)
                    width: parent.width - x - hi.width - root.dp(8)
                    height: root.dp(4)
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.fill: parent; color: Airisu.slot; antialiasing: false }
                    Rectangle {
                        x: parent.width * (Number(day.modelData.loVal) - (root.face?.weekLow ?? 0)) / day.span
                        width: Math.max(parent.height, parent.width * (Number(day.modelData.hiVal) - Number(day.modelData.loVal)) / day.span)
                        height: parent.height
                        color: stock.ink
                        antialiasing: false
                    }
                }
                AText {
                    id: hi
                    anchors.right: parent.right
                    width: root.px(32)
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: stock.ink
                    text: String(root.face?.degrees(day.modelData.hi) ?? "")
                }
            }
        }
    }
}
