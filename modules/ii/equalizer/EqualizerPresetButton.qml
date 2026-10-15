pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RippleButton {
    id: root

    required property string presetName
    property bool selected: false
    readonly property bool editorial: Appearance.editorialEverywhere

    toggled: selected
    implicitHeight: Appearance.regaliaEverywhere ? Appearance.regalia.compactControlHeight : 40
    buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : editorial ? Appearance.rounding.small
        : Appearance.angelEverywhere ? Appearance.rounding.full
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.cookieEverywhere ? Appearance.cookie.roundSmall
        : Appearance.rounding.full
    buttonRadiusPressed: buttonRadius
    cookieMorphing: Appearance.cookieEverywhere

    colBackground: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
        : Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.ink, 0.035)
        : editorial ? Appearance.editorial.layer(1)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.cookieEverywhere ? Appearance.cookie.bg1
        : "transparent"
    colBackgroundHover: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateHover
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer1Hover
        : editorial ? Appearance.colors.colLayer1Hover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.cookieEverywhere ? Appearance.cookie.bg2
        : Appearance.colors.colSurfaceContainerHigh
    colBackgroundToggled: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
        : Appearance.zzzEverywhere ? Appearance.zzz.sticker
        : editorial ? Appearance.editorial.accent
        : Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
        : Appearance.cookieEverywhere ? Appearance.cookie.primaryFace
        : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateHover
        : Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover
        : editorial ? Appearance.colors.colPrimaryHover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassElevatedHover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
        : Appearance.cookieEverywhere ? Appearance.cookie.primaryFace
        : Appearance.colors.colSecondaryContainerHover
    colRipple: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateActive
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer1Active
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.colors.colLayer2Active
    colRippleToggled: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateActive
        : Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive
        : Appearance.cookieEverywhere ? Appearance.cookie.primaryFace
        : Appearance.colors.colSecondaryContainerActive

    readonly property color _textColor: Appearance.regaliaEverywhere
        ? (root.selected ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onColor)
        : Appearance.zzzEverywhere
            ? (root.selected ? Appearance.zzz.onSticker : Appearance.zzz.ink)
        : editorial ? (root.selected ? Appearance.editorial.accentInk : Appearance.editorial.ink)
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere
            ? (root.selected ? Appearance.inir.colOnPrimaryContainer : Appearance.inir.colText)
        : Appearance.cookieEverywhere
            ? (root.selected ? Appearance.cookie.onFace : Appearance.cookie.onColor)
        : root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant

    readonly property color _accentColor: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.zzzEverywhere ? (root.selected ? Appearance.zzz.onSticker : Appearance.zzz.accent)
        : editorial ? Appearance.editorial.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary

    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        visible: !Appearance.cookieEverywhere && !Appearance.regaliaEverywhere
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? root._accentColor
            : Appearance.zzzEverywhere ? Appearance.zzz.hairline
            : root.editorial ? Appearance.editorial.rule
            : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
            : root.selected ? ColorUtils.applyAlpha(root._accentColor, 0.52)
            : Appearance.colors.colOutlineVariant

        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.stateChange.duration }
        }
    }

    contentItem: Item {
        MaterialSymbol {
            anchors {
                left: parent.left
                leftMargin: 11
                verticalCenter: parent.verticalCenter
            }
            text: "check"
            iconSize: 14
            fill: 1
            color: root._textColor
            // Keep the label genuinely centered on narrow adaptive buttons. A
            // selection tint remains sufficient feedback when there is not
            // enough side room for a leading check without colliding with text.
            opacity: root.selected && root.width >= 92 ? 1 : 0
            scale: root.selected ? 1 : 0.72

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: Appearance.zzzEverywhere ? root.presetName.toUpperCase() : root.presetName
            font.family: root.editorial ? Appearance.editorial.displayFamily : Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Appearance.zzzEverywhere ? Font.Black
                : root.selected ? Font.DemiBold : Font.Medium
            font.letterSpacing: root.editorial ? 0.35
                : Appearance.zzzEverywhere ? 0.35
                : Appearance.inirEverywhere ? 0.2 : 0
            font.italic: Appearance.zzzEverywhere && root.selected
            color: root._textColor

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.stateChange.duration }
            }
        }
    }
}
