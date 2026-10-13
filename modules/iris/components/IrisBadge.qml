pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

Rectangle {
    id: root

    property int count: 0
    property real size: Math.round(17 * IrisStyle.density)
    readonly property string figure: root.count > 99 ? "99+" : String(root.count)
    // A Design may print the count its own way (AIRISU: a station number); the count and where it sits stay the engine's.
    readonly property bool skinned: badgeSkin.active

    visible: root.count > 0
    implicitHeight: root.skinned ? root.implicitWidth : root.size
    implicitWidth: Math.max(root.size, label.implicitWidth + root.size * 0.7)
    height: root.implicitHeight
    width: root.implicitWidth
    // A Design that cuts its bodies (AIRISU) makes the count a square sticker: no ring, the number in its wide face.
    radius: IrisStyle.fieldChamfer ? 0 : height / 2
    color: root.skinned ? "transparent" : IrisStyle.badge
    border.width: root.skinned || IrisStyle.fieldChamfer ? 0 : Math.max(1, root.size * 0.07)
    border.color: IrisStyle.bodySurface

    IrisSkin {
        id: badgeSkin
        part: "badge"
        host: root
    }

    IrisText {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(root.size * 0.03)
        visible: !root.skinned
        text: root.figure
        color: IrisStyle.inkOnBadge
        font.family: IrisStyle.fontNumbers
        font.features: ({ "tnum": 1 })
        font.pixelSize: root.size * 0.62
        font.weight: IrisStyle.weight(Font.Bold)
    }
}
