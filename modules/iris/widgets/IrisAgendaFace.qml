pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetAgenda")

    readonly property var today: DateTime.clock.date
    readonly property var events: Array.from(root.widget.upcomingEvents ?? [])
    readonly property int capacity: root.small ? 1 : root.medium ? 3 : 6
    readonly property var shown: root.events.slice(0, root.capacity)

    // Today as the month calendar marks it: the accent's solid fill under its own ink.
    readonly property color todayFill: root.nothing ? root.signal : IrisStyle.accentFill
    readonly property color todayInk: root.nothing ? IrisStyle.onTintFor(root.signal) : IrisStyle.inkOnAccentFill
    readonly property var next: root.shown[0] ?? null
    readonly property var nextTime: root.next && !root.next.allDay ? IrisFaceData.timeParts(IrisFaceData.clockText(IrisFaceData.eventDate(root.next))) : null

    function dayLabel(event: var): string {
        const when = IrisFaceData.eventDate(event)
        const start = new Date(root.today)
        start.setHours(0, 0, 0, 0)
        const day = new Date(when)
        day.setHours(0, 0, 0, 0)
        const days = Math.round((day.getTime() - start.getTime()) / 86400000)
        if (days === 0) return Translation.tr("Today")
        if (days === 1) return Translation.tr("Tomorrow")
        return IrisFaceData.capitalized(Translation.locale.toString(when, "dddd d"))
    }

    component DateHero: ColumnLayout {
        spacing: 0
        FaceText {
            face: root
            Layout.fillWidth: true
            text: IrisFaceData.capitalized(Translation.locale.toString(root.today, "dddd"))
            color: root.accent
            size: 13
            weight: Font.DemiBold
        }
        FaceFigure {
            face: root
            Layout.fillWidth: true
            text: root.today.getDate()
            size: 40
        }
    }

    component EventRow: RowLayout {
        id: row
        property var event: null
        spacing: root.dp(8)
        Rectangle {
            Layout.preferredWidth: root.dp(3)
            Layout.fillHeight: true
            radius: IrisStyle.capsule(width)
            color: IrisFaceData.eventTint(row.event, root.accent)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.eventTitle(row.event)
                size: 13
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: {
                    const when = IrisFaceData.eventWhen(row.event, root.today)
                    const place = root.widget.showLocation ? String(row.event?.location ?? "") : ""
                    return place.length > 0 ? when + " · " + place : when
                }
                color: root.inkSecondary
                size: 11.5
            }
        }
    }

    component Empty: FaceText {
        face: root
        text: IrisFaceData.unwidowed(Translation.tr("Nothing scheduled"))
        color: root.inkTertiary
        size: 12.5
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }

    // An empty agenda still answers "what week is it": the week with today lit, then the words.
    readonly property var week: {
        const first = new Date(root.today)
        first.setHours(0, 0, 0, 0)
        const lead = (first.getDay() - Qt.locale().firstDayOfWeek + 7) % 7
        first.setDate(first.getDate() - lead)
        const days = []
        for (let i = 0; i < 7; ++i) {
            const day = new Date(first)
            day.setDate(first.getDate() + i)
            days.push(day)
        }
        return days
    }
    component WeekStrip: RowLayout {
        spacing: 0
        Repeater {
            model: root.week
            ColumnLayout {
                id: day
                required property var modelData
                readonly property bool current: day.modelData.getDate() === root.today.getDate()
                    && day.modelData.getMonth() === root.today.getMonth()
                // A column caps its width at its widest child unless told: the week bunched up on the left.
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: root.dp(4)
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.locale.toString(day.modelData, "ddd").charAt(0).toUpperCase()
                    color: day.current ? root.accent : root.inkTertiary
                    size: 11
                    weight: Font.DemiBold
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: root.dp(26)
                    implicitHeight: implicitWidth
                    radius: IrisStyle.capsule(width)
                    color: day.current ? root.todayFill : "transparent"
                    FaceText {
                        face: root
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        color: day.current ? root.todayInk : root.inkSecondary
                        font.family: root.fontNumbers
                        font.features: ({ "tnum": 1 })
                        size: 13
                        weight: day.current ? Font.Bold : Font.Medium
                    }
                }
            }
        }
    }

    // Small: the next event leads, its time as the figure (the date is on every other face); free, the date leads.
    ColumnLayout {
        visible: root.small && root.next !== null
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "event_upcoming"
            text: root.next ? root.dayLabel(root.next) : ""
        }
        Row {
            visible: root.nextTime !== null
            spacing: root.dp(5)
            FaceFigure {
                id: nextFigure
                face: root
                text: root.nextTime?.main ?? ""
                size: 34
            }
            FaceText {
                face: root
                visible: (root.nextTime?.suffix ?? "").length > 0
                anchors.baseline: nextFigure.baseline
                text: root.nextTime?.suffix ?? ""
                color: root.inkSecondary
                size: 15
                weight: Font.DemiBold
            }
        }
        Item { Layout.fillHeight: true }
        EventRow {
            Layout.fillWidth: true
            event: root.next
        }
    }
    ColumnLayout {
        visible: root.small && root.next === null
        anchors.fill: parent
        spacing: root.dp(6)
        DateHero { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        Empty { Layout.fillWidth: true }
    }

    RowLayout {
        visible: root.medium
        anchors.fill: parent
        spacing: root.dp(14)
        DateHero {
            Layout.fillWidth: false
            Layout.preferredWidth: root.contentWidth * 0.28
            Layout.alignment: Qt.AlignTop
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(8)
            Repeater {
                model: root.shown
                EventRow {
                    required property var modelData
                    Layout.fillWidth: true
                    event: modelData
                }
            }
            WeekStrip { visible: root.shown.length === 0; Layout.fillWidth: true }
            // Free: the words read right under the week they talk about
            Empty { visible: root.shown.length === 0; Layout.fillWidth: true; Layout.leftMargin: root.dp(4) }
            Item { Layout.fillHeight: true }
        }
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(8)
        DateHero { Layout.fillWidth: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        Repeater {
            model: root.large ? root.shown : []
            ColumnLayout {
                id: entry
                required property var modelData
                required property int index
                readonly property string day: root.dayLabel(entry.modelData)
                readonly property bool heading: entry.index === 0 || root.dayLabel(root.shown[entry.index - 1]) !== entry.day
                Layout.fillWidth: true
                spacing: root.dp(4)
                FaceText {
                    face: root
                    visible: entry.heading && root.widget.groupByDay
                    Layout.fillWidth: true
                    Layout.topMargin: entry.index === 0 ? 0 : root.dp(4)
                    text: entry.day
                    color: root.inkTertiary
                    size: 11.5
                    weight: Font.DemiBold
                }
                EventRow {
                    Layout.fillWidth: true
                    event: entry.modelData
                }
            }
        }
        WeekStrip { visible: root.shown.length === 0; Layout.fillWidth: true; Layout.topMargin: root.dp(4) }
        // A free week fills the room it has with a calm mark instead of a line of grey over air.
        Item {
            visible: root.shown.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            FaceBlank {
                face: root
                // Large has room to lose it in: there it waits right under its head, where the first row would be.
                // Placed by y, never by anchors switched per size (they left faces at the old size, 10-23).
                y: root.large ? root.dp(24) : Math.round((parent.height - height) / 2)
                width: parent.width
                glyph: "event_available"
                title: Translation.tr("Nothing scheduled")
                detail: Translation.tr("The next seven days are free")
            }
        }
        Item { Layout.fillHeight: true; visible: root.shown.length > 0 }
    }
}
