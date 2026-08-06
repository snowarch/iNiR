pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import QtMultimedia

/**
 * Two-slot video player that crossfades between sources.
 *
 * A single player bound straight to a path tears down its pipeline on every
 * change, so the surface goes black while the new file loads and then pops in.
 * This keeps the outgoing video playing until the incoming one has actually
 * decoded a frame, then fades between them.
 *
 * Uses explicit MediaPlayer + VideoOutput pairs rather than the Video
 * convenience type, which does not expose the status change signals this needs.
 */
Item {
    id: root

    property string source: ""
    property int fillMode: VideoOutput.PreserveAspectCrop
    property bool shouldPlay: true
    property bool enableTransitions: true
    property int transitionBaseDuration: 800

    readonly property int effectiveDuration: (root.enableTransitions && Appearance.animationsEnabled)
        ? Appearance.calcEffectiveDuration(root.transitionBaseDuration) : 0

    property int activeSlot: 0
    property string _loadingSource: ""
    property bool _slotAHasFrame: false
    property bool _slotBHasFrame: false
    readonly property bool hasFrame: root.activeSlot === 0
        ? root._slotAHasFrame : root._slotBHasFrame

    function _normalized(path: string): string {
        const value = String(path ?? "")
        if (!value) return ""
        return value.startsWith("file://") ? value : ("file://" + value)
    }

    function _activePlayer(): var { return root.activeSlot === 0 ? playerA : playerB }
    function _inactivePlayer(): var { return root.activeSlot === 0 ? playerB : playerA }

    onSourceChanged: root._applySource()
    Component.onCompleted: root._applySource()
    onShouldPlayChanged: root._syncPlayback()

    // An in-flight load must be abandoned whenever the requested source changes,
    // or it will finish later and swap the surface to a wallpaper nobody asked
    // for. Applying a previewed video hit exactly that: clearing the preview
    // briefly restored the old path, which started loading, and the apply then
    // matched the active slot and returned without cancelling it.
    function _cancelPendingLoad(): void {
        if (!root._loadingSource) return
        const pending = root._inactivePlayer()
        if (String(pending.source) === root._loadingSource)
            pending.source = ""
        root._loadingSource = ""
    }

    function _applySource(): void {
        const next = root._normalized(root.source)
        if (!next) {
            root._cancelPendingLoad()
            playerA.source = ""
            playerB.source = ""
            return
        }

        const active = root._activePlayer()

        // Already showing it: drop any pending load rather than letting it land.
        if (next === String(active.source) && String(active.source) !== "") {
            root._cancelPendingLoad()
            root._syncPlayback()
            return
        }

        // No transition wanted, or nothing to fade from: use the visible slot
        // directly and never hold a second decoder.
        if (!String(active.source) || root.effectiveDuration <= 0) {
            root._cancelPendingLoad()
            active.source = next
            root._syncPlayback()
            return
        }

        // Load into the hidden slot; the swap waits for a decoded frame so the
        // fade never reveals a black or half-buffered surface.
        root._cancelPendingLoad()
        root._loadingSource = next
        root._inactivePlayer().source = next
        root._syncPlayback()
    }

    // Called by a slot once it can actually show a frame.
    function _slotReady(slotIndex: int, slotSource: string): void {
        if (!root._loadingSource || String(slotSource) !== root._loadingSource)
            return
        if (slotIndex === root.activeSlot)
            return
        root._loadingSource = ""
        root.activeSlot = slotIndex
        root._syncPlayback()
        cleanupTimer.restart()
    }

    function _handleFrame(slotIndex: int, player: var): void {
        if (slotIndex === 0)
            root._slotAHasFrame = true
        else
            root._slotBHasFrame = true

        root._slotReady(slotIndex, player.source)

        // A paused wallpaper still needs one decoded frame. Prime the pipeline,
        // then stop on that first frame instead of leaving a black surface.
        if (!root.shouldPlay) {
            player.pause()
            if (player.seekable && player.position !== 0)
                player.position = 0
        }
    }

    function _syncPlayback(): void {
        // The outgoing slot keeps playing through the fade. When playback is
        // suspended, a slot without a frame is briefly played only to prime it.
        for (const player of [playerA, playerB]) {
            if (!String(player.source)) continue
            const hasFrame = player === playerA
                ? root._slotAHasFrame : root._slotBHasFrame
            if (root.shouldPlay || !hasFrame) {
                player.play()
            } else {
                player.pause()
                if (player.seekable && player.position !== 0)
                    player.position = 0
            }
        }
    }

    // Release the slot that finished fading out so it stops decoding.
    Timer {
        id: cleanupTimer
        interval: Math.max(root.effectiveDuration, 1) + 80
        onTriggered: {
            const stale = root._inactivePlayer()
            if (root._loadingSource && String(stale.source) === root._loadingSource)
                return
            stale.source = ""
        }
    }

    VideoOutput {
        id: outputA
        anchors.fill: parent
        fillMode: root.fillMode
        visible: opacity > 0
        opacity: root.activeSlot === 0 ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.effectiveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standard
            }
        }
    }

    VideoOutput {
        id: outputB
        anchors.fill: parent
        fillMode: root.fillMode
        visible: opacity > 0
        opacity: root.activeSlot === 1 ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.effectiveDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standard
            }
        }
    }

    Connections {
        target: outputA.videoSink
        enabled: !root._slotAHasFrame
        function onVideoFrameChanged(): void {
            const size = outputA.videoSink.videoSize
            if (size.width > 0 && size.height > 0)
                root._handleFrame(0, playerA)
        }
    }

    Connections {
        target: outputB.videoSink
        enabled: !root._slotBHasFrame
        function onVideoFrameChanged(): void {
            const size = outputB.videoSink.videoSize
            if (size.width > 0 && size.height > 0)
                root._handleFrame(1, playerB)
        }
    }

    // No audioOutput is assigned, so wallpapers stay silent.
    MediaPlayer {
        id: playerA
        videoOutput: outputA
        loops: MediaPlayer.Infinite
        onSourceChanged: {
            root._slotAHasFrame = false
            root._syncPlayback()
        }
    }

    MediaPlayer {
        id: playerB
        videoOutput: outputB
        loops: MediaPlayer.Infinite
        onSourceChanged: {
            root._slotBHasFrame = false
            root._syncPlayback()
        }
    }
}
