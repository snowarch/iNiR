pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: pointer
    property bool grabbing: false
    property int travel: 560
    width: Math.round(22 * IrisStyle.density)
    height: width
    z: 50
    function click(): void { pointerRing.width = 0; pointerRing.opacity = 1; pointerPulse.restart() }
    Behavior on x { NumberAnimation { duration: IrisStyle.duration(pointer.travel); easing.type: Easing.InOutCubic } }
    Behavior on y { NumberAnimation { duration: IrisStyle.duration(pointer.travel); easing.type: Easing.InOutCubic } }
    Rectangle {
        id: pointerRing
        anchors.centerIn: parent
        width: 0
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: IrisStyle.accent
        opacity: 0
    }
    ParallelAnimation {
        id: pointerPulse
        NumberAnimation { target: pointerRing; property: "width"; to: pointer.width * 1.7; duration: IrisStyle.duration(320); easing.type: Easing.OutCubic }
        NumberAnimation { target: pointerRing; property: "opacity"; to: 0; duration: IrisStyle.duration(420); easing.type: Easing.InQuad }
    }
    MaterialSymbol {
        anchors.centerIn: parent
        text: pointer.grabbing ? "back_hand" : "arrow_selector_tool"
        fill: 1
        iconSize: pointer.width
        color: "white"
    }
}
