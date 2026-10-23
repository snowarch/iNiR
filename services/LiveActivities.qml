pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int staleMinutes: 60
    readonly property int retireMs: 4000
    readonly property var tints: ["blue", "sky", "teal", "green", "yellow", "orange", "red", "pink", "indigo", "purple", "lavender", "gray"]

    property var list: []
    readonly property var active: root.list.filter(activity => !activity.ended)
    readonly property var latest: {
        let best = null
        for (const activity of root.active) if (!best || activity.updated > best.updated) best = activity
        return best
    }

    signal finished(var activity)

    function find(id: string): var {
        return root.list.find(activity => activity.id === id) ?? null
    }
    function write(id: string, fields: var): var {
        const key = String(id ?? "").trim()
        if (key.length === 0) return null
        const now = Date.now()
        const previous = root.find(key)
        const next = Object.assign({ id: key, title: key, detail: "", progress: -1, glyph: "bolt", tint: "lavender",
            started: now, ended: false, failed: false, app: "", source: "ipc", notificationId: -1, actions: [] },
            previous ?? {}, fields, { updated: now })
        root.list = root.list.filter(activity => activity.id !== key).concat([next])
        return next
    }
    function parseProgress(value: string): real {
        const text = String(value ?? "").trim()
        if (text.length === 0 || text === "-" || text === "-1") return -1
        const number = parseFloat(text.replace("%", ""))
        if (isNaN(number)) return -1
        const fraction = text.endsWith("%") || number > 1 ? number / 100 : number
        return Math.max(0, Math.min(1, fraction))
    }

    function start(id: string, title: string): var {
        return root.write(id, { title: String(title ?? "").length > 0 ? String(title) : String(id), ended: false,
            started: Date.now(), progress: -1, detail: "" })
    }
    function setProgress(id: string, value: string): var { return root.write(id, { progress: root.parseProgress(value), ended: false }) }
    function setDetail(id: string, text: string): var { return root.write(id, { detail: String(text ?? ""), ended: false }) }
    function setTitle(id: string, text: string): var { return root.write(id, { title: String(text ?? ""), ended: false }) }
    function setGlyph(id: string, glyph: string): var { return root.write(id, { glyph: String(glyph ?? "bolt"), ended: false }) }
    function setTint(id: string, tint: string): var {
        return root.write(id, { tint: root.tints.includes(tint) ? tint : "lavender", ended: false })
    }
    function end(id: string, detail: string): var { return root.close(id, detail, false) }
    function close(id: string, detail: string, failed: bool): var {
        const was = root.find(id)
        if (!was || was.ended) return null
        const done = root.write(id, { ended: true, failed: failed, progress: failed ? was.progress : 1,
            detail: String(detail ?? "").length > 0 ? String(detail) : was.detail })
        root.finished(done)
        retire.restart()
        return done
    }
    function dismiss(id: string): void {
        root.list = root.list.filter(activity => activity.id !== id)
    }
    function clear(): void { root.list = [] }

    // Notifications that carry progress become activities: the `value` hint (0-100, what notify-send -h int:value:N
    // sends), and `inir run` (app "inir" with a Stop action) even before it has a percentage. A notification replaced
    // in place updates its activity; one re-sent under the same synchronous tag lands on the same activity.
    readonly property var syncKeys: ["x-canonical-private-synchronous", "synchronous", "x-dunst-stack-tag"]
    readonly property var followed: ({})
    function syncTag(notification): string {
        const hints = notification?.hints ?? {}
        for (const key of root.syncKeys) if (String(hints[key] ?? "").length > 0) return String(hints[key])
        return ""
    }
    function valueOf(notification): real {
        const raw = notification?.hints?.value
        const number = raw === undefined || raw === null || raw === "" ? NaN : Number(raw)
        return isNaN(number) ? -1 : Math.max(0, Math.min(1, number / 100))
    }
    function isRun(notification): bool {
        return String(notification?.appName ?? "") === "inir"
            && Array.from(notification?.actions ?? []).some(action => String(action?.identifier ?? "") === "cancel")
    }
    function plain(text: string): string {
        return String(text ?? "").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
    }
    function keyOf(notification): string {
        const tag = root.syncTag(notification)
        return "notify:" + (tag.length > 0 ? String(notification.appName ?? "") + ":" + tag : String(notification.id))
    }
    // Volume and brightness scripts send a value with a synchronous tag too: those are levels, not jobs.
    function isLevel(notification): bool {
        return /volume|brightness|backlight|^mic|osd|level/i.test(root.syncTag(notification))
    }
    function follow(notification, wrapperId: int): bool {
        if (!notification || root.isLevel(notification)) return false
        if (root.valueOf(notification) < 0 && !root.isRun(notification)) return false
        const key = root.keyOf(notification)
        const fresh = !root.find(key) || root.find(key).ended
        root.refresh(notification, key, wrapperId, fresh)
        if (root.followed[notification.id]) return true
        root.followed[notification.id] = true
        const update = () => root.refresh(notification, key, wrapperId, false)
        notification.hintsChanged.connect(update)
        notification.bodyChanged.connect(update)
        notification.actionsChanged.connect(update)
        notification.closed.connect(() => {
            delete root.followed[notification.id]
            const live = root.find(key)
            if (live && !live.ended && live.notificationId === wrapperId) root.close(key, Translation.tr("Stopped"), false)
        })
        return true
    }
    function refresh(notification, key: string, wrapperId: int, fresh: bool): void {
        const run = root.isRun(notification)
        const value = root.valueOf(notification)
        const lines = root.plain(notification.body).split("\n").map(line => line.trim()).filter(line => line.length > 0)
        // `inir run` opens its body with "42% · 1:23": the figure and the clock are drawn, the line under it is the detail.
        const head = run ? (lines[0] ?? "") : ""
        const detail = run ? (lines[1] ?? "") : lines.join(" ")
        if (!run && value < 0 || value >= 1) {
            const failed = /^(failed|killed)/i.test(lines[0] ?? "") || String(notification.appIcon ?? "").includes("error")
            root.close(key, lines[0] ?? "", failed)
            return
        }
        const fields = { title: root.plain(notification.summary) || String(notification.appName ?? ""),
            app: String(notification.appName ?? ""), detail: detail, progress: value, source: run ? "run" : "notification",
            notificationId: wrapperId, glyph: run ? "terminal" : "download", ended: false, failed: false,
            actions: Array.from(notification.actions ?? []).map(action => ({ id: String(action.identifier ?? ""), text: String(action.text ?? "") }))
                .filter(action => action.id.length > 0 && action.id !== "default") }
        if (fresh) {
            const clock = head.match(/(\d+):(\d\d)(?::(\d\d))?\s*$/)
            const seconds = !clock ? 0 : clock[3] !== undefined ? Number(clock[1]) * 3600 + Number(clock[2]) * 60 + Number(clock[3])
                : Number(clock[1]) * 60 + Number(clock[2])
            fields.started = Date.now() - seconds * 1000
        }
        root.write(key, fields)
    }

    Timer {
        id: retire
        interval: root.retireMs
        onTriggered: {
            const cutoff = Date.now() - root.retireMs + 50
            root.list = root.list.filter(activity => !activity.ended || activity.updated > cutoff)
            if (root.list.some(activity => activity.ended)) retire.restart()
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.list.length > 0
        onTriggered: {
            const cutoff = Date.now() - root.staleMinutes * 60000
            root.list = root.list.filter(activity => activity.updated > cutoff)
        }
    }
}
