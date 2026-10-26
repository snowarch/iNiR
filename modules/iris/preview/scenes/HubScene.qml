pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Community Hub: what people share, as cards to take. One of them is added while you look: its button fills and
// turns into a check.
PreviewScene {
    id: hubRoot
    readonly property real naturalWidth: Math.round(600 * hubRoot.d)
    readonly property real naturalHeight: Math.round(290 * hubRoot.d)
    narrowest: Math.round(440 * hubRoot.d)
    lowest: Math.round(230 * hubRoot.d)
    subject: Qt.rect(cards.x, cards.y, cards.width, cards.height)
    property real t: 1
    Loop on t { running: hubRoot.playing; rest: 1500 }

    Row {
        id: cards
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(12 * hubRoot.d)
        spacing: Math.round(14 * hubRoot.d)
        Repeater {
            model: [
                { glyph: "widgets", name: Translation.tr("Widget"), a: IrisStyle.identity.yellow, b: IrisStyle.identity.orange },
                { glyph: "palette", name: Translation.tr("Theme"), a: IrisStyle.identity.pink, b: IrisStyle.identity.purple },
                { glyph: "language", name: Translation.tr("Web app"), a: IrisStyle.identity.sky, b: IrisStyle.identity.indigo }
            ]
            Plate {
                id: card
                required property var modelData
                required property int index
                readonly property bool taking: card.index === 1
                width: Math.round(Math.min(170 * hubRoot.d, (hubRoot.width - 70 * hubRoot.d) / 3))
                height: Math.round(190 * hubRoot.d)
                radius: IrisStyle.radiusPlate
                Rectangle {
                    x: Math.round(8 * hubRoot.d); y: x
                    width: parent.width - 2 * x
                    height: parent.height * 0.5
                    radius: IrisStyle.radiusPlate - x
                    gradient: Gradient {
                        GradientStop { position: 0; color: card.modelData.a }
                        GradientStop { position: 1; color: card.modelData.b }
                    }
                    MaterialSymbol { anchors.centerIn: parent; text: card.modelData.glyph; fill: 1; iconSize: Math.round(30 * hubRoot.d); color: IrisStyle.onMedia }
                }
                IrisText {
                    x: Math.round(14 * hubRoot.d)
                    y: parent.height * 0.5 + Math.round(16 * hubRoot.d)
                    text: card.modelData.name
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                Rectangle {
                    id: take
                    x: Math.round(12 * hubRoot.d)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(12 * hubRoot.d)
                    width: parent.width - 2 * x
                    height: Math.round(28 * hubRoot.d)
                    radius: height / 2
                    color: IrisStyle.fill
                    clip: true
                    readonly property real done: card.taking ? hubRoot.t : 0
                    Rectangle { width: parent.width * take.done; height: parent.height; radius: height / 2; color: IrisStyle.accent }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * hubRoot.d)
                        MaterialSymbol { text: take.done > 0.98 ? "check" : "add"; iconSize: Math.round(15 * hubRoot.d); color: take.done > 0.5 ? IrisStyle.inkOnAccent : IrisStyle.text }
                        IrisText { text: take.done > 0.98 ? Translation.tr("Added") : Translation.tr("Get"); font.pixelSize: IrisStyle.typeMeta; font.weight: IrisStyle.weight(Font.DemiBold); color: take.done > 0.5 ? IrisStyle.inkOnAccent : IrisStyle.text }
                    }
                }
            }
        }
    }
    Caption {
        glyph: "storefront"
        text: Translation.tr("Shared by people who use iNiR")
    }
}
