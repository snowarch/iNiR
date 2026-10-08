pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.iris.style

Item {
    id: body
    property color light
    property real restWidth: 0
    property real restHeight: 0
    property real progress: 1
    default property alias content: bodyContent.data
    RectangularShadow {
        anchors.fill: bodyPlate
        radius: bodyPlate.radius
        offset.y: 3 * IrisStyle.density
        blur: 16 * IrisStyle.density
        color: IrisStyle.shadow
    }
    LitPlate {
        id: bodyPlate
        anchors.fill: parent
        radius: Math.min(IrisStyle.radiusSheet, height / 2)
        light: body.light
    }
    Item {
        id: bodyContent
        readonly property real pad: IrisStyle.concentricPad(IrisStyle.radiusSheet, 14 * IrisStyle.density)
        x: bodyContent.pad
        y: bodyContent.pad
        width: body.restWidth - 2 * bodyContent.pad
        height: body.restHeight - 2 * bodyContent.pad
        opacity: IrisStyle.ramp(body.progress, 0.55, 0.45)
        visible: opacity > 0
    }
}
