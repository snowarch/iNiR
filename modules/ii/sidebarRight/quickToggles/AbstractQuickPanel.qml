import QtQuick
import qs.modules.common

Rectangle {
    id: root

    readonly property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false

    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: cardStyle ? "transparent"
        :(Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1)

    border.width: Appearance.inirEverywhere?1:0
    border.color: Appearance.inir.colBorder

    signal openAudioOutputDialog()
    signal openAudioInputDialog()
    signal openBluetoothDialog()
    signal openNightLightDialog()
    signal openWifiDialog()
}
