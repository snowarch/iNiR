pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's notification banner (SYSTEM.md §7): a ticket. The stub keeps the sender's mark; a perforation runs between
// it and the slip, and the time the banner has left is that perforation torn hole by hole from the top: when the last
// hole goes, the banner leaves. The pointer keeps it (the engine stops its clock) and the perforation is whole again.
// The slip is set like a station sign: the app as ruby over the title, the message, the actions as tags, and the
// notice's line colour as a short band on the bottom edge; a critical notice runs caution tape there instead. It lands
// as a stamp does, its ink a step out of register until it settles. IrisBanners keeps the list, the swipe, the clock,
// the tap and the body; this is what the body holds.
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
    readonly property int stub: Airisu.u(16)
    // What the engine reads the notice as (its sign and its line colour).
    readonly property var semantic: mark.semantic ?? ({ glyph: "notifications" })
    implicitHeight: Math.max(slip.implicitHeight, mark.height) + 2 * root.pad

    // The engine's clock for this banner; gone once the pointer has kept it, absent when it never times out.
    readonly property var clock: root.notification?.timer ?? null
    property real torn: 0
    onClockChanged: if (!root.clock) root.torn = 0
    Timer {
        running: root.clock !== null && root.visible
        repeat: true
        triggeredOnStart: true
        // A step per hole: the line only changes when a hole goes, so nothing is drawn in between.
        interval: Math.max(40, Math.round(Number(root.clock?.interval ?? 4000) / Math.max(1, perforation.holes)))
        onTriggered: {
            const span = Math.max(1, Number(root.clock?.interval ?? 1))
            const born = Number(root.notification?.time ?? Date.now())
            root.torn = Math.min(1, Math.max(0, (Date.now() - born) / span))
        }
    }

    // The stamp comes down a step out of register and settles as the banner lands.
    property bool landed: !Airisu.moving
    Timer { running: !root.landed; interval: IrisStyle.emergeDuration; onTriggered: root.landed = true }

    Item {
        id: sheet
        anchors.fill: parent
        transform: Translate {
            x: root.landed ? 0 : Airisu.registration
            y: root.landed ? 0 : Airisu.registration
            Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
            Behavior on y { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        }

        // The stub: the sender's mark.
        IrisNotificationIcon {
            id: mark
            x: root.pad
            y: root.pad
            size: Airisu.u(9)
            appName: root.app
            appIcon: String(root.notification?.appIcon ?? "")
            image: String(root.notification?.image ?? "")
            summary: String(root.notification?.summary ?? "")
            critical: root.critical
        }
        APerforation {
            id: perforation
            x: root.stub - Math.round(width / 2)
            height: root.height
            vertical: true
            fromStart: true
            torn: root.torn
            colour: Airisu.inkThird
        }

        // The slip.
        Column {
            id: slip
            x: root.stub + root.pad
            y: root.pad
            width: root.width - x - root.pad

            Item {
                id: rubyLine
                width: parent.width
                height: appLabel.implicitHeight
                AText {
                    id: appLabel
                    width: Math.min(implicitWidth, parent.width - when.implicitWidth - Airisu.u(2))
                    voice: "ruby"
                    text: root.app.length > 0 && root.app !== root.title ? root.app : ""
                }
                AText {
                    id: when
                    anchors.right: parent.right
                    visible: !root.hovered
                    voice: "ruby"
                    color: Airisu.inkThird
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
            x: root.width - root.pad - width + Airisu.u(1)
            y: slip.y + Math.round((rubyLine.height - height) / 2)
            Accessible.name: Translation.tr("Dismiss")
            onClicked: Notifications.timeoutNotification(root.notification.notificationId)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: Math.round(16 * root.d)
                color: Airisu.ink
            }
        }

        // The line the notice belongs to, as on a station sign: a short band on the bottom edge. A notice the engine
        // cannot place on a line gets none.
        Rectangle {
            visible: !root.critical && root.semantic.glyph !== "notifications"
            x: slip.x
            y: root.height - height
            width: Airisu.u(8)
            height: Airisu.m
            color: root.semantic.tint ?? Airisu.rule
        }
        // A critical notice runs caution tape along the slip's foot instead, as wide as its words.
        Item {
            visible: root.critical
            x: slip.x
            y: root.height - height
            width: slip.width
            height: Math.round(1.5 * Airisu.m)
            clip: true
            Rectangle {
                anchors.fill: parent
                color: Airisu.caution
            }
            Image {
                readonly property int cell: 2 * Airisu.m
                readonly property int half: Math.round(cell / 2)
                anchors.fill: parent
                fillMode: Image.Tile
                smooth: false
                horizontalAlignment: Image.AlignLeft
                verticalAlignment: Image.AlignTop
                // Tiger tape is the caution plate and the darkest ink there is on this stock.
                readonly property color stripe: ColorUtils.relativeLuminance(Airisu.ink) < ColorUtils.relativeLuminance(Airisu.inkOnCaution)
                    ? Airisu.ink : Airisu.inkOnCaution
                source: Airisu.svgCell(cell, cell,
                    `<polygon points='0,${half} ${half},0 ${cell},0 0,${cell}'/><polygon points='${cell},${half} ${cell},${cell} ${half},${cell}'/>`,
                    stripe)
            }
        }
    }
}
