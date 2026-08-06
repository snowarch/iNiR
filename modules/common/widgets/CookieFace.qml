pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

// Organic visual face for Cookie Shapes mode. Geometry and input stay owned
// by the host; this component only paints behind its content.
Item {
    id: root

    property color color: Appearance.colors.colLayer1
    property string role: "plate" // plate | card | control | badge
    property bool selected: false
    // Content surfaces may override the outer corner radius while retaining the
    // cookie edge treatment. Organic glyph holders ignore this value.
    property real radius: Appearance.rounding.large
    // Drawn as a ring on the same silhouette, so a focused control reads as an
    // outline instead of a filled plate — which is the only thing that works on
    // hosts whose own fill is transparent (the dock, bar icon buttons).
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    readonly property real aspect: width / Math.max(height, 1)
    readonly property real maxOrganicAspect: role === "control" ? 2.2 : 1.65

    // What a face HOLDS decides whether it may be a polygon at all.
    //
    // `badge` and `control` hold a glyph. A lobed silhouette around an icon is
    // the whole point of the style, and the glyph sits comfortably inside the
    // lobes.
    //
    // `plate` and `card` hold LAYOUT — rows, chips, text. Material Expressive
    // keeps those surfaces stable and reserves organic silhouettes for focal
    // controls and state. Lobes behind laid-out content read as a cloud and
    // compete with the content, so these roles use a generous pebble instead.
    readonly property bool _contentSurface: role === "plate" || role === "card"
    readonly property bool organic: !root._contentSurface
        && aspect <= maxOrganicAspect
        && aspect >= 1 / maxOrganicAspect

    // Only glyph holders ever reach CookiePlate, so only their shapes live here.
    // Transient pointer states never change topology: morphing communicates
    // persistent state only, and hover/press feedback belongs to colour/scale/ripple.
    readonly property string shape: role === "control"
        ? (selected ? "cookie6" : "pill")
        : (selected ? "cookie12" : "cookie9") // badge

    // A wide CONTROL stays a clean pill. The scallop needs room to read as
    // texture: a 36px-tall tab fits only two lobes along its long edge, and two
    // lobes do not read as a cookie, they read as two fused circles. Rendered and
    // compared before settling on this — it was genuinely ugly.
    Rectangle {
        anchors.fill: parent
        visible: !root.organic && root.role === "control"
        color: root.color
        radius: height / 2
        border.width: root.strokeWidth
        border.color: root.strokeColor
    }

    // Content surfaces and unusually elongated badges keep a calm silhouette.
    // Cookie identity still comes through the dedicated tonal ramp, larger
    // radii, expressive controls and motion; repeating scallops here made large
    // backgrounds look ornamental instead of Material Expressive.
    Rectangle {
        anchors.fill: parent
        visible: !root.organic && root.role !== "control"
        color: root.color
        radius: Math.min(root.radius, width / 2, height / 2)
        border.width: root.strokeWidth
        border.color: root.strokeColor
    }

    Loader {
        anchors.fill: parent
        active: root.organic
        sourceComponent: CookiePlate {
            shape: root.shape
            color: root.color
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
        }
    }
}
