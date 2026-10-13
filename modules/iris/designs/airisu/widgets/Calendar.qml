pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.widgets
import "../components"

// AIRISU's month: a printed calendar. The month and year as a ruby in the data face's capitals, the weekdays as narrow
// capitals in the third ink, the days in the figures' face, Sundays printed in the seal's type as a Japanese calendar
// prints them; today is a box ruled in the seal round its number, a day with something on it carries a mark under its
// number. Given room, the day itself stands beside the grid as the hero figure with its weekday and what comes next.
// The arrows at the head turn the month; the engine's face keeps the cells and the shift.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var viewing: root.widget ? root.widget.viewingDate : DateTime.clock.date
    readonly property var cells: root.widget ? root.widget.monthCells() : []
    readonly property int weekStart: Number(root.widget?.weekStart ?? 1)
    // A day of the month shown, as a date the calendars can be asked about.
    function dayOf(day: int): var {
        const shown = root.viewing
        return new Date(shown.getFullYear(), shown.getMonth(), day)
    }

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "time"
    }

    // The day itself, on a medium or large print.
    Column {
        id: hero
        visible: !root.small
        x: root.pad
        y: root.pad
        width: Math.round(root.width * 0.38) - root.pad
        spacing: root.dp(2)
        AText {
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: root.face?.weekday ?? ""
        }
        AText {
            voice: "figure"
            lean: Airisu.lean
            size: root.px(64)
            color: stock.ink
            text: (root.face?.today ?? new Date()).getDate()
        }
    }
    Column {
        visible: !root.small && root.face?.nextEvent
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: hero.width
        spacing: root.dp(2)
        Rectangle {
            width: root.dp(16)
            height: Math.max(2, root.dp(3))
            color: IrisFaceData.eventTint(root.face?.nextEvent, stock.ink)
            antialiasing: false
        }
        AText {
            width: parent.width
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: stock.ink
            text: root.face?.nextEvent ? IrisFaceData.eventTitle(root.face.nextEvent) : ""
        }
        AText {
            width: parent.width
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: root.face?.nextEvent ? IrisFaceData.eventWhen(root.face.nextEvent, root.face.today) : ""
        }
    }

    // The month.
    Item {
        id: month
        x: root.small ? root.pad : Math.round(root.width * 0.38) + root.dp(6)
        y: root.pad
        width: root.width - x - root.pad
        height: root.height - 2 * root.pad
        Item {
            id: head
            width: parent.width
            height: root.dp(18)
            AText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - turn.width
                voice: "mono"
                size: IrisStyle.typeCaption
                color: (root.face?.browsing ?? false) ? Airisu.sealText : stock.inkSecond
                text: Translation.locale.toString(root.viewing, "MMMM yyyy")
            }
            Row {
                id: turn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: [{ glyph: "chevron_left", shift: -1 }, { glyph: "chevron_right", shift: 1 }]
                    MaterialSymbol {
                        required property var modelData
                        text: modelData.glyph
                        iconSize: root.px(16)
                        color: tap.hovered ? stock.ink : stock.inkThird
                        HoverHandler { id: tap; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (root.widget) root.widget.monthShift += modelData.shift }
                    }
                }
            }
        }
        Grid {
            id: grid
            y: head.height + root.dp(4)
            width: parent.width
            columns: 7
            readonly property real cellW: grid.width / 7
            readonly property real cellH: (month.height - grid.y) / 7
            Repeater {
                model: 7
                AText {
                    required property int index
                    width: grid.cellW
                    height: grid.cellH
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: (root.weekStart + index) % 7 === 0 ? Airisu.sealText : stock.inkThird
                    text: Translation.locale.dayName((root.weekStart + index) % 7, Locale.NarrowFormat).toUpperCase()
                }
            }
            Repeater {
                model: root.cells
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool sunday: (root.weekStart + cell.index) % 7 === 0
                    readonly property bool busy: cell.modelData.currentMonth && IrisFaceData.hasEvents(root.dayOf(cell.modelData.day))
                    width: grid.cellW
                    height: grid.cellH
                    Rectangle {
                        visible: cell.modelData.isToday
                        anchors.centerIn: parent
                        width: Math.round(Math.min(parent.width, parent.height) * 0.92)
                        height: width
                        color: "transparent"
                        border.width: Airisu.strong
                        border.color: Airisu.seal
                        antialiasing: false
                    }
                    AText {
                        anchors.centerIn: parent
                        visible: cell.modelData.currentMonth || (root.face?.adjacent ?? false)
                        voice: "figure"
                        size: Math.round(Math.min(grid.cellH * 0.5, grid.cellW * 0.4))
                        font.weight: cell.modelData.isToday ? Font.ExtraBold : Font.Bold
                        color: !cell.modelData.currentMonth ? stock.inkThird : cell.sunday ? Airisu.sealText : stock.ink
                        text: cell.modelData.day
                    }
                    Rectangle {
                        visible: cell.busy
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Math.max(2, root.dp(4))
                        height: Math.max(1, root.dp(2))
                        color: stock.ink
                        antialiasing: false
                    }
                }
            }
        }
    }
}
