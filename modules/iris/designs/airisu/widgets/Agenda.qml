pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.widgets
import "../components"

// AIRISU's agenda: what comes next as a timetable (時刻表). The day as a ruby in the data face's capitals, then a line
// for each event: when, in the data face; a bar in its calendar's colour, as a board marks each line; its title, and
// where, when there is room. A change of day starts with the day's name over its lines. The engine's face keeps the
// events and the stock.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var shown: root.face?.shown ?? []
    readonly property var today: root.face?.today ?? new Date()

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }
    Row {
        id: head
        x: root.pad
        y: root.pad
        spacing: root.dp(6)
        AText {
            id: dayFigure
            voice: "figure"
            lean: Airisu.lean
            size: root.px(root.small ? 34 : 40)
            color: stock.ink
            text: root.today.getDate()
        }
        AText {
            anchors.baseline: dayFigure.baseline
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: Translation.locale.toString(root.today, "dddd")
        }
    }
    AText {
        visible: root.shown.length === 0
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        voice: "data"
        size: IrisStyle.typeCaption
        color: stock.inkThird
        text: Translation.tr("Nothing scheduled")
    }
    Column {
        x: root.pad
        y: head.y + head.height + root.dp(8)
        width: root.width - 2 * root.pad
        spacing: root.dp(4)
        Repeater {
            model: root.shown
            Column {
                id: entry
                required property var modelData
                required property int index
                readonly property string day: root.face ? root.face.dayLabel(entry.modelData) : ""
                readonly property bool heading: !root.small && (entry.index === 0
                    ? entry.day !== Translation.tr("Today") : entry.day !== root.face.dayLabel(root.shown[entry.index - 1]))
                width: parent.width
                spacing: root.dp(2)
                AText {
                    visible: entry.heading
                    width: parent.width
                    voice: "mono"
                    size: IrisStyle.typeCaption
                    color: stock.inkThird
                    text: entry.day
                }
                Item {
                    width: parent.width
                    height: Math.max(title.implicitHeight + (place.visible ? place.implicitHeight : 0), root.dp(18))
                    y: root.small ? root.dp(16) : 0
                    // A small print has no day heads, so its one line says the day too, over the title.
                    AText {
                        visible: root.small
                        width: parent.width
                        y: -height
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: stock.inkSecond
                        text: IrisFaceData.eventWhen(entry.modelData, root.today)
                    }
                    AText {
                        id: when
                        visible: !root.small
                        width: root.small ? 0 : root.px(56)
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: stock.inkSecond
                        // The day stands over its lines, so a line says only the hour.
                        text: entry.modelData.allDay ? Translation.tr("All day")
                            : Qt.formatTime(IrisFaceData.eventDate(entry.modelData), "hh:mm")
                    }
                    Rectangle {
                        id: line
                        x: root.small ? 0 : when.width + root.dp(4)
                        width: Math.max(2, root.dp(3))
                        height: parent.height
                        color: IrisFaceData.eventTint(entry.modelData, stock.ink)
                        antialiasing: false
                    }
                    AText {
                        id: title
                        x: line.x + line.width + root.dp(8)
                        width: parent.width - x
                        size: IrisStyle.typeLabel
                        font.weight: Font.Bold
                        color: stock.ink
                        text: IrisFaceData.eventTitle(entry.modelData)
                    }
                    AText {
                        id: place
                        visible: (root.widget?.showLocation ?? false) && String(entry.modelData.location ?? "").length > 0
                        x: title.x
                        y: title.height
                        width: title.width
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: stock.inkThird
                        text: String(entry.modelData.location ?? "")
                    }
                }
            }
        }
    }
}
