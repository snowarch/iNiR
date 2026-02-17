pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Loader {
    id: root

    required property var contentItem
    property real padding: Looks.radius.large - Looks.radius.medium
    property bool noSmoothClosing: !(Config.options?.waffles?.tweaks?.smootherMenuAnimations ?? true)
    property bool closeOnFocusLost: true
    property bool closeOnHoverLost: true  // Close when mouse leaves both popup and anchor
    property int closeOnHoverLostDelay: 300  // Delay in ms before closing on hover lost
    property bool anchorHovered: false  // Set by parent to indicate if anchor button is hovered
    signal focusCleared()
    
    property Item anchorItem: parent
    property real visualMargin: 12
    readonly property bool barAtBottom: Config.options?.waffles?.bar?.bottom ?? false
    property bool popupBelow: false  // Force popup to appear below anchor
    property real ambientShadowWidth: 1

    onFocusCleared: {
        if (!root.closeOnFocusLost) return;
        root.close()
    }

    function grabFocus() {
        if (item) item.grabFocus();
    }

    function close() {
        if (item) item.close();
        else root.active = false;
    }

    function updateAnchor() {
        item?.anchor.updateAnchor();
    }

    active: false  // Default value, can be overridden by binding from parent
    visible: active
    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true
        Component.onCompleted: {
            openAnim.start();
            // For Niri: show the click-outside backdrop
            if (CompositorService.isNiri && root.closeOnFocusLost) {
                clickOutsideBackdrop.visible = true;
            }
        }
        Component.onDestruction: {
            clickOutsideBackdrop.visible = false;
        }

        anchor {
            adjustment: PopupAdjustment.ResizeY | PopupAdjustment.SlideX
            item: root.anchorItem
            gravity: root.popupBelow ? Edges.Bottom : (root.barAtBottom ? Edges.Top : Edges.Bottom)
            edges: root.popupBelow ? Edges.Bottom : (root.barAtBottom ? Edges.Top : Edges.Bottom)
        }

        CompositorFocusGrab {
            id: focusGrab
            active: root.closeOnFocusLost && CompositorService.isHyprland
            windows: [popupWindow]
            onCleared: root.focusCleared();
        }
        
        // Close on Escape key — handled via Shortcut since PopupWindow is not an Item
        Shortcut {
            sequences: [StandardKey.Cancel]
            onActivated: root.close()
        }
        
        // Timer to close when mouse leaves both popup AND anchor
        // Same pattern as TaskPreview - only runs when conditions are met
        Timer {
            id: closeTimer
            interval: root.closeOnHoverLostDelay
            running: root.closeOnHoverLost && popupWindow.visible && !popupWindow.popupContainsMouse && !root.anchorHovered
            onTriggered: {
                root.close();
            }
        }

        function close() {
            clickOutsideBackdrop.visible = false;
            if (root.noSmoothClosing) root.active = false;
            else closeAnim.start();
        }

        function grabFocus() {
            focusGrab.active = true;
        }

        implicitWidth: realContent.implicitWidth + (root.ambientShadowWidth * 2) + (root.visualMargin * 2)
        implicitHeight: realContent.implicitHeight + (root.ambientShadowWidth * 2) + (root.visualMargin * 2)

        property real sourceEdgeMargin: -implicitHeight
        ParallelAnimation {
            id: openAnim
            PropertyAnimation {
                target: popupWindow
                property: "sourceEdgeMargin"
                to: (root.ambientShadowWidth + root.visualMargin)
                duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
            NumberAnimation {
                target: realContent
                property: "opacity"
                to: 1
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
            }
            NumberAnimation {
                target: realContent
                property: "scale"
                to: 1
                duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.popIn
            }
        }
        SequentialAnimation {
            id: closeAnim
            ParallelAnimation {
                PropertyAnimation {
                    target: popupWindow
                    property: "sourceEdgeMargin"
                    to: -implicitHeight
                    duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.accelerate
                }
                NumberAnimation {
                    target: realContent
                    property: "opacity"
                    to: 0
                    duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                }
                NumberAnimation {
                    target: realContent
                    property: "scale"
                    to: 0.98
                    duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.popOut
                }
            }
            ScriptAction {
                script: {
                    root.active = false;
                }
            }
        }

        color: "transparent"
        
        WAmbientShadow {
            target: realContent
        }
        
        Rectangle {
            id: realContent
            z: 1
            opacity: 0
            scale: 0.98
            anchors {
                left: parent.left
                right: parent.right
                top: root.barAtBottom ? undefined : parent.top
                bottom: root.barAtBottom ? parent.bottom : undefined
                margins: root.ambientShadowWidth + root.visualMargin
                // Opening anim
                bottomMargin: root.barAtBottom ? popupWindow.sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                topMargin: root.barAtBottom ? (root.ambientShadowWidth + root.visualMargin) : popupWindow.sourceEdgeMargin
            }
            color: Looks.colors.bg1Base
            radius: Looks.radius.large

            implicitWidth: root.contentItem.implicitWidth + (root.padding * 2)
            implicitHeight: root.contentItem.implicitHeight + (root.padding * 2)

            children: [root.contentItem]
        }
        
        // Hover detection for auto-close - uses HoverHandler which doesn't block events
        HoverHandler {
            id: popupHoverHandler
        }
        property alias popupHoverArea: popupHoverHandler  // Alias for compatibility
        // Expose containsMouse for the timer
        readonly property bool popupContainsMouse: popupHoverHandler.hovered
        
        // Fullscreen transparent backdrop for Niri to detect clicks outside
        // Uses WlrLayer.Top so it's below the popup (Overlay) but above normal windows
        PanelWindow {
            id: clickOutsideBackdrop
            visible: false
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:barPopupBackdrop"
            
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.close();
                }
            }
        }
    }
}
