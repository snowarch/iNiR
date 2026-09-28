pragma ComponentBehavior: Bound

import QtQuick

OrganicAudioMotion {
    id: root

    property color primaryColor: "white"
    property color secondaryColor: primaryColor
    property color tertiaryColor: secondaryColor
    property real sensitivity: 1.0
    property real amplitude: 0.9
    property real pulseStrength: 0.72
    // Spatially focus spectrum bands into narrower contour regions. Zero keeps
    // the legacy continuous field; one produces the strongest separation.
    property real compression: 0.0
    property real glowStrength: 0.45
    // Extra render room prevents high-energy contours/halo from flattening
    // against the component bounds. presentationScale sizes the organic body
    // independently from the host rectangle; overscan only grows the texture.
    property real overscan: 1.34
    property real presentationScale: 1.0
    property real baseRadius: 0.510
    property bool stretchToHost: false
    property real hollowAmount: 1.0
    // presentationMode only changes the coordinate map. The Organic contour,
    // spectrum response, pulse, palette, ring body and halo stay shared.
    // 0 = radial Visualizer, 2 = rounded-card perimeter, 3 = physical screen edge.
    property real presentationMode: 0.0
    property int screenEdge: 2 // 0 top, 1 right, 2 bottom, 3 left
    property real edgeBaseRadius: 0.39
    property vector2d edgeCardHalf: Qt.vector2d(0.72, 0.58)
    property vector2d edgeReachHalf: edgeCardHalf
    property real edgeCornerRadius: 0.12
    property vector4d edgeReachScales: Qt.vector4d(1, 1, 1, 1)
    property vector4d edgeDirections: Qt.vector4d(1, 1, 1, 1)
    property real reveal: 1.0
    ShaderEffect {
        id: blob
        readonly property real hostSpan: Math.min(root.width, root.height)
        readonly property real span: hostSpan * Math.max(1.0, root.overscan)

        width: root.stretchToHost
            ? root.width * Math.max(1.0, root.overscan) : span
        height: root.stretchToHost
            ? root.height * Math.max(1.0, root.overscan) : span
        anchors.centerIn: parent
        visible: root.active && span > 2

        property real phase: root._phase
        property real spin: root._spin
        property real energy: root._energy
        property real onset: root._onset
        property real pulse: root._pulse
        property real amplitude: root.amplitude
        property real reveal: root.reveal
        property real deformationStrength: Math.max(0.25, Math.min(2.0, root.sensitivity))
        property real pulseStrength: Math.max(0, Math.min(1.5, root.pulseStrength))
        property real compression: Math.max(0, Math.min(1, root.compression))
        property real idleMotion: Math.max(0, Math.min(1, root.idleMotion))
        property real glowStrength: Math.max(0, Math.min(1.5, root.glowStrength))
        property real presentationScale: Math.max(0.45, Math.min(1.35, root.presentationScale))
        property real baseRadius: Math.max(0.20, Math.min(0.78, root.baseRadius))
        property real hollowAmount: Math.max(0, Math.min(1, root.hollowAmount))
        property real presentationMode: root.presentationMode
        property real screenEdge: root.screenEdge
        property real aspectRatio: Math.max(0.25, Math.min(64.0, width / Math.max(1, height)))
        property real edgeBaseRadius: Math.max(0.0, Math.min(0.75, root.edgeBaseRadius))
        property vector2d edgeCardHalf: root.edgeCardHalf
        property vector2d edgeReachHalf: root.edgeReachHalf
        property real edgeCornerRadius: Math.max(0.0, root.edgeCornerRadius)
        property vector4d edgeReachScales: root.edgeReachScales
        property vector4d edgeDirections: root.edgeDirections
        property vector4d bandsA: root._bandsA
        property vector4d bandsB: root._bandsB
        property vector4d bandsC: root._bandsC
        property vector4d peaksA: root._peakA
        property vector4d peaksB: root._peakB
        property vector4d peaksC: root._peakC
        property vector4d primaryColor: Qt.vector4d(
            root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, root.primaryColor.a)
        property vector4d secondaryColor: Qt.vector4d(
            root.secondaryColor.r, root.secondaryColor.g, root.secondaryColor.b, root.secondaryColor.a)
        property vector4d tertiaryColor: Qt.vector4d(
            root.tertiaryColor.r, root.tertiaryColor.g, root.tertiaryColor.b, root.tertiaryColor.a)

        fragmentShader: Qt.resolvedUrl("OrganicAudioBlob.frag.qsb")
    }
}
