pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import qs.modules.common
import qs.modules.common.functions
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "brightnessPolicy.js" as BrightnessPolicy

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root
    signal brightnessChanged()
    property real lastUserChange: 0

    property var ddcMonitors: []
    property list<BrightnessMonitor> monitors: []
    property string backlightDevice: ""
    property bool backlightDetectionReady: false
    property int _bestBacklightMax: 0
    // last >0 level per screen.name; survives monitor recreation after dpms
    property var lastValidBrightness: ({})
    property bool asleep: false
    property var _sleepDisabledOutputs: []
    property var _wakePendingOutputs: []
    property int _wakeRetryAttempt: 0
    property var _niriQueue: []
    property bool _niriBusy: false
    property var _niriActive: null

    // Reconcile against the live screen list rather than binding to
    // Quickshell.screens: createObject() parents each monitor to root, so a
    // binding would strand a whole generation of BrightnessMonitors on every
    // screen change (hotplug, DPMS, mode switch). Still-connected screens keep
    // their existing BrightnessMonitor (and its running Timers/Processes);
    // disconnected ones are destroyed so they don't react to a dead screen.
    function _syncMonitors(): void {
        // Array.from is load-bearing: list<T> is a live view of the property, not
        // a snapshot, so holding it directly would alias the *new* list after the
        // assignment below and destroy the monitors we just built/kept.
        const prev = Array.from(root.monitors);
        const next = Quickshell.screens.map(screen => {
            const existing = prev.find(m => m.screen === screen)
                ?? prev.find(m => m.screen?.name && m.screen.name === screen?.name);
            if (existing) {
                existing.screen = screen;
                return existing;
            }
            return monitorComp.createObject(root, { screen });
        });
        root.monitors = next;
        for (const m of prev) {
            if (!next.includes(m)) m.destroy();
        }
    }

    function _detectBacklight(): void {
        root.backlightDetectionReady = false
        root.backlightDevice = ""
        root._bestBacklightMax = 0
        backlightDetectProc.running = false
        backlightDetectProc.running = true
    }

    function _connectedNames(): var {
        const names = []
        for (let i = 0; i < Quickshell.screens.length; ++i)
            names.push(Quickshell.screens[i].name)
        return names
    }

    function _enqueueNiri(args, phase = "", outputName = "", abortOnFailure = false): void {
        root._niriQueue = root._niriQueue.concat([{
            args: args,
            phase: phase,
            outputName: outputName,
            abortOnFailure: abortOnFailure,
        }])
        root._drainNiriQueue()
    }

    function _drainNiriQueue(): void {
        if (root._niriBusy || root._niriQueue.length === 0)
            return
        const next = root._niriQueue[0]
        root._niriQueue = root._niriQueue.slice(1)
        root._niriBusy = true
        root._niriActive = next
        niriSerialProc.command = next.args
        niriSerialProc.running = false
        niriSerialProc.running = true
    }

    function _queueWake(names): void {
        root._wakePendingOutputs = BrightnessPolicy.mergeOutputNames([], names)
        root._enqueueNiri(BrightnessPolicy.niriPowerOnMonitorsArgs(), "wake")
        root._tryWakeOutputs()
        if (root._wakePendingOutputs.length > 0)
            wakeRetryTimer.restart()
    }

    function _finishWakeIfDone(): void {
        if (root.asleep || root._wakePendingOutputs.length > 0)
            return
        wakeRetryTimer.stop()
        root._wakeRetryAttempt = 0
        root._sleepDisabledOutputs = []
    }

    function _recoverFailedSleep(): void {
        root._niriQueue = root._niriQueue.filter(item => item.phase !== "sleep")
        root.asleep = false
        root._wakeRetryAttempt = 0
        root._queueWake(root._sleepDisabledOutputs)
    }

    function sleepBegin(): void {
        if (!CompositorService.isNiri)
            return
        wakeRetryTimer.stop()
        root._niriQueue = root._niriQueue.filter(item => item.phase !== "wake")
        root._wakeRetryAttempt = 0
        const connected = root._connectedNames()
        root._sleepDisabledOutputs = BrightnessPolicy.pinnedForSleep(
            root._sleepDisabledOutputs, connected, root.asleep)
        root._wakePendingOutputs = []
        root.asleep = true
        const cmds = BrightnessPolicy.sleepCommandQueue(connected)
        for (let i = 0; i < cmds.length; ++i)
            root._enqueueNiri(cmds[i], "sleep", "", true)
    }

    function _tryWakeOutputs(): void {
        const names = root._wakePendingOutputs
        for (let i = 0; i < names.length; ++i)
            root._enqueueNiri(BrightnessPolicy.niriOutputOnArgs(names[i]), "wake", names[i])
    }

    function restoreAfterWake(): void {
        if (!CompositorService.isNiri) {
            root.asleep = false
            return
        }
        const pinned = BrightnessPolicy.mergeOutputNames([], root._sleepDisabledOutputs)
        root._niriQueue = root._niriQueue.filter(item => item.phase !== "sleep")
        root.asleep = false
        root._wakeRetryAttempt = 0
        root._queueWake(pinned)
        root._syncMonitors()
        for (let i = 0; i < root.monitors.length; ++i)
            root.monitors[i].restoreLastGood()
    }

    Component.onCompleted: {
        root._syncMonitors()
        root._detectBacklight()
    }

    Process {
        id: niriSerialProc
        stderr: StdioCollector { id: niriSerialErr }
        onExited: (exitCode, exitStatus) => {
            const completed = root._niriActive
            root._niriActive = null
            root._niriBusy = false

            if (exitCode !== 0) {
                const detail = (niriSerialErr.text || "").trim()
                if (completed?.abortOnFailure) {
                    console.warn(`[Brightness] sleep command failed (${completed?.args?.join(" ") ?? "unknown"}): ${detail || `exit ${exitCode}`}; skipping DPMS and restoring pinned outputs`)
                    root._niriQueue = root._niriQueue.filter(item => item.phase !== "sleep")
                    if (root.asleep) {
                        root._recoverFailedSleep()
                        return
                    }
                } else if (!completed?.outputName) {
                    console.warn(`[Brightness] niri command failed (${completed?.args?.join(" ") ?? "unknown"}): ${detail || `exit ${exitCode}`}`)
                }
            } else if (completed?.phase === "wake" && completed?.outputName) {
                root._wakePendingOutputs = BrightnessPolicy.removeOutputName(root._wakePendingOutputs, completed.outputName)
                root._finishWakeIfDone()
            }

            root._drainNiriQueue()
        }
    }

    Timer {
        id: wakeRetryTimer
        interval: 400
        repeat: true
        onTriggered: {
            root._wakeRetryAttempt++
            if (!BrightnessPolicy.shouldRetryWakeOutput(root._wakeRetryAttempt, BrightnessPolicy.wakeOutputRetryLimit())) {
                if (root._wakePendingOutputs.length > 0)
                    console.warn(`[Brightness] wake retry limit reached for: ${root._wakePendingOutputs.join(", ")}`)
                stop()
                root._wakeRetryAttempt = 0
                return
            }
            root._tryWakeOutputs()
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.asleep)
                return
            root._syncMonitors();
            root._detectBacklight();
        }
    }

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function _focusedMonitor(): var {
        const focusedName = CompositorService.isNiri ? NiriService.currentOutput : Hyprland.focusedMonitor?.name;
        return monitors.find(m => focusedName === m.screen?.name) ?? null;
    }

    function describe(m): string {
        const how = m.isDdc ? `ddc bus ${m.busNum}` : (root.backlightDevice || "no control")
        const level = Number.isFinite(m.brightness) ? `${Math.round(m.brightness * 100)}%` : "unknown"
        return `${m.screen?.name ?? "?"} ${how}: ${level}, hardware ${m._writtenRaw}/${m.rawMaxBrightness}${m.ready ? "" : " (reading)"}`
    }

    function increaseBrightness(): void {
        const focusedName = CompositorService.isNiri ? NiriService.currentOutput : Hyprland.focusedMonitor?.name;
        if (!focusedName) return;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const focusedName = CompositorService.isNiri ? NiriService.currentOutput : Hyprland.focusedMonitor?.name;
        if (!focusedName) return;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    reloadableId: "brightness"

    property var _ddcNext: []
    property string _ddcHelp: ""

    Process {
        id: ddcHelpProc
        running: true
        command: ["ddcutil", "--help"]
        stdout: StdioCollector {
            onStreamFinished: root._ddcHelp = text
        }
    }

    onMonitorsChanged: {
        if (root.asleep)
            return
        ddcProc.running = false
        ddcProc.running = true
    }

    Process {
        id: backlightDetectProc
        command: ["brightnessctl", "-l", "-m", "-c", "backlight"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                // brightnessctl machine format:
                // device,class,current,current-percent,max
                const parts = line.trim().split(",")
                if (parts.length < 5 || parts[1] !== "backlight")
                    return
                const name = parts[0]
                const max = Number(parts[parts.length - 1])
                if (!name || !Number.isFinite(max) || max <= 0)
                    return
                // Multi-backlight AMD laptops commonly expose a tiny stub and
                // the real panel device. The useful panel has the larger range.
                if (max > root._bestBacklightMax) {
                    root._bestBacklightMax = max
                    root.backlightDevice = name
                }
            }
        }
        onExited: {
            root.backlightDetectionReady = true
            root.monitors.forEach(monitor => {
                if (!monitor.isDdc)
                    monitor.initialize()
            })
        }
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root._ddcNext.push({
                        model: lines.find(l => l.startsWith("Monitor:")).split(":")[2],
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onRunningChanged: {
            if (running)
                root._ddcNext = []
        }
        onExited: {
            const found = root._ddcNext.length > 0
            if (found)
                root.ddcMonitors = root._ddcNext
            root._ddcNext = []
            root.ddcMonitorsChanged()
            // A busy I2C bus (another ddcutil, a login race) makes detect see no monitor at all; an output
            // left with no control is detected again rather than left without brightness for the session.
            const uncontrolled = root.monitors.some(m => !m.isDdc && root.backlightDevice.length === 0)
            if (!found && uncontrolled && root._detectAttempts < 5) {
                ddcDetectRetry.interval = Math.min(8000, 1000 * Math.pow(2, root._detectAttempts))
                root._detectAttempts++
                ddcDetectRetry.restart()
            } else if (found) {
                root._detectAttempts = 0
            }
        }
    }

    property int _detectAttempts: 0
    Timer {
        id: ddcDetectRetry
        onTriggered: {
            if (root.asleep || ddcProc.running)
                return
            ddcProc.running = true
        }
    }

    Process {
        id: setProc
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property bool isDdc: {
            const match = root.ddcMonitors.find(m => screen?.model?.includes(m.model) && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return !!match;
        }
        readonly property string busNum: {
            const match = root.ddcMonitors.find(m => screen?.model?.includes(m.model) && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return match?.busNum ?? "";
        }
        property int rawMaxBrightness: 100
        property real brightness
        property real brightnessMultiplier: 1.0
        property real multipliedBrightness: Math.max(0, Math.min(1, brightness * ((Config.options?.light?.antiFlashbang?.enable ?? false) ? brightnessMultiplier : 1)))
        property bool ready: false
        property bool animateChanges: !monitor.isDdc
        property bool writePending: false

        onBrightnessChanged: {
            if (!monitor.ready) return;
            root.brightnessChanged();
        }

        Behavior on multipliedBrightness {
            enabled: monitor.animateChanges
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
        onMultipliedBrightnessChanged: {
            if (!monitor.ready) return
            monitor.writePending = true
            if (!setTimer.running)
                setTimer.start()
        }

        function restoreLastGood(): void {
            const screenName = monitor.screen?.name ?? ""
            const value = BrightnessPolicy.pickRestoreValue(
                root.lastValidBrightness[screenName],
                monitor.brightness
            )
            if (!Number.isFinite(value)) {
                initialize()
                return
            }
            if (screenName)
                root.lastValidBrightness[screenName] = value
            monitor.ready = false
            monitor.brightness = value
            monitor.ready = true
            monitor._writtenRaw = -1
            syncBrightness()
        }

        function initialize() {
            monitor.ready = false;
            monitor._writtenRaw = -1
            if (isDdc) {
                initProc.command = ["ddcutil", "-b", busNum].concat(
                    BrightnessPolicy.ddcFlags(root._ddcHelp, false), ["getvcp", "10", "--brief"])
            } else if (!root.backlightDetectionReady) {
                return
            } else if (root.backlightDevice.length > 0) {
                // Pass the device as a positional shell argument instead of
                // interpolating it into the command string.
                initProc.command = [
                    "/bin/sh", "-c",
                    "printf '%s %s\\n' \"$(brightnessctl -d \"$1\" g)\" \"$(brightnessctl -d \"$1\" m)\"",
                    "_", root.backlightDevice
                ]
            } else {
                const screenName = monitor.screen?.name ?? ""
                const lastGood = root.lastValidBrightness[screenName]
                const resolved = BrightnessPolicy.resolveHardwareBrightness(Number.NaN, 0, lastGood)
                monitor.brightness = Number.isFinite(resolved.value) ? resolved.value : Number.NaN
                monitor.ready = true
                return
            }
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const parts = data.trim().split(/\s+/)
                    const current = Number(parts[parts.length - 2])
                    const max = Number(parts[parts.length - 1])
                    const screenName = monitor.screen?.name ?? ""
                    const lastGood = root.lastValidBrightness[screenName]
                    const resolved = BrightnessPolicy.resolveHardwareBrightness(current, max, lastGood, monitor.isDdc)
                    if (Number.isFinite(resolved.rawMax))
                        monitor.rawMaxBrightness = resolved.rawMax
                    if (Number.isFinite(resolved.value)) {
                        if (!resolved.restore)
                            monitor._writtenRaw = current
                        monitor.brightness = resolved.value
                        if (screenName && resolved.value >= 0.01)
                            root.lastValidBrightness[screenName] = resolved.value
                    }
                    monitor.ready = true
                    if (resolved.restore)
                        monitor.syncBrightness()
                }
            }
            onExited: {
                if (monitor.ready) {
                    monitor._initAttempts = 0
                    return
                }
                // A DDC read can fail while the bus is busy right after login, a
                // hotplug or a second `ddcutil detect`; settling here leaves the
                // slider disabled over a lit monitor. Back off up to ~23 s.
                if (monitor.isDdc && monitor._initAttempts < 5) {
                    initRetryTimer.interval = Math.min(8000, 1000 * Math.pow(2, monitor._initAttempts))
                    monitor._initAttempts++
                    initRetryTimer.restart()
                    return
                }
                if (monitor.isDdc)
                    console.warn(`[Brightness] ${monitor.screen?.name ?? "?"}: could not read the level over DDC (bus ${monitor.busNum}); opening a brightness panel retries`)
                monitor._initAttempts = 0
                const screenName = monitor.screen?.name ?? ""
                const value = BrightnessPolicy.pickRestoreValue(
                    root.lastValidBrightness[screenName],
                    monitor.brightness
                )
                if (Number.isFinite(value)) {
                    if (screenName)
                        root.lastValidBrightness[screenName] = value
                    monitor.brightness = value
                    monitor.ready = true
                    syncBrightness()
                    return
                }
                monitor.ready = true
            }
        }

        property int _initAttempts: 0
        property var initRetryTimer: Timer {
            interval: 1000
            onTriggered: monitor.initialize()
        }

        property int _writeFailures: 0
        property var ddcRetryTimer: Timer {
            interval: 800
            onTriggered: monitor.syncBrightness()
        }

        // Coalesce animation frames to ~30 writes a second (#188), then hand
        // the level to one writer per monitor. Detached ddcutil calls queue on
        // the bus lock and finish out of order, so the monitor could end on a
        // level older than the slider's; the writer runs one call at a time and
        // always ends on the newest level.
        property var setTimer: Timer {
            id: setTimer
            interval: 32
            onTriggered: {
                if (!monitor.writePending) return
                monitor.writePending = false
                syncBrightness();
            }
        }

        property int _wantedRaw: -1
        property int _writingRaw: -1
        property int _writtenRaw: -1

        function syncBrightness() {
            const raw = BrightnessPolicy.rawLevel(monitor.multipliedBrightness, monitor.rawMaxBrightness, monitor.isDdc)
            if (raw < 0)
                return
            if (monitor.isDdc ? !busNum : root.backlightDevice.length === 0)
                return
            monitor._wantedRaw = raw
            monitor._writeNext()
        }

        function _writeNext(): void {
            if (writeProc.running || monitor._wantedRaw < 0 || monitor._wantedRaw === monitor._writtenRaw)
                return
            const raw = monitor._wantedRaw
            monitor._writingRaw = raw
            writeProc.command = monitor.isDdc
                ? ["ddcutil", "-b", busNum].concat(BrightnessPolicy.ddcFlags(root._ddcHelp, true), ["setvcp", "10", `${raw}`])
                : ["brightnessctl", "-d", root.backlightDevice, "s", `${raw}`, "--quiet"]
            writeProc.running = true
        }

        readonly property Process writeProc: Process {
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0) {
                    monitor._writtenRaw = -1
                    if (++monitor._writeFailures <= 3)
                        ddcRetryTimer.restart()
                    else
                        console.warn(`[Brightness] ${monitor.screen?.name ?? "?"}: could not set level ${monitor._writingRaw} (exit ${exitCode})`)
                    return
                }
                monitor._writeFailures = 0
                monitor._writtenRaw = monitor._writingRaw
                if (monitor._wantedRaw !== monitor._writtenRaw)
                    monitor._writeNext()
                else if (monitor.isDdc)
                    readbackTimer.restart()
            }
        }

        property var readbackTimer: Timer {
            interval: 1500
            onTriggered: {
                if (!writeProc.running && !monitor.writePending)
                    readbackProc.running = true
            }
        }

        function refresh(): void {
            if (!monitor.ready || writeProc.running || monitor.writePending || readbackProc.running)
                return
            if (monitor.isDdc ? !busNum : root.backlightDevice.length === 0)
                return
            readbackProc.running = true
        }

        readonly property Process readbackProc: Process {
            command: monitor.isDdc
                ? ["ddcutil", "-b", monitor.busNum].concat(BrightnessPolicy.ddcFlags(root._ddcHelp, false), ["getvcp", "10", "--brief"])
                : ["/bin/sh", "-c", "printf '%s %s\\n' \"$(brightnessctl -d \"$1\" g)\" \"$(brightnessctl -d \"$1\" m)\"", "_", root.backlightDevice]
            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = text.trim().split(/\s+/)
                    const current = Number(parts[parts.length - 2])
                    const max = Number(parts[parts.length - 1])
                    if (!Number.isFinite(current) || !Number.isFinite(max) || max <= 0)
                        return
                    // A backlight at 0 is a panel that is off, not a level.
                    if (!monitor.isDdc && current <= 0)
                        return
                    if (writeProc.running || monitor.writePending || monitor._wantedRaw !== monitor._writtenRaw)
                        return
                    monitor.rawMaxBrightness = max
                    monitor._writtenRaw = current
                    monitor._wantedRaw = current
                    if (BrightnessPolicy.rawLevel(monitor.brightness, max, monitor.isDdc) === current)
                        return
                    monitor.ready = false
                    monitor.brightness = current / max
                    monitor.ready = true
                }
            }
        }

        function setBrightness(value: real): void {
            root.lastUserChange = Date.now()
            value = Math.max(0, Math.min(1, value));
            const screenName = monitor.screen?.name ?? ""
            if (screenName && value >= 0.01)
                root.lastValidBrightness[screenName] = value
            monitor.brightness = value;
        }

        function setBrightnessMultiplier(value: real): void {
            monitor.brightnessMultiplier = value;
        }

        Component.onCompleted: {
            initialize();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    // Anti-flashbang
    property int workspaceAnimationDelay: 500
    property int contentSwitchDelay: 30
    property string screenshotDir: "/tmp/quickshell/brightness/antiflashbang"
    function brightnessMultiplierForLightness(x: real): real {
        // I hand picked some values and fitted an exponential curve for this
        // 6.600135 + 216.360356 * e^(-0.0811129189x)
        // Division by 100 is to normalize to [0, 1]
        return (6.600135 + 216.360356 * Math.pow(Math.E, -0.0811129189 * x)) / 100.0;
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            property string screenName: modelData.name
            property string screenshotPath: `${root.screenshotDir}/screenshot-${screenName}.png`
            Connections {
                enabled: (Config.options?.light?.antiFlashbang?.enable ?? false) && Appearance.m3colors.darkmode && CompositorService.isHyprland
                target: CompositorService.isHyprland ? Hyprland : null
                function onRawEvent(event) {
                    if (["activewindowv2", "windowtitlev2"].includes(event.name)) {
                        screenshotTimer.interval = root.contentSwitchDelay;
                        screenshotTimer.restart();
                    } else if (["workspacev2"].includes(event.name)) {
                        screenshotTimer.interval = root.workspaceAnimationDelay;
                        screenshotTimer.restart();
                    }
                }
            }

            // Niri support for anti-flashbang
            Connections {
                enabled: (Config.options?.light?.antiFlashbang?.enable ?? false) && Appearance.m3colors.darkmode && CompositorService.isNiri
                target: CompositorService.isNiri ? NiriService : null
                function onActiveWindowChanged() {
                    screenshotTimer.interval = root.contentSwitchDelay;
                    screenshotTimer.restart();
                }
                function onFocusedWorkspaceIdChanged() {
                    screenshotTimer.interval = root.workspaceAnimationDelay;
                    screenshotTimer.restart();
                }
            }

            Timer {
                id: screenshotTimer
                interval: 700 // This is what I have for a Hyprland ws anim
                onTriggered: {
                    screenshotProc.running = false;
                    screenshotProc.running = true;
                }
            }

            Process {
                id: screenshotProc
                command: ["/usr/bin/bash", "-c", 
                    `/usr/bin/mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}'`
                    + ` && /usr/bin/grim -o '${StringUtils.shellSingleQuoteEscape(screenScope.screenName)}' -`
                    + ` | /usr/bin/magick png:- -colorspace Gray -format "%[fx:mean*100]" info:`
                ]
                stdout: StdioCollector {
                    id: lightnessCollector
                    onStreamFinished: {
                        // No cleanup needed - we pipe directly to magick without saving file
                        const lightness = lightnessCollector.text
                        const newMultiplier = root.brightnessMultiplierForLightness(parseFloat(lightness))
                        Brightness.getMonitorForScreen(screenScope.modelData).setBrightnessMultiplier(newMultiplier)
                    }
                }
            }
        }
    }

    // External trigger points

    IpcHandler {
        target: "brightness"

        function increment(): void {
            root.increaseBrightness();
        }

        function decrement(): void {
            root.decreaseBrightness();
        }

        function refresh(): void {
            root.monitors.forEach(m => m.refresh())
        }

        function set(percent: string): string {
            const value = Number(percent)
            const monitor = root._focusedMonitor()
            if (!monitor || !Number.isFinite(value))
                return "no focused output or bad level"
            monitor.setBrightness(value / 100)
            return root.describe(monitor)
        }

        function status(): string {
            return root.monitors.map(m => root.describe(m)).join("\n")
        }

        function sleepBegin(): void {
            root.sleepBegin();
        }

        function restoreAfterWake(): void {
            root.restoreAfterWake();
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "brightnessIncrease"
                description: "Increase brightness"
                onPressed: root.increaseBrightness()
            }

            GlobalShortcut {
                name: "brightnessDecrease"
                description: "Decrease brightness"
                onPressed: root.decreaseBrightness()
            }
        }
    }
}
