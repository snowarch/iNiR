pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

// A scene's cycle: what it shows emerges, holds, recedes. Stopped (the scene goes to rest), it finishes its cycle and
// stays on what it shows: the cycle ends on the hold, never halfway.
SequentialAnimation {
    id: loop
    property real rest: 1400
    loops: Animation.Infinite
    alwaysRunToEnd: true
    NumberAnimation { to: 0; duration: IrisStyle.duration(IrisStyle.recedeDuration * 2); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.recedeCurve }
    PauseAnimation { duration: loop.rest / 3 }
    NumberAnimation { to: 1; duration: IrisStyle.duration(IrisStyle.settleDuration * 2); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve }
    PauseAnimation { duration: loop.rest }
}
