import QtQuick
import Quickshell
import qs.modules.waffle.looks

Item {
    id: root
    anchors.centerIn: parent
    required property Item realContentItem
    property alias radius: realContent.radius
    property real verticalPadding: 8
    property real horizontalPadding: 10
    implicitWidth: realContent.implicitWidth + (Looks.glassActive ? 6 : 4)
    implicitHeight: realContent.implicitHeight + (Looks.glassActive ? 6 : 4)

    WAmbientShadow {
        target: realContent
    }
    
    Rectangle {
        id: realContent
        z: 1
        anchors.centerIn: parent
        implicitWidth: root.realContentItem.implicitWidth + root.horizontalPadding * 2
        implicitHeight: root.realContentItem.implicitHeight + root.verticalPadding * 2
        color: Looks.colors.tooltipSurface
        radius: Looks.radius.medium
        border.width: Looks.glassActive ? 1 : 0
        border.color: Looks.colors.tooltipBorder

        children: [root.realContentItem]
    }
}
