import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root

    property bool vertical: Config.options?.bar?.vertical ?? false
    property bool isMaterial: (Config.options?.bar?.m3?.cornerStyle ?? 0) === 3
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""

    implicitWidth: 32
    implicitHeight: 32
    buttonRadius: Appearance.rounding.full

    colBackground: isMaterial ? M3Palette.primaryContainer : "transparent"
    colBackgroundHover: isMaterial ? M3Palette.primaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: isMaterial ? M3Palette.primaryContainerActive : Appearance.colors.colLayer1Active
    colBackgroundToggled: isMaterial ? M3Palette.secondaryContainer : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: isMaterial ? M3Palette.secondaryContainerHover : Appearance.colors.colSecondaryContainerHover
    colRippleToggled: isMaterial ? M3Palette.secondaryContainerActive : Appearance.colors.colSecondaryContainerActive
    toggled: ShellLayoutController.sidebarOpenAtSlot("right", screenName)

    onPressed: ShellLayoutController.toggleSidebarAtSlot("right", screenName)

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.toggled ? "right_panel_close" : "right_panel_open"
        iconSize: root.vertical ? 22 : 20
        color: (Config.options?.bar?.m3?.cornerStyle ?? 0) !== 3
            ? Appearance.colors.colPrimary
            : root.toggled
                ? M3Palette.pillInk("sidebarToggle")
                : M3Palette.pillInk("rightSidebarButton")
    }
}
