import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    required property string iconName
    property bool separateLightDark: false
    property bool tryCustomIcon: true
    property bool monochrome: Config.options?.waffles?.bar?.monochromeIcons ?? false
    readonly property var currentScreen: root.QsWindow?.window?.screen ?? null
    
    property real implicitSize: Looks.scaledBar(Config.options?.waffles?.bar?.iconSize ?? 26, currentScreen)
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Kirigami.Icon {
        id: iconWidget
        anchors.fill: parent
        animated: true
        roundToIconSize: true
        fallback: root.iconName
        source: root.tryCustomIcon ? `${Looks.iconsPath}/${root.iconName}${!root.separateLightDark ? "" : Looks.dark ? "-dark" : "-light"}.svg` : fallback
    }

    Loader {
        active: root.monochrome
        anchors.fill: iconWidget
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false
                anchors.fill: parent
                source: iconWidget
                desaturation: 0.8
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Looks.colors.accent, 0.9)
            }
        }
    }
}
