pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

// Industrial stat row for ZZZ surfaces: label + numeric readout + segmented
// rail. Pure QML rectangles, no timers, no shader/FBO cost.
Rectangle {
    id: root

    property string label: ""
    property real value: 0
    property string valueText: `${Math.round(Math.max(0, Math.min(1, value)) * 100)}%`
    property color fillColor: Appearance.zzz.metricFill
    property color trackColor: Appearance.zzz.metricTrack
    property color textColor: Appearance.zzz.ink
    property color labelColor: Appearance.zzz.inkMuted
    property int segments: 18

    Layout.fillWidth: true
    implicitHeight: Math.max(34, row.implicitHeight + 12)
    radius: Appearance.zzz.cornerRadius
    color: ColorUtils.transparentize(Appearance.zzz.paperAlt, 0.10)
    border.width: 1
    border.color: Appearance.zzz.hairline
    clip: true
    // Organic morph on style/shape switch (organic-transitions)
    Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.label.toUpperCase()
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Black
                    color: root.labelColor
                    elide: Text.ElideRight
                }
                StyledText {
                    text: root.valueText
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Black
                    font.italic: true
                    color: root.fillColor
                }
            }

            Row {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: root.segments
                    Rectangle {
                        required property int index
                        readonly property real threshold: (index + 1) / Math.max(1, root.segments)
                        width: Math.max(3, (row.width - (root.segments - 1) * 2 - 20) / root.segments)
                        height: 4
                        radius: 1
                        color: Math.max(0, Math.min(1, root.value)) >= threshold ? root.fillColor : root.trackColor
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }
    }

    // Left accent bar. `clip: true` above only clips to root's bounding box,
    // not its rounded silhouette, so a square-cornered rectangle here would
    // poke past the rounded top-left/bottom-left corners as a stray straight
    // edge. Matching left-side radii keeps it inside the actual curve.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: root.fillColor
        topLeftRadius: root.radius
        bottomLeftRadius: root.radius
    }
}
