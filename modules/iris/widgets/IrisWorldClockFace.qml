pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style

IrisWidgetFace {
    id: root

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

    GridLayout {
        visible: !root.large
        anchors.centerIn: parent
        columns: root.small ? Math.min(2, Math.max(1, root.cities.length)) : Math.min(4, Math.max(1, root.cities.length))
        columnSpacing: root.small ? root.dp(14) : root.dp(18)
        rowSpacing: root.dp(6)
        Repeater {
            model: root.large ? [] : root.cities
            City { diameter: root.dialFor(root.cities.length) }
        }
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(4)
        Repeater {
            model: root.large ? root.cities : []
            ColumnLayout {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Rectangle {
                    visible: row.index > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.hairline
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.dp(12)
                    FaceDial {
                        face: root
                        Layout.preferredWidth: root.dp(46)
                        Layout.preferredHeight: root.dp(46)
                        time: WorldClock.cityDisplayDate(row.index)
                        seconds: false
                        numerals: false
                        disc: true
                        daylight: row.modelData.isDay
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        FaceText {
                            face: root
                            Layout.fillWidth: true
                            text: row.modelData.name
                            size: 14
                            weight: Font.DemiBold
                        }
                        FaceText {
                            face: root
                            Layout.fillWidth: true
                            text: root.shift(row.index)
                            color: root.inkSecondary
                            size: 12
                        }
                    }
                    FaceFigure {
                        face: root
                        text: row.modelData.time
                        size: 28
                    }
                }
            }
        }
    }
}
