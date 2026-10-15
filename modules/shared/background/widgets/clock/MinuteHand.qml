pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick

Item {
    id: root
    anchors.fill: parent

    required property int clockMinute
    property string style: "medium"
    property real handLength: 95
    property real handWidth: style === "bold" ? 20 : style === "medium" ? 12 : 5
    property color color: Appearance.colors.colTertiary

    rotation: -90 + (360 / 60) * root.clockMinute
    Behavior on rotation {
        animation: RotationAnimation {
            direction: RotationAnimation.Clockwise
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: {
            let position = parent.width / 2 - root.handWidth / 2;
            if (root.style === "classic") position -= 15;
            return position;
        }
        width: root.handLength
        height: root.handWidth
        
        radius: root.style === "classic" ? 2 : root.handWidth / 2
        color: root.color

        Behavior on height {
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        Behavior on x {
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
    }
}
