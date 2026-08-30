pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "calendarUpcoming"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 280, contentHeight: 220,
        maxEvents: 5,
        showDate: true,
        showTime: true,
        showLocation: false,
        groupByDay: true,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.10, borderWidth: 1, borderOpacity: 0.12,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 80, y: 80
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 280)
        * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 220)
        * root.scaleFactor)

    visibleWhenLocked: true
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 200
    resizeMinHeight: 120
    resizeMaxWidth: 600
    resizeMaxHeight: 800

    readonly property int maxEvents: Config.getNestedValue("background.widgets.calendarUpcoming.maxEvents", 5)
    readonly property bool showDate: Config.getNestedValue("background.widgets.calendarUpcoming.showDate", true)
    readonly property bool showTime: Config.getNestedValue("background.widgets.calendarUpcoming.showTime", true)
    readonly property bool showLocation: Config.getNestedValue("background.widgets.calendarUpcoming.showLocation", false)
    readonly property bool groupByDay: Config.getNestedValue("background.widgets.calendarUpcoming.groupByDay", true)

    readonly property real cardRadius: root.widgetCardRadius

    // ── Refresh trigger when events change ────────────────────
    property int _refreshTrigger: 0
    Connections {
        target: Events
        function onEventAdded() { root._refreshTrigger++ }
        function onEventRemoved() { root._refreshTrigger++ }
        function onEventUpdated() { root._refreshTrigger++ }
    }
    Connections {
        target: CalendarSync
        function onEventsUpdated() { root._refreshTrigger++ }
    }

    readonly property string _todayKey: Qt.formatDate(DateTime.clock.date, "yyyy-MM-dd")

    // ── Merged + sorted upcoming events ───────────────────────
    readonly property var upcomingEvents: {
        const _t = root._refreshTrigger
        const _d = root._todayKey
        return root._buildList()
    }

    function _buildList(): var {
        const now = new Date()
        const local = (typeof Events !== "undefined" && Events.getUpcomingEvents)
            ? Events.getUpcomingEvents(30).map(e => Object.assign({}, e, { _source: "local" }))
            : []

        const startDay = new Date(now)
        startDay.setHours(0, 0, 0, 0)
        const externalAll = []
        if (typeof CalendarSync !== "undefined") {
            for (let i = 0; i < 30; i++) {
                const d = new Date(startDay)
                d.setDate(d.getDate() + i)
                const dayEvents = CalendarSync.getEventsForDate(d) || []
                for (const e of dayEvents) {
                    const evtTime = new Date(e.startDate || e.dateTime)
                    if (evtTime < now && !(e.allDay && evtTime >= startDay)) continue
                    externalAll.push(Object.assign({}, e, {
                        _source: "external",
                        dateTime: e.startDate || e.dateTime
                    }))
                }
            }
        }

        const all = local.concat(externalAll)
        all.sort((a, b) => new Date(a.dateTime || a.startDate) - new Date(b.dateTime || b.startDate))
        const limited = all.slice(0, root.maxEvents)
        let previousDay = ""
        return limited.map(event => {
            const dt = new Date(event.dateTime || event.startDate)
            const dayKey = isNaN(dt.getTime()) ? "" : Qt.formatDate(dt, "yyyy-MM-dd")
            const showDayHeader = root.groupByDay && dayKey !== "" && dayKey !== previousDay
            previousDay = dayKey
            return Object.assign({}, event, { _showDayHeader: showDayHeader })
        })
    }

    // ── Edit popover: max events + toggles ────────────────────
    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6

            // Max events spinner
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignHCenter
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr("Show:")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                Repeater {
                    model: [3, 5, 8, 12]
                    SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonText: String(modelData)
                        toggled: root.maxEvents === modelData
                        onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.maxEvents", modelData)
                    }
                }
            }

            // Toggles
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "schedule"
                    buttonText: Translation.tr("Time")
                    toggled: root.showTime
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.showTime", !root.showTime)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "today"
                    buttonText: Translation.tr("Date")
                    toggled: root.showDate
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.showDate", !root.showDate)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "place"
                    buttonText: Translation.tr("Location")
                    toggled: root.showLocation
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.showLocation", !root.showLocation)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "view_day"
                    buttonText: Translation.tr("Group")
                    toggled: root.groupByDay
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.groupByDay", !root.groupByDay)
                }
            }
        }
    }

    // ── Card background ────────────────────────────────────────
    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // ── Content ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.scaleFactor)
        clip: true
        spacing: Math.round(4 * root.scaleFactor)

        // Header
        RowLayout {
            visible: root.upcomingEvents.length > 0
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                text: Translation.tr("Upcoming")
                color: root.widgetInkMuted
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

        }

        // Events list
        Repeater {
            model: root.upcomingEvents

            delegate: ColumnLayout {
                id: eventDelegate
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Math.round(3 * root.scaleFactor)

                StyledText {
                    visible: eventDelegate.modelData?._showDayHeader ?? false
                    text: root._dayHeading(eventDelegate.modelData)
                    color: root.widgetAccentVisible
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        weight: Font.DemiBold
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(8 * root.scaleFactor)

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Math.round(4 * root.scaleFactor)
                        width: Math.max(3, Math.round(3 * root.scaleFactor))
                        height: Math.round(16 * root.scaleFactor)
                        radius: width / 2
                        color: eventDelegate.modelData?.color || root.widgetAccentVisible
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: eventDelegate.modelData?.title || Translation.tr("Untitled")
                            color: root.widgetInk
                            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root._formatDateTime(eventDelegate.modelData)
                            color: root.widgetInkMuted
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                            font.family: Appearance.font.family.numbers
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.showLocation && (eventDelegate.modelData?.location?.length ?? 0) > 0
                            text: eventDelegate.modelData?.location ?? ""
                            color: root.widgetInkSubtle
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }

        Item {
            visible: root.upcomingEvents.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width,
                    Math.round(190 * root.scaleFactor))
                spacing: Math.round(7 * root.scaleFactor)

                MaterialShape {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: Math.round(54 * root.scaleFactor)
                    shape: MaterialShape.Shape.Ghostish
                    color: ColorUtils.applyAlpha(root.widgetAccent, 0.16)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "event_available"
                        iconSize: Math.round(26 * root.scaleFactor)
                        color: root.widgetAccentVisible
                    }
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("No upcoming events")
                    color: root.widgetInkMuted
                    font.pixelSize: Math.round(
                        Appearance.font.pixelSize.small * root.scaleFactor)
                    wrapMode: Text.WordWrap
                }
            }
        }

        Item {
            visible: root.upcomingEvents.length > 0
            Layout.fillHeight: true
        }
    }

    // Format date/time relative to today/tomorrow
    function _formatDateTime(event): string {
        if (!event) return ""
        const dt = new Date(event.dateTime || event.startDate)
        if (isNaN(dt.getTime())) return ""

        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const tomorrow = new Date(today)
        tomorrow.setDate(tomorrow.getDate() + 1)
        const eventDay = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate())

        let dateStr = ""
        if (root.showDate) {
            if (eventDay.getTime() === today.getTime()) dateStr = Translation.tr("Today")
            else if (eventDay.getTime() === tomorrow.getTime()) dateStr = Translation.tr("Tomorrow")
            else dateStr = Qt.formatDate(dt, "ddd d MMM")
        }

        let timeStr = ""
        if (root.showTime && !event.allDay)
            timeStr = Qt.formatTime(dt, "HH:mm")

        if (dateStr && timeStr) return dateStr + " · " + timeStr
        return dateStr || timeStr
    }

    function _dayHeading(event): string {
        if (!event) return ""
        const dt = new Date(event.dateTime || event.startDate)
        if (isNaN(dt.getTime())) return ""
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        const eventDay = new Date(dt)
        eventDay.setHours(0, 0, 0, 0)
        const days = Math.round((eventDay.getTime() - today.getTime()) / 86400000)
        if (days === 0) return Translation.tr("Today")
        if (days === 1) return Translation.tr("Tomorrow")
        return Qt.formatDate(dt, "dddd, d MMM")
    }
}
