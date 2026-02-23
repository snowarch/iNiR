// Password character indicator — exact visual equivalent of PasswordChars.qml.
// Uses the same material-shapes.js polygon data and identical animations.
//
// CRITICAL: Uses a ListModel (append/remove) instead of an integer Repeater model.
// An integer model (model: N) destroys and recreates ALL delegates when N changes,
// causing every existing shape to re-animate (blink). A ListModel preserves existing
// delegates — only newly appended items run their entrance animation.
import QtQuick 2.15

Item {
    id: root
    property int dotCount: 0
    property color dotColor: "#cdd6f4"   // colOnSurface — final color after animation
    property color animColor: "#cba6f7"  // colPrimary — color on appearance

    implicitHeight: 22
    clip: true

    // Sync ListModel with dotCount — append on increase, remove on decrease
    onDotCountChanged: {
        var diff = dotCount - dotsModel.count
        if (diff > 0) {
            for (var i = 0; i < diff; i++)
                dotsModel.append({ idx: dotsModel.count })
        } else if (diff < 0) {
            dotsModel.remove(dotsModel.count + diff, -diff)
        }
    }

    ListModel { id: dotsModel }

    // Auto-scroll to end when new shapes appear (mirrors PasswordChars contentX logic)
    property real scrollX: Math.max(0, dotsRow.implicitWidth - width)
    Behavior on scrollX { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Row {
        id: dotsRow
        x: -root.scrollX
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: dotsModel
            delegate: Item {
                id: charItem
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
                    shapeIndex: index
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
                            to: 1; duration: 200; easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0, 1, 1]
                        }
                        NumberAnimation {
                            target: shape; property: "implicitSize"
                            to: 18; duration: 200; easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0, 1, 1]
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
