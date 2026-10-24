pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// The hours under a drawn day, ends flush with its edges.
RowLayout {
    id: hours
    // sized by its content: a nested layout fills its column by default and took the room meant for others
    Layout.fillHeight: false
    required property var face
    property var marks: [0, 6, 12, 18, 24]
    spacing: 0
    Repeater {
        model: hours.marks
        FaceText {
            required property var modelData
            required property int index
            face: hours.face
            Layout.fillWidth: true
            horizontalAlignment: index === 0 ? Text.AlignLeft : index === hours.marks.length - 1 ? Text.AlignRight : Text.AlignHCenter
            text: modelData
            color: hours.face.inkTertiary
            size: 10.5
            font.family: hours.face.fontNumbers
            font.features: ({ "tnum": 1 })
        }
    }
}
