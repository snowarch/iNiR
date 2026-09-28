pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
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
    readonly property string timeText: Qt.locale().toString(root.now, root.timePattern)
    readonly property string weekday: {
        const name = Qt.locale().toString(root.now, "dddd")
        return name.charAt(0).toUpperCase() + name.slice(1)
    }
    readonly property string longDate: Qt.locale().toString(root.now, "d MMMM")

    padding: root.analog && root.small ? root.dp(8) : root.dp(16)

    SystemClock {
        id: clock
        precision: root.analog && root.seconds && root.live ? SystemClock.Seconds : SystemClock.Minutes
    }

    FaceDial {
        id: dial
        visible: root.analog
        face: root
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.small ? parent.width : parent.height
        height: width
        time: root.now
        seconds: root.seconds
        caption: root.small ? Qt.locale().toString(root.now, "ddd d").replace(/\./g, "") : ""
    }

    ColumnLayout {
        visible: !root.analog || !root.small
        anchors.left: root.analog ? dial.right : parent.left
        anchors.leftMargin: root.analog ? root.dp(18) : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.dp(2)

        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.weekday
            color: root.highlight
            size: root.small ? 13 : 14
            weight: Font.DemiBold
        }
        IrisClock {
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            text: root.timeText
            pixelSize: root.px(root.small ? 42 : root.analog ? 46 : 58)
            weight: root.figureWeight
            color: root.ink
            separatorColor: root.highlight
            family: root.fontNumbers
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.longDate
            color: root.inkSecondary
            size: root.small ? 12.5 : 13.5
        }
    }
}
