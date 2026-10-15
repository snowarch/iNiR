pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

GridLayout {
    id: root
    property string selectedShape: "Cookie4Sided"
    signal shapeSelected(string name)
    columns: 6
    columnSpacing: 4
    rowSpacing: 4

    Repeater {
        model: DesktopWidgetShapes.choices
        RippleButton {
            id: choiceButton
            required property var modelData
            Layout.fillWidth: true
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: Appearance.rounding.small
            toggled: root.selectedShape === modelData.value
            Accessible.name: modelData.label
            onClicked: root.shapeSelected(modelData.value)
            contentItem: Item {
                MaterialShape {
                    anchors.centerIn: parent
                    implicitSize: 24
                    shape: choiceButton.modelData.shape
                    color: choiceButton.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                }
            }
            StyledToolTip { text: choiceButton.modelData.label }
        }
    }
}
