import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextArea {
    cursorDelegate: TextCursor {}
    id: root
    QQC.ContextMenu.menu: null
    QQC.ContextMenu.onRequested: position => TextEditMenu.open(root, position)
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
