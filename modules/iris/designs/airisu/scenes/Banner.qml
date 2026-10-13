pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's notification banner: a ticket (切符) torn off for the notice. Its head is a sign: who sent it and when, set as
// a ruby in the data face's capitals, then the subject and the words. A notice that carries a picture (a face, a shot)
// holds it in a disc, the die AIRISU keeps for persons. A notice that can be answered is perforated across, half moons
// punched at both sides, and its answers are the stubs under the perforation. Along its foot runs the line colour of
// what it is about (messages, devices, energy…), the way a station sign says which line. The time it has left is a run
// of shu along its head, drawn back a step at a time; when the run is gone the banner leaves, and the pointer keeps it
// whole (the engine stops its clock). It lands as a stamp: the die is ruled first and the lacquer is laid one detent
// later. A critical one never times out: its head is a band of yamabuki, its die ruled in yamabuki, and its sign is
// printed in yamabuki before the sender; nothing else on it is yellow.
// IrisBanners keeps the list, the swipe, the clock, the tap and the body; this is what it holds.
Item {
    id: root
    property var notification
    property bool hovered: false
    property real now: Date.now()
    readonly property real d: Airisu.d
    // The service keeps the urgency as the enum's number in a string ("2" is critical).
    readonly property bool critical: ["2", "critical"].includes(String(root.notification?.urgency ?? "").toLowerCase())
    readonly property var actions: (root.notification?.actions ?? []).filter(action => action.identifier !== "default")
    readonly property string app: String(root.notification?.appName ?? "")
    readonly property string title: String(root.notification?.summary || root.notification?.appName || "")
    readonly property string message: String(root.notification?.body ?? "").replace(/<[^>]*>/g, "")
    readonly property string image: String(root.notification?.image ?? "")
    readonly property int pad: Airisu.u(4)
    readonly property int kiss: Airisu.kiss
    // What the engine reads the notice as: its sign and its line colour.
    readonly property var semantic: mark.semantic ?? ({ glyph: "notifications", tint: IrisStyle.identity.gray })
    readonly property color line: root.semantic.tint ?? IrisStyle.identity.gray
    readonly property color lacquer: Airisu.stockOf(Airisu.pigment("message"))
    readonly property color ink: Airisu.inkOn(root.lacquer)
    readonly property color inkSecond: Airisu.inkSecondOn(root.lacquer)
    readonly property color inkThird: Airisu.inkThirdOn(root.lacquer)
    readonly property color caution: Airisu.tape
    readonly property int head: root.critical ? Airisu.u(1) : Airisu.strong
    readonly property int foot: root.critical ? 0 : Math.max(2, Math.round(3 * root.d))
    readonly property int stubHeight: Airisu.u(9)
    readonly property bool stubbed: root.actions.length > 0
    implicitHeight: 2 * root.kiss + root.head + root.pad + slip.implicitHeight + root.pad
        + (root.stubbed ? root.stubHeight : 0) + root.foot

    // The engine's clock for this banner; gone once the pointer has kept it, absent when it never times out.
    readonly property var clock: root.notification?.timer ?? null
    property real torn: 0
    onClockChanged: if (!root.clock) root.torn = 0
    Timer {
        running: !!root.clock && root.visible === true
        repeat: true
        triggeredOnStart: true
        // Forty steps over the banner's time: the run only moves when a step goes, so nothing is drawn in between.
        interval: Math.max(40, Math.round(Number(root.clock?.interval ?? 4000) / 40))
        onTriggered: {
            const span = Math.max(1, Number(root.clock?.interval ?? 1))
            const born = Number(root.notification?.time ?? Date.now())
            root.torn = Math.min(1, Math.max(0, (Date.now() - born) / span))
        }
    }

    // Stamped: the die is ruled as the banner lands, and its lacquer laid a detent later.
    property bool landed: !Airisu.moving
    Timer { running: !root.landed; interval: IrisStyle.emergeDuration; onTriggered: root.landed = true }

    // Sign and line colour come from the engine; the mark itself is not printed on the ticket.
    IrisNotificationIcon {
        id: mark
        visible: false
        appName: root.app
        appIcon: String(root.notification?.appIcon ?? "")
        image: root.image
        summary: String(root.notification?.summary ?? "")
        critical: root.critical
    }

    Item {
        id: ticket
        x: root.kiss
        y: root.kiss
        width: root.width - 2 * root.kiss
        height: root.height - 2 * root.kiss
        readonly property int cut: Math.max(2, Airisu.chamfer - root.kiss)
        readonly property real perforation: root.head + root.pad + slip.height + root.pad

        ALacquer {
            anchors.fill: parent
            cut: ticket.cut
            lacquer: root.landed ? root.lacquer : "transparent"
        }
        ADie {
            visible: !root.landed || root.critical
            anchors.fill: parent
            kind: "chamfer"
            cut: ticket.cut
            stroke: root.critical ? root.caution : root.ink
            strokeWidth: Airisu.hair
        }

        // The head: the time left in shu, or a critical one's band of yamabuki. It runs from the cut back to the start.
        Rectangle {
            x: 0
            y: 0
            height: root.head
            // A notice that never times out has no run, unless the pointer holds it.
            width: root.critical ? parent.width - ticket.cut
                : root.clock ? Math.round((parent.width - ticket.cut) * (1 - root.torn))
                : root.hovered ? parent.width - ticket.cut : 0
            color: root.critical ? root.caution : Airisu.seal
            antialiasing: false
        }

        Item {
            id: slip
            x: root.pad
            y: root.head + root.pad
            width: parent.width - 2 * root.pad
            implicitHeight: Math.max(words.implicitHeight, disc.visible ? disc.height : 0)
            height: implicitHeight

            // A notice with a picture holds it in a disc at the start.
            ClippingRectangle {
                id: disc
                visible: mark.hasImage
                width: Airisu.u(11)
                height: width
                radius: width / 2
                color: Airisu.groundRaised
                IrisImage {
                    anchors.fill: parent
                    source: disc.visible ? root.image : ""
                }
            }

            Column {
                id: words
                x: disc.visible ? disc.width + Airisu.u(3) : 0
                width: parent.width - x
                spacing: Math.round(2 * root.d)

                // The sign: what sent it and when, in the data face; on hover, the key that puts it away.
                Item {
                    width: parent.width
                    height: sender.implicitHeight
                    Row {
                        id: senderRow
                        spacing: Airisu.u(1)
                        MaterialSymbol {
                            visible: root.critical
                            anchors.verticalCenter: parent.verticalCenter
                            text: "priority_high"
                            fill: 1
                            iconSize: Math.round(13 * root.d)
                            color: Airisu.caution
                        }
                        AText {
                            id: sender
                            width: Math.min(implicitWidth, words.width - Airisu.u(8))
                            voice: "mono"
                            size: IrisStyle.typeCaption
                            color: root.critical ? Airisu.caution : root.inkSecond
                            text: {
                                const seconds = Math.max(0, Math.floor((root.now - Number(root.notification?.time ?? root.now)) / 1000))
                                const when = seconds < 60 ? Translation.tr("now")
                                    : seconds < 3600 ? Translation.tr("%1m").arg(Math.floor(seconds / 60))
                                    : Translation.tr("%1h").arg(Math.floor(seconds / 3600))
                                return root.app.length > 0 && root.app !== root.title ? root.app + "  ·  " + when : when
                            }
                        }
                    }
                }
                AText {
                    width: parent.width
                    size: IrisStyle.typeHeadline
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    color: root.ink
                    text: root.title
                }
                AText {
                    width: parent.width
                    visible: text.length > 0
                    size: IrisStyle.typeLabel
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: root.hovered ? 8 : 2
                    lineHeight: 1.1
                    color: root.critical ? root.ink : root.inkSecond
                    text: root.message
                }
            }
        }

        // Kept, it can be put away: the key stands at the end of the sign.
        IrisButton {
            id: dismiss
            quiet: true
            visible: root.hovered
            width: Airisu.u(6)
            height: Airisu.u(6)
            x: parent.width - root.pad - width + Airisu.u(1.5)
            y: slip.y - Airisu.u(1.5)
            Accessible.name: Translation.tr("Dismiss")
            onClicked: Notifications.timeoutNotification(root.notification.notificationId)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: Math.round(15 * root.d)
                color: root.ink
            }
        }

        // The perforation: half moons punched at both sides, a row of holes between them.
        Item {
            visible: root.stubbed
            y: ticket.perforation
            width: parent.width
            Rectangle {
                width: Airisu.u(2.5)
                height: width
                radius: width / 2
                x: -width / 2
                y: -height / 2
                color: Airisu.solid(IrisStyle.bodySurface)
            }
            Rectangle {
                width: Airisu.u(2.5)
                height: width
                radius: width / 2
                x: parent.width - width / 2
                y: -height / 2
                color: Airisu.solid(IrisStyle.bodySurface)
            }
            Repeater {
                model: Math.max(0, Math.floor((ticket.width - Airisu.u(6)) / Airisu.u(1.5)))
                Rectangle {
                    required property int index
                    x: Airisu.u(3) + index * Airisu.u(1.5)
                    y: -Math.round(root.d)
                    width: Math.max(1, Math.round(2 * root.d))
                    height: width
                    color: root.inkThird
                    antialiasing: false
                }
            }
        }
        // The stubs: one per answer, parted by a rule.
        Row {
            visible: root.stubbed
            y: ticket.perforation
            width: parent.width
            height: root.stubHeight
            Repeater {
                model: root.actions
                Item {
                    id: stub
                    required property var modelData
                    required property int index
                    width: Math.floor(ticket.width / Math.max(1, root.actions.length))
                    height: root.stubHeight
                    Rectangle {
                        visible: stub.index > 0
                        x: 0
                        y: Airisu.u(2)
                        width: Airisu.hair
                        height: parent.height - Airisu.u(4)
                        color: root.inkThird
                    }
                    // A stub is torn off to answer: its word set in capitals like a ticket's printed choice.
                    IrisButton {
                        id: answer
                        anchors.fill: parent
                        anchors.margins: Airisu.u(1)
                        quiet: true
                        Accessible.name: String(stub.modelData.text ?? "")
                        skinData: ({ under: root.lacquer })
                        onClicked: Notifications.attemptInvokeAction(root.notification.notificationId, stub.modelData.identifier)
                        AText {
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, answer.width - Airisu.u(2))
                            size: IrisStyle.typeFootnote
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: Math.round(IrisStyle.typeFootnote * 0.08)
                            color: root.ink
                            text: String(stub.modelData.text ?? "")
                        }
                    }
                }
            }
        }

        // The line colour along the foot.
        Rectangle {
            visible: root.foot > 0
            x: ticket.cut
            y: parent.height - root.foot
            width: parent.width - ticket.cut
            height: root.foot
            color: root.line
            antialiasing: false
        }
    }
}
