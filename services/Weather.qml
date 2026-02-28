pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options?.bar?.weather?.enable ?? false
    readonly property int fetchInterval: (Config.options?.bar?.weather?.fetchInterval ?? 10) * 60 * 1000
    readonly property bool useUSCS: Config.options?.bar?.weather?.useUSCS ?? false

    // Manual location config
    readonly property string configCity: Config.options?.bar?.weather?.city ?? ""
    readonly property real configLat: Config.options?.bar?.weather?.manualLat ?? 0
    readonly property real configLon: Config.options?.bar?.weather?.manualLon ?? 0
    readonly property bool enableGPS: Config.options?.bar?.weather?.enableGPS ?? false
    readonly property bool hasManualCoords: configLat !== 0 || configLon !== 0
    readonly property bool hasManualCity: configCity.length > 0

    property var location: ({ valid: false, lat: 0, lon: 0, name: "" })

    property var data: ({
        uv: "0",
        humidity: "0%",
        sunrise: "--:--",
        sunset: "--:--",
        windDir: "N",
        wCode: "113",
        city: "City",
        wind: "0 km/h",
        precip: "0 mm",
        visib: "10 km",
        press: "1013 hPa",
        temp: "--°C",
        tempFeelsLike: "--°C"
    })

    function isNightNow(): bool {
        const h = new Date().getHours();
        return h < 6 || h >= 18;
    }

    function refineData(apiData) {
        if (!apiData?.current) return;
        
        const current = apiData.current;
        const astro = apiData.astronomy;
        
        let result = {};
        result.uv = current.uvIndex ?? "0";
        result.humidity = (current.humidity ?? 0) + "%";
        result.sunrise = astro?.sunrise ?? "--:--";
        result.sunset = astro?.sunset ?? "--:--";
        result.windDir = current.winddir16Point ?? "N";
        result.wCode = current.weatherCode ?? "113";
        result.city = root.location.name || "Unknown";

        if (root.useUSCS) {
            result.temp = (current.temp_F ?? 0) + "°F";
            result.tempFeelsLike = (current.FeelsLikeF ?? 0) + "°F";
            result.wind = (current.windspeedMiles ?? 0) + " mph";
            result.precip = (current.precipInches ?? 0) + " in";
            result.visib = (current.visibilityMiles ?? 0) + " mi";
            result.press = (current.pressureInches ?? 0) + " inHg";
        } else {
            result.temp = (current.temp_C ?? 0) + "°C";
            result.tempFeelsLike = (current.FeelsLikeC ?? 0) + "°C";
            result.wind = (current.windspeedKmph ?? 0) + " km/h";
            result.precip = (current.precipMM ?? 0) + " mm";
            result.visib = (current.visibility ?? 0) + " km";
            result.press = (current.pressure ?? 0) + " hPa";
        }

        root.data = result;
        console.info("[Weather] Updated:", result.temp, result.city);
    }

    function _degToCompass(deg): string {
        if (deg === undefined || deg === null || isNaN(deg)) return "N"
        const dirs = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        const idx = Math.round(((deg % 360) / 22.5)) % 16
        return dirs[idx]
    }

    function refineOpenMeteoData(apiData): void {
        const current = apiData?.current
        if (!current) return

        const units = apiData?.current_units ?? {}
        const daily = apiData?.daily ?? {}
        const sunrise = daily?.sunrise?.[0] ?? ""
        const sunset = daily?.sunset?.[0] ?? ""

        let result = {}
        result.uv = "0"
        result.humidity = (current.relative_humidity_2m ?? 0) + "%"
        result.sunrise = sunrise ? sunrise.split("T")[1] ?? sunrise : "--:--"
        result.sunset = sunset ? sunset.split("T")[1] ?? sunset : "--:--"
        result.windDir = root._degToCompass(current.wind_direction_10m)
        result.wCode = String(current.weather_code ?? 113)
        result.city = root.location.name || "Unknown"

        result.temp = (current.temperature_2m ?? 0) + (units.temperature_2m ?? (root.useUSCS ? "°F" : "°C"))
        result.tempFeelsLike = (current.apparent_temperature ?? 0) + (units.apparent_temperature ?? (root.useUSCS ? "°F" : "°C"))
        result.wind = (current.wind_speed_10m ?? 0) + " " + (units.wind_speed_10m ?? (root.useUSCS ? "mph" : "km/h"))
        result.precip = (current.precipitation ?? 0) + " " + (units.precipitation ?? (root.useUSCS ? "in" : "mm"))
        result.visib = (current.visibility ?? 0) + " " + (units.visibility ?? (root.useUSCS ? "mi" : "km"))
        result.press = (current.pressure_msl ?? 0) + " " + (units.pressure_msl ?? (root.useUSCS ? "inHg" : "hPa"))

        root.data = result
        console.info("[Weather] Updated via Open-Meteo:", result.temp, result.city)
    }

    function fetchWeatherFallback(): void {
        const lat = root.location.lat
        const lon = root.location.lon
        if ((lat === 0 && lon === 0) || openMeteoFetcher.running) {
            retryTimer.start()
            return
        }

        const tempUnit = root.useUSCS ? "fahrenheit" : "celsius"
        const windUnit = root.useUSCS ? "mph" : "kmh"
        const precipUnit = root.useUSCS ? "inch" : "mm"
        const visUnit = root.useUSCS ? "mile" : "km"
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat
            + "&longitude=" + lon
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,pressure_msl,wind_speed_10m,wind_direction_10m,weather_code,visibility"
            + "&daily=sunrise,sunset"
            + "&timezone=auto"
            + "&temperature_unit=" + tempUnit
            + "&wind_speed_unit=" + windUnit
            + "&precipitation_unit=" + precipUnit
            + "&visibility_unit=" + visUnit

        openMeteoFetcher.command = ["/usr/bin/curl", "-s", "--max-time", "15", url]
        openMeteoFetcher.running = true
    }

    // Resolve location: manual coords > manual city > GPS > IP auto-detect
    function resolveLocation(): void {
        if (gpsLocator.running || ipLocator.running || fallbackLocator.running
                || forwardGeocoder.running || reverseGeocoder.running || fetcher.running) {
            return;
        }

        if (root.hasManualCoords) {
            // User provided exact coordinates — reverse geocode for display name
            console.info("[Weather] Using manual coordinates:", root.configLat, root.configLon);
            root.location = {
                valid: true,
                lat: root.configLat,
                lon: root.configLon,
                name: root.configCity || ""
            };
            if (!root.configCity) {
                // Reverse geocode to get a nice city name
                reverseGeocoder.command = ["/usr/bin/curl", "-s", "--max-time", "10",
                    "https://nominatim.openstreetmap.org/reverse?format=json&lat=" + root.configLat + "&lon=" + root.configLon + "&zoom=10&accept-language=en"];
                reverseGeocoder.running = true;
            } else {
                root.fetchWeather();
            }
            return;
        }

        if (root.hasManualCity) {
            // User provided city name — forward geocode for coordinates + validated name
            console.info("[Weather] Using manual city:", root.configCity);
            const q = encodeURIComponent(root.configCity);
            forwardGeocoder.command = ["/usr/bin/curl", "-s", "--max-time", "10",
                "https://nominatim.openstreetmap.org/search?format=jsonv2&q=" + q + "&limit=5&addressdetails=1&accept-language=es,en"];
            forwardGeocoder.running = true;
            return;
        }

        if (root.enableGPS) {
            console.info("[Weather] Trying GPS via geoclue...");
            gpsLocator.running = true;
            return;
        }

        // Auto-detect from IP
        getLocation();
    }

    // Step 1: Get location from IP (primary method)
    function getLocation(): void {
        if (ipLocator.running) return;
        console.info("[Weather] Getting location from IP...");
        ipLocator.running = true;
    }

    // Step 2: Fetch weather using coordinates (precise) or city name (fallback)
    function fetchWeather(): void {
        if (!root.location.valid || fetcher.running) return;

        // Skip primary provider (wttr.in) if it has failed repeatedly — go straight to Open-Meteo
        if (root._primaryFailCount >= 3 && Date.now() < root._primaryFailUntil) {
            root.fetchWeatherFallback();
            return;
        }
        
        let query;
        if (root.location.lat !== 0 || root.location.lon !== 0) {
            query = root.location.lat + "," + root.location.lon;
        } else {
            query = encodeURIComponent(root.location.name.split(',')[0].trim());
        }
        const cmd = `curl -s --max-time 15 'https://wttr.in/${query}?format=j1'`;
        fetcher.command = ["/usr/bin/bash", "-c", cmd];
        fetcher.running = true;
    }

    function getData(): void {
        if (root.location.valid) {
            fetchWeather();
        } else {
            resolveLocation();
        }
    }

    // Force refresh (useful for settings UI "refresh now" button)
    function forceRefresh(): void {
        console.info("[Weather] Force refresh requested");
        root.location = { valid: false, lat: 0, lon: 0, name: "" };
        root._retryCount = 0;
        resolveLocation();
    }

    // Retry timer for when network isn't ready at startup
    property int _retryCount: 0
    property int _emptyResponseCount: 0
    // Track consecutive primary provider failures to skip it after repeated timeouts
    property int _primaryFailCount: 0
    property double _primaryFailUntil: 0  // timestamp (ms) until which primary is skipped
    Timer {
        id: retryTimer
        // Exponential backoff: 5s, 10s, 20s, 40s, 80s
        interval: Math.min(5000 * Math.pow(2, root._retryCount), 80000)
        repeat: false
        onTriggered: {
            if (root._retryCount < 5) {
                root._retryCount++;
                console.info("[Weather] Retry attempt", root._retryCount);
                if (!root.location.valid) {
                    root.resolveLocation();
                } else {
                    // Location is valid but weather fetch failed — retry weather directly
                    root.fetchWeather();
                }
            }
        }
    }

    // Debounce timer for manual location changes (wait for user to finish typing)
    Timer {
        id: locationDebounceTimer
        interval: 1500  // 1.5s after last keystroke
        repeat: false
        onTriggered: {
            root._lastCity = root.configCity;
            root._lastLat = root.configLat;
            root._lastLon = root.configLon;
            root.location = { valid: false, lat: 0, lon: 0, name: "" };
            root.resolveLocation();
        }
    }

    property bool _initialized: false

    onEnabledChanged: {
        if (enabled && Config.ready && !root._initialized) {
            root._initialized = true;
            root._retryCount = 0;
            root.location = { valid: false, lat: 0, lon: 0, name: "" };
            resolveLocation();
        }
    }
    onUseUSCSChanged: {
        if (root.location.valid) fetchWeather();
    }

    // Re-resolve when manual location config changes (debounced)
    property string _lastCity: ""
    property real _lastLat: 0
    property real _lastLon: 0

    onConfigCityChanged: {
        if (!Config.ready || !root.enabled || !root._initialized) return;
        if (root.configCity === root._lastCity) return;
        locationDebounceTimer.restart();
    }
    onConfigLatChanged: {
        if (!Config.ready || !root.enabled || !root._initialized) return;
        if (root.configLat === root._lastLat) return;
        if (root.hasManualCoords) locationDebounceTimer.restart();
    }
    onConfigLonChanged: {
        if (!Config.ready || !root.enabled || !root._initialized) return;
        if (root.configLon === root._lastLon) return;
        if (root.hasManualCoords) locationDebounceTimer.restart();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && root.enabled && !root._initialized) {
                root._initialized = true;
                root._retryCount = 0;
                root.resolveLocation();
            }
        }
    }

    // Forward geocoder: city name → coordinates + validated name
    Process {
        id: forwardGeocoder
        command: ["/usr/bin/curl", "-s", "--max-time", "10", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    console.warn("[Weather] Forward geocode empty, falling back to city name");
                    root.location = { valid: true, lat: 0, lon: 0, name: root.configCity };
                    root.fetchWeather();
                    return;
                }
                try {
                    const results = JSON.parse(text);
                    if (Array.isArray(results) && results.length > 0) {
                        const queryLower = root.configCity.toLowerCase().trim();
                        let best = results[0];
                        let bestScore = -1;

                        for (let i = 0; i < results.length; i++) {
                            const r = results[i];
                            const type = String(r?.type ?? "").toLowerCase();
                            const cls = String(r?.class ?? "").toLowerCase();
                            const name = String(r?.name ?? r?.display_name ?? "").toLowerCase();
                            const cityLike = ["city", "town", "village", "municipality", "hamlet", "suburb", "county", "administrative"];

                            let score = 0;
                            if (name === queryLower) score += 5;
                            else if (name.startsWith(queryLower)) score += 4;
                            else if (name.includes(queryLower)) score += 3;
                            if (cityLike.includes(type)) score += 2;
                            if (cls === "boundary" || cls === "place") score += 1;

                            if (score > bestScore) {
                                bestScore = score;
                                best = r;
                            }
                        }

                        const lat = parseFloat(best.lat);
                        const lon = parseFloat(best.lon);
                        let displayName = root.configCity;
                        const addr = best.address ?? {};
                        const city = addr.city || addr.town || addr.village || addr.municipality || addr.county || "";
                        const state = addr.state || addr.region || "";
                        const country = addr.country || "";
                        if (city && state) displayName = city + ", " + state;
                        else if (city && country) displayName = city + ", " + country;
                        else if (best.display_name) {
                            const parts = best.display_name.split(",").map(s => s.trim());
                            displayName = parts.length > 2 ? parts[0] + ", " + parts[parts.length - 1] : parts.join(", ");
                        }

                        root.location = { valid: true, lat: lat, lon: lon, name: displayName };
                        console.info("[Weather] Geocoded:", root.configCity, "→", displayName, "(", lat, ",", lon, ")");
                        root.fetchWeather();
                    } else {
                        console.warn("[Weather] No geocode results for:", root.configCity);
                        root.location = { valid: true, lat: 0, lon: 0, name: root.configCity };
                        root.fetchWeather();
                    }
                } catch (e) {
                    console.error("[Weather] Geocode parse error:", e.message);
                    root.location = { valid: true, lat: 0, lon: 0, name: root.configCity };
                    root.fetchWeather();
                }
            }
        }
    }

    // Reverse geocoder: coordinates → city name
    Process {
        id: reverseGeocoder
        command: ["/usr/bin/curl", "-s", "--max-time", "10", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    root.fetchWeather();
                    return;
                }
                try {
                    const data = JSON.parse(text);
                    const addr = data.address;
                    if (addr) {
                        const city = addr.city || addr.town || addr.village || addr.municipality || "";
                        const state = addr.state || addr.region || "";
                        const name = city + (state ? `, ${state}` : "");
                        if (name) {
                            root.location = {
                                valid: true,
                                lat: root.location.lat,
                                lon: root.location.lon,
                                name: name
                            };
                            // Save the resolved name back to config for display
                            console.info("[Weather] Reverse geocoded:", name);
                        }
                    }
                } catch (e) {
                    console.warn("[Weather] Reverse geocode error:", e.message);
                }
                root.fetchWeather();
            }
        }
    }

    // GPS via geoclue (where-am-i command)
    Process {
        id: gpsLocator
        property bool _handledFallback: false
        command: ["/usr/bin/bash", "-c", "where-am-i -t 10 2>/dev/null | grep -oP '(Latitude|Longitude):\\s*\\K[\\d.-]+' | head -2 | paste -sd' '"]
        onRunningChanged: if (running) _handledFallback = false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) {
                    console.warn("[Weather] GPS failed, falling back to IP");
                    gpsLocator._handledFallback = true;
                    root.getLocation();
                    return;
                }
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 2) {
                    const lat = parseFloat(parts[0]);
                    const lon = parseFloat(parts[1]);
                    if (!isNaN(lat) && !isNaN(lon)) {
                        root.location = { valid: true, lat: lat, lon: lon, name: "" };
                        console.info("[Weather] GPS location:", lat, lon);
                        // Reverse geocode for display name
                        reverseGeocoder.command = ["/usr/bin/curl", "-s", "--max-time", "10",
                            "https://nominatim.openstreetmap.org/reverse?format=json&lat=" + lat + "&lon=" + lon + "&zoom=10&accept-language=en"];
                        reverseGeocoder.running = true;
                        return;
                    }
                }
                console.warn("[Weather] GPS parse failed, falling back to IP");
                gpsLocator._handledFallback = true;
                root.getLocation();
            }
        }
        onExited: (code) => {
            if (code !== 0 && !root.location.valid && !gpsLocator._handledFallback) {
                console.warn("[Weather] GPS process failed (code " + code + "), falling back to IP");
                gpsLocator._handledFallback = true;
                root.getLocation();
            }
        }
    }

    // IP geolocation (ip-api.com - accurate)
    Process {
        id: ipLocator
        command: ["/usr/bin/curl", "-s", "--max-time", "10", "http://ip-api.com/json/?fields=lat,lon,city,regionName"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    console.warn("[Weather] IP location empty, trying fallback");
                    fallbackLocator.running = true;
                    return;
                }
                try {
                    const data = JSON.parse(text);
                    if (data.lat && data.lon) {
                        root.location = {
                            valid: true,
                            lat: data.lat,
                            lon: data.lon,
                            name: data.city + (data.regionName ? `, ${data.regionName}` : "")
                        };
                        console.info("[Weather] Location:", root.location.name);
                        root.fetchWeather();
                    } else {
                        fallbackLocator.running = true;
                    }
                } catch (e) {
                    console.error("[Weather] IP location error:", e.message);
                    fallbackLocator.running = true;
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[Weather] IP location failed, trying fallback");
                fallbackLocator.running = true;
            }
        }
    }

    // Fallback: ipwho.is
    Process {
        id: fallbackLocator
        command: ["/usr/bin/curl", "-s", "--max-time", "10", "https://ipwho.is/"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                try {
                    const data = JSON.parse(text);
                    if (data.latitude && data.longitude) {
                        root.location = {
                            valid: true,
                            lat: data.latitude,
                            lon: data.longitude,
                            name: data.city + (data.region ? `, ${data.region}` : "")
                        };
                        console.info("[Weather] Location (fallback):", root.location.name);
                        root.fetchWeather();
                    } else {
                        // Both methods failed, schedule retry
                        retryTimer.start();
                    }
                } catch (e) {
                    console.error("[Weather] Fallback location error:", e.message);
                    retryTimer.start();
                }
            }
        }
        onExited: (code) => {
            // If fallback also fails, schedule retry
            if (code !== 0 && !root.location.valid) {
                retryTimer.start();
            }
        }
    }

    // Weather fetcher
    Process {
        id: fetcher
        // Guard: prevent double fallback invocation from both onStreamFinished and onExited
        property bool _fallbackTriggered: false
        command: ["/usr/bin/bash", "-c", ""]
        onRunningChanged: if (running) _fallbackTriggered = false
        stdout: StdioCollector {
            onStreamFinished: {
                const payload = text.trim();
                if (payload.length === 0) {
                    root._emptyResponseCount++;
                    if (root._emptyResponseCount >= 3) {
                        console.warn("[Weather] Empty response (x" + root._emptyResponseCount + "), retrying");
                    } else {
                        console.info("[Weather] Empty response, retrying");
                    }
                    if (!fetcher._fallbackTriggered) {
                        fetcher._fallbackTriggered = true;
                        root._primaryFailCount++;
                        root._primaryFailUntil = Date.now() + 30 * 60 * 1000; // Skip primary for 30min after 3 fails
                        root.fetchWeatherFallback();
                    }
                    return;
                }

                if (!(payload.startsWith("{") || payload.startsWith("["))) {
                    root._emptyResponseCount++;
                    if (root._emptyResponseCount >= 3) {
                        console.warn("[Weather] Non-JSON weather response, retrying");
                    } else {
                        console.info("[Weather] Transient weather response, retrying");
                    }
                    if (!fetcher._fallbackTriggered) {
                        fetcher._fallbackTriggered = true;
                        root._primaryFailCount++;
                        root._primaryFailUntil = Date.now() + 30 * 60 * 1000;
                        root.fetchWeatherFallback();
                    }
                    return;
                }

                try {
                    const parsed = JSON.parse(payload);
                    const normalized = {
                        current: parsed?.current ?? parsed?.current_condition?.[0],
                        astronomy: parsed?.astronomy ?? parsed?.weather?.[0]?.astronomy?.[0]
                    }
                    root.refineData(normalized);
                    root._emptyResponseCount = 0;
                    root._primaryFailCount = 0; // Reset on success
                } catch (e) {
                    root._emptyResponseCount++;
                    if (root._emptyResponseCount >= 3) {
                        console.warn("[Weather] Parse error:", e.message);
                    } else {
                        console.info("[Weather] Parse error, retrying");
                    }
                    if (!fetcher._fallbackTriggered) {
                        fetcher._fallbackTriggered = true;
                        root._primaryFailCount++;
                        root._primaryFailUntil = Date.now() + 30 * 60 * 1000;
                        root.fetchWeatherFallback();
                    }
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && !fetcher._fallbackTriggered) {
                fetcher._fallbackTriggered = true;
                root._primaryFailCount++;
                root._primaryFailUntil = Date.now() + 30 * 60 * 1000;
                console.warn("[Weather] Primary provider failed, switching fallback. code:", code);
                root.fetchWeatherFallback();
            }
        }
    }

    Process {
        id: openMeteoFetcher
        command: ["/usr/bin/curl", "-s", "--max-time", "15", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const payload = text.trim()
                if (payload.length === 0) {
                    retryTimer.start()
                    return
                }
                try {
                    root.refineOpenMeteoData(JSON.parse(payload))
                    root._emptyResponseCount = 0
                } catch (e) {
                    console.warn("[Weather] Open-Meteo parse error:", e.message)
                    retryTimer.start()
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[Weather] Open-Meteo fetch failed, code:", code)
                retryTimer.start()
            }
        }
    }

    Timer {
        id: fetchTimer
        running: root.enabled && Config.ready
        repeat: true
        interval: root.fetchInterval > 0 ? root.fetchInterval : 600000
        onTriggered: root.getData()
        onRunningChanged: {
            if (running) Qt.callLater(() => root.getData())
        }
    }
}
