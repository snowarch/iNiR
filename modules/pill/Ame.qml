pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common

/**
 * 飴 Ame, the shapeshifter. One molten-glass bead, the shell's only glowing
 * element. Idle it just breathes (2.5% scale over ~8s). No music/audio/physics
 * coupling; every motion is a fixed, scripted timeline.
 *
 * Travel: a form change runs the full shapeshift over `PillMotion.shapeshift` ms.
 * anticipation stretch, a remnant droplet pinching off at the origin, a
 * quadratic-bezier flight with a tapered streak, a three-droplet landing splash,
 * then an easeOutBack settle into the new form. The flight launches once and
 * tracks a moving target live (bezier endpoint, control point and heading
 * recomputed per frame), so anchors that slide with the pill's 320ms morph bend
 * the arc, no restart. Short-distance form change skips travel and plays the
 * settle in place. Same-form target moves (hover width, seam progress, mixer
 * focus hops, seeks) glide over `PillMotion.glide` ms, chasing the anchor, never
 * escalating to a flight.
 *
 * Forms: "rest" breathing bead, "caret" blinking launcher capsule, "seam" media
 * bead, "ring" calendar ring, "dock" plain bead (mixer/power/link), "off"
 * hidden. Entering "off" fades out over `PillMotion.fast` ms; leaving it snaps to
 * the current anchor and pops back with the settle, so toast/OSD handoffs don't
 * ghost-fly from stale positions. Body draws on a QtQuick Canvas: FrameAnimation
 * drives full-rate repaint only while the timeline, splash, remnant or a glide
 * is live; otherwise a Timer ticks the slow inner swirl at 12fps (30fps while
 * the caret blinks) to keep idle cost low for a 24/7 shell.
 */
