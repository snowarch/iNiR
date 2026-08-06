pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.functions

// ZZZ signature: a burst of forward-skewed parallelogram bars — the angular
// "speed / hazard chevron" motif that sits behind or beside signature content.
// Zero delegates when inactive. Place inside a clipped surface.
Item {
    id: root

    // Visuals
    property color barColor: Appearance.zzz.accent
    // When true, bars cycle the ZZZ pop triad (accent / lime / violet) so the
    // signature carries the multi-pop energy on its own.
    property bool triad: false
    property var triadColors: [Appearance.zzz.accent, Appearance.zzz.secondary, Appearance.zzz.tertiary]
    property int bars: 3
    property real slant: 0.55          // horizontal lean as a fraction of height
    property real barWidthFrac: 0.12   // each bar width as a fraction of width (thinner = elegant, not chunky)
    property real gapFrac: 0.14        // gap between bars as a fraction of width (more air → composed, not loose)
    // Base opacity: a triad reads as a faint layered accent flourish, NOT three
    // loud loose lines. Front bar strongest, stepping down per bar.
    property real triadBaseAlpha: 0.30
    property real falloff: 0.34        // opacity step per bar (front bar strongest)
    property bool mirror: false        // lean the other way

    readonly property bool active: Appearance.zzzEverywhere
    visible: opacity > 0
    opacity: active ? 1 : 0

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Repeater {
        model: root.active ? root.bars : 0

        Shape {
            id: bar
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true

            readonly property real bw: root.width * root.barWidthFrac
            readonly property real step: root.width * (root.barWidthFrac + root.gapFrac)
            readonly property real lean: root.height * root.slant * (root.mirror ? -1 : 1)
            readonly property real x0: root.mirror
                ? root.width - root.height * root.slant - index * step
                : index * step

            readonly property color baseColor: root.triad
                ? root.triadColors[index % root.triadColors.length]
                : root.barColor

            ShapePath {
                strokeWidth: 0
                fillColor: ColorUtils.applyAlpha(bar.baseColor, root.triad
                    ? Math.max(0.10, root.triadBaseAlpha - bar.index * root.falloff)
                    : Math.max(0.12, 1.0 - bar.index * root.falloff))
                startX: bar.x0;            startY: root.height
                PathLine { x: bar.x0 + bar.lean;          y: 0 }
                PathLine { x: bar.x0 + bar.lean + bar.bw; y: 0 }
                PathLine { x: bar.x0 + bar.bw;            y: root.height }
                PathLine { x: bar.x0;                     y: root.height }
            }

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }
}
