pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

Menu {
    id: root

    property bool downDirection: false
    // True when any item carries an icon. WMenuItem reserves the icon column
    // on icon-less items so all labels align. Auto-detected on open.
    property bool hasIcons: false
    function _updateHasIcons() {
        for (let i = 0; i < root.count; i++) {
            const it = root.itemAt(i)
            if (it?.icon?.name) { root.hasIcons = true; return }
        }
        root.hasIcons = false
    }
    onOpened: root._updateHasIcons()

    property color color: Looks.colors.bg1Base
    property alias backgroundPane: bgPane

    implicitWidth: background.implicitWidth + margins * 2
    implicitHeight: background.implicitHeight + margins * 2
    margins: Looks.dp(10)
    padding: Looks.dp(3)
    property real sourceEdgeMargin: -implicitHeight
    clip: true
    
    enter: Transition {
        enabled: Looks.transition.enabled
        ParallelAnimation {
            NumberAnimation {
                property: "sourceEdgeMargin"
                from: -root.implicitHeight * 0.3
                to: root.margins
                duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.popIn
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.OutQuad
            }
        }
    }
    exit: Transition {
        enabled: Looks.transition.enabled
        ParallelAnimation {
            NumberAnimation {
                property: "sourceEdgeMargin"
                from: root.margins
                to: -root.implicitHeight * 0.2
                duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.popOut
            }
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                easing.type: Easing.InQuad
            }
        }
    }

    background: Item {
        id: bgItem
        implicitWidth: bgPane.implicitWidth
        implicitHeight: bgPane.implicitHeight
        WPane {
            id: bgPane
            anchors {
                left: parent.left
                right: parent.right
                top: root.downDirection ? parent.top : undefined
                bottom: root.downDirection ? undefined : parent.bottom
                margins: root.margins
                topMargin: root.downDirection ? root.sourceEdgeMargin : root.margins
                bottomMargin: root.downDirection ? root.margins : root.sourceEdgeMargin
            }
            contentItem: Rectangle {
                color: root.color
                implicitWidth: menuListView.implicitWidth + root.padding * 2
                implicitHeight: root.contentItem.implicitHeight + root.padding * 2
            }
        }
    }

    contentItem: Item {
        implicitWidth: menuListView.implicitWidth
        implicitHeight: menuListView.implicitHeight
        ListView {
            id: menuListView
            anchors {
                left: parent.left
                right: parent.right
                top: root.downDirection ? parent.top : undefined
                bottom: root.downDirection ? undefined : parent.bottom
                margins: root.margins
                topMargin: root.downDirection ? root.sourceEdgeMargin : root.margins
                bottomMargin: root.downDirection ? root.margins : root.sourceEdgeMargin
            }
            implicitHeight: contentHeight
            implicitWidth: Array.from({
                length: count
            }, (_, i) => itemAtIndex(i)?.implicitWidth ?? 0).reduce((a, b) => a > b ? a : b)

            model: root.contentModel
        }
    }

    delegate: WMenuItem {
        id: menuItemDelegate
        width: ListView.view?.width
    }
}
