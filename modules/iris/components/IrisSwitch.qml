import QtQuick
import QtQuick.Effects
import qs.modules.common.functions
import qs.modules.iris.style

Rectangle {
    id: root

    property bool on: false
    property string name: ""
    readonly property real d: IrisStyle.density
    // A Design may draw it its own way (AIRISU: O│I); the switch keeps the toggle, the keys and the name.
    readonly property bool skinned: skin.active
    // What a skin draws from: the pointer over it and the press.
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property bool keyed: root.activeFocus
    // Set on a chosen row's plate in a plate Design: the skin prints it in the plate's reverse ink.
    property bool reversed: false
    property string voice: ""
    signal toggled()
    // Apple: an accent track and a white thumb lifted by a soft shadow. Nothing (S4): off is a hairline ring with a
    // hollow knob, on an ink track with a paper knob. Synth: a key that sinks and lights its LED. Gel: the capsule
    // fills with glossy accent under a white bead.
    readonly property string look: IrisStyle.lookOf(root)
    readonly property bool nothing: root.look === "nothing"
    readonly property bool synth: root.look === "synth" && !root.skinned
    readonly property bool gel: root.look === "gel" && !root.skinned

    implicitWidth: Math.round((skin.item?.wantWidth ?? (root.skinned ? Number(IrisDesign.surface("switch", "width", 76)) : root.nothing ? 38 : root.synth ? 44 : root.gel ? 46 : 40)) * root.d)
    implicitHeight: Math.round((skin.item?.wantHeight ?? (root.skinned ? Number(IrisDesign.surface("switch", "height", 26)) : root.nothing ? 22 : root.synth ? 28 : root.gel ? 26 : 24)) * root.d)
    // The knob rides a spring and everything else follows it, so a quick double toggle turns back mid-way.
    IrisSpring {
        id: travel
        intent: "move"
        to: root.on ? 1 : 0
        animate: IrisStyle.motionEnabled && root.visible
    }
    Component.onCompleted: travel.jump()
    readonly property real lit: Math.max(0, Math.min(1, travel.value))
    readonly property real stroke: Math.max(1, Math.round(1.5 * root.d * 2) / 2)
    readonly property color ring: IrisStyle.ringInk
    radius: root.skinned ? 0 : root.synth ? IrisStyle.synthKeyRadius : height / 2
    color: root.skinned || root.synth ? "transparent"
        : root.gel ? IrisStyle.fillHover
        : root.nothing ? ColorUtils.applyAlpha(IrisStyle.accentFill, root.lit) : ColorUtils.mix(IrisStyle.appleAccent, IrisStyle.fillHover, root.lit)
    border.width: root.skinned || !root.nothing ? 0 : root.stroke
    border.color: ColorUtils.mix(IrisStyle.accentFill, root.ring, root.lit)
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.name
    Accessible.checked: root.on
    activeFocusOnTab: visible
    Keys.onSpacePressed: root.toggled()
    Keys.onReturnPressed: root.toggled()

    IrisSkin { id: skin; part: "switch"; voice: root.voice }
    Rectangle {
        visible: root.activeFocus && !root.skinned
        anchors.fill: parent
        anchors.margins: -Math.round(3 * root.d)
        radius: root.synth ? Math.round(8 * root.d) : height / 2
        color: "transparent"
        border.width: Math.max(1, Math.round(1.5 * root.d))
        border.color: IrisStyle.text
    }
    // Gel: the glossy fill comes up with the knob's travel, its light cap on the upper half.
    Loader {
        active: root.gel && root.lit > 0
        anchors.fill: parent
        sourceComponent: Rectangle {
            radius: height / 2
            opacity: root.lit
            gradient: Gradient {
                GradientStop { position: 0; color: IrisStyle.gelTop }
                GradientStop { position: 0.55; color: IrisStyle.gelBody }
                GradientStop { position: 1; color: IrisStyle.gelBottom }
            }
            Rectangle {
                x: Math.round(parent.height * 0.3)
                y: Math.round(2 * root.d)
                width: parent.width - 2 * x
                height: Math.round(parent.height * 0.42)
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.gelShineTop }
                    GradientStop { position: 1; color: IrisStyle.gelShineBottom }
                }
            }
        }
    }
    // Synth: the key's edge shows under its face; on, the face sinks onto it and the LED lights.
    Loader {
        active: root.synth
        anchors.fill: parent
        sourceComponent: Item {
            readonly property real edge: Math.round(3 * root.d)
            Rectangle {
                y: parent.edge
                width: parent.width
                height: parent.height - parent.edge
                radius: root.radius
                color: IrisStyle.synthKeyEdge
            }
            Rectangle {
                y: Math.round(parent.edge * (2 / 3) * root.lit + (area.pressed ? root.d : 0))
                width: parent.width
                height: parent.height - parent.edge
                radius: root.radius
                color: IrisStyle.synthKey
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(13 * root.d)
                    height: width
                    radius: width / 2
                    color: IrisStyle.synthOn
                    opacity: 0.3 * root.lit
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(7 * root.d)
                    height: width
                    radius: width / 2
                    color: ColorUtils.mix(IrisStyle.synthOn, IrisStyle.synthLedOff, root.lit)
                }
            }
        }
    }
    RectangularShadow {
        visible: !root.skinned && !root.nothing && !root.synth
        anchors.fill: knob
        radius: knob.radius
        offset.y: root.d
        blur: 3 * root.d
        color: IrisStyle.shadow
    }
    // Held, the knob stretches toward where it will travel, as a finger pressing a capsule does.
    Rectangle {
        id: knob
        visible: !root.skinned && !root.synth
        readonly property real size: root.nothing ? Math.round((12 + root.lit) * root.d) : root.height - 4 * root.d
        readonly property real pad: Math.round((root.nothing ? 4 : 2) * root.d)
        y: Math.round((root.height - height) / 2)
        width: root.nothing ? knob.size + (area.pressed ? Math.round(4 * root.d) : 0) : knob.size * (area.pressed ? 1.28 : 1)
        height: knob.size
        x: knob.pad + (root.width - 2 * knob.pad - knob.width) * travel.value
        radius: IrisStyle.capsule(height)
        color: root.nothing ? ColorUtils.applyAlpha(IrisStyle.inkOnAccentFill, root.lit) : IrisStyle.onTint
        border.width: root.nothing ? root.stroke * (1 - root.lit) : 0
        border.color: root.ring
        Behavior on width { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Loader {
            active: root.gel
            anchors.fill: parent
            sourceComponent: Rectangle {
                radius: knob.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.gelPearlTop }
                    GradientStop { position: 1; color: IrisStyle.gelPearlBottom }
                }
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * root.d
        hoverEnabled: root.skinned
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
