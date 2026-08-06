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

    // Dynamic tile sizing: fit 18 columns into available width
    readonly property real tableMargin: 12
    readonly property real cardPadding: 10
    readonly property real tileSpacing: 2
    readonly property real availableForTiles: width - tableMargin * 2 - cardPadding * 2
    readonly property real tileSize: Math.max(36, Math.min(70, (availableForTiles - 17 * tileSpacing) / 18))

    clip: true
    contentHeight: contentColumn.implicitHeight + 24

    ColumnLayout {
        id: contentColumn
        width: root.width - root.tableMargin * 2
        anchors {
            top: parent.top
            left: parent.left
            margins: root.tableMargin
        }
        spacing: 8

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
            Layout.preferredHeight: tableColumn.implicitHeight + root.cardPadding * 2
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                  : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.zzzEverywhere ? 1
                        : Appearance.inirEverywhere ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.zzzEverywhere ? Appearance.zzz.hairline
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
            Behavior on border.width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Column {
                id: tableColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: root.cardPadding
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
                                tileSize: root.tileSize
                            }
                        }
                    }
                }

                // Gap between main table and series
                Item {
                    width: 1
                    height: root.tileSpacing * 2
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
                                tileSize: root.tileSize
                            }
                        }
                    }
                }

                // Gap before legend
                Item {
                    width: 1
                    height: root.tileSpacing
                }

                // Legend showing element categories with colors
                CheatsheetElementLegend {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
