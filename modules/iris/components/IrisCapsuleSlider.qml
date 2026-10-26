pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    property real value: 0
    property string icon: "volume_up"
    property bool muted: false
    property bool vertical: false
    // Apple: the fill rises from the foot as on a phone's Control Center, its number only while held or hovered.
    // Nothing (S4): a run of dots past the glyph's pocket with a larger dot for the knob. Synth: a fader over ticks
    // past the pocket. Gel: Apple's rising fill, glossy in the accent.
    readonly property string look: IrisStyle.lookOf(root)
    readonly property bool nothing: root.look === "nothing"
    readonly property bool synth: root.look === "synth" && !root.skinned
    readonly property bool gel: root.look === "gel" && !root.skinned
    property color fillColor: root.nothing ? IrisStyle.text : root.gel ? IrisStyle.gelBody : IrisStyle.fillStrong
    // the icon's ink once the fill reaches it
    property color inkOnFill: IrisStyle.surface
    property bool readout: false
    // The level's name, for a Design that sets it in words beside the level (AIRISU's rule).
    property string label: ""
    readonly property bool hovered: pointer.containsMouse
    readonly property bool held: root.dragValue >= 0
    property real cornerCap: IrisStyle.radiusSheet
    signal moved(real value)
    signal iconClicked()
    // A Design may draw the level its own way (AIRISU: the twenty-segment meter); drag, wheel and pocket stay here.
    readonly property bool skinned: meterSkin.active

    property real dragValue: -1
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : (Number.isFinite(root.value) ? root.value : 0)))
    readonly property real thickness: root.vertical ? root.width : root.height
    readonly property real span: root.vertical ? root.height : root.width
    readonly property real corner: Math.min(root.thickness / 2, root.cornerCap)
    readonly property real pocket: Math.min(root.thickness, Math.round(52 * IrisStyle.density))

    implicitWidth: root.vertical ? Math.round(46 * IrisStyle.density) : 260
    implicitHeight: root.vertical ? 120 : Math.round(44 * IrisStyle.density)
    Accessible.role: Accessible.Slider

    IrisSkin { id: meterSkin; part: "meter" }
    Rectangle {
        id: track
        visible: !root.skinned
        anchors.fill: parent
        radius: root.corner
        color: IrisStyle.fill
        scale: pointer.pressed ? 1.015 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        Readout { ink: IrisStyle.textSecondary }
        Item {
            id: fillClip
            visible: !root.nothing && !root.synth
            property real length: root.span * root.shownValue
            Behavior on length {
                enabled: root.dragValue < 0
                NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing }
            }
            y: root.vertical ? track.height - fillClip.length : 0
            width: root.vertical ? track.width : fillClip.length
            height: root.vertical ? fillClip.length : track.height
            clip: true
            Rectangle {
                y: -fillClip.y
                width: track.width
                height: track.height
                radius: root.corner
                color: root.muted ? IrisStyle.textTertiary : root.fillColor
                Loader {
                    active: root.gel && !root.muted
                    anchors.fill: parent
                    sourceComponent: Rectangle {
                        radius: root.corner
                        gradient: Gradient {
                            GradientStop { position: 0; color: IrisStyle.gelTop }
                            GradientStop { position: 0.55; color: IrisStyle.gelBody }
                            GradientStop { position: 1; color: IrisStyle.gelBottom }
                        }
                        Rectangle {
                            x: Math.round(Math.min(parent.width, parent.height) * 0.3)
                            y: Math.round(2 * IrisStyle.density)
                            width: parent.width - 2 * x
                            height: Math.round(parent.height * 0.42)
                            radius: Math.min(height / 2, root.corner)
                            gradient: Gradient {
                                GradientStop { position: 0; color: IrisStyle.gelShineTop }
                                GradientStop { position: 1; color: IrisStyle.gelShineBottom }
                            }
                        }
                    }
                }
                Readout { ink: root.gel ? IrisStyle.inkOnGel : IrisStyle.surface }
            }
        }
        // Synth: laid out lying down and stood up for a vertical level; the fill and the cap say the level.
        Loader {
            id: fader
            active: root.synth
            readonly property real inset: Math.round(16 * IrisStyle.density)
            readonly property real readoutRoom: root.readout && !root.vertical ? Math.round(30 * IrisStyle.density) : 0
            x: root.vertical ? 0 : root.pocket
            y: root.vertical ? (root.readout ? Math.round(34 * IrisStyle.density) : fader.inset) : 0
            width: root.vertical ? track.width : track.width - root.pocket - fader.inset - fader.readoutRoom
            height: root.vertical ? track.height - root.pocket - y : track.height
            // Sized by the Loader; the body inside turns on its own for a vertical level.
            sourceComponent: Item {
                Item {
                    id: faderBody
                    anchors.centerIn: parent
                    width: root.vertical ? fader.height : fader.width
                    height: root.vertical ? fader.width : fader.height
                    rotation: root.vertical ? -90 : 0
                    readonly property real d: IrisStyle.density
                    readonly property real at: faderBody.width * root.shownValue
                    Repeater {
                        model: 11
                        Rectangle {
                            required property int index
                            x: Math.round(faderBody.width * index / 10 - width / 2)
                            y: Math.round(faderBody.height / 2 + 6 * faderBody.d)
                            width: Math.max(1, Math.round(faderBody.d))
                            height: Math.round((index % 5 === 0 ? 6 : 4) * faderBody.d)
                            color: IrisStyle.synthLedOff
                        }
                    }
                    Rectangle {
                        y: Math.round(faderBody.height / 2 - height / 2)
                        width: faderBody.width
                        height: Math.max(2, Math.round(2 * faderBody.d))
                        color: IrisStyle.synthLedOff
                    }
                    Rectangle {
                        y: Math.round(faderBody.height / 2 - height / 2)
                        width: faderBody.at
                        height: Math.round(4 * faderBody.d)
                        color: root.muted ? IrisStyle.textTertiary : IrisStyle.synthLevel
                    }
                    Rectangle {
                        readonly property real tall: Math.min(faderBody.height - 6 * faderBody.d, Math.round(26 * faderBody.d))
                        x: Math.round(Math.max(0, Math.min(faderBody.width - width, faderBody.at - width / 2)))
                        y: Math.round((faderBody.height - tall) / 2)
                        width: Math.round((pointer.pressed ? 14 : 12) * faderBody.d)
                        height: tall
                        radius: IrisStyle.synthCapRadius
                        color: IrisStyle.synthCap
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - Math.round(4 * faderBody.d)
                            height: Math.max(2, Math.round(2 * faderBody.d))
                            color: root.muted ? IrisStyle.textTertiary : IrisStyle.synthLevel
                        }
                    }
                }
            }
        }
        // Muted, the dots go quiet but keep the level.
        IrisDotStrip {
            id: dots
            visible: root.nothing
            readonly property real inset: Math.round(14 * IrisStyle.density)
            readonly property real readoutRoom: root.readout && !root.vertical ? Math.round(30 * IrisStyle.density) : 0
            vertical: root.vertical
            x: root.vertical ? 0 : root.pocket
            y: root.vertical ? (root.readout ? Math.round(34 * IrisStyle.density) : dots.inset) : 0
            width: root.vertical ? track.width : track.width - root.pocket - dots.inset - dots.readoutRoom
            height: root.vertical ? track.height - root.pocket - y : track.height
            value: root.shownValue
            stagger: root.dragValue < 0
            dotSize: Math.max(3, Math.round(4 * IrisStyle.density))
            gap: Math.max(3, Math.round(5 * IrisStyle.density))
            knobSize: Math.round((pointer.pressed ? 13 : 11) * IrisStyle.density)
            fillColor: root.muted ? IrisStyle.textTertiary : root.fillColor
        }

        MaterialSymbol {
            x: root.vertical ? (track.width - width) / 2 : (root.pocket - width) / 2
            y: root.vertical ? track.height - root.pocket + (root.pocket - height) / 2 : (track.height - height) / 2
            text: root.icon
            fill: 1
            iconSize: Math.round((root.vertical ? 19 : 20) * IrisStyle.density)
            readonly property bool overFill: !root.nothing && !root.synth && !root.muted && fillClip.length >= root.pocket * 0.72
            color: overFill ? (root.gel ? IrisStyle.inkOnGel : root.inkOnFill) : root.muted ? IrisStyle.textTertiary : IrisStyle.text
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    onMoved: GlobalStates.quietIrisLevels()
    onIconClicked: GlobalStates.quietIrisLevels()

    MouseArea {
        id: pointer
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        hoverEnabled: true
        function valueAt(mouse): real {
            return Math.max(0, Math.min(1, root.vertical ? 1 - mouse.y / Math.max(1, height) : mouse.x / Math.max(1, width)))
        }
        function inPocket(mouse): bool {
            return root.vertical ? mouse.y > height - root.pocket : mouse.x < root.pocket
        }
        onPressed: mouse => {
            if (inPocket(mouse)) return
            root.dragValue = valueAt(mouse)
            root.moved(root.dragValue)
        }
        onPositionChanged: mouse => {
            wheelIntent.track(mouse.x, mouse.y)
            if (!pressed || root.dragValue < 0) return
            root.dragValue = valueAt(mouse)
            root.moved(root.dragValue)
        }
        onReleased: mouse => {
            if (root.dragValue < 0 && inPocket(mouse)) root.iconClicked()
            root.dragValue = -1
        }
        onCanceled: root.dragValue = -1
        property real wheelAccumulator: 0
        WheelIntent { id: wheelIntent; hovered: pointer.containsMouse }
        onWheel: wheel => {
            if (!wheelIntent.take(wheel)) return
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
            pointer.wheelAccumulator += delta
            const steps = Math.trunc(pointer.wheelAccumulator / 120)
            if (steps === 0) return
            pointer.wheelAccumulator -= steps * 120
            root.moved(Math.max(0, Math.min(1, root.value + steps * 0.05)))
        }
    }

    component Readout: IrisText {
        property color ink: IrisStyle.text
        readonly property real inset: Math.round(14 * IrisStyle.density)
        visible: root.readout && (root.nothing || root.synth || pointer.containsMouse || root.dragValue >= 0)
        x: root.vertical ? (track.width - width) / 2 : track.width - width - inset
        y: root.vertical ? inset : (track.height - height) / 2
        text: Math.round(root.shownValue * 100)
        color: ink
        role: IrisText.Value
    }
}
