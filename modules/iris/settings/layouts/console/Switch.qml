import QtQuick
import qs.modules.iris.style

// Console's switch: a bare pill. On, it is the ink with a dark dot at its end; off, a thin ring with a grey dot.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property real d: IrisStyle.settingsDensity
    readonly property real wantWidth: 54
    readonly property real wantHeight: 28
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(48 * root.d)
        height: Math.round(26 * root.d)
        radius: height / 2
        color: root.on ? IrisStyle.text : "transparent"
        border.width: root.on ? 0 : 1
        border.color: (root.host?.hovered ?? false) ? IrisStyle.muted : IrisStyle.hairlineStrong
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        Rectangle {
            width: Math.round(10 * root.d)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.on ? parent.width - width - Math.round(8 * root.d) : Math.round(8 * root.d)
            color: root.on ? IrisStyle.surfaceOpaque : IrisStyle.muted
            Behavior on x { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        }
    }
}
