import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledText {
    text: "Subsection"
    color: Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.colors.colSubtext
    font.weight: Appearance.regaliaEverywhere ? Font.DemiBold : Font.Normal
    font.letterSpacing: Appearance.regaliaEverywhere ? 0.55 : 0
    Layout.leftMargin: 2
}
