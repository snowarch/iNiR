pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    // Emitted when a day with events is clicked (for navigation in legacy mode)
    signal dayWithEventsClicked(var date)
    // Emitted to open the events dialog. An event object means edit it, a Date
    // means a new event prefilled to that day.
    signal openEventsDialog(var editEvent)
    signal requestExpand()

    // Two states: "month" (grid + upcoming) and "day" (day detail)
    property string viewState: "month"
    property var selectedDate: null

    // Trigger to force recomputation when events change
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

    // Style tokens (5-style support)
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colOnPrimary: Appearance.zzzEverywhere ? Appearance.zzz.onSticker
        : Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    readonly property color colCard: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    property var locale: {
        const envLocale = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || ""
        const cleaned = (envLocale.split(".")[0] ?? "").split("@")[0] ?? ""
        return cleaned ? Qt.locale(cleaned) : Qt.locale()
    }

    property list<var> weekDaysModel: {
        const fdow = locale?.firstDayOfWeek ?? Qt.locale().firstDayOfWeek
        const first = DateUtils.getFirstDayOfWeek(new Date(), fdow)
        const days = []
        for (let i = 0; i < 7; i++) {
            const d = new Date(first)
            d.setDate(first.getDate() + i)
            days.push({
                label: locale.toString(d, "ddd"),
                today: DateUtils.sameDate(d, DateTime.clock.date)
            })
        }
        return days
    }

    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0, locale?.firstDayOfWeek ?? 1)
    implicitHeight: contentStack.implicitHeight
    implicitWidth: contentStack.implicitWidth

    // Merged event count for a specific day (local + external)
    function getEventCountForDay(day: int, weekRow: int, dayIndex: int): int {
        const _t = root._eventsTrigger
        const _t2 = root._externalTrigger
        const targetDate = _getDateForCell(day, weekRow, dayIndex)
        if (!targetDate) return 0
        const localCount = Events.getEventsForDate(targetDate).length
        const externalCount = (CalendarSync.getEventsForDate(targetDate) || []).length
        return localCount + externalCount
    }

    // Get source colors for multi-colored dots on a day cell
    function getSourceColorsForDay(day: int, weekRow: int, dayIndex: int): var {
        const _t = root._eventsTrigger
        const _t2 = root._externalTrigger
        const targetDate = _getDateForCell(day, weekRow, dayIndex)
        if (!targetDate) return []

        const colors = []
        // Local events get primary color
        const localEvents = Events.getEventsForDate(targetDate)
        if (localEvents.length > 0) {
            colors.push(root.colPrimary)
        }
        // External events get their source colors
        const externalColors = CalendarSync.getSourceColorsForDate(targetDate) || []
        for (const c of externalColors) {
            if (colors.indexOf(c) === -1) colors.push(c)
        }
        return colors
    }

    // Resolve a calendar cell to a real Date object
    function _getDateForCell(day: int, weekRow: int, dayIndex: int): var {
        const cellData = root.calendarLayout[weekRow]?.[dayIndex]
        if (!cellData) return null
        const year = root.viewingDate.getFullYear()
        const month = root.viewingDate.getMonth()
        let targetMonth = month
        let targetYear = year
        if (cellData.today === -1) {
            if (month === 0) { targetMonth = 11; targetYear = year - 1 }
            else targetMonth = month - 1
        }
        return new Date(targetYear, targetMonth, day)
    }

    function openDayDetail(date: var): void {
        root.selectedDate = date
        root.viewState = "day"
    }

    function closeDayDetail(): void {
        root.viewState = "month"
    }

    Keys.onPressed: (event) => {
        if (root.viewState === "day" && event.key === Qt.Key_Escape) {
            closeDayDetail()
            event.accepted = true
            return
        }
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) monthShift++
            else if (event.key === Qt.Key_PageUp) monthShift--
            event.accepted = true
        }
    }

    // Content stack — month view and day detail with crossfade transition
    Item {
        id: contentStack
        anchors.fill: parent
        implicitHeight: root.viewState === "day" ? dayDetailView.implicitHeight : monthView.implicitHeight
        implicitWidth: parent?.width ?? 280

        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        // Month view (grid + upcoming)
        Item {
            id: monthView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            implicitHeight: monthColumn.implicitHeight
            opacity: root.viewState === "month" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onWheel: (event) => {
                    if (event.angleDelta.y > 0) monthShift--
                    else if (event.angleDelta.y < 0) monthShift++
                }
            }

            ColumnLayout {
                id: monthColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                // Calendar header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Today's date highlight
                    Rectangle {
                        visible: monthShift === 0
                        Layout.preferredWidth: todayCol.implicitWidth + 16
                        Layout.preferredHeight: todayCol.implicitHeight + 8
                        radius: root.radius
                        color: root.colPrimary

                        ColumnLayout {
                            id: todayCol
                            anchors.centerIn: parent
                            spacing: -2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: DateTime.clock.date.getDate()
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                font.family: Appearance.font.family.numbers
                                color: root.colOnPrimary
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: locale.toString(DateTime.clock.date, "ddd")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.colOnPrimary
                                opacity: 0.9
                            }
                        }
                    }

                    // Month/Year title
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: locale.toString(viewingDate, "MMMM")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: root.colText
                        }

                        StyledText {
                            text: locale.toString(viewingDate, "yyyy")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.colTextSecondary
                        }
                    }

                    // Navigation buttons
                    RowLayout {
                        spacing: 4

                        CalNavButton {
                            visible: monthShift !== 0
                            icon: "today"
                            tooltipText: Translation.tr("Jump to today")
                            onClicked: monthShift = 0
                        }

                        CalNavButton {
                            icon: "chevron_left"
                            tooltipText: Translation.tr("Previous month")
                            onClicked: monthShift--
                        }

                        CalNavButton {
                            icon: "chevron_right"
                            tooltipText: Translation.tr("Next month")
                            onClicked: monthShift++
                        }

                        CalNavButton {
                            icon: "open_in_full"
                            tooltipText: Translation.tr("Open full calendar")
                            onClicked: root.requestExpand()
                        }
                    }
                }

                // Week days row
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: false
                    Layout.topMargin: 4
                    spacing: 5
                    Repeater {
                        model: weekDaysModel
                        delegate: CalendarDayButton {
                            required property var modelData
                            day: modelData.label
                            isToday: modelData.today ? 1 : 0
                            isHeader: true
                            bold: true
                            enabled: false
                        }
                    }
                }

                // Calendar grid rows
                Repeater {
                    id: calendarRows
                    model: 6
                    delegate: RowLayout {
                        required property int index
                        property int weekRow: index
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillHeight: false
                        spacing: 5
                        Repeater {
                            model: Array(7).fill(parent.weekRow)
                            delegate: CalendarDayButton {
                                required property int index
                                required property int modelData
                                day: root.calendarLayout[modelData][index].day
                                isToday: root.calendarLayout[modelData][index].today
                                eventCount: root.getEventCountForDay(root.calendarLayout[modelData][index].day, modelData, index)
                                sourceColors: root.getSourceColorsForDay(root.calendarLayout[modelData][index].day, modelData, index)
                                onClicked: {
                                    const targetDate = root._getDateForCell(root.calendarLayout[modelData][index].day, modelData, index)
                                    if (targetDate) {
                                        if (eventCount > 0) {
                                            root.openDayDetail(targetDate)
                                        } else {
                                            // Still allow clicking empty days to add events
                                            root.openDayDetail(targetDate)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }

        // Day detail view
        Item {
            id: dayDetailView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            implicitHeight: dayDetail.implicitHeight
            opacity: root.viewState === "day" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.OutCubic
                }
            }

            CalendarDayDetail {
                id: dayDetail
                anchors.left: parent.left
                anchors.right: parent.right
                selectedDate: root.selectedDate
                onBackClicked: root.closeDayDetail()
                onEventClicked: (event) => {
                    if ((event?.source ?? "local") === "local") root.openEventsDialog(event)
                }
                // A Date means "new event on this day". Hosts must not treat it
                // as an existing event to edit: a template object would make the
                // dialog call updateEvent() with no id and silently drop the event.
                onAddEventClicked: (date) => root.openEventsDialog(date)
            }
        }
    }

    // Navigation button component
    component CalNavButton: Item {
        id: navBtn
        required property string icon
        property string tooltipText: ""

        signal clicked()

        implicitWidth: 32
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: {
                if (navBtnMA.containsPress)
                    return Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                        : Appearance.colors.colLayer1Active
                if (navBtnMA.containsMouse)
                    return Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                        : Appearance.colors.colLayer1Hover
                return "transparent"
            }
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: navBtn.icon
                iconSize: 18
                color: root.colTextSecondary
            }

            MouseArea {
                id: navBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: navBtn.clicked()
            }

            StyledToolTip {
                visible: navBtnMA.containsMouse && navBtn.tooltipText !== ""
                text: navBtn.tooltipText
            }
        }
    }
}
