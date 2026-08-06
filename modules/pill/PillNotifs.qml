pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Notification facade for the pill's toast and link surfaces.
 *
 * Upstream this singleton owned its own NotificationServer. iNiR already runs
 * one, and two servers fight over org.freedesktop.Notifications, so this is a
 * pure view over `Notifications` instead: grouping, coalescing, read tracking and
 * age labels computed from that service's `list`. All mutations delegate back to
 * it, so dismissing here dismisses everywhere.
 */
Singleton {
    id: root

    /** Bumped by the age timer so `ageLabel` re-evaluates on a schedule. */
    property int tick: 0

    property var seenIds: ({})
    property var expandedApps: ({})
    property var expireAt: ({})

    readonly property var tracked: Notifications.list ?? []
    readonly property int count: tracked.length

    /** Popup-worthy notifications, newest last, capped like the upstream toast stack. */
    readonly property var popups: (Notifications.popupList ?? []).slice(-3)

    readonly property int unread: {
        void root.seenIds;
        let u = 0;
        for (let i = 0; i < root.tracked.length; i++)
            if (!root.seenIds[root.tracked[i].notificationId])
                u++;
        return u;
    }

    function _isCritical(n) {
        return String(n?.urgency ?? "").toLowerCase() === "critical";
    }

    /**
     * One entry per app, newest first. Within an app, consecutive notifications
     * carrying the same summary and body collapse into a single entry with a
     * count, and critical ones are split out so they can never be hidden behind a
     * collapsed group.
     */
    readonly property var groups: {
        const map = ({});
        const order = [];

        for (let i = 0; i < root.tracked.length; i++) {
            const n = root.tracked[i];
            const app = (n.appName && n.appName.length) ? n.appName : "System";
            if (map[app] === undefined) {
                map[app] = [];
                order.push(app);
            }
            map[app].push({ n: n, t: n.time || 0 });
        }

        function coalesce(list, it) {
            const last = list.length > 0 ? list[list.length - 1] : null;
            if (last && last.n.summary === it.n.summary && last.n.body === it.n.body) {
                last.count++;
                last.items.push(it.n);
            } else {
                list.push({ n: it.n, count: 1, items: [it.n] });
            }
        }

        const gs = order.map(app => {
            const items = map[app];
            items.sort((a, b) => b.t - a.t);
            const criticals = [];
            const entries = [];
            for (let k = 0; k < items.length; k++)
                coalesce(root._isCritical(items[k].n) ? criticals : entries, items[k]);
            const preview = items.find(it => !root._isCritical(it.n));
            return {
                app: app,
                count: items.length,
                t: items[0].t,
                newest: items[0].n,
                preview: preview ? preview.n : items[0].n,
                criticals: criticals,
                entries: entries
            };
        });
        gs.sort((a, b) => b.t - a.t);
        return gs;
    }

    /**
     * Resolve an icon path for a notification: an inline image wins, then the
     * app icon, desktop entry and app name are tried against the icon theme.
     */
    function iconFor(n) {
        if (!n)
            return "";
        const img = n.image || "";
        const names = [];
        if (img.indexOf("image://icon/") === 0)
            names.push(img.substring(13));
        else if (img.length && !/\.svg$/i.test(img))
            return img;

        names.push(n.appIcon, (n.appName || "").toLowerCase());
        for (let i = 0; i < names.length; i++) {
            const nm = names[i];
            if (!nm || !nm.length)
                continue;
            if (nm.indexOf("/") === 0 || nm.indexOf("file://") === 0)
                return nm;
            const p = Quickshell.iconPath(nm, true);
            if (p.length)
                return p;
        }
        return "";
    }

    function ageLabel(n) {
        void root.tick;
        const t = n?.time ?? 0;
        if (!t)
            return "";
        const m = Math.floor((Date.now() - t) / 60000);
        if (m < 1)
            return Translation.tr("now");
        if (m < 60)
            return m + "m";
        return Math.floor(m / 60) + "h";
    }

    function markAllSeen() {
        const s = Object.assign({}, root.seenIds);
        for (let i = 0; i < root.tracked.length; i++)
            s[root.tracked[i].notificationId] = true;
        root.seenIds = s;
    }

    function clearAll() {
        Notifications.discardAllNotifications();
        root.seenIds = ({});
    }

    function removePopup(n) {
        if (n)
            Notifications.timeoutNotification(n.notificationId);
    }

    function dismissEntry(e) {
        if (!e || !e.items)
            return;
        for (let i = 0; i < e.items.length; i++)
            Notifications.discardNotification(e.items[i].notificationId);
    }

    function dismissApp(app) {
        for (let i = root.tracked.length - 1; i >= 0; i--) {
            const n = root.tracked[i];
            const name = (n.appName && n.appName.length) ? n.appName : "System";
            if (name === app)
                Notifications.discardNotification(n.notificationId);
        }
    }

    /** Fire a notification's default action, then drop it. */
    function activateNotif(n) {
        if (!n)
            return;
        const actions = n.actions ?? [];
        const def = actions.find(a => a.identifier === "default") ?? actions[0];
        if (def)
            Notifications.attemptInvokeAction(n.notificationId, def.identifier);
        else
            Notifications.discardNotification(n.notificationId);
    }

    function activateEntry(e) {
        if (e && e.n)
            root.activateNotif(e.n);
    }

    function toggleExpanded(app) {
        const e = Object.assign({}, root.expandedApps);
        e[app] = !e[app];
        root.expandedApps = e;
    }

    /**
     * Raise the window that posted the notification. Niri has no "focus by app"
     * action, so match the notification's app name against the live window list
     * and focus the first hit by id.
     */
    function raiseWindow(n) {
        const app = String(n?.appName ?? "").toLowerCase();
        if (app.length === 0 || !CompositorService.isNiri)
            return;
        const win = (NiriService.windows ?? []).find(w =>
            String(w.app_id ?? "").toLowerCase().includes(app)
            || app.includes(String(w.app_id ?? "").toLowerCase()));
        if (win)
            NiriService.focusWindow(win.id);
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.tick++
    }
}
