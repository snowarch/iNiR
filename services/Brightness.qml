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

    property var ddcMonitors: []
    property list<BrightnessMonitor> monitors: []
    property string backlightDevice: ""
    property bool backlightDetectionReady: false
    property int _bestBacklightMax: 0
    // last >0 level per screen.name; survives monitor recreation after dpms
    property var lastValidBrightness: ({})
    property bool asleep: false
    property var _sleepDisabledOutputs: []
    property var _knownExternals: []
    property int _wakeRetryAttempt: 0
    property var _niriQueue: []
    property bool _niriBusy: false

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

    function _enqueueNiri(args): void {
        root._niriQueue = root._niriQueue.concat([args])
        root._drainNiriQueue()
    }

    function _drainNiriQueue(): void {
        if (root._niriBusy || root._niriQueue.length === 0)
            return
        const next = root._niriQueue[0]
        root._niriQueue = root._niriQueue.slice(1)
        root._niriBusy = true
        niriSerialProc.command = next
        niriSerialProc.running = false
        niriSerialProc.running = true
    }

    function _rememberExternals(): void {
        root._knownExternals = BrightnessPolicy.mergeOutputNames(
            root._knownExternals,
            BrightnessPolicy.outputsToPinOff(root._connectedNames()))
    }

    function sleepBegin(): void {
        if (!CompositorService.isNiri)
            return
        wakeRetryTimer.stop()
        root._wakeRetryAttempt = 0
        root.asleep = true
        const connected = root._connectedNames()
        root._sleepDisabledOutputs = BrightnessPolicy.preservePinnedOnRepeatedSleep(
            root._sleepDisabledOutputs, connected)
        root._knownExternals = BrightnessPolicy.mergeOutputNames(
            root._knownExternals, root._sleepDisabledOutputs)
        const cmds = BrightnessPolicy.sleepCommandQueue(connected)
        for (let i = 0; i < cmds.length; ++i)
            root._enqueueNiri(cmds[i])
    }

    function _tryWakeOutputs(): void {
        const names = BrightnessPolicy.mergeOutputNames(root._sleepDisabledOutputs, root._knownExternals)
        root._sleepDisabledOutputs = names
        for (let i = 0; i < names.length; ++i)
            root._enqueueNiri(BrightnessPolicy.niriOutputOnArgs(names[i]))
    }

    function _pollNiriOutputs(): void {
        niriOutputsProc.running = false
        niriOutputsProc.running = true
    }

    function restoreAfterWake(): void {
        if (!CompositorService.isNiri) {
            root.asleep = false
            return
        }
        const cmds = BrightnessPolicy.wakeCommandQueue(
            BrightnessPolicy.mergeOutputNames(root._sleepDisabledOutputs, root._knownExternals))
        for (let i = 0; i < cmds.length; ++i)
            root._enqueueNiri(cmds[i])
        root.asleep = false
        root._wakeRetryAttempt = 0
        root._pollNiriOutputs()
        wakeRetryTimer.restart()
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
        onExited: {
            root._niriBusy = false
            root._drainNiriQueue()
        }
    }

    Process {
        id: niriOutputsProc
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            id: niriOutputsOut
            onStreamFinished: {
                const extra = BrightnessPolicy.disabledExternalOutputNames(niriOutputsOut.text)
                root._sleepDisabledOutputs = BrightnessPolicy.mergeOutputNames(root._sleepDisabledOutputs, extra)
                root._knownExternals = BrightnessPolicy.mergeOutputNames(root._knownExternals, extra)
                root._tryWakeOutputs()
            }
        }
    }

    Timer {
        id: wakeRetryTimer
        interval: 400
        repeat: true
        onTriggered: {
            root._wakeRetryAttempt++
            if (!BrightnessPolicy.shouldRetryWakeOutput(root._wakeRetryAttempt, BrightnessPolicy.wakeOutputRetryLimit())) {
                stop()
                root._wakeRetryAttempt = 0
                return
            }
            root._pollNiriOutputs()
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
            if (root._ddcNext.length > 0)
                root.ddcMonitors = root._ddcNext
            root._ddcNext = []
            root.ddcMonitorsChanged()
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
            syncBrightness()
            if (monitor.isDdc)
                ddcRetryTimer.restart()
        }

        function initialize() {
            monitor.ready = false;
            if (isDdc) {
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"]
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
                    const resolved = BrightnessPolicy.resolveHardwareBrightness(current, max, lastGood)
                    if (Number.isFinite(resolved.rawMax))
                        monitor.rawMaxBrightness = resolved.rawMax
                    if (Number.isFinite(resolved.value)) {
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
                if (monitor.ready)
                    return
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

        property var ddcRetryTimer: Timer {
            interval: 800
            onTriggered: monitor.syncBrightness()
        }

        // Coalesce animation frames. DDC needs a longer debounce; backlight
        // devices are capped near 30 writes/second so high-range AMD devices do
        // not spawn a process for every QML animation frame. Fixes #188.
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 32
            onTriggered: {
                if (!monitor.writePending) return
                monitor.writePending = false
                syncBrightness();
            }
        }

        function syncBrightness() {
            const brightnessValue = monitor.multipliedBrightness
            if (!Number.isFinite(brightnessValue) || brightnessValue < 0.01)
                return
            const rawValueRounded = Math.max(Math.floor(brightnessValue * monitor.rawMaxBrightness), 1);
            if (isDdc) {
                if (!busNum)
                    return
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", `${rawValueRounded}`]);
            } else if (root.backlightDevice.length > 0) {
                Quickshell.execDetached(["brightnessctl", "-d", root.backlightDevice,
                    "s", `${rawValueRounded}`, "--quiet"]);
            }
        }

        function setBrightness(value: real): void {
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
