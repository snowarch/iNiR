import QtQuick
import QtQuick.Layouts
import qs.modules.common

GridLayout {
    id: root

    property bool uniform: false
    property real spacing: 8
    property real minimumCellWidth: 280 * Appearance.fontSizeScale
    readonly property int visibleCellCount: {
        let count = 0
        for (let i = 0; i < children.length; ++i) {
            if (children[i]?.visible !== false)
                count++
        }
        return Math.max(1, count)
    }
    readonly property int adaptiveColumns: {
        const available = Math.max(0, width)
        if (visibleCellCount >= 3 && available >= minimumCellWidth * 3 + columnSpacing * 2)
            return 3
        if (visibleCellCount >= 2 && available >= minimumCellWidth * 2 + columnSpacing)
            return 2
        return 1
    }

    Layout.fillWidth: true
    columns: adaptiveColumns
    columnSpacing: root.spacing
    rowSpacing: root.spacing
    uniformCellWidths: uniform
}
