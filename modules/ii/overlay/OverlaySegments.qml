pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Rectangle {
    id: root

    property var segments: []
    property int currentIndex: 0
    signal activated(int index)
    readonly property real d: IrisStyle.density
    readonly property real segmentWidth: (root.width - 4) / Math.max(1, root.segments.length)

    implicitHeight: Math.round(32 * root.d)
    radius: height / 2
    color: IrisStyle.fillQuiet

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1
            root.activated(Math.max(0, Math.min(root.segments.length - 1, root.currentIndex + step)))
        }
    }

    Rectangle {
        y: 2
        height: parent.height - 4
        width: root.segmentWidth
        x: 2 + root.segmentWidth * Math.max(0, root.currentIndex)
        radius: height / 2
        color: IrisStyle.fillHover
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 2
        Repeater {
            model: root.segments
            MouseArea {
                id: segment
                required property var modelData
                required property int index
                readonly property bool selected: root.currentIndex === segment.index
                width: root.segmentWidth
                height: root.height - 4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.RadioButton
                Accessible.name: Translation.tr(segment.modelData.label)
                Accessible.checked: segment.selected
                onClicked: root.activated(segment.index)
                Row {
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.d)
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.glyph ?? ""
                        visible: text.length > 0
                        iconSize: Math.round(16 * root.d)
                        fill: segment.selected ? 1 : 0
                        color: segment.selected ? IrisStyle.accent : segment.containsMouse ? IrisStyle.text : IrisStyle.textSecondary
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr(segment.modelData.label)
                        color: segment.selected || segment.containsMouse ? IrisStyle.text : IrisStyle.textSecondary
                        font.pixelSize: 12.5 * IrisStyle.typeScale
                        font.weight: segment.selected ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }
}
