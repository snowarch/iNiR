pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.waffle.looks

// Card component for grouping settings - Windows 11 style
Rectangle {
    id: root
    
    property string title: ""
    property string icon: ""
    property bool expanded: true
    property bool collapsible: false
    default property alias content: contentColumn.data
    
    Layout.fillWidth: true
    implicitHeight: mainColumn.implicitHeight
    radius: Looks.radius.xLarge
    color: cardHoverArea.containsMouse ? Qt.lighter(Looks.colors.bgPanelFooter, 1.03) : Looks.colors.bgPanelFooter
    border.width: 1
    border.color: Looks.colors.bg2Border
    
    Behavior on color {
        animation: ColorAnimation { duration: Looks.transition.enabled ? 120 : 0; easing.type: Easing.OutQuad }
    }
    
    // Card elevation shadow
    WRectangularShadow {
        target: root
    }
    
    // Subtle hover detection for entire card
    MouseArea {
        id: cardHoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    
    ColumnLayout {
        id: mainColumn
        anchors {
            left: parent.left
            right: parent.right
        }
        spacing: 0
        
        // Header
        Item {
            visible: root.title !== ""
            Layout.fillWidth: true
            implicitHeight: 52
            
            MouseArea {
                anchors.fill: parent
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: root.collapsible
                onClicked: if (root.collapsible) root.expanded = !root.expanded
            }
            
            RowLayout {
                id: headerRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 10
                
                FluentIcon {
                    visible: root.icon !== ""
                    icon: root.icon
                    implicitSize: 16
                    color: Looks.colors.accent
                }
                
                WText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Looks.font.weight.strong
                    color: Looks.colors.fg
                }
                
                FluentIcon {
                    visible: root.collapsible
                    icon: "chevron-up"
                    implicitSize: 12
                    color: Looks.colors.subfg
                    
                    rotation: root.expanded ? 0 : 180
                    Behavior on rotation {
                        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
            }
        }

        // Content with smooth collapse
        Item {
            Layout.fillWidth: true
            implicitHeight: root.expanded ? contentColumn.implicitHeight + contentColumn.anchors.topMargin + contentColumn.anchors.bottomMargin : 0
            clip: true

            Behavior on implicitHeight {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }

            ColumnLayout {
                id: contentColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: root.title !== "" ? 4 : 6
                    bottomMargin: 10
                }
                spacing: 0
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
