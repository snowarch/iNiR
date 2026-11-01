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
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
AbstractBackgroundWidget {
    id: root

    configEntryName: "calendarUpcoming"
    familyOptions: [
        { key: "groupByDay", raw: true, label: Translation.tr("Group by day"), icon: "event_list", fallback: true },
        { key: "showLocation", raw: true, label: Translation.tr("Location"), icon: "location_on", fallback: false }
    ]

    visibleWhenLocked: true
    needsColText: true
    resizeMinWidth: 200
    resizeMinHeight: 120
    resizeMaxWidth: 600
    resizeMaxHeight: 800

    readonly property int maxEvents: Number(root._readConfigKey("maxEvents") ?? 5)
    // Type follows the room: large kept small's sizes and left half its plate empty (10-30 gallery).
    readonly property real roomScale: root.isLarge ? 1.3 : 1
    readonly property bool showDate: root._readConfigKey("showDate") ?? true
    readonly property bool showTime: root._readConfigKey("showTime") ?? true
    readonly property bool showLocation: root._readConfigKey("showLocation") ?? false
    readonly property bool groupByDay: root._readConfigKey("groupByDay") ?? true
    readonly property string eventStyle: root._readConfigKey("style") ?? "card"
    readonly property bool instrument: root.eventStyle === "instrument"

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
            return Object.assign({}, event, { _showDayHeader: showDayHeader, _underHeading: root.groupByDay && dayKey !== "" })
        })
    }

    // ── Card background ────────────────────────────────────────
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
                shown: !root.familyFaced && !root.instrument && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
            }
        }
    }

    // ── Content ────────────────────────────────────────────────
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            ColumnLayout {
                visible: !root.familyFaced
                anchors.fill: parent
                anchors.margins: Math.round(12 * root.scaleFactor)
                clip: true
                spacing: Math.round(4 * root.scaleFactor)

                // Header
                RowLayout {
                    visible: root.upcomingEvents.length > 0 || root.instrument
                    Layout.fillWidth: true
                    spacing: 6

                    InstrumentLabel {
                        visible: root.instrument
                        text: Translation.tr("Agenda / Upcoming")
                        color: root.widgetAccentVisible
                        scaleFactor: root.scaleFactor
                        strong: true
                    }
                    StyledText {
                        visible: !root.instrument
                        text: Translation.tr("Upcoming")
                        color: root.instrument ? root.widgetInk : (root.widgetEditorial ? root.widgetInk : root.widgetInkMuted)
                        font.family: root.instrument ? Appearance.font.family.monospace : root.widgetTitleFamily
                        font.pixelSize: Math.round((root.instrument ? Appearance.font.pixelSize.normal
                            : Appearance.font.pixelSize.smaller * root.widgetTitleScale) * root.scaleFactor * root.roomScale)
                        font.weight: root.instrument ? Font.Bold : (root.widgetEditorial ? root.widgetTitleWeight : Font.Medium)
                        font.letterSpacing: root.instrument ? Math.round(1.4 * root.scaleFactor) : root.widgetTitleTracking
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        visible: root.instrument
                        text: String(root.upcomingEvents.length).padStart(2, "0")
                        color: root.widgetAccentVisible
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        font.weight: Font.Bold
                    }

                }

                // Events list: the ones that fit whole; the rest were cut through by the plate's edge.
                Repeater {
                    model: root.upcomingEvents.slice(0, root.fittingEvents)

                    delegate: ColumnLayout {
                        id: eventDelegate
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: Math.round(3 * root.scaleFactor)

                        StyledText {
                            visible: eventDelegate.modelData?._showDayHeader ?? false
                            text: root._dayHeading(eventDelegate.modelData)
                            color: root.instrument ? root.widgetInkMuted : root.widgetAccentVisible
                            font {
                                family: root.instrument ? Appearance.font.family.monospace : root.widgetBodyFamily
                                pixelSize: Math.round((root.instrument ? Appearance.font.pixelSize.small
                                    : Appearance.font.pixelSize.smaller) * root.scaleFactor * root.roomScale)
                                weight: Font.DemiBold
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(8 * root.scaleFactor)

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: Math.round((root.instrument ? 1 : 4) * root.scaleFactor)
                                width: Math.max(2, Math.round((root.instrument ? 2 : 3) * root.scaleFactor))
                                height: Math.round((root.instrument ? 34 : 16) * root.scaleFactor * root.roomScale)
                                radius: root.instrument ? 0 : width / 2
                                color: eventDelegate.modelData?.color || root.widgetAccentVisible
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: eventDelegate.modelData?.title || Translation.tr("Untitled")
                                    color: root.widgetInk
                                    font.family: root.widgetEditorial
                                        ? root.widgetTitleFamily : root.widgetBodyFamily
                                    font.pixelSize: Math.round((root.instrument ? Appearance.font.pixelSize.normal
                                        : Appearance.font.pixelSize.small) * root.scaleFactor * root.roomScale)
                                    font.weight: root.instrument ? Font.DemiBold
                                        : (root.widgetEditorial ? root.widgetTitleWeight : Font.Medium)
                                    font.letterSpacing: root.widgetEditorial ? root.widgetTitleTracking : 0
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: root._formatDateTime(eventDelegate.modelData)
                                    color: root.instrument ? root.widgetAccentVisible : root.widgetInkMuted
                                    font.pixelSize: Math.round((root.instrument ? Appearance.font.pixelSize.small
                                        : Appearance.font.pixelSize.smaller) * root.scaleFactor * root.roomScale)
                                    font.family: root.widgetNumbersFamily
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
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.instrument ? parent.width : Math.min(parent.width,
                            Math.round(190 * root.scaleFactor))
                        x: root.instrument ? 0 : Math.round((parent.width - width) / 2)
                        spacing: Math.round(7 * root.scaleFactor)

                        MaterialShape {
                            visible: !root.instrument
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
                            horizontalAlignment: root.instrument ? Text.AlignLeft : Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.instrument ? Translation.tr("All clear")
                                : Translation.tr("No upcoming events")
                            color: root.instrument ? root.widgetInk : root.widgetInkMuted
                            font.family: root.instrument ? root.widgetTitleFamily : root.widgetBodyFamily
                            font.pixelSize: Math.round((root.instrument ? 22 : Appearance.font.pixelSize.small) * root.scaleFactor * root.roomScale)
                            font.weight: root.instrument ? Font.Bold : Font.Normal
                            wrapMode: Text.WordWrap
                        }

                        InstrumentLabel {
                            visible: root.instrument
                            width: parent.width
                            text: Translation.tr("No events ahead")
                            color: root.widgetInkMuted
                            scaleFactor: root.scaleFactor
                        }
                    }
                }

                Item {
                    visible: root.upcomingEvents.length > 0
                    Layout.fillHeight: true
                }
            }
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
        // under its day's heading the line says only the hour ("Today" over "Today · 21:30")
        if (root.showDate && !event._underHeading) {
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

    // How many rows fit under the header, from the type sizes the rows use (a row is its title and its time line,
    // plus a day heading when it opens a day).
    readonly property int fittingEvents: {
        const k = root.scaleFactor
        const line = px => Math.ceil(px * k * root.roomScale * 1.36)
        const small = root.instrument ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
        const smaller = root.instrument ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
        let room = root.height - Math.round(24 * k) - line(Appearance.font.pixelSize.normal) - Math.round(4 * k)
        let count = 0
        for (const event of root.upcomingEvents) {
            room -= line(small) + 1 + line(smaller) + Math.round(4 * k)
                + (event._showDayHeader ? line(smaller) + Math.round(3 * k) : 0)
                + (root.showLocation && (event.location?.length ?? 0) > 0 ? line(smaller) : 0)
            if (room < 0)
                break
            ++count
        }
        return Math.max(1, count)
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
