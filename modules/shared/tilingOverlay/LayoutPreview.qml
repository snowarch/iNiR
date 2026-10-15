import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property string layout: "off"
    property int windowCount: 3
    property color accentColor: Appearance.colors.colPrimary

    readonly property color masterColor: root.accentColor
    readonly property color stackColor: ColorUtils.transparentize(root.accentColor, 0.5)
    readonly property color offColor: Appearance.colors.colLayer2
    readonly property int gap: 2
    readonly property int rad: 2
    readonly property int wc: Math.max(1, Math.min(root.windowCount, 6))

    // MASTER-LEFT
    Item {
        anchors.fill: parent
        visible: root.layout === "master-left"
        
        Row {
            anchors.fill: parent
            spacing: root.gap
            
            Rectangle {
                width: parent.width * 0.55
                height: parent.height
                radius: root.rad
                color: root.masterColor
            }
            Column {
                width: parent.width * 0.45 - root.gap
                height: parent.height
                spacing: root.gap
                
                Repeater {
                    model: Math.max(1, Math.min(root.wc - 1, 3))
                    Rectangle { 
                        width: parent.width
                        height: (parent.parent.height - (Math.max(1, Math.min(root.wc - 1, 3)) - 1) * root.gap) / Math.max(1, Math.min(root.wc - 1, 3))
                        radius: root.rad
                        color: root.stackColor 
                    }
                }
            }
        }
    }

    // MASTER-RIGHT
    Item {
        anchors.fill: parent
        visible: root.layout === "master-right"
        
        Row {
            anchors.fill: parent
            spacing: root.gap
            
            Column {
                width: parent.width * 0.45 - root.gap
                height: parent.height
                spacing: root.gap
                
                Repeater {
                    model: Math.max(1, Math.min(root.wc - 1, 3))
                    Rectangle { 
                        width: parent.width
                        height: (parent.parent.height - (Math.max(1, Math.min(root.wc - 1, 3)) - 1) * root.gap) / Math.max(1, Math.min(root.wc - 1, 3))
                        radius: root.rad
                        color: root.stackColor 
                    }
                }
            }
            Rectangle {
                width: parent.width * 0.55
                height: parent.height
                radius: root.rad
                color: root.masterColor
            }
        }
    }

    // COLUMNS
    Item {
        anchors.fill: parent
        visible: root.layout === "columns"
        
        Row {
            anchors.fill: parent
            spacing: root.gap
            
            Repeater {
                model: Math.min(root.wc, 4)
                Rectangle { 
                    width: (parent.width - (Math.min(root.wc, 4) - 1) * root.gap) / Math.min(root.wc, 4)
                    height: parent.height
                    radius: root.rad
                    color: index === 0 ? root.masterColor : root.stackColor 
                }
            }
        }
    }

    // MONOCLE
    Rectangle {
        anchors.fill: parent
        visible: root.layout === "monocle"
        radius: root.rad
        color: root.masterColor
    }

    // OFF
    Rectangle {
        anchors.fill: parent
        visible: root.layout === "off"
        radius: root.rad
        color: root.offColor
        
        MaterialSymbol {
            anchors.centerIn: parent
            text: "close"
            iconSize: Math.min(parent.width, parent.height) * 0.5
            color: ColorUtils.transparentize(root.accentColor, 0.3)
        }
    }
}
