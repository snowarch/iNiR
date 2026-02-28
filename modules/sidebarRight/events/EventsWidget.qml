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
                color: Appearance.colors.colPrimary
            }
            
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Events & Reminders")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            
            Rectangle {
                visible: Events.getUpcomingEvents(7).length > 0
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: 20
                radius: 10
                color: Appearance.colors.colSecondaryContainer
                
                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: Events.getUpcomingEvents(7).length
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSecondaryContainer
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
                
                // Upcoming events
                Repeater {
                    model: Events.getUpcomingEvents(30)
                    
                    delegate: EventCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.margins: 8
                        event: modelData
                        
                        onRemoveClicked: Events.removeEvent(modelData.id)
                        onEditClicked: (evt) => root.openEventsDialog(evt)
                    }
                }
                
                // Empty state
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    visible: Events.getUpcomingEvents(30).length === 0
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "event_available"
                            iconSize: 48
                            color: Appearance.colors.colSubtext
                            opacity: 0.5
                        }
                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("No upcoming events")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
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
