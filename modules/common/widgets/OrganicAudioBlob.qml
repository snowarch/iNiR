pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var points: []
    property real normalizationCeiling: 100
    property bool active: false
    property color primaryColor: "white"
    property color secondaryColor: primaryColor
    property color tertiaryColor: secondaryColor
    property int smoothing: 2
    property string frequencyProfile: "flat"
    property real accentStrength: 0.7
    property bool mirroredStereo: true
    property real sensitivity: 1.0
    property real amplitude: 0.9
    property real pulseStrength: 0.72
    // Spatially focus spectrum bands into narrower contour regions. Zero keeps
    // the legacy continuous field; one produces the strongest separation.
    property real compression: 0.0
    property real motionSpeed: 1.0
    property real idleMotion: 0.16
    property real glowStrength: 0.45
    // Extra render room prevents high-energy contours/halo from flattening
    // against the component bounds. presentationScale sizes the organic body
    // independently from the host rectangle; overscan only grows the texture.
    property real overscan: 1.34
    property real presentationScale: 1.0
    property real baseRadius: 0.510
    property bool stretchToHost: false
    property real hollowAmount: 1.0
    // presentationMode only changes the coordinate map. The Organic contour,
    // spectrum response, pulse, palette, ring body and halo stay shared.
    // 0 = radial Visualizer, 2 = rounded-card perimeter for Media Controls.
    property real presentationMode: 0.0
    property real edgeBaseRadius: 0.39
    property vector2d edgeCardHalf: Qt.vector2d(0.72, 0.58)
    property vector2d edgeReachHalf: edgeCardHalf
    property real edgeCornerRadius: 0.12
    property vector4d edgeReachScales: Qt.vector4d(1, 1, 1, 1)
    property vector4d edgeDirections: Qt.vector4d(1, 1, 1, 1)
    property real reveal: 1.0
    readonly property real energy: root._energy
    readonly property real deformation: Math.max(
        root._bandsA.x, root._bandsA.y, root._bandsA.z, root._bandsA.w,
        root._bandsB.x, root._bandsB.y)

    property vector4d _targetA: Qt.vector4d(0, 0, 0, 0)
    property vector4d _targetB: Qt.vector4d(0, 0, 0, 0)
    property vector4d _targetC: Qt.vector4d(0, 0, 0, 0)
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

        const weighted = new Array(source.length)
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

        const smoothed = new Array(weighted.length)
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
        const values = root._processedPoints()
        const rawLevels = new Array(12)
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
        const levels = new Array(12)
        for (let i = 0; i < 12; ++i) {
            const contrast = Math.max(0, Math.min(1, (rawLevels[i] - minimum) / spread))
            levels[i] = Math.min(1, rawLevels[i] * 0.34 + contrast * activity * 0.76)
        }
        root._targetA = Qt.vector4d(levels[0], levels[1], levels[2], levels[3])
        root._targetB = Qt.vector4d(levels[4], levels[5], levels[6], levels[7])
        root._targetC = Qt.vector4d(levels[8], levels[9], levels[10], levels[11])
        root._targetEnergy = Math.min(1, weightedEnergy / 9.6)
    }

    onPointsChanged: root._updateTargets()
    onNormalizationCeilingChanged: root._updateTargets()

    FrameAnimation {
        running: root.visible && root.active
        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            const smoothingFactor = Math.max(0, Math.min(8, root.smoothing))
            const attackRate = 24 / (1 + smoothingFactor * 0.22)
            const releaseRate = 8 / (1 + smoothingFactor * 0.20)
            const peakReleaseRate = 2.1 / (1 + smoothingFactor * 0.14)
            const energyAttackRate = 12 / (1 + smoothingFactor * 0.18)
            const energyReleaseRate = 3.2 / (1 + smoothingFactor * 0.16)
            function follow(current, target, attack, release) {
                const rate = target > current ? attack : release
                return current + (target - current) * (1 - Math.exp(-dt * rate))
            }
            root._bandsA = Qt.vector4d(
                follow(root._bandsA.x, root._targetA.x, attackRate, releaseRate),
                follow(root._bandsA.y, root._targetA.y, attackRate, releaseRate),
                follow(root._bandsA.z, root._targetA.z, attackRate, releaseRate),
                follow(root._bandsA.w, root._targetA.w, attackRate, releaseRate))
            root._bandsB = Qt.vector4d(
                follow(root._bandsB.x, root._targetB.x, attackRate, releaseRate),
                follow(root._bandsB.y, root._targetB.y, attackRate, releaseRate),
                follow(root._bandsB.z, root._targetB.z, attackRate, releaseRate),
                follow(root._bandsB.w, root._targetB.w, attackRate, releaseRate))
            root._bandsC = Qt.vector4d(
                follow(root._bandsC.x, root._targetC.x, attackRate, releaseRate),
                follow(root._bandsC.y, root._targetC.y, attackRate, releaseRate),
                follow(root._bandsC.z, root._targetC.z, attackRate, releaseRate),
                follow(root._bandsC.w, root._targetC.w, attackRate, releaseRate))
            root._peakA = Qt.vector4d(
                follow(root._peakA.x, Math.max(root._bandsA.x, root._peakA.x), attackRate, peakReleaseRate),
                follow(root._peakA.y, Math.max(root._bandsA.y, root._peakA.y), attackRate, peakReleaseRate),
                follow(root._peakA.z, Math.max(root._bandsA.z, root._peakA.z), attackRate, peakReleaseRate),
                follow(root._peakA.w, Math.max(root._bandsA.w, root._peakA.w), attackRate, peakReleaseRate))
            root._peakB = Qt.vector4d(
                follow(root._peakB.x, Math.max(root._bandsB.x, root._peakB.x), attackRate, peakReleaseRate),
                follow(root._peakB.y, Math.max(root._bandsB.y, root._peakB.y), attackRate, peakReleaseRate),
                follow(root._peakB.z, Math.max(root._bandsB.z, root._peakB.z), attackRate, peakReleaseRate),
                follow(root._peakB.w, Math.max(root._bandsB.w, root._peakB.w), attackRate, peakReleaseRate))
            root._peakC = Qt.vector4d(
                follow(root._peakC.x, Math.max(root._bandsC.x, root._peakC.x), attackRate, peakReleaseRate),
                follow(root._peakC.y, Math.max(root._bandsC.y, root._peakC.y), attackRate, peakReleaseRate),
                follow(root._peakC.z, Math.max(root._bandsC.z, root._peakC.z), attackRate, peakReleaseRate),
                follow(root._peakC.w, Math.max(root._bandsC.w, root._peakC.w), attackRate, peakReleaseRate))
            root._energy = follow(root._energy, root._targetEnergy,
                energyAttackRate, energyReleaseRate)
            const rise = Math.max(0, root._energy - root._previousEnergy)
            root._onset = follow(root._onset, Math.min(1, rise * 7.5), 28, 4.8)
            // Pulse follows both sustained low-frequency energy and transients.
            // It is deliberately quicker than the contour envelope so Organic
            // feels musical instead of merely wobbling around the cover art.
            const bassPulse = Math.max(root._bandsA.x, root._bandsA.y)
            const pulseTarget = Math.min(1, bassPulse * 0.72 + root._energy * 0.42 + root._onset * 0.88)
            root._pulse = follow(root._pulse, pulseTarget, 18, 5.2)
            root._previousEnergy = root._energy
            const speed = Math.max(0.2, Math.min(2.5, root.motionSpeed))
            const idle = Math.max(0, Math.min(1, root.idleMotion))
            root._phase = (root._phase + dt * speed
                * (0.055 + idle * 0.035 + root._energy * 0.075 + root._onset * 0.12)) % 1
            root._spin = (root._spin + dt * speed * (0.020 + idle * 0.025 + root._energy * 0.018)) % 6.28318530718
        }
    }

    ShaderEffect {
        id: blob
        readonly property real hostSpan: Math.min(root.width, root.height)
        readonly property real span: hostSpan * Math.max(1.0, root.overscan)

        width: root.stretchToHost
            ? root.width * Math.max(1.0, root.overscan) : span
        height: root.stretchToHost
            ? root.height * Math.max(1.0, root.overscan) : span
        anchors.centerIn: parent
        visible: root.active && span > 2

        property real phase: root._phase
        property real spin: root._spin
        property real energy: root._energy
        property real onset: root._onset
        property real pulse: root._pulse
        property real amplitude: root.amplitude
        property real reveal: root.reveal
        property real deformationStrength: Math.max(0.25, Math.min(2.0, root.sensitivity))
        property real pulseStrength: Math.max(0, Math.min(1.5, root.pulseStrength))
        property real compression: Math.max(0, Math.min(1, root.compression))
        property real idleMotion: Math.max(0, Math.min(1, root.idleMotion))
        property real glowStrength: Math.max(0, Math.min(1.5, root.glowStrength))
        property real presentationScale: Math.max(0.45, Math.min(1.35, root.presentationScale))
        property real baseRadius: Math.max(0.20, Math.min(0.78, root.baseRadius))
        property real hollowAmount: Math.max(0, Math.min(1, root.hollowAmount))
        property real presentationMode: root.presentationMode
        property real aspectRatio: Math.max(0.25, Math.min(8.0, width / Math.max(1, height)))
        property real edgeBaseRadius: Math.max(0.0, Math.min(0.75, root.edgeBaseRadius))
        property vector2d edgeCardHalf: root.edgeCardHalf
        property vector2d edgeReachHalf: root.edgeReachHalf
        property real edgeCornerRadius: Math.max(0.0, root.edgeCornerRadius)
        property vector4d edgeReachScales: root.edgeReachScales
        property vector4d edgeDirections: root.edgeDirections
        property vector4d bandsA: root._bandsA
        property vector4d bandsB: root._bandsB
        property vector4d bandsC: root._bandsC
        property vector4d peaksA: root._peakA
        property vector4d peaksB: root._peakB
        property vector4d peaksC: root._peakC
        property vector4d primaryColor: Qt.vector4d(
            root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, root.primaryColor.a)
        property vector4d secondaryColor: Qt.vector4d(
            root.secondaryColor.r, root.secondaryColor.g, root.secondaryColor.b, root.secondaryColor.a)
        property vector4d tertiaryColor: Qt.vector4d(
            root.tertiaryColor.r, root.tertiaryColor.g, root.tertiaryColor.b, root.tertiaryColor.a)

        fragmentShader: Qt.resolvedUrl("OrganicAudioBlob.frag.qsb")
    }
}
