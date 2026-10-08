pragma ComponentBehavior: Bound

import QtQuick

OrganicAudioMotion {
    id: root

    property vector4d edges: Qt.vector4d(0, 0, 1, 0)
    property vector4d depths: Qt.vector4d(180, 180, 180, 180)
    property real span: 0.7
    property real position: 0.5
    property real taper: 0.12
    property real cornerRadius: 24
    property real cornerBlend: 0.55
    property real flowDirection: 1
    property real thickness: 0.32
    property real detail: 0.45
    property real sensitivity: 0.75
    property real pulseStrength: 1
    property real compression: 0
    property real glow: 0.7
    property real colorSpeed: 0.35
    property real bodyOpacity: 0.30
    property real crestStrength: 0.85
    property real glowSpread: 0.50
    property real audioRange: 0.75
    property real bassDrive: 0.85
    property real trebleDrive: 0.65
    property real transientStrength: 0.90
    property real beatGlow: 0.65
    property real effectStrength: 0.4
    property int effectMode: 0
    property int colorMode: 0
    property int shapeMode: 0
    property bool joinConnected: true
    property int material: 0
    property color primaryColor: "white"
    property color secondaryColor: primaryColor
    property color tertiaryColor: secondaryColor
    property bool smoothTuning: true
    property int tuningDuration: 150

    property real _edgeTop: edges.x
    property real _edgeRight: edges.y
    property real _edgeBottom: edges.z
    property real _edgeLeft: edges.w
    property real _depthTop: depths.x
    property real _depthRight: depths.y
    property real _depthBottom: depths.z
    property real _depthLeft: depths.w
    property real _span: span
    property real _position: position
    property real _taper: taper
    property real _cornerRadius: cornerRadius
    property real _cornerBlend: cornerBlend
    property real _flowDirection: flowDirection
    property real _thickness: thickness
    property real _detail: detail
    property real _sensitivity: sensitivity
    property real _pulseStrength: pulseStrength
    property real _compression: compression
    property real _glow: glow
    property real _colorSpeed: colorSpeed
    property real _bodyOpacity: bodyOpacity
    property real _crestStrength: crestStrength
    property real _glowSpread: glowSpread
    property real _audioRange: audioRange
    property real _bassDrive: bassDrive
    property real _trebleDrive: trebleDrive
    property real _transientStrength: transientStrength
    property real _beatGlow: beatGlow
    property real _effectStrength: effectStrength
    property color _primaryColor: primaryColor
    property color _secondaryColor: secondaryColor
    property color _tertiaryColor: tertiaryColor

    component TuneBehavior: Behavior {
        enabled: root.smoothTuning
        NumberAnimation { duration: root.tuningDuration; easing.type: Easing.OutCubic }
    }

    TuneBehavior on _edgeTop {}
    TuneBehavior on _edgeRight {}
    TuneBehavior on _edgeBottom {}
    TuneBehavior on _edgeLeft {}
    TuneBehavior on _depthTop {}
    TuneBehavior on _depthRight {}
    TuneBehavior on _depthBottom {}
    TuneBehavior on _depthLeft {}
    TuneBehavior on _span {}
    TuneBehavior on _position {}
    TuneBehavior on _taper {}
    TuneBehavior on _cornerRadius {}
    TuneBehavior on _cornerBlend {}
    TuneBehavior on _flowDirection {}
    TuneBehavior on _thickness {}
    TuneBehavior on _detail {}
    TuneBehavior on _sensitivity {}
    TuneBehavior on _pulseStrength {}
    TuneBehavior on _compression {}
    TuneBehavior on _glow {}
    TuneBehavior on _colorSpeed {}
    TuneBehavior on _bodyOpacity {}
    TuneBehavior on _crestStrength {}
    TuneBehavior on _glowSpread {}
    TuneBehavior on _audioRange {}
    TuneBehavior on _bassDrive {}
    TuneBehavior on _trebleDrive {}
    TuneBehavior on _transientStrength {}
    TuneBehavior on _beatGlow {}
    TuneBehavior on _effectStrength {}
    Behavior on _primaryColor { enabled: root.smoothTuning; ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on _secondaryColor { enabled: root.smoothTuning; ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on _tertiaryColor { enabled: root.smoothTuning; ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property int shaderStatus: edgeShader.status
    readonly property string shaderLog: edgeShader.log
    readonly property real motionPhase: root._phase
    readonly property real effectiveMotionSpeed: root._effectiveMotionSpeed

    ShaderEffect {
        id: edgeShader
        anchors.fill: parent
        visible: root.active && width > 0 && height > 0
        property vector2d resolution: Qt.vector2d(width, height)
        property vector4d edges: Qt.vector4d(root._edgeTop, root._edgeRight, root._edgeBottom, root._edgeLeft)
        property vector4d depths: Qt.vector4d(root._depthTop, root._depthRight, root._depthBottom, root._depthLeft)
        property vector4d geometry: Qt.vector4d(root._span, root._position, root._taper, root._cornerRadius)
        property vector4d material: Qt.vector4d(root._thickness, root._detail, root._glow, root.material)
        property vector4d appearance: Qt.vector4d(root._bodyOpacity, root._crestStrength, root._glowSpread, root._audioRange)
        property vector4d response: Qt.vector4d(root._bassDrive, root._trebleDrive, root._transientStrength, root._beatGlow)
        property vector4d effects: Qt.vector4d(root.effectMode, root._effectStrength, root.colorMode, root.shapeMode)
        property vector4d topology: Qt.vector4d(root.joinConnected ? 1 : 0,
            root._flowDirection, root._cornerBlend, 0)
        property vector4d motion: Qt.vector4d(root._phase, root.idleMotion, root._colorSpeed, root._sensitivity)
        property vector4d activity: Qt.vector4d(root._energy, root._pulse * root._pulseStrength, root._onset, root._compression)
        property vector4d bandsA: root._bandsA
        property vector4d bandsB: root._bandsB
        property vector4d bandsC: root._bandsC
        property vector4d peaksA: root._peakA
        property vector4d peaksB: root._peakB
        property vector4d peaksC: root._peakC
        property vector4d primaryColor: Qt.vector4d(root._primaryColor.r, root._primaryColor.g, root._primaryColor.b, root._primaryColor.a)
        property vector4d secondaryColor: Qt.vector4d(root._secondaryColor.r, root._secondaryColor.g, root._secondaryColor.b, root._secondaryColor.a)
        property vector4d tertiaryColor: Qt.vector4d(root._tertiaryColor.r, root._tertiaryColor.g, root._tertiaryColor.b, root._tertiaryColor.a)
        fragmentShader: Qt.resolvedUrl("OrganicScreenEdge.frag.qsb")
    }
}
