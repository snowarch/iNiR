import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// iRiS's part `familyTransition`: what the family switch overlay (FamilyTransitionOverlay.qml) shows on the way in.
// iRiS arrives as its own mark: the real IrisMark, orbiting, over the veiled wallpaper, its name
// under it in the family's title face. It emerges on the family's curve and leaves the way it
// came, never bouncing; the shell then grows inward on its own arrival.
Item {
    id: irisRoot
    required property var overlay
    // How much of the plate tints the blurred wallpaper under it.
    readonly property real tint: 0.16
    // iRiS barely blurs what is behind its mark.
    readonly property real blur: 0.22
    anchors.fill: parent
    property bool entered: false
    Component.onCompleted: Qt.callLater(() => entered = true)
    readonly property real shown: overlay._phase ? 0 : (irisRoot.entered ? 1 : 0)

    Column {
        anchors.centerIn: parent
        spacing: Math.round(16 * IrisStyle.density)
        opacity: irisRoot.shown
        scale: overlay._phase ? 0.94 : (irisRoot.entered ? 1 : 0.86)
        Behavior on opacity {
            NumberAnimation {
                duration: overlay._phase ? IrisStyle.recedeDuration : IrisStyle.emergeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: overlay._phase ? IrisStyle.recedeCurve : IrisStyle.emergeCurve
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: overlay._phase ? IrisStyle.recedeDuration : IrisStyle.emergeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: overlay._phase ? IrisStyle.recedeCurve : IrisStyle.emergeCurve
            }
        }

        IrisMark {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitSize: Math.round(72 * IrisStyle.density)
            orbiting: true
        }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: IrisText.Display
            text: "iRiS"
            color: IrisStyle.onMedia
        }
    }
}
