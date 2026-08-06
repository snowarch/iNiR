import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Short inline note for settings pages: an accent-tinted line that informs or
// warns right where the control is. Prefer this over a long tooltip — a tooltip
// that has to wrap breaks the layout in window mode.
RowLayout {
    id: root

    property string text
    property string icon: "info"
    property bool warning: false

    spacing: 6
    Layout.fillWidth: true

    readonly property color noteColor: {
        if (root.warning) {
            return Appearance.inirEverywhere ? Appearance.inir.colWarning
                 : Appearance.colors.colTertiary
        }
        return Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
             : Appearance.colors.colSubtext
    }

    MaterialSymbol {
        text: root.icon
        iconSize: Appearance.font.pixelSize.small
        color: root.noteColor
    }

    StyledText {
        Layout.fillWidth: true
        text: root.text
        color: root.noteColor
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
    }
}
