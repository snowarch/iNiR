import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.calendar

/**
 * Calendar card. Reuses the sidebar month calendar (per-day event dots already
 * built in). Bubbles its event signals up to the dashboard host so clicking a
 * day with events — or an existing event — opens the shared events dialog,
 * correlating the calendar with the agenda. `dayWithEventsClicked` carries the
 * date so a new event is prefilled to the day the user tapped.
 */
DashCard {
    id: root

    // Host (DashboardContent) opens the shared events dialog. null = new event;
    // a Date = new event prefilled to that day; an event object = edit it.
    signal requestEventsDialog(var event)

    CalendarWidget {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        onOpenEventsDialog: editEvent => root.requestEventsDialog(editEvent)
        onDayWithEventsClicked: date => root.requestEventsDialog(date)
    }
}
