pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

PanelSurface {
    id: root

    property bool raised: false
    property bool quiet: false
    property real radius: IrisStyle.radius
    property bool notchTop: false
    property bool notchBottom: false

    surfaceDialect: "inir"
    elevation: root.raised ? 2 : 1
    opaqueSurface: true
    radiusOverride: root.radius
    cardStyle: false
    borderless: true
    outlined: false
    borderWidthOverride: 1
    clipContent: false

    Rectangle {
        anchors.fill: parent
        z: -1
        visible: !root.quiet
        radius: root.radius
        topLeftRadius: root.notchTop ? 0 : radius
        topRightRadius: root.notchTop ? 0 : radius
        bottomLeftRadius: root.notchBottom ? 0 : radius
        bottomRightRadius: root.notchBottom ? 0 : radius
        color: IrisStyle.surface
        antialiasing: true
    }
}
