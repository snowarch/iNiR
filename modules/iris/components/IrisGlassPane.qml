pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
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
    // In the chassis window the chassis field's blurred wallpaper is already there to cut from.
    readonly property Item shared: IrisGlassBackdrops.find(root.QsWindow.contentItem ?? null, null)
    readonly property bool ready: root.shared ? root.shared.ready : (ownLoader.item?.ready ?? false)

    ShaderEffect {
        x: -(root.sceneOffset.x + root.windowOffset.x)
        y: -(root.sceneOffset.y + root.windowOffset.y)
        width: root.screenWidth
        height: root.screenHeight
        visible: root.shared !== null && root.ready
        property variant source: root.shared?.ready ? root.shared.texture : null
    }

    Loader {
        id: ownLoader
        active: root.shared === null
        sourceComponent: Item {
            readonly property bool ready: wallpaper.ready

            IrisWallpaperView {
                id: wallpaper
                x: -(root.sceneOffset.x + root.windowOffset.x)
                y: -(root.sceneOffset.y + root.windowOffset.y)
                width: root.screenWidth
                height: root.screenHeight
                // Hidden by opacity: a hidden subtree never renders a live wallpaper's frames into the texture.
                opacity: 0
                screen: root.screen
                live: root.live
                provideTexture: true
                decodeSize: Qt.size(Math.max(1, Math.round(root.screenWidth / 2)), Math.max(1, Math.round(root.screenHeight / 2)))
            }

            MultiEffect {
                x: wallpaper.x
                y: wallpaper.y
                width: wallpaper.width
                height: wallpaper.height
                visible: wallpaper.ready
                source: wallpaper.textureItem
                autoPaddingEnabled: false
                blurEnabled: true
                blur: IrisStyle.glassBlurAmount
                blurMax: IrisStyle.glassBlurMax
                saturation: IrisStyle.glassSaturation
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.ready ? root.tint : IrisStyle.surfaceOpaque
    }
}
