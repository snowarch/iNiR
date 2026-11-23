pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services.deferred

/**
 * A nice wrapper for default Pipewire audio sink and source.
 */
Singleton {
    id: root

    // Misc props
    property bool ready: sink?.ready ?? rawSink?.ready ?? false
    readonly property PwNode rawSink: Pipewire.defaultAudioSink
    property PwNode _pendingSink: null
    readonly property PwNode defaultSink: root._pendingSink ?? rawSink
    property PwNode sink: root._pendingSink ?? root.resolveControllableSink(rawSink)
    property PwNode source: Pipewire.defaultAudioSource

    // When QS catches up and rawSink changes, clear the pending override
    onRawSinkChanged: {
        if (root._pendingSink) root._pendingSink = null
    }
    readonly property real hardMaxValue: 2.00
    readonly property real ceiling: Math.min(root.hardMaxValue, (Config.options?.audio?.protection?.maxAllowed ?? 100) / 100)
    property real value: sink?.audio?.volume ?? rawSink?.audio?.volume ?? 0
    property bool micBeingAccessed: Pipewire.links.values.filter(link =>
        !link.source.isStream && !link.source.isSink && link.target.isStream
    ).length > 0

    property bool _micMuted: false
    // Tracked explicitly rather than bound to source.audio.volume: setSourceVolume()
    // assigns to this imperatively, which would destroy a declarative binding for
    // good — after the first mic adjustment the shell would stop seeing volume
    // changes made anywhere else (pavucontrol, another app).
    property real _micVolume: 0
    readonly property bool micMuted: _micMuted
    readonly property real micVolume: _micVolume

    Connections {
        target: root.source?.audio ?? null
        function onVolumeChanged(): void {
            root._micVolume = root.source?.audio?.volume ?? 0
        }
    }

    onSourceChanged: {
        root._micVolume = root.source?.audio?.volume ?? 0
        _refreshMicState()
    }

    function friendlyDeviceName(node) {
        return node ? (node.nickname || node.description || Translation.tr("Unknown")) : Translation.tr("Unknown");
    }
    // The app behind a stream, not its engine: an app playing through mpv or GStreamer names itself "mpv".
    function appNodeDisplayName(node) {
        if (!node) return Translation.tr("Unknown");
        return MprisController.streamDisplayName(node)
    }

    function resolveControllableSink(node) {
        if (!node || !node.audio)
            return node

        const props = node.properties ?? {}
        const nodeName = String(props["node.name"] ?? node.name ?? "")
        const applicationId = String(props["application.id"] ?? "")
        const isVirtual = String(props["node.virtual"] ?? "false") === "true"
        const isPassthrough = String(props["monitor.passthrough"] ?? "false") === "true"
        const driverId = Number(props["node.driver-id"] ?? 0)
        const isEasyEffectsSink = nodeName === "easyeffects_sink"
            || applicationId === "com.github.wwmm.easyeffects"
            || (isVirtual && isPassthrough)

        if (!isEasyEffectsSink || !Number.isFinite(driverId) || driverId <= 0)
            return node

        const physicalSink = Pipewire.nodes.values.find(candidate =>
            root.correctType(candidate, true)
            && !candidate.isStream
            && Number(candidate.id ?? 0) === driverId
        )

        if (physicalSink) return physicalSink

        // Keep EasyEffects sink if physical mapping is unavailable.
        // Avoid picking an arbitrary non-virtual sink during reconnect/profile churn.
        return node
    }

    // Lists
    function correctType(node, isSink) {
        return (node.isSink === isSink) && node.audio
    }
    function appNodes(isSink) {
        return Pipewire.nodes.values.filter((node) => {
            return root.correctType(node, isSink) && node.isStream
        })
    }
    function devices(isSink) {
        return Pipewire.nodes.values.filter(node => {
            return root.correctType(node, isSink) && !node.isStream
        })
    }
    readonly property list<var> outputAppNodes: root.appNodes(true)
    readonly property list<var> inputAppNodes: root.appNodes(false)
    readonly property list<var> outputDevices: root.devices(true)
    readonly property list<var> inputDevices: root.devices(false)

    // Signals
    signal sinkProtectionTriggered(string reason);
    property real lastUserChange: 0

    // Controls
    function toggleMute() {
        if (!root.sink?.audio) return;
        root.lastUserChange = Date.now()
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function setSourceVolume(target: real): void {
        root.lastUserChange = Date.now()
        const clamped = Math.max(0, Math.min(root.hardMaxValue, target))
        root._micVolume = clamped
        root._queueSourceVolume(clamped)
    }

    function toggleMicMute() {
        root.lastUserChange = Date.now()
        const shouldMute = !root._micMuted
        root._micMuted = shouldMute
        const muteVal = shouldMute ? "1" : "0"
        // Mute every source device (hardware + virtual like EasyEffects)
        // so apps reading directly from hardware are also silenced.
        for (const dev of root.inputDevices) {
            const nodeId = Number(dev.id ?? 0)
            if (Number.isFinite(nodeId) && nodeId > 0)
                Quickshell.execDetached(["wpctl", "set-mute", String(nodeId), muteVal])
        }
        wpctlSetMicMute.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", muteVal])
    }

    function _isVirtualSource(dev): bool {
        const props = dev?.properties ?? {}
        const nodeName = String(props["node.name"] ?? dev?.name ?? "")
        const appId = String(props["application.id"] ?? "")
        return nodeName === "easyeffects_source" || appId === "com.github.wwmm.easyeffects"
            || String(props["node.virtual"] ?? "false") === "true"
    }

    function _hardwareSourceId(): int {
        // The default source is the one setSourceVolume() writes; read it back
        // whenever it is a real device. Reading the first hardware input instead
        // snapped the level back to an unrelated device (e.g. a USB mic as default
        // beside an onboard input at 100 %) after every adjustment.
        const defaultId = Number(root.source?.id ?? 0)
        if (defaultId > 0 && !root._isVirtualSource(root.source)) return defaultId
        for (const dev of root.inputDevices) {
            if (root._isVirtualSource(dev)) continue
            const id = Number(dev.id ?? 0)
            if (id > 0) return id
        }
        return 0
    }

    function _refreshMicState(): void {
        const hwId = root._hardwareSourceId()
        const target = hwId > 0 ? String(hwId) : "@DEFAULT_AUDIO_SOURCE@"
        _wpctlGetMicState.exec(["wpctl", "get-volume", target])
    }

    Process {
        id: wpctlSetDefaultDevice
        command: ["wpctl", "set-default", "0"]
        onExited: {
            // After switching default sink, immediately nudge volume via wpctl so
            // USB/device-route sinks (e.g. USB mic used as output) get their volume
            // state initialised in PipeWire without requiring pavucontrol interaction.
            root._queueSinkVolume(root.sink?.audio?.volume ?? 0.5)
        }
    }

    property real _queuedSinkVolume: 0
    property bool _sinkVolumePending: false
    property real _queuedSourceVolume: 0
    property bool _sourceVolumePending: false

    function _queueSinkVolume(value: real): void {
        root._queuedSinkVolume = value
        root._sinkVolumePending = true
        if (!wpctlSetSinkVolume.running && !sinkVolumeDispatch.running)
            sinkVolumeDispatch.start()
    }

    function _queueSourceVolume(value: real): void {
        root._queuedSourceVolume = value
        root._sourceVolumePending = true
        if (!wpctlSetSourceVolume.running && !sourceVolumeDispatch.running)
            sourceVolumeDispatch.start()
    }

    Timer {
        id: sinkVolumeDispatch
        interval: 16
        onTriggered: {
            if (wpctlSetSinkVolume.running || !root._sinkVolumePending)
                return
            root._sinkVolumePending = false
            wpctlSetSinkVolume.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(root._queuedSinkVolume)]
            wpctlSetSinkVolume.running = true
        }
    }

    Timer {
        id: sourceVolumeDispatch
        interval: 16
        onTriggered: {
            if (wpctlSetSourceVolume.running || !root._sourceVolumePending)
                return
            root._sourceVolumePending = false
            wpctlSetSourceVolume.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", String(root._queuedSourceVolume)]
            wpctlSetSourceVolume.running = true
        }
    }

    // Sink volume via wpctl — fallback for devices whose volume control lives at
    // the PipeWire device-route level and is not reachable through the QML binding.
    Process {
        id: wpctlSetSinkVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1.0"]
        onExited: if (root._sinkVolumePending) sinkVolumeDispatch.restart()
    }

    // Relative increment/decrement — does not require reading current volume from QML,
    // so it works even when Quickshell has not yet tracked the USB sink node.
    Process {
        id: wpctlIncrementSinkVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "2%+"]
    }

    Process {
        id: wpctlDecrementSinkVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "2%-"]
    }

    Process {
        id: wpctlSetMicMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1"]
        onExited: root._refreshMicState()
    }

    Process {
        id: wpctlSetSourceVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "1.0"]
        onExited: {
            if (root._sourceVolumePending)
                sourceVolumeDispatch.restart()
            else
                root._refreshMicState()
        }
    }

    Process {
        id: _wpctlGetMicState
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector { id: _micStateCollector }
        onExited: (exitCode, _exitStatus) => {
            if (exitCode !== 0) return
            const out = (_micStateCollector.text?.trim() ?? "")
            if (!out.length) return
            root._micMuted = out.toUpperCase().includes("MUTED")
            const match = out.match(/Volume:\s*([0-9]*\.?[0-9]+)/i)
            if (match && match[1] !== undefined) {
                const parsed = Number(match[1])
                if (Number.isFinite(parsed))
                    root._micVolume = Math.max(0, Math.min(root.hardMaxValue, parsed))
            }
        }
    }

    // Set sink volume safely. When protection is enabled, large jumps are rejected.
    // To keep UX consistent with brightness (click anywhere on slider), we ramp in small steps.
    // The queued wpctl path also works while Quickshell is rebuilding its node bindings.
    function setSinkVolume(target: real): void {
        root.lastUserChange = Date.now()
        const maxAllowed = (Config.options?.audio?.protection?.maxAllowed ?? 100) / 100;
        const clamped = Math.max(0, Math.min(Math.min(maxAllowed, root.hardMaxValue), target));

        const protectionEnabled = (Config.options?.audio?.protection?.enable ?? false);
        if (!protectionEnabled) {
            root._queueSinkVolume(clamped)
            return;
        }

        root._rampTarget = clamped;
        // Start, never restart: a slider dragged faster than 16 ms per event kept pushing the first step back.
        if (!root._rampTimer.running) root._rampTimer.start();
    }

    // Ramp helper (keeps the guard from rejecting a jump when user clicks far away on slider)
    property real _rampTarget: 0
    property alias _rampTimer: _rampTimerInternal
    Timer {
        id: _rampTimerInternal
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            if (!root.sink?.audio) {
                root._queueSinkVolume(root._rampTarget)
                running = false;
                return;
            }

            const protectionEnabled = (Config.options?.audio?.protection?.enable ?? false);
            if (!protectionEnabled) {
                root._queueSinkVolume(root._rampTarget)
                running = false;
                return;
            }

            const maxStep = (Config.options?.audio?.protection?.maxAllowedIncrease ?? 10) / 100;
            const step = Math.max(0.005, maxStep * 0.8); // Stay below protection threshold
            const current = root.sink.audio.volume;
            const diff = root._rampTarget - current;
            if (Math.abs(diff) <= step) {
                root._queueSinkVolume(root._rampTarget)
                running = false;
                return;
            }
            root._queueSinkVolume(current + Math.sign(diff) * step)
        }
    }

    function incrementVolume() {
        root.lastUserChange = Date.now()
        root.playEvent("volume")
        // Fire wpctl relative increment first — works even when sink?.audio is not yet tracked.
        if (!wpctlIncrementSinkVolume.running)
            wpctlIncrementSinkVolume.running = true
    }

    function decrementVolume() {
        root.lastUserChange = Date.now()
        root.playEvent("volume")
        // Fire wpctl relative decrement first — works even when sink?.audio is not yet tracked.
        if (!wpctlDecrementSinkVolume.running)
            wpctlDecrementSinkVolume.running = true
    }

    function setDefaultNode(node, isSink: bool): void {
        if (!node) return

        if (isSink) {
            root._pendingSink = node
            Pipewire.preferredDefaultAudioSink = node;
        } else {
            Pipewire.preferredDefaultAudioSource = node;
        }

        const nodeId = Number(node.id ?? 0)
        if (!Number.isFinite(nodeId) || nodeId <= 0 || wpctlSetDefaultDevice.running)
            return

        wpctlSetDefaultDevice.command = ["wpctl", "set-default", String(nodeId)]
        wpctlSetDefaultDevice.running = true
    }

    function setDefaultSink(node) {
        root.setDefaultNode(node, true)
    }

    function setDefaultSource(node) {
        root.setDefaultNode(node, false)
    }

    // Internals
    PwObjectTracker {
        objects: [rawSink, sink, source]
            .concat(root.outputAppNodes ?? [])
            .concat(root.inputAppNodes ?? [])
            .filter(node => node)
    }

    // Reset protection state and stop any in-flight ramp when sink changes so
    // the new sink's initial volume isn't compared against the old sink's level
    // and we don't apply a stale ramp target to the wrong device.
    onSinkChanged: {
        _sinkProtectionConn.lastReady = false
        _sinkProtectionConn.lastVolume = 0
        _rampTimerInternal.running = false
    }

    Connections { // Protection against sudden volume changes
        id: _sinkProtectionConn
        target: sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            if (!(Config.options?.audio?.protection?.enable ?? false)) return;
            if (!sink?.ready || !sink?.audio) return;
            const newVolume = sink.audio.volume;
            // when resuming from suspend, we should not write volume to avoid pipewire volume reset issues
            if (isNaN(newVolume) || newVolume === undefined || newVolume === null) {
                lastReady = false;
                lastVolume = 0;
                return;
            }
            if (!lastReady) {
                lastVolume = newVolume;
                lastReady = true;
                return;
            }
            const maxAllowedIncrease = (Config.options?.audio?.protection?.maxAllowedIncrease ?? 10) / 100; 
            const maxAllowed = (Config.options?.audio?.protection?.maxAllowed ?? 99) / 100;

            if (newVolume - lastVolume > maxAllowedIncrease) {
                root._queueSinkVolume(lastVolume)
                root.sinkProtectionTriggered(Translation.tr("It rose more than %1% at once").arg(Math.round(maxAllowedIncrease * 100)));
                return
            } else if (newVolume > maxAllowed || newVolume > root.hardMaxValue) {
                root.sinkProtectionTriggered(Translation.tr("%1% is the most allowed").arg(Math.round(maxAllowed * 100)));
                lastVolume = Math.min(lastVolume, maxAllowed)
                root._queueSinkVolume(lastVolume)
                return
            }
            lastVolume = newVolume;
        }
    }

    // Session sounds (sounds.session) greet the desktop; interface sounds (sounds.ui) answer what you do, at their own
    // volume, and keep quiet while a game holds the screen. The rest are alerts, which their callers gate.
    readonly property var sessionEvents: ["boot", "login", "lock"]
    readonly property var uiEvents: ["open", "close", "navigate", "select", "toggleOn", "toggleOff", "volume", "screenshot", "error", "deviceAdded", "deviceRemoved"]

    // Sound packs are folders of <event>.oga: ours in assets/sounds (made by assets/sounds/generate.py), yours in
    // ~/.local/share/inir/sounds/<name>/, where any of .oga, .ogg, .wav, .flac or .mp3 plays. Every sound is the shell's
    // own: an event a pack of yours has no file for plays Aurora's.
    readonly property var builtinPacks: ["aurora", "tactile", "lounge", "orbit", "crystal", "arcade"]
    property var userPacks: []
    readonly property string soundPack: Config.options?.sounds?.pack ?? "aurora"
    // Every pack a person can choose, in the order settings list them.
    readonly property var packs: root.builtinPacks.concat(root.userPacks)
    function packLabel(pack: string): string {
        return root.builtinPacks.includes(pack) ? pack.charAt(0).toUpperCase() + pack.slice(1) : pack
    }
    // What an event plays with no choice of its own.
    readonly property string packInUseLabel: Translation.tr("Sound pack (%1)").arg(root.packLabel(root.soundPack))
    // A new pack answers at once with its notification, so a choice is heard where it is made.
    onSoundPackChanged: if (Config.ready && GlobalStates.shellEntryReady) root.previewEvent("notification", root.soundPack)
    function packDir(pack: string): string {
        return root.builtinPacks.includes(pack) ? Quickshell.shellPath("assets/sounds/" + pack) : Directories.soundPacksPath + "/" + pack
    }
    function refreshPacks(): void {
        userPacksProc.running = false
        userPacksProc.running = true
    }
    Process {
        id: userPacksProc
        command: ["/bin/sh", "-c", 'for d in "$1"/*/; do [ -d "$d" ] && basename "$d"; done 2>/dev/null', "sh", Directories.soundPacksPath]
        stdout: StdioCollector {
            onStreamFinished: root.userPacks = text.split("\n").map(name => name.trim())
                .filter(name => name.length > 0 && !root.builtinPacks.includes(name))
        }
    }

    // One sound per event at a time: a held key or a burst of opens would stack copies of the same tick.
    property var _lastPlayed: ({})
    function _settled(eventId: string): bool {
        const now = Date.now()
        if (now - (root._lastPlayed[eventId] ?? 0) < 70) return false
        root._lastPlayed[eventId] = now
        return true
    }

    // Play a shell event sound: the person's choice for it first ("" = the pack in use, a pack's name = that pack's
    // sound, an absolute path or file:// = that file), then the pack's own file.
    function playEvent(eventId: string): void {
        const sounds = Config.options?.sounds ?? ({})
        const ui = root.uiEvents.includes(eventId)
        if (ui && (!(sounds.ui ?? false) || GameMode.active)) return
        if (root.sessionEvents.includes(eventId) && !(sounds.session ?? true)) return
        if (!root._settled(eventId)) return
        root._play(eventId, root.soundPack, ui ? (sounds.uiVolume ?? 0.6) : (sounds.volume ?? 0.5), true)
    }

    // Hear an event in a pack whatever is switched on: settings previews, and callers with a switch of their own.
    function previewEvent(eventId: string, pack: string): void {
        const sounds = Config.options?.sounds ?? ({})
        root._play(eventId, pack || root.soundPack,
            root.uiEvents.includes(eventId) ? (sounds.uiVolume ?? 0.6) : (sounds.volume ?? 0.5), pack === "" || pack === undefined)
    }

    function _play(eventId: string, pack: string, volume: real, honorOverride: bool): void {
        const override = honorOverride ? String(Config.options?.sounds?.events?.[eventId] ?? "") : ""
        if (override.startsWith("/") || override.startsWith("file://")) {
            Quickshell.execDetached(["pw-play", "--volume", String(volume), override.startsWith("file://") ? override.slice(7) : override])
            return
        }
        Quickshell.execDetached(["/bin/sh", "-c",
            'for d in "$1" "$4"; do for f in "$d/$2.oga" "$d/$2.ogg" "$d/$2.wav" "$d/$2.flac" "$d/$2.mp3"; do '
            + '[ -f "$f" ] && exec pw-play --volume "$3" "$f"; done; done',
            "sh", root.packDir(override.length > 0 ? override : pack), eventId, String(volume), root.packDir(root.builtinPacks[0])])
    }

    // Panels opening and closing, whichever family draws them.
    readonly property var _panelFlags: ["sidebarLeftOpen", "sidebarRightOpen", "overviewOpen", "searchOpen", "sessionOpen",
        "settingsOverlayOpen", "controlPanelOpen", "dashboardOpen", "clipboardOpen", "wallpaperSelectorOpen", "cheatsheetOpen",
        "mediaControlsOpen", "familyQuickSettingsOpen", "familyNotificationsOpen"]
    readonly property int openPanels: root._panelFlags.filter(flag => GlobalStates[flag] === true).length
    property int _openPanelsBefore: 0
    onOpenPanelsChanged: {
        const before = root._openPanelsBefore
        root._openPanelsBefore = root.openPanels
        if (!GlobalStates.shellEntryReady) return
        // Choosing a result closes its panel: the choice already spoke for both.
        if (root.openPanels < before && Date.now() - (root._lastPlayed["select"] ?? 0) < 400) return
        root.playEvent(root.openPanels > before ? "open" : "close")
    }

    Connections {
        target: GlobalStates
        function onSettingsOverlayOpenChanged(): void {
            if (GlobalStates.settingsOverlayOpen) root.refreshPacks()
        }
        function onScreenLockedChanged(): void {
            if (!GlobalStates.shellEntryReady) return
            root.playEvent(GlobalStates.screenLocked ? "lock" : "login")
        }
    }

    Component.onCompleted: {
        _refreshMicState();
        userPacksProc.running = true;
        root._openPanelsBefore = root.openPanels;
    }

    // IPC handlers for external control (keybinds, etc.)
    /// Volume and mute control.
    IpcHandler {
        target: "audio"

        /// Increase volume
        function volumeUp(): void {
            root.incrementVolume();
        }

        /// Decrease volume
        function volumeDown(): void {
            root.decrementVolume();
        }

        /// Toggle speaker mute
        function mute(): void {
            root.toggleMute();
        }

        /// Play a shell event sound (e.g. `notification`, `batteryLow`, `boot`, `open`) from the sound pack in use,
        /// honoring the user's per-event override and the session and interface switches
        function playEvent(event: string): void {
            root.playEvent(event);
        }

        /// Hear an event in a sound pack (`aurora`, `tactile`, `lounge`, `orbit`, `crystal`, `arcade` or one of yours),
        /// whatever is switched on
        function previewEvent(event: string, pack: string): void {
            root.previewEvent(event, pack);
        }

        /// Toggle microphone mute
        function micMute(): void {
            root.toggleMicMute();
        }
    }
}
