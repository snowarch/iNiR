pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.pieces
import qs.modules.iris.preview.parts

PreviewScene {
    id: cardRoot
    readonly property real cardWidth: Number(cardRoot.opt("iris.appearance.surfaces.cards.width", 0)) > 0
        ? Number(cardRoot.opt("iris.appearance.surfaces.cards.width", 0)) * cardRoot.d : Math.round(340 * cardRoot.d)
    readonly property bool header: cardRoot.opt("iris.appearance.surfaces.cards.header", true)
    readonly property bool devices: cardRoot.opt("iris.appearance.surfaces.cards.devices", true)
    readonly property bool mixer: cardRoot.opt("iris.appearance.surfaces.cards.mixer", true)
    readonly property real naturalWidth: cardRoot.cardWidth + Math.round(120 * cardRoot.d)
    readonly property real naturalHeight: cardPlate.y + cardPlate.height + Math.round(24 * cardRoot.d)
    Rectangle {
        id: origin
        anchors.horizontalCenter: parent.horizontalCenter
        y: IrisFrame.band
        width: IrisFrame.islandBand; height: width
        radius: IrisStyle.pieceRadius(width)
        color: IrisStyle.bodySurface
        MaterialSymbol { anchors.centerIn: parent; text: "volume_up"; fill: 1; iconSize: Math.round(18 * cardRoot.d); color: IrisStyle.text }
    }
    Plate {
        id: cardPlate
        surface: "cards"
        own: IrisStyle.identity.sky
        anchors.horizontalCenter: parent.horizontalCenter
        y: origin.y + origin.height + IrisStyle.weld
        width: cardRoot.cardWidth
        height: cardColumn.implicitHeight + Math.round(32 * cardRoot.d)
        ColumnLayout {
            id: cardColumn
            x: Math.round(16 * cardRoot.d); y: Math.round(16 * cardRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(12 * cardRoot.d)
            RowLayout {
                visible: cardRoot.header
                spacing: Math.round(10 * cardRoot.d)
                Rectangle {
                    implicitWidth: Math.round(30 * cardRoot.d); implicitHeight: implicitWidth
                    radius: IrisStyle.iconRadius(width); color: IrisStyle.identity.sky
                    MaterialSymbol { anchors.centerIn: parent; text: "volume_up"; fill: 1; iconSize: Math.round(16 * cardRoot.d); color: IrisStyle.onTint }
                }
                ColumnLayout {
                    spacing: 0
                    IrisText { text: Translation.tr("Sound"); font.weight: IrisStyle.weight(Font.DemiBold) }
                    IrisText { text: Audio.sink?.description ?? Translation.tr("Speakers"); color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeMeta }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * cardRoot.d)
                MaterialSymbol { text: "volume_up"; iconSize: Math.round(18 * cardRoot.d); color: IrisStyle.text }
                Level { value: Math.min(1, Audio.value ?? 0.6); tint: IrisStyle.text }
                IrisText { text: Math.round(Math.min(1, Audio.value ?? 0.6) * 100); font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.DemiBold) }
            }
            Row {
                visible: cardRoot.devices
                spacing: Math.round(6 * cardRoot.d)
                Repeater {
                    model: [Translation.tr("Speakers"), Translation.tr("Headphones")]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: devLabel.implicitWidth + Math.round(20 * cardRoot.d); height: Math.round(26 * cardRoot.d)
                        radius: height / 2
                        color: index === 0 ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fillQuiet
                        IrisText { id: devLabel; anchors.centerIn: parent; text: parent.modelData; color: parent.index === 0 ? IrisStyle.accent : IrisStyle.subtext; font.pixelSize: IrisStyle.typeMeta }
                    }
                }
            }
            Repeater {
                model: cardRoot.mixer ? (TaskbarApps.apps ?? []).filter(app => app && !app.separator && String(app.appId ?? "").length > 0 && app.appId !== "SEPARATOR").slice(0, 2) : []
                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Math.round(10 * cardRoot.d)
                    SmartAppIcon { implicitSize: Math.round(20 * cardRoot.d); icon: IrisPieces.appIcon(parent.modelData.appId); fallback: "application-x-executable" }
                    Level { value: parent.index === 0 ? 0.8 : 0.45 }
                }
            }
        }
    }
}
