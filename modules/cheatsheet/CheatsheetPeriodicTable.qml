import "periodic_table.js" as PTable
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

StyledFlickable {
    id: root
    readonly property var elements: PTable.elements
    readonly property var series: PTable.series
    property real tileSpacing: Appearance.sizes.spacingSmall

    clip: true
    contentHeight: contentColumn.implicitHeight + 40

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                text: "experiment"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }

            StyledText {
                text: Translation.tr("Periodic Table of Elements")
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
            }

            Item { Layout.fillWidth: true }
        }

        // Table container
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: tableColumn.implicitHeight + 32
            radius: Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1

            Column {
                id: tableColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                spacing: root.tileSpacing

                // Main table rows
                Repeater {
                    model: root.elements

                    delegate: Row {
                        id: tableRow
                        spacing: root.tileSpacing
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: tableRow.modelData
                            delegate: ElementTile {
                                required property var modelData
                                element: modelData
                            }
                        }
                    }
                }

                // Gap between main table and series
                Item {
                    width: 1
                    height: Appearance.sizes.spacingLarge
                }

                // Lanthanides and Actinides series
                Repeater {
                    model: root.series

                    delegate: Row {
                        id: seriesTableRow
                        spacing: root.tileSpacing
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: seriesTableRow.modelData
                            delegate: ElementTile {
                                required property var modelData
                                element: modelData
                            }
                        }
                    }
                }

                // Gap before legend
                Item {
                    width: 1
                    height: Appearance.sizes.spacingMedium
                }

                // Legend showing element categories with colors
                CheatsheetElementLegend {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
