pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Base page component for Windows 11 style settings
Flickable {
    id: root
    
    property string pageTitle: ""
    property string pageIcon: ""
    property string pageDescription: ""
    default property alias content: contentColumn.data
    
    // Settings search context
    property int settingsPageIndex: -1
    property string settingsPageName: pageTitle
    
    clip: true
    contentHeight: contentColumn.implicitHeight + 56
    boundsBehavior: Flickable.StopAtBounds
    pressDelay: 50
    
    ScrollBar.vertical: WScrollBar {}
    
    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 32
            leftMargin: 36
            rightMargin: 36
            bottomMargin: 28
        }
        spacing: 16

        opacity: 0
        transform: Translate { id: contentTranslate; y: Looks.transition.enabled ? 18 : 0 }

        Component.onCompleted: {
            if (Looks.transition.enabled) {
                contentEntrance.start()
            } else {
                contentColumn.opacity = 1
                contentTranslate.y = 0
            }
        }

        ParallelAnimation {
            id: contentEntrance
            NumberAnimation {
                target: contentColumn
                property: "opacity"
                from: 0; to: 1
                duration: Looks.transition.duration.medium
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: contentTranslate
                property: "y"
                from: 18; to: 0
                duration: Looks.transition.duration.medium
                easing.type: Easing.OutCubic
            }
        }

        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 16
            spacing: 10

            RowLayout {
                spacing: 14

                FluentIcon {
                    visible: root.pageIcon !== ""
                    icon: root.pageIcon
                    implicitSize: 28
                    color: Looks.colors.accent
                }

                WText {
                    text: root.pageTitle
                    font.pixelSize: Looks.font.pixelSize.xlarger * 1.6
                    font.weight: Looks.font.weight.strong
                }
            }
            
            WText {
                visible: root.pageDescription !== ""
                Layout.fillWidth: true
                text: root.pageDescription
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
        }
    }
}
