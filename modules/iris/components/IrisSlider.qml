import QtQuick
import qs.modules.iris.style

// A plain range (a display's brightness): the family's dot scrubber with its knob, wheel and arrow keys.
Item {
    id: root

    property real value: 0
    readonly property bool pressed: scrubber.dragging
    // What a skin draws from: the pointer over it.
    readonly property bool hovered: hover.hovered
    signal moved(real value)

    implicitWidth: 220
    implicitHeight: Math.round(34 * IrisStyle.density)

    IrisScrubber {
        id: scrubber
        anchors.fill: parent
        // Under a Design's skin the slider keeps its input and draws nothing.
        opacity: skin.active ? 0 : 1
        enabled: root.enabled
        seekable: root.enabled
        knob: true
        value: root.value
        fillColor: IrisStyle.text
        onMoved: next => root.moved(next)
    }
    HoverHandler { id: hover; enabled: skin.active }
    IrisSkin { id: skin; part: "slider"; host: root }
}
