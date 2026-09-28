import QtQuick
import QtQuick.Controls
import qs.modules.iris.style

ScrollBar {
    id: root

    readonly property real d: IrisStyle.density
    readonly property bool engaged: root.hovered || root.pressed
    policy: ScrollBar.AsNeeded
    padding: Math.round(3 * root.d)
    implicitWidth: Math.round(14 * root.d)
    minimumSize: 0.08
    background: null
    contentItem: Item {
        implicitWidth: Math.round(14 * root.d)
        opacity: root.size < 1 && root.engaged ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(root.engaged ? 120 : 420); easing.type: IrisStyle.feedbackEasing } }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.round((root.engaged ? 8 : 5) * root.d)
            radius: width / 2
            color: root.engaged ? IrisStyle.muted : IrisStyle.textTertiary
            Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        }
    }
}
