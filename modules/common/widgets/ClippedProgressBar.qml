import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * A progress bar with both ends rounded and text acts as clipping like OneUI 7's battery indicator.
 */
ProgressBar {
    id: root
    property bool vertical: false
    property real valueBarWidth: 30
    property real valueBarHeight: 18
    // ZZZ: use the lime/orange signal fill on a carbon track. The default
    // (colOnSecondaryContainer) resolves to near-black ink under ZZZ → invisible fill.
    property color highlightColor: Appearance.zzzEverywhere ? Appearance.zzz.metricFill
        : (Appearance.colors.colOnSecondaryContainer)
    property color trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
        : (ColorUtils.transparentize(highlightColor, 0.5))
    property alias radius: contentItem.radius
    property string text
    default property Item textMask: Item {
        width: valueBarWidth
        height: valueBarHeight
        StyledText {
            anchors.centerIn: parent
            font: root.font
            text: root.text
        }
    }

    text: Math.round(value * 100)
    font {
        pixelSize: 13
        weight: text.length > 2 ? Font.Medium : Font.DemiBold
    }

    Behavior on value {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Rectangle {
        id: contentItem
        anchors.fill: parent
        radius: Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Math.min(width, height) / 2
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        color: root.trackColor
        visible: false

        Rectangle {
            id: progressFill
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: undefined
            }
            width: parent.width * root.visualPosition
            height: parent.height

            states: State {
                name: "vertical"
                when: root.vertical
                AnchorChanges {
                    target: progressFill
                    anchors {
                        top: undefined
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                }
                PropertyChanges {
                    target: progressFill
                    width: parent.width
                    height: parent.height * root.visualPosition
                }
            }

            radius: Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
                : Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.unsharpen
            Behavior on radius {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            color: root.highlightColor

            Behavior on width {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on height {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }

    OpacityMask {
        id: roundingMask
        visible: false
        anchors.fill: parent
        source: contentItem
        maskSource: Rectangle {
            width: contentItem.width
            height: contentItem.height
            radius: contentItem.radius
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: roundingMask
        invert: true
        maskSource: root.textMask
    }
}
