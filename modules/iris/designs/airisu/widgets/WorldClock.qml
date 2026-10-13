import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's world clock: an airport's departures board. One row per city, parted by hairlines: the city's name, how far
// it is from here and which day in the data face, and its time as a figure leaning at the end. A single city is set as
// the hero figure with its name as a ruby over it. The engine's face keeps the cities and the stock.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var cities: root.face?.cities ?? []
    readonly property bool single: root.cities.length === 1
    function timeOf(index: int): string {
        WorldClock.now
        return Qt.formatTime(WorldClock.cityDisplayDate(index), "hh:mm")
    }

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }

    // One city: the hero.
    Column {
        visible: root.single
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: root.dp(2)
        AText {
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: root.single ? String(root.cities[0].name ?? "") : ""
        }
        AText {
            voice: "figure"
            lean: Airisu.lean
            size: root.px(root.small ? 48 : 64)
            color: stock.ink
            text: root.single ? root.timeOf(0) : ""
        }
        AText {
            width: parent.width
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkThird
            text: root.single ? String(root.face?.shift(0) ?? "") : ""
        }
    }

    // Several: the board.
    Column {
        visible: !root.single
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        Repeater {
            model: root.single ? [] : root.cities
            Item {
                id: row
                required property var modelData
                required property int index
                width: parent.width
                height: Math.floor((root.height - 2 * root.pad) / Math.max(1, root.cities.length))
                Rectangle {
                    visible: row.index > 0
                    width: parent.width
                    height: Airisu.hair
                    color: stock.inkThird
                    antialiasing: false
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - time.width - root.dp(8)
                    AText {
                        width: parent.width
                        visible: root.widget?.showNames ?? true
                        size: IrisStyle.typeLabel
                        font.weight: Font.Bold
                        color: stock.ink
                        text: String(row.modelData.name ?? "")
                    }
                    AText {
                        width: parent.width
                        visible: !root.small && (root.widget?.showOffsets ?? true)
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: stock.inkThird
                        text: String(root.face?.shift(row.index) ?? "")
                    }
                }
                AText {
                    id: time
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "figure"
                    lean: Airisu.lean
                    size: root.small ? IrisStyle.typeHeadline : IrisStyle.typeTitle
                    color: stock.ink
                    text: root.timeOf(row.index)
                }
            }
        }
    }
}
