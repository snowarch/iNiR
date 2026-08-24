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
    property bool presented: true
    property bool closing: false
    property bool panelRightAligned: false
    property real visualMargin: Looks.dp(12)
    // The bar exclusive zone already offsets attached windows.
    property int closeAnimDuration: Looks.transition.duration.medium
    property bool revealFromSides: false
    property bool revealFromLeft: true

    // Animation configuration
    property real openScale: 0.94
    property real closeScale: 0.97
    property int openDuration: Looks.transition.duration.panel
    property int slideOffset: Looks.dp(20)

    function close() {
        if (root.closing)
            return
        root.closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    function present() {
        closeAnim.stop()
        root.closing = false
        panelContent.sourceEdgeMargin = -root.slideOffset
        panelContent.sideEdgeMargin = -root.slideOffset
        panelContent.opacity = 0
        panelContent.scale = root.openScale
        if (Looks.transition.enabled) {
            openAnim.restart()
        } else {
            panelContent.sourceEdgeMargin = root.visualMargin
            panelContent.sideEdgeMargin = root.visualMargin
            panelContent.opacity = 1
            panelContent.scale = 1
        }
    }

    readonly property bool barAtBottom: Config.options?.waffles?.bar?.bottom ?? false
    onPresentedChanged: presented ? present() : close()

    // Screen position for GlassBackground blur alignment in child WPanes
    readonly property var _screen: root.QsWindow?.window?.screen ?? Quickshell.screens[0]
    readonly property real _screenW: _screen?.width ?? 1920
    readonly property real _screenH: _screen?.height ?? 1080
    readonly property real panelScreenX: {
        if (panelRightAligned) {
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

        Component.onCompleted: if (root.presented) Qt.callLater(root.present)

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
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
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
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.accelerate
                }
                NumberAnimation {
                    target: panelContent
                    property: "scale"
                    to: root.closeScale
                    duration: Looks.transition.enabled ? root.closeAnimDuration : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.accelerate
                }
            }
            ScriptAction {
                script: {
                    root.closing = false
                    root.closed()
                }
            }
        }
        
        implicitWidth: root.contentItem.implicitWidth
        implicitHeight: root.contentItem.implicitHeight
        children: [root.contentItem]
    }
}
