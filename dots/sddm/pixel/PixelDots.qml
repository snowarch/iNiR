// Password character indicator — exact visual equivalent of PasswordChars.qml.
// Uses the same material-shapes.js polygon data and identical animations.
import QtQuick 2.15

Item {
    id: root
    property int dotCount: 0
    property color dotColor: "#cdd6f4"   // colOnSurface — final color after animation
    property color animColor: "#cba6f7"  // colPrimary — color on appearance

    implicitHeight: 22
    clip: true

    // Auto-scroll to end when new shapes appear (mirrors PasswordChars contentX logic)
    property real scrollX: Math.max(0, dotsRow.implicitWidth - width)
    Behavior on scrollX { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Row {
        id: dotsRow
        x: -root.scrollX
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.dotCount
            delegate: Item {
                id: charItem
                required property int index
                // implicitWidth/Height driven by the PasswordCharsShape inside
                implicitWidth: shape.implicitSize
                implicitHeight: shape.implicitSize

                // Identical animation sequence to PasswordChars.qml:
                //   opacity  0 → 1    (50ms)
                //   scale    0.5 → 1  (200ms bezier)
                //   implicitSize 0 → 18  (200ms bezier)
                //   color    primary → onSurface  (1000ms)
                PasswordCharsShape {
                    id: shape
                    anchors.centerIn: parent
                    shapeIndex: charItem.index
                    implicitSize: 0
                    opacity: 0
                    scale: 0.5
                    shapeColor: root.animColor

                    Component.onCompleted: appearAnim.start()

                    ParallelAnimation {
                        id: appearAnim
                        NumberAnimation {
                            target: shape; property: "opacity"
                            to: 1; duration: 50
                        }
                        NumberAnimation {
                            target: shape; property: "scale"
                            to: 1; duration: 200; easing.type: Easing.OutBack
                        }
                        NumberAnimation {
                            target: shape; property: "implicitSize"
                            to: 18; duration: 200; easing.type: Easing.OutBack
                        }
                        ColorAnimation {
                            target: shape; property: "shapeColor"
                            from: root.animColor; to: root.dotColor
                            duration: 1000
                        }
                    }
                }
            }
        }
    }
}
