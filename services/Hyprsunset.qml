pragma Singleton

import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

/**
 * Night light service with automatic mode.
 * Uses hyprsunset on Hyprland, wlsunset on Niri.
 */
Singleton {
    id: root
    property string from: Config.options?.light?.night?.from ?? "19:00" 
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic: Config.options?.light?.night?.automatic && (Config?.ready ?? true)
    property bool manualEnabled: Config.options?.light?.night?.enabled ?? false
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool active: false

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    // Debounce timer for wlsunset restarts
    property bool _pendingRestart: false
    Timer {
        id: restartDebounce
        interval: 300
        onTriggered: {
            // Stop first: the unit is still there, and systemd-run refuses a name in use.
            if (root._pendingRestart && root.active) {
                root.enable()
            }
            root._pendingRestart = false
        }
    }

    // wlsunset keeps a gamma control the compositor dropped (a charger moving resets the panel on some Intel laptops) and
    // asks again only when its temperature changes, which with fixed times is never: the screen stayed blue until the
    // next toggle (11-03). After a power or output change, the shell restarts it when it said it lost one.
    readonly property bool _pluggedIn: Battery.isPluggedIn
    readonly property var _outputs: NiriService.outputs
    on_PluggedInChanged: if (root.active && CompositorService.isNiri) gammaCheck.restart()
    on_OutputsChanged: if (root.active && CompositorService.isNiri) gammaCheck.restart()
    Timer {
        id: gammaCheck
        interval: 2500
        onTriggered: if (!gammaLostProc.running) gammaLostProc.running = true
    }
    Process {
        id: gammaLostProc
        // Without a user journal (runit, OpenRC) it can't know, and a restart costs a blink.
        command: ["bash", "-c",
            `if command -v journalctl >/dev/null 2>&1 && systemctl --user is-active --quiet inir-wlsunset.service 2>/dev/null; then
                journalctl --user -u inir-wlsunset.service --since "-30s" -o cat --no-pager 2>/dev/null | grep -q "gamma control of output .* failed";
            fi`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.active) {
                root._pendingRestart = true
                restartDebounce.restart()
            }
        }
    }

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()
    function ensureState() {
        if (root.manualActive !== undefined)
            return;

        if (root.automatic) {
            if (root.shouldBeOn) {
                root.enable();
            } else {
                root.disable();
            }
        } else if (root.manualEnabled) {
            root.enable();
        } else {
            root.disable();
        }
    }

    function load() { } // Dummy to force init

    function _doEnable() {
        if (CompositorService.isNiri) {
            Quickshell.execDetached([
                "bash", "-c",
                `if [ -S "${Quickshell.env("XDG_RUNTIME_DIR") || ""}/systemd/private" ] &&
                    command -v systemd-run >/dev/null && command -v systemctl >/dev/null && command -v timeout >/dev/null &&
                    timeout 3s systemctl --user show-environment >/dev/null 2>&1; then
                    exec systemd-run --user --collect --unit=inir-wlsunset.service wlsunset -T 6500 -t ${root.colorTemperature} -s 00:00 -S 23:59;
                fi;
                pidof wlsunset >/dev/null 2>&1 ||
                    nohup wlsunset -T 6500 -t ${root.colorTemperature} -s 00:00 -S 23:59
                        >/dev/null 2>&1 </dev/null &`
            ]);
        } else {
            hyprsunsetStartProc.running = true;
        }
    }

    function enable() {
        root.active = true;
        if (CompositorService.isNiri) {
            // Kill first, then start after kill completes
            wlsunsetKillProc.running = true;
        } else {
            root._doEnable();
        }
    }

    function disable() {
        root.active = false;
        if (CompositorService.isNiri) {
            wlsunsetKillProc.running = true;
        } else {
            hyprsunsetKillProc.running = true;
        }
    }

    function fetchState() {
        if (CompositorService.isNiri) {
            niriFetchProc.running = true;
        } else {
            fetchProc.running = true;
        }
    }

    // === Hyprland processes ===
    Process {
        id: hyprsunsetStartProc
        command: ["bash", "-c", `pidof hyprsunset || hyprsunset --temperature ${root.colorTemperature}`]
    }

    Process {
        id: hyprsunsetKillProc
        command: ["pkill", "-x", "hyprsunset"]
    }

    Process {
        id: fetchProc
        running: !CompositorService.isNiri
        command: ["bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const output = stateCollector.text.trim();
                if (output.length == 0 || output.startsWith("Couldn't"))
                    root.active = false;
                else
                    root.active = (output != "6500"); // 6500 is the default when off
            }
        }
    }

    // === Niri processes (wlsunset) ===
    Process {
        id: wlsunsetKillProc
        command: ["bash", "-c",
            `if [ -S "${Quickshell.env("XDG_RUNTIME_DIR") || ""}/systemd/private" ] &&
                command -v systemctl >/dev/null && command -v timeout >/dev/null &&
                timeout 3s systemctl --user show-environment >/dev/null 2>&1; then
                systemctl --user stop inir-wlsunset.service >/dev/null 2>&1 || true;
            fi;
            pkill -x wlsunset >/dev/null 2>&1 || true`]
        onExited: {
            // If we're enabling, start wlsunset after kill completes
            if (root.active) {
                root._doEnable();
            }
        }
    }

    Process {
        id: niriFetchProc
        running: CompositorService.isNiri
        command: ["bash", "-c",
            `if [ -S "${Quickshell.env("XDG_RUNTIME_DIR") || ""}/systemd/private" ] &&
                command -v systemctl >/dev/null && command -v timeout >/dev/null &&
                timeout 3s systemctl --user show-environment >/dev/null 2>&1 &&
                systemctl --user is-active --quiet inir-wlsunset.service; then
                exit 0;
            fi;
            pidof wlsunset >/dev/null`]
        onExited: (exitCode, exitStatus) => {
            root.active = (exitCode === 0);
        }
    }

    function toggle(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.active;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        Config.setNestedValue("light.night.enabled", root.manualActive);
        if (root.manualActive) {
            root.enable();
        } else {
            root.disable();
        }
    }

    // React to temperature changes while active
    Connections {
        target: Config.options?.light?.night ?? null
        enabled: !!(Config.options?.light?.night)
        
        function onColorTemperatureChanged() {
            if (!root.active) return;
            const temp = Config.options?.light?.night?.colorTemperature ?? root.colorTemperature;
            
            if (CompositorService.isNiri) {
                // Queue restart with debounce
                root._pendingRestart = true;
                restartDebounce.restart();
            } else {
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", `${temp}`]);
            }
        }
    }

    // React to schedule changes while automatic mode is on
    Connections {
        target: Config.options?.light?.night ?? null
        enabled: root.automatic && !!(Config.options?.light?.night)
        
        function onFromChanged() {
            root.firstEvaluation = true;
            root.reEvaluate();
        }
        
        function onToChanged() {
            root.firstEvaluation = true;
            root.reEvaluate();
        }
    }
}
