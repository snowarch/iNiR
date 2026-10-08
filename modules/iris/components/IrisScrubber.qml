pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common.functions
import qs.modules.iris.style

Item {
    id: root

    property real value: 0
    property bool seekable: true
    property color fillColor: IrisStyle.fillStrong
    property color trackColor: IrisStyle.fill
    signal seekRequested(real value)
    signal moved(real value)
    property bool knob: false
    property real stepSize: 0.05
    activeFocusOnTab: root.seekable

    property real dragValue: -1
    readonly property bool dragging: pointer.pressed
    readonly property bool engaged: root.seekable && (pointer.containsMouse || pointer.pressed || root.activeFocus)
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))

    implicitWidth: 200
    implicitHeight: Math.round(14 * IrisStyle.density)

    Accessible.role: Accessible.Slider
    Keys.onPressed: event => {
        if (!root.seekable) return
        let next = root.shownValue
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += root.stepSize
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= root.stepSize
        else if (event.key === Qt.Key_Home) next = 0
        else if (event.key === Qt.Key_End) next = 1
        else return
        next = Math.max(0, Math.min(1, next))
        root.moved(next)
        root.seekRequested(next)
        event.accepted = true
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round((root.engaged ? 9 : 4) * IrisStyle.density)
        Behavior on height { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.trackColor
        }
        Item {
            width: track.width * root.shownValue
            height: track.height
            clip: true
            Rectangle {
                width: track.width
                height: track.height
                radius: height / 2
                color: root.fillColor
            }
        }
    }

    // The same thumb as the switch: white, lifted by a soft shadow instead of an outline.
    RectangularShadow {
        visible: root.knob
        anchors.fill: knobFace
        radius: knobFace.radius
        offset.y: IrisStyle.density
        blur: 3 * IrisStyle.density
        color: IrisStyle.shadow
    }
    Rectangle {
        id: knobFace
        visible: root.knob
        width: Math.round((root.engaged ? 20 : 18) * IrisStyle.density)
        height: width
        radius: width / 2
        x: Math.max(0, Math.min(root.width - width, root.width * root.shownValue - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: IrisStyle.onTint
        Behavior on width { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.seekable
        hoverEnabled: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function valueAt(px: real): real { return Math.max(0, Math.min(1, px / Math.max(1, width))) }
        onPressed: mouse => { root.forceActiveFocus(); root.dragValue = valueAt(mouse.x); root.moved(root.dragValue) }
        onPositionChanged: mouse => { wheelIntent.track(mouse.x, mouse.y); if (pressed) { root.dragValue = valueAt(mouse.x); root.moved(root.dragValue) } }
        onReleased: {
            if (root.dragValue >= 0) root.seekRequested(root.dragValue)
            root.dragValue = -1
        }
        onCanceled: {
            if (root.dragValue >= 0) root.seekRequested(root.dragValue)
            root.dragValue = -1
        }
        preventStealing: true
        property real wheelAccumulator: 0
        IrisWheelIntent { id: wheelIntent; hovered: pointer.containsMouse }
        onWheel: wheel => {
            if (!wheelIntent.take(wheel)) return
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
            pointer.wheelAccumulator += delta
            const steps = Math.trunc(pointer.wheelAccumulator / 120)
            if (steps === 0) return
            pointer.wheelAccumulator -= steps * 120
            const next = Math.max(0, Math.min(1, root.shownValue + steps * root.stepSize))
            root.moved(next)
            root.seekRequested(next)
        }
    }
}
