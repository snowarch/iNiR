pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

/**
 * Mini-segmented choice control. `options` is a list of `{ label, value }`; the
 * pill whose value equals `value` lights with a flame tint. Picking a pill emits
 * `picked(value)`; selection keys off the source value, never a child's effective
 * visibility. The host passes `s` for scale.
 */
Rectangle {
    id: seg

    property real s: 1
    property var options: []
    property var value
    signal picked(var value)

    /**
     * When `flushLeft`, the control shifts left by the first option's text inset
     * so that text lines up with x=0 of where the control is placed, rather than
     * the pill edge sitting there.
     */
    property bool flushLeft: false

    readonly property real pad: 1
    readonly property real edgePad: seg.pad + 9 * seg.s

    x: seg.flushLeft ? -seg.edgePad : 0
    width: pills.implicitWidth + 2 * pad
    height: pills.implicitHeight + 2 * pad
    radius: 9 * seg.s
    color: "transparent"

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 2 * seg.s

        Repeater {
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: seg.value === modelData.value
                property bool hovered: false

                width: optLabel.implicitWidth + 18 * seg.s
                height: optLabel.implicitHeight + 12 * seg.s
                radius: 8 * seg.s
                color: opt.current ? Qt.alpha(PillTheme.onGlow, 0.16) : (opt.hovered ? PillTheme.frameBg : "transparent")
                Behavior on color { ColorAnimation { duration: PillMotion.fast } }

                Text {
                    id: optLabel
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.current ? PillTheme.cream : PillTheme.subtle
                    font.family: PillTheme.font
                    font.pixelSize: 10.5 * seg.s
                    font.weight: Font.Bold
                    font.letterSpacing: 0.3 * seg.s
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: opt.hovered = true
                    onExited: opt.hovered = false
                    onClicked: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
