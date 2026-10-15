import QtQuick
import qs.modules.common

/**
 * Toggle switch: tile bg off, terracotta fill on, cream knob slides on the
 * fast motion token. Shared by the link surface and its WLAN/Bluetooth
 * drill-ins.
 */
Rectangle {
    id: toggle

    property real s: 1
    property bool on: false
    signal toggled()

    width: 28 * s
    height: 16 * s
    radius: 999
    color: on ? PillTheme.verm : PillTheme.tileBg
    border.width: on ? 0 : 1
    border.color: PillTheme.border

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 10 * toggle.s
        height: 10 * toggle.s
        radius: width / 2
        color: PillTheme.cream
        x: toggle.on ? toggle.width - width - 3 * toggle.s : 3 * toggle.s
        Behavior on x { NumberAnimation { duration: PillMotion.fast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
