pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.services

Singleton {
    id: root

    readonly property bool enabled: Config.options?.sidebar?.screenTime?.enable ?? false
    property bool ready: false

    property var _todayData: null
    property string _currentAppId: ""
    property string _currentAppName: ""
    property string _sessionAppId: ""
    property int _currentSessionSeconds: 0
    property int _sessionRevision: 0
    property real _idleStartedAt: 0
    property real _lastReturnAt: 0
    property int _lastIdleDurationSeconds: 0
    property real _lastTickTime: 0
    property real _lastPersistMs: 0
    readonly property int _persistIntervalMs: 30000
    property string _currentDate: ""
    property bool _dirty: false
    property bool _initialized: false
    property bool _loadingToday: false
    property var _rangeHistoryData: ({})
    property var _rangeQueue: []
    property int _activeRangeDays: 0
    property int _rangeGeneration: 0
    readonly property int _idleTimeoutSeconds: {
        const override = parseInt(Quickshell.env("INIR_SCREENTIME_IDLE_TIMEOUT_SECONDS") || "")
        return override > 0 ? override : 300
    }
    readonly property bool userIdle: idleMonitor.isIdle

    readonly property var todayData: _todayData
    readonly property string currentAppId: _currentAppId
    readonly property string currentAppName: _currentAppName
    readonly property int currentSessionSeconds: _currentSessionSeconds
    readonly property int sessionRevision: _sessionRevision
    readonly property real lastReturnAt: _lastReturnAt
    readonly property int lastIdleDurationSeconds: _lastIdleDurationSeconds

    signal dataChanged()
    signal rangeLoaded(int days, var data)

    Component.onCompleted: root._syncEnabledState()
    onEnabledChanged: root._syncEnabledState()

    function _syncEnabledState(): void {
        if (!root.enabled) {
            if (root._dirty) {
                root._persistToday()
                root._dirty = false
                root._lastPersistMs = Date.now()
            }
            root._sessionAppId = ""
            root._currentSessionSeconds = 0
            root._sessionRevision++
            root.ready = true
            return
        }

        const today = root._dateString(new Date())
        if (!root._initialized || root._currentDate !== today) {
            if (root._dirty)
                root._persistToday()
            root.ready = false
            root._currentDate = today
            root._loadTodayFromFile()
            return
        }
        root.ready = true
    }

    function _loadTodayFromFile(): void {
        if (root._loadingToday || startupReadProc.running)
            return
        root._loadingToday = true
        const path = root._todayFilePath()
        startupReadProc.command = ["/usr/bin/bash", "-c", `test -f "${path}" && cat "${path}" || echo "__NOFILE__"`]
        startupReadProc.running = true
    }

    IdleMonitor {
        id: idleMonitor
        enabled: root.enabled
        timeout: root._idleTimeoutSeconds
        respectInhibitors: false
        onIsIdleChanged: {
            const now = Date.now()
            root._lastTickTime = now
            root._sessionAppId = ""
            root._currentSessionSeconds = 0
            root._sessionRevision++
            if (idleMonitor.isIdle) {
                // ext-idle-notify fires after the timeout, so reconstruct the
                // beginning of the idle period for a useful break duration.
                root._idleStartedAt = now - root._idleTimeoutSeconds * 1000
            } else if (root._idleStartedAt > 0) {
                root._lastIdleDurationSeconds = Math.max(0,
                    Math.round((now - root._idleStartedAt) / 1000))
                root._lastReturnAt = now
                root._idleStartedAt = 0
            }
            root.dataChanged()
        }
    }

    Timer {
        id: pollTimer
        interval: (Config.options?.sidebar?.screenTime?.pollIntervalSeconds ?? 5) * 1000
        running: root.enabled && root.ready && root._initialized
        repeat: true
        triggeredOnStart: true
        onTriggered: root._tick()
    }

    Timer {
        id: dayRolloverTimer
        interval: 60000
        running: root.enabled && root.ready && root._initialized
        repeat: true
        onTriggered: {
            const now = root._dateString(new Date())
            if (now !== root._currentDate) {
                root._persistToday()
                root._currentDate = now
                root._todayData = root._emptyDay(now)
                root._currentAppId = ""
                root._currentAppName = ""
                root._sessionAppId = ""
                root._currentSessionSeconds = 0
                root._sessionRevision++
                root._lastTickTime = Date.now()
                root._lastPersistMs = Date.now()
                root._rangeGeneration++
                root._rangeHistoryData = ({})
                root._rangeQueue = []
                root._pruneHistory()
                root.dataChanged()
            }
        }
    }

    function _tick(): void {
        if (!root.enabled) return

        const now = Date.now()
        let appId = ""
        let appName = ""

        if (CompositorService.isNiri) {
            // The initial WindowsChanged snapshot already marks the focused
            // window, but NiriService.activeWindow is event-driven and can stay
            // null until the next focus change. Use the reactive list as the
            // startup fallback without spawning a compositor query per tick.
            const win = NiriService.activeWindow
                ?? (NiriService.windows ?? []).find(w => w.is_focused)
            if (win) {
                appId = win.app_id || ""
                appName = appId ? _humanizeAppId(appId) : ""
            }
        } else if (CompositorService.isHyprland) {
            const wins = HyprlandData.windowList || []
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].focusHistoryID === 0) {
                    appId = wins[i].class || ""
                    appName = appId ? _humanizeAppId(appId) : ""
                    break
                }
            }
        }

        const elapsed = root._lastTickTime > 0
            ? Math.round((now - root._lastTickTime) / 1000)
            : 0
        const intervalStart = root._lastTickTime
        root._lastTickTime = now

        if (root.userIdle) {
            root._currentAppId = appId
            root._currentAppName = appName
            return
        }

        if (appId !== root._sessionAppId) {
            root._sessionAppId = appId
            root._currentSessionSeconds = 0
            root._sessionRevision++
        }

        if (elapsed <= 0 || elapsed > 60) {
            root._currentAppId = appId
            root._currentAppName = appName
            return
        }

        if (!root._todayData)
            root._todayData = _emptyDay(root._currentDate)

        if (appId.length > 0) {
            root._currentSessionSeconds += elapsed
            root._todayData.totalSeconds += elapsed

            const key = appId.toLowerCase().replace(/[^a-z0-9-]/g, "")
            if (!root._todayData.apps[key])
                root._todayData.apps[key] = { name: appName, seconds: 0, originalId: appId, hourly: new Array(24).fill(0) }
            const appEntry = root._todayData.apps[key]
            if (!appEntry.originalId)
                appEntry.originalId = appId
            if (!appEntry.hourly || appEntry.hourly.length !== 24)
                appEntry.hourly = new Array(24).fill(0)
            appEntry.seconds += elapsed

            // Attribute time to the hour(s) the interval actually spanned, so a
            // tick that crosses an hour boundary splits correctly instead of
            // dumping everything into the tick's hour.
            const perHour = _distributeElapsed(intervalStart, now)
            for (const h in perHour) {
                const secs = perHour[h]
                root._todayData.hourly[h] = (root._todayData.hourly[h] || 0) + secs
                appEntry.hourly[h] = (appEntry.hourly[h] || 0) + secs
            }

            root._dirty = true
        }

        root._currentAppId = appId
        root._currentAppName = appName
        root._todayData = Object.assign({}, root._todayData)
        root.dataChanged()

        // Flush by elapsed wall-clock since the last persist, not a fragile
        // modulo on the running total (which could skip or double-write).
        if (root._dirty && (now - root._lastPersistMs) >= root._persistIntervalMs) {
            root._persistToday()
            root._dirty = false
            root._lastPersistMs = now
        }
    }

    // Split an interval [startMs, endMs] into per-hour-of-day seconds.
    // Returns an object { hourIndex: seconds }. Handles the interval crossing
    // one or more hour boundaries (clamped to a single day's worth of buckets).
    function _distributeElapsed(startMs: real, endMs: real): var {
        const result = ({})
        if (!(startMs > 0) || endMs <= startMs)
            return result
        let cursor = startMs
        // Safety cap: never iterate more than 25 boundaries (>1 day shouldn't
        // happen because elapsed>60 is already rejected upstream).
        let guard = 0
        while (cursor < endMs && guard < 26) {
            const d = new Date(cursor)
            const hour = d.getHours()
            // Milliseconds until the next hour boundary
            const next = new Date(cursor)
            next.setMinutes(60, 0, 0)
            const boundary = Math.min(next.getTime(), endMs)
            const secs = Math.round((boundary - cursor) / 1000)
            if (secs > 0)
                result[hour] = (result[hour] || 0) + secs
            cursor = boundary
            guard++
        }
        return result
    }

    function getToday(): var {
        return root._todayData || _emptyDay(root._currentDate)
    }

    function requestDays(count: int): void {
        if (count <= 1) {
            root.rangeLoaded(1, root.getToday())
            return
        }
        const cached = root.getCachedDays(count)
        if (cached) {
            root.rangeLoaded(count, cached)
            return
        }
        if (root._activeRangeDays === count || root._rangeQueue.indexOf(count) !== -1)
            return
        root._rangeQueue = root._rangeQueue.concat([count])
        root._startNextRangeRead()
    }

    function _startNextRangeRead(): void {
        if (rangeReadProc.running || root._activeRangeDays > 0 || root._rangeQueue.length === 0)
            return
        const queue = root._rangeQueue.slice()
        const count = queue.shift()
        root._rangeQueue = queue

        let script = ""
        const now = new Date()
        for (let i = 1; i < count; i++) {
            const d = new Date(now)
            d.setDate(d.getDate() - i)
            const path = `${Directories.screenTimePath}/${root._dateString(d)}.json`
            script += `cat "${path}" 2>/dev/null || echo "{}"; echo "---DELIM---";\n`
        }
        root._activeRangeDays = count
        rangeReadProc._requestedDays = count
        rangeReadProc._generation = root._rangeGeneration
        rangeReadProc.command = ["/usr/bin/bash", "-c", script]
        rangeReadProc.running = true
    }

    function getCachedDays(count: int): var {
        const history = root._rangeHistoryData[count]
        return history === undefined
            ? null : root._mergeHistoricalData(root.getToday(), history)
    }

    function getAppList(days: int): var {
        const data = days <= 1 ? root.getToday() : (root.getCachedDays(days) || root.getToday())
        const apps = data.apps || {}
        const list = []
        const keys = Object.keys(apps)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            list.push({ id: key, name: apps[key].name || key, seconds: apps[key].seconds || 0, originalId: apps[key].originalId || key })
        }
        list.sort((a, b) => b.seconds - a.seconds)
        return list
    }

    function formatDuration(totalSeconds: int): string {
        if (totalSeconds < 60) return totalSeconds + "s"
        const hours = Math.floor(totalSeconds / 3600)
        const mins = Math.floor((totalSeconds % 3600) / 60)
        if (hours > 0) return hours + "h " + mins + "m"
        return mins + "m"
    }

    function _emptyDay(dateStr: string): var {
        return { date: dateStr, totalSeconds: 0, hourly: new Array(24).fill(0), apps: {} }
    }

    function _humanizeAppId(id: string): string {
        const parts = id.split(".")
        const name = parts.length > 1 ? parts[parts.length - 1] : id
        return name.replace(/[-_]/g, " ").replace(/\b\w/g, function(c) { return c.toUpperCase() }).trim()
    }

    function _dateString(d: var): string {
        const y = d.getFullYear()
        const m = String(d.getMonth() + 1).padStart(2, "0")
        const day = String(d.getDate()).padStart(2, "0")
        return `${y}-${m}-${day}`
    }

    function _todayFilePath(): string {
        return `${Directories.screenTimePath}/${root._currentDate}.json`
    }

    function _persistToday(): void {
        if (!root._todayData || root._currentDate.length === 0) return
        const url = Qt.resolvedUrl(root._todayFilePath())
        if (todayFileView.path !== url)
            todayFileView.path = url
        todayFileView.setText(JSON.stringify(root._todayData, null, 2))
    }

    function _pruneHistory(): void {
        const retention = Math.max(1,
            Config.options?.sidebar?.screenTime?.retentionDays ?? 30)
        Quickshell.execDetached([
            "/usr/bin/find", Directories.screenTimePath,
            "-maxdepth", "1", "-type", "f", "-name", "*.json",
            "-mtime", `+${retention}`, "-delete"
        ])
    }

    function _mergeDays(todayData: var, rawText: string): var {
        const result = {
            totalSeconds: todayData.totalSeconds || 0,
            hourly: (todayData.hourly || []).slice(),
            apps: {}
        }
        if (!result.hourly.length) result.hourly = new Array(24).fill(0)

        const todayApps = todayData.apps || {}
        const todayKeys = Object.keys(todayApps)
        for (let i = 0; i < todayKeys.length; i++) {
            const key = todayKeys[i]
            result.apps[key] = {
                name: todayApps[key].name,
                seconds: todayApps[key].seconds,
                originalId: todayApps[key].originalId || key,
                hourly: (todayApps[key].hourly && todayApps[key].hourly.length === 24)
                    ? todayApps[key].hourly.slice() : new Array(24).fill(0)
            }
        }

        const sections = rawText.split("---DELIM---").filter(s => s.trim().length > 0 && s.trim() !== "{}")
        for (let i = 0; i < sections.length; i++) {
            try {
                const dayData = JSON.parse(sections[i].trim())
                if (!dayData || !dayData.totalSeconds) continue
                result.totalSeconds += dayData.totalSeconds || 0
                if (dayData.hourly) {
                    for (let h = 0; h < 24; h++)
                        result.hourly[h] = (result.hourly[h] || 0) + (dayData.hourly[h] || 0)
                }
                if (dayData.apps) {
                    const keys = Object.keys(dayData.apps)
                    for (let k = 0; k < keys.length; k++) {
                        const key = keys[k]
                        if (!result.apps[key]) {
                            const histOriginalId = dayData.apps[key].originalId
                                || (AppSearch.lookupDesktopEntry(dayData.apps[key].name || key)?.id ?? "").replace(/\.desktop$/, "")
                                || key
                            result.apps[key] = { name: dayData.apps[key].name || key, seconds: 0, originalId: histOriginalId, hourly: new Array(24).fill(0) }
                        }
                        result.apps[key].seconds += dayData.apps[key].seconds || 0
                        // Per-app hourly only exists in newer day files; older
                        // files contribute to seconds but leave hourly at 0.
                        const dh = dayData.apps[key].hourly
                        if (dh && dh.length === 24) {
                            for (let h = 0; h < 24; h++)
                                result.apps[key].hourly[h] += (dh[h] || 0)
                        }
                    }
                }
            } catch (e) {}
        }
        return result
    }

    function _mergeHistoricalData(todayData: var, historyData: var): var {
        const result = root._mergeDays(todayData, "")
        if (!historyData)
            return result

        result.totalSeconds += historyData.totalSeconds || 0
        const historyHourly = historyData.hourly || []
        for (let h = 0; h < 24; h++)
            result.hourly[h] = (result.hourly[h] || 0) + (historyHourly[h] || 0)

        const historyApps = historyData.apps || {}
        const keys = Object.keys(historyApps)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            const source = historyApps[key]
            if (!result.apps[key]) {
                result.apps[key] = {
                    name: source.name || key,
                    seconds: 0,
                    originalId: source.originalId || key,
                    hourly: new Array(24).fill(0)
                }
            }
            const target = result.apps[key]
            target.seconds += source.seconds || 0
            const sourceHourly = source.hourly || []
            for (let h = 0; h < 24; h++)
                target.hourly[h] = (target.hourly[h] || 0) + (sourceHourly[h] || 0)
        }
        return result
    }

    // Per-app breakdown for a given hour-of-day over the selected range.
    // Returns apps sorted desc by seconds in that hour: [{id,name,seconds,originalId}].
    // Days whose files predate per-app hourly data simply contribute nothing
    // here (the UI shows a "no detail" hint when the hour has time but no rows).
    function getHourBreakdown(hour: int, days: int): var {
        const data = days <= 1 ? root.getToday() : (root.getCachedDays(days) || root.getToday())
        const apps = data.apps || {}
        const keys = Object.keys(apps)
        const list = []
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            const hourly = apps[key].hourly
            const secs = (hourly && hourly.length === 24) ? (hourly[hour] || 0) : 0
            if (secs > 0)
                list.push({ id: key, name: apps[key].name || key, seconds: secs, originalId: apps[key].originalId || key })
        }
        list.sort((a, b) => b.seconds - a.seconds)
        return list
    }

    FileView {
        id: todayFileView
        path: ""
    }

    Process {
        id: startupReadProc
        command: ["/usr/bin/bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                root._dirty = false
                if (text.trim() === "__NOFILE__" || text.trim().length === 0) {
                    root._todayData = root._emptyDay(root._currentDate)
                } else {
                    try {
                        root._todayData = JSON.parse(text.trim())
                        if (root._todayData.apps) {
                            const keys = Object.keys(root._todayData.apps)
                            for (let i = 0; i < keys.length; i++) {
                                const app = root._todayData.apps[keys[i]]
                                if (!app.originalId) {
                                    const entry = AppSearch.lookupDesktopEntry(app.name || keys[i])
                                    if (entry?.id) {
                                        app.originalId = entry.id.replace(/\.desktop$/, "")
                                        root._dirty = true
                                    }
                                }
                            }
                        }
                    } catch (e) {
                        root._todayData = root._emptyDay(root._currentDate)
                    }
                }
                root._lastTickTime = Date.now()
                root._lastPersistMs = Date.now()
                root._initialized = true
                root._loadingToday = false
                root.ready = true
                root._pruneHistory()
                if (root._dirty) {
                    root._persistToday()
                    root._dirty = false
                }
                root.dataChanged()
            }
        }
    }

    Process {
        id: rangeReadProc
        property int _requestedDays: 1
        property int _generation: 0
        property bool _completed: false
        command: ["/usr/bin/bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                rangeReadProc._completed = true
                const days = rangeReadProc._requestedDays
                if (rangeReadProc._generation === root._rangeGeneration) {
                    const history = root._mergeDays(root._emptyDay("history"), text)
                    const cache = {}
                    cache[days] = history
                    root._rangeHistoryData = Object.assign({}, root._rangeHistoryData, cache)
                    root.rangeLoaded(days,
                        root._mergeHistoricalData(root.getToday(), history))
                }
                root._activeRangeDays = 0
            }
        }
        onExited: {
            if (!rangeReadProc._completed)
                root._activeRangeDays = 0
            rangeReadProc._completed = false
            Qt.callLater(root._startNextRangeRead)
        }
    }
}
