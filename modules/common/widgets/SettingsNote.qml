import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Short inline note for settings pages: supporting text right where the control is, or a warning. Prefer this over
// a long tooltip: a tooltip that has to wrap breaks the layout in window mode. Only a warning wears a glyph; a small
// decorative one beside supporting text read as an empty checkbox (10-30).
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
        visible: root.warning
        text: root.icon === "info" ? "warning" : root.icon
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
