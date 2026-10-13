pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.iris.style

// A level in a preview: a bar, or under a plate Design (AIRISU) a row of steps lit as far as it goes, as its meters are.
Rectangle {
    id: level
    property real value: 0.6
    property color tint: IrisStyle.fillStrong
    readonly property bool stepped: IrisStyle.plateSelection
    Layout.fillWidth: true
    implicitHeight: Math.round((level.stepped ? 8 : 6) * IrisStyle.density)
    radius: IrisStyle.capsule(height)
    color: level.stepped ? "transparent" : IrisStyle.fill
    Rectangle { visible: !level.stepped; width: parent.width * parent.value; height: parent.height; radius: height / 2; color: parent.tint }
    Row {
        visible: level.stepped
        spacing: Math.max(1, Math.round(2 * IrisStyle.density))
        readonly property int count: Math.max(4, Math.floor((level.width + spacing) / (Math.round(5 * IrisStyle.density) + spacing)))
        Repeater {
            model: parent.count
            Rectangle {
                required property int index
                width: Math.round(5 * IrisStyle.density)
                height: level.height
                color: index < Math.round(level.value * parent.count) ? level.tint : IrisStyle.fill
                antialiasing: false
            }
        }
    }
}
