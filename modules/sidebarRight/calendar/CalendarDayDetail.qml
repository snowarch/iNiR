pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

// Day detail view — shown when a day is clicked in the calendar grid.
// Groups events by time-of-day, merges local and external events.
Item {
    id: root

    required property var selectedDate // Date object

    signal backClicked()
    signal eventClicked(var event)
    signal addEventClicked(var date)

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colSubtext: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colOnPrimary: Appearance.zzzEverywhere ? Appearance.zzz.onSticker
        : Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    readonly property real cardRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    // Refresh when events change
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

    readonly property var locale: {
        const envLocale = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || ""
        const cleaned = (envLocale.split(".")[0] ?? "").split("@")[0] ?? ""
        return cleaned ? Qt.locale(cleaned) : Qt.locale()
    }

    // Build grouped events for the selected date
    readonly property var timeGroups: {
        root._eventsTrigger
        root._externalTrigger
        return _buildTimeGroups()
    }

    readonly property bool hasEvents: {
        for (const group of root.timeGroups) {
            if (group.events.length > 0) return true
        }
        return false
    }

    function _buildTimeGroups(): var {
        if (!root.selectedDate) return []

        // Merge local + external
        const localEvents = Events.getAllEventsForDate(root.selectedDate).map(e => Object.assign({}, e, {
            source: "local",
            startDate: e.dateTime
        }))
        const externalEvents = CalendarSync.getEventsForDate(root.selectedDate) || []
        const allEvents = localEvents.concat(externalEvents)

        // Categorize by time of day
        const allDay = []
        const morning = []   // 00:00 - 11:59
        const afternoon = [] // 12:00 - 17:59
        const evening = []   // 18:00 - 23:59

        for (const evt of allEvents) {
            if (evt.allDay) {
                allDay.push(evt)
                continue
            }
            const hour = new Date(evt.startDate || evt.dateTime).getHours()
            if (hour < 12) morning.push(evt)
            else if (hour < 18) afternoon.push(evt)
            else evening.push(evt)
        }

        // Sort each group by time
        const sortByTime = (a, b) => new Date(a.startDate || a.dateTime) - new Date(b.startDate || b.dateTime)
        morning.sort(sortByTime)
        afternoon.sort(sortByTime)
        evening.sort(sortByTime)

        const groups = []
        if (allDay.length > 0) groups.push({ label: Translation.tr("All Day"), icon: "wb_sunny", events: allDay })
        if (morning.length > 0) groups.push({ label: Translation.tr("Morning"), icon: "wb_twilight", events: morning })
        if (afternoon.length > 0) groups.push({ label: Translation.tr("Afternoon"), icon: "light_mode", events: afternoon })
        if (evening.length > 0) groups.push({ label: Translation.tr("Evening"), icon: "dark_mode", events: evening })

        return groups
    }

    implicitHeight: detailColumn.implicitHeight
    implicitWidth: parent?.width ?? 200

    ColumnLayout {
        id: detailColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        // Header with back button and date
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Back button
            RippleButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer2Hover
                onClicked: root.backClicked()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 18
                    color: root.colSubtext
                }
            }

            // Date display
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: {
                        if (!root.selectedDate) return ""
                        const now = new Date()
                        const sel = root.selectedDate
                        if (now.toDateString() === sel.toDateString()) return Translation.tr("Today")
                        const tomorrow = new Date(now)
                        tomorrow.setDate(tomorrow.getDate() + 1)
                        if (tomorrow.toDateString() === sel.toDateString()) return Translation.tr("Tomorrow")
                        return root.locale.toString(sel, "dddd")
                    }
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.colText
                }

                StyledText {
                    text: root.selectedDate ? root.locale.toString(root.selectedDate, "d MMMM yyyy") : ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                }
            }

            // Add event button
            RippleButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: ColorUtils.transparentize(root.colPrimary, 0.88)
                colBackgroundHover: ColorUtils.transparentize(root.colPrimary, 0.80)
                onClicked: root.addEventClicked(root.selectedDate)

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "add"
                    iconSize: 18
                    color: root.colPrimary
                }

                StyledToolTip {
                    text: Translation.tr("Add event")
                }
            }
        }

        // Time-grouped event list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            Layout.maximumHeight: 280
            contentHeight: groupsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: groupsColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.timeGroups

                    delegate: ColumnLayout {
                        id: timeGroup
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 2

                        // Time-of-day header
                        RowLayout {
                            Layout.leftMargin: 4
                            Layout.topMargin: index > 0 ? 4 : 0
                            spacing: 6

                            MaterialSymbol {
                                text: timeGroup.modelData.icon
                                iconSize: 14
                                color: root.colSubtext
                                opacity: 0.7
                            }

                            StyledText {
                                text: timeGroup.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                color: root.colSubtext
                                opacity: 0.8
                            }
                        }

                        // Events in this time group
                        Repeater {
                            model: timeGroup.modelData.events

                            delegate: CalendarEventRow {
                                required property var modelData
                                Layout.fillWidth: true
                                event: modelData
                                showDate: false
                                interactive: (modelData?.source ?? "local") === "local"
                                onClicked: root.eventClicked(modelData)
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            visible: !root.hasEvents
            spacing: 8

            MascotImage {
                id: noEventsMascot
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                surface: "calendar"
                fallbackSurface: "emptyStates"
                pose: "calendar-star-mark"
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                visible: !noEventsMascot.active
                text: "event_busy"
                iconSize: 32
                color: root.colSubtext
                opacity: 0.4
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No events on this day")
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colSubtext
                opacity: 0.6
            }

            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: addLabel.implicitWidth + 24
                implicitHeight: 32
                buttonRadius: root.cardRadius
                colBackground: ColorUtils.transparentize(root.colPrimary, 0.88)
                colBackgroundHover: ColorUtils.transparentize(root.colPrimary, 0.80)
                onClicked: root.addEventClicked(root.selectedDate)

                contentItem: StyledText {
                    id: addLabel
                    anchors.centerIn: parent
                    text: Translation.tr("Add event")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: root.colPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
