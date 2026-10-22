pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.bar.island as IslandParts
import qs.modules.iris.preview.parts

// The highlight is the glanced detail: the clock's separator, today's number, a timer. Everything else here is plain
// ink, so the one colour that moves with the row is the one the eye lands on.
PreviewScene {
    id: hl
    subject: Qt.rect(hlPlate.x, hlPlate.y, hlPlate.width, hlPlate.height)
    // Laid tight, so the three marks read at the head's size instead of floating in air.
    readonly property real naturalWidth: Math.round(460 * hl.d)
    readonly property real naturalHeight: Math.round(230 * hl.d)
    readonly property date today: DateTime.clock.date
    // The day alone, so the strip below is rebuilt once a day, not on every tick of the clock.
    readonly property int dayKey: hl.today.getFullYear() * 512 + hl.today.getMonth() * 32 + hl.today.getDate()
    // The week around today, Monday first: the same strip a calendar card draws.
    readonly property var week: {
        const key = hl.dayKey
        const day = new Date(Math.floor(key / 512), Math.floor((key % 512) / 32), key % 32)
        const monday = new Date(day.getFullYear(), day.getMonth(), day.getDate() - ((day.getDay() + 6) % 7))
        const days = []
        for (let i = 0; i < 7; i++)
            days.push(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i))
        return days
    }
    IslandPill {
        id: hlIsland
        anchors.horizontalCenter: hlPlate.horizontalCenter
        y: IrisFrame.band
    }
    Plate {
        id: hlPlate
        surface: "controlCenter"
        fallbackRadius: IrisStyle.radiusPlate
        anchors.horizontalCenter: parent.horizontalCenter
        y: hlIsland.y + hlIsland.height + IrisFrame.bodyAir
        width: Math.round(384 * hl.d)
        height: hlRow.implicitHeight + 2 * hlRow.pad
        RowLayout {
            id: hlRow
            readonly property int pad: IrisStyle.concentricPad(hlPlate.radius, 16 * hl.d)
            x: hlRow.pad; y: hlRow.pad
            width: parent.width - 2 * hlRow.pad
            spacing: Math.round(18 * hl.d)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(10 * hl.d)
                IslandParts.DateMark {
                    pixelSize: IrisStyle.typeTitleLarge
                    inkColor: IrisStyle.textSecondary
                }
                Row {
                    spacing: Math.round(2 * hl.d)
                    Repeater {
                        model: hl.week
                        Rectangle {
                            id: hlDay
                            required property var modelData
                            readonly property bool isToday: modelData.getDate() === hl.today.getDate() && modelData.getMonth() === hl.today.getMonth()
                            width: Math.round(26 * hl.d); height: width
                            radius: IrisStyle.capsule(width)
                            color: hlDay.isToday ? IrisStyle.tintFill(IrisStyle.secondaryAccent) : "transparent"
                            IrisText {
                                anchors.centerIn: parent
                                text: Translation.locale.toString(hlDay.modelData, "d")
                                color: hlDay.isToday ? IrisStyle.secondaryAccent : IrisStyle.textSecondary
                                font.family: IrisStyle.fontNumbers
                                font.weight: hlDay.isToday ? IrisStyle.weight(Font.Bold) : IrisStyle.weight(Font.Medium)
                                font.features: ({ "tnum": 1 })
                                font.pixelSize: IrisStyle.typeMeta
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(6 * hl.d)
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round(72 * hl.d)
                    Layout.preferredHeight: Layout.preferredWidth
                    IslandParts.ProgressRing {
                        anchors.fill: parent
                        stroke: Math.max(2, 3 * hl.d)
                        tint: IrisStyle.secondaryAccent
                        progress: 0.62
                    }
                    IrisText {
                        anchors.centerIn: parent
                        text: "12:40"
                        color: IrisStyle.secondaryAccent
                        font.family: IrisStyle.fontNumbers
                        font.weight: IrisStyle.weight(Font.Bold)
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
                IrisText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Timer")
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeFootnote
                }
            }
        }
    }
    Caption { glyph: "ink_highlighter"; text: Translation.tr("The highlight: the detail you glance at") }
}
