pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root

    property bool selected: false
    property string chipIcon: ""
    property bool monospace: false
    property real minimumWidth: 0
    property color surfaceColor: Appearance.colors.colLayer1

    implicitWidth: Math.max(root.minimumWidth,
        label.implicitWidth
            + (icon.visible ? icon.implicitWidth + (Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 6) : 0)
            + (Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal * 2 : 24))
    implicitHeight: Appearance.regaliaEverywhere ? Appearance.regalia.compactControlHeight : 30
    buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : root._zzz ? Appearance.zzz.controlRadius : height / 2
    buttonRadiusPressed: buttonRadius
    toggled: root.selected

    Accessible.name: root.text
    Accessible.role: Accessible.Button
    Accessible.checked: root.selected

    readonly property bool _zzz: Appearance.zzzEverywhere

    readonly property color _restFill: Appearance.regaliaEverywhere
        ? (root.selected ? Appearance.regalia.primaryPlate : Appearance.regalia.controlPlate)
        : root.selected ? Appearance.colors.colPrimaryContainer
        : ColorUtils.mix(root.surfaceColor, Appearance.colors.colOnLayer1, 0.945)
    readonly property color _hoverFill: Appearance.regaliaEverywhere
        ? (root.selected ? Appearance.regalia.primaryPlateHover : Appearance.regalia.controlPlateHover)
        : root.selected ? Appearance.colors.colPrimaryContainerHover
        : ColorUtils.mix(root.surfaceColor, Appearance.colors.colOnLayer1, 0.88)

    colBackground: root._restFill
    colBackgroundHover: root._hoverFill
    colBackgroundToggled: root._restFill
    colBackgroundToggledHover: root._hoverFill

    readonly property color _ink: ColorUtils.ensureReadable(
        root.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1,
        root.buttonHovered ? root._hoverFill : root._restFill, 4.5)

    readonly property color _border: Appearance.regaliaEverywhere ? "transparent"
        : root.selected ? "transparent"
        : (root.buttonHovered ? Appearance.colors.colOutline : Appearance.colors.colOutlineVariant)

    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.visualFocus ? (Appearance.regaliaEverywhere ? 1 : 2)
            : (root._border === "transparent" ? 0 : 1)
        border.color: root.visualFocus
            ? Appearance.colors.colPrimary : root._border
    }

    contentItem: Row {
        anchors.centerIn: parent
        spacing: icon.visible ? (Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 6) : 0

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.chipIcon.length > 0
            text: root.chipIcon
            iconSize: 15
            color: root._ink

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: root.monospace ? Appearance.font.family.monospace
                : Appearance.font.family.main
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: root._ink

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }
    }
}
