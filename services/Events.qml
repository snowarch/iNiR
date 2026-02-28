pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string filePath: `${Directories.state}/user/events.json`
    property var list: []
    property int nextId: 1
    
    signal eventAdded(var event)
    signal eventRemoved(int id)
    signal eventUpdated(var event)
    signal eventTriggered(var event)

    Component.onCompleted: {
        loadFromFile()
        checkTimer.start()
    }

    FileView {
        id: eventsFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onLoaded: {
            const fileContents = eventsFileView.text()
            if (!fileContents || fileContents.trim() === "") {
                root.list = []
                root.nextId = 1
                return
            }
            try {
                const data = JSON.parse(fileContents)
                root.list = data.events || []
                root.nextId = data.nextId || 1
                console.log("[Events] Loaded", root.list.length, "events")
            } catch (e) {
                console.warn("[Events] Failed to parse file:", e)
                root.list = []
                root.nextId = 1
            }
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                console.log("[Events] File not found, creating new file.")
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'))
                Quickshell.execDetached(["/usr/bin/mkdir", "-p", parentDir])
                root.list = []
                root.nextId = 1
                root.saveToFile()
            } else {
                console.log("[Events] Error loading file:", error)
                root.list = []
                root.nextId = 1
            }
        }
    }

    // Check for due events every minute
    Timer {
        id: checkTimer
        interval: 60000 // 1 minute
        running: false
        repeat: true
        onTriggered: root.checkDueEvents()
    }

    signal reminderTriggered(var event, int minutesBefore)

    function checkDueEvents() {
        const now = new Date()
        const currentTime = now.getTime()
        let needsSave = false
        
        for (let i = 0; i < root.list.length; i++) {
            const event = root.list[i]
            if (!event.dateTime) continue
            
            const eventTime = new Date(event.dateTime).getTime()
            const reminderMinutes = event.reminderMinutes ?? 0
            const reminderTime = eventTime - (reminderMinutes * 60 * 1000)
            
            // Check for reminder notification (before event)
            if (reminderMinutes > 0 && !event.reminderNotified && currentTime >= reminderTime && currentTime < eventTime) {
                root.list[i].reminderNotified = true
                root.reminderTriggered(event, reminderMinutes)
                needsSave = true
            }
            
            // Check for event time notification
            if (!event.notified && currentTime >= eventTime) {
                root.list[i].notified = true
                root.eventTriggered(event)
                needsSave = true
                
                // Handle recurrence - create next occurrence
                if (event.recurrence && event.recurrence !== "none") {
                    root.createNextRecurrence(event)
                }
            }
        }
        
        if (needsSave) root.saveToFile()
    }

    function createNextRecurrence(event) {
        const eventDate = new Date(event.dateTime)
        let nextDate = new Date(eventDate)
        
        switch (event.recurrence) {
            case "daily":
                nextDate.setDate(nextDate.getDate() + 1)
                break
            case "weekly":
                nextDate.setDate(nextDate.getDate() + 7)
                break
            case "monthly":
                nextDate.setMonth(nextDate.getMonth() + 1)
                break
            case "yearly":
                nextDate.setFullYear(nextDate.getFullYear() + 1)
                break
            default:
                return
        }
        
        // Create recurring event
        root.addEvent(
            event.title,
            event.description,
            nextDate.toISOString(),
            event.category,
            event.priority,
            event.reminderMinutes,
            event.recurrence
        )
    }

    function addEvent(title, description, dateTime, category, priority, reminderMinutes, recurrence) {
        const event = {
            id: root.nextId++,
            title: title || "",
            description: description || "",
            dateTime: dateTime || new Date().toISOString(),
            category: category || "general", // general, birthday, meeting, deadline, reminder
            priority: priority || "normal", // low, normal, high
            reminderMinutes: reminderMinutes ?? 15, // 0, 5, 15, 30, 60, 1440
            recurrence: recurrence || "none", // none, daily, weekly, monthly, yearly
            notified: false,
            reminderNotified: false,
            createdAt: new Date().toISOString()
        }
        
        root.list.push(event)
        root.list = root.list // Trigger binding update
        root.eventAdded(event)
        root.saveToFile()
        return event
    }

    function removeEvent(id) {
        const index = root.list.findIndex(e => e.id === id)
        if (index !== -1) {
            root.list.splice(index, 1)
            root.list = root.list
            root.eventRemoved(id)
            root.saveToFile()
            return true
        }
        return false
    }

    function updateEvent(id, updates) {
        const index = root.list.findIndex(e => e.id === id)
        if (index !== -1) {
            root.list[index] = Object.assign({}, root.list[index], updates)
            root.list = root.list
            root.eventUpdated(root.list[index])
            root.saveToFile()
            return true
        }
        return false
    }

    function getEventsForDate(date) {
        const targetDate = new Date(date)
        targetDate.setHours(0, 0, 0, 0)
        
        return root.list.filter(event => {
            const eventDate = new Date(event.dateTime)
            eventDate.setHours(0, 0, 0, 0)
            // Only show non-notified events (upcoming or future)
            return eventDate.getTime() === targetDate.getTime() && !event.notified
        })
    }
    
    // Get ALL events for a date (including notified/past) - for history view
    function getAllEventsForDate(date) {
        const targetDate = new Date(date)
        targetDate.setHours(0, 0, 0, 0)
        
        return root.list.filter(event => {
            const eventDate = new Date(event.dateTime)
            eventDate.setHours(0, 0, 0, 0)
            return eventDate.getTime() === targetDate.getTime()
        })
    }

    function getUpcomingEvents(days) {
        const now = new Date()
        const future = new Date()
        future.setDate(future.getDate() + (days || 7))
        
        return root.list.filter(event => {
            const eventDate = new Date(event.dateTime)
            return eventDate >= now && eventDate <= future && !event.notified
        }).sort((a, b) => new Date(a.dateTime) - new Date(b.dateTime))
    }

    function markAsNotified(id) {
        return root.updateEvent(id, { notified: true })
    }

    function saveToFile() {
        const data = {
            nextId: root.nextId,
            events: root.list
        }
        eventsFileView.setText(JSON.stringify(data, null, 2))
    }

    function loadFromFile() {
        eventsFileView.reload()
    }

    function getCategoryIcon(category) {
        switch (category) {
            case "birthday": return "cake"
            case "meeting": return "groups"
            case "deadline": return "flag"
            case "reminder": return "notifications"
            default: return "event"
        }
    }

    function getPriorityColor(priority) {
        switch (priority) {
            case "high": return "#ef4444"
            case "low": return "#6b7280"
            default: return "#3b82f6"
        }
    }
}
