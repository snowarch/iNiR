pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * Chaos-mode romp: she runs across the desktop and physically messes with
 * it. Separate window from the peek companion so none of the peek
 * invariants (hide/teardown timers, click ladder) are ever touched.
 *
 * The window ignores exclusive zones so its coordinates line up 1:1 with
 * the Background layer where desktop widgets live; widget geometry comes
 * from the MascotChaos registry and impulses go back out over its signals.
 *
 * Plans: "bonk" (mallet a widget, it goes flying), "toss" (hurl a widget
 * to a new spot — persists only when chaos.allowRearrange), "quake"
 * (ground slam: the bar bounces and every widget wobbles). Fully
 * click-through; aborts instantly on suppression.
 */
PanelWindow {
    id: romp

    required property var rompScreen
    signal finished()
    // fired when she leaves destruction behind — the companion schedules
    // her cleanup encore off this
    signal wrecked()

    screen: rompScreen
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell:mascotRomp"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Click-through except her sprite; chase mode captures the whole screen
    // so every click becomes a spot for her to pounce on
    mask: Region { item: romp.phase === "chase" ? chaseCatchArea : sprite }

    // Which behavior this window starts in ("romp" | "chase")
    property string startMode: "romp"

    readonly property bool suppressed: GameMode.active || GameMode.hasVisibleFullscreenWindow
        || GlobalStates.screenLocked || GlobalStates.sessionOpen
    onSuppressedChanged: if (suppressed) romp._abort()

    readonly property int spriteSize: Config.options?.mascot?.companion?.size ?? 150
    readonly property real groundY: height - spriteSize
    // gait varies per outing: usually a stroll-to-jog, sometimes zoomies
    property real runSpeed: 0.5 // px per ms, rolled in _begin

    property var _manifest: ({})
    readonly property var _chaosCfg: _manifest.chaos ?? ({})
    readonly property var _fullBodyPoses: _manifest.fullBodyPoses ?? []
    readonly property var _contextualOcclusionPoses: _manifest.contextualOcclusionPoses ?? []
    FileView {
        id: manifestFile
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        onLoadedChanged: {
            if (!manifestFile.loaded) return
            try {
                romp._manifest = JSON.parse(manifestFile.text())
            } catch (e) {
                console.warn("[MascotRomp] manifest load failed:", e)
            }
            romp._begin()
        }
    }

    // ── Plan ────────────────────────────────────────────────────────────
    // A plan is a list of stops; each stop is a place to run to and a thing
    // to do there. Rampage chains several, trip has a stop that hits nothing.
    property string planType: ""
    property var planStops: []
    property int planIndex: 0

    function _pickLine(pools): string {
        const pool = pools ?? []
        return pool.length ? Translation.tr(pool[Math.floor(Math.random() * pool.length)]) : ""
    }

    // Impact foley from the freedesktop sound theme (opt-out via chaos.sfx)
    function _sfx(name: string): void {
        if (!(Config.options?.mascot?.chaos?.sfx ?? true)) return
        Quickshell.execDetached(["sh", "-c",
            `paplay /usr/share/sounds/freedesktop/stereo/${name}.oga 2>/dev/null || true`])
    }

    // Bigger widgets attract more violence ("the ones hogging the screen")
    function _pickWeighted(ts): var {
        const total = ts.reduce((s, t) => s + t.w * t.h, 0)
        let r = Math.random() * total
        for (const t of ts) {
            r -= t.w * t.h
            if (r <= 0) return t
        }
        return ts[ts.length - 1]
    }

    // Chaos poses can be a single name or a pool; pools rotate with memory
    property var _recentActPoses: []
    function _isFullBodyPose(candidate): bool {
        return typeof candidate === "string" && romp._fullBodyPoses.includes(candidate)
    }

    function _safeFullBodyPose(candidate, fallback): string {
        return romp._isFullBodyPose(candidate) ? candidate
             : (romp._isFullBodyPose(fallback) ? fallback : "hand-on-hip")
    }

    function _pickActPose(p, fallback): string {
        const candidates = !p ? [] : (typeof p === "string" ? [p] : p)
        const fullBody = candidates.filter(x => romp._isFullBodyPose(x))
        const safeFallback = romp._safeFullBodyPose(fallback, "hand-on-hip")
        const pool = fullBody.length ? fullBody : [safeFallback]
        const fresh = pool.filter(x => !romp._recentActPoses.includes(x))
        const src = fresh.length ? fresh : pool
        const pick = src[Math.floor(Math.random() * src.length)]
        romp._recentActPoses.push(pick)
        while (romp._recentActPoses.length > 3) romp._recentActPoses.shift()
        return pick
    }

    function _actXFor(t): real {
        return Math.max(0, Math.min(t.x + t.w / 2 - romp.spriteSize / 2, romp.width - romp.spriteSize))
    }

    function _makePlan(): bool {
        const targets = MascotChaos.targets().filter(t => t.y + t.h < romp.height && t.w < romp.width * 0.7)
        const rearrange = MascotChaos.allowRearrange
        const stops = []

        // Comedy fail: sometimes she just eats the floor and leaves
        if (Math.random() < 0.12) {
            romp.planType = "trip"
            stops.push({ kind: "trip", actX: romp.width * (0.30 + Math.random() * 0.40) })
            romp.planStops = stops
            return true
        }

        const options = ["quake", "punt", "sightsee"]
        if (targets.length > 0) {
            options.push("bonk", "bonk", "wreck", "steal", "inspect", "occupy", "occupy")
            if (targets.length >= 2) options.push("rampage", "rampage", "parkour")
            if (rearrange) options.push("toss")
        }
        romp.planType = options[Math.floor(Math.random() * options.length)]

        const shuffled = targets.slice().sort(() => Math.random() - 0.5)
        // destructive singles pick their victim by screen area
        const victim = targets.length > 0 ? romp._pickWeighted(targets) : null
        const hitMode = pref => pref === "wreck" ? "wreck" : (rearrange ? "persist" : "bounce")

        if (romp.planType === "quake") {
            stops.push({ kind: "quake", actX: romp.width * (0.30 + Math.random() * 0.40) })
        } else if (romp.planType === "punt") {
            // she kicks the bar/dock directly — the panels take it personally
            stops.push({ kind: "punt", actX: romp.width * (0.15 + Math.random() * 0.70) })
        } else if (romp.planType === "rampage") {
            // tear through up to 3 widgets, escalating
            const n = Math.min(3, shuffled.length)
            for (let i = 0; i < n; i++) {
                const t = shuffled[i]
                stops.push({
                    kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t),
                    vx: (Math.random() < 0.5 ? -1 : 1) * (160 + Math.random() * 200), vy: 30,
                    mode: i === n - 1 ? "wreck" : hitMode("")
                })
            }
        } else if (romp.planType === "steal") {
            const t = victim
            stops.push({ kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t), vx: 200, vy: 0, mode: "vanish" })
        } else if (romp.planType === "inspect") {
            const t = victim
            stops.push({ kind: "inspect", key: t.key, actX: romp._actXFor(t) })
        } else if (romp.planType === "occupy") {
            // she plants herself on top of it — zero physics, pure squatting
            const t = victim
            stops.push({ kind: "occupy", key: t.key, actX: romp._actXFor(t) })
        } else if (romp.planType === "sightsee") {
            // ambient: a couple of pose stops at random spots, nothing touched
            const n = 2 + Math.floor(Math.random() * 2)
            for (let i = 0; i < n; i++)
                stops.push({ kind: "sightsee", actX: romp.width * (0.12 + Math.random() * 0.76) })
        } else if (romp.planType === "parkour") {
            // hurdle every widget across the screen, no casualties
            const sorted = targets.slice().sort((a, b) => a.x - b.x)
            for (const t of sorted)
                stops.push({ kind: "hop", key: t.key, actX: romp._actXFor(t) })
        } else if (romp.planType === "toss") {
            const t = victim
            const nx = 40 + Math.random() * Math.max(80, romp.width - t.w - 80)
            const ny = 40 + Math.random() * Math.max(80, romp.height - t.h - 200)
            stops.push({ kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t), vx: nx - t.x, vy: ny - t.y, mode: "persist" })
        } else {
            // bonk or wreck: single target, direction filled in at _begin
            const t = victim
            stops.push({
                kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t),
                vx: 140 + Math.random() * 160, vy: 30,
                mode: romp.planType === "wreck" ? "wreck" : hitMode(""),
                dodge: romp.planType === "bonk" && Math.random() < 0.25
            })
        }
        romp.planStops = stops
        return stops.length > 0
    }

    // Domino: if the flung widget's landing spot overlaps another target,
    // that one takes a delayed secondary hit
    property var _dominoHit: null
    Timer {
        id: dominoTimer
        interval: 480
        onTriggered: {
            if (!romp._dominoHit) return
            MascotChaos.impact(romp._dominoHit.key, romp._dominoHit.vx, 0, "bounce")
            romp._dominoHit = null
        }
    }
    function _checkDomino(stop): void {
        if (stop.mode === "wreck") return
        const lx = stop.x + stop.vx
        for (const t of MascotChaos.targets()) {
            if (t.key === stop.key) continue
            if (lx < t.x + t.w && lx + stop.w > t.x && Math.abs(t.y - 0) < romp.height) {
                romp._dominoHit = { key: t.key, vx: stop.vx * 0.5 }
                dominoTimer.restart()
                return
            }
        }
    }

    // Calling card after a proper wrecking (real notification, 40% chance)
    function _maybeCallingCard(): void {
        if (Math.random() > 0.4) return
        const lines = romp._chaosCfg.notify ?? ["Nothing happened. Don't check your widgets."]
        const body = Translation.tr(lines[Math.floor(Math.random() * lines.length)])
        Quickshell.execDetached(["notify-send", "-a", "Kira", "-i",
            Quickshell.shellPath("assets/images/mascot/inir-mascot-peace-wink.png").toString().replace("file://", ""),
            Translation.tr("Kira was here"), body])
    }

    // ── Sprite state machine ────────────────────────────────────────────
    property string phase: "idle" // enter | act | aftermath | leave
    property bool _enterFromLeft: Math.random() < 0.5
    property real spriteX: 0
    // Run style picked once per outing — always a real running-gait GIF
    // (run-cycle/dash-loop). heroic-run/tiptoe-sneak used to be in this
    // pool by name-match alone; neither is a running pose (heroic-run is a
    // static braced-stance action pose, tiptoe-sneak a static sneak pose) —
    // dragging a static frame across the screen with a fake bob looked
    // wrong. Fixed 2026-07-08, see PROMPTS.md's own descriptions.
    property string _runPose: "run-cycle"
    property string pose: _runPose
    property string line: ""
    readonly property bool running: phase === "enter" || phase === "leave"
    readonly property bool movingRight: runTween.to > spriteX

    NumberAnimation {
        id: runTween
        target: romp
        property: "spriteX"
        onStopped: {
            if (romp._beatPending) { romp._playBeat(); return }
            romp._phaseDone()
        }
    }
    Timer { id: phaseTimer; onTriggered: romp._phaseDone() }
    Timer {
        id: aftershockTimer
        interval: 1300
        onTriggered: {
            romp._sfx("bell")
            MascotChaos.panelShake(1.5)
            for (const t of MascotChaos.targets())
                MascotChaos.impact(t.key, (Math.random() - 0.5) * 60, 0, "bounce")
        }
    }

    // Mid-run beat: on long runs she sometimes stops halfway, looks at
    // YOU for a moment, then carries on — tiny pauses read as intent
    property bool _beatPending: false
    property real _beatFinalX: 0
    Timer {
        id: beatTimer
        interval: 750
        onTriggered: {
            romp.pose = romp._runPose
            romp.line = ""
            romp._runTo(romp._beatFinalX)
        }
    }
    function _playBeat(): void {
        romp._beatPending = false
        const b = romp._chaosCfg.beat ?? ({})
        romp.pose = romp._pickActPose(b.pose, "alert-look")
        if (Math.random() < 0.3) romp.line = romp._pickLine(b.lines)
        beatTimer.restart()
    }

    function _begin(): void {
        if (romp.suppressed || !MascotChaos.enabled) { romp._abort(); return }
        romp._runPose = romp._pickActPose(romp._chaosCfg.run, "run-cycle")
        romp.runSpeed = Math.random() < 0.15 ? 0.95 : (0.40 + Math.random() * 0.35)
        if (romp.startMode === "cleanup") {
            // the encore: she comes back, fixes her own mess, leaves proud
            romp._enterFromLeft = Math.random() < 0.5
            romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
            romp.pose = romp._runPose
            romp.phase = "enter"
            romp.planStops = [{ kind: "cleanup", actX: romp.width * (0.35 + Math.random() * 0.30) }]
            romp.planIndex = 0
            romp.planType = "cleanup"
            console.log("[MascotRomp] cleanup encore")
            romp._runTo(romp.planStops[0].actX)
            return
        }
        if (romp.startMode === "chase") {
            // run in to center stage first, then the game is on
            romp._enterFromLeft = Math.random() < 0.5
            romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
            romp.pose = romp._runPose
            romp.phase = "enter"
            romp.planStops = [{ kind: "chase", actX: romp.width * 0.45 }]
            romp.planIndex = 0
            romp.planType = "chase"
            console.log("[MascotRomp] chase mode")
            romp._runTo(romp.width * 0.45)
            return
        }
        if (romp.startMode === "hide") {
            // run to a spot, then go quiet — a click before the timeout wins
            romp._enterFromLeft = Math.random() < 0.5
            romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
            romp.pose = romp._runPose
            romp.phase = "enter"
            const hideX = romp.width * (0.12 + Math.random() * 0.76)
            romp.planStops = [{ kind: "hideSpot", actX: hideX }]
            romp.planIndex = 0
            romp.planType = "hide"
            console.log("[MascotRomp] hide mode")
            romp._runTo(hideX)
            return
        }
        // Rare spectacle: she rockets straight across the sky and is gone.
        // No stops, no victims — pure entrance value.
        if (Math.random() < 0.08) {
            romp._enterFromLeft = Math.random() < 0.5
            romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
            romp.spriteY = romp.height * (0.15 + Math.random() * 0.35)
            romp.pose = "rocket-ride"
            romp.planType = "flyby"
            romp.planStops = []
            romp.planIndex = 0
            if (Math.random() < 0.6) romp.line = romp._pickLine(romp._chaosCfg.flyby?.lines)
            romp.phase = "leave"
            console.log("[MascotRomp] flyby")
            runTween.to = romp._enterFromLeft ? romp.width + romp.spriteSize : -romp.spriteSize
            runTween.duration = Math.abs(runTween.to - romp.spriteX) / 1.1
            runTween.restart()
            return
        }
        if (!romp._makePlan()) { romp._abort(); return }
        romp.planIndex = 0
        const first = romp.planStops[0]
        // enter from the edge nearest to the first stop
        romp._enterFromLeft = first.actX < romp.width / 2
        romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
        // single hits fling in her run direction so she "kicks through";
        // stolen widgets fly out the same side she exits from
        if ((romp.planType === "bonk" || romp.planType === "wreck" || romp.planType === "steal") && first.kind === "hit")
            first.vx = (romp._enterFromLeft ? 1 : -1) * Math.abs(first.vx)
        romp.pose = romp._runPose
        romp.line = ""
        romp.phase = "enter"
        console.log(`[MascotRomp] ${romp.planType} (${romp.planStops.length} stop${romp.planStops.length > 1 ? "s" : ""})`)
        romp._runTo(first.actX)
    }

    function _runTo(x: real): void {
        const dist = Math.abs(x - romp.spriteX)
        if (romp.phase === "enter" && !romp._beatPending && dist > 600 && Math.random() < 0.35) {
            romp._beatPending = true
            romp._beatFinalX = x
            const midX = romp.spriteX + (x - romp.spriteX) * (0.35 + Math.random() * 0.30)
            runTween.to = midX
            runTween.duration = Math.max(300, Math.abs(midX - romp.spriteX) / romp.runSpeed)
            runTween.restart()
            return
        }
        runTween.to = x
        runTween.duration = Math.max(450, dist / romp.runSpeed)
        runTween.restart()
    }

    property bool _dodged: false

    // Parkour hop: a quick arc over whatever she just reached
    SequentialAnimation {
        id: hopAnim
        NumberAnimation { target: romp; property: "spriteY"; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: romp; property: "spriteY"; duration: 220; easing.type: Easing.InQuad }
        onStopped: romp.spriteY = -1
    }
    function _hop(): void {
        romp.spriteY = romp.groundY
        hopAnim.animations[0].to = romp.groundY - 110
        hopAnim.animations[1].to = romp.groundY
        hopAnim.restart()
    }

    function _phaseDone(): void {
        if (romp.phase === "chase") { romp._chaseTimeout(); return }
        if (romp.phase === "hide") { romp._endHide("notFound"); return }
        const stop = romp.planStops[romp.planIndex]
        if (romp.phase === "enter" && stop.kind === "chase") {
            romp._startChase()
            return
        }
        if (romp.phase === "enter" && stop.kind === "hideSpot") {
            romp._startHide()
            return
        }
        if (romp.phase === "enter" && stop.kind === "cleanup") {
            const act = romp._chaosCfg.cleanup ?? romp._chaosCfg.tidy ?? ({})
            romp.pose = romp._pickActPose(act.pose, "battle-point")
            romp.line = romp._pickLine(act.lines)
            romp.phase = "act"
            phaseTimer.interval = 900
            phaseTimer.restart()
            return
        }
        if (romp.phase === "act" && stop.kind === "cleanup") {
            MascotChaos.tidy()
            romp._sfx("complete")
            const act = romp._chaosCfg.cleanup ?? ({})
            romp.pose = romp._pickActPose(act.after, "stomp-victory")
            romp.line = ""
            romp.phase = "aftermath"
            phaseTimer.interval = 1400
            phaseTimer.restart()
            return
        }
        if (romp.phase === "enter" && stop.kind === "hop") {
            // hurdle it: arc + a startled wobble underneath, then keep running
            romp._hop()
            MascotChaos.impact(stop.key, (Math.random() - 0.5) * 50, 0, "bounce")
            if (romp.planIndex === 0)
                romp.line = romp._pickLine(romp._chaosCfg.parkour?.lines)
            romp.phase = "act"
            phaseTimer.interval = 460
            phaseTimer.restart()
            return
        }
        if (romp.phase === "enter") {
            const cfgKey = stop.kind === "hit" ? romp._hitCfgKey(stop) : stop.kind
            const act = romp._chaosCfg[cfgKey] ?? ({})
            // Fallbacks stay in the romp's full-body domain; chibi art belongs
            // to the tier-4 click ladder, not to a character moving through
            // desktop space next to full-body art.
            romp.pose = romp._pickActPose(act.pose, stop.kind === "trip" ? "dead-crash" : "mallet-swing")
            romp.line = romp._pickLine(act.lines)
            romp.phase = "act"
            phaseTimer.interval = stop.kind === "trip" ? 2000
                : stop.kind === "occupy" ? 1800
                : stop.kind === "sightsee" ? 700
                : 620
            phaseTimer.restart()
        } else if (romp.phase === "act") {
            if (stop.kind === "occupy") {
                // she just sits there — no impact, no domino, pure vibes
                const act = romp._chaosCfg.occupy ?? ({})
                romp.pose = romp._pickActPose(act.after, "stomp-victory")
                romp.line = ""
                romp.phase = "aftermath"
                phaseTimer.interval = 1400
                phaseTimer.restart()
                return
            }
            if (stop.kind === "sightsee") {
                // ambient multi-stop — cycle to the next pose, or wrap up
                romp.planIndex++
                romp.line = ""
                if (romp.planIndex < romp.planStops.length) {
                    romp.pose = romp._runPose
                    romp.phase = "enter"
                    romp._runTo(romp.planStops[romp.planIndex].actX)
                } else {
                    const act = romp._chaosCfg.sightsee ?? ({})
                    romp.pose = romp._pickActPose(act.after, "standing-unimpressed")
                    romp.phase = "aftermath"
                    phaseTimer.interval = 1300
                    phaseTimer.restart()
                }
                return
            }
            if (stop.kind === "trip") {
                // she just lies there; then gets up, pretends it didn't happen
                const act = romp._chaosCfg.trip ?? ({})
                romp.pose = romp._pickActPose(act.after, "stand-pout")
                romp.line = romp._pickLine(romp._chaosCfg.trip?.after_lines ?? ["You saw NOTHING."])
                romp.phase = "aftermath"
                phaseTimer.interval = 1200
                phaseTimer.restart()
                return
            }
            if (stop.kind === "hop") {
                // hop finished mid-run — straight on to the next hurdle or the exit
                romp.planIndex++
                romp.line = ""
                if (romp.planIndex < romp.planStops.length) {
                    romp.pose = romp._runPose
                    romp.phase = "enter"
                    romp._runTo(romp.planStops[romp.planIndex].actX)
                } else {
                    const act = romp._chaosCfg.parkour ?? ({})
                    romp.pose = romp._pickActPose(act.after, "stomp-victory")
                    romp.phase = "aftermath"
                    phaseTimer.interval = 1300
                    phaseTimer.restart()
                }
                return
            }
            if (stop.kind === "inspect") {
                // fake-out: a tiny nudge, a second look, and she's gone
                MascotChaos.impact(stop.key, (Math.random() < 0.5 ? -1 : 1) * 30, 0, "bounce")
                const act = romp._chaosCfg.inspect ?? ({})
                romp.pose = romp._pickActPose(act.after, "lean-peek")
                romp.line = ""
                romp.planIndex++
                romp.phase = "aftermath"
                phaseTimer.interval = 1400
                phaseTimer.restart()
                return
            }
            if (stop.kind === "hit" && stop.dodge && !romp._dodged) {
                // the widget saw it coming — quick sidestep, she whiffs
                romp._dodged = true
                MascotChaos.impact(stop.key, (Math.random() < 0.5 ? -1 : 1) * 70, 0, "bounce")
                romp.pose = romp._pickActPose(romp._chaosCfg.dodge_pose, "shocked-jump")
                romp.line = romp._pickLine(romp._chaosCfg.dodge ?? ["Oh, it DODGED. Cute."])
                romp.phase = "act"
                phaseTimer.interval = 900
                phaseTimer.restart()
                return
            }
            // the hit lands
            if (stop.kind === "quake") {
                // no two quakes alike: variable magnitude, and sometimes
                // an aftershock rolls through a beat later
                romp._sfx("dialog-warning")
                MascotChaos.panelShake(1 + Math.random() * 1.4)
                for (const t of MascotChaos.targets())
                    MascotChaos.impact(t.key, (Math.random() - 0.5) * (90 + Math.random() * 130), 0, "bounce")
                if (Math.random() < 0.35) aftershockTimer.restart()
            } else if (stop.kind === "punt") {
                romp._sfx("dialog-warning")
                MascotChaos.panelShake(2.4)
            } else {
                romp._sfx(stop.mode === "vanish" ? "trash-empty" : (stop.mode === "wreck" ? "dialog-error" : "bell"))
                MascotChaos.impact(stop.key, stop.vx, stop.vy, stop.mode)
                romp._checkDomino(stop)
            }
            romp.planIndex++
            if (romp.planIndex < romp.planStops.length) {
                // rampage: on to the next victim
                romp.pose = romp._runPose
                romp.line = ""
                romp.phase = "enter"
                romp._runTo(romp.planStops[romp.planIndex].actX)
                return
            }
            const cfgKey = stop.kind === "hit" ? romp._hitCfgKey(stop) : stop.kind
            const act = romp._chaosCfg[cfgKey] ?? ({})
            romp.pose = romp._pickActPose(act.after, "stomp-victory")
            romp.phase = "aftermath"
            phaseTimer.interval = 1500
            phaseTimer.restart()
            if (stop.mode === "wreck" || romp.planType === "rampage")
                romp._maybeCallingCard()
        } else if (romp.phase === "aftermath") {
            // stolen goods leave with her, at a burdened waddle
            const stealing = romp.planType === "steal"
            romp.pose = stealing
                ? romp._safeFullBodyPose(romp._chaosCfg.steal?.carry, "carry-crate")
                : romp._runPose
            romp.line = ""
            romp.phase = "leave"
            // keep going in the same direction, out the far side
            runTween.to = romp._enterFromLeft ? romp.width + romp.spriteSize : -romp.spriteSize
            runTween.duration = Math.max(450, Math.abs(runTween.to - romp.spriteX) / (stealing ? romp.runSpeed * 0.55 : romp.runSpeed))
            runTween.restart()
        } else if (romp.phase === "leave") {
            if (romp.planType === "steal" || romp.planType === "rampage"
                || romp.planStops.some(s => s.mode === "wreck"))
                romp.wrecked()
            romp.finished()
        }
    }

    function _hitCfgKey(stop): string {
        if (stop.kind === "quake") return "quake"
        if (romp.planType === "toss") return "toss"
        if (romp.planType === "steal") return "steal"
        return stop.mode === "wreck" ? "wreck" : "bonk"
    }

    function _abort(): void {
        runTween.stop()
        chaseXTween.stop()
        chaseYTween.stop()
        phaseTimer.stop()
        romp.finished()
    }

    // ── Chase mode: she hunts your mouse clicks ─────────────────────────
    // Every click is a spot to pounce on; click HER to catch her and win.
    property int _chaseClicks: 0
    property real spriteY: -1 // -1 = glued to the ground
    NumberAnimation { id: chaseXTween; target: romp; property: "spriteX"; duration: 320; easing.type: Easing.OutQuad }
    NumberAnimation {
        id: chaseYTween
        target: romp
        property: "spriteY"
        duration: 320
        easing.type: Easing.OutQuad
        onStopped: if (romp.phase === "chase")
            romp.pose = romp._safeFullBodyPose(romp._chaosCfg.chase?.wait, "low-angle-guard")
    }

    function _startChase(): void {
        runTween.stop()
        romp._chaseClicks = 0
        romp.phase = "chase"
        romp.pose = romp._pickActPose(romp._chaosCfg.chase?.invite, "follow-me")
        romp.line = romp._pickLine(romp._chaosCfg.chase?.lines ?? ["Catch me if you can."])
        if (romp.spriteY < 0) romp.spriteY = romp.groundY
        phaseTimer.interval = 25000
        phaseTimer.restart()
    }

    function _chasePounce(cx: real, cy: real): void {
        romp._chaseClicks++
        if (romp._chaseClicks > 14) { romp._endChase("bored"); return }
        romp.pose = romp._safeFullBodyPose(romp._chaosCfg.chase?.pounce, "jump-bounce")
        romp.line = ""
        chaseXTween.stop(); chaseYTween.stop()
        chaseXTween.to = Math.max(0, Math.min(cx - romp.spriteSize / 2, romp.width - romp.spriteSize))
        chaseYTween.to = Math.max(0, Math.min(cy - romp.spriteSize / 2, romp.height - romp.spriteSize))
        chaseXTween.restart(); chaseYTween.restart()
    }

    function _chaseTimeout(): void { romp._endChase("timeout") }

    function _endChase(how: string): void {
        phaseTimer.stop()
        chaseXTween.stop(); chaseYTween.stop()
        const c = romp._chaosCfg.chase ?? ({})
        if (how === "caught") {
            romp.pose = romp._pickActPose(c.caughtPose, "sit-peace-wink")
            romp.line = romp._pickLine(c.caught ?? ["Okay. You win. This once."])
        } else if (how === "bored") {
            romp.pose = romp._pickActPose(c.boredPose, "hand-on-hip")
            romp.line = romp._pickLine(c.bored ?? ["I have things to wreck. Bye."])
        } else {
            romp.pose = romp._pickActPose(c.timeoutPose, "stand-pout")
            romp.line = romp._pickLine(c.timeout ?? ["Too slow. Noted."])
        }
        // settle to the ground, brag a moment, then leave
        romp.spriteY = -1
        romp.phase = "aftermath"
        phaseTimer.interval = 1800
        phaseTimer.restart()
    }

    // ── Hide-and-seek: she tucks into a spot; a click before the timeout
    // catches her, otherwise she wins by default ─────────────────────────
    function _startHide(): void {
        const h = romp._chaosCfg.hide ?? ({})
        const hiddenPose = h.hidePose ?? "box-hideout"
        romp.pose = romp._contextualOcclusionPoses.includes(hiddenPose) ? hiddenPose : "box-hideout"
        romp.line = romp._pickLine(h.invite ?? ["Bet you can't find me."])
        romp.phase = "hide"
        phaseTimer.interval = 20000
        phaseTimer.restart()
    }
    function _endHide(how: string): void {
        phaseTimer.stop()
        const h = romp._chaosCfg.hide ?? ({})
        if (how === "found") {
            romp.pose = romp._pickActPose(h.foundPose, "sit-peace-wink")
            romp.line = romp._pickLine(h.found ?? ["FOUND. Fine. You win this round."])
        } else {
            romp.pose = romp._pickActPose(h.notFoundPose, "stomp-victory")
            romp.line = romp._pickLine(h.notFound ?? ["Too slow. I win by default."])
        }
        romp.phase = "aftermath"
        phaseTimer.interval = 1600
        phaseTimer.restart()
    }

    // ── Visuals ─────────────────────────────────────────────────────────
    // Chase mode: the whole screen becomes her playground. She HUNTS the
    // live cursor — stalking toward it, lunging when close — clicks are
    // pounce targets, and clicking her ends the game (you caught her).
    Item {
        id: chaseCatchArea
        anchors.fill: parent
        visible: romp.phase === "chase"

        MouseArea {
            id: chaseArea
            anchors.fill: parent
            enabled: romp.phase === "chase"
            hoverEnabled: true
            onClicked: mouse => {
                const inSprite = mouse.x >= sprite.x && mouse.x <= sprite.x + sprite.width
                    && mouse.y >= sprite.y && mouse.y <= sprite.y + sprite.height
                if (inSprite) romp._endChase("caught")
                else romp._chasePounce(mouse.x, mouse.y)
            }
        }

        // The hunt: steer toward the cursor a step at a time; prowl when
        // far, crouch when she's within striking range, lunge on a whim
        Timer {
            id: pursuitTimer
            interval: 90
            repeat: true
            running: romp.phase === "chase" && chaseArea.containsMouse
            onTriggered: {
                if (chaseXTween.running || chaseYTween.running) return
                const tx = chaseArea.mouseX - romp.spriteSize / 2
                const ty = chaseArea.mouseY - romp.spriteSize / 2
                const dx = tx - romp.spriteX
                const dy = ty - (romp.spriteY >= 0 ? romp.spriteY : romp.groundY)
                const dist = Math.hypot(dx, dy)
                if (dist < romp.spriteSize * 0.45) {
                    romp.pose = romp._chaosCfg.chase?.wait ?? "low-angle-guard"
                    return
                }
                if (romp.spriteY < 0) romp.spriteY = romp.groundY
                // occasional full lunge, otherwise a stalking step
                const lunge = dist < romp.spriteSize * 2.4 && Math.random() < 0.30
                const step = lunge ? 1.0 : Math.min(1.0, (110 + Math.random() * 60) / dist)
                romp.pose = lunge
                    ? romp._safeFullBodyPose(romp._chaosCfg.chase?.pounce, "jump-bounce")
                    : romp._safeFullBodyPose(romp._chaosCfg.chase?.stalk, "tiptoe-sneak")
                chaseXTween.duration = lunge ? 260 : 340
                chaseYTween.duration = chaseXTween.duration
                chaseXTween.to = Math.max(0, Math.min(romp.spriteX + dx * step, romp.width - romp.spriteSize))
                chaseYTween.to = Math.max(0, Math.min((romp.spriteY) + dy * step, romp.height - romp.spriteSize))
                chaseXTween.restart()
                chaseYTween.restart()
            }
        }
    }

    Item {
        id: sprite
        width: romp.spriteSize
        height: romp.spriteSize
        x: romp.spriteX
        y: romp.spriteY >= 0 ? romp.spriteY : romp.groundY
        // bob rides on a transform so it can never feed back into the y
        // binding (the previous "+ bob" form loop-detected under the hop)
        property real bob: 0
        transform: Translate { y: sprite.bob }

        // Poked mid-romp: she startles — and might turn it into a game
        TapHandler {
            enabled: romp.phase === "act" || romp.phase === "aftermath" || romp.phase === "hide"
            onTapped: {
                if (romp.phase === "hide") { romp._endHide("found"); return }
                if (Math.random() < 0.45) {
                    romp._startChase()
                } else {
                    romp.pose = romp._pickActPose(romp._chaosCfg.startle_pose, "stand-pout")
                    romp.line = romp._pickLine(romp._chaosCfg.startle ?? ["HEY. Working here."])
                }
            }
        }

        // run-cycle bob: little hops while she's moving. Reset happens on
        // the animation itself — writing bob from onYChanged loops the
        // y binding (bob feeds y).
        SequentialAnimation {
            // real run-cycle GIFs animate their own gait — bob only fakes
            // locomotion for static poses like tiptoe-sneak
            running: romp.running && Appearance.animationsEnabled
                && !(romp._manifest.animatedPoses ?? []).includes(romp.pose)
            loops: Animation.Infinite
            alwaysRunToEnd: false
            onRunningChanged: if (!running) sprite.bob = 0
            NumberAnimation { target: sprite; property: "bob"; to: -10; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: sprite; property: "bob"; to: 0; duration: 140; easing.type: Easing.InQuad }
        }

        // Two stacked sprites, cross-faded. A single Image swapping `source`
        // replaces the pixels the instant the new file decodes, so entering and
        // leaving a run read as a hard cut. The incoming layer only starts its
        // fade once it is Ready, otherwise the fade begins on an empty frame
        // and she blinks out of existence for a beat.
        Item {
            id: spriteStack
            anchors.fill: parent

            readonly property string source: romp.phase === "idle"
                ? ""
                : Quickshell.shellPath(`assets/images/mascot/inir-mascot-${romp.pose}.${(romp._manifest.animatedPoses ?? []).includes(romp.pose) ? "gif" : "png"}`)
            readonly property bool mirrored: romp.running
                && (romp.movingRight !== (romp._manifest.facesRight ?? []).includes(romp.pose))
            readonly property int fadeDuration: Appearance.calcEffectiveDuration(130)

            // Which layer currently owns the visible pose.
            property bool frontIsA: true

            onSourceChanged: {
                if (source === "") { layerA.source = ""; layerB.source = ""; return }
                _load(frontIsA ? layerB : layerA, source)
            }

            function _load(layer, src) {
                // Re-assigning a source a layer already holds emits no
                // statusChanged, so a Ready-gated reveal would never fire and the
                // outgoing pose would stay on screen. This is the exact path
                // "leave" takes: it returns to the run GIF the layer used on
                // "enter", which is why she left the screen frozen mid-stride.
                if (layer.source == src && layer.status === Image.Ready) {
                    _reveal(layer)
                    return
                }
                layer.source = src
            }

            function _reveal(layer) {
                // Restart the loop so a run always begins on its contact frame
                // instead of wherever the cached movie happened to stop.
                if (layer.playing) layer.currentFrame = 0
                // Ignore a late Ready from a layer that is already the front one.
                if (layer === layerA && !frontIsA) frontIsA = true
                else if (layer === layerB && frontIsA) frontIsA = false
            }

            component RompSprite: AnimatedImage {
                anchors.fill: parent
                playing: true
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // Switching back to _runPose on "leave" would otherwise be an
                // uncached async decode lagging behind the tween already moving,
                // reading as "she leaves without the run animation."
                cache: true
                // Same fix as MascotCompanion/MascotWidget: nearest-neighbor
                // scaling of the 640px source art serrated her edges.
                smooth: true
                mipmap: true
                antialiasing: true
                mirror: spriteStack.mirrored
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: spriteStack.fadeDuration; easing.type: Easing.InOutQuad }
                }
            }

            RompSprite {
                id: layerA
                opacity: spriteStack.frontIsA ? 1 : 0
                onStatusChanged: if (status === Image.Ready) spriteStack._reveal(layerA)
            }

            RompSprite {
                id: layerB
                opacity: spriteStack.frontIsA ? 0 : 1
                onStatusChanged: if (status === Image.Ready) spriteStack._reveal(layerB)
            }

            Component.onCompleted: if (source !== "") _load(layerA, source)
        }
    }

    // Speech bubble, same tooltip token dispatch as the companion
    Rectangle {
        id: rompBubble
        readonly property int pad: 10
        visible: opacity > 0
        // The flyby lives entirely in "leave", so it keeps its bubble mid-flight
        opacity: romp.line.length > 0 && (romp.phase !== "leave" || romp.planType === "flyby") ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        implicitWidth: rompBubbleText.width + pad * 2
        implicitHeight: rompBubbleText.implicitHeight + pad * 2
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
             : Appearance.rounding.verysmall
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassTooltip
             : Appearance.inirEverywhere ? Appearance.inir.colLayer2
             : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipSurface
             : Appearance.colors.colLayer3
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer3Hover
        x: Math.max(12, Math.min(sprite.x + sprite.width / 2 - width / 2, romp.width - width - 12))
        y: sprite.y - height - 8

        Rectangle {
            width: 10
            height: 10
            x: Math.max(12, Math.min(sprite.x + sprite.width * 0.5 - rompBubble.x - width / 2,
                                     rompBubble.width - width - 12))
            y: rompBubble.height - height / 2
            rotation: 45
            z: -1
            color: rompBubble.color
            border.width: rompBubble.border.width
            border.color: rompBubble.border.color
        }

        StyledText {
            id: rompBubbleText
            anchors.centerIn: parent
            text: romp.line
            width: Math.min(implicitWidth, 240)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                 : Appearance.inirEverywhere ? Appearance.inir.colText
                 : Appearance.colors.colOnLayer3
        }
    }
}
