import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledText {
    text: "Subsection"
    color: Appearance.editorialEverywhere ? Appearance.editorial.accent
        : Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.colors.colSubtext
    font.family: Appearance.font.family.main
    font.pixelSize: Appearance.editorialEverywhere ? Appearance.font.pixelSize.smallest : Appearance.font.pixelSize.normal
    font.weight: Appearance.editorialEverywhere ? Appearance.editorial.labelWeight
        : Appearance.regaliaEverywhere ? Font.DemiBold : Font.Normal
    font.capitalization: Appearance.editorialEverywhere ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.metadataTracking
        : Appearance.regaliaEverywhere ? 0.55 : 0
    Layout.leftMargin: 2
}
