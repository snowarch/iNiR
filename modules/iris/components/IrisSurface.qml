pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.field
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

    // Light leak: the surface is film exposed by the shell's one light, as the field's bodies are. Every host is a
    // full-output window, so its window position is its place on the output.
    Loader {
        anchors.fill: parent
        z: -1
        active: IrisStyle.leak && !root.quiet
        sourceComponent: IrisLeakPlate {
            at: {
                void (root.x + root.y + root.width + root.height + (root.parent?.x ?? 0) + (root.parent?.y ?? 0))
                return root.mapToItem(null, 0, 0)
            }
            output: Qt.size(root.QsWindow.window?.screen?.width ?? root.width, root.QsWindow.window?.screen?.height ?? root.height)
            corners: Qt.vector4d(root.notchTop ? 0 : root.radius, root.notchTop ? 0 : root.radius,
                root.notchBottom ? 0 : root.radius, root.notchBottom ? 0 : root.radius)
            base: IrisStyle.surface
        }
    }
}
