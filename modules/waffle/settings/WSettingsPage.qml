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
    signal navigateRequested(int pageIndex)
    
    // Settings search context
    property int settingsPageIndex: -1
    property string settingsPageName: pageTitle
    
    clip: true
    contentHeight: contentColumn.implicitHeight + 48
    boundsBehavior: Flickable.StopAtBounds
    pressDelay: 50
    
    ScrollBar.vertical: WScrollBar {}
    
    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 24
            leftMargin: 28
            rightMargin: 28
            bottomMargin: 20
        }
        spacing: 10

        opacity: 0
        transform: Translate { id: contentTranslate; y: Looks.transition.enabled ? 14 : 0 }

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
                duration: Looks.transition.duration.page
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
            NumberAnimation {
                target: contentTranslate
                property: "y"
                from: 14; to: 0
                duration: Looks.transition.duration.page
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }

        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            spacing: 4

            WText {
                text: root.pageTitle
                font.pixelSize: Looks.font.pixelSize.xlarger * 1.5
                font.weight: Looks.font.weight.stronger
            }
            
            WText {
                visible: root.pageDescription !== ""
                Layout.fillWidth: true
                text: root.pageDescription
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
        }
    }
}
