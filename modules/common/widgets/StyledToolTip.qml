import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

PopupToolTip {
    id: root
    property string position: "bottom" // "bottom", "left", "right", "top"
    font.family: Appearance.font.family.main
    font.variableAxes: Appearance.font.variableAxes.main
    font.pixelSize: Appearance?.font.pixelSize.smaller ?? 14
    font.hintingPreference: Font.PreferNoHinting // Prevent shaky text

    anchorEdges: position === "left" ? Edges.Left
        : position === "right" ? Edges.Right
        : position === "top" ? Edges.Top
        : Edges.Bottom
    anchorGravity: anchorEdges

    contentItem: StyledToolTipContent {
        id: contentItem
        font: root.font
        text: root.text
        shown: false
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }
}
