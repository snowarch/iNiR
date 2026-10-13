pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's notice kept in Today: the banner's ticket (切符) at rest. Who sent it and when as a ruby in the data face's
// capitals, then the subject and the words; answers are stubs under a perforation punched with half moons, and the line
// colour of what it is about runs along its foot. A stack folded under it says how many more as a figure at its head.
// A critical one has a band of yamabuki at its head and its die ruled in yamabuki. The host keeps the taps (unfold,
// dismiss, answer).
Item {
    id: root
    property var host
    readonly property var notification: root.host?.notification ?? null
    readonly property int hidden: Number(root.host?.hidden ?? 0)
    readonly property bool critical: ["2", "critical"].includes(String(root.notification?.urgency ?? "").toLowerCase())
    readonly property var actions: root.notification?.actions ?? []
    readonly property string app: String(root.notification?.appName ?? "")
    readonly property real d: Airisu.d
    readonly property int pad: Airisu.u(3)
    readonly property color lacquer: Airisu.lacquerOf(Airisu.pigment("message"))
    readonly property color ink: Airisu.inkOn(root.lacquer)
    readonly property color inkSecond: Airisu.inkSecondOn(root.lacquer)
    readonly property color inkThird: Airisu.inkThirdOn(root.lacquer)
    readonly property int head: root.critical ? Airisu.u(1) : 0
    readonly property int foot: root.critical ? 0 : Math.max(2, Math.round(3 * root.d))
    readonly property int stubHeight: Airisu.u(8)
    readonly property bool stubbed: root.actions.length > 0
    readonly property int cut: Airisu.cutFor(root.height)
    implicitHeight: root.head + root.pad + words.implicitHeight + root.pad + (root.stubbed ? root.stubHeight : 0) + root.foot

    property real now: Date.now()
    Timer { interval: 30000; running: root.visible; repeat: true; onTriggered: root.now = Date.now() }

    IrisNotificationIcon {
        id: reading
        visible: false
        appName: root.app
        appIcon: String(root.notification?.appIcon ?? "")
        summary: String(root.notification?.summary ?? "")
        critical: root.critical
    }

    ALacquer {
        anchors.fill: parent
        cut: root.cut
        lacquer: root.lacquer
        moving: false
    }
    ADie {
        visible: root.critical
        anchors.fill: parent
        kind: "chamfer"
        cut: root.cut
        stroke: Airisu.tape
        strokeWidth: Airisu.hair
    }
    Rectangle {
        visible: root.critical
        width: parent.width - root.cut
        height: root.head
        color: Airisu.tape
        antialiasing: false
    }

    Column {
        id: words
        x: root.pad
        y: root.head + root.pad
        width: parent.width - 2 * root.pad
        spacing: Math.round(2 * root.d)
        Item {
            width: parent.width
            height: Math.max(ruby.implicitHeight, Airisu.u(5))
            AText {
                id: ruby
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - Airisu.u(14))
                voice: "mono"
                size: IrisStyle.typeCaption
                color: root.critical ? Airisu.caution : root.inkSecond
                text: {
                    const seconds = Math.max(0, Math.floor((root.now - Number(root.notification?.time ?? root.now)) / 1000))
                    const when = seconds < 60 ? Translation.tr("now")
                        : seconds < 3600 ? Translation.tr("%1m").arg(Math.floor(seconds / 60))
                        : seconds < 86400 ? Translation.tr("%1h").arg(Math.floor(seconds / 3600))
                        : Qt.formatDate(new Date(Number(root.notification?.time ?? root.now)), "d/M")
                    return root.app.length > 0 ? root.app + "  ·  " + when : when
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Airisu.u(1)
                AText {
                    visible: root.hidden > 0
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "figure"
                    lean: Airisu.lean
                    size: IrisStyle.typeLabel
                    color: root.inkSecond
                    text: "+" + root.hidden
                }
                IrisButton {
                    quiet: true
                    width: Airisu.u(5)
                    height: Airisu.u(5)
                    skinData: ({ under: root.lacquer })
                    Accessible.name: Translation.tr("Dismiss notification")
                    onClicked: root.host?.dismiss()
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Math.round(14 * root.d)
                        color: root.inkSecond
                    }
                }
            }
        }
        AText {
            width: parent.width
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            color: root.ink
            text: String(root.notification?.summary ?? "")
        }
        AText {
            width: parent.width
            visible: text.length > 0
            size: IrisStyle.typeFootnote
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            maximumLineCount: 4
            lineHeight: 1.1
            color: root.inkSecond
            text: String(root.notification?.body ?? "").replace(/<[^>]*>/g, "")
        }
    }

    // The perforation and the stubs.
    Item {
        visible: root.stubbed
        y: words.y + words.height + root.pad
        width: parent.width
        Rectangle {
            width: Airisu.u(2)
            height: width
            radius: width / 2
            x: -width / 2
            y: -height / 2
            color: Airisu.solid(IrisStyle.bodySurface)
        }
        Rectangle {
            width: Airisu.u(2)
            height: width
            radius: width / 2
            x: parent.width - width / 2
            y: -height / 2
            color: Airisu.solid(IrisStyle.bodySurface)
        }
        Repeater {
            model: Math.max(0, Math.floor((root.width - Airisu.u(5)) / Airisu.u(1.5)))
            Rectangle {
                required property int index
                x: Airisu.u(2.5) + index * Airisu.u(1.5)
                y: -Math.round(root.d)
                width: Math.max(1, Math.round(2 * root.d))
                height: width
                color: root.inkThird
                antialiasing: false
            }
        }
        Row {
            width: parent.width
            height: root.stubHeight
            Repeater {
                model: root.actions
                Item {
                    id: stub
                    required property var modelData
                    required property int index
                    width: Math.floor(root.width / Math.max(1, root.actions.length))
                    height: root.stubHeight
                    Rectangle {
                        visible: stub.index > 0
                        y: Airisu.u(2)
                        width: Airisu.hair
                        height: parent.height - Airisu.u(4)
                        color: root.inkThird
                    }
                    IrisButton {
                        anchors.fill: parent
                        anchors.margins: Airisu.u(1)
                        quiet: true
                        skinData: ({ under: root.lacquer })
                        text: stub.modelData.identifier === "default" ? Translation.tr("Open") : String(stub.modelData.text ?? "")
                        onClicked: root.host?.invoke(stub.modelData.identifier)
                    }
                }
            }
        }
    }

    Rectangle {
        visible: root.foot > 0
        x: root.cut
        y: parent.height - root.foot
        width: parent.width - root.cut
        height: root.foot
        color: reading.semantic?.tint ?? IrisStyle.identity.gray
        antialiasing: false
    }
}
