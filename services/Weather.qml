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

    // Resolve location: manual coords > manual city > GPS > IP auto-detect
    function resolveLocation(): void {
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
                "https://nominatim.openstreetmap.org/search?format=json&q=" + q + "&limit=1&accept-language=en"];
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
        
        let query;
        if (root.location.lat !== 0 || root.location.lon !== 0) {
            query = root.location.lat + "," + root.location.lon;
        } else {
            query = encodeURIComponent(root.location.name.split(',')[0].trim());
        }
        const cmd = `curl -s --max-time 15 'wttr.in/${query}?format=j1' | jq '{current: .current_condition[0], astronomy: .weather[0].astronomy[0]}'`;
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
    Timer {
        id: retryTimer
        interval: 5000  // 5 seconds between retries
        repeat: false
        onTriggered: {
            if (!root.location.valid && root._retryCount < 5) {
                root._retryCount++;
                console.info("[Weather] Retry attempt", root._retryCount);
                root.resolveLocation();
            }
        }
    }

    onEnabledChanged: {
        if (enabled && Config.ready) {
            root._retryCount = 0;
            root.location = { valid: false, lat: 0, lon: 0, name: "" };
            resolveLocation();
        }
    }
    onUseUSCSChanged: fetchWeather()

    // Re-resolve when manual location config changes
    onConfigCityChanged: {
        if (Config.ready && root.enabled) {
            root.location = { valid: false, lat: 0, lon: 0, name: "" };
            resolveLocation();
        }
    }
    onConfigLatChanged: {
        if (Config.ready && root.enabled && root.hasManualCoords) {
            root.location = { valid: false, lat: 0, lon: 0, name: "" };
            resolveLocation();
        }
    }
    onConfigLonChanged: {
        if (Config.ready && root.enabled && root.hasManualCoords) {
            root.location = { valid: false, lat: 0, lon: 0, name: "" };
            resolveLocation();
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && root.enabled) {
                // Auto-refresh on shell restart: always resolve fresh
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
                        const r = results[0];
                        const lat = parseFloat(r.lat);
                        const lon = parseFloat(r.lon);
                        // Build a nice display name from the result
                        const displayName = r.display_name ? r.display_name.split(",").slice(0, 2).map(s => s.trim()).join(", ") : root.configCity;
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
        command: ["/usr/bin/bash", "-c", "where-am-i -t 10 2>/dev/null | grep -oP '(Latitude|Longitude):\\s*\\K[\\d.-]+' | head -2 | paste -sd' '"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) {
                    console.warn("[Weather] GPS failed, falling back to IP");
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
                root.getLocation();
            }
        }
        onExited: (code) => {
            if (code !== 0 && !root.location.valid) {
                console.warn("[Weather] GPS process failed (code " + code + "), falling back to IP");
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
        command: ["/usr/bin/bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    console.warn("[Weather] Empty response");
                    retryTimer.start();
                    return;
                }
                try {
                    root.refineData(JSON.parse(text));
                } catch (e) {
                    console.error("[Weather] Parse error:", e.message);
                    retryTimer.start();
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                console.error("[Weather] Fetch failed, code:", code);
                retryTimer.start();
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
