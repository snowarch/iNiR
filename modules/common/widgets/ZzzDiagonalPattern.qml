pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common

// Generated-color diagonal hatching for ZZZ surfaces.
//
// One Shape (a single stroked ShapePath / PathMultiline) per instance instead
// of ~42 rotated Rectangle delegates. On a busy settings page this collapses
// the always-resident object + scene-graph node count ~14× (was ~5700 Items
// across the visible SettingsCardSections), cutting memory and JSGC churn.
// Zero work when inactive (empty path → nothing to triangulate or draw).
Item {
    id: root

    anchors.fill: parent
    clip: true

    property int stripeSpacing: 22
    property int stripeThickness: Math.max(1, Appearance.zzz.borderThick)
    property color stripeColor: Appearance.zzz.diagonalStripe
    readonly property bool active: Appearance.zzzEverywhere && Appearance.zzz.useDiagonals

    // -24° from vertical (matches the old rotated-rect lean): every stripe runs
    // top→bottom edge, tilting left toward the top. Built once per geometry
    // change as one multiline so the whole hatch is a single stroked path
    // (one node), not N items. Strokes overflow the bounds; parent clip trims.
    readonly property real _run: height * Math.tan(24 * Math.PI / 180)
    readonly property var stripePaths: {
        if (!active || width <= 0 || height <= 0)
            return []
        const sp = Math.max(1, stripeSpacing)
        const run = _run
        const out = []
        for (let b = -run; b <= width + run; b += sp)
            out.push([Qt.point(b - run, 0), Qt.point(b, height)])
        return out
    }

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

    Shape {
        anchors.fill: parent
        visible: root.active
        asynchronous: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.stripeColor
            strokeWidth: root.stripeThickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            // Single element holding every stripe as a disconnected 2-point line.
            PathMultiline { paths: root.stripePaths }
        }
    }
}
