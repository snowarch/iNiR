import QtQuick
import qs.modules.iris.style

Item {
    id: root
    required property IrisHeaderScrim scrim
    visible: false
    layer.enabled: true
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: root.scrim.maskSolidEnd; color: "transparent" }
            GradientStop { position: Math.min(0.99, root.scrim.maskRampEnd + 0.08 * root.scrim.meltTop); color: "white" }
            GradientStop { position: Math.max(0.6, root.scrim.midAt); color: "white" }
            GradientStop { position: 1; color: IrisStyle.glassy ? "transparent" : "white" }
        }
    }
}
