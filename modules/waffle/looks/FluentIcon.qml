import QtQuick
import org.kde.kirigami as Kirigami
import qs.modules.common
import qs.modules.waffle.looks

Kirigami.Icon {
    id: root
    required property string icon
    property bool filled: false
    // Missing filled variants render blank without warning.
    readonly property bool effectiveFilled: filled && WIcons.hasFilledVariant(root.icon)
    property alias monochrome: root.isMask
    // Should be 16, but it appears the icons have some padding, 
    // Unlike the Windows-only Segoe UI icons, the open source FluentUI ones are hella small
    property int implicitSize: 20
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    source: icon === "" ? "" : `${Looks.iconsPath}/${root.icon}${effectiveFilled ? "-filled" : ""}.svg`
    fallback: root.icon
    roundToIconSize: true
    color: Looks.colors.fg
    isMask: true
    animated: true
}
