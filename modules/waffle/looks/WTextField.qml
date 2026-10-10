import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls.FluentWinUI3
import QtQuick.Controls

TextField {
    id: root
    
    clip: true
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    color: Looks.colors.fg

    // The focus line FluentWinUI3 draws under the field.
    palette.accent: Looks.colors.accent

    font {
        hintingPreference: Font.PreferDefaultHinting
        family: Looks.font.family.ui
        pixelSize: Looks.font.pixelSize.normal
        weight: Looks.font.weight.regular
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
    }

    TextInputContextMenu {
        target: root
    }
}
