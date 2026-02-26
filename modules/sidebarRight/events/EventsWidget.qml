import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property bool showAddDialog: false
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
                        Layout.fillWidth: true
                        Layout.margins: 8
                        event: modelData
                        
                        onRemoveClicked: Events.removeEvent(modelData.id)
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
        onClicked: root.showAddDialog = true
    }
    
    // Add event dialog
    WindowDialog {
        show: root.showAddDialog
        backgroundHeight: 500
        onDismiss: root.showAddDialog = false
        
        property string eventTitle: ""
        property string eventDescription: ""
        property date eventDate: new Date()
        property int eventHour: 12
        property int eventMinute: 0
        property string eventCategory: "general"
        property string eventPriority: "normal"
        
        WindowDialogTitle {
            text: Translation.tr("New Event")
        }
        
        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Event title")
            text: parent.eventTitle
            onTextChanged: parent.eventTitle = text
        }
        
        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Description (optional)")
            text: parent.eventDescription
            onTextChanged: parent.eventDescription = text
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText {
                text: Translation.tr("Date:")
                font.pixelSize: Appearance.font.pixelSize.small
            }
            
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 36
                colBackground: Appearance.colors.colLayer1
                
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Qt.formatDate(parent.parent.parent.eventDate, "dd/MM/yyyy")
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText {
                text: Translation.tr("Time:")
                font.pixelSize: Appearance.font.pixelSize.small
            }
            
            SpinBox {
                from: 0
                to: 23
                value: parent.parent.eventHour
                onValueChanged: parent.parent.eventHour = value
            }
            
            StyledText {
                text: ":"
            }
            
            SpinBox {
                from: 0
                to: 59
                value: parent.parent.eventMinute
                onValueChanged: parent.parent.eventMinute = value
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText {
                text: Translation.tr("Category:")
                font.pixelSize: Appearance.font.pixelSize.small
            }
            
            StyledComboBox {
                Layout.fillWidth: true
                model: [
                    { value: "general", text: Translation.tr("General") },
                    { value: "birthday", text: Translation.tr("Birthday") },
                    { value: "meeting", text: Translation.tr("Meeting") },
                    { value: "deadline", text: Translation.tr("Deadline") },
                    { value: "reminder", text: Translation.tr("Reminder") }
                ]
                textRole: "text"
                valueRole: "value"
                onCurrentValueChanged: parent.parent.eventCategory = currentValue
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText {
                text: Translation.tr("Priority:")
                font.pixelSize: Appearance.font.pixelSize.small
            }
            
            ButtonGroup {
                spacing: 4
                
                SelectionGroupButton {
                    buttonText: Translation.tr("Low")
                    selected: parent.parent.parent.eventPriority === "low"
                    onClicked: parent.parent.parent.eventPriority = "low"
                }
                
                SelectionGroupButton {
                    buttonText: Translation.tr("Normal")
                    selected: parent.parent.parent.eventPriority === "normal"
                    onClicked: parent.parent.parent.eventPriority = "normal"
                }
                
                SelectionGroupButton {
                    buttonText: Translation.tr("High")
                    selected: parent.parent.parent.eventPriority === "high"
                    onClicked: parent.parent.parent.eventPriority = "high"
                }
            }
        }
        
        WindowDialogSeparator {}
        
        WindowDialogButtonRow {
            Item { Layout.fillWidth: true }
            
            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: root.showAddDialog = false
            }
            
            DialogButton {
                buttonText: Translation.tr("Add")
                onClicked: {
                    if (parent.parent.eventTitle.trim() !== "") {
                        const dateTime = new Date(parent.parent.eventDate)
                        dateTime.setHours(parent.parent.eventHour, parent.parent.eventMinute, 0, 0)
                        
                        Events.addEvent(
                            parent.parent.eventTitle,
                            parent.parent.eventDescription,
                            dateTime.toISOString(),
                            parent.parent.eventCategory,
                            parent.parent.eventPriority
                        )
                        
                        root.showAddDialog = false
                    }
                }
            }
        }
    }
    
    // Listen for triggered events and show notifications
    Connections {
        target: Events
        
        function onEventTriggered(event) {
            Notifications.notify(
                event.title,
                event.description || Translation.tr("Event reminder"),
                Events.getCategoryIcon(event.category),
                "event-" + event.id,
                5000,
                []
            )
        }
    }
}
