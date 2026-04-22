pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

BodyRectangle {
    id: root

    // State
    property bool collapsed

    // Selected day for detail view (null = no selection)
    property var selectedDate: null
    readonly property bool showDayDetail: selectedDate !== null

    // Locale
    property var locale: {
        const loc = Config.options?.waffles?.calendar?.locale ?? "";
        if (loc)
            return Qt.locale(loc);

        const envLocale = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "";
        const cleaned = (envLocale.split(".")[0] ?? "").split("@")[0] ?? "";
        return cleaned ? Qt.locale(cleaned) : Qt.locale();
    }

    implicitHeight: collapsed ? 0 : calendarContent.implicitHeight
    implicitWidth: calendarContent.implicitWidth

    clip: true

    // Event triggers for reactivity
    property int _eventsTrigger: 0
    Connections {
        target: Events
        function onEventAdded(event) { root._eventsTrigger++ }
        function onEventRemoved(id) { root._eventsTrigger++ }
        function onEventUpdated(event) { root._eventsTrigger++ }
    }
    property int _externalTrigger: 0
    Connections {
        target: CalendarSync
        function onEventsUpdated() { root._externalTrigger++ }
    }

    // Get merged event count for a specific date
    function getEventCountForDate(date: var): int {
        root._eventsTrigger
        root._externalTrigger
        if (!date) return 0
        const localCount = Events.getEventsForDate(date).length
        const externalCount = (CalendarSync.getEventsForDate(date) || []).length
        return localCount + externalCount
    }

    // Get source colors for a date (for multi-dots)
    function getSourceColorsForDate(date: var): var {
        root._eventsTrigger
        root._externalTrigger
        if (!date) return []
        const colors = []
        const localEvents = Events.getEventsForDate(date)
        if (localEvents.length > 0) colors.push(Looks.colors.accent)
        const externalColors = CalendarSync.getSourceColorsForDate(date) || []
        for (const c of externalColors) {
            if (colors.indexOf(c) === -1) colors.push(c)
        }
        return colors
    }

    // Get events for the selected day
    function getSelectedDayEvents(): var {
        root._eventsTrigger
        root._externalTrigger
        if (!root.selectedDate) return []
        const localEvents = Events.getAllEventsForDate(root.selectedDate).map(e => Object.assign({}, e, {
            source: "local",
            startDate: e.dateTime
        }))
        const externalEvents = CalendarSync.getEventsForDate(root.selectedDate) || []
        const all = localEvents.concat(externalEvents)
        all.sort((a, b) => {
            if (a.allDay && !b.allDay) return -1
            if (!a.allDay && b.allDay) return 1
            return new Date(a.startDate || a.dateTime) - new Date(b.startDate || b.dateTime)
        })
        return all
    }

    // Get upcoming events (next 3 days)
    function getUpcomingEvents(): var {
        root._eventsTrigger
        root._externalTrigger
        const now = new Date()
        now.setHours(0, 0, 0, 0)
        const events = []

        for (let dayOffset = 0; dayOffset < 3; dayOffset++) {
            const date = new Date(now)
            date.setDate(date.getDate() + dayOffset)

            const localEvents = Events.getEventsForDate(date).map(e => Object.assign({}, e, {
                source: "local",
                startDate: e.dateTime,
                _dayOffset: dayOffset
            }))
            const externalEvents = (CalendarSync.getEventsForDate(date) || []).map(e => Object.assign({}, e, {
                _dayOffset: dayOffset
            }))
            const dayEvents = localEvents.concat(externalEvents)
            dayEvents.sort((a, b) => {
                if (a.allDay && !b.allDay) return -1
                if (!a.allDay && b.allDay) return 1
                return new Date(a.startDate || a.dateTime) - new Date(b.startDate || b.dateTime)
            })
            events.push(...dayEvents)
        }

        return events.slice(0, 5) // Cap at 5 items for density
    }

    readonly property var upcomingEvents: getUpcomingEvents()
    readonly property bool hasUpcoming: (Config.options?.calendar?.showUpcoming ?? true) && upcomingEvents.length > 0
    readonly property var selectedDayEvents: getSelectedDayEvents()

    Item {
        id: viewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.implicitHeight
        clip: true

        ColumnLayout {
            id: calendarContent
            width: parent.width
            spacing: 12
            opacity: 1
            scale: 1

            CalendarHeader {
                Layout.topMargin: 10
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 5
                Layout.rightMargin: 5
                spacing: 1

                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: root.locale
                    spacing: calendarView.buttonSpacing
                    implicitHeight: calendarView.buttonSize
                    delegate: Item {
                        id: dayOfWeekItem
                        required property var model
                        implicitHeight: calendarView.buttonSize
                        implicitWidth: calendarView.buttonSize

                        WText {
                            anchors.centerIn: parent
                            text: {
                                var result = dayOfWeekItem.model.shortName;
                                if (Config.options?.waffles?.calendar?.force2CharDayOfWeek ?? false) result = result.substring(0,2);
                                return result;
                            }
                            color: Looks.colors.fg
                            font.pixelSize: Looks.font.pixelSize.large
                        }
                    }
                }

                CalendarView {
                    id: calendarView
                    locale: root.locale
                    verticalPadding: 2
                    buttonSize: 41
                    buttonSpacing: 1
                    Layout.fillWidth: true
                    delegate: DayButton {}
                }
            }

            // Day detail — opacity + scale crossfade (WPageLoader pattern)
            ColumnLayout {
                id: dayDetailContent
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 4

                visible: opacity > 0
                opacity: root.showDayDetail ? 1 : 0
                scale: root.showDayDetail ? 1.0 : 0.97
                transformOrigin: Item.Top

                Behavior on opacity {
                    NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: root.showDayDetail ? Looks.transition.easing.bezierCurve.decelerate : Looks.transition.easing.bezierCurve.standard }
                }
                Behavior on scale {
                    NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: root.showDayDetail ? Looks.transition.easing.bezierCurve.decelerate : Looks.transition.easing.bezierCurve.standard }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Looks.colors.bg1Border
                    opacity: 0.5
                }

                // Header: selected date + close button
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    WText {
                        Layout.fillWidth: true
                        text: {
                            if (!root.selectedDate) return ""
                            const now = new Date()
                            if (now.toDateString() === root.selectedDate.toDateString()) return Translation.tr("Today")
                            const tomorrow = new Date(now)
                            tomorrow.setDate(tomorrow.getDate() + 1)
                            if (tomorrow.toDateString() === root.selectedDate.toDateString()) return Translation.tr("Tomorrow")
                            return root.locale.toString(root.selectedDate, "dddd, d MMMM")
                        }
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: Looks.font.weight.strong
                    }

                    WBorderlessButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        onClicked: root.selectedDate = null
                        contentItem: Item {
                            FluentIcon {
                                anchors.centerIn: parent
                                implicitSize: 10
                                icon: "dismiss"
                                color: Looks.colors.subfg
                            }
                        }
                    }
                }

                // Events for the selected day
                Repeater {
                    model: root.selectedDayEvents

                    delegate: WaffleEventRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        event: modelData
                        showDayPrefix: false
                    }
                }

                // Empty state
                WText {
                    visible: root.selectedDayEvents.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("No events")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                    opacity: 0.7
                }
            }

            // Upcoming events — crossfade out when day detail is shown
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8
                spacing: 4

                visible: opacity > 0
                opacity: (root.hasUpcoming && !root.showDayDetail) ? 1 : 0
                scale: (root.hasUpcoming && !root.showDayDetail) ? 1.0 : 0.97
                transformOrigin: Item.Top

                Behavior on opacity {
                    NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
                Behavior on scale {
                    NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Looks.colors.bg1Border
                    opacity: 0.5
                }

                WText {
                    text: Translation.tr("Upcoming")
                    font.pixelSize: Looks.font.pixelSize.small
                    font.weight: Looks.font.weight.strong
                    color: Looks.colors.subfg
                    Layout.topMargin: 2
                }

                Repeater {
                    model: root.upcomingEvents

                    delegate: WaffleEventRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        event: modelData
                        showDayPrefix: true
                    }
                }
            }

            // Bottom margin
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
            }
        }
    }

    // Waffle-styled compact event row
    component WaffleEventRow: Item {
        id: eventRow
        required property var event
        property bool showDayPrefix: true

        implicitHeight: rowContent.implicitHeight + 6
        implicitWidth: parent?.width ?? 200

        readonly property bool isExternal: (event?.source ?? "local") === "external"
        readonly property color dotColor: isExternal ? (event?.sourceColor ?? Looks.colors.accent) : Looks.colors.accent

        Rectangle {
            anchors.fill: parent
            radius: Looks.rounding.medium
            color: rowMA.containsMouse ? Looks.colors.bg1Hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Looks.transition.enabled ? 70 : 0
                }
            }

            RowLayout {
                id: rowContent
                anchors.fill: parent
                anchors.margins: 4
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8

                // Source color bar
                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: parent.height - 4
                    Layout.alignment: Qt.AlignVCenter
                    radius: 1.5
                    color: eventRow.dotColor
                }

                // Title + source name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    WText {
                        Layout.fillWidth: true
                        text: eventRow.event?.title ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.fg
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    WText {
                        Layout.fillWidth: true
                        visible: eventRow.isExternal && (eventRow.event?.sourceName ?? "") !== ""
                        text: eventRow.event?.sourceName ?? ""
                        font.pixelSize: Looks.font.pixelSize.tiny
                        color: Looks.colors.subfg
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        opacity: 0.7
                    }
                }

                // Time
                WText {
                    text: {
                        if (eventRow.event?.allDay) return Translation.tr("All day")
                        const d = new Date(eventRow.event?.startDate ?? eventRow.event?.dateTime ?? "")
                        if (isNaN(d.getTime())) return ""
                        if (!eventRow.showDayPrefix) return Qt.formatTime(d, "HH:mm")
                        const now = new Date()
                        const tomorrow = new Date(now)
                        tomorrow.setDate(tomorrow.getDate() + 1)
                        const dayOffset = eventRow.event?._dayOffset ?? 0
                        const prefix = dayOffset === 0 ? "" : dayOffset === 1 ? Translation.tr("Tomorrow") + " " : Qt.formatDate(d, "dd/MM") + " "
                        return prefix + Qt.formatTime(d, "HH:mm")
                    }
                    font.pixelSize: Looks.font.pixelSize.small
                    font.family: Looks.font.family.monospace
                    color: Looks.colors.subfg
                }
            }

            MouseArea {
                id: rowMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    component DayButton: WButton {
        id: dayButton
        required property var model
        checked: model.today || (root.selectedDate !== null && root.selectedDate.toDateString() === dayButton.buttonDate?.toDateString())
        enabled: hovered || calendarView.scrolling || checked || model.month === calendarView.focusedMonth
        implicitWidth: calendarView.buttonSize
        implicitHeight: calendarView.buttonSize
        radius: height / 2

        required property int index

        // Calculate the actual date this button represents
        readonly property var buttonDate: {
            const focused = calendarView.focusedDate
            if (!focused) return null
            const year = focused.getFullYear()
            const month = focused.getMonth()
            // model.month is relative to focused month
            let targetMonth = month + (model.month - calendarView.focusedMonth)
            let targetYear = year
            if (targetMonth < 0) { targetMonth += 12; targetYear-- }
            if (targetMonth > 11) { targetMonth -= 12; targetYear++ }
            return new Date(targetYear, targetMonth, model.day)
        }
        readonly property int eventCount: root.getEventCountForDate(buttonDate)
        readonly property var sourceColors: root.getSourceColorsForDate(buttonDate)

        onClicked: {
            if (model.month !== calendarView.focusedMonth) return
            // Toggle selection: click same day again to deselect
            if (root.selectedDate !== null && root.selectedDate.toDateString() === dayButton.buttonDate?.toDateString()) {
                root.selectedDate = null
            } else {
                root.selectedDate = dayButton.buttonDate
            }
        }

        contentItem: Item {
            WText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: dayButton.eventCount > 0 ? -2 : 0
                text: dayButton.model.day
                color: dayButton.fgColor
                font.pixelSize: Looks.font.pixelSize.large
            }

            // Multi-colored event dots
            Row {
                visible: dayButton.eventCount > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: 2

                Repeater {
                    model: dayButton.sourceColors.length > 0 ? dayButton.sourceColors.slice(0, 3) : (dayButton.eventCount > 0 ? [dayButton.checked ? Looks.colors.accentFg : Looks.colors.accent] : [])

                    delegate: Rectangle {
                        required property var modelData
                        width: 4
                        height: 4
                        radius: 2
                        color: modelData
                    }
                }
            }
        }
    }

    component CalendarHeader: RowLayout {
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        spacing: 8

        WBorderlessButton {
            Layout.fillWidth: true
            implicitHeight: 34
            contentItem: Item {
                WText {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignLeft
                    text: root.locale.toString(calendarView.focusedDate, "MMMM yyyy")
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Looks.font.weight.strong
                }
            }
        }
        ScrollMonthButton {
            scrollDown: false
        }
        ScrollMonthButton {
            scrollDown: true
        }
    }

    component ScrollMonthButton: WBorderlessButton {
        id: scrollMonthButton
        required property bool scrollDown
        Layout.alignment: Qt.AlignVCenter

        onClicked: {
            calendarView.scrollMonthsAndSnap(scrollDown ? 1 : -1);
        }
        implicitWidth: 32
        implicitHeight: 34

        contentItem: FluentIcon {
            filled: true
            implicitSize: 12
            icon: scrollMonthButton.scrollDown ? "caret-down" : "caret-up"
        }
    }
}
