pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    property var editingEvent: null
    property bool isEditing: editingEvent !== null

    // Form state
    property string eventTitle: ""
    property string eventDescription: ""
    property date eventDate: new Date()
    property string eventTime: "12:00"
    property string eventCategory: "general"
    property string eventPriority: "normal"
    property int reminderMinutes: 15
    property string recurrence: "none"

    function resetForm(): void {
        root.editingEvent = null
        root.eventTitle = ""
        root.eventDescription = ""
        root.eventDate = new Date()
        root.eventTime = "12:00"
        root.eventCategory = "general"
        root.eventPriority = "normal"
        root.reminderMinutes = 15
        root.recurrence = "none"
    }

    function loadEvent(event: var): void {
        root.editingEvent = event
        root.eventTitle = event.title || ""
        root.eventDescription = event.description || ""
        const dt = new Date(event.dateTime)
        root.eventDate = dt
        root.eventTime = dt.getHours().toString().padStart(2, '0') + ":" + dt.getMinutes().toString().padStart(2, '0')
        root.eventCategory = event.category || "general"
        root.eventPriority = event.priority || "normal"
        root.reminderMinutes = event.reminderMinutes ?? 15
        root.recurrence = event.recurrence || "none"
    }

    function saveEvent(): bool {
        if (root.eventTitle.trim() === "") return false

        const timeParts = root.eventTime.split(":")
        const hour = parseInt(timeParts[0]) || 0
        const minute = parseInt(timeParts[1]) || 0

        const dateTime = new Date(root.eventDate)
        dateTime.setHours(hour, minute, 0, 0)

        if (root.isEditing) {
            Events.updateEvent(root.editingEvent.id, {
                title: root.eventTitle.trim(),
                description: root.eventDescription.trim(),
                dateTime: dateTime.toISOString(),
                category: root.eventCategory,
                priority: root.eventPriority,
                reminderMinutes: root.reminderMinutes,
                recurrence: root.recurrence,
                notified: false
            })
        } else {
            Events.addEvent(
                root.eventTitle.trim(),
                root.eventDescription.trim(),
                dateTime.toISOString(),
                root.eventCategory,
                root.eventPriority,
                root.reminderMinutes,
                root.recurrence
            )
        }
        return true
    }

    WindowDialogTitle {
        text: root.isEditing ? Translation.tr("Edit Event") : Translation.tr("New Event")
    }

    WindowDialogSeparator {}

    // Scrollable content
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true

        contentHeight: formColumn.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: formColumn
            width: parent.width
            spacing: 4

            // ─── Basic Info Section ───────────────────────────────────
            WindowDialogSectionHeader {
                text: Translation.tr("Basic Info")
            }

            WindowDialogSeparator {
                Layout.topMargin: -22
            }

            Column {
                width: parent.width
                spacing: 8
                topPadding: 8

                MaterialTextField {
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    placeholderText: Translation.tr("Event title") + " *"
                    text: root.eventTitle
                    onTextChanged: root.eventTitle = text
                }

                MaterialTextField {
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    placeholderText: Translation.tr("Description (optional)")
                    text: root.eventDescription
                    onTextChanged: root.eventDescription = text
                }
            }

            // ─── Date & Time Section ──────────────────────────────────
            WindowDialogSectionHeader {
                text: Translation.tr("Date & Time")
                topPadding: 16
            }

            WindowDialogSeparator {
                Layout.topMargin: -22
            }

            Column {
                width: parent.width
                spacing: 0

                // Date picker
                DatePicker {
                    width: parent.width
                    selectedDate: root.eventDate
                    onDateSelected: (date) => { root.eventDate = date }
                }

                // Time input using ConfigTimeInput pattern
                ConfigTimeInput {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    icon: "schedule"
                    text: Translation.tr("Time")
                    value: root.eventTime
                    onTimeChanged: (newTime) => { root.eventTime = newTime }
                }
            }

            // ─── Category Section ─────────────────────────────────────
            WindowDialogSectionHeader {
                text: Translation.tr("Category")
                topPadding: 16
            }

            WindowDialogSeparator {
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("General"), icon: "event", value: "general" },
                    { displayName: Translation.tr("Birthday"), icon: "cake", value: "birthday" },
                    { displayName: Translation.tr("Meeting"), icon: "groups", value: "meeting" },
                    { displayName: Translation.tr("Deadline"), icon: "flag", value: "deadline" },
                    { displayName: Translation.tr("Reminder"), icon: "notifications", value: "reminder" }
                ]
                currentValue: root.eventCategory
                onSelected: (newValue) => { root.eventCategory = newValue }
            }

            // ─── Priority Section ─────────────────────────────────────
            WindowDialogSectionHeader {
                text: Translation.tr("Priority")
                topPadding: 16
            }

            WindowDialogSeparator {
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("Low"), icon: "arrow_downward", value: "low" },
                    { displayName: Translation.tr("Normal"), icon: "remove", value: "normal" },
                    { displayName: Translation.tr("High"), icon: "priority_high", value: "high" }
                ]
                currentValue: root.eventPriority
                onSelected: (newValue) => { root.eventPriority = newValue }
            }

            // ─── Reminder Section ─────────────────────────────────────
            WindowDialogSectionHeader {
                text: Translation.tr("Reminder")
                topPadding: 16
            }

            WindowDialogSeparator {
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("None"), icon: "notifications_off", value: 0 },
                    { displayName: Translation.tr("5 min"), icon: "alarm", value: 5 },
                    { displayName: Translation.tr("15 min"), icon: "alarm", value: 15 },
                    { displayName: Translation.tr("1 hour"), icon: "alarm", value: 60 },
                    { displayName: Translation.tr("1 day"), icon: "alarm", value: 1440 }
                ]
                currentValue: root.reminderMinutes
                onSelected: (newValue) => { root.reminderMinutes = newValue }
            }

            // ─── Repeat Section ───────────────────────────────────────
            WindowDialogSectionHeader {
                text: Translation.tr("Repeat")
                topPadding: 16
            }

            WindowDialogSeparator {
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("Never"), icon: "block", value: "none" },
                    { displayName: Translation.tr("Daily"), icon: "today", value: "daily" },
                    { displayName: Translation.tr("Weekly"), icon: "date_range", value: "weekly" },
                    { displayName: Translation.tr("Monthly"), icon: "calendar_month", value: "monthly" },
                    { displayName: Translation.tr("Yearly"), icon: "event_repeat", value: "yearly" }
                ]
                currentValue: root.recurrence
                onSelected: (newValue) => { root.recurrence = newValue }
            }

            // Bottom padding
            Item { width: 1; height: 16 }
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            visible: root.isEditing
            buttonText: Translation.tr("Delete")
            onClicked: {
                Events.removeEvent(root.editingEvent.id)
                root.resetForm()
                root.dismiss()
            }
        }

        Item { Layout.fillWidth: true }

        DialogButton {
            buttonText: Translation.tr("Cancel")
            onClicked: {
                root.resetForm()
                root.dismiss()
            }
        }

        DialogButton {
            buttonText: root.isEditing ? Translation.tr("Save") : Translation.tr("Add Event")
            enabled: root.eventTitle.trim() !== ""
            onClicked: {
                if (root.saveEvent()) {
                    root.resetForm()
                    root.dismiss()
                }
            }
        }
    }
}