Item {
    id: root

    property real s: 1
    property point point: Qt.point(0, 0)
    property string form: "rest"
    property real heat: 0
    property point wake: Qt.point(0, 0)
    property real wickDir: -1

    opacity: form === "off" ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
    visible: opacity > 0.001

    // User-facing knobs: visual style of the bead and a size multiplier
    // (bar.pill.soul.*). The enable gate lives in the pill's form binding.
    readonly property string beadStyle: Config.options?.bar?.pill?.soul?.style ?? "orb"
    readonly property real beadSize: Config.options?.bar?.pill?.soul?.size ?? 1

    readonly property real restR: 5 * s * beadSize
    readonly property real heatScale: 1 - 0.4 * heat
    readonly property real flightThreshold: 30 * s
    readonly property real pAntic: 0.146
    readonly property real pFly: 0.658

    property real bx: 0
    property real by: 0
    property string activeForm: "rest"
    property bool hidden: false
    property bool arcFlip: false
    property bool quickFlight: false
    property point lastTarget: Qt.point(0, 0)

    property real prog: 1
    property string phase: "idle"
    property point fromPoint: Qt.point(0, 0)
    property point ctrlPoint: Qt.point(0, 0)
    property real flightAng: 0
    property real flightDist: 0
    property real remnant: 0
    property point remnantPoint: Qt.point(0, 0)
    property real swirl: 0

    property real glideT: 1
    property point glideFrom: Qt.point(0, 0)
    property point glideTo: Qt.point(0, 0)

    readonly property bool timelineLive: prog < 1 || remnant > 0
    readonly property bool gliding: glideT < 1
    readonly property bool blinking: activeForm === "caret"
    readonly property bool busy: timelineLive || gliding

    function clamp01(u) { return Math.max(0, Math.min(1, u)); }
    function smoothstep(u) { return u * u * (3 - 2 * u); }
    function easeInOutQuint(u) { return u < 0.5 ? 16 * u * u * u * u * u : 1 - Math.pow(-2 * u + 2, 5) / 2; }
    function easeOutBack(u) { const c = 1.70158; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); }

    function bez(a, c, b, u) {
        const v = 1 - u;
        return Qt.point(v * v * a.x + 2 * v * u * c.x + u * u * b.x,
                        v * v * a.y + 2 * v * u * c.y + u * u * b.y);
    }

    /**
     * Recompute heading, distance and the perpendicular bezier control point
     * for the current fromPoint->point pair. Called per frame during the antic
     * and fly phases so a target that slides mid-flight bends the arc and the
     * painted streak stays on the same curve as the bead. Arc side is latched
     * in startFlight (arcFlip); re-deciding it per frame would mirror the whole
     * curve in one frame when the target crosses the vertical through the origin.
     */
    function updateFlightGeo() {
        const dx = point.x - fromPoint.x;
        const dy = point.y - fromPoint.y;
        const dd = Math.hypot(dx, dy) || 1;
        flightDist = dd;
        flightAng = Math.atan2(dy, dx);
        let px = -dy / dd;
        let py = dx / dd;
        if (arcFlip) { px = -px; py = -py; }
        ctrlPoint = Qt.point((fromPoint.x + point.x) / 2 + px * dd * 0.22,
                             (fromPoint.y + point.y) / 2 + py * dd * 0.22);
    }

    function stopGlide() {
        glideAnim.stop();
        glideTo = Qt.point(bx, by);
        glideT = 1;
    }

    function startFlight(targetForm, quick) {
        quickFlight = quick === true;
        fromPoint = Qt.point(bx, by);
        arcFlip = point.x > fromPoint.x;
        updateFlightGeo();
        remnantAnim.stop();
        remnantPoint = Qt.point(bx, by);
        remnant = flightDist > root.flightThreshold ? 1 : 0;
        activeForm = targetForm;
        stopGlide();
        settleAnim.stop();
        flightAnim.restart();
        if (remnant > 0)
            remnantAnim.restart();
    }

    /**
     * In-place transform: skip travel, replay only the settle window (splash +
     * easeOutBack pop) so a nearby form change still reads as a shapeshift
     * without a pointless flight.
     */
    function startMorph(targetForm) {
        flightAnim.stop();
        activeForm = targetForm;
        prog = root.pFly;
        settleAnim.restart();
    }

    function startGlide(target) {
        glideFrom = Qt.point(bx, by);
        glideTo = target;
        glideT = 0;
        glideAnim.restart();
    }

    /**
     * Wake from the hidden ("off") state. Re-shows start at the wake anchor: the
     * bead condenses there, then flies to its target if far or pops in place if
     * near. Positions from before the hidden period never leak in.
     */
    function appear() {
        stopGlide();
        remnantAnim.stop();
        remnant = 0;
        bx = wake.x;
        by = wake.y;
        if (Math.hypot(point.x - bx, point.y - by) > root.flightThreshold) {
            startFlight(form, true);
        } else {
            bx = point.x;
            by = point.y;
            startMorph(form);
        }
    }

    function retarget() {
        const dx = point.x - bx;
        const dy = point.y - by;
        const dd = Math.hypot(dx, dy);
        if (form !== activeForm) {
            if (dd > root.flightThreshold) {
                startFlight(form);
            } else {
                flightAnim.stop();
                settleAnim.stop();
                if (dd > 0.5)
                    startGlide(point);
                startMorph(form);
            }
        } else if (timelineLive && prog < root.pFly) {
            const jump = Math.hypot(point.x - lastTarget.x, point.y - lastTarget.y);
            if (jump > root.flightThreshold) {
                flightAnim.stop();
                startGlide(point);
                prog = 1;
            }
        } else if (dd > 0.5) {
            startGlide(point);
        } else if (!gliding) {
            bx = point.x;
            by = point.y;
        }
    }

    /**
     * Coalesced decision point. form and point are sibling bindings in Pill
     * whose change handlers fire mid-cascade in unspecified order. Deciding
     * synchronously would read a stale partner value (a far form change sees
     * dd≈0 against the not-yet-updated point and quietly degrades the flight to
     * an in-place morph). Qt.callLater defers the decision until both bindings
     * have settled, and collapses the per-frame handler bursts of a pill morph
     * into one retarget per tick. lastTarget tracks the previous settled anchor
     * so a mid-flight DISCRETE hop (mixer focus jump, seek snap) is told apart
     * from a morph slide and handed to a glide rather than teleporting the
     * airborne bead.
     */
    function decide() {
        if (form === "off") {
            if (hidden)
                return;
            hidden = true;
            flightAnim.stop();
            settleAnim.stop();
            remnantAnim.stop();
            remnant = 0;
            stopGlide();
            prog = 1;
            return;
        }
        if (hidden) {
            hidden = false;
            appear();
        } else {
            retarget();
        }
        lastTarget = Qt.point(point.x, point.y);
    }

    onPointChanged: Qt.callLater(root.decide)
    onFormChanged: Qt.callLater(root.decide)
    onHeatChanged: canvas.requestPaint()

    Component.onCompleted: {
        bx = point.x;
        by = point.y;
        activeForm = form;
        hidden = form === "off";
        lastTarget = Qt.point(point.x, point.y);
    }

    NumberAnimation {
        id: flightAnim
        target: root
        property: "prog"
        from: 0
        to: 1
        duration: root.quickFlight ? Math.round(460 * PillMotion.mult) : PillMotion.shapeshift
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: settleAnim
        target: root
        property: "prog"
        to: 1
        duration: Math.round(PillMotion.shapeshift * (1 - root.pFly))
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: remnantAnim
        target: root
        property: "remnant"
        from: 1
        to: 0
        duration: Math.round(350 * PillMotion.mult)
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: glideAnim
        target: root
        property: "glideT"
        from: 0
        to: 1
        duration: PillMotion.glide
        easing.type: Easing.OutCubic
    }

    onProgChanged: {
        if (prog < pAntic) {
            phase = "antic";
            updateFlightGeo();
            bx = fromPoint.x;
            by = fromPoint.y;
        } else if (prog < pFly) {
            phase = "fly";
            updateFlightGeo();
            const u = easeInOutQuint((prog - pAntic) / (pFly - pAntic));
            const p = bez(fromPoint, ctrlPoint, point, u);
            bx = p.x;
            by = p.y;
        } else {
            if (phase === "fly")
                flightAng = Math.atan2(point.y - ctrlPoint.y, point.x - ctrlPoint.x);
            phase = prog >= 1 ? "idle" : "settle";
            if (!gliding) {
                bx = point.x;
                by = point.y;
            }
        }
    }

    onGlideTChanged: if (gliding || glideT === 1) {
        bx = glideFrom.x + (glideTo.x - glideFrom.x) * glideT;
        by = glideFrom.y + (glideTo.y - glideFrom.y) * glideT;
        if (glideT >= 1) {
            bx = glideTo.x;
            by = glideTo.y;
        }
    }

    FrameAnimation {
        running: root.visible && root.busy
        onTriggered: {
            root.swirl += frameTime * 0.5;
            canvas.requestPaint();
        }
    }

    Timer {
        running: root.visible && !root.busy
        interval: root.blinking ? 33 : 83
        repeat: true
        onTriggered: {
            root.swirl += interval * 0.0005;
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        antialiasing: true

        readonly property real breathe: 1 + 0.0125 * Math.sin(root.swirl * 0.32)

        function bead(ctx, x, y, R, stretch, ang, alpha) {
            ctx.save();
            if (alpha !== undefined)
                ctx.globalAlpha = alpha;
            ctx.translate(x, y);
            ctx.rotate(ang);
            ctx.scale(1 + stretch, 1 / (1 + stretch * 0.55));
            ctx.rotate(-ang);
            if (root.beadStyle === "ring") {
                // Hollow ring: a calm outline, no inner life.
                ctx.beginPath();
                ctx.arc(0, 0, Math.max(0.5, R - 0.9 * root.s), 0, 7);
                ctx.strokeStyle = PillTheme.hex(PillTheme.vermLit);
                ctx.lineWidth = 1.8 * root.s;
                ctx.stroke();
                ctx.restore();
                return;
            }
            const hg = ctx.createRadialGradient(-R * 0.32, -R * 0.38, 0, 0, 0, R);
            hg.addColorStop(0, PillTheme.flameInk);
            hg.addColorStop(0.55, PillTheme.vermLit);
            hg.addColorStop(0.92, PillTheme.verm);
            hg.addColorStop(1, PillTheme.flameEmber);
            ctx.beginPath();
            ctx.arc(0, 0, R, 0, 7);
            ctx.fillStyle = hg;
            ctx.fill();
            if (root.beadStyle === "ember") {
                // Plain ember: gradient dot without the swirl or highlight.
                ctx.restore();
                return;
            }
            ctx.save();
            ctx.beginPath();
            ctx.arc(0, 0, R, 0, 7);
            ctx.clip();
            ctx.globalAlpha = (alpha === undefined ? 1 : alpha) * 0.35;
            for (let k = 0; k < 2; k++) {
                ctx.beginPath();
                ctx.arc(0, 0, R * (0.45 + k * 0.22),
                        root.swirl * (0.5 + k * 0.25) + k * 2.6,
                        root.swirl * (0.5 + k * 0.25) + k * 2.6 + 2.4);
                ctx.strokeStyle = k ? PillTheme.flameBurn : PillTheme.flameTip;
                ctx.lineWidth = 1.6 * root.s;
                ctx.stroke();
            }
            ctx.restore();
            ctx.beginPath();
            ctx.ellipse(-R * 0.34 - R * 0.30, -R * 0.42 - R * 0.18, R * 0.60, R * 0.36);
            ctx.fillStyle = "rgba(255,246,240,0.6)";
            ctx.fill();
            ctx.beginPath();
            ctx.arc(0, 0, Math.max(0.5, R - 0.8 * root.s), Math.PI * 0.25, Math.PI * 0.75);
            ctx.strokeStyle = "rgba(255,217,194,0.45)";
            ctx.lineWidth = 1.2 * root.s;
            ctx.stroke();
            ctx.restore();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.visible)
                return;

            const S = root.s;
            const bx = root.bx;
            const by = root.by;
            const baseR = root.restR;

            if (root.remnant > 0 && root.phase !== "antic") {
                const rr = baseR * 0.5 * root.remnant;
                if (rr > 0.4 * S)
                    bead(ctx, root.remnantPoint.x + (1 - root.remnant) * 6 * S, root.remnantPoint.y,
                         rr, 0, 0, root.remnant * 0.9);
            }

            if (root.phase === "antic") {
                const q = root.clamp01(root.prog / root.pAntic);
                const pull = root.smoothstep(q) * 0.55;
                bead(ctx, bx, by, baseR, pull, root.flightAng);
                return;
            }

            if (root.phase === "fly") {
                const q = (root.prog - root.pAntic) / (root.pFly - root.pAntic);
                const u = root.easeInOutQuint(root.clamp01(q));
                const tail = Math.max(0, u - 0.26 * Math.sin(Math.PI * Math.min(1, q * 1.4)));
                const NSEG = 15;
                for (let i = 0; i < NSEG; i++) {
                    const u1 = tail + (u - tail) * (i / NSEG);
                    const u2 = tail + (u - tail) * ((i + 1) / NSEG);
                    const a2 = root.bez(root.fromPoint, root.ctrlPoint, root.point, u1);
                    const b2 = root.bez(root.fromPoint, root.ctrlPoint, root.point, u2);
                    const fI = i / NSEG;
                    ctx.beginPath();
                    ctx.moveTo(a2.x, a2.y);
                    ctx.lineTo(b2.x, b2.y);
                    ctx.strokeStyle = fI > 0.6 ? PillTheme.vermLit : PillTheme.verm;
                    ctx.lineWidth = (0.8 + 6.5 * fI * fI) * S;
                    ctx.lineCap = "round";
                    ctx.globalAlpha = 0.12 + 0.55 * fI;
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
                const speed = Math.sin(Math.PI * root.clamp01(q));
                const d1 = root.bez(root.fromPoint, root.ctrlPoint, root.point, Math.min(1, u + 0.01));
                const tang = Math.atan2(d1.y - by, d1.x - bx);
                bead(ctx, bx, by, baseR * 1.62, speed * 1.0, tang);
                return;
            }

            const settling = root.phase === "settle";
            const q = settling ? root.clamp01((root.prog - root.pFly) / (1 - root.pFly)) : 1;
            const e = settling ? root.easeOutBack(q) : 1;
            const fadeIn = settling ? root.smoothstep(root.clamp01(q * 1.8)) : 1;

            if (settling && q < 0.55) {
                const sq = q / 0.55;
                const hop = Math.sin(Math.PI * sq);
                const angles = [-2.35, -1.57, -0.79];
                for (let i = 0; i < 3; i++) {
                    const sa = angles[i];
                    const sr = 13 * S * hop;
                    const sx2 = bx + Math.cos(sa) * sr;
                    const sy2 = by + Math.sin(sa) * sr * 1.25;
                    ctx.beginPath();
                    ctx.arc(sx2, sy2, (2.2 - 0.9 * sq) * S, 0, 7);
                    ctx.fillStyle = PillTheme.vermLit;
                    ctx.globalAlpha = hop * 0.85;
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
            }

            const f = root.activeForm;

            if (f === "caret") {
                const blink = settling ? 1 : (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(root.swirl * 5.7)));
                const hgt = 15 * S * e;
                const wdt = (2.5 + 6 * (1 - fadeIn)) * S;
                ctx.globalAlpha = blink;
                ctx.beginPath();
                ctx.roundedRect(bx - wdt / 2, by - hgt / 2, wdt, Math.max(2 * S, hgt), Math.min(wdt, hgt) / 2, Math.min(wdt, hgt) / 2);
                ctx.fillStyle = PillTheme.flameInk;
                ctx.fill();
                ctx.globalAlpha = 1;
                return;
            }

            if (f === "seam") {
                const R = (3.5 + 1.5 * (1 - fadeIn)) * S;
                bead(ctx, bx, by, R * (settling ? (0.8 + 0.2 * e) : 1), 0, 0);
                return;
            }

            if (f === "soul") {
                const r = 2.8 * S * (settling ? (0.7 + 0.3 * e) : 1);
                const wl = 7 * S * fadeIn;
                const wy0 = by + root.wickDir * (r + 1.5 * S);
                const wg = ctx.createLinearGradient(0, wy0, 0, wy0 + root.wickDir * wl);
                wg.addColorStop(0, Qt.rgba(1, 0.851, 0.761, 0.55 * fadeIn));
                wg.addColorStop(1, Qt.alpha(PillTheme.vermLit, 0));
                ctx.beginPath();
                ctx.moveTo(bx, wy0);
                ctx.lineTo(bx, wy0 + root.wickDir * wl);
                ctx.strokeStyle = wg;
                ctx.lineWidth = 1.1 * S;
                ctx.lineCap = "round";
                ctx.stroke();
                bead(ctx, bx, by, r, settling ? (1 - q) * 0.3 : 0, 0);
                return;
            }

            if (f === "tick") {
                const rx = 5.5 * S * (settling ? (0.75 + 0.25 * e) : 1);
                const ry = 3.1 * S;
                ctx.save();
                ctx.translate(bx, by);
                ctx.scale(rx / ry, 1);
                const tg = ctx.createRadialGradient(-ry * 0.3, -ry * 0.35, 0, 0, 0, ry);
                tg.addColorStop(0, PillTheme.flameInk);
                tg.addColorStop(0.55, PillTheme.vermLit);
                tg.addColorStop(0.92, PillTheme.verm);
                tg.addColorStop(1, PillTheme.flameEmber);
                ctx.beginPath();
                ctx.arc(0, 0, ry, 0, 7);
                ctx.fillStyle = tg;
                ctx.globalAlpha = Math.max(0.25, fadeIn);
                ctx.fill();
                ctx.restore();
                ctx.beginPath();
                ctx.ellipse(bx - rx * 0.55, by - ry * 0.75, rx * 0.55, ry * 0.4);
                ctx.fillStyle = Qt.rgba(1, 0.965, 0.941, 0.55 * fadeIn);
                ctx.fill();
                return;
            }

            if (f === "rowseam") {
                const sh = 18 * S * (settling ? (0.6 + 0.4 * e) : 1);
                const sw = 4.2 * S;
                const sg3 = ctx.createLinearGradient(0, by - sh / 2, 0, by + sh / 2);
                sg3.addColorStop(0, Qt.alpha(PillTheme.vermLit, 0.92));
                sg3.addColorStop(0.5, PillTheme.flameInk);
                sg3.addColorStop(1, Qt.alpha(PillTheme.vermLit, 0.92));
                ctx.beginPath();
                ctx.roundedRect(bx - sw / 2, by - sh / 2, sw, sh, sw / 2, sw / 2);
                ctx.fillStyle = sg3;
                ctx.globalAlpha = Math.max(0.85, fadeIn);
                ctx.fill();
                ctx.beginPath();
                ctx.ellipse(bx - sw * 0.26, by - sh * 0.3, sw * 0.28, sh * 0.18);
                ctx.fillStyle = Qt.rgba(1, 0.965, 0.941, 0.6);
                ctx.fill();
                ctx.globalAlpha = 1;
                if (fadeIn < 0.7)
                    bead(ctx, bx, by, 2.6 * S * (1 - fadeIn), 0, 0, 1 - fadeIn * 1.3);
                return;
            }

            if (f === "ring") {
                const R = (baseR + 6 * S) + 5 * S * root.smoothstep(fadeIn) * e;
                ctx.globalAlpha = 1;
                ctx.beginPath();
                ctx.arc(bx, by, Math.max(2 * S, R), 0, 7);
                ctx.strokeStyle = PillTheme.vermLit;
                ctx.lineWidth = Math.max(1.6 * S, (7 - 4.8 * fadeIn) * S);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(bx, by, Math.max(2 * S, R), -1.2, 0.4);
                ctx.strokeStyle = Qt.rgba(1, 0.851, 0.761, 0.7 * fadeIn);
                ctx.lineWidth = 1.4 * S;
                ctx.stroke();
                if (fadeIn < 0.6)
                    bead(ctx, bx, by, baseR * (1 - fadeIn), 0, 0, 1 - fadeIn * 1.5);
                return;
            }

            const land = settling ? (0.7 + 0.3 * e) : 1;
            const breathe = (f === "rest") ? canvas.breathe : 1;
            const r = baseR * breathe * land * (f === "dock" ? root.heatScale : 1);
            bead(ctx, bx, by, r, settling ? (1 - q) * 0.4 : 0, root.flightAng);
        }
    }

    /**
     * The blur layer allocates an FBO the size of the whole pill; while the bead
     * is hidden (wallpaper strip, toast, plain hover) that's pure GPU tax on an
     * empty canvas, so the layer only exists while something is drawn or fading.
     */
    layer.enabled: opacity > 0.001 || busy
    layer.effect: MultiEffect {
        blurEnabled: true
        blur: 0.34
        blurMax: 8
    }
}
