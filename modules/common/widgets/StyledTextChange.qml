import QtQuick
import qs.modules.common

// The slide-and-fade a StyledText runs when its text changes, built only for the texts that animate a change.
SequentialAnimation {
    id: change
    required property Text text
    readonly property Translate slide: Translate {
        x: change.text._slideX
        y: change.text._slideY
    }
    alwaysRunToEnd: true

    component Anim: NumberAnimation {
        target: change.text
        duration: Appearance.animation.elementMoveFast.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }

    ParallelAnimation {
        Anim { property: "_slideX"; to: -change.text.animationDistanceX; easing.type: Easing.InSine }
        Anim { property: "_slideY"; to: -change.text.animationDistanceY; easing.type: Easing.InSine }
        Anim { property: "opacity"; to: 0; easing.type: Easing.InSine }
    }
    PropertyAction {} // Tie the text update to this point (we don't want it to happen during the first slide+fade)
    PropertyAction { target: change.text; property: "_slideX"; value: change.text.animationDistanceX }
    PropertyAction { target: change.text; property: "_slideY"; value: change.text.animationDistanceY }
    ParallelAnimation {
        Anim { property: "_slideX"; to: 0; easing.type: Easing.OutSine }
        Anim { property: "_slideY"; to: 0; easing.type: Easing.OutSine }
        Anim { property: "opacity"; to: 1; easing.type: Easing.OutSine }
    }
}
