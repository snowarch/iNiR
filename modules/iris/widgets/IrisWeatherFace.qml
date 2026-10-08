pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property bool ready: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property string glyph: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
    readonly property color sky: IrisStyle.skyLight(root.glyph)
    readonly property string city: root.widget.showLocation && Weather.showVisibleCity ? Weather.visibleCity : ""
    readonly property string condition: IrisFaceData.capitalized(String(Weather.data?.description ?? ""))
    readonly property string range: {
        const high = root.degrees(Weather.data?.tempMax)
        const low = root.degrees(Weather.data?.tempMin)
        return high.length > 0 && low.length > 0 ? Translation.tr("H:%1  L:%2").arg(high).arg(low) : ""
    }
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, root.large ? 6 : 5)
    readonly property var days: Array.from(Weather.data?.forecast ?? []).slice(0, 5)
    readonly property var lows: root.days.map(day => Number(day.loVal)).filter(Number.isFinite)
    readonly property var highs: root.days.map(day => Number(day.hiVal)).filter(Number.isFinite)
    readonly property real weekLow: root.lows.length > 0 ? Math.min(...root.lows) : 0
    readonly property real weekHigh: root.highs.length > 0 ? Math.max(...root.highs) : 1

    function degrees(value: var): string {
        const text = String(value ?? "").trim()
        if (text.length === 0 || text.startsWith("--"))
            return ""
        return text.replace(/°[CF]$/, "°").replace(/([0-9])$/, "$1°")
    }

    light: root.ready ? root.sky : "transparent"

    component Now: ColumnLayout {
        spacing: 0
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.city.length > 0
            text: root.city
            size: 13.5
            weight: Font.DemiBold
        }
        FaceFigure {
            face: root
            Layout.fillWidth: true
            text: root.widget.temperatureText
            size: root.large ? 50 : 44
        }
    }

    component Condition: ColumnLayout {
        spacing: root.dp(1)
        MaterialSymbol {
            text: root.glyph
            fill: 1
            iconSize: root.px(20)
            color: root.sky
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.condition
            size: 12.5
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.range.length > 0 || Weather.stale
            text: !Weather.stale ? root.range
                : !Network.online ? Translation.tr("Offline · %1").arg(Weather.updatedLabel)
                : Translation.tr("Updated %1").arg(Weather.updatedLabel)
            color: Weather.stale ? root.inkTertiary : root.inkSecondary
            size: 12
        }
    }

    component Hours: RowLayout {
        spacing: 0
        Repeater {
            model: root.hours
            ColumnLayout {
                id: hour
                required property var modelData
                required property int index
                readonly property string glyph: Icons.getWeatherIcon(hour.modelData.code, hour.modelData.isNight) ?? "cloud"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: root.dp(4)
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: hour.index === 0 ? Translation.tr("Now") : String(hour.modelData.label).slice(0, 5)
                    color: hour.index === 0 ? root.ink : root.inkSecondary
                    size: 11.5
                    weight: hour.index === 0 ? Font.DemiBold : Font.Medium
                    font.features: ({ "tnum": 1 })
                }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: hour.glyph
                    fill: 1
                    iconSize: root.px(19)
                    color: IrisStyle.skyLight(hour.glyph)
                }
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: root.degrees(hour.modelData.temp)
                    size: 13
                    weight: Font.DemiBold
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
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

    ColumnLayout {
        visible: root.ready && root.small
        anchors.fill: parent
        spacing: 0
        Now { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        Condition { Layout.fillWidth: true }
    }

    RowLayout {
        visible: root.ready && root.medium
        anchors.fill: parent
        spacing: root.dp(14)
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: root.contentWidth * 0.36
            Layout.maximumWidth: root.contentWidth * 0.36
            Layout.fillHeight: true
            spacing: 0
            Now { Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            Condition { Layout.fillWidth: true }
        }
        Hours {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    ColumnLayout {
        visible: root.ready && root.large
        anchors.fill: parent
        spacing: root.dp(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(12)
            Now { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            Condition { Layout.preferredWidth: root.contentWidth * 0.42; Layout.alignment: Qt.AlignBottom }
        }
        Hours { Layout.fillWidth: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        Repeater {
            model: root.days
            RowLayout {
                id: day
                required property var modelData
                readonly property string glyph: Icons.getWeatherIcon(day.modelData.code, false) ?? "cloud"
                readonly property real span: Math.max(1, root.weekHigh - root.weekLow)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(10)
                FaceText {
                    face: root
                    Layout.preferredWidth: root.contentWidth * 0.24
                    text: IrisFaceData.capitalized(day.modelData.dayName)
                    size: 13
                    weight: Font.DemiBold
                }
                MaterialSymbol {
                    Layout.preferredWidth: root.px(22)
                    text: day.glyph
                    fill: 1
                    iconSize: root.px(18)
                    color: IrisStyle.skyLight(day.glyph)
                }
                FaceText {
                    face: root
                    Layout.preferredWidth: root.px(30)
                    horizontalAlignment: Text.AlignRight
                    text: root.degrees(day.modelData.lo)
                    color: root.inkSecondary
                    size: 13
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
                            GradientStop { position: 0; color: IrisStyle.identity.sky }
                            GradientStop { position: 1; color: IrisStyle.identity.orange }
                        }
                    }
                }
                FaceText {
                    face: root
                    Layout.preferredWidth: root.px(30)
                    text: root.degrees(day.modelData.hi)
                    size: 13
                    weight: Font.DemiBold
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
