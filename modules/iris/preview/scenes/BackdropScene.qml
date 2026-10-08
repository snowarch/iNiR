pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.iris.style
import qs.modules.iris.preview.parts

PreviewScene {
    id: backdropRoot
    readonly property real naturalWidth: Math.round(640 * backdropRoot.d)
    readonly property real naturalHeight: Math.round(260 * backdropRoot.d)
    readonly property bool on: backdropRoot.opt("background.backdrop.enable", true)
    readonly property real blurAmount: Math.max(0, Math.min(100, Number(backdropRoot.opt("background.backdrop.blurRadius", 40))))
    readonly property real dim: Math.max(0, Math.min(100, Number(backdropRoot.opt("background.backdrop.dim", 40)))) / 100
    readonly property bool vignette: backdropRoot.opt("background.backdrop.vignetteEnabled", false)
    Rectangle { anchors.fill: parent; color: IrisStyle.surface }
    Item {
        anchors.fill: parent
        visible: backdropRoot.on
        clip: true
        ShaderEffectSource {
            id: backdropImage
            anchors.fill: parent
            anchors.margins: -48
            visible: false
            sourceItem: backdropRoot.wallpaperView.textureItem
            live: true
        }
        MultiEffect {
            anchors.fill: backdropImage
            source: backdropImage
            blurEnabled: backdropRoot.blurAmount > 0
            blur: backdropRoot.blurAmount / 100
            blurMax: 48
        }
        Rectangle { anchors.fill: parent; color: "black"; opacity: backdropRoot.dim }
        Rectangle {
            anchors.fill: parent
            visible: backdropRoot.vignette
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) } // iris-literal: vignette falloff
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) } // iris-literal: vignette falloff
            }
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: Math.round(18 * backdropRoot.d)
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: Math.round((index === 1 ? 200 : 150) * backdropRoot.d)
                height: Math.round((index === 1 ? 130 : 100) * backdropRoot.d)
                anchors.verticalCenter: parent.verticalCenter
                radius: IrisStyle.radiusTile
                color: IrisStyle.surfaceHigh
                border.width: index === 1 ? 2 : 1
                border.color: index === 1 ? IrisStyle.accent : IrisStyle.border
                Rectangle { x: 10; y: 10; width: parent.width * 0.5; height: 7; radius: 3.5; color: IrisStyle.fill }
                Rectangle { x: 10; y: 24; width: parent.width * 0.7; height: 7; radius: 3.5; color: IrisStyle.fillQuiet }
            }
        }
    }
    Caption {
        glyph: "grid_view"
        text: backdropRoot.on ? Translation.tr("Overview over your wallpaper") : Translation.tr("Overview over Niri's plain background")
    }
}
