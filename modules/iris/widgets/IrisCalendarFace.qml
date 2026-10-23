pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

// The month as SekaiPop's calendar card builds it, in iRiS: a plate (the month as the title, the year and this week's
// number over it, today as a disc that brings the page back, the month's tally on a tab and the two page keys), the
// days as keys (today the raised accent key, a day with entries wears their dots), and what a day holds when you
// pick it. The wheel over the days turns the page.
IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetCalendar")

    readonly property var today: DateTime.clock.date
    readonly property var viewing: root.widget.viewingDate
    readonly property bool browsing: root.widget.monthShift !== 0
    readonly property bool adjacent: root.widget.showAdjacentDays
    readonly property var upcoming: IrisFaceData.upcomingEvents(root.today, 7)
    readonly property string monthName: IrisFaceData.capitalized(Translation.locale.standaloneMonthName(root.viewing.getMonth()))
    readonly property int week: {
        const day = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())
        day.setDate(day.getDate() + 3 - (day.getDay() + 6) % 7)
        const first = new Date(day.getFullYear(), 0, 4)
        return 1 + Math.round(((day - first) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7)
    }
    readonly property int monthDays: new Date(root.viewing.getFullYear(), root.viewing.getMonth() + 1, 0).getDate()
    readonly property int busyDays: {
        let busy = 0
        for (let d = 1; d <= root.monthDays; ++d)
            if (IrisFaceData.hasEvents(new Date(root.viewing.getFullYear(), root.viewing.getMonth(), d)))
                busy++
        return busy
    }
    // The day you picked (null = the week ahead).
    property var picked: null
    readonly property var pickedEvents: root.picked ? root.eventsOn(root.picked) : []
    readonly property var shownEvents: root.picked ? root.pickedEvents : root.upcoming

    function eventsOn(date: var): var {
        return Array.from(Events.getEventsForDate(date) ?? []).concat(Array.from(CalendarSync.getEventsForDate(date) ?? []))
            .sort((a, b) => IrisFaceData.eventDate(a) - IrisFaceData.eventDate(b))
    }
    function sameDay(a: var, b: var): bool {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }
    function turn(step: int): void {
        root.picked = null
        root.widget.monthShift = step === 0 ? 0 : root.widget.monthShift + step
    }

    // Today as a disc: click it to bring the page back.
    component TodayDisc: Rectangle {
        property real side: root.dp(34)
        width: side
        height: side
        radius: side / 2
        color: root.highlight
        scale: discTap.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        FaceFigure {
            face: root
            anchors.centerIn: parent
            text: root.today.getDate()
            size: Math.max(14, parent.side / root.t * 0.46)
            tone: root.onFill(root.highlight)
        }
        TapHandler { id: discTap; onTapped: root.turn(0) }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // The two page keys as one capsule.
    component PageKeys: Rectangle {
        implicitWidth: root.dp(56)
        implicitHeight: root.dp(24)
        radius: height / 2
        color: root.fillQuiet
        Row {
            anchors.fill: parent
            Repeater {
                model: [{ glyph: "chevron_left", step: -1 }, { glyph: "chevron_right", step: 1 }]
                Item {
                    id: pageKey
                    required property var modelData
                    width: parent.width / 2
                    height: parent.height
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.dp(2)
                        radius: height / 2
                        color: pageHover.hovered ? root.fillHover : "transparent"
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: pageKey.modelData.glyph
                        iconSize: root.px(16)
                        color: root.inkSecondary
                    }
                    HoverHandler { id: pageHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.turn(pageKey.modelData.step) }
                }
            }
        }
    }

    // The month's tally on a tab.
    component Tally: Rectangle {
        implicitWidth: tallyText.implicitWidth + root.dp(14)
        implicitHeight: root.dp(22)
        radius: height / 2
        color: root.busyDays > 0 ? Qt.alpha(root.accent, 0.18) : root.fillQuiet
        FaceText {
            id: tallyText
            face: root
            anchors.centerIn: parent
            text: root.busyDays === 0 ? Translation.tr("Free month")
                : root.busyDays === 1 ? Translation.tr("1 busy day") : Translation.tr("%1 busy days").arg(root.busyDays)
            size: 11
            weight: Font.DemiBold
            color: root.busyDays > 0 ? root.accent : root.inkSecondary
        }
    }

    // The month title with the year and the week over it.
    component Title: ColumnLayout {
        property real size: 17
        spacing: 0
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.browsing ? String(root.viewing.getFullYear())
                : Translation.tr("%1 · Week %2").arg(root.viewing.getFullYear()).arg(root.week)
            color: root.inkTertiary
            size: 11.5
            weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.monthName
            color: root.heading
            size: parent.size
            weight: Font.Bold
        }
    }

    // The days as keys.
    component Days: ColumnLayout {
        id: days
        property real cellText: 11
        property bool keycaps: true
        spacing: root.dp(2)
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(days.keycaps ? 3 : 0)
            Repeater {
                model: 7
                FaceText {
                    required property int index
                    face: root
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.locale.dayName((root.widget.weekStart + index) % 7, Locale.NarrowFormat).toUpperCase()
                    color: (root.widget.weekStart + index) % 7 === 0 || (root.widget.weekStart + index) % 7 === 6 ? root.inkTertiary : root.inkSecondary
                    size: days.cellText - 1.5
                    weight: Font.DemiBold
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: root.dp(days.keycaps ? 3 : 0)
            columnSpacing: root.dp(days.keycaps ? 3 : 0)
            Repeater {
                model: root.widget.monthCells()
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property var date: new Date(root.viewing.getFullYear(), root.viewing.getMonth()
                        + (cell.modelData.currentMonth ? 0 : cell.index < 7 ? -1 : 1), cell.modelData.day)
                    readonly property var events: cell.modelData.currentMonth ? root.eventsOn(cell.date) : []
                    readonly property bool chosen: root.sameDay(root.picked, cell.date)
                    readonly property bool shown: cell.modelData.currentMonth || root.adjacent
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    Rectangle {
                        id: keycap
                        anchors.centerIn: parent
                        width: days.keycaps ? parent.width : Math.min(parent.width, parent.height) * 0.92
                        height: days.keycaps ? parent.height : width
                        radius: days.keycaps ? Math.min(root.dp(8), height * 0.32) : height / 2
                        visible: cell.shown
                        color: cell.modelData.isToday ? root.highlight
                            : cell.chosen ? root.fillActive
                            : dayHover.hovered && cell.modelData.currentMonth ? root.fillHover
                            : days.keycaps && cell.modelData.currentMonth ? root.fillQuiet : "transparent"
                        border.width: cell.chosen && !cell.modelData.isToday ? 1 : 0
                        border.color: root.accent
                        scale: dayTap.pressed ? 0.9 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                        FaceText {
                            face: root
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.events.length > 0 && days.keycaps ? -root.dp(2) : 0
                            text: cell.modelData.day
                            color: cell.modelData.isToday ? root.onFill(root.highlight)
                                : cell.modelData.currentMonth ? root.ink : root.inkTertiary
                            size: days.cellText
                            weight: cell.modelData.isToday ? Font.Bold : Font.Medium
                            font.family: root.fontNumbers
                            font.features: ({ "tnum": 1 })
                        }
                        // Up to three dots, one per entry, in their own colours.
                        Row {
                            visible: cell.events.length > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.max(1, root.dp(days.keycaps ? 3 : 0))
                            spacing: root.dp(2)
                            Repeater {
                                model: cell.events.slice(0, 3)
                                Rectangle {
                                    required property var modelData
                                    width: root.dp(4)
                                    height: width
                                    radius: width / 2
                                    color: cell.modelData.isToday ? root.onFill(root.highlight) : IrisFaceData.eventTint(modelData, root.accent)
                                }
                            }
                        }
                    }
                    HoverHandler { id: dayHover; enabled: cell.shown; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: dayTap
                        enabled: cell.shown
                        onTapped: {
                            if (!cell.modelData.currentMonth)
                                root.turn(cell.index < 7 ? -1 : 1)
                            else
                                root.picked = cell.chosen ? null : cell.date
                        }
                    }
                }
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (Math.abs(event.angleDelta.y) >= 60)
                    root.turn(event.angleDelta.y < 0 ? 1 : -1)
            }
        }
    }

    // One entry: its colour, title and when.
    component Entry: Rectangle {
        id: entry
        property var event: null
        implicitHeight: root.dp(38)
        radius: root.innerRadius
        color: root.fillQuiet
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.dp(8)
            anchors.rightMargin: root.dp(10)
            spacing: root.dp(8)
            Rectangle {
                Layout.preferredWidth: root.dp(4)
                Layout.preferredHeight: parent.height - root.dp(14)
                radius: width / 2
                color: IrisFaceData.eventTint(entry.event, root.accent)
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.eventTitle(entry.event)
                size: 12.5
                weight: Font.DemiBold
            }
            Rectangle {
                implicitWidth: whenText.implicitWidth + root.dp(12)
                implicitHeight: root.dp(20)
                radius: height / 2
                color: Qt.alpha(IrisFaceData.eventTint(entry.event, root.accent), 0.18)
                FaceText {
                    id: whenText
                    face: root
                    anchors.centerIn: parent
                    text: IrisFaceData.eventWhen(entry.event, root.today)
                    size: 10.5
                    weight: Font.DemiBold
                    color: root.inkSecondary
                }
            }
        }
    }

    // What the picked day (or the week ahead) holds.
    component Agenda: ColumnLayout {
        id: agenda
        property int rows: 2
        spacing: root.dp(5)
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.picked ? IrisFaceData.capitalized(Translation.locale.toString(root.picked, "dddd d MMMM"))
                : Translation.tr("Coming up")
            color: root.inkSecondary
            size: 11.5
            weight: Font.DemiBold
        }
        Repeater {
            model: root.shownEvents.slice(0, agenda.rows)
            Entry {
                required property var modelData
                Layout.fillWidth: true
                event: modelData
            }
        }
        Rectangle {
            visible: root.shownEvents.length === 0
            Layout.fillWidth: true
            implicitHeight: root.dp(38)
            radius: root.innerRadius
            color: root.fillQuiet
            FaceText {
                face: root
                anchors.centerIn: parent
                text: root.picked ? Translation.tr("Nothing on this day") : Translation.tr("No events this week")
                color: root.inkTertiary
                size: 12
            }
        }
    }

    // Small: title and disc, then the days.
    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(4)
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(4)
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.monthName
                color: root.heading
                size: 13
                weight: Font.Bold
            }
            PageKeys { implicitWidth: root.dp(44); implicitHeight: root.dp(20) }
        }
        Days {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellText: 9.5
            keycaps: false
        }
    }

    // Medium: the plate beside the days.
    RowLayout {
        visible: root.medium
        anchors.fill: parent
        spacing: root.dp(12)
        ColumnLayout {
            Layout.preferredWidth: root.contentWidth * 0.33
            Layout.maximumWidth: root.contentWidth * 0.33
            Layout.fillHeight: true
            spacing: root.dp(6)
            RowLayout {
                Layout.fillWidth: true
                Title { Layout.fillWidth: true; size: 16 }
            }
            TodayDisc { side: root.dp(40) }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.dp(4)
                PageKeys {}
                Item { Layout.fillWidth: true }
            }
        }
        Days {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellText: 10.5
        }
    }

    // Large: the plate across the top, the days, then what is coming.
    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(10)
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(10)
            TodayDisc { side: root.dp(46) }
            Title { Layout.fillWidth: true; size: 20 }
            ColumnLayout {
                spacing: root.dp(4)
                PageKeys { Layout.alignment: Qt.AlignRight }
                Tally { Layout.alignment: Qt.AlignRight }
            }
        }
        Days {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellText: 13
        }
        Agenda {
            Layout.fillWidth: true
            Layout.fillHeight: false
            rows: 2
        }
    }
}
