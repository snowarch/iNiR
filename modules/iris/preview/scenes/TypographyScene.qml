pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: typeRoot
    readonly property real naturalWidth: Math.round(560 * typeRoot.d)
    readonly property real naturalHeight: Math.round(280 * typeRoot.d)
    Plate {
        anchors.centerIn: parent
        width: Math.round(480 * typeRoot.d)
        height: Math.round(216 * typeRoot.d)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(24 * typeRoot.d)
            spacing: Math.round(6 * typeRoot.d)
            IrisText { text: Translation.tr("A little room to breathe"); font.family: IrisStyle.fontTitle; font.pixelSize: IrisStyle.typeTitleLarge; font.weight: IrisStyle.weight(Font.Medium) }
            IrisClock { pixelSize: 56 * IrisStyle.typeScale; separatorColor: IrisStyle.secondaryAccent }
            Rectangle { Layout.fillWidth: true; height: 1; color: IrisStyle.hairline }
            RowLayout {
                Layout.fillWidth: true
                IrisText { text: Translation.tr("Words, figures, one family"); color: IrisStyle.subtext }
                Item { Layout.fillWidth: true }
                IrisText { text: "Aa 0123"; color: IrisStyle.accent; font.pixelSize: IrisStyle.typeTitle }
            }
        }
    }
    Caption { glyph: "text_fields"; text: Translation.tr("Your typefaces, weight and text size") }
}
