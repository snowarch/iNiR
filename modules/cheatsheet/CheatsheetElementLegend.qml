import "periodic_table.js" as PTable
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: legendFlow.implicitWidth
    implicitHeight: legendFlow.implicitHeight

    // Category color mapping matching ElementTile.qml - dynamically bound to theme
    function getCategoryColor(category) {
        switch (category) {
            case "metal": return Appearance.colors.colSecondary
            case "nonmetal": return Appearance.colors.colTertiary
            case "noblegas": return Appearance.colors.colPrimary
            case "lanthanum": return Appearance.colors.colPrimaryContainer
            case "actinium": return Appearance.colors.colSecondaryContainer
            default: return Appearance.colors.colLayer2
        }
    }

    // Category display names from periodic_table.js
    readonly property var categoryNames: PTable.niceTypes

    // List of categories to display (excluding 'empty')
    readonly property var categories: ["metal", "nonmetal", "noblegas", "lanthanum", "actinium"]

    Flow {
        id: legendFlow
        anchors.fill: parent
        spacing: Appearance.sizes.spacingMedium

        Repeater {
            model: root.categories

            delegate: Row {
                id: legendItem
                required property string modelData
                spacing: Appearance.sizes.spacingSmall

                Rectangle {
                    id: colorSwatch
                    width: 16
                    height: 16
                    radius: Appearance.rounding.small
                    color: root.getCategoryColor(legendItem.modelData)
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }

                StyledText {
                    text: root.categoryNames[legendItem.modelData] ?? legendItem.modelData
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
