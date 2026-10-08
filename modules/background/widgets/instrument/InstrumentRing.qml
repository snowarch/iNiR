pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Shared instrument-ring primitive for desktop widgets.
 *
 * One continuous instrument on a single shared radius: 60 minute ticks with
 * quarter emphasis, an optional recency trail, an elapsed arc with a comet
 * tail riding the tip, and optional radial labels. Borderless by contract —
 * the caller owns center content and wallpaper-sampled ink tokens.
 */
Item {
    id: root

    // ── Geometry (fills parent; ring centers on this item) ──
    property real scaleFactor: 1

    // ── Instrument state ─────────────────────────────────────
    // Elapsed fraction of the tracked period, 0..1.
    property real fraction: 0
    // Minutes of "trail" that glow brighter behind the arc tip.
    property bool recencyTrail: true
    property real recencyMinutes: 40

    // ── Options ──────────────────────────────────────────────
    property bool showTicks: true
    property bool showArc: true
    property bool showComet: true
    // Tick rhythm: watch faces use 60 ticks with a medium tier every 5;
    // gauges use a coarser count with the medium tier disabled.
    property int tickCount: 60
    property int midEvery: 5
    // Soft level band just inside the ticks, for magnitude instruments
    // (levels) as opposed to cycle instruments (watches).
    property bool showFill: false
    // Fixed band: a faint arc marking a constant span of the cycle (e.g. the
    // night half of a watch dial), independent of the elapsed fraction.
    property bool showBand: false
    // Filled variant: the band as a low-alpha half-disc (180° spans close by
    // chord) — the night side reads as a side of the dial, not a loose line.
    property bool bandFill: false
    property real bandFrom: 0
    property real bandTo: 1
    readonly property color bandColor: ColorUtils.applyAlpha(ink, 0.14)
    readonly property color bandFillColor: ColorUtils.applyAlpha(ink, 0.06)
    // Radial labels just outside the ring; each { text, hour } where
    // hour places the label clockwise from 12 o'clock (0..24).
    property var labels: []
    property bool showLabels: true
    // Chapters inside the tick track (watch numerals) instead of outside it.
    property bool labelsInside: false
    // Default chapter size, unscaled px. A label may override per item:
    // { text, hour, size: finalPx, accent: true } — hero chapters use size
    // + accent, base chapters inherit.
    property real labelPixelSize: 11

    // ── Tokens (callers pass wallpaper-sampled semantic inks) ──
    property color ink
    property color accent
    property color accentSoft
    property bool animated: true

    readonly property real size: Math.min(width, height)
    readonly property real radius: Math.max(1, size / 2 - Math.max(6,
        showLabels && !labelsInside
            ? Math.round(24 * scaleFactor)
            : Math.min(Math.round(15 * scaleFactor), Math.round(size * 0.13))))
    readonly property real arcWidth: Math.max(3, Math.round(4.5 * scaleFactor))
    readonly property int quarterStep: Math.max(1, Math.round(root.tickCount / 4))

    readonly property color inkFaint: ColorUtils.applyAlpha(ink, 0.26)
    readonly property color inkDim: ColorUtils.applyAlpha(ink, 0.62)
    readonly property real progress: Number.isFinite(fraction)
        ? Math.max(0, Math.min(1, fraction)) : 0
    readonly property color cometOuter: showArc && showComet ? ColorUtils.applyAlpha(accent, 0.18) : "transparent"
    readonly property color cometInner: showArc && showComet ? ColorUtils.applyAlpha(accent, 0.38) : "transparent"

    Behavior on fraction {
        enabled: animated
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    // ── Fixed band ──────────────────────────────────────
    Shape {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        preferredRendererType: Shape.CurveRenderer
        visible: root.showBand || root.bandFill

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.bandFill ? root.bandFillColor : "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: Math.max(1, root.radius - root.arcWidth - Math.round(2 * root.scaleFactor))
                radiusY: Math.max(1, root.radius - root.arcWidth - Math.round(2 * root.scaleFactor))
                startAngle: -90 + root.bandFrom * 360
                sweepAngle: (root.bandTo - root.bandFrom) * 360
            }
        }

        ShapePath {
            strokeColor: root.showBand ? root.bandColor : "transparent"
            strokeWidth: Math.max(1, Math.round(1.5 * root.scaleFactor))
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: Math.max(1, root.radius - root.arcWidth - Math.round(2 * root.scaleFactor))
                radiusY: Math.max(1, root.radius - root.arcWidth - Math.round(2 * root.scaleFactor))
                startAngle: -90 + root.bandFrom * 360
                sweepAngle: (root.bandTo - root.bandFrom) * 360
            }
        }
    }

    // ── Tick ring ────────────────────────────────────────────
    Repeater {
        model: Math.max(0, root.tickCount)

        Item {
            id: tick
            required property int index
            readonly property bool elapsed: root.progress > 0
                && (index / root.tickCount) < root.progress
            readonly property bool quarter: index % root.quarterStep === 0
            readonly property bool mid: root.midEvery > 0
                && index % root.midEvery === 0 && !tick.quarter
            // Recent minutes burn brighter toward the tip: the ring reads
            // as a fading trail instead of a flat fill.
            readonly property real recency: root.recencyTrail
                ? Math.max(0, Math.min(1, 1 - (root.progress * root.tickCount - index) / Math.max(1, root.recencyMinutes)))
                : 0
            opacity: root.showTicks ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: root.animated
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            anchors.centerIn: root
            width: root.size
            height: root.size
            rotation: index * (360 / root.tickCount)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                // Ticks straddle the shared radius so the arc meets them
                // edge-to-edge instead of floating inside.
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -root.radius
                width: tick.quarter ? Math.round(3 * root.scaleFactor)
                    : tick.mid ? Math.max(1, Math.round(2 * root.scaleFactor))
                    : 1
                height: tick.quarter ? Math.round(13 * root.scaleFactor)
                    : tick.mid ? Math.round(9 * root.scaleFactor)
                    : Math.round(6 * root.scaleFactor)
                radius: width / 2
                color: !tick.elapsed
                    ? (tick.quarter ? ColorUtils.applyAlpha(root.ink, 0.52)
                        : tick.mid ? ColorUtils.applyAlpha(root.ink, 0.26)
                        : root.inkFaint)
                    : tick.quarter ? root.accent
                    : ColorUtils.applyAlpha(root.accentSoft, 0.34 + 0.66 * tick.recency)
                Behavior on color {
                    enabled: root.animated
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }
        }
    }

    // ── Radial labels ────────────────────────────────────────
    Repeater {
        model: root.labels

        StyledText {
            id: ringLabel
            required property var modelData
            readonly property real angle: (Number(modelData.hour) / 24) * 2 * Math.PI - Math.PI / 2
            readonly property real labelRadius: root.labelsInside
                ? root.radius - Math.max(14, Math.round(16 * root.scaleFactor))
                : root.radius + Math.max(15, Math.round(16 * root.scaleFactor))
            // Center on the ring's true center per axis (same reference as
            // the ticks' anchors.centerIn) so labels stay attached at any
            // widget aspect ratio.
            x: root.width / 2 + labelRadius * Math.cos(angle) - width / 2
            y: root.height / 2 + labelRadius * Math.sin(angle) - height / 2
            opacity: root.showLabels ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: root.animated
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            text: String(modelData.text)
            color: modelData.accent ? root.accent : root.inkDim
            font {
                family: Appearance.font.family.numbers
                pixelSize: Math.round(modelData.size
                    ?? root.labelPixelSize * root.scaleFactor)
                weight: modelData.accent ? Font.Bold : Font.DemiBold
                letterSpacing: 1
            }
        }
    }

    // ── Elapsed arc + comet tail ─────────────────────────────
    Shape {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        preferredRendererType: Shape.CurveRenderer
        opacity: (root.showArc || root.showFill) && root.progress > 0.0005 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: root.animated
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        // Level band: a soft stroke just inside the ticks that grows with
        // the fraction. Gauges read through this fill; watches leave it off
        // so the sharp elapsed arc stays the only sweep.
        ShapePath {
            strokeColor: root.showFill
                ? ColorUtils.applyAlpha(root.accent, 0.13) : "transparent"
            strokeWidth: Math.max(5, Math.round(9 * root.scaleFactor))
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: Math.max(1, root.radius - Math.round(7 * root.scaleFactor))
                radiusY: Math.max(1, root.radius - Math.round(7 * root.scaleFactor))
                startAngle: -90
                sweepAngle: root.progress * 360
            }
        }

        ShapePath {
            strokeColor: root.showArc ? root.accent : "transparent"
            strokeWidth: root.arcWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: root.progress * 360
            }
        }

        // Comet tail riding the tip on the same radius: motion emphasis
        // that melts into the arc instead of a detached dot.
        ShapePath {
            strokeColor: root.cometOuter
            strokeWidth: root.arcWidth + Math.max(2, Math.round(2.5 * root.scaleFactor))
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90 + root.progress * 360 - 14
                sweepAngle: 14
            }
        }
        ShapePath {
            strokeColor: root.cometInner
            strokeWidth: root.arcWidth + Math.max(1, Math.round(1.5 * root.scaleFactor))
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90 + root.progress * 360 - 5
                sweepAngle: 5
            }
        }
    }
}
