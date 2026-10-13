pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.iris.components
import qs.modules.iris.style

Rectangle {
    id: root

    property var links: []
    // Every link opens on its identity mark, as every group row does: one grammar on the page.
    property bool tinted: true

    Layout.fillWidth: true
    implicitHeight: linkColumn.implicitHeight
    radius: IrisStyle.radiusTile
    color: IrisStyle.fieldChamfer ? "transparent" : IrisStyle.readingCard
    IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: IrisStyle.readingCard }

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
