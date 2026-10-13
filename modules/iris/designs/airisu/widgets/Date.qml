import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's date widget: a page of a tear-off calendar (日めくり). The binding strip at its head holds the month and year
// in the data face's capitals, with the perforation under it where yesterday was torn off; the day's number fills the
// page as the hero figure, leaning, its weekday beside it in the person's words with the Japanese day as a layer; at the
// foot, how far into the year as a run and the day's number in it. The engine's face keeps the data and the stock.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property var today: root.face?.today ?? new Date()
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property int strip: root.dp(26)
    readonly property string kanaDay: ["日", "月", "火", "水", "木", "金", "土"][root.today.getDay()]

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }
    // The binding strip, a print deeper than the page, cut by the page's die.
    ALacquer {
        anchors.fill: parent
        cut: Airisu.chamfer
        lacquer: "transparent"
        coat: Airisu.underPlate(stock.lacquer)
        head: true
        band: root.strip
        share: 1
        moving: false
    }
    AText {
        x: root.pad
        width: root.width - 2 * root.pad
        height: root.strip
        verticalAlignment: Text.AlignVCenter
        voice: "mono"
        size: IrisStyle.typeCaption
        color: stock.inkSecond
        text: Translation.locale.toString(root.today, (root.widget?.showYear ?? true) ? "MMMM yyyy" : "MMMM")
    }
    // The perforation.
    Row {
        x: root.pad
        y: root.strip + root.dp(3)
        spacing: root.dp(4)
        Repeater {
            model: Math.max(0, Math.floor((root.width - 2 * root.pad) / root.dp(6)))
            Rectangle { width: Math.max(1, root.dp(2)); height: width; color: stock.inkThird; antialiasing: false }
        }
    }
    Row {
        x: root.pad
        y: root.strip + root.dp(8)
        spacing: root.dp(8)
        AText {
            id: day
            voice: "figure"
            lean: Airisu.lean
            size: root.px(root.small ? 70 : 84)
            color: stock.ink
            text: root.today.getDate()
        }
        AText {
            visible: root.widget?.showWeekday ?? true
            anchors.bottom: day.bottom
            anchors.bottomMargin: Math.round(day.height * 0.2)
            voice: "kana"
            size: root.px(22)
            color: Airisu.sealText
            text: root.kanaDay
        }
    }
    AText {
        visible: root.widget?.showWeekday ?? true
        x: root.pad
        y: day.parent.y + day.height - root.dp(4)
        width: root.width - 2 * root.pad
        size: IrisStyle.typeLabel
        font.weight: Font.Bold
        color: stock.ink
        text: Translation.locale.toString(root.today, "dddd")
    }
    // How far into the year.
    Item {
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        height: ordinal.height
        AText {
            id: ordinal
            anchors.right: parent.right
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: Translation.tr("Day %1").arg(root.widget?.dayOfYear ?? 0)
        }
        Rectangle {
            anchors.verticalCenter: ordinal.verticalCenter
            width: parent.width - ordinal.width - root.dp(8)
            height: Math.max(2, root.dp(3))
            color: Airisu.slot
            antialiasing: false
            Rectangle {
                width: Math.round(parent.width * (root.face?.yearShare ?? 0))
                height: parent.height
                color: stock.ink
                antialiasing: false
            }
        }
    }
}
