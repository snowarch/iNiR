pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.background.widgets
import qs.modules.background.widgets.clock
import qs.modules.background.widgets.mediaControls
import qs.modules.background.widgets.weather
import qs.modules.background.widgets.systemMonitor
import qs.modules.background.widgets.battery
import qs.modules.background.widgets.notes
import qs.modules.background.widgets.calendar
import qs.modules.background.widgets.todo
import qs.modules.background.widgets.timers
import qs.modules.background.widgets.dateBadge
import qs.modules.background.widgets.uptime
import qs.modules.background.widgets.controls
import qs.modules.background.widgets.screenTime
import qs.modules.background.widgets.dayProgress
import qs.modules.background.widgets.worldClock
import qs.modules.background.widgets.userCard
import qs.modules.background.widgets.newsTicker
import qs.modules.iris.widgets
import qs.modules.iris.style

Item {
    id: root

    property string screenName: ""
    readonly property string scope: DesktopWidgetLayout.lockScope(root.screenName)
    readonly property var shown: {
        Config.revision
        if (root.screenName.length === 0) return []
        return IrisFaceData.galleryEntries.map(entry => entry.key)
            .filter(key => DesktopWidgetLayout.enabled(root.scope, key, false))
    }

    // While the lock is being designed, a tapped widget becomes the selection ("widget:<key>") and the
    // inspector opens its own Look on this scope, so the lock keeps shapes and materials of its own.
    readonly property string selectedKey: GlobalStates.irisLockEdit && GlobalStates.irisLockSelection.startsWith("widget:")
        ? GlobalStates.irisLockSelection.slice(7) : ""
    readonly property var selectedItem: root.selectedKey.length > 0 ? root.item(root.selectedKey) : null
    function showTab(): void {
        if (root.selectedItem && GlobalStates.irisLockWidgetTab.length > 0) root.selectedItem._quickTab = GlobalStates.irisLockWidgetTab
    }
    onSelectedItemChanged: root.showTab()
    Connections {
        target: GlobalStates
        function onIrisLockWidgetTabChanged(): void { root.showTab() }
    }
    function item(key: string): var {
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i)
            if (slot?.modelData === key) return slot.item ?? null
        }
        return null
    }

    Rectangle {
        readonly property real d: IrisStyle.density
        readonly property real pad: Math.round(8 * d)
        visible: root.selectedItem !== null
        z: 1
        x: (root.selectedItem?.x ?? 0) - pad
        y: (root.selectedItem?.y ?? 0) - pad
        width: (root.selectedItem?.width ?? 0) + pad * 2
        height: (root.selectedItem?.height ?? 0) + pad * 2
        radius: IrisStyle.radiusPlate
        color: "transparent"
        border.width: Math.max(1, Math.round(1.5 * d))
        border.color: IrisStyle.accentOnMedia
    }

    Repeater {
        id: slots
        model: IrisFaceData.galleryEntries.map(entry => entry.key)
        delegate: Loader {
            id: slot
            required property string modelData
            active: root.shown.includes(slot.modelData)
            Connections {
                target: slot.item
                enabled: GlobalStates.irisLockEdit
                function onPressed(): void { GlobalStates.irisLockSelection = "widget:" + slot.modelData }
            }
            sourceComponent: ({
                clock: clockWidget, weather: weatherWidget, mediaControls: mediaWidget, controls: controlsWidget,
                monthCalendar: monthWidget, calendarUpcoming: upcomingWidget, todo: todoWidget, notes: notesWidget,
                timers: timersWidget, screenTime: screenTimeWidget, systemMonitor: vitalsWidget, battery: batteryWidget,
                worldClock: worldClockWidget, dayProgress: dayWidget, dateBadge: dateWidget, userCard: profileWidget,
                uptime: uptimeWidget, newsTicker: newsWidget
            })[slot.modelData] ?? null
        }
    }

    Component { id: clockWidget; ClockWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: weatherWidget; WeatherWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: mediaWidget; MediaControlsWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: controlsWidget; ControlsWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: monthWidget; MonthCalendarWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: upcomingWidget; CalendarUpcomingWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: todoWidget; TodoWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: notesWidget; NotesWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: timersWidget; TimerWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: screenTimeWidget; ScreenTimeWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: vitalsWidget; SystemMonitorWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: batteryWidget; BatteryWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: worldClockWidget; WorldClockWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: dayWidget; DayProgressWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: dateWidget; DateBadgeWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: profileWidget; UserCardWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: uptimeWidget; UptimeWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
    Component { id: newsWidget; NewsTickerWidget { visibleWhenLocked: true; outputName: root.scope; screenWidth: root.width; screenHeight: root.height; scaledScreenWidth: root.width; scaledScreenHeight: root.height; wallpaperScale: 1 } }
}
