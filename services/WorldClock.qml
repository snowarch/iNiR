pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property bool widgetOn: Config.options?.background?.widgets?.worldClock?.enable ?? false
    // Zones another surface shows (an Island face, say), each with how many ask for it: kept fresh while asked, without
    // the widget's second clock. `want` on show, `release` on hide; `offsetOf` answers once the zone is read.
    property var _asked: ({})
    readonly property var askedZones: Object.keys(root._asked).filter(tz => root._asked[tz] > 0)
    readonly property bool enabled: root.widgetOn || root.askedZones.length > 0
    // What one refresh reads: the widget's cities while it shows, and every asked zone.
    readonly property var zones: (root.widgetOn ? root.timezones : []).concat(root.askedZones.filter(tz => !root.widgetOn || !root.timezones.includes(tz)))
    property var zoneOffsets: ({})

    function want(tz: string): void {
        const zone = String(tz ?? "")
        if (zone.length === 0)
            return
        const asked = Object.assign({}, root._asked)
        asked[zone] = (asked[zone] ?? 0) + 1
        root._asked = asked
    }
    function release(tz: string): void {
        const zone = String(tz ?? "")
        if (!(root._asked[zone] > 0))
            return
        const asked = Object.assign({}, root._asked)
        asked[zone] -= 1
        if (asked[zone] <= 0)
            delete asked[zone]
        root._asked = asked
    }
    // Minutes east of UTC, or undefined until the zone has been read.
    function offsetOf(tz: string): var {
        return root.zoneOffsets[String(tz ?? "")]
    }

    readonly property var fallbackTimezones: ["Pacific/Auckland", "Pacific/Honolulu", "Australia/Sydney", "Australia/Perth", "Asia/Tokyo", "Asia/Seoul", "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore", "Asia/Bangkok", "Asia/Kolkata", "Asia/Dubai", "Asia/Qatar", "Asia/Tehran", "Asia/Jerusalem", "Europe/Moscow", "Europe/Istanbul", "Europe/Athens", "Europe/Warsaw", "Europe/Berlin", "Europe/Paris", "Europe/Madrid", "Europe/Rome", "Europe/London", "Europe/Lisbon", "Africa/Cairo", "Africa/Johannesburg", "Africa/Nairobi", "Africa/Lagos", "America/Sao_Paulo", "America/Argentina/Buenos_Aires", "America/Santiago", "America/Montevideo", "America/La_Paz", "America/Lima", "America/Bogota", "America/Caracas", "America/Mexico_City", "America/New_York", "America/Chicago", "America/Denver", "America/Phoenix", "America/Los_Angeles", "America/Anchorage", "America/Vancouver", "America/Toronto", "UTC"]

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

    readonly property int maxTimezones: 4
    readonly property var defaultTimezones: ["Asia/Tokyo", "Europe/London", "America/New_York"]
    readonly property var timezones: {
        const configured = Config.options?.background?.widgets?.worldClock?.timezones
            ?? root.defaultTimezones;
        const normalized = configured?.slice ? configured.slice(0, root.maxTimezones) : [];
        return normalized.length > 0 ? normalized : root.defaultTimezones;
    }

    function setTimezone(index: int, tz: string): void {
        let updated = root.timezones.slice();
        if (index < 0 || index >= updated.length)
            return;
        updated[index] = tz;
        Config.setNestedValue("background.widgets.worldClock.timezones", updated);
    }

    function addTimezone(tz: string): void {
        const candidate = String(tz ?? "");
        if (!candidate || root.timezones.length >= root.maxTimezones)
            return;
        const updated = root.timezones.slice();
        if (updated.includes(candidate))
            return;
        updated.push(candidate);
        Config.setNestedValue("background.widgets.worldClock.timezones", updated);
    }

    function removeTimezone(index: int): void {
        if (root.timezones.length <= 1 || index < 0 || index >= root.timezones.length)
            return;
        const updated = root.timezones.slice();
        const gone = updated.splice(index, 1)[0];
        Config.setNestedValue("background.widgets.worldClock.timezones", updated);
        Undo.offer(Translation.tr("Removed %1").arg(String(gone).split("/").pop().replace(/_/g, " ")), () => {
            const back = root.timezones.slice();
            if (back.includes(gone)) return;
            back.splice(Math.min(index, back.length), 0, gone);
            Config.setNestedValue("background.widgets.worldClock.timezones", back);
        });
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
    property var offsetsMinutes: []
    property int _offsetIndex: -1
    property var _nextOffsets: []
    property bool _refreshQueued: false
    property string _offsetText: ""
    property var _reading: []

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
        root._reading = root.zones.slice();
        root._runNextOffset();
    }

    function _runNextOffset(): void {
        if (!root.enabled) {
            root._offsetIndex = -1;
            root._nextOffsets = [];
            return;
        }
        if (root._offsetIndex >= root._reading.length) {
            const read = Object.assign({}, root.zoneOffsets);
            root._reading.forEach((tz, i) => read[tz] = root._nextOffsets[i]);
            root.zoneOffsets = read;
            root.offsetsMinutes = root.timezones.map((tz, i) => read[tz] ?? root.offsetsMinutes[i] ?? 0);
            root._offsetIndex = -1;
            if (root._refreshQueued)
                root.refreshOffsets();
            return;
        }

        root._offsetText = "";
        offsetProc.exec({
            command: ["date", "+%z"],
            environment: ({ TZ: String(root._reading[root._offsetIndex] ?? "UTC") })
        });
    }

    onZonesChanged: root.refreshOffsets()
    onWidgetOnChanged: if (root.widgetOn) root.now = new Date()
    Component.onCompleted: root.refreshOffsets()

    Timer {
        interval: 1000
        running: root.widgetOn
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

    // cityDate() deliberately encodes the target wall clock in UTC fields so
    // timeStringFor() can read it without the host timezone shifting it again.
    // QML's locale formatter, however, formats Date objects in the host zone.
    // Rebuild a local Date from those UTC fields before using it for calendar
    // text, otherwise cities across midnight can display the previous/next day.
    function cityDisplayDate(index: int): var {
        const cd = root.cityDate(index);
        return new Date(cd.getUTCFullYear(), cd.getUTCMonth(), cd.getUTCDate(),
            cd.getUTCHours(), cd.getUTCMinutes(), cd.getUTCSeconds(), cd.getUTCMilliseconds());
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
