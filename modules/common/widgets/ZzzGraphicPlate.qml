pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common

// Clean ZZZ plate: a generated surface separated by fill, not outlines. Heavy
// ornaments (hatching, ghost type, edge rail) are OPT-IN and off by default —
// the bold ZZZ statement lives at panel level, cards stay clean.
// Inner content is masked to the rounded silhouette so accents follow the corners.
Rectangle {
    id: root

    property string ghostText: ""
    property bool showTape: false            // opt-in poster edge rail
    property bool showDiagonalPattern: false // opt-in hatching
    property bool showTechFrame: false // cards stay clean; the tech frame is a panel-level statement
    property string frameLabel: ""
    property string frameIndex: ""
    property color plateColor: Appearance.zzz.paper
    property color strokeColor: Appearance.zzz.hairlineStrong
    property color ghostColor: Appearance.zzz.ghostInk
    property color accentColor: Appearance.zzz.accent
    readonly property bool active: Appearance.zzzEverywhere

    visible: active
    color: "transparent" // real fill is painted by the masked inner layer
    radius: Appearance.zzz.panelRadius
    // Outer hairline drawn by the antialiased Shape outline below (drawn on
    // top of the masked inner layer). A Rectangle.border on a radius=18 curve
    // renders a fuzzy/stair-stepped 1px stroke — the "bordecito blanco feo en
    // las esquinas". The Shape stroke stays crisp at every corner.
    border.width: 0
    border.color: "transparent"

    // Inner content masked to the rounded silhouette (plain `clip` is rectangular).
    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: root.active
        layer.smooth: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: inner.width
                height: inner.height
                radius: root.radius
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.plateColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        // ── Opt-in ornaments (off by default) ──
        ZzzDiagonalPattern {
            anchors.fill: parent
            visible: root.active && root.showDiagonalPattern
            stripeSpacing: 18
            stripeThickness: 1
            stripeColor: root.ghostColor
        }

        ZzzTechFrame {
            visible: root.showTechFrame
            label: root.frameLabel
            index: root.frameIndex
            margin: Math.max(8, Appearance.zzz.borderThick * 4)
            gridSpacing: 64
            accentColor: root.accentColor
            lineColor: Appearance.zzz.technicalGrid
            showGrid: false
            showTicks: false
        }

        Text {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: -Math.round(width * 0.06)
                bottomMargin: -Math.round(height * 0.22)
            }
            visible: root.ghostText.length > 0
            text: root.ghostText
            color: root.ghostColor
            font.family: Appearance.font.family.title
            font.pixelSize: Math.max(34, Math.round(root.height * 0.62))
            font.weight: Font.Black
            font.italic: true
            renderType: Text.NativeRendering
        }

        ZzzSurfaceAccent {
            showTape: root.showTape
            showSticker: false
            tapeHeight: Appearance.zzz.borderThick * 3
        }

        // TRA-style clipped-corner cue. The plate remains rectangular for layout
        // stability, while the drawn diagonal makes the ZZZ surface read as a
        // technical cut panel. Tied to the tech frame so clean cards have no
        // floating diagonal in their corner.
        Rectangle {
            visible: root.showTechFrame
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Appearance.zzz.borderThick
            anchors.bottomMargin: Math.round(Appearance.zzz.cutCorner / 2)
            width: Appearance.zzz.cutCorner + 6
            height: Appearance.zzz.borderThick
            rotation: -45
            color: root.accentColor
        }
    }

    // ── Outer hairline outline (antialiased, follows the panel radius) ──
    // Drawn on top of the masked inner layer so it always reads as one crisp
    // stroke around the card silhouette (replaces the Rectangle.border that
    // fuzzed at the rounded corners — the "bordecito blanco feo").
    Shape {
        id: plateOutline
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        readonly property real inset: Appearance.zzz.borderThick / 2
        readonly property real r: Math.max(0, Math.min(root.radius, root.width / 2 - plateOutline.inset, root.height / 2 - plateOutline.inset))
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.strokeColor
            strokeWidth: Appearance.zzz.borderThick
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: plateOutline.inset + plateOutline.r
            startY: plateOutline.inset
            PathLine { x: root.width - plateOutline.inset - plateOutline.r; y: plateOutline.inset }
            PathArc { x: root.width - plateOutline.inset; y: plateOutline.inset + plateOutline.r; radiusX: plateOutline.r; radiusY: plateOutline.r }
            PathLine { x: root.width - plateOutline.inset; y: root.height - plateOutline.inset - plateOutline.r }
            PathArc { x: root.width - plateOutline.inset - plateOutline.r; y: root.height - plateOutline.inset; radiusX: plateOutline.r; radiusY: plateOutline.r }
            PathLine { x: plateOutline.inset + plateOutline.r; y: root.height - plateOutline.inset }
            PathArc { x: plateOutline.inset; y: root.height - plateOutline.inset - plateOutline.r; radiusX: plateOutline.r; radiusY: plateOutline.r }
            PathLine { x: plateOutline.inset; y: plateOutline.inset + plateOutline.r }
            PathArc { x: plateOutline.inset + plateOutline.r; y: plateOutline.inset; radiusX: plateOutline.r; radiusY: plateOutline.r }
        }
    }
}
