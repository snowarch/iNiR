pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root

    required property real availableWidth
    required property real availableHeight
    property string title: Translation.tr("Quick controls")
    property real regularWidth: 360
    readonly property bool dense: availableHeight < 760
    readonly property bool wideDense: dense && availableWidth >= 480
    readonly property int optionColumns: wideDense ? 4 : 3
    readonly property int metricColumns: wideDense ? 4 : 2
    readonly property real contentNaturalWidth: contentColumn.implicitWidth
    readonly property real resolvedWidth: {
        const safeWidth = Math.max(0, root.availableWidth)
        const natural = Math.max(244, root.regularWidth,
            root.contentNaturalWidth)
        const responsive = root.dense ? Math.max(480, natural) : natural
        return Math.min(safeWidth, root.dense ? Math.min(620, responsive) : responsive)
    }

    default property alias contentData: contentColumn.data

    implicitWidth: resolvedWidth
    spacing: dense ? 6 : 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 5

        MaterialSymbol {
            text: "tune"
            iconSize: 14
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: root.title
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
    }

    ColumnLayout {
        id: contentColumn
        Layout.fillWidth: true
        spacing: root.dense ? 6 : 8
    }
}
