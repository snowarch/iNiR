pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    readonly property bool ready: Weather.enabled && (Weather.data?.temp ?? "--°C") !== "--°C"

    readonly property string city: Weather.visibleCity ?? ""

    /** The manual town, shared with the rest of the shell's weather settings. */
    readonly property string configCity: Config.options?.bar?.weather?.city ?? ""

    function setCity(name) {
        Config.setNestedValue("bar.weather.city", String(name).trim());
    }
    readonly property int codeNow: parseInt(Weather.data?.wCode ?? "113")
    readonly property bool isDay: Weather.sunState === "day"

    /** Weather.data.temp is a display string like "18°C" / "64°F". */
    readonly property int tempNow: parseInt(Weather.data?.temp ?? "0")
    readonly property int humidity: parseInt(Weather.data?.humidity ?? "0")

    /**
     * The calendar's forecast strip wants {day, code, temp}; iNiR stores
     * {dayName, code, hi, lo, hiVal} under data.forecast. Reshape rather than
     * touching either side.
     */
    readonly property var daily: (Weather.data?.forecast ?? []).map(d => ({
        day: d.dayName,
        code: d.code,
        temp: Math.round(d.hiVal),
        lo: Math.round(d.loVal)
    }))

    readonly property var _cloudy: [116, 119, 122]
    readonly property var _fog: [143, 248, 260]
    readonly property var _thunder: [200, 386, 389, 392, 395]
    readonly property var _snow: [179, 227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377]
    readonly property var _sleet: [182, 185, 317, 320, 362, 365]

    function glyphFor(code, day) {
        const c = Number(code);
        if (c === 113)
            return day ? "sun" : "moon";
        if (root._thunder.includes(c))
            return "cloud-lightning";
        if (root._snow.includes(c))
            return "cloud-snow";
        if (root._sleet.includes(c))
            return "cloud-snow";
        if (root._fog.includes(c))
            return "cloud-fog";
        if (root._cloudy.includes(c))
            return "cloud";
        // Everything left in the WWO table is some flavour of rain or drizzle.
        if (c >= 176)
            return "cloud-rain";
        return "cloud";
    }

    /** iNiR already owns the localized description table; don't duplicate it. */
    function labelFor(code) {
        return Weather.describeWeather(code);
    }
}
