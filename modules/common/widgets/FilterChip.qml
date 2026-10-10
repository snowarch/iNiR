pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A Material 3 filter chip: 32 px, 8 px corners, a hairline outline at rest; selected, it fills with
// secondary container and leads with a check (in place of its own icon). Other Global Styles keep
// their own plate and radius through the same tokens.
RippleButton {
    id: root

    property bool selected: false
    property string chipIcon: ""
    property bool monospace: false
    property real minimumWidth: 0
    property color surfaceColor: Appearance.colors.colLayer1

    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property bool _m3: !Appearance.regaliaEverywhere && !_zzz && !Appearance.editorialEverywhere
    readonly property string _glyph: root.selected ? "check" : root.chipIcon
    readonly property int _gap: Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 8
    readonly property int _padStart: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : root._glyph.length > 0 ? 8 : 16
    readonly property int _padEnd: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : 16

    // From the label's natural width, never from the row (the label narrows to fit the chip).
    implicitWidth: Math.max(root.minimumWidth, root._padStart + label.implicitWidth
        + (glyph.visible ? glyph.implicitWidth + root._gap : 0) + root._padEnd)
    implicitHeight: Appearance.regaliaEverywhere ? Appearance.regalia.compactControlHeight : 32
    buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : root._zzz ? Appearance.zzz.controlRadius
        : Appearance.editorialEverywhere ? Appearance.rounding.small
        : Appearance.rounding.verysmall
    buttonRadiusPressed: buttonRadius
    toggled: root.selected

    Accessible.name: root.text
    Accessible.role: Accessible.Button
    Accessible.checked: root.selected

    readonly property color _restFill: Appearance.regaliaEverywhere
        ? (root.selected ? Appearance.regalia.primaryPlate : Appearance.regalia.controlPlate)
        : root.selected ? Appearance.colors.colSecondaryContainer
        : root._m3 ? ColorUtils.transparentize(root.surfaceColor, 1)
        : ColorUtils.mix(root.surfaceColor, Appearance.colors.colOnLayer1, 0.945)
    // The M3 state layer: the label colour at 8 % over the chip.
    readonly property color _hoverFill: Appearance.regaliaEverywhere
        ? (root.selected ? Appearance.regalia.primaryPlateHover : Appearance.regalia.controlPlateHover)
        : root.selected ? Appearance.colors.colSecondaryContainerHover
        : ColorUtils.mix(root.surfaceColor, Appearance.colors.colOnLayer1, 0.92)

    colBackground: root._restFill
    colBackgroundHover: root._hoverFill
    colBackgroundToggled: root._restFill
    colBackgroundToggledHover: root._hoverFill
    colRipple: ColorUtils.transparentize(root._ink, 0.88)
    colRippleToggled: ColorUtils.transparentize(root._ink, 0.88)

    readonly property color _ink: ColorUtils.ensureReadable(
        root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant,
        root.buttonHovered ? root._hoverFill : (root._restFill.a > 0.01 ? root._restFill : root.surfaceColor), 4.5)

    readonly property color _border: Appearance.editorialEverywhere || Appearance.regaliaEverywhere || root.selected
        ? "transparent" : Appearance.colors.colOutlineVariant

    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.visualFocus ? 2 : (root._border === "transparent" ? 0 : 1)
        border.color: root.visualFocus ? Appearance.colors.colPrimary : root._border
    }

    // Centred in the space the control gives its content (a Row anchored to the button would be
    // placed by the control at its left edge instead).
    contentItem: Item {
        implicitWidth: root.implicitWidth - root._padStart - root._padEnd
        implicitHeight: chipRow.implicitHeight

        Row {
            id: chipRow
            x: Math.round(root._padStart + Math.max(0, root.width - root.implicitWidth) / 2) - root.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: glyph.visible ? root._gap : 0

            MaterialSymbol {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                visible: root._glyph.length > 0
                text: root._glyph
                iconSize: 18
                color: root._ink
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }

            // A label longer than the chip was given (a long translation in a fixed cell) elides
            // inside the chip instead of running out of it.
            StyledText {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(0, root.width - root._padStart - root._padEnd
                    - (glyph.visible ? glyph.implicitWidth + root._gap : 0)))
                elide: Text.ElideRight
                text: root.text
                font.pixelSize: Appearance.font.pixelSize.smallie
                font.family: root.monospace ? Appearance.font.family.monospace : Appearance.font.family.main
                font.weight: Font.Medium
                color: root._ink
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }
        }
    }
}
