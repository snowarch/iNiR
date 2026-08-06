pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

// Bespoke ZZZ control: the reusable generalization of the session action button.
// Built on the chamfered ZzzPlate (real cut-corner geometry), with a restrained
// signal fill on hover/press/selected and a subtle hairline when idle. Use this
// instead of a recolored RippleButton whenever a ZZZ surface needs an actionable
// poster control.
RippleButton {
    id: button

    property string buttonIcon: ""
    property bool selected: false
    property real iconSize: 22
    // "signal" (primary pop), "sticker" (muted accent plate) or "accent" (raw accent)
    property string accentRole: "signal"
    readonly property color _activeColor: button.accentRole === "sticker" ? Appearance.zzz.sticker
        : button.accentRole === "accent" ? Appearance.zzz.accentSoft : Appearance.zzz.accentSoft
    readonly property color _onActiveColor: button.accentRole === "sticker" ? Appearance.zzz.onSticker
        : Appearance.zzz.onAccentSoft
    readonly property bool _engaged: button.selected || button.down

    pointingHandCursor: true
    padding: 0

    buttonRadius: Appearance.zzz.cornerRadius
    // The chamfered plate is the visible surface; the ripple rect stays transparent.
    colBackground: "transparent"
    colBackgroundHover: "transparent"
    colRipple: ColorUtils.applyAlpha(button._activeColor, 0.26)

    property color colText: button._engaged ? button._onActiveColor
        : (button.buttonHovered || button.focus) ? Appearance.zzz.onSticker
        : Appearance.zzz.ink

    // Chamfered plate surface (real geometry).
    ZzzPlate {
        anchors.fill: parent
        chamfer: Appearance.zzz.cutCorner
        fillColor: button._engaged ? button._activeColor
            : (button.buttonHovered || button.focus) ? Appearance.zzz.sticker
            : Appearance.zzz.paperAlt
        strokeColor: button._engaged ? "transparent" : Appearance.zzz.hairlineStrong
        strokeWidth: 1
    }

    contentItem: RowLayout {
        spacing: button.buttonText.length > 0 && button.buttonIcon.length > 0 ? 8 : 0

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            visible: button.buttonIcon.length > 0
            text: button.buttonIcon
            iconSize: button.iconSize
            color: button.colText
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: button.buttonText.length > 0
            text: button.buttonText.toUpperCase()
            font.family: Appearance.font.family.title
            font.weight: Font.Black
            font.italic: true
            color: button.colText
        }
    }
}
