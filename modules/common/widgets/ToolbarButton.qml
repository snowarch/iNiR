import QtQuick
import QtQuick.Layouts
import qs.modules.common

RippleButton {
    Layout.fillHeight: true
    buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
}
