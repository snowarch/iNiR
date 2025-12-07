pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Switch setting row - Windows 11 style
WSettingsRow {
    id: root
    
    property bool checked: false
    
    clickable: true
    onClicked: root.checked = !root.checked
    
    control: Component {
        WSwitch {
            checked: root.checked
            onClicked: root.checked = !root.checked
        }
    }
}
