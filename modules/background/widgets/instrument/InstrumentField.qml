pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A labelled reading: the caption above, the value in the numbers face below.
ColumnLayout {
    id: root
    property real scaleFactor: 1
    property string label: ""
    property string value: ""
    property color ink
    property color muted
    property string family: Appearance.font.family.numbers
    property real valueSize: 15

    spacing: 0
    InstrumentLabel {
        Layout.fillWidth: true
        text: root.label
        color: root.muted
        scaleFactor: root.scaleFactor
        size: 8
    }
    StyledText {
        Layout.fillWidth: true
        text: root.value.length > 0 ? root.value : "--"
        color: root.ink
        elide: Text.ElideRight
        font.family: root.family
        font.pixelSize: Math.max(11, Math.round(root.valueSize * root.scaleFactor))
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }
}
