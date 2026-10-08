pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

Item {
    id: root

    property color faceColor: Appearance.editorial.paper
    property color backingColor: Appearance.editorial.paperBacking
    property color edgeColor: Qt.alpha(Appearance.editorial.edge, 0.70)
    property color backingEdgeColor: Qt.alpha(Appearance.editorial.accent, 0.50)
    property real edgeWidth: 1
    property real materialOpacity: 1
    property real backingOpacity: 1
    property real radius: Appearance.editorial.radius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    readonly property real depth: Math.max(0, Math.min(Math.round(Appearance.editorial.paperDepth), Math.floor(width / 8), Math.floor(height / 8)))
    readonly property real faceWidth: Math.max(0, width - depth)
    readonly property real faceHeight: Math.max(0, height - depth)

    function faceRadius(value: real): real {
        return Math.max(0, Math.min(value,
            root.faceWidth / 2, root.faceHeight / 2))
    }

    visible: Appearance.editorialEverywhere && Appearance.editorial.paperStack

    // Both sheets stay inside the host's mask and input geometry.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Qt.alpha(root.backingColor, root.backingOpacity)
        border.width: root.edgeWidth
        border.color: root.backingEdgeColor
    }

    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: root.depth
        anchors.bottomMargin: root.depth
        radius: root.faceRadius(root.radius)
        topLeftRadius: root.faceRadius(root.topLeftRadius)
        topRightRadius: root.faceRadius(root.topRightRadius)
        bottomLeftRadius: root.faceRadius(root.bottomLeftRadius)
        bottomRightRadius: root.faceRadius(root.bottomRightRadius)
        color: Qt.alpha(root.faceColor, root.materialOpacity)
        border.width: root.edgeWidth
        border.color: root.edgeColor
    }
}
