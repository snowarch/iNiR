import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextArea {
    id: root
    renderType: Text.NativeRendering
    selectedTextColor: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk : Appearance.colors.colOnSecondaryContainer
    selectionColor: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate : Appearance.colors.colSecondaryContainer
    placeholderTextColor: Appearance.regaliaEverywhere ? Appearance.regalia.onMuted : Appearance.colors.colOutline
    font {
        family: Appearance.font.family.main
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }

    TextInputContextMenu {
        target: root
    }
}
