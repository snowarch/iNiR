import QtQuick
import qs.modules.iris.style

Item {
    id: root
    property real implicitSize: 22 * IrisStyle.density
    property color color: IrisStyle.accent
    property bool orbiting: false
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // The active Design may draw the insignia its own way (DESIGNS.md); the ring below is the iRiS one.
    readonly property string skin: IrisDesign.skin("insignia")
    Loader {
        anchors.fill: parent
        active: root.skin.length > 0
        source: root.skin
        onLoaded: item.host = root
    }

    Item {
        anchors.fill: parent
        visible: root.skin.length === 0

        Rectangle {
            anchors.centerIn: parent
            width: root.implicitSize * 0.72
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, root.implicitSize * 0.07)
            border.color: root.color
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.implicitSize * 0.18
            height: width
            radius: width / 2
            color: root.color
        }

        Item {
            anchors.fill: parent
            Rectangle {
                x: root.width * 0.76
                y: root.height * 0.08
                width: root.implicitSize * 0.13
                height: width
                radius: width / 2
                color: IrisStyle.secondaryAccent
            }
            RotationAnimator on rotation {
                running: root.orbiting && IrisStyle.motionEnabled && root.skin.length === 0
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 9000
            }
        }
    }
}
