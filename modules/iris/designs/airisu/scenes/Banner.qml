pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's notification banner: the notice is laid on the body as a panel of lacquer in its pigment (the accent, a
// critical one the caution's yamabuki), the sender's mark at its head and the words beside it. The time the banner has
// left is that lacquer itself: it is drawn back across the body along the die's 45° a step at a time, and when the
// body is bare the banner leaves. The pointer keeps it (the engine stops its clock) and the lacquer is whole again.
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
    readonly property int pad: Airisu.u(4)
    readonly property int kiss: Airisu.kiss
    // What the engine reads the notice as (its sign and its line colour), and the notice's pigment.
    readonly property var semantic: mark.semantic ?? ({ glyph: "notifications" })
    readonly property color pigment: root.critical ? Airisu.pigment("caution")
        : Airisu.pigment("message")
    // The body under the lacquer, the lacquer, and the ink that reads on both while one is drawn back off the other.
    readonly property color bare: Airisu.solid(IrisStyle.bodySurface)
    readonly property color lacquer: root.critical ? Airisu.vivid(root.pigment) : Airisu.stockOf(root.pigment)
    readonly property color ink: root.clock ? Airisu.inkOver(root.bare, root.lacquer) : Airisu.inkOn(root.lacquer)
    readonly property color inkSecond: ColorUtils.mix(root.ink, root.lacquer, 0.72) // iris-literal: second tone on the notice
    readonly property color inkThird: ColorUtils.mix(root.ink, root.lacquer, 0.52) // iris-literal: third tone on the notice
    implicitHeight: Math.max(slip.implicitHeight, mark.height) + 2 * root.pad + 2 * root.kiss

    // The engine's clock for this banner; gone once the pointer has kept it, absent when it never times out.
    readonly property var clock: root.notification?.timer ?? null
    property real torn: 0
    onClockChanged: if (!root.clock) root.torn = 0
    Timer {
        running: root.clock !== null && root.visible
        repeat: true
        triggeredOnStart: true
        // Forty steps over the banner's time: the coat only moves when a step goes, so nothing is drawn in between.
        interval: Math.max(40, Math.round(Number(root.clock?.interval ?? 4000) / 40))
        onTriggered: {
            const span = Math.max(1, Number(root.clock?.interval ?? 1))
            const born = Number(root.notification?.time ?? Date.now())
            root.torn = Math.min(1, Math.max(0, (Date.now() - born) / span))
        }
    }

    // The lacquer is laid as the banner lands.
    property bool landed: !Airisu.moving
    Timer { running: !root.landed; interval: IrisStyle.emergeDuration; onTriggered: root.landed = true }

    Item {
        id: sheet
        anchors.fill: parent

        // The notice's lacquer, drawn back as its time goes; whole while kept or when it never times out.
        ALacquer {
            x: root.kiss
            y: root.kiss
            width: root.width - 2 * root.kiss
            height: root.height - 2 * root.kiss
            cut: Math.max(2, Airisu.chamfer - root.kiss)
            lacquer: "transparent"
            coat: root.lacquer
            share: !root.landed ? 0 : root.clock ? 1 - root.torn : 1
            travel: root.landed && root.torn === 0 ? Airisu.tear : 0
        }
        IrisNotificationIcon {
            id: mark
            x: root.kiss + root.pad
            y: root.kiss + root.pad
            size: Airisu.u(10)
            appName: root.app
            appIcon: String(root.notification?.appIcon ?? "")
            image: String(root.notification?.image ?? "")
            summary: String(root.notification?.summary ?? "")
            critical: root.critical
        }

        // The slip.
        Column {
            id: slip
            x: mark.x + mark.width + Airisu.u(3)
            y: root.kiss + root.pad
            width: root.width - x - root.pad - root.kiss

            Item {
                id: rubyLine
                width: parent.width
                height: appLabel.implicitHeight
                AText {
                    id: appLabel
                    width: Math.min(implicitWidth, parent.width - when.implicitWidth - Airisu.u(2))
                    size: IrisStyle.typeFootnote
                    font.weight: Font.Bold
                    color: root.inkSecond
                    text: root.app.length > 0 && root.app !== root.title ? root.app : ""
                }
                AText {
                    id: when
                    anchors.right: parent.right
                    visible: !root.hovered
                    size: IrisStyle.typeFootnote
                    font.weight: Font.Medium
                    color: root.inkThird
                    text: {
                        const seconds = Math.max(0, Math.floor((root.now - Number(root.notification?.time ?? root.now)) / 1000))
                        return seconds < 60 ? Translation.tr("now")
                            : seconds < 3600 ? Translation.tr("%1m").arg(Math.floor(seconds / 60))
                            : Translation.tr("%1h").arg(Math.floor(seconds / 3600))
                    }
                }
            }
            AText {
                width: parent.width
                topPadding: Math.round(2 * root.d)
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
                topPadding: Math.round(2 * root.d)
                size: IrisStyle.typeLabel
                font.weight: Font.Normal
                wrapMode: Text.Wrap
                maximumLineCount: root.hovered ? 8 : 2
                lineHeight: 1.08
                color: root.ink
                text: root.message
            }
            Flow {
                width: parent.width
                visible: root.actions.length > 0
                topPadding: Airisu.u(3)
                spacing: Airisu.u(2)
                Repeater {
                    model: root.actions
                    IrisButton {
                        id: action
                        required property var modelData
                        text: String(action.modelData.text ?? "")
                        implicitHeight: Airisu.u(7)
                        implicitWidth: Math.min(slip.width, Math.ceil(measure.advanceWidth) + Airisu.u(6))
                        onClicked: Notifications.attemptInvokeAction(root.notification.notificationId, action.modelData.identifier)
                        TextMetrics {
                            id: measure
                            font.family: Airisu.textFace
                            font.pixelSize: IrisStyle.typeLabel
                            font.weight: Font.DemiBold
                            text: action.text
                        }
                    }
                }
            }
        }

        // Kept, it can be put away: the key stands where the time was.
        IrisButton {
            id: dismiss
            quiet: true
            visible: root.hovered
            width: Airisu.u(6)
            height: Airisu.u(6)
            x: root.width - root.kiss - root.pad - width + Airisu.u(1)
            y: slip.y + Math.round((rubyLine.height - height) / 2)
            Accessible.name: Translation.tr("Dismiss")
            onClicked: Notifications.timeoutNotification(root.notification.notificationId)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: Math.round(16 * root.d)
                color: root.ink
            }
        }

    }
}
