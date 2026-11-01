pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
// One choice in a widget's quick controls. It sizes from its whole content with equal side padding,
// and in a grid it takes the cell's width and keeps its icon and label centred together.
// iRiS draws the Island's quiet fill with the accent on the chosen one; the ii family its Global Style.
Rectangle {
    id: root

    property string iconName: ""
    property string label: ""
    property bool selected: false
    property bool danger: false
    property string tooltip: ""
    signal clicked()

    readonly property var look: DesktopWidgetLook.look
    readonly property real d: root.look.density
    property real sidePadding: Math.round(12 * root.d)
    readonly property color ink: root.look.chipInk(root.selected)
    readonly property color dangerInk: FamilyStyle.danger
    readonly property color glyphInk: root.danger ? root.dangerInk : root.look.chipGlyphInk(root.selected)

    implicitWidth: content.implicitWidth + root.sidePadding * 2
    implicitHeight: Math.round(34 * root.d)
    radius: root.look.chipRadius(height)
    color: root.look.chipFill(root.selected, hover.hovered)
    border.width: root.selected ? root.look.chipEdge : 0
    border.color: root.look.chipEdgeColor
    scale: tap.pressed ? FamilyStyle.pressScale(0.97) : 1
    Behavior on color {
        enabled: FamilyStyle.motionEnabled
        ColorAnimation { duration: root.look.feedbackDuration }
    }
    Behavior on scale {
        enabled: FamilyStyle.motionEnabled
        NumberAnimation { duration: root.look.feedbackDuration }
    }

    Row {
        id: content
        readonly property real room: root.width - root.sidePadding * 2
        anchors.centerIn: parent
        spacing: root.iconName.length > 0 && root.label.length > 0 ? Math.round(6 * root.d) : 0

        MaterialSymbol {
            id: glyph
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconName
            fill: root.selected ? 1 : 0
            iconSize: Math.round(16 * root.d)
            color: root.glyphInk
        }
        StyledText {
            visible: root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Math.ceil(implicitWidth), Math.max(0, content.room - (glyph.visible ? glyph.width + content.spacing : 0)))
            text: root.label
            elide: Text.ElideRight
            color: root.danger ? root.dangerInk : root.ink
            font.family: FamilyStyle.fontMain
            font.pixelSize: root.look.labelSize
            font.weight: root.selected ? Font.DemiBold : Font.Medium
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: answer.restart() }
    // Answered after the tap returns: a pick can rebuild the rows this cell lives in, and a cell
    // destroyed inside its own tap swallows the next click.
    Timer { id: answer; interval: 0; onTriggered: root.clicked() }
    StyledToolTip { text: root.tooltip; extraVisibleCondition: hover.hovered && root.tooltip.length > 0 }
    Accessible.role: Accessible.RadioButton
    Accessible.name: root.label
    Accessible.checked: root.selected
}
