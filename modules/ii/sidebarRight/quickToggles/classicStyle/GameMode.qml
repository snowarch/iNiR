import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: root
    buttonIcon: "gamepad"
    toggled: GameMode.active

    onClicked: {
        GameMode.toggle()
    }

    // Visual indicator when auto-detected
    Rectangle {
        visible: opacity > 0
        opacity: (GameMode.active && GameMode.autoDetect && !GameMode.manuallyActivated) ? 1 : 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        width: 8
        height: 8
        radius: Appearance.rounding.unsharpen
        color: Appearance.colors.colPrimary
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    StyledToolTip {
        text: GameMode.active 
            ? Translation.tr("Game mode") + " (" + Translation.tr("active") + ")"
            : Translation.tr("Game mode")
    }
}
