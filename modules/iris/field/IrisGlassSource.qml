pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services
import qs.modules.iris.background
import qs.modules.iris.components
import qs.modules.iris.style

Item {
    id: root

    property var screen: null
    // A window that stops a live wallpaper while it rests (IrisGlassPane) says so; the chassis's copy always plays.
    property bool live: true
    width: root.screen?.width ?? 0
    height: root.screen?.height ?? 0
    readonly property bool ready: view.ready
    readonly property Item texture: blurred

    // Hidden by opacity, not visibility: a hidden subtree never renders a video frame into the texture.
    opacity: 0

    readonly property size half: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))

    IrisWallpaperView {
        id: view
        anchors.fill: parent
        screen: root.screen
        live: root.live
        // Under a grade the grade captures the view itself.
        provideTexture: !grade.active
        decodeSize: Qt.size(Math.max(1, Math.round((root.screen?.width ?? root.width) / 2)),
            Math.max(1, Math.round((root.screen?.height ?? root.height) / 2)))
    }

    // The desktop wears a texture's light (Afterglow, Light leak): the glass blurs the same graded picture, so a body
    // keeps its frost and the light the wallpaper shows runs on through it. Graded at the blur's half resolution, kept
    // until the picture or the light changes; the copy never develops on its own (the desktop's is what is seen).
    Loader {
        id: grade
        anchors.fill: parent
        active: IrisStyle.afterglowWallpaper || IrisStyle.leakWallpaper
        sourceComponent: IrisStyle.afterglowWallpaper ? afterglowGrade : leakGrade
    }
    Component {
        id: afterglowGrade
        IrisAfterglowWallpaper {
            source: view
            textureSize: root.half
        }
    }
    Component {
        id: leakGrade
        IrisLeakWallpaper {
            source: view
            develops: false
            textureSize: root.half
        }
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.textureSize: root.half
        source: grade.item?.texture ?? view.textureItem
        autoPaddingEnabled: false
        blurEnabled: true
        blur: IrisStyle.glassBlurAmount
        blurMax: IrisStyle.glassBlurMax
        saturation: Math.max(-1, Math.min(1, IrisStyle.glassSaturation + Wallpapers.desktopSaturation))
        contrast: Wallpapers.desktopContrast
    }
}
