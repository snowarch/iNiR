pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.calendar

/**
 * Upcoming agenda: merges local events (Events service) with external
 * calendars (CalendarSync, ICS) into one day-grouped list for the next two
 * weeks. Rows reuse CalendarEventRow so both sources render consistently.
 */
DashCard {
    id: card
    icon: "event_upcoming"
    title: Translation.tr("Agenda")

    // Host (DashboardContent) opens the shared events dialog; null = new event.
    signal requestEventsDialog(var event)

    readonly property int lookaheadDays: 14
    readonly property int maxRows: 8

    property int _localTrigger: 0
    Connections {
        target: Events
        function onEventAdded(event) { card._localTrigger++ }
        function onEventRemoved(id) { card._localTrigger++ }
        function onEventUpdated(event) { card._localTrigger++ }
    }
    property int _externalTrigger: 0
    Connections {
        target: CalendarSync
        function onEventsUpdated() { card._externalTrigger++ }
    }

    function _dayLabel(d) {
        const today = new Date(); today.setHours(0, 0, 0, 0)
        const day = new Date(d); day.setHours(0, 0, 0, 0)
        const diff = Math.round((day - today) / 86400000)
        if (diff === 0) return Translation.tr("Today")
        if (diff === 1) return Translation.tr("Tomorrow")
        return Qt.formatDate(day, "ddd d MMM")
    }

    readonly property string _todayKey: Qt.formatDate(DateTime.clock.date, "yyyy-MM-dd")

    // Day-grouped entries: { header } and { event } rows, capped at maxRows
    // events with an overflow counter.
    readonly property var entries: {
        const _t1 = card._localTrigger
        const _t2 = card._externalTrigger
        const _d = card._todayKey
        return card._buildEntries()
    }
    property int overflowCount: 0

    function _buildEntries() {
        const now = new Date()
        const startDay = new Date(now); startDay.setHours(0, 0, 0, 0)
        const merged = Events.getUpcomingEvents(card.lookaheadDays)
            .map(e => Object.assign({}, e, { _source: "local" }))
        for (let i = 0; i < card.lookaheadDays; i++) {
            const d = new Date(startDay); d.setDate(d.getDate() + i)
            const dayEvents = CalendarSync.getEventsForDate(d) || []
            for (const e of dayEvents) {
                const evtTime = new Date(e.startDate || e.dateTime)
                if (evtTime < now && !(e.allDay && evtTime >= startDay)) continue
                merged.push(Object.assign({}, e, {
                    _source: "external",
                    dateTime: e.startDate || e.dateTime,
                    category: "general",
                    priority: "normal"
                }))
            }
        }
        merged.sort((a, b) => new Date(a.dateTime || a.startDate) - new Date(b.dateTime || b.startDate))

        const rows = []
        let lastDay = ""
        let shown = 0
        for (const e of merged) {
            if (shown >= card.maxRows) break
            const dayKey = card._dayLabel(e.dateTime || e.startDate)
            if (dayKey !== lastDay) {
                rows.push({ type: "header", label: dayKey })
                lastDay = dayKey
            }
            rows.push({ type: "event", event: e })
            shown++
        }
        card.overflowCount = Math.max(0, merged.length - shown)
        return rows
    }

    Repeater {
        model: card.entries
        delegate: Loader {
            id: entryLoader
            required property var modelData
            Layout.fillWidth: true
            sourceComponent: modelData.type === "header" ? headerRow : eventRow

            Component {
                id: headerRow
                StyledText {
                    text: entryLoader.modelData.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: card.colAccent
                }
            }
            Component {
                id: eventRow
                CalendarEventRow {
                    event: entryLoader.modelData.event
                    onClicked: {
                        if ((entryLoader.modelData.event?._source ?? "local") === "local")
                            card.requestEventsDialog(entryLoader.modelData.event)
                    }
                }
            }
        }
    }

    StyledText {
        visible: card.overflowCount > 0
        text: Translation.tr("+%1 more in the next two weeks").arg(card.overflowCount)
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: card.colSubtext
    }

    // Empty state
    ColumnLayout {
        visible: card.entries.length === 0
        Layout.fillWidth: true
        spacing: 4
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("No upcoming events")
            font.pixelSize: Appearance.font.pixelSize.small
            color: card.colSubtext
        }
    }

    RippleButton {
        Layout.alignment: Qt.AlignHCenter
        implicitHeight: 30
        implicitWidth: addRowContent.implicitWidth + 24
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colLayer1Active
        onClicked: card.requestEventsDialog(null)
        contentItem: RowLayout {
            id: addRowContent
            spacing: 4
            MaterialSymbol {
                text: "add"
                iconSize: Appearance.font.pixelSize.normal
                color: card.colAccent
            }
            StyledText {
                text: Translation.tr("New event")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: card.colAccent
            }
        }
    }
}
