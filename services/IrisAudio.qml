pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/**
 * The iRiS audio engine: one panel over the whole EasyEffects output chain.
 *
 * EasyEffects has no IPC verb to add or remove a module from a stream, so the chain
 * itself lives in a preset file and every parameter move is a plain set_property.
 * That split is why this service is thin and the daemon is not: module on/off is a
 * bypass, not a preset reload, so toggling a module never glitches the stream.
 *
 * Nothing is spawned until ensureRunning() is called. A singleton is constructed the
 * moment anything imports it, and it is imported by the settings page as well as the
 * panel, so starting a process from the constructor would leave an audio daemon
 * running for users who never open the panel.
 */
Singleton {
    id: root

    // ---------------------------------------------------------------- wiring

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/inir-audio.sock"
    readonly property string bridgeScript: Quickshell.shellPath("scripts/audio/inir-audio-bridge.py")

    // ---------------------------------------------------------------- state

    /** The bridge daemon is connected. Says nothing about EasyEffects itself. */
    property bool available: false
    /** EasyEffects answered and we hold a full snapshot. This is what the UI gates on. */
    property bool ready: false
    /** A bridge or engine problem the user should see, empty when there is none. */
    property string lastError: ""

    /** { preset, chain, modules, equalizer } as last reported by the daemon. */
    property var snapshot: ({})
    /** Band count the user picked, 10 / 15 / 32. Mirrors the engine after a reload. */
    property int bandCount: 10
    /** [{ frequency, gain, q }] in engine order. */
    property var bands: []
    /**
     * { <module>: FLAT param map } — exactly what the bridge's `status` sends,
     * e.g. bass_enhancer is { bypass, amount, floor, floor-active }. There is
     * no `params` sub-object, because there never was one on the wire.
     *
     * `active` is the one exception and it is DERIVED here: the engine only
     * knows `bypass`, but several readers ask for `active` because that is the
     * natural name for a switch. _withDerivedActive() stamps it as the exact
     * inverse of `bypass` whenever a snapshot is installed, and every optimistic
     * write updates the pair together, so the two can never disagree.
     */
    property var modules: ({})
    /** [{ name }] presets the engine knows about. */
    property var presets: []
    /** Name of the preset the engine last loaded. */
    property string presetName: ""
    /** Module ids in plugins_order, e.g. ["equalizer", "autogain"]. */
    property var chain: []

    /**
     * The order modules are installed in, i.e. the signal path order.
     *
     * bass_enhancer and exciter generate harmonics, so they run BEFORE the
     * equalizer and the user can shape the harmonics they add with the EQ
     * curve; crystalizer is a multiband transient enhancer and runs after it;
     * autogain normalises loudness and must run before the limiter; the
     * limiter is always last.
     *
     * Because every module the bridge installs comes in bypassed (see
     * setModuleActive), adopting this order costs nothing while everything is
     * off: it only decides signal order once the user opts a module in.
     */
    readonly property var chainOrder: [
        "bass_enhancer",
        "exciter",
        "equalizer",
        "crystalizer",
        "autogain",
        "limiter"
    ]

    /**
     * A chain rebuild is in flight. Installing a module rewrites the preset and
     * reloads the engine, which is a brief audio interruption, so the panel has
     * to be able to show that rather than pretend the switch was instant.
     *
     * Tracked separately from pendingCount on purpose: a band-slider drag also
     * keeps a request outstanding, and flagging that as a "rebuild" would make
     * the indicator flicker on every frame of a drag.
     */
    readonly property bool rebuilding: _rebuildCount > 0
    /** Requests sent to the bridge that have not been answered yet. */
    readonly property int pendingCount: _pendingCount
    property int _pendingCount: 0
    property int _rebuildCount: 0
    property var _pendingIds: ({})
    property var _rebuildIds: ({})

    /** Commands that make the engine reload a preset, i.e. the audible ones. */
    readonly property var _rebuildCommands: ["set_chain", "set_band_count",
                                            "apply_preset"]

    signal stateRefreshed()
    signal engineFailed(string message)

    // -------------------------------------------------------- request plumbing

    property int _nextId: 1

    // A slider drag emits a change per frame. Hold them for one frame window and let
    // the daemon flush them as a single batch, so a drag is a handful of writes
    // instead of one per frame.
    property var _bandQueue: ({})
    property bool _bandQueueDirty: false
    readonly property int coalesceMs: 25

    DankSocket {
        id: link
        path: root.socketPath
        // Intent, not state. This link wants to be up; whether it IS up is what
        // the connectionStateChanged handler below reports. It must not sit at
        // `false` here: a fresh Socket given only a path does not connect on
        // its own, so every socket DankSocket builds would be born idle.
        connected: true
        parser: SplitParser {
            onRead: line => root._onLine(line)
        }
    }

    // Taken in a Connections block, on purpose. Declared inline as
    // `onConnectionStateChanged:` on the DankSocket object it never runs at all,
    // which leaves `available` permanently false: the panel then sits on
    // "Starting the audio bridge…" forever with a live bridge and a bound
    // socket, retried correctly, and can never be told the link was up.
    //
    // A Connections block with an explicit function is also the documented way
    // to handle another object's signal, and it cannot collide with the inner
    // Socket's own signal of the same name — the hazard the inline form walked
    // into.
    Connections {
        target: link
        function onConnectionStateChanged(isConnected: bool): void {
            if (isConnected) {
                root.available = true
                root.lastError = ""
                root._reconcileFailures = 0
                root._keepTryingAttempts = 0
                keepTryingTimer.stop()
                root.refresh()
                return
            }
            root.available = false
            root.ready = false
            // Nothing will answer the requests we already sent.
            root._pendingIds = ({})
            root._pendingCount = 0
            root._rebuildIds = ({})
            root._rebuildCount = 0
            root._reconcileFailures++
            if (root._wanted) root._retry()
        }
    }

    property bool _wanted: false
    property bool _spawned: false
    property int _reconcileFailures: 0
    property int _keepTryingAttempts: 0


    // Process has no startDetached() in Quickshell 0.3.1; execDetached is the API for
    // a process that must outlive the shell that started it. The bridge is meant to
    // outlive us, so a failure to start it must not take the panel down with it.
    // `_spawned` is therefore only a fast path: a bridge that crashed must be
    // replaceable, so respawn after a few consecutive failures instead.
    function _ensureDaemon(): void {
        if (_spawned && _reconcileFailures < 3) return
        _spawned = false
        _startBridge()
    }

    function _startBridge(): void {
        try {
            Quickshell.execDetached(["python3", bridgeScript, "--socket", socketPath])
            _spawned = true
        } catch (error) {
            _spawned = false
            lastError = "could not start the audio bridge: " + String(error)
            engineFailed(lastError)
        }
    }

    // Self-sustaining reconnect. A failed connect is NOT guaranteed to emit
    // connectionStateChanged, so this timer asks for a connect on a backed-off
    // interval for as long as we want the bridge and don't have it: it cannot
    // depend on a failure being reported.
    Timer {
        id: keepTryingTimer
        interval: root._backoff
        repeat: true
        onTriggered: {
            if (!root._wanted || root.available) {
                keepTryingTimer.stop()
                return
            }
            // Drive the socket directly. Cycling the wrapper's `connected`
            // relies on onConnectedChanged to re-assert the socket, and that hop
            // does not happen: the guard passes, the property cycles, and a live
            // bridge with a bound socket is never touched again.
            link.reconnect()
            // A bridge that died once must be startable again. See _ensureDaemon.
            root._ensureDaemon()
            root._keepTryingAttempts = Math.min(root._keepTryingAttempts + 1, 6)
            keepTryingTimer.interval = Math.min(400 * Math.pow(2, root._keepTryingAttempts), 15000)
        }
    }

    Timer {
        id: coalesceTimer
        interval: root.coalesceMs
        repeat: false
        onTriggered: root._flushBands()
    }

    readonly property int _backoff: {
        const step = Math.min(_reconcileFailures, 6)
        return Math.min(400 * Math.pow(2, step), 15000)
    }

    // ------------------------------------------------------------------ calls

    /**
     * Connect to the bridge, starting it if it is not already up. Safe to call as
     * often as you like: while the daemon is believed up, no new spawn is tried.
     */
    function ensureRunning(): void {
        _wanted = true
        if (available) return
        _ensureDaemon()
        // The bridge is spawned detached, so its socket does not exist yet: the
        // first connect is expected to lose that race. Arm the tick so the panel
        // keeps asking instead of waiting on a signal that may never come.
        _keepTryingAttempts = 0
        keepTryingTimer.interval = _backoff
        keepTryingTimer.restart()
        // State the intent and then ask for a socket. `reconnect()` replaces the
        // Socket object rather than re-asserting it, because one that lost the
        // race against the bridge's own startup can never be revived.
        link.connected = true
        link.reconnect()
    }

    function release(): void {
        _wanted = false
        keepTryingTimer.stop()
        // Drop the intent too. Leaving it true means the next open assigns the
        // value it already has, which changes nothing and re-asserts nothing.
        link.connected = false
        // Nothing forces a respawn on the next open otherwise.
        _spawned = false
        // Nothing will answer the outstanding requests, so no reply will clear
        // these. Same reason onConnectionStateChanged drops _pendingIds; it is
        // left alone, so the bundle's own ids are cleared here instead.
        _profileIds = ({})
        if (activeProfile !== "") activeProfile = ""
    }

    function _retry(): void {
        // Deliberately does not set link.connected = false. That also switches off
        // DankSocket's own reconnect gate (`if (root.connected)`), and with two
        // mechanisms each waiting on the other to move, neither one ran again.
        _keepTryingAttempts = 0
        keepTryingTimer.interval = _backoff
        keepTryingTimer.restart()
    }

    // Deliberately NOT gated on `available`. `available` only ever became true from
    // the socket's connectionStateChanged, and that signal is emitted from inside
    // the Loader's rebuild and races the `target: socketLoader.item` binding, so
    // `available` can stay false indefinitely — and a gate on it would then refuse
    // every write, so the panel would never even ask whether the link was up.
    // `available` means "the bridge has answered us", set in _onLine from real
    // data.
    function _send(cmd, args): int {
        const id = _nextId++
        if (!link.send(Object.assign({ id: id, cmd: cmd }, args ?? {}))) return -1
        _pendingIds[id] = true
        _pendingCount++
        if (_rebuildCommands.indexOf(cmd) !== -1) {
            _rebuildIds[id] = true
            _rebuildCount++
        }
        return id
    }

    /** Retire one in-flight request. Called for every reply, success or error. */
    function _resolve(id): void {
        if (id === undefined || id === null) return
        if (!_pendingIds[id]) return
        if (_profileIds[id] !== undefined) {
            // The bundle's write is over either way, so the profile label must
            // not outlive it: a stale name would sit on screen looking active.
            if (activeProfile === _profileIds[id]) activeProfile = ""
            delete _profileIds[id]
        }
        delete _pendingIds[id]
        _pendingCount = Math.max(0, _pendingCount - 1)
        if (_rebuildIds[id]) {
            delete _rebuildIds[id]
            _rebuildCount = Math.max(0, _rebuildCount - 1)
        }
    }

    function _noteLinkAlive(): void {
        if (root.available) return
        root.available = true
        root.lastError = ""
        root._reconcileFailures = 0
        root._keepTryingAttempts = 0
        keepTryingTimer.stop()
    }

    function _onLine(line): void {
        const text = String(line ?? "").trim()
        if (text.length === 0) return
        let message
        try {
            message = JSON.parse(text)
        } catch (error) {
            console.warn("IrisAudio: unparseable line:", text)
            return
        }
        // A reply that parsed is the only honest proof the link works. Not the
        // socket's opinion of itself: the signal is emitted as the Loader builds
        // the new item and `target: socketLoader.item` is only re-evaluated
        // afterwards, so a Connections handler can miss every emit.
        _noteLinkAlive()
        // Retire the request on EVERY reply, including errors: a failed install
        // still ends the wait, and leaving it pending would pin `rebuilding`
        // on forever and hide the error the user needs to see.
        root._resolve(message?.id)
        // Only when the reply actually carries it: a non-bundle reply has no
        // `skipped` key, and clearing on every line would wipe a real result.
        if (Array.isArray(message?.skipped)) lastBundleSkipped = message.skipped
        // Same rule: only when the reply actually carries it, so an unrelated
        // reply cannot blank a state we have already read.
        if (message?.globalBypass !== undefined && message?.globalBypass !== null)
            globalBypass = String(message.globalBypass)
        if (message && message.ok === false) {
            lastError = String(message.error ?? "audio engine error")
            engineFailed(lastError)
            return
        }
        // The bridge's `snapshot` field is a STRING label, not the state object, so
        // it must never be what gates the parse: it is truthy and would hand
        // _applySnapshot a string. The state (equalizer/modules/chain/preset)
        // sits at the top level of the reply.
        if (message.equalizer || message.modules) _applySnapshot(message)
        // Replies that carry a preset list without a full snapshot (list_presets)
        // would otherwise be parsed and dropped, leaving the panel showing an
        // empty list while the engine does have presets.
        if (Array.isArray(message.presets)) presets = message.presets
    }

    function _applySnapshot(next): void {
        if (!next) return
        snapshot = next
        presetName = String(next.preset ?? "")
        chain = Array.isArray(next.chain) ? next.chain : []
        // Only overwrite when the payload actually carries presets: a status reply has
        // no `presets` key, so the unconditional form wiped a list the user can see.
        if (Array.isArray(next.presets)) presets = next.presets
        const eq = next.equalizer ?? {}
        bandCount = Number(eq.numBands ?? bandCount)
        const list = Array.isArray(eq.bands) ? eq.bands : []
        if (list.length > 0) {
            // `type` and `mode` are per-band enum state the panel can edit, so they must
            // survive this map: dropped here, a setter would paint a value that
            // the very next status reply reverted.
            bands = list.map(band => ({
                frequency: Number(band.frequency ?? 0),
                gain: Number(band.gain ?? 0),
                q: Number(band.q ?? 1),
                type: band.type ?? "",
                mode: band.mode ?? ""
            }))
        }
        // Everything on the equalizer that is not a band or the band count. Populated from
        // the snapshot as well as from local writes, otherwise these go stale the moment a
        // preset is loaded or anything else touches the chain. The bridge speaks camelCase
        // but preset-style kebab-case is accepted too, so a naming change cannot silently
        // blank the readouts.
        const scalar = Object.assign({}, eq)
        delete scalar.bands
        delete scalar.numBands
        delete scalar["num-bands"]
        const params = {}
        for (const key in scalar) {
            const kebab = key.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase()
            params[key] = scalar[key]
            params[kebab] = scalar[key]
        }
        _equalizerParams = params
        modules = root._withDerivedActive(next.modules ?? {})
        // The engine answering at all is what "ready" means; an empty module map is a
        // legitimate state for a chain that holds only the equalizer.
        ready = true
        lastError = ""
        stateRefreshed()
    }

    /**
     * Stamp the derived `active` mirror onto every entry that reports a
     * boolean `bypass`.
     *
     * The engine has no `active` field, only `bypass`, but the module cards
     * (IrisEqModuleCard, and IrisEqCrystalizer, which this service does not
     * own) read `active`. Installing it in the same pass that installs the
     * snapshot is what keeps those switches honest: before, the snapshot
     * replaced `modules` wholesale, `active` vanished, and a card that had
     * been switched on fell back to `?? false` and drew itself OFF while
     * EasyEffects was still processing audio.
     *
     * Derived, never authored: `bypass` stays the single source of truth and
     * this cannot drift from it, because nothing writes one without the other.
     */
    function _withDerivedActive(map: var): var {
        const out = ({})
        for (const id in map) {
            const entry = Object.assign({}, map[id])
            if (typeof entry.bypass === "boolean")
                entry.active = !entry.bypass
            out[id] = entry
        }
        return out
    }

    /**
     * Whether a module is running, read the same way IrisEqSpec.moduleActive
     * reads it.
     *
     * Duplicated on purpose: that helper lives in qs.modules.iris.equalizer,
     * and a service must not import a UI module (it would invert the layering
     * that module already depends on). The rule is two lines and the comment
     * above it is the contract; if one changes, change both.
     */
    function _moduleActive(id: string): bool {
        const entry = (modules ?? {})[id] ?? null
        if (!entry) return false
        if (typeof entry.active === "boolean") return entry.active
        if (typeof entry.bypass === "boolean") return !entry.bypass
        return false
    }

    function refresh(): void {
        _send("status", {})
        // Asked on every refresh because nothing else carries it: `status` has
        // no bypass field, and the state is set from outside too (EasyEffects'
        // own GUI), so reading it only once would go stale on its own.
        root.requestGlobalBypass()
    }

    // ------------------------------------------------------------------ bands

    function setBandGain(index, gain): void {
        _editBand(index, { gain: Number(gain) })
    }

    function setBandFrequency(index, hz): void {
        _editBand(index, { frequency: Number(hz) })
    }

    function setBandQ(index, q): void {
        _editBand(index, { q: Number(q) })
    }

    /** Per-band filter TYPE. `typeName` is an EasyEffects Equalizer label, e.g. "Bell". */
    function setBandType(index: int, typeName: string): void {
        _setBandEnum(index, "type", typeName)
    }

    /** Per-band filter MODE, e.g. "RLC (BT)". */
    function setBandMode(index: int, modeName: string): void {
        _setBandEnum(index, "mode", modeName)
    }

    /**
     * Discrete enum writes, deliberately NOT routed through _editBand's
     * coalescing queue.
     *
     * _editBand merges one patch per band and flushes a `set_bands` batch,
     * which is right for the three float slider fields but wrong for an enum:
     * a queued label would ride along with in-flight slider traffic, and the
     * batch readback verifies labels by exact equality against a float
     * tolerance that means nothing here. Enums are low-frequency and discrete,
     * so they get their own single-band write.
     *
     * `sync` asks the bridge to flush and read back before replying, so an
     * unknown label or a refused value surfaces as an error reply (which
     * _onLine turns into lastError) instead of a silent no-op - EasyEffects
     * does not clamp enums and set_property returns nothing at all.
     */
    function _setBandEnum(index, field, label): void {
        const i = Number(index)
        const name = String(label)
        const current = Array.from(bands)
        if (i < 0 || i >= current.length) return
        if (name.length === 0) return
        const next = Object.assign({}, current[i])
        next[field] = name
        current[i] = next
        bands = current
        const args = { index: i, sync: true }
        args[field] = name
        _send("set_band", args)
    }

    /** Per-crystalizer-band mute. Addresses the dotted public path band<N>.mute. */
    function setCrystalizerBandMute(index: int, on: bool): void {
        _setCrystalizerBand(index, "mute", Boolean(on))
    }

    /** Per-crystalizer-band bypass. Note EasyEffects defaults a crystalizer
     *  band to bypass=true, so "off" is the non-obvious state here. */
    function setCrystalizerBandBypass(index: int, on: bool): void {
        _setCrystalizerBand(index, "bypass", Boolean(on))
    }

    /**
     * Crystalizer bands are NOT scalars: the preset stores 13 nested objects,
     * so the public key is the dotted path "band<N>.<field>" and the bridge
     * resolves the flat camelCase IPC name itself. 13 bands is the count the
     * bridge's schema declares; an index outside it is refused by the bridge,
     * and dropped here so no doomed request is sent.
     *
     * Painted flat into `modules` because that is the shape the snapshot
     * carries, so the optimistic value survives the next status reply.
     */
    function _setCrystalizerBand(index, field, want): void {
        const i = Number(index)
        if (!Number.isInteger(i) || i < 0 || i > 12) return
        const key = "band" + i + "." + field
        const entry = Object.assign({}, modules.crystalizer ?? {})
        entry[key] = want
        const next = Object.assign({}, modules)
        next.crystalizer = entry
        modules = next
        _send("set_param", { module: "crystalizer", key: key, value: want, sync: true })
    }

    /** Paint the band locally so the slider tracks the finger, then let the daemon batch it. */
    function _editBand(index, patch): void {
        const i = Number(index)
        const current = Array.from(bands)
        if (i < 0 || i >= current.length) return
        const next = Object.assign({}, current[i], patch)
        current[i] = next
        bands = current
        const queued = Object.assign({}, _bandQueue[i] ?? {}, patch)
        queued.index = i
        _bandQueue[i] = queued
        _bandQueueDirty = true
        if (!coalesceTimer.running) coalesceTimer.restart()
    }

    function _flushBands(): void {
        if (!_bandQueueDirty) return
        _bandQueueDirty = false
        const queue = _bandQueue
        _bandQueue = ({})
        const list = Object.keys(queue).map(key => queue[key])
        if (list.length === 0) return
        _send("set_bands", { bands: list })
    }

    /**
     * Band count is structural: the band list lives in the preset file, so this is the
     * one change that rewrites a preset and reloads the engine. It costs a short
     * stream reset, which is why it is not a slider.
     */
    function setBandCount(count): void {
        const wanted = Number(count)
        if (![10, 15, 32].includes(wanted)) return
        if (wanted === bandCount) return
        _send("set_band_count", { count: wanted })
        refresh()
    }

    // ---------------------------------------------------------------- modules

    /**
     * Turn a module on or off.
     *
     * A module that is already in the chain is just a bypass, so this is a
     * plain set_module and the stream never glitches.
     *
     * A module that is NOT in the chain has to be installed first, and that is
     * the only way to change the chain: EasyEffects has no IPC verb for it, so
     * the bridge rewrites the preset and reloads the engine. The install carries
     * `activate: [module]` so this one comes up live while everything else being
     * installed stays bypassed, which is why no follow-up set_module is sent
     * here: the install already set the right bypass. `bandCount` is passed
     * through so the user's band count survives the rebuild.
     */
    function setModuleActive(module, active): void {
        const id = String(module)
        const want = Boolean(active)
        // Optimistic local update, kept for both paths: the switch must move
        // under the finger immediately, not after a round trip.
        const entry = Object.assign({}, modules[id] ?? {})
        // BOTH names, ONE value, updated together. `bypass` is the field the
        // snapshot carries, so writing it is what makes the optimistic update
        // and the next status reply agree; writing only `active` left `bypass`
        // stale, so the snapshot arriving from the very commit the user had
        // just made replaced the entry with the pre-toggle bypass and the
        // switch snapped back OFF while EasyEffects was already ON.
        entry.bypass = !want
        entry.active = want
        const next = Object.assign({}, modules)
        next[id] = entry
        modules = next

        if (chain.indexOf(id) === -1) {
            if (!want) return
            _send("set_chain", {
                modules: chainOrder,
                numBands: bandCount,
                activate: [id]
            })
            refresh()
            return
        }
        _send("set_module", { module: id, active: want })
    }

    function toggleModule(module): void {
        const id = String(module)
        // Read the canonical way. `active` is DERIVED, so it can be absent on an
        // entry a snapshot touched and `?? false` would ask for "off" on a
        // module that was already on.
        setModuleActive(id, !root._moduleActive(id))
    }

    /**
     * Honour Settings › Equalizer on panel open: the global on/off plus the
     * default band count. Only sends what disagrees with the engine, so a
     * reopen never rebuilds twice. An unset value (undefined) means the user
     * has not chosen in Settings, and the engine keeps whatever it holds.
     */
    function applyPreferences(enabled, bands): void {
        if (enabled !== undefined && enabled !== null) {
            const wantBypass = !Boolean(enabled)
            if (equalizerBypass !== wantBypass) setEqualizerParam("bypass", wantBypass)
        }
        const count = Number(bands)
        if ([10, 15, 32].includes(count) && count !== bandCount) setBandCount(count)
    }

    /**
     * Write one module parameter.
     *
     * The optimistic value is painted FLAT, onto the entry itself, because that
     * is the shape the snapshot carries. It used to go into a nested `params`
     * sub-object that the engine never sends and that IrisEqSpec.paramOf only
     * reads as a fallback, so the optimistic write was invisible: the card's
     * readout kept returning the engine's old number until a preset load
     * happened to change it - "only when I close and reopen the panel". Worse,
     * the slider's own `value` binding reads this map, so every drag step
     * snapped the handle back to the stale number: that is the jitter.
     *
     * Same idiom, and the same reason, as _setCrystalizerBand above.
     */
    function setParam(module, key, value): void {
        const id = String(module)
        const field = String(key)
        const entry = Object.assign({}, modules[id] ?? {})
        entry[field] = value
        const next = Object.assign({}, modules)
        next[id] = entry
        modules = next
        _send("set_param", { module: id, key: field, value: value })
    }

    function setEqualizerParam(key, value): void {
        const field = String(key)
        const next = Object.assign({}, _equalizerParams)
        next[field] = value
        _equalizerParams = next

        // The equalizer's bypass is the one module parameter that has two homes:
        // the panel's own switch lands here, while the counter, the module card
        // and the crystalizer all read modules[id].active. So it is written into
        // BOTH maps from one value, exactly as setModuleActive does it: bypass is
        // the field a snapshot carries, and active is derived from it. Not
        // audio-affecting: the value sent below is unchanged, this only stops
        // the panel keeping two copies of one fact and disagreeing with itself.
        if (field === "bypass") {
            const entry = Object.assign({}, modules.equalizer ?? {})
            entry.bypass = Boolean(value)
            entry.active = !entry.bypass
            const merged = Object.assign({}, modules)
            merged.equalizer = entry
            modules = merged
        }

        _send("set_param", { module: "equalizer", key: field, value: value })
    }

    property var _equalizerParams: ({})

    // Public readouts for the chain's input/output trim. The panel binds to these instead
    // of echoing its own writes, so a clamp or a preset load re-syncs the number.
    readonly property real equalizerInputGain: Number(_equalizerParams.inputGain ?? _equalizerParams["input-gain"] ?? 0)
    readonly property real equalizerOutputGain: Number(_equalizerParams.outputGain ?? _equalizerParams["output-gain"] ?? 0)
    readonly property real equalizerBalance: Number(_equalizerParams.balance ?? 0)

    // The equalizer's own on/off. The bridge decodes reads to typed JSON, so this
    // arrives as a real bool; the string branch is kept because a future reply
    // shape would otherwise bind "false" -- truthy -- and stick the switch on.
    // Defaults to true, which is both the bridge's default and the honest state
    // before anything has answered: an equalizer nobody has enabled does nothing.
    readonly property bool equalizerBypass: {
        const v = _equalizerParams.bypass ?? _equalizerParams["bypass"] ?? true
        if (typeof v === "string")
            return ["1", "true", "on", "yes"].indexOf(v.trim().toLowerCase()) !== -1
        return v !== false
    }

    // ---------------------------------------------------------------- profiles

    /**
     * The profile whose bundle is currently in flight, "" when none is.
     *
     * A profile is a coherent set (loudness target + curve + module states) and
     * the panel needs to name it while the write is outstanding, so the indicator
     * cannot be derived from `presetName`: a bundle does NOT load a preset, and
     * overwriting presetName would make the UI claim the engine is on a preset it
     * never loaded. Cleared when the reply for that request arrives, and in
     * release(). A socket drop mid-flight leaves it set: the connection handler
     * that drops the other in-flight bookkeeping is deliberately untouched, and
     * a stale name for one lost reply is better than editing that handler.
     */
    property string activeProfile: ""
    // What the last bundle could NOT do, straight from the bridge's readback:
    // [{module, reason}] with reasons not_in_chain, unknown_module,
    // write_not_confirmed, band_write_not_confirmed. A profile naming a module
    // that is not installed is skipped rather than installed, so without this
    // the panel would show a profile as fully applied when part of it silently
    // did nothing. Cleared when the next bundle is sent.
    property var lastBundleSkipped: []

    // Raw global bypass as the ENGINE reports it, kept as a string on purpose.
    // EasyEffects' write path accepts only 0 and 1 (its regex is
    // ^global_bypass:([01])$), yet this machine reports "2" — a third state its
    // own UI can set and its IPC cannot. I do not know what 2 means, and a
    // switch that renders an unknown engine state as plain "on" is a control
    // that lies. So the raw value is surfaced verbatim and the UI gives it its
    // own state instead of guessing. "" means not asked yet.
    property string globalBypass: ""

    // Bypass the whole chain at once, the way EasyEffects' own global bypass
    // does: no parameter writes, no preset reload, and every setting survives
    // for when it is switched back off.
    function setGlobalBypass(on: bool): void {
        _send("global_bypass", { value: on === true })
        // Ask for the state back rather than assuming the write landed. Without
        // this the switch renders the old value until something else refreshes,
        // so a press looks like it did nothing and the next one reverses it.
        refresh()
    }

    // Reading it is a request with no `value`; the command replies with the
    // current state and writes nothing.
    function requestGlobalBypass(): void {
        _send("global_bypass", {})
    }
    /** Bundle request id -> the profile name it was sent for. */
    property var _profileIds: ({})

    /**
     * Apply a coherent bundle of writes in ONE bridge command:
     * `spec` is `{ target, bands, modules }`, every section optional.
     *
     * `apply_bundle` deliberately does NOT flip `rebuilding`. That indicator
     * means "the engine is reloading a preset", which costs a brief audio
     * interruption, and it is reserved for exactly those commands
     * (_rebuildCommands: set_chain, set_band_count, apply_preset). A bundle is
     * only a set_property batch - no preset load, no reinstall, no interruption -
     * so marking it rebuilding would show a scary "rebuilding the engine" state
     * for a write that lands in a single round trip. It is still visible through
     * `pendingCount`, which is what a spinner belongs to.
     *
     * `profileName` is purely local: the bridge has no concept of a profile, so
     * the name rides on our side to label the request in flight.
     */
    function applyBundle(spec, profileName = ""): int {
        const req = spec ?? {}
        const args = {}
        if (req.target !== undefined && req.target !== null)
            args.target = Number(req.target)
        if (req.bands !== undefined && req.bands !== null) {
            args.bands = req.bands.map(b => (typeof b === "object" && b !== null)
                ? Object.assign({}, b) : Number(b))
        }
        if (req.modules !== undefined && req.modules !== null) {
            // `[id, active]` pairs, active coerced to a real bool: the bridge
            // refuses anything else, because the string "false" is truthy and
            // would install the opposite state.
            args.modules = req.modules.map(pair => [
                String(pair[0]), pair[1] === true
            ])
        }
        const name = String(profileName ?? "")
        const id = _send("apply_bundle", args)
        if (id === -1) return id
        _profileIds[id] = name
        lastBundleSkipped = []
        if (name.length > 0) activeProfile = name
        // Ask for the new state back. Applying a bundle queues writes whose
        // effect lands in the engine, but `bands` and `modules` only change
        // when a status snapshot arrives, so without this the profile that was
        // just applied would not read as active until the panel was reopened
        // (whose onOpenChanged already refreshes). Same idiom as applyPreset.
        refresh()
        return id
    }

    // ---------------------------------------------------------------- presets

    function applyPreset(name): void {
        _send("apply_preset", { name: String(name) })
        refresh()
    }

    function savePreset(name): void {
        const id = String(name).trim()
        if (id.length === 0) return
        _send("save_preset", { name: id })
        refresh()
    }

    function deletePreset(name): void {
        const gone = String(name)
        // Where it sat in the list we know about. After the delete the user must
        // land on something, and "the next one along" is only computable from
        // the ordering as it was BEFORE the reply lands.
        const at = presets.findIndex(p => String(p) === gone)
        const rest = presets.filter(p => String(p) !== gone)
        _send("delete_preset", { name: gone })
        // Ask for the thing that changed. `refresh` sends status, which carries
        // no preset list, so deleting a chip needs list_presets as well or the
        // chips keep rendering it. Same readback rule as the save path above.
        listPresets()
        refresh()
        // Only adopt a replacement when the preset in use is the one that went
        // away. Deleting some other chip must not move the engine, and
        // `presetName` is what the chips match against to draw the current one.
        if (presetName !== gone)
            return
        if (rest.length === 0) {
            // Nothing left to fall back on. Clearing the selection is better
            // than leaving the panel claiming the engine is on a file that no
            // longer exists; nothing is loaded, so the audio is untouched.
            presetName = ""
            return
        }
        // Default if it is there - that is what the engine falls back to on a
        // restart - otherwise the neighbour that took the deleted chip's
        // place, clamped to the end of the list.
        let pick = rest.find(p => String(p) === "Default")
        if (pick === undefined)
            pick = rest[Math.min(at < 0 ? 0 : at, rest.length - 1)]
        // adopt, don't guess: applyPreset loads it and the status reply it
        // triggers is what sets presetName back, so this is confirmed state.
        applyPreset(pick)
    }

    function listPresets(): void {
        _send("list_presets", {})
    }

    // `save_preset` sends no state payload at all, only { name }: the bridge
    // assembles the file from the live engine itself. Anything that needs the
    // current state reads `modules` / `bands` / `_equalizerParams`, which are
    // the shapes the engine actually sends.
}