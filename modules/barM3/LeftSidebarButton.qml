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
    property bool showPing: false
    property bool vertical: Config.options.bar.vertical
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property bool animeEnabled: Config.options.policies.weeb !== 0
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    property real buttonPadding: 5

    visible: aiChatEnabled || translatorEnabled || animeEnabled

    implicitWidth: 32
    implicitHeight: 32

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? M3Palette.primaryContainer : "transparent"
    colBackgroundHover: isMaterial ? M3Palette.primaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: isMaterial ? M3Palette.primaryContainerActive : Appearance.colors.colLayer1Active
    colBackgroundToggled: isMaterial ? M3Palette.secondaryContainer : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: isMaterial ? M3Palette.secondaryContainerHover : Appearance.colors.colSecondaryContainerHover
    colRippleToggled: isMaterial ? M3Palette.secondaryContainerActive : Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.sidebarLeftOpen
        && GlobalStates.sidebarLeftPresentationOutput === (root.QsWindow.window?.screen?.name ?? "")

    onPressed: {
        GlobalStates.toggleSidebarLeft(root.QsWindow.window?.screen?.name ?? "");
    }

    Connections {
        target: Ai
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }
    Connections {
        target: Booru
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            root.showPing = false;
        }
    }

    CustomIcon {
        id: distroIcon
        anchors.centerIn: parent
        width: root.isMaterial ? (root.vertical ? 24 : 22) : 19.5
        height: root.isMaterial ? (root.vertical ? 24 : 22) : 19.5
        // Config.options.custom.distroIcon/colorizeIcon do not exist in iNiR;
        // ported to the same source iNiR's own LeftSidebarButton uses.
        source: (Config.options?.bar?.topLeftIcon ?? "distro") === "distro"
            ? SystemInfo.distroIcon
            : `${Config.options?.bar?.topLeftIcon ?? "distro"}-symbolic`
        colorize: true
        color: (Config.options?.bar?.m3?.cornerStyle ?? 0) !== 3
            ? Appearance.colors.colPrimary
            : root.toggled
                ? M3Palette.pillInk("sidebarToggle")
                : M3Palette.pillInk("leftSidebarButton")

        Rectangle {
            opacity: root.showPing ? 1 : 0
            visible: opacity > 0
            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: -2
                rightMargin: -2
            }
            implicitWidth: 8
            implicitHeight: 8
            radius: Appearance.rounding.full
            color: Appearance.colors.colTertiary
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
