pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

// ZZZ data chip / black capsule label. Encodes the reference's "black capsule
// labels + small data chips": an uppercase condensed key with an optional value
// readout. Pure typography + plate, no interactivity. Drop into dense ZZZ headers,
// stat rows, or card corners.
Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property color accentColor: Appearance.zzz.accent
    // "plate" (neutral carbon chip) or "signal" (filled accent capsule)
    property string emphasis: "plate"
    readonly property bool _signal: root.emphasis === "signal"

    implicitWidth: row.implicitWidth + 18
    implicitHeight: Math.max(20, row.implicitHeight + 8)
    radius: Appearance.zzz.cornerRadius
    color: root._signal ? root.accentColor : Appearance.zzz.contrastPlate
    border.width: Appearance.zzz.borderThick
    border.color: root._signal ? root.accentColor : Appearance.zzz.hairlineStrong
    clip: true
    // Organic morph (organic-transitions) — emphasis flip + shape morph
    Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle { // category marker tick
            Layout.alignment: Qt.AlignVCenter
            visible: !root._signal
            implicitWidth: Appearance.zzz.borderThick
            implicitHeight: Math.round(root.height * 0.5)
            color: root.accentColor
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.label.toUpperCase()
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Black
            color: root._signal ? Appearance.zzz.onAccent : Appearance.zzz.onContrastPlate
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.value.length > 0
            text: root.value
            font.family: Appearance.font.family.numbers
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Black
            font.italic: true
            color: root._signal ? Appearance.zzz.onAccent : root.accentColor
        }
    }
}
