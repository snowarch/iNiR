pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Motion tokens for the pill family. Durations collapse to zero when the shell
 * has animations off, so the pill honours the same global gate every other
 * iNiR surface does instead of running its own reduce-motion flag.
 */
Singleton {
    readonly property real mult: Appearance.animationsEnabled
        ? ((Config.options?.performance?.reduceAnimations ?? false) ? 0.4 : 1)
        : 0

    readonly property int fast: Math.round(140 * mult)
    readonly property int standard: Math.round(300 * mult)
    readonly property int morph: Math.round(420 * mult)
    readonly property int shapeshift: Math.round(820 * mult)
    readonly property int glide: Math.round(260 * mult)
    readonly property int heat: Math.round(1100 * mult)
    readonly property int pulse: Math.round(420 * mult)

    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph: Easing.BezierSpline

    /**
     * Liquid morph curve, cubic-bezier(0.16, 1, 0.3, 1). Front-loaded like an
     * exponential chase but with a long, visible settle tail.
     */
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]

    readonly property real rSmall: 7
    readonly property real rTile: 13
}
