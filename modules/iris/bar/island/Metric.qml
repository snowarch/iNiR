pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Row {
    id: metric
    property string value: ""
    property string unit: ""
    property real pixelSize: IrisStyle.typeHeadline
    property int weight: Font.DemiBold
    property color color: IrisStyle.text
    IrisText {
        id: metricValue
        text: metric.value
        color: metric.color
        font.pixelSize: metric.pixelSize
        font.family: IrisStyle.fontNumbers
        font.weight: metric.weight
        font.features: ({ "tnum": 1 })
        font.letterSpacing: Math.round(-metric.pixelSize * 0.015)
    }
    IrisText {
        visible: metric.unit.length > 0
        anchors.baseline: metricValue.baseline
        leftPadding: metric.pixelSize * 0.06
        text: metric.unit
        color: IrisStyle.secondaryOf(metric.color)
        font.pixelSize: Math.max(9, metric.pixelSize * 0.6)
        font.weight: IrisStyle.weight(Font.DemiBold)
    }
}
