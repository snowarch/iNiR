import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Translation of Player.kt ResizableIconButton — a flat 32dp icon button with an
// M3 state layer (hover/press) and an optional active pill for toggle states.
Item {
    id: root
    property string symbol: ""
    property color color: Appearance.colors.colOnSurface
    property color activeColor: Appearance.colors.colOnSecondaryContainer
    property color activeBackground: Appearance.colors.colSecondaryContainer
    property bool active: false
    property bool enabled: true
    property int iconSize: 32
    implicitHeight: 48
    implicitWidth: 48

    signal clicked()

    // Active pill (toggle state, e.g. shuffle/repeat on) — grows from the center.
    Rectangle {
        anchors.centerIn: parent
        width: root.active ? parent.width : 0
        height: root.active ? parent.height : 0
        radius: Math.min(width, height) / 2
        color: root.activeBackground
        opacity: root.active ? 1 : 0
        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.calcEffectiveDuration(Appearance.animation.elementResize.duration)
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
        Behavior on height {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.calcEffectiveDuration(Appearance.animation.elementResize.duration)
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    // M3 state layer — the press/hover feedback that was missing.
    Rectangle {
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: width / 2
        color: root.active ? root.activeColor : root.color
        opacity: !root.enabled ? 0 : (mouseArea.pressed ? 0.14 : (mouseArea.containsMouse ? 0.08 : 0))
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.symbol
        iconSize: root.iconSize
        color: root.enabled ? (root.active ? root.activeColor : root.color) : Appearance.colors.colOutline
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
