pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Dropdown/ComboBox setting row - Windows 11 style
WSettingsRow {
    id: root
    
    property var options: [] // [{value: "x", displayName: "X"}, ...]
    property var currentValue
    
    signal selected(var newValue)
    
    control: Component {
        ComboBox {
            id: combo
            implicitWidth: 160
            implicitHeight: 32
            
            model: root.options
            textRole: "displayName"
            valueRole: "value"
            currentIndex: {
                for (let i = 0; i < root.options.length; i++) {
                    if (root.options[i].value === root.currentValue) return i
                }
                return 0
            }
            
            onActivated: index => {
                if (index >= 0 && index < root.options.length) {
                    root.selected(root.options[index].value)
                }
            }
            
            background: Rectangle {
                radius: Looks.radius.medium
                color: combo.down ? Looks.colors.bg2Active 
                    : combo.hovered ? Looks.colors.bg2Hover 
                    : Looks.colors.inputBg
                border.width: 1
                border.color: combo.activeFocus ? Looks.colors.accent : Looks.colors.bg2Border
            }
            
            contentItem: RowLayout {
                spacing: 8
                
                WText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    text: combo.displayText
                    font.pixelSize: Looks.font.pixelSize.normal
                    elide: Text.ElideRight
                }
                
                FluentIcon {
                    Layout.rightMargin: 8
                    icon: "chevron-down"
                    implicitSize: 12
                    color: Looks.colors.subfg
                }
            }
            
            popup: Popup {
                y: combo.height + 4
                width: combo.width
                implicitHeight: contentItem.implicitHeight + 8
                padding: 4
                
                enter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.OutCubic }
                    }
                }
                exit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.InQuad }
                        NumberAnimation { property: "scale"; from: 1.0; to: 0.97; duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.InQuad }
                    }
                }
                
                background: Item {
                    Rectangle {
                        id: popupBg
                        anchors.fill: parent
                        radius: Looks.radius.large
                        color: Looks.colors.bgPanelFooter
                        border.width: 1
                        border.color: Looks.colors.bg2Border
                    }
                    
                    WRectangularShadow {
                        target: popupBg
                    }
                }
                
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: combo.popup.visible ? combo.delegateModel : null
                    currentIndex: combo.highlightedIndex
                    
                    ScrollBar.vertical: WScrollBar {}
                }
            }
            
            delegate: ItemDelegate {
                id: delegateItem
                required property int index
                required property var modelData
                
                width: combo.width - 8
                height: 36
                highlighted: combo.highlightedIndex === index
                
                background: Rectangle {
                    radius: Looks.radius.medium
                    color: {
                        if (delegateItem.index === combo.currentIndex) return Looks.colors.accent
                        if (delegateItem.highlighted) return Looks.colors.bg2Hover
                        return "transparent"
                    }
                    opacity: delegateItem.index === combo.currentIndex ? 0.15 : 1.0
                    
                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
                
                contentItem: RowLayout {
                    spacing: 6
                    
                    FluentIcon {
                        Layout.leftMargin: 8
                        icon: "checkmark"
                        implicitSize: 12
                        color: delegateItem.index === combo.currentIndex ? Looks.colors.accent : Looks.colors.fg
                        visible: delegateItem.index === combo.currentIndex
                    }
                    
                    Item {
                        Layout.leftMargin: 8
                        implicitWidth: 12
                        visible: delegateItem.index !== combo.currentIndex
                    }
                    
                    WText {
                        Layout.fillWidth: true
                        text: delegateItem.modelData.displayName
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: delegateItem.index === combo.currentIndex ? Looks.font.weight.strong : Looks.font.weight.regular
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
