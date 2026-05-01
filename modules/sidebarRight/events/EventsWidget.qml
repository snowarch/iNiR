pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    // Signal to open external EventsDialog
    signal openEventsDialog(var editEvent)
    
    property int fabSize: 48
    property int fabMargins: 14

    // Style tokens
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colSubtext: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBadgeBg: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.70)
        : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
        : Appearance.colors.colSecondaryContainer
    readonly property color colBadgeText: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
        : Appearance.colors.colOnSecondaryContainer
    readonly property color colEmptyBg: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.85)
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colSubSurface ?? Appearance.colors.colSecondaryContainer)
        : Appearance.colors.colSecondaryContainer
    
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
    
    // Merged events: local + external, sorted by date
    readonly property var mergedEvents: {
        const _t = root._eventsTrigger
        const _t2 = root._externalTrigger
        return _buildMergedEvents()
    }

    function _buildMergedEvents(): var {
        const now = new Date()
        const local = Events.getUpcomingEvents(30).map(e => Object.assign({}, e, {
            _source: "local"
        }))

        // Get external events for the next 30 days, skip past ones
        const startDay = new Date(now)
        startDay.setHours(0, 0, 0, 0)
        const externalAll = []
        for (let i = 0; i < 30; i++) {
            const d = new Date(startDay)
            d.setDate(d.getDate() + i)
            const dayEvents = CalendarSync.getEventsForDate(d) || []
            for (const e of dayEvents) {
                const evtTime = new Date(e.startDate || e.dateTime)
                if (evtTime < now && !(e.allDay && evtTime >= startDay)) continue
                externalAll.push(Object.assign({}, e, {
                    _source: "external",
                    dateTime: e.startDate || e.dateTime,
                    category: "general",
                    priority: "normal"
                }))
            }
        }

        const all = local.concat(externalAll)
        all.sort((a, b) => {
            const da = new Date(a.dateTime || a.startDate)
            const db = new Date(b.dateTime || b.startDate)
            return da - db
        })
        return all
    }

    readonly property int upcomingCount: {
        const _t = root._eventsTrigger
        const _t2 = root._externalTrigger
        return root.mergedEvents.length
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Header with upcoming count
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8
            
            MaterialSymbol {
                text: "event_upcoming"
                iconSize: 20
                fill: 1
                color: root.colPrimary
            }
            
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Events & Reminders")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.colText
            }
            
            Rectangle {
                visible: root.upcomingCount > 0
                implicitWidth: Math.max(20, countText.implicitWidth + 10)
                implicitHeight: 20
                radius: 10
                color: root.colBadgeBg
                
                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: root.upcomingCount
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.family: Appearance.font.family.numbers
                    color: root.colBadgeText
                }
            }
        }
        
        // Events list
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: eventsColumn.implicitHeight
            clip: true
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            
            ColumnLayout {
                id: eventsColumn
                width: parent.width
                spacing: 8
                
                // Merged events
                Repeater {
                    model: root.mergedEvents
                    
                    delegate: EventCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.margins: 8
                        event: modelData
                        isExternal: (modelData?._source ?? "local") === "external"
                        
                        onRemoveClicked: {
                            if (!isExternal) Events.removeEvent(modelData.id)
                        }
                        onEditClicked: (evt) => {
                            if (!isExternal) root.openEventsDialog(evt)
                        }
                    }
                }
                
                // Empty state
                Item {
                    id: emptyState
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    visible: root.mergedEvents.length === 0
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        width: parent.width - 32

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 24
                            color: root.colEmptyBg

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "event_available"
                                iconSize: 24
                                fill: 0
                                color: root.colPrimary

                                SequentialAnimation on opacity {
                                    running: emptyState.visible && Appearance.animationsEnabled
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.5; duration: 2000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("No upcoming events")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: root.colText
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Translation.tr("Tap + to add your first event")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
    
    // FAB to add event
    StyledRectangularShadow {
        target: fabButton
        radius: fabButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }
    
    FloatingActionButton {
        id: fabButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins
        iconText: "add"
        baseSize: root.fabSize
        onClicked: root.openEventsDialog(null)
    }
    
    // Listen for triggered events and show notifications
    Connections {
        target: Events
        
        function onEventTriggered(event) {
            const urgency = event.priority === "high" ? 2 : (event.priority === "low" ? 0 : 1)
            Notifications.notify(
                event.title,
                event.description || Translation.tr("Event is now!"),
                Events.getCategoryIcon(event.category),
                "event-" + event.id,
                event.priority === "high" ? 0 : 10000,
                []
            )
        }
        
        function onReminderTriggered(event, minutesBefore) {
            const reminderText = minutesBefore >= 1440 
                ? Translation.tr("Tomorrow")
                : minutesBefore >= 60 
                    ? Translation.tr("In %1 hour(s)").arg(Math.floor(minutesBefore / 60))
                    : Translation.tr("In %1 minutes").arg(minutesBefore)
            
            Notifications.notify(
                Translation.tr("Upcoming: %1").arg(event.title),
                reminderText + (event.description ? " — " + event.description : ""),
                "alarm",
                "event-reminder-" + event.id,
                8000,
                []
            )
        }
    }
}
