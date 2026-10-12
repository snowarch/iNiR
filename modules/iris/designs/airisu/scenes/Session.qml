pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's session screen: the lock's 2.39 letterbox, and the actions as a shifter gate. Each action is a gear on the H
// (1 Sleep, 2 Restart, 3 Shut down, 4 Lock, R Log out: the order the arrows walk; the keys 1–4 and R jump straight),
// and the knob travels the gate the way a lever does: back to neutral, across, into the gear. A gear that asks twice
// turns kerria amber and says so until it is pressed again. IrisSessionScreen keeps the actions, the keys and the
// confirm; this is the stage.
Item {
    id: root
    property Item host
    property bool shown: false
    readonly property real d: Airisu.d
    readonly property var actions: root.host?.actions ?? []
    readonly property int focusIndex: root.host?.focusIndex ?? 0
    readonly property string pending: root.host?.pending ?? ""
    property int hoverIndex: -1
    // The lever is in a gear while the pointer or the keys hold one; at rest it sits in neutral.
    readonly property bool engaged: root.hoverIndex >= 0 || (root.host?.keyboardNavigation ?? false) || root.pending.length > 0
    readonly property real bar: Math.max(Math.round(56 * root.d), Math.round((root.height - root.width / 2.39) / 2))

    // The gate: three throws, two rows, the neutral bar between them; R has a half throw at the top right.
    readonly property real gateWidth: Math.round(480 * root.d)
    readonly property real gateHeight: Math.round(168 * root.d)
    readonly property var gears: ["1", "2", "3", "4", "R"]
    function slotX(i: int): real { return Math.floor(i / 2) * root.gateWidth / 2 }
    function slotY(i: int): real { return i === 4 || i % 2 === 0 ? 0 : root.gateHeight }

    // The letterbox closes in with the focus shot (300 ms); what it frames arrives 40 ms after (the rolling shot).
    property real letterbox: root.shown ? 1 : 0
    Behavior on letterbox { NumberAnimation { duration: IrisStyle.motionEnabled ? 300 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }

    Rectangle { anchors.fill: parent; color: Airisu.lacquer; opacity: 0.72 * root.letterbox } // iris-literal: the night grade over the scene
    Rectangle { width: parent.width; height: Math.round(root.bar * root.letterbox); color: Airisu.lacquer }
    Rectangle { width: parent.width; height: Math.round(root.bar * root.letterbox); y: parent.height - height; color: Airisu.lacquer }

    component Slate: AText { voice: "mono"; color: Airisu.quiet }

    Item {
        width: parent.width
        height: root.bar
        opacity: root.letterbox
        Slate { x: Math.round(56 * root.d); anchors.verticalCenter: parent.verticalCenter; text: "SHIFT ● 2.39:1" }
        Slate {
            anchors.centerIn: parent
            text: `${SystemInfo.hostname || SystemInfo.distroName} / ${Translation.tr("Session")}`
        }
        Slate {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(56 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().toString(DateTime.clock.date, "ddd d MMM")
        }
    }

    // Night view, standing at the left, as on the lock: an ornament, faint.
    Column {
        x: Math.round(96 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        opacity: centre.opacity
        Repeater {
            model: ["夜", "景"]
            Text {
                required property string modelData
                text: modelData
                font.family: "Noto Sans CJK JP"
                font.weight: Font.Black
                font.pixelSize: Math.round(116 * root.d)
                color: Airisu.gofun
                opacity: 0.1 // iris-literal: an ornament, never information
                lineHeight: 0.92
                renderType: Text.NativeRendering
            }
        }
    }

    Column {
        id: centre
        anchors.centerIn: parent
        spacing: Math.round(44 * root.d)
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: IrisStyle.motionEnabled && root.shown ? 40 : 0 }
                NumberAnimation { duration: Airisu.roll; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
            }
        }

        // The time, wide, with the uptime as its slate.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(6 * root.d)
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                voice: "wide"
                size: Math.round(IrisStyle.typeDisplay * 2.6)
                text: Qt.locale().toString(DateTime.clock.date, "HH:mm")
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(12 * root.d)
                AStripe { anchors.verticalCenter: parent.verticalCenter; width: Math.round(36 * root.d); height: Math.round(7 * root.d); single: true }
                Slate { color: Airisu.data; text: `${Translation.tr("Uptime")} ${DateTime.uptime}` }
            }
        }

        Item {
            id: gate
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real node: Math.round(56 * root.d)
            readonly property real track: Math.max(2, Math.round(2 * root.d))
            readonly property real labelRoom: Math.round(34 * root.d)
            width: root.gateWidth + gate.node + Math.round(120 * root.d)
            height: root.gateHeight + gate.node + 2 * gate.labelRoom
            readonly property real ox: Math.round((gate.width - root.gateWidth) / 2)
            readonly property real oy: gate.node / 2 + gate.labelRoom

            // The slots cut in the plate.
            Rectangle { x: gate.ox; y: Math.round(gate.oy + root.gateHeight / 2 - gate.track / 2); width: root.gateWidth; height: gate.track; color: Airisu.fillet }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: Math.round(gate.ox + index * root.gateWidth / 2 - gate.track / 2)
                    y: gate.oy
                    width: gate.track
                    height: index === 2 ? root.gateHeight / 2 : root.gateHeight
                    color: Airisu.fillet
                }
            }
            // Neutral, marked where the lever rests.
            AText {
                x: Math.round(gate.ox + root.gateWidth / 2 + Math.round(16 * root.d))
                y: Math.round(gate.oy + root.gateHeight / 2 + Math.round(6 * root.d))
                voice: "mono"
                color: Airisu.quiet
                text: "N"
            }

            // The knob: it leaves the gear to neutral, crosses, and drops into the next one (≈210 ms in all).
            Rectangle {
                id: knob
                property real px: root.gateWidth / 2
                property real py: root.gateHeight / 2
                readonly property real size: Math.round(16 * root.d)
                z: 2
                x: Math.round(gate.ox + knob.px - knob.size / 2)
                y: Math.round(gate.oy + knob.py - knob.size / 2)
                width: knob.size
                height: knob.size
                radius: width / 2
                visible: !root.engaged || travel.running
                color: root.pending.length > 0 ? Airisu.amber : Airisu.seal
                readonly property real targetX: root.engaged ? root.slotX(root.focusIndex) : root.gateWidth / 2
                readonly property real targetY: root.engaged ? root.slotY(root.focusIndex) : root.gateHeight / 2
                onTargetXChanged: travelStart.restart()
                onTargetYChanged: travelStart.restart()
                // Both targets change in one step: start once, after both.
                Timer {
                    id: travelStart
                    interval: 0
                    onTriggered: {
                        travel.stop()
                        if (!IrisStyle.motionEnabled) { knob.px = knob.targetX; knob.py = knob.targetY; return }
                        travel.sameThrow = Math.abs(knob.px - knob.targetX) < 1
                        travel.start()
                    }
                }
                SequentialAnimation {
                    id: travel
                    property bool sameThrow: false
                    NumberAnimation { target: knob; property: "py"; to: travel.sameThrow ? knob.targetY : root.gateHeight / 2; duration: 60; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
                    NumberAnimation { target: knob; property: "px"; to: knob.targetX; duration: travel.sameThrow ? 0 : Airisu.shift; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
                    NumberAnimation { target: knob; property: "py"; to: knob.targetY; duration: 60; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
                }
            }

            Repeater {
                model: root.actions
                Item {
                    id: gear
                    required property var modelData
                    required property int index
                    readonly property bool upper: root.slotY(gear.index) === 0
                    // In gear once the lever has arrived: the plate snaps in with one pixel of rebound.
                    readonly property bool held: root.engaged && root.focusIndex === gear.index && !travel.running
                    readonly property bool armed: root.pending === String(gear.modelData.id)
                    x: Math.round(gate.ox + root.slotX(gear.index) - gate.node / 2)
                    y: Math.round(gate.oy + root.slotY(gear.index) - gate.node / 2)
                    width: gate.node
                    height: gate.node

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: gear.armed ? Airisu.amber : gear.held ? Airisu.gofun : Airisu.lacquer
                        border.width: Math.max(2, Math.round(2 * root.d))
                        border.color: gear.armed ? Airisu.amber : gear.held ? Airisu.gofun : point.containsMouse ? Airisu.gofun : Airisu.data
                        scale: point.pressed ? 0.94 : gear.held ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Airisu.shift; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                        AText {
                            anchors.centerIn: parent
                            voice: "wide"
                            size: IrisStyle.typeTitleLarge
                            color: gear.armed ? Airisu.inkOnAmber : gear.held ? Airisu.inkOnGofun : Airisu.gofun
                            text: root.gears[gear.index] ?? ""
                        }
                    }
                    // Its name outside the gate, above the top row and under the bottom one; a gear that asks says so.
                    AText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: gear.upper ? -height - Math.round(12 * root.d) : parent.height + Math.round(12 * root.d)
                        voice: "mono"
                        size: IrisStyle.typeFootnote
                        color: gear.armed ? Airisu.amber : gear.held ? Airisu.gofun : Airisu.data
                        text: gear.armed ? `${gear.modelData.label} · ${Translation.tr("Confirm")}` : String(gear.modelData.label ?? "")
                    }
                    MouseArea {
                        id: point
                        anchors.fill: parent
                        anchors.margins: -Math.round(14 * root.d)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: String(gear.modelData.label ?? "")
                        onContainsMouseChanged: {
                            if (point.containsMouse) {
                                root.hoverIndex = gear.index
                                if (root.host) { root.host.keyboardNavigation = false; root.host.focusIndex = gear.index }
                            } else if (root.hoverIndex === gear.index) root.hoverIndex = -1
                        }
                        onClicked: root.host?.trigger(gear.index)
                    }
                }
            }
        }

        AText {
            anchors.horizontalCenter: parent.horizontalCenter
            voice: "mono"
            color: root.pending.length > 0 ? Airisu.amber : Airisu.quiet
            text: root.pending.length > 0
                ? Translation.tr("Press %1 again to continue").arg(root.actions.find(action => action.id === root.pending)?.label ?? "")
                : `1–4 · R   ${Translation.tr("Engage")}      ESC   ${Translation.tr("Neutral")}`
        }
    }

    // Who is at the wheel.
    Column {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(64 * root.d)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bar + Math.round(36 * root.d)
        spacing: Math.round(2 * root.d)
        opacity: centre.opacity
        Slate { anchors.right: parent.right; text: Translation.tr("Driver") }
        AText {
            anchors.right: parent.right
            voice: "wide"
            size: IrisStyle.typeDisplay
            text: `[${SystemInfo.username}]`
        }
    }
}
