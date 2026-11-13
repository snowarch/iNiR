pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// On or off: the family's own switch when it has one, Material's otherwise. `toggled` asks for the change; `checked`
// follows the value it was given.
Item {
    id: root

    property bool checked: false
    property string name: ""
    signal toggled()

    implicitWidth: familySwitch.url.length > 0 ? familySwitch.width : materialSwitch.width
    implicitHeight: familySwitch.url.length > 0 ? familySwitch.height : materialSwitch.height

    FamilyPart {
        id: familySwitch
        visible: familySwitch.url.length > 0
        anchors.centerIn: parent
        part: "control.switch"
        props: ({ on: root.checked, name: root.name })
        Connections {
            target: familySwitch.item
            function onToggled(): void { answer.restart() }
        }
    }
    StyledSwitch {
        id: materialSwitch
        visible: familySwitch.url.length === 0
        anchors.centerIn: parent
        checked: root.checked
        onClicked: {
            answer.restart()
            materialSwitch.checked = Qt.binding(() => root.checked)
        }
    }

    // Answered after the tap returns, so a control rebuilt by its own change never dies inside the click.
    Timer { id: answer; interval: 0; onTriggered: root.toggled() }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.name
    Accessible.checked: root.checked
}
