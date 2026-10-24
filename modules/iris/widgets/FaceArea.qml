pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common.functions

// The data drawn as the Day draws the sun: a line through the values with the face's colour fading under it.
// `curve(t)` gives the height (0 baseline, 1 top) at t in 0..1 across the width; the line runs `from`..`upTo` (where
// the data stops: now), the fade under the whole `from`..`to`. An Item around the Shape: a Shape sizes itself from its
// paths, and these come from its size.
Item {
    id: area
    required property var face
    property var curve: t => 0
    property real from: 0
    property real to: 1
    property real upTo: area.to
    property color tint: area.face.accent
    property real fade: 0.26
    // The quiet line along the whole width, as the Day's night.
    property bool rest: false
    property bool guide: true
    readonly property real pad: area.face.dp(4)
    readonly property real base: area.height - area.face.dp(1)

    function yAt(t: real): real {
        return area.base - Math.max(0, Math.min(1, area.curve(t))) * (area.base - area.pad)
    }
    // The fade starts at the shape's own top, not the box's: a low line had almost none under it.
    readonly property real crest: {
        let top = area.base
        for (let i = 0; i <= 48; i++) {
            const t = area.from + (area.to - area.from) * i / 48
            top = Math.min(top, area.yAt(t))
        }
        return top
    }
    function trace(a: real, b: real): string {
        if (area.width <= 0 || b <= a)
            return ""
        const steps = Math.max(2, Math.ceil((b - a) * 96))
        let d = ""
        for (let i = 0; i <= steps; i++) {
            const t = a + (b - a) * i / steps
            d += (i === 0 ? "M " : " L ") + (t * area.width) + " " + area.yAt(t)
        }
        return d
    }

    Rectangle {
        visible: area.guide
        width: parent.width
        height: 1
        y: Math.round(area.base)
        color: area.face.hairline
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: area.crest; x2: 0; y2: area.base
                GradientStop { position: 0; color: ColorUtils.applyAlpha(area.tint, area.fade) }
                GradientStop { position: 1; color: ColorUtils.applyAlpha(area.tint, 0) }
            }
            PathSvg {
                path: {
                    const d = area.trace(area.from, area.to)
                    return d.length > 0 ? d + " L " + area.to * area.width + " " + area.base + " L " + area.from * area.width + " " + area.base + " Z" : ""
                }
            }
        }
        ShapePath {
            strokeColor: area.rest ? area.face.fillActive : "transparent"
            strokeWidth: area.face.dp(2)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathSvg { path: area.rest ? area.trace(0, 1) : "" }
        }
        ShapePath {
            strokeColor: area.tint
            strokeWidth: area.face.dp(2)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            PathSvg { path: area.trace(area.from, Math.min(area.to, area.upTo)) }
        }
    }
}
