pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.iris.style

Rectangle {
    property real value: 0.6
    property color tint: IrisStyle.fillStrong
    Layout.fillWidth: true
    implicitHeight: Math.round(6 * IrisStyle.density)
    radius: height / 2
    color: IrisStyle.fill
    Rectangle { width: parent.width * parent.value; height: parent.height; radius: height / 2; color: parent.tint }
}
