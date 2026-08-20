pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options?.background?.widgets?.worldClock?.enable ?? false

    readonly property var fallbackTimezones: ["Pacific/Auckland", "Pacific/Honolulu", "Australia/Sydney", "Australia/Perth", "Asia/Tokyo", "Asia/Seoul", "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore", "Asia/Bangkok", "Asia/Kolkata", "Asia/Dubai", "Asia/Tehran", "Asia/Jerusalem", "Europe/Moscow", "Europe/Istanbul", "Europe/Athens", "Europe/Warsaw", "Europe/Berlin", "Europe/Paris", "Europe/Madrid", "Europe/Rome", "Europe/London", "Europe/Lisbon", "Africa/Cairo", "Africa/Johannesburg", "Africa/Nairobi", "Africa/Lagos", "America/Sao_Paulo", "America/Argentina/Buenos_Aires", "America/Santiago", "America/Montevideo", "America/La_Paz", "America/Lima", "America/Bogota", "America/Caracas", "America/Mexico_City", "America/New_York", "America/Chicago", "America/Denver", "America/Phoenix", "America/Los_Angeles", "America/Anchorage", "America/Vancouver", "America/Toronto", "UTC"]

    readonly property var timezoneList: {
        if (typeof Intl !== "undefined" && typeof Intl.supportedValuesOf === "function") {
            try {
                return Intl.supportedValuesOf("timeZone");
            } catch (e) {
                return root.fallbackTimezones;
            }
        }
        return root.fallbackTimezones;
    }

    function labelFor(tz: string): string {
        const parts = String(tz).split("/");
        const city = (parts[parts.length - 1] ?? tz).replace(/_/g, " ");
        const region = parts.length > 1 ? parts[0] : "";
        return region ? `${city} (${region})` : city;
    }

    readonly property var comboModel: root.timezoneList.map(tz => ({
                label: root.labelFor(tz),
                tz: tz,
                icon: ""
            }))

    readonly property var defaultTimezones: ["Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"]
    readonly property var timezones: Config.options?.background?.widgets?.worldClock?.timezones ?? root.defaultTimezones

    function setTimezone(index: int, tz: string): void {
        let updated = root.timezones.slice();
        if (index < 0 || index >= updated.length)
            return;
        updated[index] = tz;
        Config.setNestedValue("background.widgets.worldClock.timezones", updated);
    }

    readonly property string ampmToken: {
        const fmt = Config.options?.time?.format ?? "HH:mm";
        if (fmt.includes("AP"))
            return "AP";
        if (fmt.includes("ap"))
            return "ap";
        return "";
    }
    readonly property bool use24h: root.ampmToken === ""

    property var now: new Date()
    property var offsetsMinutes: [0, 0, 0, 0]
    property int _offsetIndex: -1
    property var _nextOffsets: []
    property bool _refreshQueued: false
    property string _offsetText: ""

    function refreshOffsets(): void {
        if (!root.enabled)
            return;
        if (offsetProc.running) {
            root._refreshQueued = true;
            return;
        }
        root._refreshQueued = false;
        root._offsetIndex = 0;
        root._nextOffsets = [];
        root._runNextOffset();
    }

    function _runNextOffset(): void {
        if (!root.enabled) {
            root._offsetIndex = -1;
            root._nextOffsets = [];
            return;
        }
        if (root._offsetIndex >= root.timezones.length) {
            root.offsetsMinutes = root._nextOffsets;
            root._offsetIndex = -1;
            if (root._refreshQueued)
                root.refreshOffsets();
            return;
        }

        root._offsetText = "";
        offsetProc.exec({
            command: ["date", "+%z"],
            environment: ({ TZ: String(root.timezones[root._offsetIndex] ?? "UTC") })
        });
    }

    onTimezonesChanged: root.refreshOffsets()
    onEnabledChanged: {
        if (root.enabled) {
            root.now = new Date();
            root.refreshOffsets();
        }
    }
    Component.onCompleted: root.refreshOffsets()

    Timer {
        interval: 1000
        running: root.enabled
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refreshOffsets()
    }

    Process {
        id: offsetProc
        stdout: StdioCollector {
            id: offsetCollector
            onStreamFinished: root._offsetText = offsetCollector.text.trim()
        }
        onExited: {
            const match = root._offsetText.match(/^([+-])(\d{2})(\d{2})$/);
            const offset = match
                ? (match[1] === "-" ? -1 : 1)
                    * (parseInt(match[2]) * 60 + parseInt(match[3]))
                : 0;
            const nextOffsets = root._nextOffsets.slice();
            nextOffsets.push(offset);
            root._nextOffsets = nextOffsets;
            root._offsetIndex++;
            Qt.callLater(root._runNextOffset);
        }
    }

    function pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function cityDate(index: int): var {
        const offsetMin = root.offsetsMinutes[index] ?? 0;
        return new Date(root.now.getTime() + offsetMin * 60000);
    }

    function timeStringFor(index: int): string {
        const cd = root.cityDate(index);
        const h = cd.getUTCHours();
        const m = cd.getUTCMinutes();
        if (root.use24h)
            return root.pad(h) + ":" + root.pad(m);
        let h12 = h % 12;
        if (h12 === 0)
            h12 = 12;
        const base = root.pad(h12) + ":" + root.pad(m);
        if (root.ampmToken === "AP")
            return base + " " + (h >= 12 ? "PM" : "AM");
        return base + " " + (h >= 12 ? "pm" : "am");
    }

    function offsetLabelFor(index: int): string {
        const offsetMin = root.offsetsMinutes[index] ?? 0;
        const sign = offsetMin >= 0 ? "+" : "-";
        const abs = Math.abs(offsetMin);
        const h = Math.floor(abs / 60);
        const m = abs % 60;
        return "UTC" + sign + h + (m > 0 ? ":" + root.pad(m) : "");
    }

    function isDaytimeFor(index: int): bool {
        const h = root.cityDate(index).getUTCHours();
        return h >= 6 && h < 18;
    }

    readonly property var entries: root.timezones.map((tz, i) => ({
                tz: tz,
                name: root.labelFor(tz).split(" (")[0],
                time: root.timeStringFor(i),
                offset: root.offsetLabelFor(i),
                isDay: root.isDaytimeFor(i)
            }))
}
