pragma ComponentBehavior: Bound

import QtQuick
import qs.services.deferred
import qs.modules.common

/**
 * Rest-pill spectrum: one rounded ember bar per band, packed into the clock-glyph
 * slot so the cluster never widens the pill. Heights chase the cava points with a
 * short ease so the motion stays liquid instead of strobing on every frame cava
 * emits.
 *
 * The band count is fixed at five and deliberately does NOT follow the shell's
 * cava settings: the slot is only as wide as the 時 glyph it replaces, and the
 * user's spectrum (50 bands by default) would spill across the clock. The bands
 * are sampled evenly out of whatever CavaService reports.
 */
Row {
    id: root

    property real s: 1
    property real span: 18
    property bool running: false

    /** Bands drawn here, independent of CavaService.effectiveBars. */
    readonly property int bars: 5

    /**
     * cava's ascii range is nominally 0..1000, but with autosens on a typical
     * track only ever reaches a few hundred; dividing by the nominal ceiling
     * flattens every bar to its 2px minimum. Normalise against a running peak
     * instead, floored so silence doesn't amplify noise into a full-height bar.
     */
    readonly property real minPeak: 220
    property real peak: minPeak

    height: span * s
    spacing: 1.2 * s

    readonly property bool _wanted: running && !Appearance.gameModeMinimal
    property bool _held: false

    function _reconcile(): void {
        if (_wanted === _held)
            return
        if (_wanted) CavaService.subscribe()
        else CavaService.unsubscribe()
        _held = _wanted
    }

    on_WantedChanged: root._reconcile()
    Component.onCompleted: root._reconcile()
    Component.onDestruction: if (root._held) CavaService.unsubscribe()

    /**
     * Raw band peaks for the five drawn bars. Peak, not mean: ten source bands
     * fold into each drawn one, and averaging buries every transient in its
     * neighbours. A property, not a function, so the delegates re-evaluate when
     * CavaService pushes a new frame.
     */
    readonly property var raw: {
        const pts = CavaService.points ?? [];
        if (pts.length === 0)
            return [0, 0, 0, 0, 0];

        const per = pts.length / root.bars;
        const out = [];
        for (let i = 0; i < root.bars; i++) {
            const from = Math.floor(i * per);
            const to = Math.max(from + 1, Math.floor((i + 1) * per));
            let band = 0;
            for (let k = from; k < to && k < pts.length; k++)
                band = Math.max(band, pts[k] ?? 0);
            out.push(band);
        }
        return out;
    }

    /**
     * Chase the loudest band seen recently: jump up at once, decay slowly. Kept
     * out of the `levels` binding — writing `peak` from a binding that also reads
     * it is a loop.
     */
    onRawChanged: {
        const frameMax = Math.max.apply(null, root.raw);
        root.peak = frameMax > root.peak
            ? frameMax
            : Math.max(root.minPeak, root.peak * 0.995);
    }

    readonly property var levels: root.raw.map(v => Math.min(1, v / root.peak))

    Repeater {
        model: root.bars

        Rectangle {
            required property int index

            width: 1.8 * root.s
            radius: width / 2
            anchors.bottom: parent.bottom
            height: Math.max(2 * root.s, (root.levels[index] ?? 0) * root.span * root.s)

            gradient: Gradient {
                GradientStop { position: 0.0; color: PillTheme.flameGlow }
                GradientStop { position: 1.0; color: PillTheme.vermLit }
            }

            Behavior on height {
                NumberAnimation { duration: PillMotion.fast; easing.type: Easing.OutQuad }
            }
        }
    }
}
