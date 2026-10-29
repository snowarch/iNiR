import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Settings stack one per row: labels run down the left edge, states down the right, and the eye reads both columns
// without zigzagging. `uniform` and `minimumCellWidth` remain for pages that set them.
GridLayout {
    id: root

    property bool uniform: false
    property real spacing: SettingsMaterialPreset.tileGap
    property real minimumCellWidth: 280 * Appearance.fontSizeScale

    Layout.fillWidth: true
    columns: 1
    columnSpacing: root.spacing
    rowSpacing: root.spacing
    uniformCellWidths: uniform
}
