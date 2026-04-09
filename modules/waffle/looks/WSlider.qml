pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

Slider {
    id: root

    property real trackWidth: 4
    property string tooltipContent: `${Math.round(value * 100)}`
    property bool scrollable: false
    property bool _userInteracting: false
    stepSize: 0.02
    leftPadding: 0
    rightPadding: 0

    Timer {
        id: _userInteractingReset
        interval: 180
        repeat: false
        onTriggered: root._userInteracting = false
    }

    implicitHeight: handle.implicitHeight

    // No animation on value - instant response to user input
    // External changes (volume changed by other app) also instant, which is fine

    background: MouseArea {
        id: background
        anchors.fill: parent

        onWheel: (event) => {
            if (!root.scrollable) {
                event.accepted = false;
                return;
            }
            root._userInteracting = true
            _userInteractingReset.restart()

            const step = root.stepSize > 0 ? root.stepSize : 0.02
            if (event.angleDelta.y > 0) {
                root.value = Math.min(root.value + step, root.to)
                root.moved()
            } else {
                root.value = Math.max(root.value - step, root.from)
                root.moved()
            }
        }

        Rectangle {
            id: trackHighlight
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            topLeftRadius: root.trackWidth / 2
            bottomLeftRadius: root.trackWidth / 2
            color: Looks.colors.accent
            implicitHeight: root.pressed ? root.trackWidth + 2 : root.trackWidth
            width: background.width * root.visualPosition
            
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on color {
                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }

        Rectangle {
            id: trackTrough
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            topRightRadius: root.trackWidth / 2
            bottomRightRadius: root.trackWidth / 2
            color: Looks.colors.controlBg
            implicitHeight: root.pressed ? root.trackWidth + 2 : root.trackWidth
            width: background.width * (1 - root.visualPosition)
            
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    handle: Circle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: (diameter / 2) + root.visualPosition * (root.width - diameter) - (diameter / 2)
        diameter: 20
        color: Looks.colors.controlFg

        MouseArea {
            id: handleMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Circle {
            anchors.centerIn: parent
            diameter: root.pressed ? 10 : handleMouseArea.containsMouse ? 14 : 12
            color: Looks.colors.accent

            Behavior on diameter {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
            }
        }

        WToolTip {
            id: tooltip
            extraVisibleCondition: root.pressed
            text: root.tooltipContent
            font.pixelSize: Looks.font.pixelSize.larger
            font.features: { "tnum": 1 }
            verticalPadding: 3
            horizontalPadding: 8
        }
    }
}
