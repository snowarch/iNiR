pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style

IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetWorldClock")

    readonly property var cities: Array.from(root.widget.cities ?? []).slice(0, 4)
    readonly property int localOffset: -WorldClock.now.getTimezoneOffset()

    function shift(index: int): string {
        const delta = ((WorldClock.offsetsMinutes[index] ?? 0) - root.localOffset) / 60
        const hours = Math.abs(delta) % 1 === 0 ? Math.abs(delta) : Math.abs(delta).toFixed(1)
        const day = root.widget.cityDayDelta(index)
        const dayWord = day > 0 ? Translation.tr("Tomorrow") : day < 0 ? Translation.tr("Yesterday") : Translation.tr("Today")
        return delta === 0 ? dayWord : dayWord + ", " + (delta > 0 ? "+" : "−") + hours + " h"
    }

    // A city's day: the 24 hours around now, daylight in the warm fade (brightest at noon, as the Day's sun peaks),
    // now the notch in the middle. Where it is day reads across the cities.
    component DayBand: Item {
        id: band
        required property int index
        readonly property var local: WorldClock.cityDisplayDate(band.index)
        readonly property real hour: band.local.getHours() + band.local.getMinutes() / 60
        // daylight as WorldClock reads it (6 to 18), for yesterday, today and tomorrow, cut to the band
        readonly property var days: [-24, 0, 24].map(shift => ({ from: Math.max(6 + shift, band.hour - 12),
            to: Math.min(18 + shift, band.hour + 12), noon: 12 + shift })).filter(span => span.to - span.from > 0.05)
        function glow(at: real, noon: real): color {
            return Qt.alpha(root.warm, 0.3 + 0.55 * (1 - Math.min(1, Math.abs(at - noon) / 6)))
        }
        height: root.dp(6)
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.capsule(height)
            color: root.fillQuiet
        }
        Repeater {
            model: band.days
            Rectangle {
                id: daylight
                required property var modelData
                readonly property real noonAt: Math.max(0, Math.min(1, (modelData.noon - modelData.from) / (modelData.to - modelData.from)))
                x: Math.round((modelData.from - band.hour + 12) / 24 * band.width)
                width: Math.round((modelData.to - band.hour + 12) / 24 * band.width) - x
                height: band.height
                radius: IrisStyle.capsule(height)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: band.glow(daylight.modelData.from, daylight.modelData.noon) }
                    GradientStop { position: daylight.noonAt; color: band.glow(Math.min(daylight.modelData.to, Math.max(daylight.modelData.from, daylight.modelData.noon)), daylight.modelData.noon) }
                    GradientStop { position: 1; color: band.glow(daylight.modelData.to, daylight.modelData.noon) }
                }
            }
        }
        Rectangle {
            x: Math.round((band.width - width) / 2)
            y: -root.dp(3)
            width: root.dp(2)
            height: band.height + root.dp(6)
            radius: width / 2
            color: root.ink
        }
    }

    FaceText {
        face: root
        visible: root.cities.length === 0
        anchors.centerIn: parent
        text: Translation.tr("Add a city")
        color: root.inkTertiary
        size: 12.5
    }

    // Side by side (medium, or one or two cities on a small face): each city its name, its time as the figure, how far
    // it is and its day drawn under it. Three or four on a small face are rows, a city and its time each.
    readonly property bool rows: root.small && root.cities.length > 2
    Row {
        id: columns
        visible: !root.large && !root.rows
        readonly property int count: Math.max(1, root.cities.length)
        readonly property real gap: root.dp(root.small ? 14 : 18)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: columns.gap
        Repeater {
            model: root.large || root.rows ? [] : root.cities
            Column {
                id: city
                required property var modelData
                required property int index
                width: (columns.width - (columns.count - 1) * columns.gap) / columns.count
                spacing: root.dp(2)
                FaceText {
                    face: root
                    width: Math.min(implicitWidth, city.width)
                    visible: root.widget.showNames
                    text: city.modelData.name
                    color: city.modelData.isDay ? root.ink : root.inkSecondary
                    size: root.small ? 12 : 13
                    weight: Font.DemiBold
                }
                FaceFigure {
                    face: root
                    text: city.modelData.time
                    size: columns.count === 1 ? (root.small ? 46 : 52) : columns.count === 2 ? (root.small ? 30 : 40) : columns.count === 3 ? 32 : 26
                    tone: city.modelData.isDay ? root.ink : root.inkSecondary
                }
                FaceText {
                    face: root
                    width: Math.min(implicitWidth, city.width)
                    visible: root.widget.showOffsets
                    text: root.shift(city.index)
                    color: root.inkTertiary
                    size: 11
                }
                Item { width: 1; height: root.dp(8) }
                DayBand {
                    index: city.index
                    width: city.width
                }
            }
        }
    }

    Item {
        id: smallRows
        visible: root.rows
        anchors.fill: parent
        Repeater {
            model: root.rows ? root.cities : []
            Item {
                id: smallRow
                required property var modelData
                required property int index
                readonly property real pitch: smallRows.height / root.cities.length
                y: Math.round(smallRow.index * smallRow.pitch)
                width: smallRows.width
                height: Math.round((smallRow.index + 1) * smallRow.pitch) - y
                Rectangle {
                    visible: smallRow.index > 0
                    width: parent.width
                    height: 1
                    color: root.hairline
                }
                FaceText {
                    face: root
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - smallTime.width - root.dp(8))
                    text: smallRow.modelData.name
                    color: smallRow.modelData.isDay ? root.ink : root.inkSecondary
                    size: 12.5
                    weight: Font.DemiBold
                }
                FaceFigure {
                    id: smallTime
                    face: root
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width - width
                    text: smallRow.modelData.time
                    size: 18
                    tone: smallRow.modelData.isDay ? root.ink : root.inkSecondary
                }
            }
        }
    }

    // Large: a row per city, its time the figure (no dial saying it again) and its day drawn under it: the 24 hours
    // around now, daylight in the warm fade, now the notch in the middle. Where it is day reads down the rows.
    Item {
        id: largeRows
        visible: root.large
        anchors.fill: parent
        readonly property real band: root.dp(6)
        Repeater {
            model: root.large ? root.cities : []
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property real pitch: largeRows.height / root.cities.length
                y: Math.round(row.index * row.pitch)
                width: largeRows.width
                height: Math.round((row.index + 1) * row.pitch) - y
                Rectangle {
                    visible: row.index > 0
                    width: parent.width
                    height: 1
                    color: root.hairline
                }
                Column {
                    id: rowText
                    y: Math.round((parent.height - largeRows.band - root.dp(10) - height) / 2)
                    width: parent.width - rowTime.width - root.dp(12)
                    FaceText {
                        face: root
                        width: Math.min(implicitWidth, rowText.width)
                        text: row.modelData.name
                        size: 14
                        weight: Font.DemiBold
                    }
                    FaceText {
                        face: root
                        width: Math.min(implicitWidth, rowText.width)
                        text: root.shift(row.index)
                        color: root.inkSecondary
                        size: 12
                    }
                }
                FaceFigure {
                    id: rowTime
                    face: root
                    x: parent.width - width
                    y: Math.round(rowText.y + (rowText.height - height) / 2)
                    text: row.modelData.time
                    size: 30
                    tone: row.modelData.isDay ? root.ink : root.inkSecondary
                }
                DayBand {
                    index: row.index
                    y: Math.round(parent.height - largeRows.band - (row.index < root.cities.length - 1 ? root.dp(12) : 0)) - root.dp(2)
                    width: parent.width
                }
            }
        }
    }
}
