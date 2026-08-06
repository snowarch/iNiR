pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Display-device facade for the pill's mixer surface.
 *
 * Upstream shelled out to ddcutil and nvibrant directly. iNiR's Brightness
 * service already owns both the DDC monitors and the internal backlight, so
 * this exposes its live BrightnessMonitor objects instead of spawning a second
 * set of processes that would fight over the same i2c buses. Faders bind
 * straight to monitor.brightness, so a change made anywhere else (OSD keys,
 * another monitor's fader, anti-flashbang) moves the fader with it.
 *
 * Monitors are gated on `ready`: a fader only appears once its real hardware
 * value has been read, never showing a made-up default.
 *
 * Digital vibrance has no counterpart here (it needs nvibrant, an nvidia-only
 * dependency iNiR does not declare) and the mixer's vibrance fader is removed
 * rather than silently no-op'd.
 */
Singleton {
    id: root

    readonly property var _monitors: Brightness.monitors ?? []

    /**
     * A monitor is usable once its hardware read landed with a real number.
     * Brightness flips `ready` even when brightnessctl fails (the parse yields
     * NaN), so the value check is what keeps a dead fader off the row.
     */
    function usable(m) {
        return m && m.ready && !isNaN(m.brightness);
    }

    /** External monitors reachable over DDC, as live BrightnessMonitor objects. */
    readonly property var ddcMonitors: root._monitors.filter(m => root.usable(m) && m.isDdc)

    /** The internal backlight's monitor, when one exists and has been read. */
    readonly property var internalMonitor: root._monitors.find(m => root.usable(m) && !m.isDdc) ?? null
    readonly property bool backlightPresent: root.internalMonitor !== null
}
