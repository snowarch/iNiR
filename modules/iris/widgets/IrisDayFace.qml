pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.bar.island

IrisWidgetFace {
    id: root

    readonly property real fraction: root.widget.dayFraction
    readonly property int percent: Math.floor(root.fraction * 100)
    readonly property int minutesLeft: Math.max(0, Math.round((1 - root.fraction) * 1440))
    readonly property string remaining: {
        const hours = Math.floor(root.minutesLeft / 60)
        const minutes = root.minutesLeft % 60
        const span = hours > 0 ? Translation.tr("%1 h %2 min").arg(hours).arg(minutes) : Translation.tr("%1 min").arg(minutes)
        return Translation.tr("%1 left").arg(span)
    }
    readonly property real sunrise: root.dayShare(Weather.data?.sunrise, 6 / 24)
    readonly property real sunset: root.dayShare(Weather.data?.sunset, 19 / 24)

    function dayShare(text: var, fallback: real): real {
        const match = String(text ?? "").match(/(\d{1,2}):(\d{2})\s*([AaPp][Mm])?/)
        if (!match)
            return fallback
        let hours = Number(match[1]) % 12
        if (!match[3] || match[3].toLowerCase() === "am")
            hours = match[3] ? hours : Number(match[1])
        else
            hours += 12
        return (hours * 60 + Number(match[2])) / 1440
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(6)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ProgressRing {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                progress: root.fraction
                tint: root.warm
                stroke: Math.max(4, root.dp(9))
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: -root.dp(2)
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: root.dp(1)
                    FaceFigure {
                        id: compactPercent
                        face: root
                        text: root.percent
                        size: 32
                    }
                    FaceText {
                        face: root
                        anchors.baseline: compactPercent.baseline
                        text: "%"
                        color: root.inkSecondary
                        size: 14
                    }
                }
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("of today")
                    color: root.inkTertiary
                    size: 11
                }
            }
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.remaining
            color: root.inkSecondary
            size: 12
        }
    }

    ColumnLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: root.widget.isDaytime ? "light_mode" : "bedtime"
            text: IrisFaceData.capitalized(Qt.locale().toString(DateTime.clock.date, "dddd d"))
            tint: root.warm
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(10)
            Row {
                spacing: root.dp(2)
                FaceFigure {
                    id: dayPercent
                    face: root
                    text: root.percent
                    size: 48
                }
                FaceText {
                    face: root
                    anchors.baseline: dayPercent.baseline
                    text: "%"
                    color: root.inkSecondary
                    size: 22
                }
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: root.dp(8)
                text: root.remaining
                color: root.inkSecondary
                size: 12.5
            }
        }
        Item { Layout.fillHeight: true }
        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(26)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: root.dp(8)
                radius: height / 2
                color: root.fill
                Rectangle {
                    width: parent.width * root.fraction
                    height: parent.height
                    radius: height / 2
                    color: root.warm
                }
            }
            Repeater {
                model: [{ at: root.sunrise, glyph: "wb_twilight" }, { at: root.sunset, glyph: "wb_twilight" }]
                MaterialSymbol {
                    required property var modelData
                    x: track.width * modelData.at - width / 2
                    y: root.dp(4) - height
                    text: modelData.glyph
                    fill: 1
                    iconSize: root.px(13)
                    color: root.warm
                }
            }
            Rectangle {
                x: track.width * root.fraction - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.dp(4)
                height: root.dp(18)
                radius: width / 2
                color: root.ink
            }
        }
        RowLayout {
            Layout.fillWidth: true
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
    }
}
