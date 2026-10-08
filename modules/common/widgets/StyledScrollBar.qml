import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.functions

ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    topPadding: Appearance.rounding.normal
    bottomPadding: Appearance.rounding.normal

    contentItem: Rectangle {
        implicitWidth: 4
        implicitHeight: 100
        radius: width / 2
        color: Appearance.colors.colOnSurfaceVariant
        
        // iRiS shows it only under the pointer: a bar flashing on every wheel turn fights its pages.
        readonly property bool shows: Config.options?.panelFamily === "iris" ? (root.hovered || root.pressed) : root.active
        opacity: root.policy === ScrollBar.AlwaysOn || (shows && root.size < 1.0) ? 0.5 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 350
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }
}
