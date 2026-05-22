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
        showBackground: true, showBorder: true,
        backgroundOpacity: 0.10, borderOpacity: 0.12,
        colorMode: "auto", dim: 0,
        x: 80, y: 80
    })

    implicitWidth: Math.round((Config.getNestedValue("background.widgets.calendarUpcoming.contentWidth", 280)) * scaleFactor)
    implicitHeight: Math.round((Config.getNestedValue("background.widgets.calendarUpcoming.contentHeight", 220)) * scaleFactor)

    visibleWhenLocked: true
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 200
    resizeMinHeight: 100
    resizeMaxWidth: 600
    resizeMaxHeight: 800

    readonly property int maxEvents: Config.getNestedValue("background.widgets.calendarUpcoming.maxEvents", 5)
    readonly property bool showDate: Config.getNestedValue("background.widgets.calendarUpcoming.showDate", true)
    readonly property bool showTime: Config.getNestedValue("background.widgets.calendarUpcoming.showTime", true)
    readonly property bool showLocation: Config.getNestedValue("background.widgets.calendarUpcoming.showLocation", false)
    readonly property bool groupByDay: Config.getNestedValue("background.widgets.calendarUpcoming.groupByDay", true)

    property real dimFactor: {
        const v = Number(Config.getNestedValue("background.widgets.calendarUpcoming.dim", 0));
        return Math.max(0, Math.min(1, Number.isFinite(v) ? v / 100 : 0));
    }

    readonly property real cardRadius: Appearance.rounding.normal

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

    // ── Merged + sorted upcoming events ───────────────────────
    readonly property var upcomingEvents: {
        const _t = root._refreshTrigger
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
        return all.slice(0, root.maxEvents)
    }

    // ── Edit popover: max events + toggles ────────────────────
    editPopoverContent: Component {
        Column {
            spacing: 6

            // Max events spinner
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
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
                anchors.horizontalCenter: parent.horizontalCenter
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "schedule"
                    buttonText: "Time"
                    toggled: root.showTime
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.showTime", !root.showTime)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "today"
                    buttonText: "Date"
                    toggled: root.showDate
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.showDate", !root.showDate)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "place"
                    buttonText: "Location"
                    toggled: root.showLocation
                    onClicked: Config.setNestedValue("background.widgets.calendarUpcoming.showLocation", !root.showLocation)
                }
            }
        }
    }

    // ── Card background ────────────────────────────────────────
    WidgetSurface {
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.colText
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
    }

    // ── Content ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.scaleFactor)
        spacing: Math.round(4 * root.scaleFactor)
        opacity: 1.0 - root.dimFactor * 0.5

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                text: Translation.tr("Upcoming")
                color: ColorUtils.applyAlpha(root.colText, 0.7)
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            StyledText {
                visible: root.upcomingEvents.length === 0
                text: Translation.tr("No events")
                color: ColorUtils.applyAlpha(root.colText, 0.4)
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
            }
        }

        // Events list
        Repeater {
            model: root.upcomingEvents

            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Math.round(8 * root.scaleFactor)

                // Color/source indicator
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.round(4 * root.scaleFactor)
                    width: 3
                    height: Math.round(16 * root.scaleFactor)
                    radius: 1.5
                    color: parent.modelData?.color || ColorUtils.applyAlpha(root.colText, 0.5)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: parent.parent.modelData?.title || Translation.tr("Untitled")
                        color: root.colText
                        font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root._formatDateTime(parent.parent.modelData)
                        color: ColorUtils.applyAlpha(root.colText, 0.6)
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        font.family: Appearance.font.family.numbers
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.showLocation && (parent.parent.modelData?.location?.length ?? 0) > 0
                        text: parent.parent.modelData?.location ?? ""
                        color: ColorUtils.applyAlpha(root.colText, 0.5)
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
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
}
