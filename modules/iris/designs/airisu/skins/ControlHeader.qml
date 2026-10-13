import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's Control Center heading: a leaf of a tear-off calendar (日めくり). The day set large in the figures' face, the
// weekday beside it and the month under the weekday as ruby. As such calendars print it, a Sunday's figure is in the
// vermilion and a Saturday's in blue. The line the pointer writes (a control's name and state) takes the month's place
// in the ink; while the panel is arranged the leaf gives way to the title and how to arrange it.
Item {
    id: root
    property Item host
    readonly property bool editing: root.host?.editing ?? false
    readonly property string hint: root.host?.hint ?? ""
    readonly property var date: DateTime.clock.date
    readonly property int weekday: root.date.getDay()
    implicitHeight: Math.max(figure.implicitHeight, words.implicitHeight)

    AText {
        id: figure
        visible: !root.editing
        anchors.verticalCenter: parent.verticalCenter
        voice: "figure"
        lean: Airisu.lean
        size: IrisStyle.typeDisplay
        text: Qt.formatDate(root.date, "d")
        color: root.weekday === 0 ? Airisu.sealText : root.weekday === 6 ? IrisStyle.identity.blue : Airisu.ink
    }
    Column {
        id: words
        x: root.editing ? 0 : figure.width + Airisu.u(2.5)
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - x
        spacing: 0
        AText {
            width: parent.width
            size: root.editing ? IrisStyle.typeHeadline : IrisStyle.typeLabel
            font.weight: Font.Bold
            text: {
                if (root.editing) return Translation.tr("Arrange the Control Center")
                const day = Translation.locale.toString(root.date, "dddd")
                return day.charAt(0).toUpperCase() + day.slice(1)
            }
        }
        AText {
            width: parent.width
            voice: "ruby"
            text: root.hint.length > 0 ? root.hint
                : root.editing ? Translation.tr("Drag to reorder, drag a corner to resize, − takes it out")
                : Translation.locale.toString(root.date, "MMMM yyyy")
            color: root.hint.length > 0 ? Airisu.ink : Airisu.inkSecond
        }
    }
}
