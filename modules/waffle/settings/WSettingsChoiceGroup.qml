pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.waffle.looks

// Standardized grid of WChoiceButton tiles for multi-option selection
Item {
    id: root

    property var options: []    // [{value: "x", label: "Label", icon: ""}, ...]
    property var currentValue
    property int columns: 3
    property int rowSpacing: 6
    property int columnSpacing: 6

    signal selected(var newValue)

    Layout.fillWidth: true
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors {
            left: parent.left
            right: parent.right
        }
        columns: root.columns
        columnSpacing: root.columnSpacing
        rowSpacing: root.rowSpacing

        Repeater {
            model: root.options

            WChoiceButton {
                id: choiceBtn
                required property var modelData
                required property int index

                Layout.fillWidth: true
                text: modelData.label ?? ""
                icon.name: modelData.icon ?? ""
                checked: root.currentValue === modelData.value
                onClicked: root.selected(modelData.value)
            }
        }
    }
}
