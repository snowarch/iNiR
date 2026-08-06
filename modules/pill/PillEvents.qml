pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Event facade for the pill's calendar surface.
 *
 * Upstream kept its own JSON store keyed by "YYYY-MM-DD" date strings with a
 * {date, endDate, time, endTime, text, recur} shape. iNiR's Events service is the
 * real store and speaks Date objects with an ISO `dateTime`. Everything is
 * translated here so both the calendar and the rest of the shell see one agenda.
 */
Singleton {
    id: root

    readonly property var birthdayRe: /\b(birthday|cumple(a|ñ)os|bday)\b/i

    readonly property int length: (Events.list ?? []).length

    function isBirthday(t) {
        return root.birthdayRe.test(t || "");
    }

    /** "YYYY-MM-DD" (+ optional "HH:MM") to a local Date. */
    function _toDate(dateStr, timeStr) {
        const parts = String(dateStr).split("-");
        const d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        if (timeStr && timeStr.length >= 4) {
            const t = String(timeStr).split(":");
            d.setHours(Number(t[0]), Number(t[1]) || 0, 0, 0);
        }
        return d;
    }

    function _timeOf(ev) {
        const d = new Date(ev.dateTime);
        if (d.getHours() === 0 && d.getMinutes() === 0)
            return "";
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
    }

    /** Entries for a "YYYY-MM-DD" key, all-day first then by start time. */
    function forDate(dateStr) {
        void Events.list;
        const evs = Events.getEventsForDate(root._toDate(dateStr)) ?? [];
        const out = evs.map(e => ({
            id: e.id,
            text: e.title,
            date: dateStr,
            endDate: "",
            time: root._timeOf(e),
            endTime: "",
            end: "",
            recur: e.recurrence ?? ""
        }));
        out.sort((a, b) => {
            if (a.time === b.time)
                return 0;
            if (a.time === "")
                return -1;
            if (b.time === "")
                return 1;
            return a.time < b.time ? -1 : 1;
        });
        return out;
    }

    function hasEvents(dateStr) {
        void Events.list;
        if (!dateStr || dateStr.length === 0)
            return false;
        return (Events.getEventsForDate(root._toDate(dateStr)) ?? []).length > 0;
    }

    function add(dateStr, endDate, time, endTime, text, recur) {
        Events.addEvent(text, "", root._toDate(dateStr, time), "general", "normal", 0, recur || "");
    }

    function remove(id) {
        Events.removeEvent(id);
    }
}
