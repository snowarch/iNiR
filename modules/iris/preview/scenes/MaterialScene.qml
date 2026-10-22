pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// The material is what every surface is made of: the Island, a card and a side panel at once, each glass or solid the way
// the real surface resolves it (IrisStyle.surfaceGlass, so a per-surface override shows here too).
PreviewScene {
    id: mat
    subject: Qt.rect(matCard.x, matCard.y, matCard.width, matCard.height)
    // Laid tight, so the bodies read at the head's size.
    readonly property real naturalWidth: Math.round(460 * mat.d)
    readonly property real naturalHeight: Math.round(230 * mat.d)
    narrowest: Math.round(380 * mat.d)
    lowest: Math.round(200 * mat.d)
    // Re-reads when a per-surface row changes.
    readonly property string cardsMaterial: String(mat.opt("iris.appearance.surfaces.cards.material", ""))
    readonly property string panelsMaterial: String(mat.opt("iris.appearance.surfaces.panels.material", ""))

    // One body: frost over the wallpaper (the host's decoded texture) or the solid paper, as its surface resolves, and the
    // shadow a floating body really casts (Shadows moves it).
    component Body: Item {
        id: body
        required property PreviewScene scene
        required property string surface
        property string override: ""
        property int fallbackRadius: IrisStyle.radiusSheet
        default property alias content: host.data
        readonly property string resolved: { body.override; return IrisStyle.surfaceGlass(body.surface) }
        readonly property bool glass: body.resolved === "solid" ? false : body.resolved === "inherit" ? IrisStyle.glassy : true
        readonly property real radius: IrisStyle.surfaceRadius(body.surface, body.fallbackRadius)
        RectangularShadow {
            anchors.fill: plate
            radius: plate.radius
            offset.y: Math.round(3 * body.scene.d)
            blur: Math.round(16 * body.scene.d)
            color: IrisStyle.shadow
        }
        ClippingRectangle {
            id: plate
            anchors.fill: parent
            radius: body.radius
            // A chamfered Design (AIRISU) cuts the body by its die, so a preview wears the same 45° corners as the shell.
            layer.enabled: IrisStyle.fieldChamfer
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: plateDie
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            IrisCutPlate {
                id: plateDie
                anchors.fill: parent
                visible: false
                layer.enabled: IrisStyle.fieldChamfer
                cutLength: Math.max(2, Math.min(IrisStyle.chamferCut, Math.round(Math.min(width, height) / 4)))
                color: "white" // iris-literal: a mask, never shown
            }
            color: body.glass ? "transparent" : IrisStyle.bodySurface
            border.width: !body.glass && IrisStyle.rim.a > 0 ? 1 : 0
            border.color: IrisStyle.rim
            ShaderEffectSource {
                id: frostSource
                x: -body.x; y: -body.y
                width: body.scene.width; height: body.scene.height
                visible: false
                sourceItem: body.glass ? body.scene.wallpaperView.textureItem : null
                live: true
            }
            MultiEffect {
                anchors.fill: frostSource
                visible: body.glass
                source: frostSource
                blurEnabled: true
                blur: IrisStyle.glassBlurAmount
                blurMax: IrisStyle.glassBlurMax
                saturation: IrisStyle.glassSaturation
            }
            Rectangle { anchors.fill: parent; visible: body.glass; color: ColorUtils.applyAlpha(IrisStyle.surfaceOpaque, IrisStyle.glassTint) }
            Item { id: host; anchors.fill: parent }
            IrisGlassEdge { anchors.fill: parent; visible: (body.glass || IrisStyle.edgeLit) && shown; radius: plate.radius }
        }
    }

    IslandPill {
        id: matIsland
        anchors.horizontalCenter: parent.horizontalCenter
        y: IrisFrame.band
    }

    Body {
        id: matCard
        scene: mat
        surface: "cards"
        override: mat.cardsMaterial
        fallbackRadius: IrisStyle.radiusPlate
        x: Math.round(24 * mat.d)
        y: matIsland.y + matIsland.height + Math.round(16 * mat.d)
        width: Math.round(216 * mat.d)
        height: cardColumn.implicitHeight + 2 * cardColumn.pad
        ColumnLayout {
            id: cardColumn
            readonly property int pad: IrisStyle.concentricPad(matCard.radius, 14 * mat.d)
            x: cardColumn.pad; y: cardColumn.pad
            width: parent.width - 2 * cardColumn.pad
            spacing: Math.round(10 * mat.d)
            RowLayout {
                spacing: Math.round(10 * mat.d)
                Rectangle {
                    implicitWidth: Math.round(36 * mat.d); implicitHeight: implicitWidth
                    radius: IrisStyle.iconRadius(width); color: IrisStyle.fill
                    MaterialSymbol { anchors.centerIn: parent; text: "music_note"; fill: 1; iconSize: Math.round(18 * mat.d); color: IrisStyle.textSecondary }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText { Layout.fillWidth: true; elide: Text.ElideRight; text: Translation.tr("Now playing"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeLabel }
                    IrisText { Layout.fillWidth: true; elide: Text.ElideRight; text: Translation.tr("Artist"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IrisStyle.hairline }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(2, Math.round(4 * mat.d))
                radius: IrisStyle.capsule(height)
                color: IrisStyle.fill
                Rectangle { width: parent.width * 0.42; height: parent.height; radius: parent.radius; color: IrisStyle.accent }
            }
            IrisControlPlate {
                id: matControls
                Layout.alignment: Qt.AlignHCenter
                controlHeight: Math.round(30 * mat.d)
                Row {
                    spacing: matControls.framed ? Math.round(4 * mat.d) : Math.round(18 * mat.d)
                    Repeater {
                        model: ["skip_previous", "pause", "skip_next"]
                        Item {
                            required property string modelData
                            width: Math.round(30 * mat.d); height: width
                            MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(20 * mat.d); color: IrisStyle.text }
                        }
                    }
                }
            }
        }
    }

    Body {
        id: matPanel
        scene: mat
        surface: "panels"
        override: mat.panelsMaterial
        fallbackRadius: IrisStyle.radiusPanel
        anchors.right: parent.right
        anchors.rightMargin: IrisFrame.band + IrisFrame.bodyAir + Math.round(12 * mat.d)
        // Level with the card: in a miniature the Island would otherwise reach over the panel's shoulder.
        y: matCard.y
        width: Math.round(140 * mat.d)
        height: parent.height - y - IrisFrame.band - IrisFrame.bodyAir
        ColumnLayout {
            readonly property int pad: IrisStyle.concentricPad(matPanel.radius, 12 * mat.d)
            x: pad; y: pad
            width: parent.width - 2 * pad
            height: parent.height - 2 * pad
            spacing: Math.round(8 * mat.d)
            Repeater {
                model: [["calendar_month", Translation.tr("Calendar"), IrisStyle.identity.red], ["partly_cloudy_day", Translation.tr("Weather"), IrisStyle.identity.sky], ["timer", Translation.tr("Timer"), IrisStyle.identity.orange]]
                Rectangle {
                    id: panelRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: IrisStyle.radiusCard
                    color: IrisStyle.fillQuiet
                    Rectangle {
                        id: panelMark
                        x: Math.round(8 * mat.d)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(22 * mat.d); height: width
                        radius: IrisStyle.iconRadius(width); color: panelRow.modelData[2]
                        MaterialSymbol { anchors.centerIn: parent; text: panelRow.modelData[0]; fill: 1; iconSize: Math.round(13 * mat.d); color: IrisStyle.onTint }
                    }
                    IrisText {
                        anchors.left: panelMark.right; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Math.round(8 * mat.d); anchors.rightMargin: Math.round(6 * mat.d)
                        elide: Text.ElideRight
                        text: panelRow.modelData[1]
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
            }
        }
    }

    Caption {
        glyph: "layers"
        text: Translation.tr("%1 on every surface").arg(Translation.tr(IrisStyle.materialLabel(IrisStyle.materialName)))
    }
}
