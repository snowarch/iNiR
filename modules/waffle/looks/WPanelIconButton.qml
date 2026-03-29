import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.bar

WButton {
    id: root

    readonly property var currentScreen: root.QsWindow?.window?.screen ?? null
    property alias iconName: iconContent.icon
    property alias monochrome: iconContent.monochrome
    implicitWidth: Looks.scaled(40, currentScreen)
    implicitHeight: Looks.scaled(40, currentScreen)

    contentItem: FluentIcon {
        id: iconContent
        anchors.centerIn: parent
        implicitSize: Looks.scaled(18, root.currentScreen)
        icon: root.iconName
    }
}
