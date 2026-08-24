import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    cookieMorphing: true

    property bool showPing: false

    property real buttonPadding: 5
    implicitWidth: distroIcon.width + buttonPadding * 2
    implicitHeight: distroIcon.height + buttonPadding * 2
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
    // zzz stays transparent here — the ZzzPlate below is the only hover
    // surface; it renders a real chamfer, while this Control's own
    // background is a plain rounded Rectangle that would otherwise poke
    // out past the chamfered cut (matches CircleUtilButton.qml).
    colBackgroundHover: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    colRipple: Appearance.zzzEverywhere ? Appearance.colors.colLayer1Active
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.zzzEverywhere ? Appearance.zzz.sticker
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colSelectionHover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colSecondaryContainerActive
    // Spatial control: addresses whatever sidebar role occupies the left slot.
    toggled: ShellLayoutController.sidebarOpenAtSlot("left",
        root.QsWindow.window?.screen?.name ?? "")

    onPressed: {
        ShellLayoutController.toggleSidebarAtSlot("left",
            root.QsWindow.window?.screen?.name ?? "");
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
        target: Wallhaven
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

    ZzzPlate {
        anchors.fill: parent
        visible: Appearance.zzzEverywhere
        chamfer: (root.buttonHovered || root.toggled) ? Appearance.zzz.cutCorner * 0.7 : Appearance.zzz.cutCorner * 0.35
        fillColor: root.toggled ? Appearance.zzz.accentSoft
            : root.buttonHovered ? Appearance.zzz.sticker : "transparent"
        strokeColor: root.toggled ? "transparent"
            : root.buttonHovered ? Appearance.zzz.accentSoft : "transparent"
        strokeWidth: 1
        z: -1
    }

    CustomIcon {
        id: distroIcon
        anchors.centerIn: parent
        width: 19.5
        height: 19.5
        source: (Config.options?.bar?.topLeftIcon ?? 'distro') == 'distro' ? SystemInfo.distroIcon : `${Config.options?.bar?.topLeftIcon ?? 'distro'}-symbolic`
        colorize: true
        color: Appearance.zzzEverywhere
            ? (root.toggled ? Appearance.zzz.onAccentSoft : Appearance.zzz.ink)
            : Appearance.colors.colOnLayer0

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
            color: Appearance.zzzEverywhere ? Appearance.zzz.accent : Appearance.colors.colTertiary
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
