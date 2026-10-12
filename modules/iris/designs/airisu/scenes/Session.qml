pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's session screen (SYSTEM.md §7): a strip of numbered tickets, as a book of coupon tickets (回数券) is printed,
// one ticket per action joined by perforations. Each carries its station code (S1…, the key that takes it) and its sign;
// the date stands over the time as ruby above the strip. What cannot be undone is sealed by holding it: the seal inks
// from the centre for 600 ms and stays printed, and letting go before does nothing (law 5); the keyboard asks twice, as
// the engine does, and the seal's ring waits printed in outline. The pointer brings trim marks on the ticket's cut
// lines, the keyboard the same marks in the seal. IrisSessionScreen keeps the actions, the keys and the confirm.
Item {
    id: root
    property var host
    property bool shown: false
    readonly property real d: Airisu.d
    readonly property var actions: root.host?.actions ?? []
    readonly property int ticketWidth: Math.round(128 * root.d)
    readonly property int ticketHeight: Math.round(168 * root.d)
    readonly property int pad: Airisu.u(3)
    // Trim marks: they stand off the strip by `air` and run `reach` beyond it, on the line a ticket is torn along.
    readonly property int air: Airisu.u(1.5)
    readonly property int reach: Airisu.u(3)
    implicitWidth: sheet.width
    implicitHeight: sheet.height

    // The stamp lands a step out of register and settles as the screen comes up.
    property bool settled: false
    onShownChanged: {
        if (!root.shown) { root.settled = false; return }
        if (Airisu.moving) settle.restart()
        else root.settled = true
    }
    Component.onCompleted: if (root.shown) settle.restart()
    Timer { id: settle; interval: Airisu.snap; onTriggered: root.settled = true }

    Column {
        id: sheet
        anchors.centerIn: parent
        spacing: Airisu.u(6)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { enabled: Airisu.moving; NumberAnimation { duration: Airisu.snap } }
        transform: Translate {
            x: root.settled ? 0 : Airisu.registration
            y: root.settled ? 0 : Airisu.registration
            Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
            Behavior on y { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        }

        // The date as ruby over the time, set on the backdrop in the media's ink.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Airisu.u(1)
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                voice: "ruby"
                size: IrisStyle.typeLabel
                color: IrisStyle.onMediaSecondary
                text: Translation.locale.toString(DateTime.clock.date, "dddd, d MMMM")
            }
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                voice: "figure"
                size: 2 * IrisStyle.typeDisplay
                color: IrisStyle.onMedia
                text: DateTime.time
            }
        }

        // The strip.
        Item {
            id: strip
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.actions.length * root.ticketWidth
            height: root.ticketHeight

            ADie {
                anchors.fill: parent
                kind: "chamfer"
                cut: Airisu.chamfer
                fill: Airisu.ground
            }
            Repeater {
                model: Math.max(0, root.actions.length - 1)
                APerforation {
                    required property int index
                    x: (index + 1) * root.ticketWidth - Math.round(width / 2)
                    height: strip.height
                    vertical: true
                    colour: Airisu.inkThird
                }
            }

            Repeater {
                model: root.actions
                Item {
                    id: ticket
                    required property var modelData
                    required property int index
                    readonly property bool confirms: ticket.modelData.confirm === true
                    readonly property bool keyed: (root.host?.keyboardNavigation ?? false) && (root.host?.focusIndex ?? -1) === ticket.index
                    readonly property bool waiting: (root.host?.pending ?? "") === ticket.modelData.id
                    readonly property bool hovered: area.containsMouse
                    readonly property bool pressed: area.pressed
                    // How much of the seal is inked while it is held (0 to 1); a stand-in host (the Design proof) may
                    // show a hold under way.
                    property real ink: (root.host?.held?.index ?? -1) === ticket.index ? Number(root.host.held.ink) : 0
                    readonly property int run: ticket.pressed ? Airisu.registration : 0
                    x: ticket.index * root.ticketWidth
                    width: root.ticketWidth
                    height: root.ticketHeight

                    NumberAnimation {
                        id: inking
                        target: ticket
                        property: "ink"
                        to: 1
                        // The person's time: holding is the confirmation, so it never shortens with motion off.
                        duration: Math.round(Airisu.inkTime * (1 - ticket.ink))
                        onFinished: if (ticket.ink >= 1) root.host?.commit(ticket.index)
                    }
                    NumberAnimation {
                        id: lifting
                        target: ticket
                        property: "ink"
                        to: 0
                        duration: Airisu.snap
                    }

                    Item {
                        id: face
                        width: parent.width
                        height: parent.height
                        x: ticket.run
                        y: ticket.run

                        // The station code: its number is the key that takes it.
                        ADie {
                            id: code
                            x: root.pad
                            y: root.pad
                            width: codeText.implicitWidth + Airisu.u(2)
                            height: Airisu.u(5)
                            kind: "rect"
                            fill: ticket.keyed ? Airisu.seal : "transparent"
                            stroke: ticket.keyed ? "transparent" : Airisu.ink
                            strokeWidth: Airisu.hair
                            AText {
                                id: codeText
                                anchors.centerIn: parent
                                voice: "figure"
                                size: IrisStyle.typeLabel
                                font.letterSpacing: 0
                                color: ticket.keyed ? Airisu.inkOnSeal : Airisu.ink
                                text: "S" + (ticket.index + 1)
                            }
                        }

                        // The seal: a ring waits where it will be stamped, and holding inks it from the centre.
                        Item {
                            id: seal
                            readonly property int size: Math.round(64 * root.d)
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(code.y + code.height + (parent.height - code.y - code.height - words.height - root.pad - size) / 2)
                            width: seal.size
                            height: seal.size
                            Rectangle {
                                anchors.fill: parent
                                visible: ticket.confirms && (ticket.waiting || ticket.pressed || ticket.ink > 0)
                                radius: width / 2
                                color: "transparent"
                                border.width: Airisu.strong
                                border.color: Airisu.seal
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.round(seal.size * ticket.ink)
                                height: width
                                radius: width / 2
                                color: Airisu.seal
                            }
                            MaterialSymbol {
                                id: glyph
                                anchors.centerIn: parent
                                text: String(ticket.modelData.icon ?? "")
                                fill: 1
                                iconSize: Math.round(30 * root.d)
                                color: ticket.ink * seal.size >= glyph.iconSize * 1.1 ? Airisu.inkOnSeal : Airisu.ink
                            }
                        }

                        Column {
                            id: words
                            x: root.pad
                            width: parent.width - 2 * root.pad
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.pad
                            spacing: Math.round(2 * root.d)
                            AText {
                                width: parent.width
                                voice: "ruby"
                                color: ticket.waiting ? Airisu.sealText : Airisu.inkSecond
                                text: !ticket.confirms ? " "
                                    : ticket.waiting ? Translation.tr("Confirm") : Translation.tr("Hold to confirm")
                            }
                            AText {
                                width: parent.width
                                size: IrisStyle.typeHeadline
                                font.weight: Font.Bold
                                text: String(ticket.modelData.label ?? "")
                            }
                        }
                    }

                    // Trim marks on the ticket's cut lines, above and below the strip.
                    Repeater {
                        model: [[0, -1], [1, -1], [0, 1], [1, 1]]
                        Rectangle {
                            required property var modelData
                            visible: ticket.keyed || (ticket.hovered && !ticket.pressed && !(root.host?.keyboardNavigation ?? false))
                            color: ticket.keyed ? Airisu.seal : IrisStyle.onMedia
                            width: ticket.keyed ? Airisu.strong : Airisu.hair
                            height: root.reach
                            x: modelData[0] === 0 ? 0 : ticket.width - width
                            y: modelData[1] < 0 ? -root.air - height : ticket.height + root.air
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: String(ticket.modelData.label ?? "")
                        Accessible.description: ticket.confirms ? Translation.tr("Hold to confirm") : ""
                        onEntered: if (root.host) root.host.keyboardNavigation = false
                        onPressed: {
                            if (!ticket.confirms) return
                            lifting.stop()
                            inking.restart()
                        }
                        onClicked: if (!ticket.confirms) root.host?.trigger(ticket.index)
                        onReleased: if (ticket.confirms && ticket.ink < 1) { inking.stop(); lifting.restart() }
                        onCanceled: { inking.stop(); lifting.restart() }
                    }
                }
            }
        }

        // What the screen is waiting for, or how long the machine has been up.
        AText {
            anchors.horizontalCenter: parent.horizontalCenter
            voice: "ruby"
            size: IrisStyle.typeLabel
            color: root.host?.pendingAction ? IrisStyle.onMedia : IrisStyle.onMediaTertiary
            text: root.host?.pendingAction
                ? Translation.tr("Press %1 again to continue").arg(root.host.pendingAction.label)
                : Translation.tr("Up %1").arg(DateTime.uptime)
        }
    }
}
