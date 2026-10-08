pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Row {
    id: dateMark
    property real pixelSize: IrisStyle.typeMeta
    property color dayColor: IrisStyle.secondaryAccent
    property color inkColor: IrisStyle.muted
    spacing: Math.round(dateMark.pixelSize * 0.3)
    IrisText {
        id: weekdayText
        text: Translation.locale.toString(DateTime.clock.date, "ddd").replace(/\.$/, "")
        color: dateMark.inkColor
        font.pixelSize: dateMark.pixelSize * 0.92
        font.weight: IrisStyle.weight(Font.Medium)
    }
    IrisText {
        anchors.baseline: weekdayText.baseline
        text: Translation.locale.toString(DateTime.clock.date, "d")
        color: dateMark.dayColor
        font.pixelSize: dateMark.pixelSize
        font.family: IrisStyle.fontNumbers
        font.weight: IrisStyle.weight(Font.Bold)
        font.features: ({ "tnum": 1 })
    }
}
