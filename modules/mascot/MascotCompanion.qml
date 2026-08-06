import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * Playful mascot companion: she occasionally peeks from a screen edge and
 * reacts to shell events (music, battery, updates, network). Strictly
 * non-invasive: input only on her sprite, never over fullscreen windows or
 * game mode, never while locked or on the session screen, rate-limited.
 * IPC target "mascot": poke() / appear(pose, edge) / hide().
 */
Scope {
    id: root

    readonly property bool companionEnabled: (Config.options?.mascot?.enable ?? false)
        && (Config.options?.mascot?.companion?.enable ?? true)
    readonly property int intervalMinutes: Config.options?.mascot?.companion?.intervalMinutes ?? 25
    readonly property int spriteSize: Config.options?.mascot?.companion?.size ?? 150
    readonly property string placement: Config.options?.mascot?.companion?.placement ?? "peek"
    readonly property int visibleSeconds: Config.options?.mascot?.companion?.visibleSeconds ?? 8
    readonly property int slideMs: Config.options?.mascot?.companion?.slideMs ?? 400
    // Per-peek entrance profile, re-rolled on every show so arrivals stop
    // feeling metronomic: sometimes she zips out, sometimes she creeps in
    // warily, sometimes the slide lands with an eager overshoot, and how far
    // she leans out of the edge varies too.
    property real _slideScale: 1
    property bool _bouncyIn: false
    property real _peekDepth: 0.07
    function _rollEntrance() {
        const r = Math.random()
        _slideScale = r < 0.18 ? 0.45 + Math.random() * 0.15
                    : r < 0.36 ? 1.6 + Math.random() * 0.6
                    : 0.85 + Math.random() * 0.3
        _bouncyIn = Math.random() < 0.22
        _peekDepth = 0.04 + Math.random() * 0.07
    }

    // Only peek from edges the user allows; fall back to any edge if all are off
    function _edgeAllowed(e) {
        // Never slide out from behind an open sidebar — overlapping an
        // active surface reads as a rendering glitch, not a visit
        if (e === "left" && GlobalStates.sidebarLeftOpen) return false
        if (e === "right" && GlobalStates.sidebarRightOpen) return false
        const cfg = Config.options?.mascot?.companion?.edges
        if (!cfg) return true
        const v = cfg[e]
        return v === undefined ? true : v
    }
    function _fixEdge(e) {
        if (_edgeAllowed(e)) return e
        for (const alt of ["left", "right", "top", "bottom"])
            if (_edgeAllowed(alt)) return alt
        return e
    }
    readonly property bool suppressed: GameMode.active || GameMode.hasVisibleFullscreenWindow
        || GlobalStates.screenLocked || GlobalStates.sessionOpen

    // Where the user's main panel actually lives — contextual reactions and
    // panel-flavored peeks come from this edge instead of a hardcoded "top"
    readonly property string panelEdge: (Config.options?.panelFamily ?? "ii") === "waffle" ? "bottom"
        : (Config.options?.bar?.bottom ?? false) ? "bottom"
        : (Config.options?.bar?.vertical ?? false) ? "left"
        : "top"

    // Which screen she lives on: the configured primary, or the one with
    // the focused workspace (multi-monitor setups)
    readonly property var companionScreen: {
        if ((Config.options?.mascot?.companion?.monitor ?? "primary") === "focused") {
            const out = NiriService.currentOutput ?? ""
            if (out.length > 0) {
                const s = Quickshell.screens.find(scr => scr.name === out)
                if (s) return s
            }
        }
        return GlobalStates.primaryScreen
    }

    property string pose: "edge-peek"
    property string edge: "right" // "left" | "right" | "top"
    property bool showing: false
    property string line: ""
    // Art-style lock: "classic" (pixel-art line) vs "street" (streetwear
    // line) are two different renders of her, not interchangeable frames of
    // the same one. Set once from the pose that opened this visit; click
    // escalation and stare reactions stay on that style instead of jumping
    // mid-visit. Chibi has no street counterpart, so it is style-neutral.
    property string _visitArtStyle: ""
    function _artStyleOf(poseName: string): string {
        if (poseName.startsWith("chibi-")) return ""
        return poseName.startsWith("street-") ? "street" : "classic"
    }
    function _filterByArtStyle(pool) {
        if (!pool || !pool.length || !root._visitArtStyle) return pool
        const matched = pool.filter(p => {
            const s = root._artStyleOf(p)
            return s === "" || s === root._visitArtStyle
        })
        return matched.length ? matched : pool
    }
    property double _lastShownAt: 0
    property int _clickCount: 0
    property string _contextualSource: ""
    property var _manifest: ({ idlePicks: [], linesByPose: ({}), idleLines: [], animatedPoses: [], linesByPoseSource: ({}), moodLines: ({}), voiceLines: ({}), smartLines: ({}) })

    property string _lastGameName: ""
    property var _screenTimeMilestonesSeen: []
    property int _commentedSessionRevision: -1
    property real _commentedReturnAt: 0

    // What she says, by pose. Rendered as a QML bubble — translated,
    // theme-aware, never baked into the image.
    readonly property var _linesByPose: _manifest.linesByPose && Object.keys(_manifest.linesByPose).length
        ? _manifest.linesByPose
        : ({
            "music-vibe": [Translation.tr("Decent taste. Barely."), Translation.tr("Volume up. Trust me.")],
            "battery-low": [Translation.tr("Feed the battery. Now.")],
            "update-ready": [Translation.tr("Update's ready. I read the changelog so you don't have to.")],
            "cable-defeat": [Translation.tr("The internet left. It's not me.")],
            "sleep-dnd": [Translation.tr("Shh. Do-not-disturb includes me. Rude.")],
            "late-night": [Translation.tr("Sleep is a feature, you know.")],
            "morning-coffee": [Translation.tr("Coffee first. Talk later.")],
            "tea-break": [Translation.tr("Tea. Don't rush me.")],
            "gaming-focus": [Translation.tr("GG. Who won?"), Translation.tr("Back already? Rematch?")],
            "workspace-juggle": [Translation.tr("Pick one already."), Translation.tr("They're all the same workspace to me.")]
        })
    readonly property var _linesByPoseSource: _manifest.linesByPoseSource ?? ({})
    readonly property var _moodLines: _manifest.moodLines ?? ({})
    readonly property var _voiceLines: _manifest.voiceLines ?? ({})
    readonly property string _configuredVoiceMode: Config.options?.mascot?.personality?.voiceMode ?? "adaptive"
    readonly property string _effectiveVoiceMode: {
        const explicit = ["casual", "dry", "composed", "chaotic"]
        if (explicit.includes(root._configuredVoiceMode))
            return root._configuredVoiceMode
        if (!(Config.options?.mascot?.personality?.enabled ?? true))
            return "casual"
        switch (MascotMood.currentMood ?? "neutral") {
        case "hyper": return "chaotic"
        case "contemplative": return "composed"
        case "sleepy":
        case "snarky": return "dry"
        default: return "casual"
        }
    }
    readonly property var _idleLines: _manifest.idleLines?.length
        ? _manifest.idleLines
        : [
            Translation.tr("Just checking."),
            Translation.tr("Still no crashes? Impressive."),
            Translation.tr("Your config… bold choices."),
            Translation.tr("Hydrate."),
            Translation.tr("Super+/ shows the keybinds. Just saying."),
            Translation.tr("I saw that typo.")
        ]

    // Click ladder pose/line pools — manifest-driven, translated at pick time
    readonly property var _clickTier1Poses: _manifest.clickTiers?.tier1?.poses ?? ["annoyed-poked", "shy-flustered", "error-annoyed"]
    readonly property var _clickTier1Lines: _manifest.clickTiers?.tier1?.lines ?? ["Do I look clickable to you?", "...What.", "Wow. Rude."]
    readonly property var _clickTier2Poses: _manifest.clickTiers?.tier2?.poses ?? ["purr-content", "heart-eyes-pat", "shy-flustered", "chibi-love"]
    readonly property var _clickTier2Lines: _manifest.clickTiers?.tier2?.lines ?? ["...okay. Pats are acceptable.", "Don't make it weird.", "...Hmph."]
    readonly property var _clickTier4Poses: _manifest.clickTiers?.tier4?.poses ?? ["chibi-rage", "laughing-roast", "facepalm", "chibi-cry"]
    readonly property var _clickTier4Lines: _manifest.clickTiers?.tier4?.lines ?? ["THAT'S IT. I'm out.", "Banned. Forever.", "CONSEQUENCES."]

    // Stare-notice reactions — manifest-driven, anti-repeat via _recentLines
    readonly property var _stareReactions: _manifest.stareReactions?.length
        ? _manifest.stareReactions
        : [
            { pose: "shy-flustered", line: "...What." },
            { pose: "fisheye-inspect", line: "Take a picture. It lasts longer." },
            { pose: "annoyed-poked", line: "Creeping is still creeping." }
        ]

    // Attention backoff: every peek that ends completely untouched (no
    // hover, no click) stretches the next idle visit a little; a single
    // interaction resets the streak. She reads the room instead of nagging.
    property int _ignoredStreak: 0
    property bool _peekTouched: false
    readonly property real _attentionFactor: 1 + Math.min(_ignoredStreak, 6) * 0.25

    // Anti-repetition memory: she never repeats a recent line or pose,
    // which is most of what "she feels scripted" was.
    property var _recentLines: []
    property var _recentPoses: []
    property var _recentContexts: []
    function _remember(list, item, cap) {
        list.push(item)
        while (list.length > cap) list.shift()
    }
    function _pickFrom(pool) {
        if (!pool || !pool.length) return ""
        const fresh = pool.filter(l => !_recentLines.includes(l))
        const src = fresh.length ? fresh : pool
        const pick = src[Math.floor(Math.random() * src.length)]
        _remember(_recentLines, pick, 12)
        return pick
    }
    function _pickPose(pool) {
        if (!pool || !pool.length) return ""
        const fresh = pool.filter(p => !_recentPoses.includes(p))
        const src = fresh.length ? fresh : pool
        const pick = src[Math.floor(Math.random() * src.length)]
        _remember(_recentPoses, pick, 10)
        return pick
    }

    // A line carrying %1 is only sayable when a value was handed in. With a
    // value we prefer those lines (the number is the joke); without one we must
    // exclude them or she says the literal token.
    function _poolForArg(pool, hasArg) {
        if (!pool || !pool.length) return pool
        const withSlot = pool.filter(l => l.includes("%1"))
        const withoutSlot = pool.filter(l => !l.includes("%1"))
        if (hasArg) return withSlot.length ? withSlot : withoutSlot
        return withoutSlot.length ? withoutSlot : []
    }

    function _lineFor(poseName) {
        const hasArg = root._pendingLineArg.length > 0
        // Contextual mode: try source-specific lines first
        if (root._contextualSource.length > 0
            && (Config.options?.mascot?.companion?.contextualPlacement ?? false)) {
            const sourcePool = _poolForArg(_linesByPoseSource[poseName], hasArg)
            if (sourcePool && sourcePool.length) return Translation.tr(_pickFrom(sourcePool))
        }
        const pool = _poolForArg(_linesByPose[poseName], hasArg)
        if (pool && pool.length) return Translation.tr(_pickFrom(pool))
        // Idle peeks only talk sometimes; silence is also personality. Voice
        // register and mood are separate axes so she can be sleepy-casual,
        // contemplative-composed, or explicitly pinned by the user.
        if (Math.random() < 0.55) {
            const moodEnabled = Config.options?.mascot?.personality?.enabled ?? true
            const mood = moodEnabled ? (MascotMood.currentMood ?? "neutral") : null
            const moodPool = mood ? (root._moodLines[mood] ?? []) : []
            const voicePool = root._voiceLines[root._effectiveVoiceMode] ?? []
            const custom = Config.options?.mascot?.companion?.customLines ?? []
            const baseLines = _idleLines.concat(custom.filter(l => (l ?? "").length > 0))
            const roll = Math.random()
            const all = moodPool.length > 0 && roll < 0.32 ? moodPool
                : voicePool.length > 0 && roll < 0.78 ? voicePool
                : baseLines
            return all.length ? Translation.tr(_pickFrom(all)) : ""
        }
        return ""
    }

    // Pretty-print an app identifier: strip reverse-dns (only if no spaces,
    // i.e. looks like an app_id, not a title), capitalize, truncate 40
    function _prettyAppName(s) {
        if (!s || s.length === 0) return ""
        let name = s
        if (!s.includes(" ")) {
            const dotIdx = s.lastIndexOf(".")
            name = dotIdx >= 0 ? s.substring(dotIdx + 1) : s
        }
        name = name.charAt(0).toUpperCase() + name.slice(1)
        return name.length > 40 ? name.substring(0, 37) + "..." : name
    }

    // Poses that exist as animated GIF loops instead of static PNGs
    readonly property var animatedPoses: _manifest.animatedPoses?.length
        ? _manifest.animatedPoses
        : ["tail-sway", "ear-twitch", "sleepy-nod", "wave-loop", "idle-blink", "idle-breathe"]
    readonly property var _fullBodyPoses: _manifest.fullBodyPoses ?? []

    // Some art is culturally specific (the mate gourd reads as a prop nobody
    // outside the Southern Cone owns). manifest.poseRegions maps such a pose to
    // the ISO country codes where it makes sense; unlisted poses show anywhere.
    // Without a resolved Weather location we cannot know, so we stay silent.
    readonly property var _poseRegions: _manifest.poseRegions ?? ({})

    function _poseAllowedHere(pose: string): bool {
        const allowed = _poseRegions[pose]
        if (!allowed || allowed.length === 0) return true
        const country = Weather.countryCode
        return country.length > 0 && allowed.indexOf(country) !== -1
    }

    // Poses gated to this user's country, ready to be mixed into the idle bag.
    readonly property var _regionalPoses: Object.keys(_poseRegions)
        .filter(p => _poseAllowedHere(p) && _fullBodyPoses.includes(p))

    readonly property var _idlePicks: _manifest.idlePicks?.length
        ? _manifest.idlePicks.filter(p => _fullBodyPoses.length === 0 || _fullBodyPoses.includes(p[0]))
        : [
            ["presence-idle-loop", "left"], ["presence-idle-loop", "right"],
            ["tail-sway", "right"], ["tea-break", "bottom"],
            ["hanging-claws", "top"]
        ]

    // Idle pick = the whole catalog + a few time/mood-flavored duplicates.
    // Flavor biases the odds gently; it never drowns out catalog variety,
    // and recent poses are filtered out so she rotates instead of looping.
    function _timeFlavoredPick() {
        const hour = (new Date()).getHours()
        const moodEnabled = Config.options?.mascot?.personality?.enabled ?? true
        const mood = moodEnabled ? (MascotMood.currentMood ?? "neutral") : "neutral"
        let bag = _idlePicks.slice()
        const add = (pose, edge, n) => {
            if (_fullBodyPoses.length > 0 && !_fullBodyPoses.includes(pose)) return
            for (let i = 0; i < n; i++) bag.push([pose, edge])
        }
        if (mood === "sleepy") { add("yawn-stretch", "left", 3); add("tea-break", "bottom", 2) }
        if (mood === "hyper") { add("stretching-break", "right", 2); add("low-angle-guard", "right", 2); add("tiptoe-sneak", "left", 1) }
        if (commentaryOn && hour >= 1 && hour < 6) { add("yawn-stretch", "left", 3); add("reading", "bottom", 2) }
        if (commentaryOn && hour >= 6 && hour < 11) add("presence-idle-loop", "left", 3)
        add("tea-break", "bottom", 2)
        _regionalPoses.forEach(pose => add(pose, "right", 2))
        add("presence-idle-loop", "right", 2); add("tail-sway", "left", 1)
        const fresh = bag.filter(p => !_recentPoses.includes(p[0]))
        const src = fresh.length ? fresh : bag
        return src[Math.floor(Math.random() * src.length)]
    }

    // Value spliced into the next peek line's %1 slot; cleared on every exit
    // path so a swallowed reaction can never leak its number into a later peek.
    property string _pendingLineArg: ""

    function show(poseName: string, edgeName: string): bool {
        if (!companionEnabled || suppressed || showing) {
            console.log(`[MascotCompanion] peek denied (enabled=${companionEnabled} suppressed=${suppressed} showing=${showing})`)
            _pendingLineArg = ""
            return false
        }
        edgeName = _fixEdge(edgeName)
        // Pose-edge coherence: edge-anchored art never appears from a wrong
        // edge, no matter what settings overrides or IPC calls request.
        const aff = _manifest.poseAffinity?.[poseName]
        if (aff && aff.length && !aff.includes(edgeName))
            edgeName = aff.find(e => _edgeAllowed(e)) ?? aff[0]

        // Edge switch mid-teardown: kill old window so slide-in originates from the new edge
        if (companionLoader.active && !showing && edgeName !== edge) {
            teardownTimer.stop()
        }

        console.log(`[MascotCompanion] peek: ${poseName} from ${edgeName}`)
        pose = poseName
        edge = edgeName
        _visitArtStyle = _artStyleOf(poseName)
        // A reaction may hand us a value to splice into its %1 slot (e.g. the
        // actual battery percentage). Consumed once, never leaks to the next peek.
        const picked = _lineFor(poseName)
        line = _pendingLineArg.length > 0 ? picked.arg(_pendingLineArg) : picked
        _pendingLineArg = ""
        _peekTouched = false
        _clickCount = 0
        _rollEntrance()
        // Dwell jitter: quick drive-by peeks and lingering stays instead of a
        // fixed on-screen time (re-rolled per peek, so the binding is moot).
        hideTimer.interval = Math.max(3, visibleSeconds) * 1000 * (0.7 + Math.random() * 0.6)
        _lastShownAt = Date.now()
        showing = true
        hideTimer.restart()
        return true
    }

    // Context brain: idle peeks that comment on what's actually happening
    // instead of pure random. Each candidate names a manifest contextLines
    // pool; %1 in a line is filled with the candidate's arg.
    property string _lastContext: ""
    // Personal observations (your uptime, your 3AM, your app marathons) are
    // charming to some and grating to others — one switch turns them off
    readonly property bool commentaryOn: Config.options?.mascot?.personality?.commentary ?? true
    function _smartCandidates() {
        const out = []
        const now = new Date()
        const day = now.getDay()
        const hour = now.getHours()
        if (_eventEnabled("music") && _looksLikeMusic()) {
            const t = MprisController.activePlayer?.trackTitle ?? ""
            // An untitled track would render the line as an empty quote.
            if (t.length > 0)
                out.push({ key: "media-playing", pose: "headphone-groove-full-loop", edge: "right", arg: t.length > 40 ? t.substring(0, 37) + "..." : t })
        }
        const notifCount = Notifications.list?.length ?? 0
        if (commentaryOn && notifCount >= 10)
            out.push({ key: "notif-pileup", pose: "package-lifter", edge: "right", arg: notifCount })
        const upDays = parseInt((DateTime.uptime.match(/(\d+)\s*d/) ?? [])[1] ?? "0")
        if (commentaryOn && upDays >= 2)
            out.push({ key: "uptime-days", pose: "yawn-stretch", edge: "left", arg: upDays })
        if (day === 1 && hour >= 6 && hour < 12)
            out.push({ key: "monday", pose: "tea-break", edge: "bottom" })
        if (day === 5 && hour >= 20)
            out.push({ key: "friday-night", pose: "handheld-gaming", edge: "right" })
        if ((day === 0 || day === 6) && hour >= 12 && hour < 20)
            out.push({ key: "weekend", pose: "reading", edge: "bottom" })
        // Battery.percentage is 0 on a machine with no battery, so every battery
        // check needs Battery.available or it reads a desktop as a dead laptop.
        if (Battery.available && Battery.isPluggedIn && Battery.percentage >= 0.97)
            out.push({ key: "battery-full", pose: "presence-idle-loop", edge: "left" })
        const screenTimeReady = ScreenTime.enabled && ScreenTime.ready
        if (commentaryOn && screenTimeReady
            && ScreenTime.currentSessionSeconds >= 45 * 60
            && ScreenTime.currentAppName.length > 0
            && root._commentedSessionRevision !== ScreenTime.sessionRevision) {
            out.push({
                key: "app-marathon",
                pose: "sit-laptop",
                edge: "bottom",
                arg: root._prettyAppName(ScreenTime.currentAppName)
            })
        }
        if (commentaryOn && screenTimeReady) {
            const total = ScreenTime.todayData?.totalSeconds ?? 0
            const milestones = [
                { key: "screen-time-8h", seconds: 8 * 3600, pose: "yawn-stretch" },
                { key: "screen-time-4h", seconds: 4 * 3600, pose: "tea-break" },
                { key: "screen-time-2h", seconds: 2 * 3600, pose: "stretching-break" }
            ]
            for (const milestone of milestones) {
                if (total >= milestone.seconds
                    && !root._screenTimeMilestonesSeen.includes(milestone.key)) {
                    out.push({ key: milestone.key, pose: milestone.pose, edge: "bottom" })
                    break
                }
            }
            if (ScreenTime.lastReturnAt > root._commentedReturnAt
                && ScreenTime.lastIdleDurationSeconds >= 5 * 60
                && Date.now() - ScreenTime.lastReturnAt < 10 * 60 * 1000) {
                out.push({
                    key: "break-return",
                    pose: "welcoming",
                    edge: "right",
                    arg: Math.max(5, Math.round(ScreenTime.lastIdleDurationSeconds / 60))
                })
            }
        }
        // Wet weather outside → umbrella commentary (wttr WWO rain/sleet/thunder codes)
        if (Weather.enabled) {
            const wet = ["176", "179", "182", "185", "200", "263", "266", "281", "284", "293", "296", "299", "302", "305", "308", "311", "314", "317", "320", "353", "356", "359", "386", "389", "392", "395"]
            const description = Weather.data?.description ?? ""
            if (description.length > 0 && wet.includes(String(Weather.data?.wCode ?? "113")))
                out.push({ key: "weather-wet", pose: "weather-windswept", edge: "right", arg: description })
        }
        // Music "playing" into a muted sink deserves a call-out
        if (commentaryOn && _eventEnabled("music") && MprisController.isPlaying && (Audio.sink?.audio?.muted ?? false))
            out.push({ key: "muted-media", pose: "headphone-groove-full-loop", edge: "right" })
        const winCount = NiriService.windows?.length ?? 0
        // heavy-lift is full-body art and read wrong from a bust-crop peek.
        if (commentaryOn && winCount >= 12)
            out.push({ key: "window-pileup", pose: "package-lifter", edge: "left", arg: winCount })
        if (Updates.available && Updates.count >= 25)
            out.push({ key: "updates-waiting", pose: "package-lifter", edge: "right", arg: Updates.count })
        const wsCount = Object.keys(NiriService.workspaces ?? ({})).length
        if (commentaryOn && wsCount >= 6)
            out.push({ key: "workspace-sprawl", pose: "workspace-portal", edge: "left", arg: wsCount })
        if (_eventEnabled("music") && MprisController.isPlaying
            && (Audio.sink?.audio?.volume ?? 0) >= 0.85 && !(Audio.sink?.audio?.muted ?? false))
            out.push({ key: "volume-blast", pose: "volume-wave-rider", edge: "right" })
        if (commentaryOn && hour >= 1 && hour < 5)
            out.push({ key: "deep-night", pose: "yawn-stretch", edge: "bottom" })
        // Keep several recent themes out of rotation. Remembering only the
        // immediately previous key made small candidate sets alternate.
        const fresh = out.filter(c => !root._recentContexts.includes(c.key))
        return fresh.length ? fresh : out.filter(c => c.key !== root._lastContext)
    }

    function _showWithLine(poseName, edgeName, lineText) {
        if (!show(poseName, edgeName)) return false
        line = lineText
        return true
    }

    function poke(): bool {
        // Chaos mode: once in a while the idle visit is a full desktop romp
        if (chaosEnabled && !rompActive
            && Date.now() - _lastRompAt > 30 * 60 * 1000
            && Math.random() < 0.12) {
            const r = Math.random()
            return startRomp(r < 0.15 ? "chase" : (r < 0.30 ? "hide" : "romp"))
        }
        const ctxs = _smartCandidates()
        const ctxLines = _manifest.contextLines ?? ({})
        if (ctxs.length && Math.random() < 0.35) {
            const c = ctxs[Math.floor(Math.random() * ctxs.length)]
            const pool = ctxLines[c.key] ?? []
            if (pool.length) {
                let text = Translation.tr(_pickFrom(pool))
                if (c.arg !== undefined) text = text.arg(c.arg)
                if (_showWithLine(c.pose, c.edge, text)) {
                    root._lastContext = c.key
                    root._remember(root._recentContexts, c.key, 6)
                    _remember(_recentPoses, c.pose, 10)
                    if (c.key.startsWith("screen-time-"))
                        root._remember(root._screenTimeMilestonesSeen, c.key, 3)
                    if (c.key === "app-marathon")
                        root._commentedSessionRevision = ScreenTime.sessionRevision
                    if (c.key === "break-return")
                        root._commentedReturnAt = ScreenTime.lastReturnAt
                    return true
                }
                return false
            }
        }
        // Fall back to the flavored candidate bag (already avoids recent poses)
        const pick = _timeFlavoredPick()
        _remember(_recentPoses, pick[0], 10)
        return show(pick[0], pick[1])
    }

    // Independent detectors share one long cooldown so they cannot take turns
    // interrupting the user while each appears individually rate-limited.
    readonly property int _reactionCooldownMs: 8 * 60 * 1000
    function _showReaction(poseName, edgeName, sourceWidget) {
        if (Date.now() - _lastShownAt < _reactionCooldownMs) {
            console.log(`[MascotCompanion] reaction '${poseName}' swallowed by cooldown`)
            root._pendingLineArg = ""
            return false
        }
        const contextualOn = Config.options?.mascot?.companion?.contextualPlacement ?? false
        if (contextualOn && sourceWidget.length > 0) {
            root._contextualSource = sourceWidget
            show(poseName, root.panelEdge)
        } else {
            root._contextualSource = ""
            show(poseName, edgeName)
        }
        return true
    }
    // Every event reaction is user-configurable: on/off per event, and an
    // optional fixed pose override (settings) replacing the manifest pool.
    function _eventEnabled(key) {
        const e = Config.options?.mascot?.companion?.events
        const v = e ? e[key] : undefined
        return v === undefined ? true : v
    }
    function _eventPose(key, pool) {
        const p = Config.options?.mascot?.companion?.eventPoses
        const v = p ? (p[key] ?? "") : ""
        return v.length > 0 ? v : _pickPose(pool ?? [])
    }

    // Event reactions are pose POOLS (manifest "reactions") so the same
    // trigger never parades the same image; the line follows the picked pose.
    readonly property var _reactionMap: _manifest.reactions ?? ({})
    function reactEvent(key) {
        if (!_eventEnabled(key)) return
        const fallback = ({
            "battery": { poses: ["power-cord-yank"], edge: "left", source: "battery" },
            "update": { poses: ["package-lifter"], edge: "top", source: "update" },
            "network": { poses: ["network-signal-fishing"], edge: "bottom", source: "network" },
            "dnd": { poses: ["tea-break"], edge: "bottom", source: "dnd" },
            "notification": { poses: ["cleanup-sweep-loop"], edge: "right", source: "" },
            "wallpaper": { poses: ["wallpaper-color-sweep-loop"], edge: "right", source: "" },
            "screenshot": { poses: ["snapshot-director-loop"], edge: "right", source: "" },
            "gaming": { poses: ["handheld-gaming"], edge: "right", source: "" },
            "workspace": { poses: ["workspace-portal"], edge: "right", source: "" },
            "unlock": { poses: ["polkit-bouncer"], edge: "right", source: "" }
        })
        const r = _reactionMap[key] ?? fallback[key]
        if (!r) return
        _showReaction(_eventPose(key, r.poses), r.edge ?? "right", r.source ?? "")
    }
    function _reactWithLine(poseName, edgeName, sourceWidget, lineText) {
        if (_showReaction(poseName, edgeName, sourceWidget))
            root.line = lineText
    }

    function hide() {
        hideTimer.stop()
        showing = false
    }

    Timer {
        id: idleTimer
        running: root.companionEnabled && !root.showing && !root.suppressed
        repeat: true
        interval: Math.max(3, root.intervalMinutes) * 60000 * (0.75 + Math.random() * 0.5) * root._attentionFactor
        onTriggered: {
            interval = Math.max(3, root.intervalMinutes) * 60000 * (0.75 + Math.random() * 0.5) * root._attentionFactor
            root.poke()
        }
    }

    Timer {
        id: hideTimer
        interval: Math.max(3, root.visibleSeconds) * 1000
        onTriggered: {
            if (companionLoader.item?.hovered ?? false) { restart(); return }
            root.showing = false
        }
    }

    // If a fullscreen window / game / lock appears mid-peek, vanish instantly
    onSuppressedChanged: if (suppressed) hide()

    Connections {
        target: MprisController
        function onIsPlayingChanged() {
            if (MprisController.isPlaying) musicSustainTimer.restart()
            else musicSustainTimer.stop()
        }
    }

    // A real song has an artist; browser videos playing through MPRIS
    // usually don't. Requiring one (default) keeps her music commentary
    // to actual music — configurable for people who want everything.
    readonly property bool _musicRequireArtist: Config.options?.mascot?.companion?.musicRequireArtist ?? true
    function _looksLikeMusic() {
        if (!MprisController.isPlaying) return false
        const artist = MprisController.activePlayer?.trackArtist ?? ""
        return !_musicRequireArtist || artist.length > 0
    }

    Timer {
        id: musicSustainTimer
        interval: 7000
        onTriggered: {
            if (!root._eventEnabled("music") || !root._looksLikeMusic()) return
            const title = MprisController.activePlayer?.trackTitle ?? ""
            if (title.length === 0) return
            const artist = MprisController.activePlayer?.trackArtist ?? ""
            const mpose = root._eventPose("music", root._reactionMap.music?.poses ?? ["music-vibe"])
            const pool = root._manifest.smartLines?.["music-track"] ?? []
            if (pool.length === 0) { root._showReaction(mpose, "right", "media"); return }
            const usePool = artist.length > 0 ? pool : pool.filter(l => !l.includes("%2"))
            if (usePool.length === 0) { root._showReaction(mpose, "right", "media"); return }
            const truncatedTitle = title.length > 40 ? title.substring(0, 37) + "..." : title
            let text = Translation.tr(root._pickFrom(usePool))
            text = artist.length > 0 ? text.arg(truncatedTitle).arg(artist) : text.arg(truncatedTitle)
            root._reactWithLine(mpose, "right", "media", text)
        }
    }

    Connections {
        target: Battery
        function onIsLowAndNotChargingChanged() {
            // Battery.isLow already requires Battery.available, so this cannot
            // fire on a desktop. The line names the real charge left.
            if (!Battery.isLowAndNotCharging) return
            root._pendingLineArg = Math.round(Battery.percentage * 100) + "%"
            root.reactEvent("battery")
        }
    }

    Connections {
        target: ShellUpdates
        function onHasUpdateChanged() {
            if (ShellUpdates.hasUpdate) root.reactEvent("update")
        }
    }

    Connections {
        target: Network
        function onWifiStatusChanged() {
            if (Network.wifiStatus === "disconnected") root.reactEvent("network")
        }
    }

    Connections {
        target: Notifications
        function onSilentChanged() {
            if (Notifications.silent) root.reactEvent("dnd")
        }
        // Nosy: sometimes she comes to read your notifications. Chance-gated
        // on top of the shared long cooldown so it stays a treat, not a pest.
        function onNotify(notification) {
            if (Notifications.silent) return
            if (Math.random() > 0.3) return
            root.reactEvent("notification")
        }
    }

    // A wallpaper change re-themes the whole shell — she notices. The grace
    // window swallows the initial config-load "change" at startup.
    property double _bootAt: Date.now()
    Connections {
        target: Wallpapers
        function onEffectiveWallpaperPathChanged() {
            if (Date.now() - root._bootAt < 30 * 1000) return
            root.reactEvent("wallpaper")
        }
    }

    // She notices screenshots: after the region selector closes she may show
    // up asking to be in the picture. Chance-gated + shared long cooldown, and
    // delayed so she never appears while the capture is still happening.
    property bool _regionWasOpen: false
    Connections {
        target: GlobalStates
        function onRegionSelectorOpenChanged() {
            if (GlobalStates.regionSelectorOpen) { root._regionWasOpen = true; return }
            if (root._regionWasOpen) {
                root._regionWasOpen = false
                if (Math.random() < 0.5) screenshotTimer.restart()
            }
        }
        // Welcome-back after unlocking — she kept the place safe, obviously.
        // Boot grace swallows the initial lock-state settle at startup.
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) return
            if (Date.now() - root._bootAt < 30 * 1000) return
            if (Math.random() < 0.35) unlockTimer.restart()
        }
    }
    Timer { id: unlockTimer; interval: 2200; onTriggered: root.reactEvent("unlock") }
    Timer { id: screenshotTimer; interval: 1800; onTriggered: root.reactEvent("screenshot") }

    // "GG" after a gaming session ends — only if game mode was active for ≥8s
    // (filters out brief fullscreen video, IDE toggle, etc.)
    property bool _wasGaming: false
    Timer {
        id: gameModeSustainTimer
        interval: 8000
        onTriggered: {
            root._wasGaming = true
            const w = NiriService.activeWindow
            root._lastGameName = root._prettyAppName(w?.title ?? w?.app_id ?? "")
        }
    }
    Connections {
        target: GameMode
        function onActiveChanged() {
            if (GameMode.active) {
                gameModeSustainTimer.restart()
            } else {
                gameModeSustainTimer.stop()
                if (root._wasGaming) {
                    root._wasGaming = false
                    ggTimer.restart()
                }
            }
        }
    }
    Timer { id: ggTimer; interval: 3500; onTriggered: {
        if (!root._eventEnabled("gaming")) return
        if (root._lastGameName.length > 0) {
            const pool = root._manifest.smartLines?.["game-over"] ?? []
            if (pool.length > 0) {
                const pose = root._eventPose("gaming", root._reactionMap.gaming?.poses ?? ["gaming-focus"])
                root._reactWithLine(pose, "right", "", Translation.tr(root._pickFrom(pool)).arg(root._lastGameName))
                return
            }
        }
        root.reactEvent("gaming")
    }}

    // Frantic workspace switching earns commentary
    property int _wsHops: 0
    Connections {
        target: NiriService
        function onFocusedWorkspaceIndexChanged() {
            root._wsHops++
            wsHopsWindow.restart()
            if (root._wsHops >= 6) {
                root._wsHops = 0
                root.reactEvent("workspace")
            }
        }
    }
    Timer { id: wsHopsWindow; interval: 4000; onTriggered: root._wsHops = 0 }

    // ── Chaos mode: she runs across the desktop and messes with it ──────
    property bool rompActive: false
    property string rompMode: "romp"
    property double _lastRompAt: 0
    readonly property bool chaosEnabled: companionEnabled && MascotChaos.enabled
    function startRomp(mode: string): bool {
        if (!chaosEnabled || suppressed || rompActive) {
            console.log(`[MascotCompanion] romp denied (chaos=${chaosEnabled} suppressed=${suppressed} active=${rompActive})`)
            return false
        }
        _lastRompAt = Date.now()
        rompMode = mode
        rompActive = true
        return true
    }
    Loader {
        id: rompLoader
        active: root.rompActive
        sourceComponent: MascotRomp {
            rompScreen: root.companionScreen
            startMode: root.rompMode
            onFinished: root.rompActive = false
            // she always comes back to clean up her own destruction —
            // a few minutes later, in a random new form
            onWrecked: {
                encoreTimer.interval = (120 + Math.random() * 180) * 1000
                encoreTimer.restart()
            }
        }
    }
    Timer {
        id: encoreTimer
        onTriggered: if (root.chaosEnabled && !root.suppressed && !root.rompActive) root.startRomp("cleanup")
    }

    // ── System-event chaos: rare, reason-flavored romps instead of pure
    // idle rolls — a quick peek naming the trigger, then a real romp follows.
    // One shared cooldown across all four signals so she doesn't nag.
    property double _lastSystemChaosAt: 0
    function _checkSystemChaos(): void {
        if (!chaosEnabled || rompActive || suppressed) return
        if (!(Config.options?.mascot?.chaos?.systemEvents ?? true)) return
        if (Date.now() - _lastSystemChaosAt < 45 * 60 * 1000) return

        const triggers = _manifest.chaosTriggers ?? ({})
        let key = "", pose = ""
        // Without Battery.available this reads a desktop (percentage 0, never
        // "plugged in") as a laptop at 0% and romps about a battery it lacks.
        if (Battery.available && Battery.percentage <= 0.15 && !Battery.isPluggedIn) {
            key = "batteryCritical"; pose = "power-cord-yank"
        } else if (Notifications.list.length >= 8) {
            key = "notificationPileup"; pose = "notification-scout"
        } else {
            const hour = new Date().getHours()
            if (hour >= 1 && hour < 5) { key = "bedtime"; pose = "yawn-stretch" }
        }
        if (key.length === 0) return
        const lines = triggers[key]?.lines ?? []
        if (lines.length === 0) return
        // Organic, not naggy — only a fraction of eligible checks actually fire
        if (Math.random() > 0.25) return

        _lastSystemChaosAt = Date.now()
        if (_showWithLine(pose, panelEdge, Translation.tr(_pickFrom(lines)))) {
            _remember(_recentPoses, pose, 10)
            systemChaosFollowup.restart()
        }
    }
    // The peek needs a beat on screen before the romp window steals focus,
    // but the peek itself must be torn down first or the romp window opens
    // while peek #1 is still on screen — two Kiras visible simultaneously.
    // The followup hides the peek; a second timer waits for peek slide-out
    // (teardownTimer keeps the peek window alive for the exit animation)
    // before opening the romp window.
    Timer {
        id: systemChaosFollowup
        interval: 2600
        onTriggered: if (root.chaosEnabled && !root.rompActive && !root.suppressed) {
            if (root.showing) {
                root.hide()
                systemChaosRompAfterTeardown.restart()
            } else {
                root.startRomp("romp")
            }
        }
    }
    Timer {
        id: systemChaosRompAfterTeardown
        interval: Math.max(500, root.slideMs * root._slideScale + 120)
        onTriggered: if (root.chaosEnabled && !root.rompActive && !root.suppressed) root.startRomp("romp")
    }
    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root._checkSystemChaos()
    }

    IpcHandler {
        target: "mascot"

        function poke(): void { root.poke() }
        // Runtime-safe personality diagnostics. Deliberately omits app/window names.
        function status(): string {
            return JSON.stringify({
                enabled: root.companionEnabled,
                showing: root.showing,
                pose: root.pose,
                edge: root.edge,
                mood: MascotMood.currentMood ?? "neutral",
                configuredVoiceMode: root._configuredVoiceMode,
                effectiveVoiceMode: root._effectiveVoiceMode,
                commentary: root.commentaryOn,
                screenTime: {
                    enabled: ScreenTime.enabled,
                    ready: ScreenTime.ready,
                    userIdle: ScreenTime.userIdle,
                    todaySeconds: ScreenTime.todayData?.totalSeconds ?? 0,
                    sessionSeconds: ScreenTime.currentSessionSeconds,
                    sessionRevision: ScreenTime.sessionRevision,
                    lastIdleDurationSeconds: ScreenTime.lastIdleDurationSeconds
                },
                seenMilestones: root._screenTimeMilestonesSeen
            })
        }
        // Set the idle conversational register; "adaptive" follows MascotMood.
        function setVoice(mode: string): string {
            const valid = ["adaptive", "casual", "dry", "composed", "chaotic"]
            if (!valid.includes(mode))
                return "invalid voice mode"
            Config.setNestedValue("mascot.personality.voiceMode", mode)
            return mode
        }
        // Chaos mode: run across the desktop and mess with widgets/panels
        function romp(): void { root.startRomp("romp") }
        // Chase game: she hunts your mouse clicks — click her to catch her
        function chase(): void { root.startRomp("chase") }
        // Hide-and-seek: she tucks into a spot — click her before the
        // timeout to find her, otherwise she wins by default
        function hideSeek(): void { root.startRomp("hide") }
        // Undo the chaos: every displaced widget returns home
        function tidy(): void {
            MascotChaos.tidy()
            const t = root._manifest.chaos?.tidy ?? ({})
            if (root.show(t.pose ?? "cleanup-sweep-loop", "right"))
                root.line = Translation.tr(root._pickFrom(t.lines ?? ["You saw nothing."]))
        }
        // Named "appear" because "show" collides with the `qs ipc show` subcommand
        function appear(pose: string, edge: string): void { root.show(pose, edge) }
        function appearContextual(pose: string, sourceWidget: string): void {
            // Testable entry: skip reactTo cooldown (it's an explicit IPC call)
            root._contextualSource = sourceWidget
            root.show(pose, root.panelEdge)
        }
        // Easter eggs need a fixed line instead of the random _lineFor pick
        function appearWithLine(pose: string, edge: string, line: string): void {
            if (root.show(pose, edge)) root.line = line
        }
        function hide(): void { root.hide() }
    }

    // Load pose data / dialogue from manifest.json at runtime
    FileView {
        id: manifestFile
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        watchChanges: true
        onLoadedChanged: {
            if (!manifestFile.loaded) return
            try {
                root._manifest = JSON.parse(manifestFile.text())
            } catch (e) {
                console.warn("[MascotCompanion] manifest load failed:", e)
            }
        }
    }

    Loader {
        id: companionLoader
        active: root.showing || teardownTimer.running

        Timer {
            id: teardownTimer
            // Keep the window alive for the slide-out animation (configurable,
            // scaled by the entrance profile so slow creeps finish their exit)
            interval: Math.max(450, root.slideMs * root._slideScale + 50)
        }

        onActiveChanged: if (!active) root._clickCount = 0

        sourceComponent: PanelWindow {
            id: companionWindow

            readonly property bool hovered: mascotHover.hovered

            screen: root.companionScreen
            visible: true
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:mascotCompanion"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            mask: Region { item: mascotItem }

            // Random-but-stable placement along the chosen edge for this peek
            // When contextual mode is active, use a widget-aligned x fraction
            readonly property real edgeFraction: {
                if (root._contextualSource.length > 0) {
                    const map = ({ "battery": 0.85, "media": 0.30, "update": 0.92, "network": 0.80, "dnd": 0.78 })
                    return map[root._contextualSource] ?? (0.22 + Math.random() * 0.5)
                }
                // Mostly the comfortable middle band, but sometimes she shows
                // up way off in a corner like she owns the whole edge.
                return Math.random() < 0.25 ? 0.06 + Math.random() * 0.86
                                            : 0.22 + Math.random() * 0.5
            }

            Item {
                id: mascotItem

                readonly property bool fromTop: root.edge === "top"
                readonly property bool fromBottom: root.edge === "bottom"
                readonly property bool fromLeft: root.edge === "left"
                readonly property bool vertical: fromTop || fromBottom
                readonly property int size: root.spriteSize
                // How far she retreats off-screen when hidden
                readonly property int hideOffset: size + 24

                // Panel-sitter: the window respects layer-shell exclusive zones, so its
                // bounds already track bar/dock/taskbar in both families at runtime.
                // Panel-sitter just hugs the window edge; peek mode uses a small offset.
                readonly property bool panelSitterMode: root.placement === "panel-sitter"
                readonly property int _peekOffset: Math.round(size * root._peekDepth)
                readonly property int _topPeekOffset: Math.round(size * root._peekDepth * 0.75)

                // Starts false so she slides in from off-screen on creation
                property bool onStage: false
                readonly property bool peekedOut: root.showing && onStage

                Component.onCompleted: Qt.callLater(() => onStage = true)

                width: size
                height: size
                // Side peeks are anchored to the bottom of the screen so cutout
                // sprites never show a floating cut edge; top/bottom peeks pick
                // a random horizontal spot per appearance.
                // Panel-sitter: window bounds already track panels via exclusive zones,
                // so the sprite just hugs the window edge (or uses a peek offset).
                x: vertical ? companionWindow.width * companionWindow.edgeFraction
                   : fromLeft ? (peekedOut
                      ? (panelSitterMode ? 0 : -_peekOffset)
                      : -hideOffset)
                   : (peekedOut
                      ? (panelSitterMode ? companionWindow.width - width : companionWindow.width - width + _peekOffset)
                      : companionWindow.width + hideOffset)
                y: fromTop ? (peekedOut
                   ? (panelSitterMode ? 0 : -_topPeekOffset)
                   : -hideOffset)
                   : fromBottom ? (peekedOut
                      ? (panelSitterMode ? companionWindow.height - height : companionWindow.height - height + _peekOffset)
                      : companionWindow.height + hideOffset)
                   : (panelSitterMode
                      ? companionWindow.height - height
                      : companionWindow.height - height + _peekOffset)

                Behavior on x {
                    enabled: Appearance.animationsEnabled && !mascotItem.vertical
                    NumberAnimation { duration: Math.max(100, root.slideMs * root._slideScale); easing.type: root._bouncyIn ? Easing.OutBack : Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1] }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled && mascotItem.vertical
                    NumberAnimation { duration: Math.max(100, root.slideMs * root._slideScale); easing.type: root._bouncyIn ? Easing.OutBack : Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1] }
                }

                AnimatedImage {
                    id: companionSprite
                    anchors.fill: parent
                    source: Quickshell.shellPath(`assets/images/mascot/inir-mascot-${root.pose}.${root.animatedPoses.includes(root.pose) ? "gif" : "png"}`)
                    playing: root.showing
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    // High-quality filtering avoids the serrated edges nearest-
                    // neighbor scaling produces going from 640px source art down
                    // to the 150-280px sprite size (see MascotWidget.qml).
                    smooth: true
                    mipmap: true
                    antialiasing: true
                    // Only poses drawn hugging the left canvas edge flip on the
                    // right edge; everything else (badge text, asymmetric props)
                    // must render as drawn — mirroring reverses the iNiR badge.
                    mirror: root.edge === "right" && (root._manifest.mirrorOnRight ?? ["edge-peek"]).includes(root.pose)

                    // She isn't just a swapped photo: a slow breathing pulse runs
                    // under every pose, static or GIF, so she reads as alive even
                    // between picks. Transform-only (never touches width/height),
                    // scoped to the sprite so it never perturbs mascotItem's own
                    // hit-test geometry or the bubble's layout math.
                    transform: Scale {
                        id: breathScale
                        origin.x: companionSprite.width / 2
                        origin.y: companionSprite.height / 2
                        property real amount: 0
                        xScale: 1 + amount
                        yScale: 1 + amount
                    }
                    SequentialAnimation {
                        running: mascotItem.peekedOut && Appearance.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { target: breathScale; property: "amount"; from: 0; to: 0.018; duration: 2100; easing.type: Easing.InOutSine }
                        NumberAnimation { target: breathScale; property: "amount"; from: 0.018; to: 0; duration: 2100; easing.type: Easing.InOutSine }
                    }
                }

                HoverHandler {
                    id: mascotHover
                    onHoveredChanged: if (hovered) root._peekTouched = true
                }

                // Stare at her long enough and she notices
                Timer {
                    id: stareTimer
                    interval: 4000
                    running: mascotHover.hovered && root.showing && root.pose !== "shy-flustered"
                    onTriggered: {
                        const onStyle = root._stareReactions.filter(r => {
                            const s = root._artStyleOf(r.pose)
                            return s === "" || s === root._visitArtStyle
                        })
                        const styled = onStyle.length ? onStyle : root._stareReactions
                        const fresh = styled.filter(r => !root._recentLines.includes(r.line))
                        const src = fresh.length ? fresh : styled
                        const pick = src[Math.floor(Math.random() * src.length)]
                        root._remember(root._recentLines, pick.line, 12)
                        root._remember(root._recentPoses, pick.pose, 10)
                        root.pose = pick.pose
                        root.line = Translation.tr(pick.line)
                    }
                }

                TapHandler {
                    onTapped: {
                        root._peekTouched = true
                        root._clickCount++
                        clickResetTimer.restart()
                        if (root._clickCount >= 4) {
                            // Enough. She rage-quits.
                            root.pose = root._pickPose(root._filterByArtStyle(root._clickTier4Poses))
                            root.line = Translation.tr(root._pickFrom(root._clickTier4Lines))
                            offendedTimer.restart()
                        } else if (root._clickCount >= 2) {
                            // Fine, pats are accepted. Dignity optional.
                            root.pose = root._pickPose(root._filterByArtStyle(root._clickTier2Poses))
                            root.line = Translation.tr(root._pickFrom(root._clickTier2Lines))
                            hideTimer.restart()
                        } else {
                            // First poke: tolerated, barely
                            root.pose = root._pickPose(root._filterByArtStyle(root._clickTier1Poses))
                            root.line = Translation.tr(root._pickFrom(root._clickTier1Lines))
                            hideTimer.restart()
                        }
                    }
                }

                Timer { id: clickResetTimer; interval: 1500; onTriggered: root._clickCount = 0 }
                Timer { id: offendedTimer; interval: 900; onTriggered: root.hide() }
            }

            // Speech bubble — QML layer beside her, input-transparent
            Rectangle {
                id: bubble

                readonly property int pad: 10
                readonly property int gap: 4
                readonly property bool fullBody: root._fullBodyPoses.includes(root.pose)
                // Full-body art is letterboxed horizontally inside its square
                // stage. Anchor to the visible shoulder/head area, not the far
                // edge of that transparent box.
                readonly property real sideAnchor: fullBody ? 0.74 : 1.0
                readonly property real desiredX: mascotItem.vertical
                    ? mascotItem.x + mascotItem.width / 2 - width / 2
                    : mascotItem.fromLeft
                        ? mascotItem.x + mascotItem.width * sideAnchor + gap
                        : mascotItem.x + mascotItem.width * (1 - sideAnchor) - width - gap
                readonly property real desiredY: mascotItem.fromTop
                    ? mascotItem.y + mascotItem.height + gap
                    : mascotItem.fromBottom
                        ? mascotItem.y - height - gap
                        : mascotItem.y + mascotItem.height * 0.22 - height / 2

                visible: opacity > 0
                opacity: root.showing && root.line.length > 0 ? 1 : 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                implicitWidth: bubbleText.width + pad * 2
                implicitHeight: bubbleText.implicitHeight + pad * 2
                // Same style dispatch as StyledToolTipContent so the bubble
                // reads as a native shell tooltip in every global style
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

                x: Math.max(12, Math.min(desiredX, companionWindow.width - width - 12))
                y: Math.max(12, Math.min(desiredY, companionWindow.height - height - 12))

                // Small themed pointer keeps the copy visually attached to her
                // instead of reading as an unrelated tooltip.
                Rectangle {
                    z: -1
                    width: 10
                    height: 10
                    rotation: 45
                    color: bubble.color
                    border.width: bubble.border.width
                    border.color: bubble.border.color
                    x: mascotItem.vertical ? bubble.width / 2 - width / 2
                        : mascotItem.fromLeft ? -width / 2 : bubble.width - width / 2
                    y: mascotItem.fromTop ? -height / 2
                        : mascotItem.fromBottom ? bubble.height - height / 2
                        : bubble.height / 2 - height / 2
                }

                StyledText {
                    id: bubbleText
                    anchors.centerIn: parent
                    text: root.line
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
    }

    onShowingChanged: if (!showing) {
        teardownTimer.restart()
        _visitArtStyle = ""
        // A suppression cut (fullscreen/lock appeared mid-peek) is nobody
        // ignoring her — only a peek that ran its course counts.
        if (_peekTouched) _ignoredStreak = 0
        else if (!suppressed) _ignoredStreak = Math.min(_ignoredStreak + 1, 6)
    }
}
