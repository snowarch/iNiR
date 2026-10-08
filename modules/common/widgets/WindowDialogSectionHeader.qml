import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

StyledText {
    text: "Section"
    font {
        family: Appearance.font.family.title
        pixelSize: Appearance.font.pixelSize.large
        variableAxes: Appearance.editorialEverywhere ? ({}) : Appearance.font.variableAxes.title
        weight: Appearance.editorialEverywhere ? Appearance.editorial.titleWeight : Font.Normal
        letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
    }
}
