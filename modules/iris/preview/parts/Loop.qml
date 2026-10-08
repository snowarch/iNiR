pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

SequentialAnimation {
    id: loop
    property real rest: 1400
    loops: Animation.Infinite
    NumberAnimation { to: 1; duration: IrisStyle.duration(IrisStyle.settleDuration * 2); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve }
    PauseAnimation { duration: loop.rest }
    NumberAnimation { to: 0; duration: IrisStyle.duration(IrisStyle.recedeDuration * 2); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.recedeCurve }
    PauseAnimation { duration: loop.rest / 3 }
}
