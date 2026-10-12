pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's notification (board Desktop): a vermilion countdown along the top edge, the app in mono with the time at
// the right, the sender bold and the message to read, and the actions as mono words. A critical one is kerria amber:
// its frame, the warning tape down its side and its first action filled. IrisBanners keeps the list, the swipe,
// the timeout and the body; this is what the plate holds.
Item {
    id: root
    property var notification
    property bool hovered: false
    property real now: Date.now()
    signal activated()
    readonly property real d: Airisu.d
    // The service keeps the urgency as the enum's number in a string ("2" is critical).
    readonly property bool critical: ["2", "critical"].includes(String(root.notification?.urgency ?? "").toLowerCase())
    readonly property var actions: (root.notification?.actions ?? []).filter(action => action.identifier !== "default")
    readonly property int lifetime: Math.max(1000, Number(Config.options?.iris?.notifications?.duration ?? 4000))
    implicitHeight: column.implicitHeight + Math.round(36 * root.d)

    // The countdown: the seal shrinking to the left; held still while the pointer rests on it.
    Rectangle {
        id: countdown
        visible: !root.critical
        height: Math.round(4 * root.d)
        color: Airisu.seal
        property real remaining: 1
        width: Math.round((parent.width - IrisStyle.chamferCut) * countdown.remaining)
        NumberAnimation on remaining {
            id: run
            from: 1; to: 0
            duration: root.lifetime
            running: !root.critical && IrisStyle.motionEnabled
            paused: root.hovered
        }
    }

    // Critical: an amber frame and the warning tape standing down the left edge.
    Rectangle {
        anchors.fill: parent
        visible: root.critical
        color: "transparent"
        border.width: Airisu.line
        border.color: Airisu.amber
    }
    Item {
        id: tape
        visible: root.critical
        width: Math.round(8 * root.d)
        height: parent.height
        clip: true
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Airisu.amber
                strokeColor: "transparent"
                PathPolyline {
                    path: {
                        const out = []
                        const step = Math.round(10 * root.d)
                        for (let y = -tape.width; y < root.height + step; y += step * 2)
                            out.push(Qt.point(0, y), Qt.point(tape.width, y - tape.width), Qt.point(tape.width, y - tape.width + step),
                                Qt.point(0, y + step), Qt.point(0, y))
                        return out
                    }
                }
            }
        }
    }

    Column {
        id: column
        x: Math.round(18 * root.d) + (root.critical ? tape.width : 0)
        y: Math.round(20 * root.d)
        width: parent.width - x - Math.round(18 * root.d)
        spacing: Math.round(3 * root.d)

        Item {
            width: parent.width
            height: meta.implicitHeight
            AText {
                id: meta
                width: Math.min(implicitWidth, parent.width - when.implicitWidth - Airisu.gap)
                voice: "mono"
                color: root.critical ? Airisu.amber : Airisu.data
                text: String(root.notification?.appName ?? "")
            }
            AText {
                id: when
                anchors.right: parent.right
                voice: "mono"
                color: Airisu.quiet
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
            font.weight: Font.ExtraBold
            text: String(root.notification?.summary || root.notification?.appName || "")
        }
        AText {
            width: parent.width
            visible: text.length > 0
            size: IrisStyle.typeLabel
            font.weight: Font.Normal
            color: Airisu.data
            wrapMode: Text.Wrap
            maximumLineCount: root.hovered ? 8 : 2
            text: String(root.notification?.body ?? "").replace(/<[^>]*>/g, "")
        }
        Row {
            visible: root.actions.length > 0
            topPadding: Math.round(10 * root.d)
            spacing: Math.round(8 * root.d)
            Repeater {
                model: root.actions
                ASeal {
                    required property var modelData
                    required property int index
                    kind: root.critical && index === 0 ? "amber" : "line"
                    implicitHeight: Math.round(30 * root.d)
                    text: String(modelData.text ?? "")
                    onClicked: Notifications.attemptInvokeAction(root.notification.notificationId, modelData.identifier)
                }
            }
            ASeal {
                kind: "line"
                implicitHeight: Math.round(30 * root.d)
                text: Translation.tr("Dismiss")
                onClicked: Notifications.timeoutNotification(root.notification.notificationId)
            }
        }
    }
}
