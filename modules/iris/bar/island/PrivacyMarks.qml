pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// Who is listening or watching, as marks at the Island's trailing edge: the mic and the camera in signal, a screen
// cast in ink. Spelled (MIC ●) beside the clock; dots alone beside an activity, which needs the room.
Row {
    id: root
    property bool spelled: true
    // The ink of what it sits on (a Design's lacquered strip); the mic and camera stay the signal.
    property color ink: IrisStyle.text
    // On a strip already lacquered in the signal (AIRISU recording) the marks take its ink, or they would vanish.
    property color alarm: IrisStyle.signal
    readonly property real d: IrisStyle.density
    // Apple marks as iOS does: an orange dot for the mic, a green one for the camera, no words. Nothing spells them.
    readonly property bool nothing: IrisStyle.wearsNothing(root)
    readonly property bool any: Privacy.micActive || Privacy.cameraActive || Privacy.screenSharing
    spacing: Math.round(8 * root.d)
    // Stays laid out while the last mark folds away, so the row it rides closes instead of jumping.
    visible: root.any || root.implicitWidth > 0.5

    component Mark: Item {
        id: mark
        property bool active: false
        property string label: ""
        property color ink: root.alarm
        property color appleInk: root.ink
        property real reveal: mark.active ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: IrisStyle.duration(220); easing.type: Easing.OutCubic } }
        visible: mark.reveal > 0.01
        clip: mark.reveal < 1
        implicitWidth: Math.round(row.implicitWidth * mark.reveal)
        implicitHeight: row.implicitHeight
        opacity: mark.reveal
        Row {
            id: row
            spacing: Math.round(6 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            IrisLabel {
                visible: root.spelled && root.nothing
                anchors.verticalCenter: parent.verticalCenter
                text: mark.label
                color: Qt.colorEqual(mark.ink, IrisStyle.signal) ? IrisStyle.signalInk : root.ink
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(6 * root.d)
                height: width
                radius: width / 2
                color: root.nothing ? mark.ink : mark.appleInk
            }
        }
    }

    Mark { active: Privacy.micActive; label: Translation.tr("Mic"); appleInk: IrisStyle.identity.orange }
    Mark { active: Privacy.cameraActive; label: Translation.tr("Cam"); appleInk: IrisStyle.identity.green }
    Mark { active: Privacy.screenSharing; label: Translation.tr("Cast"); ink: root.ink }
}
