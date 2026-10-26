pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common.functions
import qs.modules.common.widgets as Kit
import qs.modules.iris.style

Item {
    id: root

    property real value: 0
    property bool seekable: true
    // Apple: a capsule track that thickens under the pointer and a white thumb. Nothing (S4): a row of dots. Synth: a
    // fader, a thin blue run over ticks with a cap. Gel: a glossy accent run and a pearl knob.
    readonly property string look: IrisStyle.lookOf(root)
    readonly property bool nothing: root.look === "nothing"
    readonly property bool synth: root.look === "synth" && !skin.active
    readonly property bool gel: root.look === "gel" && !skin.active
    property color fillColor: root.nothing ? IrisStyle.text : IrisStyle.fillStrong
    property color trackColor: IrisStyle.fill
    signal seekRequested(real value)
    signal moved(real value)
    property bool knob: false
    // Whether what it scrubs is running now (a playing track): a Design may mark the head with it.
    property bool live: true
    property real stepSize: 0.05
    // A notch of the wheel moves about a twentieth of the range, in whole steps: one step of 0-100 took a hundred notches.
    readonly property real wheelStep: root.stepSize >= 0.05 ? root.stepSize : Math.max(1, Math.round(0.05 / Math.max(0.0001, root.stepSize))) * root.stepSize
    property string voice: ""
    // What a voiced skin prints the value from (Folio's ruler, Console's dots): the row's own numbers.
    property var range: null
    activeFocusOnTab: root.seekable

    property real dragValue: -1
    readonly property bool dragging: pointer.pressed
    readonly property bool engaged: root.seekable && (pointer.containsMouse || pointer.pressed || root.activeFocus)
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))

    implicitWidth: 200
    implicitHeight: Math.round(14 * IrisStyle.density)

    Accessible.role: Accessible.Slider
    Keys.onPressed: event => {
        if (!root.seekable) return
        let next = root.shownValue
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) next += root.stepSize
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) next -= root.stepSize
        else if (event.key === Qt.Key_Home) next = 0
        else if (event.key === Qt.Key_End) next = 1
        else return
        next = Math.max(0, Math.min(1, next))
        root.moved(next)
        root.seekRequested(next)
        event.accepted = true
    }

    // The active Design may draw it (AIRISU: a meter for a level, a light trail for time); input stays here.
    IrisSkin { id: skin; part: "scrubber"; host: root; voice: root.voice }
    // Signal (DESIGN.md S4): a row of dots, filled up to the value, with a larger dot for the knob. The value may sit
    // beside it in the Label voice; clicked, it turns into a field to type the number.
    property bool showValue: false
    readonly property bool valueShown: root.showValue && root.range !== null && !skin.active
    readonly property real valueRoom: root.valueShown ? Math.ceil(valueLabel.implicitWidth) + Math.round(12 * IrisStyle.density) : 0
    // Where the value runs, whichever draws it: the pointer maps onto this lane.
    readonly property real laneStart: root.nothing ? track.start : 0
    readonly property real laneLength: root.nothing ? track.lane : bar.width
    Item {
        id: bar
        visible: !skin.active && !root.nothing
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.valueRoom
        height: Math.round((root.synth ? (root.engaged ? 4 : 3) : root.gel ? (root.engaged ? 10 : 7) : root.engaged ? 9 : 4) * IrisStyle.density)
        readonly property real corner: root.synth ? Math.round(IrisStyle.density) : IrisStyle.capsule(height)
        Behavior on height { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        Repeater {
            model: root.synth && root.knob ? 11 : 0
            Rectangle {
                required property int index
                x: Math.round((bar.width - width) * index / 10)
                y: bar.height + Math.round(4 * IrisStyle.density)
                width: Math.max(1, Math.round(IrisStyle.density))
                height: Math.round((index % 5 === 0 ? 5 : 3) * IrisStyle.density)
                color: IrisStyle.synthLedOff
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: bar.corner
            color: root.synth ? IrisStyle.synthLedOff : root.trackColor
        }
        Item {
            width: bar.width * root.shownValue
            height: bar.height
            clip: true
            Rectangle {
                width: bar.width
                height: bar.height
                radius: bar.corner
                color: root.synth ? IrisStyle.synthLevel : root.gel ? IrisStyle.gelBody : root.fillColor
                Loader {
                    active: root.gel
                    anchors.fill: parent
                    sourceComponent: Rectangle {
                        radius: bar.corner
                        gradient: Gradient {
                            GradientStop { position: 0; color: IrisStyle.gelTop }
                            GradientStop { position: 0.55; color: IrisStyle.gelBody }
                            GradientStop { position: 1; color: IrisStyle.gelBottom }
                        }
                        Rectangle {
                            x: Math.round(bar.height / 2)
                            y: Math.max(1, Math.round(IrisStyle.density))
                            width: parent.width - 2 * x
                            height: Math.round(bar.height * 0.42)
                            radius: height / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: IrisStyle.gelShineTop }
                                GradientStop { position: 1; color: IrisStyle.gelShineBottom }
                            }
                        }
                    }
                }
            }
        }
    }
    RectangularShadow {
        visible: knobFace.visible
        anchors.fill: knobFace
        radius: knobFace.radius
        offset.y: IrisStyle.density
        blur: 3 * IrisStyle.density
        color: IrisStyle.shadow
    }
    Rectangle {
        id: knobFace
        visible: root.knob && !skin.active && !root.nothing
        width: Math.round((root.synth ? (root.engaged ? 12 : 10) : root.engaged ? 20 : 18) * IrisStyle.density)
        height: root.synth ? Math.round(20 * IrisStyle.density) : width
        radius: root.synth ? IrisStyle.synthCapRadius : IrisStyle.capsule(width)
        x: Math.max(0, Math.min(bar.width - width, bar.width * root.shownValue - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: root.synth ? IrisStyle.synthCap : IrisStyle.onTint
        Behavior on width { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        Loader {
            active: root.gel
            anchors.fill: parent
            sourceComponent: Rectangle {
                radius: knobFace.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.gelPearlTop }
                    GradientStop { position: 1; color: IrisStyle.gelPearlBottom }
                }
            }
        }
        // Synth: the cap's line says where the level stands.
        Rectangle {
            visible: root.synth
            anchors.centerIn: parent
            width: parent.width - Math.round(4 * IrisStyle.density)
            height: Math.max(2, Math.round(2 * IrisStyle.density))
            color: IrisStyle.synthLevel
        }
    }
    IrisDotStrip {
        id: track
        visible: !skin.active && root.nothing
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.valueRoom
        height: Math.max(dotSize, knobSize)
        value: root.shownValue
        stagger: !root.dragging
        dotSize: Math.max(3, Math.round(4 * IrisStyle.density))
        gap: Math.max(3, Math.round(5 * IrisStyle.density))
        knobSize: root.seekable && (root.knob || root.engaged) ? Math.round((root.dragging ? 13 : 11) * IrisStyle.density) : 0
        fillColor: root.fillColor
        // A track colour given as a faint film still has to read as dots.
        emptyColor: Qt.rgba(root.trackColor.r, root.trackColor.g, root.trackColor.b, Math.max(0.2, root.trackColor.a))
    }
    IrisLabel {
        id: valueLabel
        visible: root.valueShown && !typing.visible
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: String(root.range?.text ?? "")
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.IBeamCursor
            onClicked: { typing.text = String(root.range?.value ?? ""); typing.visible = true; typing.forceActiveFocus(); typing.selectAll() }
        }
    }
    TextInput {
        id: typing
        visible: false
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(valueLabel.implicitWidth, Math.round(40 * IrisStyle.density))
        horizontalAlignment: TextInput.AlignRight
        color: IrisStyle.text
        selectionColor: IrisStyle.accentContainer
        selectedTextColor: IrisStyle.inkOnAccentContainer
        font.family: IrisStyle.fontLabel
        font.pixelSize: IrisStyle.typeLabelMono
        validator: DoubleValidator {}
        Keys.onEscapePressed: typing.visible = false
        onActiveFocusChanged: if (!activeFocus) typing.visible = false
        onAccepted: {
            const min = Number(root.range?.min ?? 0), max = Number(root.range?.max ?? 1)
            const typed = Number(typing.text.replace(",", "."))
            typing.visible = false
            if (!Number.isFinite(typed) || max <= min) return
            const next = Math.max(0, Math.min(1, (typed - min) / (max - min)))
            root.moved(next)
            root.seekRequested(next)
        }
    }

    MouseArea {
        id: pointer
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.width - root.valueRoom
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.seekable
        hoverEnabled: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function valueAt(px: real): real { return Math.max(0, Math.min(1, (px - root.laneStart) / Math.max(1, root.laneLength))) }
        onPressed: mouse => { root.forceActiveFocus(); root.dragValue = valueAt(mouse.x); root.moved(root.dragValue) }
        onPositionChanged: mouse => { wheelIntent.track(mouse.x, mouse.y); if (pressed) { root.dragValue = valueAt(mouse.x); root.moved(root.dragValue) } }
        onReleased: {
            if (root.dragValue >= 0) root.seekRequested(root.dragValue)
            root.dragValue = -1
        }
        onCanceled: {
            if (root.dragValue >= 0) root.seekRequested(root.dragValue)
            root.dragValue = -1
        }
        preventStealing: true
        property real wheelAccumulator: 0
        Kit.WheelIntent { id: wheelIntent; hovered: pointer.containsMouse }
        onWheel: wheel => {
            if (!wheelIntent.take(wheel)) return
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
            pointer.wheelAccumulator += delta
            const steps = Math.trunc(pointer.wheelAccumulator / 120)
            if (steps === 0) return
            pointer.wheelAccumulator -= steps * 120
            const next = Math.max(0, Math.min(1, root.shownValue + steps * root.wheelStep))
            root.moved(next)
            root.seekRequested(next)
        }
    }
}
