pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components

// One Character preset as a miniature of what it makes a surface: corners, fill and figure contrast.
MouseArea {
    id: tile
    readonly property real d: IrisStyle.density
    required property string name
    readonly property var values: IrisStyle.presets[tile.name] ?? IrisStyle.presets.iris
    readonly property bool selected: IrisStyle.presetName === tile.name
    implicitHeight: Math.round(62 * tile.d)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.RadioButton
    Accessible.name: tile.name
    Accessible.checked: tile.selected
    onClicked: Config.setNestedValue("iris.appearance.preset", tile.name)
    Rectangle {
        id: miniature
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(40 * tile.d)
        radius: Math.round(12 * tile.values.shape * tile.d)
        color: IrisStyle.surfaceOpaque
        border.width: tile.selected ? 2 : 1
        border.color: tile.selected ? IrisStyle.accent : (tile.containsMouse ? IrisStyle.borderStrong : IrisStyle.border)
        Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        Column {
            anchors.fill: parent
            anchors.margins: Math.round(7 * tile.d)
            spacing: Math.round(4 * tile.d)
            Rectangle {
                width: parent.width
                height: Math.round(13 * tile.d)
                radius: Math.round(6 * tile.values.shape * tile.d)
                color: Qt.alpha(IrisStyle.text, Math.min(0.5, 0.12 * tile.values.fill))
            }
            Row {
                spacing: Math.round(4 * tile.d)
                Rectangle { width: Math.round(16 * tile.d); height: Math.round(8 * tile.d); radius: height / 2; color: IrisStyle.accent }
                Rectangle { width: Math.round(22 * tile.d); height: Math.round(8 * tile.d); radius: height / 2; color: Qt.alpha(IrisStyle.text, tile.values.textTertiary) }
            }
        }
    }
    IrisText {
        anchors.top: miniature.bottom
        anchors.topMargin: Math.round(4 * tile.d)
        anchors.horizontalCenter: parent.horizontalCenter
        text: Translation.tr(tile.name.charAt(0).toUpperCase() + tile.name.slice(1))
        color: tile.selected ? IrisStyle.text : IrisStyle.subtext
        font.pixelSize: IrisStyle.typeFootnote
        font.weight: tile.selected ? Font.DemiBold : Font.Normal
    }
}
