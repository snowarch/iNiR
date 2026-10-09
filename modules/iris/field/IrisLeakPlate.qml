import QtQuick
import qs.modules.iris.style

// A plate of Light leak film for a surface IrisField does not draw (desktop widgets, IrisSurface): the same light, grain
// and burn as the field's bodies, sampled where the plate sits on its output. Static: it redraws only with its window.
ShaderEffect {
    id: root

    // Where the plate's top-left sits on its output, and the output's size, in pixels.
    property point at: Qt.point(0, 0)
    property size output: Qt.size(1920, 1080)
    property real radius: 0
    // Top-left, top-right, bottom-right, bottom-left: a notched side has square corners.
    property vector4d corners: Qt.vector4d(root.radius, root.radius, root.radius, root.radius)
    // The plate's own colour: a light one is exposed as photo paper, a dark one as film.
    property color base: IrisStyle.surface
    // How much of the light this plate catches (desktop widgets: Light leak › Widgets).
    property real strength: 1

    fragmentShader: Qt.resolvedUrl("IrisLeakPlate.frag.qsb")
    readonly property vector4d plate: Qt.vector4d(root.at.x, root.at.y, root.output.width, root.output.height)
    readonly property vector4d body: Qt.vector4d(root.width, root.height, 0, IrisStyle.leakBody.x)
    readonly property vector4d tone: Qt.vector4d(root.base.r, root.base.g, root.base.b, root.base.a)
    readonly property vector4d leakMix: Qt.vector4d(IrisStyle.leakMix.x, IrisStyle.leakMix.y * root.strength, IrisStyle.leakMix.z, IrisStyle.leakMix.w)
    readonly property vector4d leakGrain: IrisStyle.leakFilm
    readonly property vector4d leakStop0: IrisStyle.leakStop0
    readonly property vector4d leakStop1: IrisStyle.leakStop1
    readonly property vector4d leakStop2: IrisStyle.leakStop2
    readonly property vector4d leakStop3: IrisStyle.leakStop3
    readonly property vector4d leakStop4: IrisStyle.leakStop4
    readonly property vector4d leakCore: IrisStyle.leakCore
    readonly property vector4d leakAt0: IrisStyle.leakAt0
    readonly property vector4d leakAt1: IrisStyle.leakAt1
    readonly property vector4d leakAt2: IrisStyle.leakAt2
    readonly property vector4d leakForm0: IrisStyle.leakForm0
    readonly property vector4d leakForm1: IrisStyle.leakForm1
    readonly property vector4d leakForm2: IrisStyle.leakForm2
    readonly property vector4d leakHue0: IrisStyle.leakHue0
    readonly property vector4d leakHue1: IrisStyle.leakHue1
    readonly property vector4d leakHue2: IrisStyle.leakHue2
}
