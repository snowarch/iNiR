pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

Item {
    id: root

    signal closed

    required property Item contentItem
    property real visualMargin: Looks.dp(12)
    property int closeAnimDuration: 180
    property bool revealFromSides: false
    property bool revealFromLeft: true
    
    // Animation configuration
    property real openScale: 0.94
    property real closeScale: 0.97
    property int openDuration: Looks.transition.duration.panel
    property int slideOffset: Looks.dp(20)  // Reduced slide distance for subtlety

    function close() {
        closeAnim.start();
    }

    readonly property bool barAtBottom: Config.options?.waffles?.bar?.bottom ?? false

    // Screen position for GlassBackground blur alignment in child WPanes
    readonly property var _screen: Quickshell.screens[0]
    readonly property real _screenW: _screen?.width ?? 1920
    readonly property real _screenH: _screen?.height ?? 1080
    readonly property real panelScreenX: {
        if (revealFromSides && !revealFromLeft) {
            // Right-side panel
            return _screenW - root.implicitWidth
        }
        return 0  // Left-side or vertical panel
    }
    readonly property real panelScreenY: {
        if (barAtBottom) {
            return _screenH - root.implicitHeight
        }
        return 0  // Top-anchored
    }

    implicitHeight: contentItem.implicitHeight + visualMargin * 2
    implicitWidth: contentItem.implicitWidth + visualMargin * 2

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close();
        }
    }

    Item {
        id: panelContent
        anchors {
            left: (root.revealFromSides && !root.revealFromLeft) ? undefined : parent.left
            right: (root.revealFromSides && root.revealFromLeft) ? undefined : parent.right
            top: (!root.revealFromSides && root.barAtBottom) ? undefined : parent.top
            bottom: (!root.revealFromSides && !root.barAtBottom) ? undefined : parent.bottom
            bottomMargin: (!root.revealFromSides && root.barAtBottom) ? sourceEdgeMargin : root.visualMargin
            topMargin: (!root.revealFromSides && !root.barAtBottom) ? sourceEdgeMargin : root.visualMargin
            leftMargin: (root.revealFromSides && root.revealFromLeft) ? sideEdgeMargin : root.visualMargin
            rightMargin: (root.revealFromSides && !root.revealFromLeft) ? sideEdgeMargin : root.visualMargin
        }

        // Initial state for animation
        property real sourceEdgeMargin: -root.slideOffset
        property real sideEdgeMargin: -root.slideOffset
        opacity: 0
        scale: root.openScale
        
        // Transform origin based on reveal direction
        transformOrigin: {
            if (root.revealFromSides) {
                return root.revealFromLeft ? Item.Left : Item.Right
            } else {
                return root.barAtBottom ? Item.Bottom : Item.Top
            }
        }

        Component.onCompleted: {
            if (Looks.transition.enabled) {
                openAnim.start()
            } else {
                sourceEdgeMargin = root.visualMargin
                sideEdgeMargin = root.visualMargin
                opacity = 1
                scale = 1
            }
        }

        // Opening animation - slide + scale + fade
        ParallelAnimation {
            id: openAnim
            
            NumberAnimation {
                target: panelContent
                property: "sourceEdgeMargin"
                to: root.visualMargin
                duration: Looks.transition.enabled ? root.openDuration : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
            NumberAnimation {
                target: panelContent
                property: "sideEdgeMargin"
                to: root.visualMargin
                duration: Looks.transition.enabled ? root.openDuration : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
            NumberAnimation {
                target: panelContent
                property: "opacity"
                to: 1
                duration: Looks.transition.enabled ? (root.openDuration * 0.7) : 0
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: panelContent
                property: "scale"
                to: 1
                duration: Looks.transition.enabled ? root.openDuration : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.spring
            }
        }
        
        // Closing animation - faster, subtle scale down
        SequentialAnimation {
            id: closeAnim
            
            ParallelAnimation {
                NumberAnimation {
                    target: panelContent
                    property: "sourceEdgeMargin"
                    to: -root.slideOffset * 0.5
                    duration: Looks.transition.enabled ? root.closeAnimDuration : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.accelerate
                }
                NumberAnimation {
                    target: panelContent
                    property: "sideEdgeMargin"
                    to: -root.slideOffset * 0.5
                    duration: Looks.transition.enabled ? root.closeAnimDuration : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.accelerate
                }
                NumberAnimation {
                    target: panelContent
                    property: "opacity"
                    to: 0
                    duration: Looks.transition.enabled ? (root.closeAnimDuration * 0.8) : 0
                    easing.type: Easing.InQuad
                }
                NumberAnimation {
                    target: panelContent
                    property: "scale"
                    to: root.closeScale
                    duration: Looks.transition.enabled ? root.closeAnimDuration : 0
                    easing.type: Easing.InQuad
                }
            }
            ScriptAction {
                script: root.closed()
            }
        }
        
        implicitWidth: root.contentItem.implicitWidth
        implicitHeight: root.contentItem.implicitHeight
        children: [root.contentItem]
    }
}
