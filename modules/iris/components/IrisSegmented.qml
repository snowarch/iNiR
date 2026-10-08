pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

// One segmented control for iRiS: a quiet track, the chosen segment lifted off it as a thumb.
// options: [{ value, label, glyph?, swatch? }]. `pictured` stacks glyph over label in a taller
// tile; `glyphOnly` draws square glyph segments sized by the track height.
Rectangle {
    id: root

    property var options: []
    property var current
    property bool pictured: false
    property bool glyphOnly: false
    property string accessibleName: ""
    property var fontFor: null
    readonly property real d: IrisStyle.density
    readonly property int inset: 2
    readonly property int count: Math.max(1, root.options.length)
    readonly property int selectedIndex: root.options.findIndex(option => option.value === root.current)
    readonly property real slot: (root.width - 2 * root.inset) / root.count
    signal picked(var value)

    implicitHeight: Math.round((root.pictured ? 52 : root.glyphOnly ? 32 : 28) * root.d)
    implicitWidth: root.glyphOnly ? root.count * (root.implicitHeight - 2 * root.inset) + 2 * root.inset : 0
    readonly property real thumbRadius: root.pictured ? IrisStyle.radiusTile - root.inset
        : IrisStyle.controlPlated ? IrisStyle.pieceRadius(root.height - 2 * root.inset) : (root.height - 2 * root.inset) / 2
    radius: root.pictured ? IrisStyle.radiusTile : IrisStyle.controlPlated ? root.thumbRadius + root.inset : height / 2
    color: IrisStyle.controlPlated ? IrisStyle.plateFillFor(IrisStyle.controlPlate) : IrisStyle.fillQuiet

    IrisGlassEdge {
        anchors.fill: parent
        visible: (IrisStyle.controlPlate === "glass" || (IrisStyle.controlPlated && IrisStyle.edgeLit)) && shown
        radius: root.radius
    }

    function slotX(index: int): int {
        return root.inset + Math.round(index * root.slot)
    }

    RectangularShadow {
        visible: thumb.visible
        anchors.fill: thumb
        radius: thumb.radius
        offset.y: root.d
        blur: 3 * root.d
        color: IrisStyle.shadow
    }
    Rectangle {
        id: thumb
        visible: root.selectedIndex >= 0
        y: root.inset
        height: root.height - 2 * root.inset
        x: root.slotX(Math.max(0, root.selectedIndex))
        // From the target slot, not from the animating x: tied to x the thumb stretched past the new slot first.
        width: root.slotX(Math.max(0, root.selectedIndex) + 1) - root.slotX(Math.max(0, root.selectedIndex))
        radius: root.thumbRadius
        color: IrisStyle.raised
        Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
    }

    Repeater {
        model: root.options
        MouseArea {
            id: segment
            required property var modelData
            required property int index
            readonly property bool selected: root.selectedIndex === segment.index
            x: root.slotX(segment.index)
            y: root.inset
            width: root.slotX(segment.index + 1) - x
            height: root.height - 2 * root.inset
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: (root.accessibleName.length > 0 ? root.accessibleName + ": " : "") + Translation.tr(String(segment.modelData.label ?? ""))
            Accessible.checked: segment.selected
            Keys.onSpacePressed: root.picked(segment.modelData.value)
            Keys.onReturnPressed: root.picked(segment.modelData.value)
            onClicked: root.picked(segment.modelData.value)

            Rectangle {
                anchors.fill: parent
                radius: thumb.radius
                color: !segment.selected && segment.containsMouse ? IrisStyle.fillQuiet : "transparent"
                border.width: segment.activeFocus ? 1 : 0
                border.color: IrisStyle.accent
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            }
            MaterialSymbol {
                visible: root.glyphOnly
                anchors.centerIn: parent
                text: String(segment.modelData.glyph ?? "")
                fill: segment.selected ? 1 : 0
                iconSize: Math.round(16 * root.d)
                color: segment.selected ? IrisStyle.accent : IrisStyle.subtext
            }
            Column {
                visible: root.pictured
                anchors.centerIn: parent
                width: parent.width - Math.round(8 * root.d)
                spacing: Math.round(2 * root.d)
                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(segment.modelData.glyph ?? "")
                    iconSize: Math.round(20 * root.d)
                    fill: segment.selected ? 1 : 0
                    color: segment.selected ? IrisStyle.accent : IrisStyle.subtext
                }
                IrisText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr(String(segment.modelData.label ?? ""))
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(segment.selected ? Font.DemiBold : Font.Normal)
                    color: segment.selected ? IrisStyle.text : IrisStyle.subtext
                    elide: Text.ElideRight
                }
            }
            Row {
                visible: !root.pictured && !root.glyphOnly
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                Rectangle {
                    visible: String(segment.modelData.swatch ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(12 * root.d)
                    height: width
                    radius: width / 2
                    color: segment.modelData.swatch ?? "transparent"
                    border.width: 1
                    border.color: IrisStyle.borderStrong
                }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr(String(segment.modelData.label ?? ""))
                    font.family: root.fontFor ? root.fontFor(segment.modelData) : IrisStyle.fontMain
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(segment.selected ? Font.DemiBold : Font.Normal)
                    color: segment.selected ? IrisStyle.text : IrisStyle.subtext
                }
            }
        }
    }
}
