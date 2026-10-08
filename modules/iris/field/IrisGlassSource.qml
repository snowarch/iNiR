pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services
import qs.modules.iris.components
import qs.modules.iris.style

Item {
    id: root

    property var screen: null
    width: root.screen?.width ?? 0
    height: root.screen?.height ?? 0
    readonly property bool ready: view.ready
    readonly property Item texture: blurred

    // Hidden by opacity, not visibility: a hidden subtree never renders a video frame into the texture.
    opacity: 0

    IrisWallpaperView {
        id: view
        anchors.fill: parent
        screen: root.screen
        provideTexture: true
        decodeSize: Qt.size(Math.max(1, Math.round((root.screen?.width ?? root.width) / 2)),
            Math.max(1, Math.round((root.screen?.height ?? root.height) / 2)))
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
        source: view.textureItem
        autoPaddingEnabled: false
        blurEnabled: true
        blur: IrisStyle.glassBlurAmount
        blurMax: IrisStyle.glassBlurMax
        saturation: Math.max(-1, Math.min(1, IrisStyle.glassSaturation + Wallpapers.desktopSaturation))
        contrast: Wallpapers.desktopContrast
    }
}
