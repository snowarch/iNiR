pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

// The pages of a widget's quick controls under Material: one row of connected buttons on a tonal track (M3
// Expressive), the chosen one filled and rounded out, sliding between them.
Rectangle {
    id: root

    property var model: []
    property var current: undefined
    signal picked(var value)

    readonly property var entries: Array.from(root.model ?? []).filter(entry => entry && entry.visible !== false)
    readonly property int chosenIndex: Math.max(0, root.entries.findIndex(entry => entry.value === root.current))
    readonly property real inset: 4
    readonly property real cell: root.entries.length > 0 ? (root.width - 2 * root.inset) / root.entries.length : 0

    Layout.fillWidth: true
    implicitHeight: 44
    radius: height / 2
    color: Appearance.colors.colLayer2

    Rectangle {
        x: root.inset + root.cell * root.chosenIndex
        y: root.inset
        width: root.cell
        height: root.height - 2 * root.inset
        radius: height / 2
        color: Appearance.colors.colPrimary
        visible: root.entries.length > 0
        Behavior on x { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial } }
    }
    Row {
        x: root.inset
        y: root.inset
        Repeater {
            model: root.entries
            delegate: RippleButton {
                id: tab
                required property var modelData
                required property int index
                readonly property bool chosen: tab.index === root.chosenIndex
                width: root.cell
                height: root.height - 2 * root.inset
                buttonRadius: height / 2
                colBackground: "transparent"
                colBackgroundHover: tab.chosen ? "transparent" : Appearance.colors.colLayer2Hover
                colRipple: tab.chosen ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active
                Accessible.name: tab.modelData.label ?? ""
                onClicked: root.picked(tab.modelData.value)
                contentItem: StyledText {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tab.modelData.label ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: tab.chosen ? Font.DemiBold : Font.Medium
                    color: tab.chosen ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                    Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                }
            }
        }
    }
}
