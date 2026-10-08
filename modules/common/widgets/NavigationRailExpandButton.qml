import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: 40
    implicitHeight: 40
    downAction: () => {
        parent.expanded = !parent.expanded;
    }
    buttonRadius: Appearance.editorialEverywhere ? Appearance.rounding.small : Appearance.rounding.full

    rotation: root.parent.expanded ? 0 : -180
    Behavior on rotation {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    contentItem: MaterialSymbol {
        id: icon
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        iconSize: 24
        color: Appearance.colors.colOnLayer1
        text: root.parent.expanded ? "menu_open" : "menu"
    }
}
