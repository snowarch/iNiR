import QtQuick

// A halftone (網点, SYSTEM.md Law 1): a tone printed in one ink as a screen of dots on a grid turned 45°, each dot as large
// as the tone under its cell, none under a printable size. `source` is the tone (any texture provider); `fadeFrom` ..
// `fadeTo` shrink the dots to nothing along x, as a printer fades a screen, never an alpha ramp. `lightInk` prints the
// lights (a light ink on lacquer), otherwise the darks (sumi on paper). Static: it costs one pass when the window draws.
ShaderEffect {
    id: root
    property Item source
    property color ink: Airisu.ink
    property real cell: Airisu.u(1.5)
    property real angle: Math.PI / 4
    property real fadeFrom: 0
    property real fadeTo: 0
    property real lightInk: 1
    property real floorPx: 1.5
    property real gain: 1
    readonly property size size: Qt.size(root.width, root.height)
    fragmentShader: Qt.resolvedUrl("../shaders/halftone.frag.qsb")
}
