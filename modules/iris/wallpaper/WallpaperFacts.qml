pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// An entry's facts in a line: what it is, its size, how liked it is, when; figures in the figure face.
Flow {
    id: root

    required property var engine
    property var entry: null
    property color ink: IrisStyle.textSecondary
    readonly property real d: IrisStyle.density

    spacing: Math.round(14 * root.d)

    Repeater {
        model: root.engine.facts(root.entry)
        Row {
            id: fact
            required property var modelData
            spacing: Math.round(4 * root.d)
            height: Math.round(20 * root.d)
            MaterialSymbol {
                visible: String(fact.modelData.glyph ?? "").length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: String(fact.modelData.glyph ?? "")
                fill: 1
                iconSize: Math.round(14 * root.d)
                color: root.ink
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                text: String(fact.modelData.label ?? "")
                color: root.ink
                font.family: fact.modelData.figure ? IrisStyle.fontNumbers : IrisStyle.fontMain
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(fact.modelData.figure ? Font.Bold : Font.Medium)
            }
        }
    }
}
