pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions
import qs.modules.onScreenKeyboard
import qs.modules.iris.style

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
    pressScaleEnabled: true
    cookieMorphing: false

    colBackground: root.shape === "empty" ? "transparent" : IrisStyle.fill
    colBackgroundHover: IrisStyle.fillHover
    colBackgroundToggled: IrisStyle.tintFill(IrisStyle.accent)
    colBackgroundToggledHover: IrisStyle.tintFillHover(IrisStyle.accent)
    colRipple: IrisStyle.fillActive
    colRippleToggled: IrisStyle.tintFillHover(IrisStyle.accent)

    colKeyText: IrisStyle.text
    colKeyTextToggled: IrisStyle.accent
    keyFontFamily: IrisStyle.fontMain
    keyFontSize: IrisStyle.typeHeadline
    fnFontSize: IrisStyle.typeMeta
    glyphFontSize: Math.round(20 * root.d)

    // A lit key (shift, caps) is a tint and a hairline of the same tint.
    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.toggled ? 1 : 0
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        visible: border.width > 0
    }
}
