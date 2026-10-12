import QtQuick
import qs.modules.common.functions

// A picture printed as a halftone (網点) in one ink: dots on a screen turned 45°, each as large as its tone. On a dark
// stock the light ink prints the lights; on paper the dark ink prints the darks, so a cover reads the same way round
// in every scheme. `fadeFrom`..`fadeTo` fades it by the dots alone (a screen ramp), never by transparency. The picture
// is decoded at the drawn size and the pass runs only when its inputs change.
Item {
    id: root
    property url source
    property color ink: Airisu.inkThird
    property real cell: Math.max(4, Math.round(5 * Airisu.d))
    property real angle: 45
    property real fadeFrom: 0
    property real fadeTo: 0
    property real gain: 1
    // A light ink on a darker stock prints the lights.
    readonly property bool lightInk: ColorUtils.relativeLuminance(root.ink) > ColorUtils.relativeLuminance(Airisu.ground)
    readonly property bool ready: picture.status === Image.Ready

    Image {
        id: picture
        anchors.fill: parent
        visible: false
        source: root.source
        sourceSize.width: Math.max(1, Math.round(root.width / 2))
        sourceSize.height: Math.max(1, Math.round(root.height / 2))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.ready
        readonly property var source: picture
        readonly property size size: Qt.size(root.width, root.height)
        readonly property real cell: root.cell
        readonly property real angle: root.angle * Math.PI / 180
        readonly property color ink: root.ink
        readonly property real fadeFrom: root.fadeFrom
        readonly property real fadeTo: root.fadeTo
        readonly property real lightInk: root.lightInk ? 1 : 0
        readonly property real floorPx: 1.6
        readonly property real gain: root.gain
        fragmentShader: Qt.resolvedUrl("../shaders/halftone.frag.qsb")
    }
}
