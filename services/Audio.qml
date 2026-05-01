pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

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
    property string audioTheme: Config.options?.sounds?.theme ?? "freedesktop"
    property real value: sink?.audio?.volume ?? rawSink?.audio?.volume ?? 0
    property bool micBeingAccessed: Pipewire.links.values.filter(link =>
        !link.source.isStream && !link.source.isSink && link.target.isStream
    ).length > 0

    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0

    function friendlyDeviceName(node) {
        return node ? (node.nickname || node.description || Translation.tr("Unknown")) : Translation.tr("Unknown");
    }
    function appNodeDisplayName(node) {
        if (!node) return Translation.tr("Unknown");
        return (node.properties?.["application.name"] || node.description || node.name || Translation.tr("Unknown"))
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

    // Controls
    function toggleMute() {
        if (!root.sink?.audio) return;
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function setSourceVolume(target: real): void {
        if (!root.source?.audio) return
        root.source.audio.volume = Math.max(0, Math.min(root.hardMaxValue, target))
    }

    function toggleMicMute() {
        if (!root.source?.audio) return
        root.source.audio.muted = !root.source.audio.muted
    }

    Process {
        id: wpctlSetDefaultDevice
        command: ["wpctl", "set-default", "0"]
        onExited: {
            // After switching default sink, immediately nudge volume via wpctl so
            // USB/device-route sinks (e.g. USB mic used as output) get their volume
            // state initialised in PipeWire without requiring pavucontrol interaction.
            if (!wpctlSetSinkVolume.running) {
                wpctlSetSinkVolume.command = ["wpctl", "set-volume",
                    "@DEFAULT_AUDIO_SINK@",
                    String(root.sink?.audio?.volume ?? 0.5)]
                wpctlSetSinkVolume.running = true
            }
        }
    }

    // Sink volume via wpctl — fallback for devices whose volume control lives at
    // the PipeWire device-route level and is not reachable through the QML binding.
    Process {
        id: wpctlSetSinkVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1.0"]
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

    // Set sink volume safely. When protection is enabled, large jumps are rejected as "Illegal increment".
    // To keep UX consistent with brightness (click anywhere on slider), we ramp in small steps.
    // wpctl is fired before the QML guard so USB/device-route sinks are always reachable
    // even when Quickshell has not fully tracked the node yet.
    function setSinkVolume(target: real): void {
        const maxAllowed = (Config.options?.audio?.protection?.maxAllowed ?? 100) / 100;
        const clamped = Math.max(0, Math.min(Math.min(maxAllowed, root.hardMaxValue), target));

        // Always send to wpctl regardless of QML node availability.
        if (!wpctlSetSinkVolume.running) {
            wpctlSetSinkVolume.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(clamped)]
            wpctlSetSinkVolume.running = true
        }

        if (!root.sink?.audio) return;

        const protectionEnabled = (Config.options?.audio?.protection?.enable ?? false);
        if (!protectionEnabled) {
            root.sink.audio.volume = clamped;
            return;
        }

        root._rampTarget = clamped;
        root._rampTimer.restart();
    }

    // Ramp helper (prevents "Illegal increment" when user clicks far away on slider)
    property real _rampTarget: 0
    property alias _rampTimer: _rampTimerInternal
    Timer {
        id: _rampTimerInternal
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            if (!root.sink?.audio) {
                running = false;
                return;
            }

            const protectionEnabled = (Config.options?.audio?.protection?.enable ?? false);
            if (!protectionEnabled) {
                root.sink.audio.volume = root._rampTarget;
                running = false;
                return;
            }

            const maxStep = (Config.options?.audio?.protection?.maxAllowedIncrease ?? 10) / 100;
            const step = Math.max(0.005, maxStep * 0.8); // Stay below protection threshold
            const current = root.sink.audio.volume;
            const diff = root._rampTarget - current;
            if (Math.abs(diff) <= step) {
                root.sink.audio.volume = root._rampTarget;
                running = false;
                return;
            }
            root.sink.audio.volume = current + Math.sign(diff) * step;
        }
    }

    function incrementVolume() {
        // Fire wpctl relative increment first — works even when sink?.audio is not yet tracked.
        if (!wpctlIncrementSinkVolume.running)
            wpctlIncrementSinkVolume.running = true
        if (!root.sink?.audio) return;
        const currentVolume = root.sink.audio.volume;
        const step = currentVolume < 0.1 ? 0.01 : 0.02;
        root.sink.audio.volume = Math.min(root.hardMaxValue, currentVolume + step);
    }

    function decrementVolume() {
        // Fire wpctl relative decrement first — works even when sink?.audio is not yet tracked.
        if (!wpctlDecrementSinkVolume.running)
            wpctlDecrementSinkVolume.running = true
        if (!root.sink?.audio) return;
        const currentVolume = root.sink.audio.volume;
        const step = currentVolume <= 0.1 ? 0.01 : 0.02;
        root.sink.audio.volume = Math.max(0, currentVolume - step);
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
            if (!sink?.audio) return;
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
                sink.audio.volume = lastVolume;
                root.sinkProtectionTriggered(Translation.tr("Illegal increment"));
            } else if (newVolume > maxAllowed || newVolume > root.hardMaxValue) {
                root.sinkProtectionTriggered(Translation.tr("Exceeded max allowed"));
                sink.audio.volume = Math.min(lastVolume, maxAllowed);
            }
            lastVolume = sink.audio.volume;
        }
    }

    function playSystemSound(soundName) {
        const volume = Config.options?.sounds?.volume ?? 0.5;
        const ogaPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.oga`;
        const oggPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.ogg`;

        // pw-play volume range: 0.0 to 1.0
        let command = ["/usr/bin/pw-play", "--volume", volume.toString(), ogaPath];
        Quickshell.execDetached(command);

        command = ["/usr/bin/pw-play", "--volume", volume.toString(), oggPath];
        Quickshell.execDetached(command);
    }

    // IPC handlers for external control (keybinds, etc.)
    IpcHandler {
        target: "audio"

        function volumeUp(): void {
            root.incrementVolume();
        }

        function volumeDown(): void {
            root.decrementVolume();
        }

        function mute(): void {
            root.toggleMute();
        }

        function micMute(): void {
            root.toggleMicMute();
        }
    }
}
