import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's notice in a list (the Control Center's, Today's): a line of a timetable (時刻表). When it came stands first in
// the data face, then a bar in the line colour of what it is about, the way a departure board marks each line; then the
// sender as a ruby in the data face's capitals over the subject, and the newest words under it. How many are waiting is
// a figure at the end. The pointer brings the row's crop marks and, where the figure stood, the key that puts the whole
// group away. The host keeps the tap (it opens the newest) and the dismissal.
Item {
    id: root
    property var host
    readonly property var newest: root.host?.newest ?? null
    readonly property string app: String(root.host?.modelData ?? "")
    readonly property int count: Number(root.host?.count ?? 0)
    readonly property bool hovered: (root.host?.hovered ?? false) && !(root.host?.editing ?? false)
    readonly property int lines: Number(root.host?.lines ?? 2)
    readonly property bool critical: ["2", "critical"].includes(String(root.newest?.urgency ?? "").toLowerCase())
    readonly property real d: Airisu.d
    readonly property int pad: Airisu.u(2)
    readonly property int clockWidth: Airisu.u(9)
    implicitHeight: Math.max(words.implicitHeight, Airisu.u(9)) + 2 * root.pad

    property real now: Date.now()
    Timer { interval: 30000; running: root.visible; repeat: true; onTriggered: root.now = Date.now() }

    // What the engine reads the notice as: its line colour.
    IrisNotificationIcon {
        id: reading
        visible: false
        appName: root.app
        appIcon: String(root.host?.group?.appIcon ?? "")
        summary: String(root.newest?.summary ?? "")
        critical: root.critical
    }

    AText {
        id: clock
        x: 0
        y: root.pad + Math.round(2 * root.d)
        width: root.clockWidth
        voice: "data"
        size: IrisStyle.typeFootnote
        color: root.critical ? Airisu.caution : Airisu.inkThird
        text: {
            const seconds = Math.max(0, Math.floor((root.now - Number(root.newest?.time ?? root.now)) / 1000))
            return seconds < 60 ? Translation.tr("now")
                : seconds < 3600 ? Translation.tr("%1m").arg(Math.floor(seconds / 60))
                : seconds < 86400 ? Translation.tr("%1h").arg(Math.floor(seconds / 3600))
                : Qt.formatDate(new Date(Number(root.newest?.time ?? root.now)), "d/M")
        }
    }
    Rectangle {
        id: line
        x: root.clockWidth
        y: root.pad
        width: Math.max(2, Math.round(3 * root.d))
        height: root.height - 2 * root.pad
        color: root.critical ? Airisu.tape : (reading.semantic?.tint ?? IrisStyle.identity.gray)
        antialiasing: false
    }
    Column {
        id: words
        x: line.x + line.width + Airisu.u(3)
        y: root.pad
        width: root.width - x - tail.width - Airisu.u(2)
        spacing: 0
        AText {
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeCaption
            color: Airisu.inkSecond
            text: root.app
        }
        AText {
            width: parent.width
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: Airisu.ink
            text: String(root.newest?.summary || root.app)
        }
        AText {
            width: parent.width
            visible: text.length > 0
            size: IrisStyle.typeFootnote
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            maximumLineCount: root.lines
            color: Airisu.inkSecond
            text: String(root.newest?.body ?? "").replace(/<[^>]*>/g, "")
        }
    }
    // How many wait, or, under the pointer, the key that puts them away.
    Item {
        id: tail
        anchors.right: parent.right
        y: root.pad
        width: Airisu.u(7)
        height: Airisu.u(6)
        AText {
            anchors.right: parent.right
            visible: !root.hovered && root.count > 1
            voice: "figure"
            lean: Airisu.lean
            size: IrisStyle.typeHeadline
            color: Airisu.inkSecond
            text: "×" + root.count
        }
        IrisButton {
            anchors.right: parent.right
            visible: root.hovered
            quiet: true
            width: Airisu.u(6)
            height: Airisu.u(6)
            Accessible.name: Translation.tr("Dismiss")
            onClicked: root.host?.dismissAll()
            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: Math.round(14 * root.d)
                color: Airisu.ink
            }
        }
    }
    AMarks {
        anchors.fill: parent
        anchors.leftMargin: -Airisu.u(1)
        shown: root.hovered
        gap: Math.round(Airisu.m / 2)
    }
}
