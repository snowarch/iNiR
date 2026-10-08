pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

// A mark that breathes (recording, an app asking for attention): opacity 1 → 0.35 → 1 on a sine, drawn through
// LiveLayer so it does not repaint the whole chassis every frame. The level comes from the wall clock, not an
// animation of its own: two InOutSine halves between 1 and 0.35 are exactly this cosine, and the copy in place and
// the one in its own surface stay in phase across a hand-off.
Item {
    id: root
    property color color: IrisStyle.danger
    property real radius: Math.min(width, height) / 2
    property real borderWidth: 0
    property color borderColor: "transparent"
    property bool pulsing: true
    property int halfPeriod: 700
    // `visible` is effective visibility: a hidden mark (nothing recording, a Dock dot of a closed app) must not keep
    // its FrameAnimation running, or the host window redraws at the display rate for nothing.
    readonly property bool breathing: root.pulsing && root.visible && IrisStyle.motionEnabled

    LiveLayer {
        anchors.fill: parent
        live: root.breathing
        content: mark
    }

    Component {
        id: mark
        Rectangle {
            id: face
            property bool drawing: false
            antialiasing: true
            radius: root.radius
            color: root.color
            border.width: root.borderWidth
            border.color: root.borderColor
            function level(): real {
                return 0.675 + 0.325 * Math.cos(2 * Math.PI * (Date.now() % (2 * root.halfPeriod)) / (2 * root.halfPeriod))
            }
            opacity: 1
            FrameAnimation {
                running: face.drawing && root.breathing
                onTriggered: face.opacity = face.level()
                onRunningChanged: face.opacity = running ? face.level() : 1
            }
        }
    }
}
