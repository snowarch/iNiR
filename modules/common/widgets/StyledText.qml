import qs.modules.common
import QtQuick

Text {
    id: root
    property bool animateChange: false
    property real animationDistanceX: 0
    property real animationDistanceY: 6

    property real _slideX: 0
    property real _slideY: 0
    Translate {
        id: slideTransform
        x: root._slideX
        y: root._slideY
    }
    transform: root.animateChange ? [slideTransform] : []

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    property bool shouldUseNumberFont: /^\d+$/.test(root.text)
    property var defaultFont: shouldUseNumberFont ? Appearance.font.family.numbers : Appearance.font.family.main
    
    font {
        hintingPreference: Font.PreferDefaultHinting
        family: defaultFont
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        variableAxes: shouldUseNumberFont ? ({}) : Appearance.font.variableAxes.main
        // ZZZ poster crispness: a small global letter-spacing under the zzz style
        // (token-driven, absolute px). Numbers stay untracked so digit columns
        // don't drift. Other styles unaffected (0).
        letterSpacing: (Appearance?.zzzEverywhere && !root.shouldUseNumberFont)
            ? (Appearance?.zzz.tracking ?? 0)
            : (Appearance?.regaliaEverywhere && !root.shouldUseNumberFont) ? 0.12 : 0
    }
    color: Appearance?.colors.colOnLayer0 ?? "black"
    linkColor: Appearance?.colors.colPrimary

    component Anim: NumberAnimation {
        target: root
        duration: 300 / 2
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }

    Behavior on text {
        enabled: root.animateChange

        SequentialAnimation {
            alwaysRunToEnd: true

            ParallelAnimation {
                Anim {
                    property: "_slideX"
                    to: -root.animationDistanceX
                    easing.type: Easing.InSine
                }
                Anim {
                    property: "_slideY"
                    to: -root.animationDistanceY
                    easing.type: Easing.InSine
                }
                Anim {
                    property: "opacity"
                    to: 0
                    easing.type: Easing.InSine
                }
            }
            PropertyAction {} // Tie the text update to this point (we don't want it to happen during the first slide+fade)
            PropertyAction {
                target: root
                property: "_slideX"
                value: root.animationDistanceX
            }
            PropertyAction {
                target: root
                property: "_slideY"
                value: root.animationDistanceY
            }
            ParallelAnimation {
                Anim {
                    property: "_slideX"
                    to: 0
                    easing.type: Easing.OutSine
                }
                Anim {
                    property: "_slideY"
                    to: 0
                    easing.type: Easing.OutSine
                }
                Anim {
                    property: "opacity"
                    to: 1
                    easing.type: Easing.OutSine
                }
            }
        }
    }
}
