pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

IrisWidgetFace {
    id: root

    readonly property bool analog: String(root.widget.irisOption("face", "analog")) === "analog"
    readonly property bool seconds: Boolean(root.widget.irisOption("seconds", true))
    readonly property var now: clock.date
    readonly property string timePattern: {
        const format = String(root.widget.timeFormat ?? "system")
        if (format === "24h") return "HH:mm"
        if (format === "12h") return "h:mm AP"
        return String(Config.options?.time?.format ?? "hh:mm").replace(/:ss/, "")
    }
    readonly property string timeText: Translation.locale.toString(root.now, root.timePattern)
    readonly property string weekday: {
        const name = Translation.locale.toString(root.now, "dddd")
        return name.charAt(0).toUpperCase() + name.slice(1)
    }
    readonly property string longDate: Translation.locale.toString(root.now, "d MMMM")

    // A Design may print its own clock (AIRISU's date stamp): the dial and the figures step aside for it.
    designFace: IrisDesign.skin("widgetClock")
    padding: root.analog && root.small ? root.dp(8) : root.edgePad

    SystemClock {
        id: clock
        precision: root.analog && root.seconds && root.moving ? SystemClock.Seconds : SystemClock.Minutes
    }

    FaceDial {
        id: dial
        visible: root.analog && !root.designed
        face: root
        // Large: the dial leads above the week; medium: beside the date. Placed by x/y: anchors switched per size
        // left the dial at the old size's width after a size change (10-23).
        width: root.small ? parent.width : root.large ? Math.min(parent.width, parent.height - footer.height - root.dp(14)) : parent.height
        height: width
        x: root.large ? Math.round((parent.width - width) / 2) : 0
        y: root.large ? 0 : Math.round((parent.height - height) / 2)
        time: root.now
        seconds: root.seconds
        caption: root.small ? Translation.locale.toString(root.now, "ddd d").replace(/\./g, "")
            : root.large ? Translation.locale.toString(root.now, "d MMM").replace(/\./g, "") : ""
    }

    ColumnLayout {
        id: column
        visible: (!root.analog || root.medium) && !root.designed
        anchors.left: root.analog ? dial.right : parent.left
        anchors.leftMargin: root.analog ? root.dp(18) : 0
        anchors.right: parent.right
        y: root.large ? 0 : Math.round((parent.height - height) / 2)
        spacing: root.dp(2)

        // The week strip says the weekday wherever it shows.
        FaceText {
            face: root
            visible: root.small
            Layout.fillWidth: true
            text: root.weekday
            color: root.highlight
            size: root.small ? 13 : 14
            weight: Font.DemiBold
        }
        // Beside a dial the hour is already read: the figure there is the date.
        FaceFigure {
            face: root
            visible: root.analog
            Layout.fillWidth: true
            text: Translation.locale.toString(root.now, "d MMMM")
            size: 30
        }
        IrisClock {
            visible: !root.analog
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            text: root.timeText
            pixelSize: root.px(root.small ? 42 : root.large ? 86 : 58)
            weight: root.figureWeight
            color: root.ink
            separatorColor: root.highlight
            family: root.fontNumbers
        }
        FaceText {
            face: root
            visible: !root.analog
            Layout.fillWidth: true
            text: root.longDate
            color: root.inkSecondary
            size: root.small ? 12.5 : 13.5
        }
        Week {
            visible: !root.small && !root.large
            Layout.fillWidth: true
            Layout.topMargin: root.dp(6)
        }
    }

    // Large: the week as the foot, under the dial or the big digits.
    ColumnLayout {
        id: footer
        visible: root.large && !root.designed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: root.dp(10)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        Week { Layout.fillWidth: true }
    }

    // The week, today as the chosen capsule.
    component Week: RowLayout {
        spacing: root.dp(3)
        Repeater {
            model: 7
            Rectangle {
                id: weekday
                required property int index
                readonly property bool today: weekday.index === (root.now.getDay() + 6) % 7
                Layout.fillWidth: true
                implicitHeight: root.dp(20)
                radius: height / 2
                color: weekday.today ? root.highlight : "transparent"
                FaceText {
                    face: root
                    anchors.centerIn: parent
                    // 2024-01-01 was a Monday: its week gives the locale's day names in order.
                    text: Translation.locale.toString(new Date(2024, 0, 1 + weekday.index), "ddd").replace(/\./g, "").slice(0, 2)
                    size: 10.5
                    weight: weekday.today ? Font.DemiBold : Font.Medium
                    color: weekday.today ? root.onFill(root.highlight) : weekday.index >= 5 ? root.inkTertiary : root.inkSecondary
                }
            }
        }
    }
}
