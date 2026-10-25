pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components

// Ledger: the day as an entry (weekday over the date) beside the time, a hairline between. Only the resting clock;
// the engine draws media, timers, notices and levels.
Item {
    id: root
    property var island: null
    readonly property var modes: ["idle", "clock"]
    readonly property real d: IrisStyle.density
    readonly property real h: root.island?.compactHeight ?? 42
    // A slim strip keeps the day on the time's line.
    readonly property bool stacks: root.h >= Math.round(34 * root.d)
    readonly property real contentWidth: row.implicitWidth
    readonly property date now: DateTime.clock.date
    readonly property color mark: root.island?.clockAccent ?? IrisStyle.accent

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(10 * root.d)

        Column {
            visible: root.stacks
            anchors.verticalCenter: parent.verticalCenter
            IrisText {
                text: Translation.locale.toString(root.now, "dddd").toUpperCase()
                font.pixelSize: Math.round(9 * root.d)
                font.weight: IrisStyle.weight(Font.Bold)
                font.letterSpacing: 1.1
                color: root.mark
            }
            IrisText {
                text: Translation.locale.toString(root.now, "d MMM").replace(/\.$/, "")
                font.pixelSize: Math.round(12 * root.d)
                font.weight: IrisStyle.weight(Font.Medium)
                color: IrisStyle.subtext
            }
        }
        IrisText {
            visible: !root.stacks
            anchors.verticalCenter: parent.verticalCenter
            text: Translation.locale.toString(root.now, "ddd d").replace(/\./g, "").toUpperCase()
            font.pixelSize: Math.round(11 * root.d)
            font.weight: IrisStyle.weight(Font.DemiBold)
            font.letterSpacing: 0.8
            color: IrisStyle.subtext
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Math.round(root.h * 0.46)
            color: IrisStyle.hairline
        }
        IrisClock {
            anchors.verticalCenter: parent.verticalCenter
            pixelSize: root.island?.figureSize ?? IrisStyle.typeHeadline
            family: root.island?.nothingLook ? IrisStyle.fontDot : IrisStyle.figureFace(pixelSize)
            separatorColor: root.mark
        }
    }
}
