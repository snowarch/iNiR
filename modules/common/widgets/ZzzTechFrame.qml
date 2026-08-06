pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

// ZZZ technical overlay: corner registration marks, faint engineering grid,
// manual labels and scan ticks. It draws no delegates when ZZZ is inactive.
Item {
    id: root

    anchors.fill: parent

    property string label: ""
    property string index: ""
    property bool showGrid: false
    property bool showCornerMarks: false
    property bool showLabels: false
    property bool showTicks: false // scan ticks read as stray marks; opt-in only
    property int gridSpacing: 56
    property int margin: 14
    property color accentColor: Appearance.zzz.technicalMarker
    property color lineColor: Appearance.zzz.technicalGrid
    property color strongLineColor: Appearance.zzz.technicalGridStrong

    readonly property bool active: Appearance.zzzEverywhere
    readonly property int verticalCount: active && showGrid ? Math.ceil(width / Math.max(1, gridSpacing)) + 1 : 0
    readonly property int horizontalCount: active && showGrid ? Math.ceil(height / Math.max(1, gridSpacing)) + 1 : 0

    visible: opacity > 0
    opacity: active ? 1 : 0
    clip: true

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Repeater {
        model: root.verticalCount
        Rectangle {
            required property int index
            x: index * root.gridSpacing
            y: 0
            width: 1
            height: root.height
            color: root.lineColor
        }
    }

    Repeater {
        model: root.horizontalCount
        Rectangle {
            required property int index
            x: 0
            y: index * root.gridSpacing
            width: root.width
            height: 1
            color: root.lineColor
        }
    }

    component CornerMark: Item {
        id: mark
        property bool alignRight: false
        property bool alignBottom: false
        width: Appearance.zzz.markerLength
        height: Appearance.zzz.markerLength
        visible: root.active && root.showCornerMarks

        Rectangle {
            width: parent.width
            height: Appearance.zzz.markerThickness
            y: mark.alignBottom ? parent.height - height : 0
            color: root.accentColor
        }
        Rectangle {
            width: Appearance.zzz.markerThickness
            height: parent.height
            x: mark.alignRight ? parent.width - width : 0
            color: root.accentColor
        }
    }

    CornerMark {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: root.margin
    }
    CornerMark {
        alignRight: true
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.margin
    }
    CornerMark {
        alignBottom: true
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: root.margin
    }
    CornerMark {
        alignRight: true
        alignBottom: true
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.margin
    }

    Rectangle {
        id: labelRail
        visible: root.active && root.showLabels && (root.label.length > 0 || root.index.length > 0)
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.margin + Appearance.zzz.markerLength + 8
        anchors.topMargin: root.margin + 2
        z: 4
        width: labelRow.implicitWidth + 12
        height: labelRow.implicitHeight + 5
        radius: Appearance.zzz.cornerRadius
        color: ColorUtils.transparentize(Appearance.zzz.paperAlt, 0.07)
        border.width: 1
        border.color: root.strongLineColor

        RowLayout {
            id: labelRow
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 8

            StyledText {
                visible: root.index.length > 0
                text: root.index
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.numbers
                font.weight: Font.Black
                color: Appearance.zzz.technicalWarning
            }
            StyledText {
                visible: root.label.length > 0
                text: root.label.toUpperCase()
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Black
                color: root.accentColor
            }
        }
    }

    Repeater {
        model: root.active && root.showTicks ? 6 : 0
        Rectangle {
            required property int index
            width: index % 2 === 0 ? 12 : 7
            height: 1
            x: index % 2 === 0 ? root.margin : root.width - root.margin - width
            y: root.margin + Appearance.zzz.markerLength + 22 + index * 28
            color: index % 2 === 0 ? root.strongLineColor : root.accentColor
        }
    }

}
