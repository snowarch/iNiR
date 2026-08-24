pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.waffle.looks

Item {
    id: root

    property var options: []    // [{value: "x", label: "Label", icon: ""}, ...]
    property var currentValue
    property int columns: 3
    property int rowSpacing: Looks.dp(8)
    property int columnSpacing: Looks.dp(8)

    signal selected(var newValue)

    // Row controls need the grid's intrinsic width.
    Layout.fillWidth: true
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors.fill: parent
        columns: root.columns
        columnSpacing: root.columnSpacing
        rowSpacing: root.rowSpacing

        Repeater {
            model: root.options

            Rectangle {
                id: chip
                required property var modelData

                readonly property bool checked: root.currentValue === modelData.value
                readonly property string chipIcon: modelData.icon ?? ""

                Layout.fillWidth: true
                implicitWidth: chipRow.implicitWidth + Looks.dp(24)
                implicitHeight: Looks.dp(36)
                radius: Looks.settings.radiusLarge
                color: {
                    if (chip.checked)
                        return chipMa.pressed ? Qt.darker(Looks.colors.accent, 1.12) : Looks.colors.accent
                    if (chipMa.pressed)
                        return Looks.settings.tilePressed
                    if (chipMa.containsMouse)
                        return Looks.settings.tileHover
                    return Looks.settings.tile
                }
                border.width: 1
                border.color: chip.checked
                    ? Looks.colors.accent : Looks.settings.stroke

                Behavior on color {
                    animation: ColorAnimation {
                        duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                    }
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(chip.modelData.value)
                }

                RowLayout {
                    id: chipRow
                    anchors {
                        fill: parent
                        leftMargin: Looks.dp(12)
                        rightMargin: Looks.dp(12)
                    }
                    spacing: Looks.dp(8)

                    FluentIcon {
                        visible: chip.chipIcon !== ""
                        icon: chip.chipIcon
                        implicitSize: Looks.dp(15)
                        color: chip.checked ? Looks.colors.accentFg : Looks.colors.subfg
                    }

                    WText {
                        Layout.fillWidth: true
                        text: chip.modelData.label ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: chip.checked ? Looks.font.weight.strong : Looks.font.weight.regular
                        color: chip.checked ? Looks.colors.accentFg : Looks.colors.fg
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
