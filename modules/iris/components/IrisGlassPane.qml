pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.iris.field
import qs.modules.iris.style

Item {
    id: root

    property point sceneOffset: Qt.point(0, 0)
    property point windowOffset: Qt.point(0, 0)
    property color tint: IrisStyle.placeSurface
    property bool live: true
    readonly property var screen: root.QsWindow.window?.screen ?? null
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real screenHeight: root.screen?.height ?? 1080
    // In the chassis window the chassis field's blurred wallpaper is already there to cut from; elsewhere the pane
    // blurs its own copy, the same one (graded with the desktop's texture), decoded once for this window.
    readonly property Item shared: IrisGlassBackdrops.find(root.QsWindow.contentItem ?? null, null)
    readonly property Item backdrop: root.shared ?? ownLoader.item
    readonly property bool ready: root.backdrop?.ready ?? false

    ShaderEffect {
        x: -(root.sceneOffset.x + root.windowOffset.x)
        y: -(root.sceneOffset.y + root.windowOffset.y)
        width: root.screenWidth
        height: root.screenHeight
        visible: root.ready
        property variant source: root.ready ? root.backdrop.texture : null
    }

    Loader {
        id: ownLoader
        active: root.shared === null
        sourceComponent: IrisGlassSource {
            screen: root.screen
            live: root.live
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.ready ? root.tint : IrisStyle.surfaceOpaque
    }
}
