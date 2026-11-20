import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * PlayKey - One play/pause key: a circle when paused, a square when playing.
 */
Item {
    id: root

    property bool isPlaying: false
    property color color: Appearance.colors.colPrimary
    property int size: 40
    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size

    MaterialShape {
        anchors.fill: parent
        implicitSize: root.size
        shape: root.isPlaying ? MaterialShape.Shape.Square : MaterialShape.Shape.Circle
        color: root.color
        scale: tap.pressed ? 0.90 : (tap.containsMouse ? 1.06 : 1.0)
        Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 150 } }
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.isPlaying ? "pause" : "play_arrow"
            fill: 1
            iconSize: Math.round(root.size * 0.55)
            color: ColorUtils.contrastColor(root.color)
        }
    }
    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
