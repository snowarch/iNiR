pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root
    property Item contentItem
    property real radius: Looks.radius.large
    property alias border: borderRect
    property alias borderColor: borderRect.border.color
    property alias borderWidth: borderRect.border.width

    // Glass background support — screen coordinates for blur alignment
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080

    readonly property bool glassActive: Looks.glassActive

    implicitWidth: borderRect.implicitWidth
    implicitHeight: borderRect.implicitHeight

    WRectangularShadow {
        target: borderRect
        visible: !root.glassActive
    }

    Rectangle {
        id: borderRect
        z: 1

        color: "transparent"
        radius: root.glassActive
            ? (Appearance.angelEverywhere ? Appearance.angel.roundingLarge : Appearance.rounding.screenRounding)
            : root.radius
        border.color: root.glassActive
            ? (Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
                : Appearance.aurora.colTooltipBorder)
            : Looks.colors.bg2Border
        border.width: root.glassActive
            ? (Appearance.angelEverywhere ? Appearance.angel.panelBorderWidth : 1)
            : 1
        implicitWidth: contentItem.implicitWidth + border.width * 2
        implicitHeight: contentItem.implicitHeight + border.width * 2
        anchors.fill: contentRect
        anchors.margins: -border.width
    }

    Rectangle {
        id: contentRect
        anchors.centerIn: parent
        z: 0

        color: root.glassActive ? "transparent" : Looks.colors.bgPanelFooterBase
        implicitWidth: contentItem.implicitWidth
        implicitHeight: contentItem.implicitHeight
        layer.enabled: Appearance.effectsEnabled
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                id: contentAreaMask
                width: contentRect.width
                height: contentRect.height
                radius: borderRect.radius - borderRect.border.width
            }
        }

        // Glass background for aurora/angel styles
        GlassBackground {
            id: glassBackground
            anchors.fill: parent
            visible: root.glassActive
            radius: borderRect.radius - borderRect.border.width
            fallbackColor: Appearance.colors.colLayer0
            auroraTransparency: Appearance.angelEverywhere
                ? Appearance.angel.panelTransparentize
                : Math.max(0.12, Appearance.aurora.subSurfaceTransparentize - 0.14)
            screenX: root.screenX
            screenY: root.screenY
            screenWidth: root.screenWidth
            screenHeight: root.screenHeight
        }

        children: [glassBackground, root.contentItem]
    }
}