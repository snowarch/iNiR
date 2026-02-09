import QtQuick
import qs.modules.common

Rectangle {
    id: root

    readonly property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false

    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: cardStyle
        ? (Appearance.inirEverywhere ? Appearance.inir.colLayer1
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colLayer1)
        : "transparent"
    border.width: Appearance.inirEverywhere?1:0
    border.color: cardStyle && Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

    signal openAudioOutputDialog()
    signal openAudioInputDialog()
    signal openBluetoothDialog()
    signal openNightLightDialog()
    signal openWifiDialog()
}
