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
    property PwNode sink: root.resolveControllableSink(rawSink)
    property PwNode source: Pipewire.defaultAudioSource
    readonly property real hardMaxValue: 2.00
    property string audioTheme: Config.options?.sounds?.theme ?? "freedesktop"
    property real value: sink?.audio?.volume ?? rawSink?.audio?.volume ?? 0
    property bool micBeingAccessed: Pipewire.links.values.filter(link =>
        !link.source.isStream && !link.source.isSink && link.target.isStream
    ).length > 0

    property bool _wpctlMicStateKnown: false
    property bool _wpctlMicMuted: false
    readonly property bool micMuted: _wpctlMicStateKnown ? _wpctlMicMuted : (source?.audio?.muted ?? false)

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

        // Fallback: find the first non-virtual, non-EasyEffects hardware sink.
        // This handles cases where EasyEffects uses pw-loopback/filter-chain and
        // driver-id doesn't point directly to the hardware sink node.
        const fallbackSink = Pipewire.nodes.values.find(candidate => {
            if (!root.correctType(candidate, true) || candidate.isStream) return false
            const cProps = candidate.properties ?? {}
            const cName = String(cProps["node.name"] ?? candidate.name ?? "")
            const cAppId = String(cProps["application.id"] ?? "")
            const cVirtual = String(cProps["node.virtual"] ?? "false") === "true"
            const cPassthrough = String(cProps["monitor.passthrough"] ?? "false") === "true"
            const isEE = cName === "easyeffects_sink"
                || cAppId === "com.github.wwmm.easyeffects"
                || (cVirtual && cPassthrough)
            return !isEE
        })

        return fallbackSink ?? node
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
        const clamped = Math.max(0, Math.min(root.hardMaxValue, target))
        if (root.source?.audio) {
            root.source.audio.volume = clamped
        }
        if (wpctlSetSourceVolume.running) return
        wpctlSetSourceVolume.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", String(clamped)]
        wpctlSetSourceVolume.running = true
    }

    function toggleMicMute() {
        const shouldMute = !root.micMuted
        if (root.source?.audio) {
            root.source.audio.muted = shouldMute
        }
        if (wpctlSetMicMute.running) return
        wpctlSetMicMute.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", shouldMute ? "1" : "0"]
        wpctlSetMicMute.running = true
    }

    function refreshMicState(): void {
        if (wpctlGetMicState.running) return
        wpctlGetMicState.running = true
    }

    Process {
        id: wpctlSetMicMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        onExited: refreshMicState()
    }

    Process {
        id: wpctlSetSourceVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "1.0"]
        onExited: refreshMicState()
    }

    Process {
        id: wpctlGetMicState
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            id: wpctlGetMicStateStdout
        }
        onExited: (exitCode, _exitStatus) => {
            if (exitCode !== 0) return
            const raw = (wpctlGetMicStateStdout.text?.trim() ?? "")
            if (!raw.length) return
            const out = raw.split(/\r?\n/).filter(l => l.trim().length > 0).slice(-1)[0] ?? ""
            if (!out.length) return

            root._wpctlMicStateKnown = true
            root._wpctlMicMuted = out.toUpperCase().includes("MUTED")
        }
    }

    Process {
        id: wpctlSetDefaultDevice
        command: ["wpctl", "set-default", "0"]
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: refreshMicState()
    }

    Component.onCompleted: refreshMicState()

    // Set sink volume safely. When protection is enabled, large jumps are rejected as "Illegal increment".
    // To keep UX consistent with brightness (click anywhere on slider), we ramp in small steps.
    function setSinkVolume(target: real): void {
        if (!root.sink?.audio) return;

        const maxAllowed = (Config.options?.audio?.protection?.maxAllowed ?? 100) / 100;
        const clamped = Math.max(0, Math.min(Math.min(maxAllowed, root.hardMaxValue), target));

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
        if (!root.sink?.audio) return;
        const currentVolume = root.sink.audio.volume;
        const step = currentVolume < 0.1 ? 0.01 : 0.02;
        root.sink.audio.volume = Math.min(root.hardMaxValue, currentVolume + step);
    }
    
    function decrementVolume() {
        if (!root.sink?.audio) return;
        const currentVolume = root.sink.audio.volume;
        const step = currentVolume <= 0.1 ? 0.01 : 0.02;
        root.sink.audio.volume = Math.max(0, currentVolume - step);
    }

    function setDefaultNode(node, isSink: bool): void {
        if (!node) return

        if (isSink) {
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

    Connections { // Protection against sudden volume changes
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
