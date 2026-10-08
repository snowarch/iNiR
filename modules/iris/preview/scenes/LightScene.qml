pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: lightRoot
    readonly property real naturalWidth: Math.round(620 * lightRoot.d)
    readonly property real naturalHeight: Math.round(290 * lightRoot.d)
    readonly property string aura: String(lightRoot.opt("iris.appearance.aura", "subtle"))
    readonly property real reach: Number(lightRoot.opt("iris.appearance.theme.lightReach", 100))
    readonly property real glow: Number(lightRoot.opt("iris.appearance.theme.glow", 0))
    readonly property real bodyWidth: Math.round(236 * lightRoot.d)
    readonly property real bodyHeight: Math.round(176 * lightRoot.d)
    readonly property real gutter: Math.round((lightRoot.width - 2 * lightRoot.bodyWidth) / 3)
    property real t: 0
    Loop on t { running: lightRoot.playing }
    readonly property real grown: IrisFrame.islandBand + (lightRoot.bodyHeight - IrisFrame.islandBand) * lightRoot.t
    readonly property real wide: IrisFrame.islandBand * 2 + (lightRoot.bodyWidth - IrisFrame.islandBand * 2) * lightRoot.t

    LitBody {
        x: lightRoot.gutter + (lightRoot.bodyWidth - width) / 2
        y: Math.round(26 * lightRoot.d)
        width: lightRoot.wide
        height: lightRoot.grown
        restWidth: lightRoot.bodyWidth
        restHeight: lightRoot.bodyHeight
        progress: lightRoot.t
        light: IrisStyle.identity.sky
        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(2 * lightRoot.d)
            RowLayout {
                spacing: Math.round(6 * lightRoot.d)
                MaterialSymbol { text: "partly_cloudy_day"; fill: 1; iconSize: Math.round(18 * lightRoot.d); color: IrisStyle.identity.sky }
                IrisText { text: Translation.tr("Weather"); font.weight: IrisStyle.weight(Font.DemiBold) }
            }
            IrisText {
                text: "18°"
                font.family: IrisStyle.fontNumbers
                font.weight: IrisStyle.figureWeight
                font.pixelSize: 40 * IrisStyle.typeScale
            }
            IrisText { text: Translation.tr("Partly cloudy"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
            Item { Layout.fillHeight: true }
        }
    }
    LitBody {
        x: 2 * lightRoot.gutter + lightRoot.bodyWidth + (lightRoot.bodyWidth - width) / 2
        y: Math.round(26 * lightRoot.d)
        width: lightRoot.wide
        height: lightRoot.grown
        restWidth: lightRoot.bodyWidth
        restHeight: lightRoot.bodyHeight
        progress: lightRoot.t
        light: IrisStyle.wallpaperLight
        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(10 * lightRoot.d)
            RowLayout {
                spacing: Math.round(6 * lightRoot.d)
                MaterialSymbol { text: "tune"; iconSize: Math.round(18 * lightRoot.d); color: IrisStyle.text }
                IrisText { text: Translation.tr("Control Center"); font.weight: IrisStyle.weight(Font.DemiBold) }
            }
            RowLayout {
                spacing: Math.round(8 * lightRoot.d)
                Repeater {
                    model: ["wifi", "bluetooth", "dark_mode"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        implicitWidth: Math.round(38 * lightRoot.d)
                        implicitHeight: implicitWidth
                        radius: IrisStyle.pieceRadius(implicitWidth)
                        color: index === 0 ? IrisStyle.accent : IrisStyle.fill
                        MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(18 * lightRoot.d); color: parent.index === 0 ? IrisStyle.inkOnAccent : IrisStyle.text }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.round(26 * lightRoot.d)
                radius: height / 2
                color: IrisStyle.fill
                Rectangle { width: parent.width * 0.62; height: parent.height; radius: height / 2; color: IrisStyle.fillActive }
            }
            Item { Layout.fillHeight: true }
        }
    }
    Caption {
        glyph: lightRoot.aura === "off" ? "light_off" : "light_mode"
        text: (lightRoot.aura === "off" ? Translation.tr("Light off")
            : (lightRoot.aura === "vivid" ? Translation.tr("Vivid") : Translation.tr("Subtle")) + " · " + Translation.tr("reach %1%").arg(Math.round(lightRoot.reach)))
            + " · " + (lightRoot.glow > 0 ? Translation.tr("shadows glow %1%").arg(Math.round(lightRoot.glow)) : Translation.tr("dark shadows"))
    }
}
