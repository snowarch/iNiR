pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common

// ZZZ signature surface: a rectangle whose corner is CHAMFERED in the real
// geometry (a true 45° cut), not a sticker drawn on top. This is the distinctive
// ZZZ plate silhouette — fillable, strokeable, antialiased — and the building
// block for ZZZ cards, buttons and console keys.
//
// Content goes in the default slot and sits on top of the plate. The plate paints
// the fill + optional technical stroke following the chamfered outline exactly.
Item {
    id: root

    property color fillColor: Appearance.zzz.paper
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    // Chamfer size; clamped so it never exceeds half the smallest side.
    property real chamfer: Appearance.zzz.cutCorner
    readonly property real _ch: Math.max(0, Math.min(chamfer, width / 2, height / 2))
    // Rounded-corner radius. When > 0 (e.g. ZZZ round mode), the plate renders
    // as a native rounded Rectangle instead of the chamfered Shape — this is
    // what makes the round anime read apply to every ZzzPlate-based surface,
    // which previously stayed square because the Shape's PathLine geometry
    // ignored radius entirely.
    property real radius: Appearance.zzz.round ? Appearance.zzz.panelRadius : 0
    readonly property bool _rounded: radius > 0
    // Which corners are cut. The ZZZ default is a single bottom-right cut — the
    // restrained "manufactured panel" read. Opt into more for stronger statements.
    // (Chamfer flags only apply in SQUARE mode; rounded mode paints all corners.)
    property bool chamferTopLeft: false
    property bool chamferTopRight: false
    property bool chamferBottomLeft: false
    property bool chamferBottomRight: true

    default property alias content: contentHolder.data

    // ── Rounded renderer (round mode) ──
    // Fill: native Rectangle (no border). Stroke: an antialiased Shape outline
    // (CurveRenderer) tracing a rounded rect.
    // Rationale: Qt's Rectangle.border on a curved edge renders a 1px
    // semi-transparent stroke with uneven/stair-stepped AA — visibly low
    // quality vs the square-mode Shape, which is why round mode looked "feo
    // y de baja calidad" while square stayed crisp. Drawing the hairline on
    // the same kind of antialiased Shape path the square renderer uses makes
    // round-mode edges read just as clean.
    Rectangle {
        anchors.fill: parent
        visible: root._rounded
        radius: root.radius
        color: root.fillColor
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot } }
    }
    Shape {
        id: outline
        anchors.fill: parent
        visible: root._rounded && root.strokeWidth > 0
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        // Inset so the stroke centerline sits half a pixel inside the bounds
        // (Rectangle.border draws fully inside; this matches that and keeps
        // the hairline from being clipped at the item edge).
        readonly property real inset: root.strokeWidth / 2
        readonly property real r: Math.max(0, Math.min(root.radius, root.width / 2 - outline.inset, root.height / 2 - outline.inset))
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: outline.inset + outline.r
            startY: outline.inset
            PathLine { x: root.width - outline.inset - outline.r; y: outline.inset }
            PathArc { x: root.width - outline.inset; y: outline.inset + outline.r; radiusX: outline.r; radiusY: outline.r }
            PathLine { x: root.width - outline.inset; y: root.height - outline.inset - outline.r }
            PathArc { x: root.width - outline.inset - outline.r; y: root.height - outline.inset; radiusX: outline.r; radiusY: outline.r }
            PathLine { x: outline.inset + outline.r; y: root.height - outline.inset }
            PathArc { x: outline.inset; y: root.height - outline.inset - outline.r; radiusX: outline.r; radiusY: outline.r }
            PathLine { x: outline.inset; y: outline.inset + outline.r }
            PathArc { x: outline.inset + outline.r; y: outline.inset; radiusX: outline.r; radiusY: outline.r }
        }
    }

    // ── Chamfered renderer (square mode) ── true 45° cut geometry.
    Shape {
        id: outline_chamfer
        anchors.fill: parent
        visible: !root._rounded
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        // Inset so the stroke centerline sits half a pixel inside the bounds,
        // same as the rounded renderer. Without this, the 1px hairline gets
        // clipped at the item edge and renders as broken dots/segments on the
        // vertical edges above the cut corner.
        readonly property real inset: root.strokeWidth / 2

        ShapePath {
            fillColor: root._rounded ? "transparent" : root.fillColor
            strokeColor: root._rounded ? "transparent" : root.strokeColor
            strokeWidth: root._rounded ? 0 : root.strokeWidth
            joinStyle: ShapePath.MiterJoin

            startX: (root.chamferTopLeft ? root._ch : 0) + outline_chamfer.inset
            startY: outline_chamfer.inset

            PathLine { x: root.width - (root.chamferTopRight ? root._ch : 0) - outline_chamfer.inset; y: outline_chamfer.inset }
            PathLine { x: root.width - outline_chamfer.inset; y: (root.chamferTopRight ? root._ch : 0) + outline_chamfer.inset }
            PathLine { x: root.width - outline_chamfer.inset; y: root.height - (root.chamferBottomRight ? root._ch : 0) - outline_chamfer.inset }
            PathLine { x: root.width - (root.chamferBottomRight ? root._ch : 0) - outline_chamfer.inset; y: root.height - outline_chamfer.inset }
            PathLine { x: (root.chamferBottomLeft ? root._ch : 0) + outline_chamfer.inset; y: root.height - outline_chamfer.inset }
            PathLine { x: outline_chamfer.inset; y: root.height - (root.chamferBottomLeft ? root._ch : 0) - outline_chamfer.inset }
            PathLine { x: outline_chamfer.inset; y: (root.chamferTopLeft ? root._ch : 0) + outline_chamfer.inset }
            PathLine { x: (root.chamferTopLeft ? root._ch : 0) + outline_chamfer.inset; y: outline_chamfer.inset }
        }
    }

    Behavior on fillColor {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    // The chamfer can morph (e.g. grow on hover) for a mechanical ZZZ feedback.
    Behavior on chamfer {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot }
    }
    Behavior on strokeColor {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on strokeWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
