pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Card component for grouping settings - Windows 11 style
// Cards are static containers — individual rows handle their own hover.
Rectangle {
    id: root
    
    property string title: ""
    property string icon: ""
    property bool expanded: true
    property bool collapsible: false
    default property alias content: contentColumn.data
    
    Layout.fillWidth: true
    implicitHeight: mainColumn.implicitHeight
    radius: Looks.radius.large
    color: Looks.colors.bg1Base
    border.width: 1
    border.color: Looks.colors.bg1Border
    
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
            implicitHeight: 44

            Rectangle {
                id: headerBg
                anchors.fill: parent
                radius: root.expanded ? 0 : Looks.radius.large
                // Top corners always rounded; bottom only when collapsed
                topLeftRadius: Looks.radius.large
                topRightRadius: Looks.radius.large
                color: root.collapsible && headerMa.containsMouse ? Looks.colors.bg1Hover : "transparent"

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
            }
            
            MouseArea {
                id: headerMa
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
                    leftMargin: 14
                    rightMargin: 14
                }
                spacing: 10
                
                FluentIcon {
                    visible: root.icon !== ""
                    icon: root.icon
                    implicitSize: 16
                    color: Looks.colors.subfg
                }
                
                WText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.strong
                    color: Looks.colors.subfg
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
                    topMargin: root.title !== "" ? 0 : 6
                    bottomMargin: 6
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
