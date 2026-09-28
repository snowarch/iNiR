pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.iris.style

Rectangle {
    id: root

    property var links: []
    property bool tinted: false

    Layout.fillWidth: true
    implicitHeight: linkColumn.implicitHeight
    radius: IrisStyle.radiusTile
    color: IrisStyle.readingCard

    Column {
        id: linkColumn
        width: parent.width
        Repeater {
            model: root.links
            IrisLinkRow {
                required property var modelData
                required property int index
                entry: modelData
                tinted: root.tinted
                last: index === root.links.length - 1
            }
        }
    }
}
