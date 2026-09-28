pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var points: []
    property real normalizationCeiling: 100
    property bool active: false
    property int smoothing: 2
    property string frequencyProfile: "flat"
    property real accentStrength: 0.7
    property bool mirroredStereo: true
    property real motionSpeed: 1.0
    property real idleMotion: 0.16
    property real attackScale: 1.0
    property real releaseScale: 1.0
    property bool animate: true

    readonly property real energy: root._energy
    readonly property real deformation: Math.max(
        root._bandsA.x, root._bandsA.y, root._bandsA.z, root._bandsA.w,
        root._bandsB.x, root._bandsB.y)

    // Kept across passes: this runs at the display rate and at cava's, where fresh arrays are only garbage.
    readonly property var _work: ({ weighted: [], smoothed: [], raw: new Float64Array(12),
        targets: new Float64Array(12), bands: new Float64Array(12), peaks: new Float64Array(12) })
    property vector4d _bandsA: Qt.vector4d(0, 0, 0, 0)
    property vector4d _bandsB: Qt.vector4d(0, 0, 0, 0)
    property vector4d _bandsC: Qt.vector4d(0, 0, 0, 0)
    property vector4d _peakA: Qt.vector4d(0, 0, 0, 0)
    property vector4d _peakB: Qt.vector4d(0, 0, 0, 0)
    property vector4d _peakC: Qt.vector4d(0, 0, 0, 0)
    property real _targetEnergy: 0
    property real _energy: 0
    property real _previousEnergy: 0
    property real _onset: 0
    property real _pulse: 0
    property real _phase: 0
    property real _spin: 0
    property real _effectiveMotionSpeed: 1.0
    property real _effectiveIdleMotion: 0.16
    property bool _motionInitialized: false

    function _profileWeight(position: real): real {
        const x = Math.max(0, Math.min(1, position))
        if (root.frequencyProfile === "bass")
            return 0.44 + 1.86 * Math.exp(-4.2 * x)
        if (root.frequencyProfile === "warm")
            return 1.82 - 1.08 * x
        if (root.frequencyProfile === "vocal") {
            const distance = (x - 0.46) / 0.17
            return 0.48 + 1.72 * Math.exp(-distance * distance)
        }
        if (root.frequencyProfile === "treble")
            return 0.44 + 1.86 * Math.pow(x, 1.75)
        if (root.frequencyProfile === "smile")
            return 0.52 + 1.56 * Math.pow(Math.abs(x - 0.5) * 2, 1.45)
        return 1
    }

    function _processedPoints(): var {
        const source = root.points ?? []
        if (source.length === 0)
            return []

        const weighted = root._work.weighted
        weighted.length = source.length
        const profileStrength = Math.max(0, Math.min(1, root.accentStrength))
        for (let i = 0; i < source.length; ++i) {
            const rawPosition = source.length > 1 ? i / (source.length - 1) : 0.5
            const frequencyPosition = root.mirroredStereo
                ? Math.abs(rawPosition * 2 - 1) : rawPosition
            const profileWeight = root._profileWeight(frequencyPosition)
            weighted[i] = (Number(source[i]) || 0)
                * (1 + (profileWeight - 1) * profileStrength)
        }

        const radius = Math.max(0, Math.round(root.smoothing))
        if (radius === 0 || weighted.length < 3)
            return weighted

        const smoothed = root._work.smoothed
        smoothed.length = weighted.length
        let start = 0
        let end = Math.min(weighted.length - 1, radius)
        let total = 0
        for (let i = start; i <= end; ++i)
            total += weighted[i]
        for (let i = 0; i < weighted.length; ++i) {
            const nextStart = Math.max(0, i - radius)
            const nextEnd = Math.min(weighted.length - 1, i + radius)
            while (start < nextStart)
                total -= weighted[start++]
            while (end < nextEnd)
                total += weighted[++end]
            smoothed[i] = total / Math.max(1, end - start + 1)
        }
        return smoothed
    }

    function _bandLevel(values: var, fromRatio: real, toRatio: real): real {
        if (values.length === 0)
            return 0
        const from = Math.max(0, Math.min(values.length - 1,
            Math.floor(values.length * fromRatio)))
        const to = Math.max(from + 1, Math.min(values.length,
            Math.ceil(values.length * toRatio)))
        const ceiling = Math.max(1, root.normalizationCeiling)
        let total = 0
        let peak = 0
        for (let i = from; i < to; ++i) {
            const level = Math.max(0, Math.min(1,
                Number(values[i] ?? 0) / ceiling))
            total += level
            peak = Math.max(peak, level)
        }
        const average = total / Math.max(1, to - from)
        return Math.pow(Math.min(1, average * 0.66 + peak * 0.54), 0.68)
    }

    function _sectorLevel(values: var, sector: int): real {
        return root._bandLevel(values, sector / 12, (sector + 1) / 12)
    }

    function _updateTargets(): void {
        root._targetsStale = false
        const values = root._processedPoints()
        const rawLevels = root._work.raw
        let weightedEnergy = 0
        let minimum = 1
        let maximum = 0
        for (let i = 0; i < 12; ++i) {
            rawLevels[i] = root._sectorLevel(values, i)
            minimum = Math.min(minimum, rawLevels[i])
            maximum = Math.max(maximum, rawLevels[i])
            weightedEnergy += rawLevels[i] * (1.35 - (i / 11) * 0.55)
        }
        const spread = Math.max(0.10, maximum - minimum)
        const activity = Math.min(1, Math.pow(maximum, 0.72) * 1.16)
        const levels = root._work.targets
        for (let i = 0; i < 12; ++i) {
            const contrast = Math.max(0, Math.min(1, (rawLevels[i] - minimum) / spread))
            levels[i] = Math.min(1, rawLevels[i] * 0.34 + contrast * activity * 0.76)
        }
        root._targetEnergy = Math.min(1, weightedEnergy / 9.6)
    }

    // A hidden or held field (a closed card, the overlay behind an organic aura) still hears every cava frame:
    // it catches up once it moves again instead of working for nothing.
    property bool _targetsStale: true
    function _refreshTargets(): void {
        if (root._moving) root._updateTargets()
        else root._targetsStale = true
    }
    onPointsChanged: root._refreshTargets()
    onNormalizationCeilingChanged: root._refreshTargets()
    on_MovingChanged: if (root._moving && root._targetsStale) root._updateTargets()

    // Silent, the field only drifts: the shared 42 ms idle clock keeps it smooth without holding the window's
    // render loop at the display rate the way a running FrameAnimation does.
    readonly property bool _quiet: root._targetEnergy < 0.004 && root._energy < 0.01
        && root._pulse < 0.01 && root._onset < 0.01
    readonly property bool _moving: root.visible && root.active && root.animate

    FrameAnimation {
        running: root._moving && !root._quiet
        onTriggered: root._step(frameTime)
    }
    readonly property bool _drifting: root._moving && root._quiet
    property bool _onClock: false
    function _syncClock(want: bool): void {
        if (want === root._onClock) return
        OrganicIdleClock.users += want ? 1 : -1
        root._onClock = want
    }
    on_DriftingChanged: root._syncClock(root._drifting)
    Component.onCompleted: root._syncClock(root._drifting)
    Component.onDestruction: root._syncClock(false)
    Connections {
        target: root._drifting ? OrganicIdleClock : null
        function onTick(dt: real): void { root._step(dt) }
    }

    function _follow(current: real, target: real, attack: real, release: real): real {
        return current + (target - current) * (target > current ? attack : release)
    }

    function _step(frameTime: real): void {
        const dt = Math.min(frameTime, 0.05)
        const smoothingFactor = Math.max(0, Math.min(8, root.smoothing))
        const attackScale = Math.max(0.2, Math.min(2.5, root.attackScale))
        const releaseScale = Math.max(0.2, Math.min(2.5, root.releaseScale))
        const attackRate = 24 * attackScale / (1 + smoothingFactor * 0.22)
        const releaseRate = 8 * releaseScale / (1 + smoothingFactor * 0.20)
        const peakReleaseRate = 2.1 * releaseScale / (1 + smoothingFactor * 0.14)
        const energyAttackRate = 12 * attackScale / (1 + smoothingFactor * 0.18)
        const energyReleaseRate = 3.2 * releaseScale / (1 + smoothingFactor * 0.16)
        // One exponential per rate per frame, not one per band.
        const step = rate => 1 - Math.exp(-dt * rate)
        const kAttack = step(attackRate)
        const kRelease = step(releaseRate)
        const kPeakRelease = step(peakReleaseRate)
        const follow = root._follow
        const w = root._work
        const bands = w.bands, peaks = w.peaks, targets = w.targets
        for (let i = 0; i < 12; ++i) {
            bands[i] = follow(bands[i], targets[i], kAttack, kRelease)
            peaks[i] = follow(peaks[i], bands[i], kAttack, kPeakRelease)
        }
        root._bandsA = Qt.vector4d(bands[0], bands[1], bands[2], bands[3])
        root._bandsB = Qt.vector4d(bands[4], bands[5], bands[6], bands[7])
        root._bandsC = Qt.vector4d(bands[8], bands[9], bands[10], bands[11])
        root._peakA = Qt.vector4d(peaks[0], peaks[1], peaks[2], peaks[3])
        root._peakB = Qt.vector4d(peaks[4], peaks[5], peaks[6], peaks[7])
        root._peakC = Qt.vector4d(peaks[8], peaks[9], peaks[10], peaks[11])
        root._energy = follow(root._energy, root._targetEnergy,
            step(energyAttackRate), step(energyReleaseRate))
        const rise = Math.max(0, root._energy - root._previousEnergy)
        root._onset = follow(root._onset, Math.min(1, rise * 7.5), step(28), step(4.8))
        // Pulse follows both sustained low-frequency energy and transients.
        // It is deliberately quicker than the contour envelope so Organic
        // feels musical instead of merely wobbling around the cover art.
        const bassPulse = Math.max(root._bandsA.x, root._bandsA.y)
        const pulseTarget = Math.min(1, bassPulse * 0.72 + root._energy * 0.42 + root._onset * 0.88)
        root._pulse = follow(root._pulse, pulseTarget, step(18), step(5.2))
        root._previousEnergy = root._energy
        const targetSpeed = Math.max(0, Math.min(2.5, root.motionSpeed))
        const targetIdle = Math.max(0, Math.min(1, root.idleMotion))
        if (!root._motionInitialized) {
            root._effectiveMotionSpeed = targetSpeed
            root._effectiveIdleMotion = targetIdle
            root._motionInitialized = true
        } else {
            root._effectiveMotionSpeed = follow(root._effectiveMotionSpeed,
                targetSpeed, step(7.5), step(7.5))
            root._effectiveIdleMotion = follow(root._effectiveIdleMotion,
                targetIdle, step(6.0), step(6.0))
        }
        const speed = root._effectiveMotionSpeed
        const idle = root._effectiveIdleMotion
        root._phase = (root._phase + dt * speed
            * (0.055 + idle * 0.035 + root._energy * 0.075 + root._onset * 0.12)) % 1
        root._spin = (root._spin + dt * speed * (0.020 + idle * 0.025 + root._energy * 0.018)) % 6.28318530718
    }

}
