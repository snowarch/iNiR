pragma ComponentBehavior: Bound

import QtQuick

// A second figure beside its name, as the Day's other sun time: the name, the figure, its unit a step down.
Row {
    id: aside
    required property var face
    property string label: ""
    property string value: ""
    property string unit: ""
    property real size: 17
    property color tone: aside.face.ink
    spacing: aside.face.dp(5)
    FaceText {
        face: aside.face
        visible: aside.label.length > 0
        anchors.baseline: figure.baseline
        text: aside.label
        color: aside.face.inkSecondary
        size: 12.5
        weight: Font.DemiBold
    }
    FaceFigure {
        id: figure
        face: aside.face
        text: aside.value
        size: aside.size
        tone: aside.tone
    }
    FaceText {
        face: aside.face
        visible: aside.unit.length > 0
        anchors.baseline: figure.baseline
        text: aside.unit
        color: aside.face.inkSecondary
        size: Math.max(11, Math.round(aside.size * 0.55))
        weight: Font.DemiBold
    }
}
