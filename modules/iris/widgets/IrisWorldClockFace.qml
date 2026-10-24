pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    // The dial fills what the count leaves: one city is the face, four share it.
    readonly property real contentHeight: root.height - root.padding * 2
    function dialFor(count: int): real {
        const text = root.dp(root.widget.showNames ? 22 : 0) + root.dp(root.widget.showOffsets ? 18 : 0)
        if (root.small)
            return count === 1 ? Math.round(Math.min(root.contentWidth, root.contentHeight - text) * 0.92)
                : count === 2 ? Math.round(Math.min(root.contentWidth / 2 - root.dp(8), root.contentHeight - text - root.dp(8)) * 0.9)
                : root.dp(44)
        return Math.round(Math.min((root.contentWidth - root.dp(18) * (Math.min(4, count) - 1)) / Math.min(4, Math.max(1, count)),
            root.contentHeight - text) * (count <= 2 ? 0.86 : 1))
    }

    component City: ColumnLayout {
        id: city
        required property var modelData
        required property int index
        property real diameter: root.dp(56)
        spacing: root.dp(5)
        FaceDial {
            face: root
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: city.diameter
            Layout.preferredHeight: city.diameter
            time: WorldClock.cityDisplayDate(city.index)
            seconds: false
            numerals: false
            disc: true
            daylight: city.modelData.isDay
        }
        FaceText {
            face: root
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: city.diameter * 1.35
            visible: root.widget.showNames
            text: city.modelData.name
            size: root.small ? 11 : 12
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Math.max(city.diameter * 1.35, root.contentWidth)
            visible: root.widget.showOffsets && (!root.small || root.cities.length === 1)
            text: root.shift(city.index)
            color: root.inkTertiary
            size: 11
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

    // One or two cities are dials; three or four on a small face are rows, a city and its time each, so none ends up
    // alone under the others.
    readonly property bool rows: root.small && root.cities.length > 2
    GridLayout {
        visible: !root.large && !root.rows
        anchors.centerIn: parent
        columns: root.small ? Math.min(2, Math.max(1, root.cities.length)) : Math.min(4, Math.max(1, root.cities.length))
        columnSpacing: root.small ? root.dp(14) : root.dp(18)
        rowSpacing: root.dp(6)
        Repeater {
            model: root.large || root.rows ? [] : root.cities
            City {
                diameter: root.dialFor(root.cities.length)
                Layout.alignment: Qt.AlignHCenter
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
                readonly property var local: WorldClock.cityDisplayDate(row.index)
                readonly property real hour: row.local.getHours() + row.local.getMinutes() / 60
                // daylight as WorldClock reads it (6 to 18), for yesterday, today and tomorrow, cut to the band
                readonly property var days: [-24, 0, 24].map(shift => ({ from: Math.max(6 + shift, row.hour - 12),
                    to: Math.min(18 + shift, row.hour + 12), noon: 12 + shift })).filter(span => span.to - span.from > 0.05)
                // brightest at noon, as the Day's sun peaks
                function glow(at: real, noon: real): color {
                    return Qt.alpha(root.warm, 0.3 + 0.55 * (1 - Math.min(1, Math.abs(at - noon) / 6)))
                }
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
                Item {
                    id: dayBand
                    y: Math.round(parent.height - largeRows.band - (row.index < root.cities.length - 1 ? root.dp(12) : 0)) - root.dp(2)
                    width: parent.width
                    height: largeRows.band
                    Rectangle {
                        anchors.fill: parent
                        radius: IrisStyle.capsule(height)
                        color: root.fillQuiet
                    }
                    Repeater {
                        model: row.days
                        Rectangle {
                            id: daylight
                            required property var modelData
                            readonly property real noonAt: Math.max(0, Math.min(1, (modelData.noon - modelData.from) / (modelData.to - modelData.from)))
                            x: Math.round((modelData.from - row.hour + 12) / 24 * dayBand.width)
                            width: Math.round((modelData.to - row.hour + 12) / 24 * dayBand.width) - x
                            height: dayBand.height
                            radius: IrisStyle.capsule(height)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: row.glow(daylight.modelData.from, daylight.modelData.noon) }
                                GradientStop { position: daylight.noonAt; color: row.glow(Math.min(daylight.modelData.to, Math.max(daylight.modelData.from, daylight.modelData.noon)), daylight.modelData.noon) }
                                GradientStop { position: 1; color: row.glow(daylight.modelData.to, daylight.modelData.noon) }
                            }
                        }
                    }
                    Rectangle {
                        x: Math.round((dayBand.width - width) / 2)
                        y: -root.dp(3)
                        width: root.dp(2)
                        height: dayBand.height + root.dp(6)
                        radius: width / 2
                        color: root.ink
                    }
                }
            }
        }
    }
}
