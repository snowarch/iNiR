pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: glassRoot
    readonly property real naturalWidth: Math.round(620 * glassRoot.d)
    readonly property real naturalHeight: Math.round(280 * glassRoot.d)
    readonly property string mode: String(glassRoot.opt("iris.appearance.glass.mode", "off"))
    property real t: 0
    Loop on t { running: glassRoot.playing; rest: 600 }
    ClippingRectangle {
        id: pane
        width: Math.round(300 * glassRoot.d)
        height: Math.round(170 * glassRoot.d)
        x: Math.round(24 * glassRoot.d + (glassRoot.width - width - 48 * glassRoot.d) * glassRoot.t)
        y: Math.round(28 * glassRoot.d)
        radius: IrisStyle.radiusSheet
        color: IrisStyle.glassy ? "transparent" : IrisStyle.bodySurface
        ShaderEffectSource {
            id: paneSource
            x: -pane.x; y: -pane.y
            width: glassRoot.width; height: glassRoot.height
            visible: false
            sourceItem: IrisStyle.glassy ? glassRoot.wallpaperView.textureItem : null
            live: true
        }
        MultiEffect {
            anchors.fill: paneSource
            visible: IrisStyle.glassy
            source: paneSource
            blurEnabled: true
            blur: IrisStyle.glassBlurAmount
            blurMax: IrisStyle.glassBlurMax
            saturation: IrisStyle.glassSaturation
        }
        Rectangle { anchors.fill: parent; visible: IrisStyle.glassy; color: IrisStyle.bodyTint }
        Column {
            x: IrisStyle.concentricPad(pane.radius, 14 * glassRoot.d)
            y: x
            width: pane.width - 2 * x
            spacing: Math.round(4 * glassRoot.d)
            IrisText { text: Translation.tr("Now playing"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeBody }
            IrisText { width: parent.width; text: Translation.tr("Secondary text stays readable over the wallpaper"); color: IrisStyle.muted; wrapMode: Text.WordWrap; font.pixelSize: IrisStyle.typeMeta }
            IrisText { text: Translation.tr("Tertiary detail"); color: IrisStyle.textTertiary; font.pixelSize: IrisStyle.typeMeta }
        }
        IrisControlPlate {
            id: glassControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: IrisStyle.concentricPad(pane.radius, 12 * glassRoot.d)
            controlHeight: Math.round(30 * glassRoot.d)
            Row {
                spacing: glassControls.framed ? Math.round(4 * glassRoot.d) : Math.round(18 * glassRoot.d)
                Repeater {
                    model: ["skip_previous", "pause", "skip_next"]
                    Item {
                        required property string modelData
                        width: Math.round(30 * glassRoot.d); height: width
                        MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(20 * glassRoot.d); color: IrisStyle.text }
                    }
                }
            }
        }
        IrisGlassEdge { anchors.fill: parent; visible: (IrisStyle.glassy || IrisStyle.edgeLit) && shown; radius: pane.radius }
    }
    Caption {
        glyph: IrisStyle.glassy ? "blur_on" : "crop_square"
        text: !IrisStyle.glassy ? Translation.tr("Off: solid material")
            : (glassRoot.mode === "off" ? Translation.tr("Lume frost") + " · " : "")
                + Translation.tr("Tint %1% · frost %2%").arg(Math.round(IrisStyle.glassTint * 100)).arg(Math.round(IrisStyle.glassBlurAmount * 100))
                + (glassRoot.mode === "compositor" ? " · " + Translation.tr("Blur previews as Glass") : "")
    }
}
