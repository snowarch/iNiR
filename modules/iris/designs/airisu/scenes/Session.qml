pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import "../components"

// AIRISU's session screen: a row of tickets (切符), one per action (locking in tame, the others breathing the accent's
// shu), each with the key that takes it (S1…) leaning on its stub, a perforation and half moons where the stub would be
// torn, and its sign and name under it. What cannot be undone is sealed by holding it: a seal box beside the sign is
// stamped from its middle out over 600 ms, and when it is whole it is done; letting go lifts it. The keyboard asks twice,
// as the engine does, and the box waits stamped between the two. As the screen comes up the tickets are laid one after
// another. IrisSessionScreen keeps the actions, the keys and the confirm.
Item {
    id: root
    property var host
    property bool shown: false
    readonly property real d: Airisu.d
    readonly property var actions: root.host?.actions ?? []
    readonly property int ticketWidth: Math.round(128 * root.d)
    readonly property int ticketHeight: Math.round(168 * root.d)
    readonly property int gap: Airisu.u(2)
    readonly property int pad: Airisu.u(3)
    implicitWidth: sheet.width
    implicitHeight: sheet.height

    function pigmentOf(id: string): color {
        switch (id) {
        case "suspend": return Airisu.pigment("time")
        case "reboot": return Airisu.pigment("restart")
        case "poweroff": return Airisu.pigment("live")
        case "lock": return Airisu.pigment("system")
        case "logout": return Airisu.pigment("message")
        default: return Airisu.pigment("rest")
        }
    }

    Column {
        id: sheet
        anchors.centerIn: parent
        spacing: Airisu.u(6)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { enabled: Airisu.moving; NumberAnimation { duration: Airisu.snap } }

        // The date over the time, set on the backdrop in the media's ink.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Airisu.u(1)
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: IrisStyle.onMediaSecondary
                text: Translation.locale.toString(DateTime.clock.date, "dddd, d MMMM")
            }
            AText {
                anchors.horizontalCenter: parent.horizontalCenter
                voice: "figure"
                lean: Airisu.lean
                size: 2 * IrisStyle.typeDisplay
                color: IrisStyle.onMedia
                text: DateTime.time
            }
        }

        Row {
            id: strip
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.gap

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
                    // How much of the coat is laid while it is held (0 to 1); a stand-in host (the Design proof) may
                    // show a hold under way.
                    property real ink: (root.host?.held?.index ?? -1) === ticket.index ? Number(root.host.held.ink) : 0
                    readonly property int run: ticket.pressed ? Airisu.hair : 0
                    readonly property color pigment: root.pigmentOf(String(ticket.modelData.id ?? ""))
                    readonly property color lacquer: Airisu.lacquerOf(ticket.pigment)
                    readonly property color coat: Airisu.vivid(ticket.pigment)
                    readonly property color face: ticket.hovered && !ticket.pressed ? Airisu.step(ticket.lacquer, Airisu.hoverStep) : ticket.lacquer
                    // How far the coat is laid: the hold's, or all of it while the keyboard waits for the second press.
                    readonly property real laidShare: ticket.waiting ? 1 : ticket.ink
                    // Each thing printed takes the ticket's ink (the seal is stamped beside the words, never under them).
                    function under(px: real, py: real): bool { return false }
                    function inkAt(px: real, py: real): color { return Airisu.inkOn(ticket.under(px, py) ? ticket.coat : ticket.face) }
                    function secondAt(px: real, py: real): color {
                        const on = ticket.under(px, py)
                        return ColorUtils.mix(Airisu.inkOn(on ? ticket.coat : ticket.face), on ? ticket.coat : ticket.face, 0.74) // iris-literal: second tone on lacquer
                    }
                    // Laid one after another as the screen comes up.
                    property bool laid: false
                    width: root.ticketWidth
                    height: root.ticketHeight
                    Timer {
                        running: root.shown && !ticket.laid
                        interval: Airisu.moving ? 40 + ticket.index * 45 : 0
                        onTriggered: ticket.laid = true
                    }
                    Connections {
                        target: root
                        function onShownChanged() { if (!root.shown) ticket.laid = false }
                    }

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

                    // The ticket: punched with a half moon at both sides where its stub is torn off.
                    readonly property real perforation: root.pad + Airisu.u(7)
                    ADie {
                        anchors.fill: parent
                        kind: "ticket"
                        notchY: ticket.perforation
                        notchRadius: Airisu.u(1.5)
                        fill: ticket.laid ? ticket.face : "transparent"
                    }
                    Row {
                        x: Airisu.u(3)
                        y: ticket.perforation - Math.round(Airisu.d)
                        spacing: Airisu.u(1.5) - width0
                        readonly property int width0: Math.max(1, Math.round(2 * Airisu.d))
                        Repeater {
                            model: Math.max(0, Math.floor((ticket.width - Airisu.u(6)) / Airisu.u(1.5)))
                            Rectangle {
                                width: Math.max(1, Math.round(2 * Airisu.d))
                                height: width
                                color: Airisu.inkThirdOn(ticket.face)
                                antialiasing: false
                            }
                        }
                    }
                    // What cannot be undone is sealed by holding it: the box is stamped from its middle out as the hold
                    // goes, and whole while the keyboard waits for the second press.
                    ASeal {
                        visible: ticket.confirms
                        x: parent.width - root.pad - width + ticket.run
                        y: ticket.perforation + root.pad + ticket.run
                        width: Airisu.u(10)
                        height: width
                        stamped: ticket.laidShare > 0
                        rule: Airisu.inkThirdOn(ticket.face)
                        seal: ticket.coat
                        pressed: ticket.laidShare
                        driven: true
                    }
                    AMarks {
                        anchors.fill: parent
                        shown: ticket.keyed
                        color: Airisu.seal
                    }

                    Item {
                        width: parent.width
                        height: parent.height
                        x: ticket.run
                        y: ticket.run
                        // The key that takes it.
                        AText {
                            x: root.pad
                            y: root.pad
                            voice: "figure"
                            lean: Airisu.lean
                            size: IrisStyle.typeLabel
                            color: ticket.secondAt(x + width / 2, y + height / 2)
                            text: "S" + (ticket.index + 1)
                        }
                        MaterialSymbol {
                            x: root.pad - Math.round(2 * root.d)
                            y: ticket.perforation + root.pad
                            text: String(ticket.modelData.icon ?? "")
                            fill: 1
                            iconSize: Math.round(34 * root.d)
                            color: ticket.inkAt(x + width / 2, y + height / 2)
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
                                size: IrisStyle.typeFootnote
                                font.weight: Font.Bold
                                color: ticket.secondAt(words.x + Math.min(implicitWidth, width) / 2, words.y + y + height / 2)
                                text: !ticket.confirms ? " "
                                    : ticket.waiting ? Translation.tr("Confirm") : Translation.tr("Hold to confirm")
                            }
                            AText {
                                width: parent.width
                                size: IrisStyle.typeHeadline
                                font.weight: Font.Bold
                                color: ticket.inkAt(words.x + Math.min(implicitWidth, width) / 2, words.y + y + height / 2)
                                text: String(ticket.modelData.label ?? "")
                            }
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
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: root.host?.pendingAction ? IrisStyle.onMedia : IrisStyle.onMediaTertiary
            text: root.host?.pendingAction
                ? Translation.tr("Press %1 again to continue").arg(root.host.pendingAction.label)
                : Translation.tr("Up %1").arg(DateTime.uptime)
        }
    }
}
