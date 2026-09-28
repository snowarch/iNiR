pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

Rectangle {
    id: root

    property int count: 0
    property real size: Math.round(17 * IrisStyle.density)

    visible: root.count > 0
    height: root.size
    width: Math.max(root.size, label.implicitWidth + root.size * 0.7)
    radius: height / 2
    color: IrisStyle.badge
    border.width: Math.max(1, root.size * 0.07)
    border.color: IrisStyle.bodySurface

    IrisText {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(root.size * 0.03)
        text: root.count > 99 ? "99+" : root.count
        color: IrisStyle.onBadge
        font.family: IrisStyle.fontNumbers
        font.features: ({ "tnum": 1 })
        font.pixelSize: root.size * 0.62
        font.weight: IrisStyle.weight(Font.Bold)
    }
}
