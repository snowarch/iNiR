pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// One choice of a few, side by side: the family's own segmented control when it has one, a pill track otherwise.
// `options`: [{ value, label, glyph }], labels untranslated.
Item {
    id: root

    property var options: []
    property var current
    property string accessibleName: ""
    signal picked(var value)

    readonly property real d: OverlayLook.d
    readonly property int selectedIndex: root.options.findIndex(option => option.value === root.current)
    readonly property real slot: (root.width - 4) / Math.max(1, root.options.length)

    implicitHeight: familySegmented.url.length > 0 ? familySegmented.implicitHeight : Math.round(30 * root.d)
    implicitWidth: Math.round(200 * root.d)

    FamilyPart {
        id: familySegmented
        anchors.fill: parent
        part: "control.segmented"
        props: ({ options: root.options, current: root.current, accessibleName: root.accessibleName })
        Connections {
            target: familySegmented.item
            function onPicked(value: var): void { root.picked(value) }
        }
    }

    Rectangle {
        id: track
        visible: familySegmented.url.length === 0
        anchors.fill: parent
        radius: height / 2
        color: OverlayLook.colRecessed

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const step = event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1
                const next = Math.max(0, Math.min(root.options.length - 1, root.selectedIndex + step))
                if (next !== root.selectedIndex) root.picked(root.options[next].value)
            }
        }

        Rectangle {
            visible: root.selectedIndex >= 0
            y: 2
            height: parent.height - 4
            width: root.slot
            x: 2 + root.slot * Math.max(0, root.selectedIndex)
            radius: height / 2
            color: OverlayLook.colToggle
            Behavior on x { NumberAnimation { duration: FamilyStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.morphCurve } }
        }

        Row {
            id: segmentRow
            anchors.fill: parent
            anchors.margins: 2
            Repeater {
                model: root.options
                MouseArea {
                    id: segment
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.selectedIndex === segment.index
                    readonly property color ink: segment.selected ? OverlayLook.colOnToggle
                        : segment.containsMouse ? OverlayLook.colOnLayer1 : OverlayLook.colSubtext
                    width: root.slot
                    height: segmentRow.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: Translation.tr(String(segment.modelData.label ?? ""))
                    Accessible.checked: segment.selected
                    onClicked: root.picked(segment.modelData.value)
                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(5 * root.d)
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(segment.modelData.glyph ?? "")
                            visible: text.length > 0
                            iconSize: Math.round(15 * root.d)
                            fill: segment.selected ? 1 : 0
                            color: segment.ink
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, segment.width - Math.round((String(segment.modelData.glyph ?? "").length > 0 ? 30 : 8) * root.d))
                            elide: Text.ElideRight
                            text: Translation.tr(String(segment.modelData.label ?? ""))
                            color: segment.ink
                            font.family: OverlayLook.fontMain
                            font.pixelSize: OverlayLook.typeMeta
                            font.weight: segment.selected ? Font.DemiBold : Font.Medium
                        }
                    }
                }
            }
        }
    }
}
