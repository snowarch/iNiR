pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.modules.common

Singleton {
    id: root

    property bool _initialized: false
    // Quickshell warns at the first touch of PowerProfiles when no daemon can start (Arch has none by default),
    // so nothing here touches it until the system bus has one running or startable
    property bool available: false
    onAvailableChanged: if (available && Config.ready) Qt.callLater(() => root._applyPreferredProfile())

    Process {
        running: true
        command: ["sh", "-c", "command -v gdbus >/dev/null || exit 0; for m in ListNames ListActivatableNames; do gdbus call --system --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.$m; done | grep -q PowerProfiles"]
        onExited: code => root.available = code === 0
    }

    function _profileToString(profile): string {
        switch (profile) {
            case PowerProfile.PowerSaver: return "power-saver"
            case PowerProfile.Balanced: return "balanced"
            case PowerProfile.Performance: return "performance"
        }
        return ""
    }

    function _stringToProfile(value: string): int {
        switch (String(value ?? "").trim()) {
            case "power-saver": return PowerProfile.PowerSaver
            case "balanced": return PowerProfile.Balanced
            case "performance": return PowerProfile.Performance
        }
        return -1
    }

    function _applyPreferredProfile(): void {
        if (!Config.ready || !root.available || root._initialized)
            return

        root._initialized = true

        const restore = Config.options?.powerProfiles?.restoreOnStart ?? true
        const preferred = Config.options?.powerProfiles?.preferredProfile ?? ""

        if (!restore)
            return

        const desired = root._stringToProfile(preferred)
        if (desired < 0)
            return

        if (!PowerProfiles.hasPerformanceProfile && desired === PowerProfile.Performance)
            return

        if (PowerProfiles.profile !== desired) {
            PowerProfiles.profile = desired
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                Qt.callLater(() => root._applyPreferredProfile())
            }
        }
    }

    // Covers the path where Config was ALREADY ready before this singleton was
    // instantiated (hot-reload, or deferred loading after Config.ready fired) —
    // onReadyChanged never re-arms in that case. _applyPreferredProfile is
    // idempotent via _initialized, so running both is safe.
    Component.onCompleted: {
        if (Config.ready) {
            Qt.callLater(() => root._applyPreferredProfile())
        }
    }

    Connections {
        target: root.available ? PowerProfiles : null
        function onProfileChanged() {
            const s = root._profileToString(PowerProfiles.profile)
            if (s.length === 0)
                return
            Config.setNestedValue("powerProfiles.preferredProfile", s)
        }
    }
}
