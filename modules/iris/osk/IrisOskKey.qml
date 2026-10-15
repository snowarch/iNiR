pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions
import qs.modules.shared.onScreenKeyboard
import qs.modules.iris.style
import qs.modules.iris.components

// The shared keycap (`OskKey` keeps the behaviour: ydotool, shift, caps), spoken in iRiS's fills.
OskKey {
    id: root

    readonly property real d: IrisStyle.density

    baseWidth: Math.round(44 * root.d)
    baseHeight: Math.round(44 * root.d)

    buttonRadius: IrisStyle.radiusTile
    buttonRadiusPressed: Math.max(3, IrisStyle.radiusTile - 4)
    rippleEnabled: false
    rippleDuration: IrisStyle.duration(420)
    stateTransitionsEnabled: IrisStyle.motionEnabled
    pressScaleEnabled: !root.skinned
    cookieMorphing: false

    // A Design that cuts its own keycaps (IrisDesign part `oskKey`) draws the plate; the key keeps its legend.
    readonly property bool skinned: capSkin.active
    colBackground: root.shape === "empty" || root.skinned ? "transparent" : IrisStyle.fill
    colBackgroundHover: root.skinned ? "transparent" : IrisStyle.fillHover
    colBackgroundToggled: root.skinned ? "transparent" : IrisStyle.tintFill(IrisStyle.accent)
    colBackgroundToggledHover: root.skinned ? "transparent" : IrisStyle.tintFillHover(IrisStyle.accent)
    colRipple: IrisStyle.fillActive
    colRippleToggled: IrisStyle.tintFillHover(IrisStyle.accent)

    colKeyText: IrisStyle.text
    colKeyTextToggled: root.skinned && IrisStyle.plateSelection ? IrisStyle.inkOnAccentFill : IrisStyle.accent
    keyFontFamily: IrisStyle.fontMain
    keyFontSize: IrisStyle.typeHeadline
    fnFontSize: IrisStyle.typeMeta
    glyphFontSize: Math.round(20 * root.d)

    IrisSkin { id: capSkin; part: "oskKey"; host: root; z: -1 }

    // A lit key (shift, caps) is a tint and a hairline of the same tint.
    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.toggled && !root.skinned ? 1 : 0
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        visible: border.width > 0
    }
}
