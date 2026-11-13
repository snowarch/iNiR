pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

// A value from 0 to 1 in the family's own slider (its scrubber part), Material's otherwise.
// `moved` fires while dragging, `committed` once on release.
Item {
    id: root

    property real value: 0
    property real stepSize: 0.05
    signal moved(real value)
    signal committed(real value)

    implicitHeight: Math.max(familyScrubber.implicitHeight, materialSlider.implicitHeight, Math.round(20 * OverlayLook.d))
    implicitWidth: Math.round(120 * OverlayLook.d)

    function snap(v: real): real {
        return Math.max(0, Math.min(1, Math.round(v / root.stepSize) * root.stepSize))
    }

    FamilyPart {
        id: familyScrubber
        visible: familyScrubber.url.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        part: "control.scrubber"
        props: ({ knob: true, fillColor: FamilyStyle.accent, stepSize: root.stepSize, value: root.value })
        Connections {
            target: familyScrubber.item
            function onMoved(v: real): void { root.moved(root.snap(v)) }
            function onSeekRequested(v: real): void { root.committed(root.snap(v)) }
        }
    }

    StyledSlider {
        id: materialSlider
        visible: familyScrubber.url.length === 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        enableSettingsSearch: false
        configuration: StyledSlider.Configuration.XS
        stopIndicatorValues: []
        from: 0
        to: 1
        stepSize: root.stepSize
        value: root.value
        onMoved: root.moved(root.snap(materialSlider.value))
        onPressedChanged: {
            if (materialSlider.pressed)
                return
            root.committed(root.snap(materialSlider.value))
            materialSlider.value = Qt.binding(() => root.value)
        }
    }
}
