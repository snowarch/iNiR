pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
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
    // Blur (beta): Niri blurs what is behind the glass, windows included. The values are the Niri rows' own
    // (IrisCompositorBlur); with Niri blur off the pane keeps the window sharp behind its tint.
    readonly property bool viaNiri: IrisStyle.glassy && glassRoot.mode === "compositor" && IrisCompositorBlur.available
    readonly property bool niriBlur: glassRoot.viaNiri && IrisCompositorBlur.enabled
    // Niri's passes × offset (light 2×2, balanced 3×3, strong 4×4.5) as a share of the preview blur's reach.
    readonly property real niriAmount: ({ light: 0.25, balanced: 0.55, strong: 0.95 })[IrisCompositorBlur.strength] ?? 0.55
    readonly property real niriSaturation: Math.max(-1, Math.min(1, (IrisCompositorBlur.saturation - 1) / 1.5))
    property real t: 0
    Loop on t { running: glassRoot.playing; rest: 600 }
    // What is behind the pane under Niri: the wallpaper and a window, sharp. The pane samples it.
    Item {
        id: behind
        anchors.fill: parent
        z: -1
        visible: glassRoot.viaNiri
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: glassRoot.viaNiri ? glassRoot.wallpaperView.textureItem : null
            live: true
        }
        Rectangle {
            id: appWindow
            x: Math.round(glassRoot.width * 0.34); y: Math.round(78 * glassRoot.d)
            width: Math.round(250 * glassRoot.d); height: Math.round(136 * glassRoot.d)
            radius: IrisStyle.radiusTile
            color: IrisStyle.surfaceHighOpaque
            Rectangle { x: 0; y: 0; width: Math.round(64 * glassRoot.d); height: parent.height; topLeftRadius: parent.radius; bottomLeftRadius: parent.radius; color: IrisStyle.surfaceOpaque }
            Column {
                x: Math.round(78 * glassRoot.d); y: Math.round(14 * glassRoot.d)
                spacing: Math.round(8 * glassRoot.d)
                Rectangle { width: Math.round(90 * glassRoot.d); height: Math.round(8 * glassRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.text }
                Rectangle { width: Math.round(150 * glassRoot.d); height: Math.round(6 * glassRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.muted }
                Rectangle { width: Math.round(120 * glassRoot.d); height: Math.round(6 * glassRoot.d); radius: IrisStyle.radiusMicro; color: IrisStyle.muted }
                Rectangle { width: Math.round(158 * glassRoot.d); height: Math.round(34 * glassRoot.d); radius: IrisStyle.radiusRow; color: IrisStyle.accent }
            }
        }
    }
    ClippingRectangle {
        id: pane
        width: Math.round(300 * glassRoot.d)
        height: Math.round(170 * glassRoot.d)
        x: Math.round(24 * glassRoot.d + (glassRoot.width - width - 48 * glassRoot.d) * glassRoot.t)
        y: Math.round(28 * glassRoot.d)
        radius: IrisStyle.radiusSheet
        color: IrisStyle.glassy ? "transparent" : IrisStyle.bodySurface
        // Edges › Style Line: the rim a real body wears, in the same colour and width.
        border.width: IrisStyle.rim.a > 0 ? IrisStyle.edgeWidth : 0
        border.color: IrisStyle.rim
        ShaderEffectSource {
            id: paneSource
            x: -pane.x; y: -pane.y
            width: glassRoot.width; height: glassRoot.height
            visible: false
            sourceItem: !IrisStyle.glassy ? null : glassRoot.viaNiri ? behind : glassRoot.wallpaperView.textureItem
            live: true
        }
        MultiEffect {
            anchors.fill: paneSource
            visible: IrisStyle.glassy
            source: paneSource
            blurEnabled: glassRoot.viaNiri ? glassRoot.niriBlur : true
            blur: glassRoot.viaNiri ? glassRoot.niriAmount : IrisStyle.glassBlurAmount
            blurMax: IrisStyle.glassBlurMax
            saturation: glassRoot.viaNiri ? (glassRoot.niriBlur ? glassRoot.niriSaturation : 0) : IrisStyle.glassSaturation
        }
        // Niri's grain: one noise cell, tiled.
        Image {
            anchors.fill: parent
            visible: glassRoot.niriBlur && IrisCompositorBlur.noise > 0
            opacity: Math.min(1, IrisCompositorBlur.noise * 5)
            source: visible ? Quickshell.shellPath("assets/textures/grain.png") : ""
            fillMode: Image.Tile
            smooth: false
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
        glyph: glassRoot.viaNiri ? "blur_on" : IrisStyle.glassy ? "wallpaper" : "crop_square"
        // On the Edges page the head names the edge; on Glass, what the glass lies over.
        text: glassRoot.group === "Edges"
            ? (IrisStyle.edgeLit ? Translation.tr("Lit edges, like glass catching the light")
                : IrisStyle.rim.a > 0 ? Translation.tr("A %1 px line round every surface").arg(IrisStyle.edgeWidth)
                : IrisStyle.edgeStyle === "line" ? Translation.tr("No line: Lines is at 0 %")
                : Translation.tr("No edge line"))
            : glassRoot.viaNiri ? Translation.tr("Blur over your windows")
            : IrisStyle.glassy ? Translation.tr("Glass over your wallpaper") : Translation.tr("Solid")
    }
}
