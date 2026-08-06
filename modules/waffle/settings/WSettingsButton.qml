pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Button setting row - Windows 11 style
WSettingsRow {
    id: root
    
    property string buttonText: ""
    property string buttonIcon: ""
    property bool accent: false
    
    signal buttonClicked()
    
    control: Component {
        WButton {
            text: root.buttonText
            icon.name: root.buttonIcon
            
            colBackground: root.accent
                ? Looks.colors.accent : Looks.colors.interactiveSurface
            colBackgroundHover: root.accent
                ? Looks.colors.accentHover : Looks.colors.interactiveSurfaceHover
            colBackgroundActive: root.accent
                ? Looks.colors.accentActive : Looks.colors.interactiveSurfaceActive
            colForeground: root.accent ? Looks.colors.accentFg : Looks.colors.fg
            
            onClicked: root.buttonClicked()
        }
    }
}
