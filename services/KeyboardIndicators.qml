pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

Singleton {
    id: root

    property list<string> capsLockPaths: []
    property list<string> numLockPaths: []
    property var _capsLockStates: ({})
    property var _numLockStates: ({})
    property string _knownLayoutName: ""
    property string _lockSource: "unknown"
    property bool _destroying: false
    property bool _numLockReliable: false
    property var _lastRawNumLockState: null
    property string lockStateDaemonPath: Quickshell.shellPath("scripts/daemon/keyboard_lock_state_daemon.py")

    property bool capsLock: false
    property bool numLock: false
    property bool ready: false
    property string popupKind: ""
    property bool popupActive: false
    property string popupText: ""
    property int popupSequence: 0

    readonly property bool showPopup: Config.options?.keyboardIndicators?.showPopup ?? true
    readonly property bool showPanel: Config.options?.keyboardIndicators?.showPanel ?? true
    readonly property bool showLayoutPopup: root.showPopup && (Config.options?.keyboardIndicators?.popup?.layout ?? true)
    readonly property bool showCapsPopup: root.showPopup && (Config.options?.keyboardIndicators?.popup?.caps ?? true)
    readonly property bool showNumPopup: root.showPopup && (Config.options?.keyboardIndicators?.popup?.num ?? false)
    readonly property bool showLayoutPanel: root.showPanel && (Config.options?.keyboardIndicators?.panel?.layout ?? true)
    readonly property bool showCapsPanel: root.showPanel && (Config.options?.keyboardIndicators?.panel?.caps ?? true)
    readonly property bool showNumPanel: root.showPanel && (Config.options?.keyboardIndicators?.panel?.num ?? false)
    readonly property bool hasMultipleLayouts: (HyprlandXkb.layoutCodes?.length ?? 0) > 1
    readonly property string currentLayoutName: HyprlandXkb.currentLayoutName ?? ""
    readonly property string currentLayoutCode: HyprlandXkb.currentLayoutCode ?? ""
    readonly property string capsMaterialIcon: "keyboard_capslock"
    readonly property string numMaterialIcon: "dialpad"
    readonly property string capsFluentIcon: "key"
    readonly property string numFluentIcon: "keyboard-dock"
    readonly property string popupMaterialIcon: root.popupKind === "layout" ? "language"
        : root.popupKind === "caps" ? root.capsMaterialIcon
        : root.numMaterialIcon
    readonly property string popupFluentIcon: root.popupKind === "layout" ? "keyboard"
        : root.popupKind === "caps" ? root.capsFluentIcon
        : root.numFluentIcon
    readonly property string currentLayoutCodeMultiline: root.abbreviateLayoutCode(root.currentLayoutCode, "\n")
    readonly property string currentLayoutCodeInline: root.abbreviateLayoutCode(root.currentLayoutCode, " ").toUpperCase()
    readonly property bool usingEvdev: root._lockSource === "evdev"
    readonly property bool layoutVisible: root.showLayoutPanel && root.hasMultipleLayouts && root.currentLayoutCode.length > 0
    readonly property bool capsLockVisible: root.showCapsPanel && root.capsLock
    readonly property bool numLockVisible: root.showNumPanel && root.numLock
    readonly property bool hasPanelIndicators: root.layoutVisible || root.capsLockVisible || root.numLockVisible

    function _log(...args) {
        if (Quickshell.env("QS_DEBUG") === "1")
            console.log("[KeyboardIndicators]", ...args);
    }

    function abbreviateLayoutCode(fullCode, separator) {
        if (!fullCode || !fullCode.length)
            return "";

        return fullCode.split(":").map(layout => {
            const baseLayout = layout.split("-")[0];
            return baseLayout.slice(0, 4);
        }).join(separator);
    }

    function refreshLedPaths() {
        if (root.usingEvdev)
            return;
        if (!ledDiscoveryProc.running)
            ledDiscoveryProc.running = true;
    }

    function _setCapsLockValue(nextValue, allowPopup) {
        const previousValue = root.capsLock;
        root.capsLock = nextValue;
        if (allowPopup && previousValue !== nextValue)
            root._emitLockPopup("caps", nextValue);
    }

    function _setNumLockValue(nextValue, allowPopup) {
        const previousValue = root.numLock;
        root.numLock = nextValue;
        if (allowPopup && previousValue !== nextValue)
            root._emitLockPopup("num", nextValue);
    }

    function _setEvdevState(nextCapsValue, nextNumValue, allowPopup) {
        root._lockSource = "evdev";
        root._setCapsLockValue(nextCapsValue, allowPopup);
        root._setNumLockRawValue(nextNumValue, allowPopup);
    }

    function _handleEvdevOutput(rawLine) {
        const trimmed = String(rawLine).trim();
        if (!trimmed.length)
            return;

        try {
            const payload = JSON.parse(trimmed);
            if (payload.type !== "state")
                return;

            root._setEvdevState(Boolean(payload.caps), Boolean(payload.num), true);
        } catch (error) {
            root._log("Failed to parse evdev output", trimmed, error);
        }
    }

    function _enableSysfsFallback() {
        if (root.usingEvdev)
            return;

        root._lockSource = "sysfs";
        root.refreshLedPaths();
    }

    function _setPopup(kind, active, text) {
        if (!root.ready)
            return;

        if (kind === "layout" && !root.showLayoutPopup)
            return;

        if (kind === "caps" && !root.showCapsPopup)
            return;

        if (kind === "num" && !root.showNumPopup)
            return;

        root.popupKind = kind;
        root.popupActive = active;
        root.popupText = text;
        root.popupSequence += 1;
    }

    function _emitLockPopup(kind, active) {
        if (kind === "caps") {
            root._setPopup(kind, active, active ? Translation.tr("Caps Lock on") : Translation.tr("Caps Lock off"));
            return;
        }

        root._setPopup(kind, active, active ? Translation.tr("Num Lock on") : Translation.tr("Num Lock off"));
    }

    function _emitLayoutPopup() {
        if (!root.hasMultipleLayouts || !root.currentLayoutName.length)
            return;

        root._setPopup("layout", true, root.currentLayoutName);
    }

    function _hasKnownState(paths, states) {
        return paths.some(path => states[path] !== null && states[path] !== undefined);
    }

    function _setLockPaths(kind, paths) {
        if (root.usingEvdev)
            return;

        const uniquePaths = [...new Set(paths)].sort();
        const previousStates = kind === "caps" ? root._capsLockStates : root._numLockStates;
        const nextStates = {};

        for (const path of uniquePaths)
            nextStates[path] = previousStates.hasOwnProperty(path) ? previousStates[path] : null;

        if (kind === "caps") {
            root.capsLockPaths = uniquePaths;
            root._capsLockStates = nextStates;
            if (!uniquePaths.length)
                root.capsLock = false;
            root._recomputeLockState(kind, false);
            return;
        }

        root.numLockPaths = uniquePaths;
        root._numLockStates = nextStates;
        if (!uniquePaths.length) {
            root._numLockReliable = false;
            root._lastRawNumLockState = null;
            root.numLock = false;
        }
        root._recomputeLockState(kind, false);
    }

    function _setLockState(kind, path, rawValue) {
        if (root.usingEvdev)
            return;

        const nextValue = Number(String(rawValue).trim()) > 0;

        if (kind === "caps") {
            root._capsLockStates = Object.assign({}, root._capsLockStates, { [path]: nextValue });
            root._recomputeLockState(kind, true);
            return;
        }

        root._numLockStates = Object.assign({}, root._numLockStates, { [path]: nextValue });
        root._recomputeLockState(kind, true);
    }

    function _clearLockState(kind, path) {
        if (root.usingEvdev)
            return;

        if (kind === "caps") {
            root._capsLockStates = Object.assign({}, root._capsLockStates, { [path]: null });
            root._recomputeLockState(kind, false);
            return;
        }

        root._numLockStates = Object.assign({}, root._numLockStates, { [path]: null });
        root._recomputeLockState(kind, false);
    }

    function _setNumLockRawValue(nextValue, allowPopup) {
        const previousVisibleValue = root._numLockReliable ? root.numLock : root._lastRawNumLockState;

        if (root._lastRawNumLockState === null) {
            root._lastRawNumLockState = nextValue;
            root._numLockReliable = !nextValue;
        } else if (nextValue !== root._lastRawNumLockState) {
            root._lastRawNumLockState = nextValue;
            root._numLockReliable = true;
        }

        root._setNumLockValue(root._numLockReliable ? nextValue : false, false);
        if (root._numLockReliable && allowPopup && previousVisibleValue !== null && previousVisibleValue !== root.numLock)
            root._emitLockPopup("num", root.numLock);
    }

    function _recomputeLockState(kind, allowPopup) {
        const paths = kind === "caps" ? root.capsLockPaths : root.numLockPaths;
        const states = kind === "caps" ? root._capsLockStates : root._numLockStates;

        if (paths.length > 0 && !root._hasKnownState(paths, states))
            return;

        const nextValue = paths.some(path => states[path] === true);

        if (kind === "caps") {
            root._setCapsLockValue(nextValue, allowPopup);
            return;
        }

        if (!paths.length) {
            root._numLockReliable = false;
            root._lastRawNumLockState = null;
            root.numLock = false;
            return;
        }

        root._setNumLockRawValue(nextValue, allowPopup);
    }

    Process {
        id: evdevProbeProc
        running: false
        command: ["/usr/bin/python3", root.lockStateDaemonPath, "--once"]

        stdout: SplitParser {
            onRead: line => root._handleEvdevOutput(line)
        }

        stderr: SplitParser {
            onRead: line => root._log("evdev probe", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (!evdevMonitorProc.running)
                    evdevMonitorProc.running = true;
                return;
            }

            root._log("evdev probe exited", exitCode, exitStatus);
            root._enableSysfsFallback();
        }
    }

    Timer {
        id: evdevRestartTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            if (!root._destroying && root.usingEvdev && !evdevMonitorProc.running)
                evdevMonitorProc.running = true;
        }
    }

    Process {
        id: evdevMonitorProc
        running: false
        command: ["/usr/bin/python3", "-u", root.lockStateDaemonPath]

        stdout: SplitParser {
            onRead: line => root._handleEvdevOutput(line)
        }

        stderr: SplitParser {
            onRead: line => root._log("evdev monitor", line)
        }

        onExited: (exitCode, exitStatus) => {
            if (root._destroying)
                return;

            root._log("evdev monitor exited", exitCode, exitStatus);
            if (root.usingEvdev) {
                evdevRestartTimer.restart();
                return;
            }

            root._enableSysfsFallback();
        }
    }

    Process {
        id: ledDiscoveryProc
        running: false
        command: ["/usr/bin/bash", "-lc", "printf 'capslock\\n'; for f in /sys/class/leds/*::capslock/brightness; do [ -e \"$f\" ] && printf '%s\\n' \"$f\"; done; printf 'numlock\\n'; for f in /sys/class/leds/*::numlock/brightness; do [ -e \"$f\" ] && printf '%s\\n' \"$f\"; done"]

        stdout: StdioCollector {
            id: ledCollector

            onStreamFinished: {
                let section = "";
                const nextCapsPaths = [];
                const nextNumPaths = [];

                for (const rawLine of ledCollector.text.split("\n")) {
                    const line = rawLine.trim();
                    if (!line.length)
                        continue;
                    if (line === "capslock" || line === "numlock") {
                        section = line;
                        continue;
                    }
                    if (section === "capslock")
                        nextCapsPaths.push(line);
                    else if (section === "numlock")
                        nextNumPaths.push(line);
                }

                root._setLockPaths("caps", nextCapsPaths);
                root._setLockPaths("num", nextNumPaths);
            }
        }
    }

    Timer {
        id: readyTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            root.ready = true;
            root._knownLayoutName = root.currentLayoutName;
        }
    }

    Timer {
        interval: 8000
        running: !root.usingEvdev
        repeat: true
        onTriggered: root.refreshLedPaths()
    }

    Instantiator {
        model: root.capsLockPaths

        FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            onFileChanged: reload()
            onLoaded: root._setLockState("caps", modelData, text())
            onLoadFailed: root._clearLockState("caps", modelData)
        }
    }

    Instantiator {
        model: root.numLockPaths

        FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            onFileChanged: reload()
            onLoaded: root._setLockState("num", modelData, text())
            onLoadFailed: root._clearLockState("num", modelData)
        }
    }

    Connections {
        target: HyprlandXkb

        function onCurrentLayoutNameChanged() {
            if (!root.currentLayoutName.length)
                return;
            if (!root._knownLayoutName.length) {
                root._knownLayoutName = root.currentLayoutName;
                return;
            }
            if (root._knownLayoutName === root.currentLayoutName)
                return;

            root._knownLayoutName = root.currentLayoutName;
            root._emitLayoutPopup();
        }
    }

    Component.onCompleted: {
        root._knownLayoutName = root.currentLayoutName;
        evdevProbeProc.running = true;
    }

    Component.onDestruction: root._destroying = true
}
