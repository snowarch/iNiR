pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
// An on/off option in a widget's quick controls: a row with its glyph, its name and a switch. The
// whole row toggles. A choice between values is WidgetQuickChoices, never a lit capsule.
Rectangle {
    id: root

    property string iconName: ""
    property string label: ""
    property bool checked: false
    signal toggled()

    readonly property var look: DesktopWidgetLook.look
    readonly property real d: root.look.density

    opacity: root.enabled ? 1 : 0.45
    implicitWidth: Math.round(200 * root.d)
    implicitHeight: Math.round(38 * root.d)
    radius: root.look.rowRadius
    color: root.look.rowFill(hover.hovered)
    Behavior on color {
        enabled: FamilyStyle.motionEnabled
        ColorAnimation { duration: root.look.feedbackDuration }
    }

    MaterialSymbol {
        id: glyph
        visible: root.iconName.length > 0
        anchors.left: parent.left
        anchors.leftMargin: Math.round(11 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        text: root.iconName
        fill: root.checked ? 1 : 0
        iconSize: Math.round(17 * root.d)
        color: root.checked ? root.look.controlInk : FamilyStyle.textSecondary
    }
    StyledText {
        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: Math.round((glyph.visible ? 9 : 12) * root.d)
        anchors.right: switchSlot.left
        anchors.rightMargin: Math.round(8 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: root.look.controlInk
        font.family: FamilyStyle.fontMain
        font.pixelSize: root.look.labelSize
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    Item {
        anchors.left: parent.left
        anchors.right: switchSlot.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: answer.restart() }
    }

    Item {
        id: switchSlot
        anchors.right: parent.right
        anchors.rightMargin: Math.round(9 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        width: familySwitch.url.length > 0 ? familySwitch.width : materialSwitch.width
        height: familySwitch.url.length > 0 ? familySwitch.height : materialSwitch.height

        FamilyPart {
            id: familySwitch
            visible: familySwitch.url.length > 0
            anchors.centerIn: parent
            part: "control.switch"
            props: ({ on: root.checked, name: root.label })
            Connections {
                target: familySwitch.item
                function onToggled(): void { answer.restart() }
            }
        }
        StyledSwitch {
            id: materialSwitch
            visible: familySwitch.url.length === 0
            anchors.centerIn: parent
            checked: root.checked
            onClicked: {
                answer.restart()
                materialSwitch.checked = Qt.binding(() => root.checked)
            }
        }
    }

    // Answered after the tap returns, so a row rebuilt by its own change never dies inside the click.
    Timer { id: answer; interval: 0; onTriggered: root.toggled() }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.label
    Accessible.checked: root.checked
}
