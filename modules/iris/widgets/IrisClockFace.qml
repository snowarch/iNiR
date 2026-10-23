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

    readonly property string faceKind: String(root.widget.irisOption("face", "analog"))
    readonly property bool analog: root.faceKind === "analog"
    // SekaiPop's KEYS clock in iRiS: each digit on its own key, a beat between hours and minutes, the week under them.
    readonly property bool keys: root.faceKind === "keys"
    readonly property bool seconds: Boolean(root.widget.irisOption("seconds", true))
    readonly property var now: clock.date
    readonly property string timePattern: {
        const format = String(root.widget.timeFormat ?? "system")
        if (format === "24h") return "HH:mm"
        if (format === "12h") return "h:mm AP"
        return String(Config.options?.time?.format ?? "hh:mm").replace(/:ss/, "")
    }
    readonly property bool twelve: /AP|ap/.test(root.timePattern)
    readonly property string timeText: Translation.locale.toString(root.now, root.timePattern)
    readonly property string weekday: {
        const name = Translation.locale.toString(root.now, "dddd")
        return name.charAt(0).toUpperCase() + name.slice(1)
    }
    readonly property string longDate: Translation.locale.toString(root.now, "d MMMM")
    readonly property string hourDigits: Translation.locale.toString(root.now, root.twelve ? "hh" : "HH")
    readonly property string minuteDigits: Translation.locale.toString(root.now, "mm")
    readonly property bool morning: root.now.getHours() < 12
    // Monday first, as the calendar.
    readonly property int weekIndex: (root.now.getDay() + 6) % 7
    readonly property bool beating: root.keys && root.seconds && root.moving

    // A Design may print its own clock (AIRISU's date stamp): the dial and the figures step aside for it.
    designFace: IrisDesign.skin("widgetClock")
    padding: root.analog && root.small ? root.dp(8) : root.edgePad

    SystemClock {
        id: clock
        precision: (root.analog || root.keys) && root.seconds && root.moving ? SystemClock.Seconds : SystemClock.Minutes
    }

    // One digit on a raised key; a changed digit rolls (FaceFigure).
    component Key: Rectangle {
        id: key
        property string digit: "0"
        property real figure: 40
        property bool lead: true
        radius: Math.min(root.innerRadius, width * 0.28)
        color: key.lead ? root.fill : root.fillQuiet
        border.width: 1
        border.color: root.hairline
        FaceFigure {
            face: root
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(key.figure * 0.02)
            text: key.digit
            size: key.figure
            tone: key.lead ? root.ink : root.highlight
        }
        // The fold across the middle of a flip key.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Qt.alpha(root.knockout, 0.35)
        }
    }

    // Two dots between hours and minutes taking turns once a second.
    component Beat: Column {
        property real dot: root.dp(6)
        spacing: dot
        Repeater {
            model: 2
            Rectangle {
                required property int index
                width: parent.dot
                height: width
                radius: width / 2
                color: root.highlight
                opacity: !root.beating ? 1 : (root.now.getSeconds() + index) % 2 === 0 ? 1 : 0.28
                Behavior on opacity { enabled: root.beating; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }
    }

    // The four keys in a row (or two rows of two when stacked).
    component Time: GridLayout {
        id: time
        property real figure: 40
        property bool stacked: false
        columns: time.stacked ? 2 : 5
        rowSpacing: root.dp(6)
        columnSpacing: root.dp(time.stacked ? 6 : 5)
        Key { Layout.fillWidth: true; Layout.fillHeight: true; digit: root.hourDigits.charAt(0); figure: time.figure }
        Key { Layout.fillWidth: true; Layout.fillHeight: true; digit: root.hourDigits.charAt(1); figure: time.figure }
        Beat { visible: !time.stacked; Layout.alignment: Qt.AlignCenter; dot: root.dp(time.figure > 50 ? 8 : 6) }
        Key { Layout.fillWidth: true; Layout.fillHeight: true; digit: root.minuteDigits.charAt(0); figure: time.figure; lead: false }
        Key { Layout.fillWidth: true; Layout.fillHeight: true; digit: root.minuteDigits.charAt(1); figure: time.figure; lead: false }
    }

    // The week: today is the chosen capsule.
    component Week: RowLayout {
        spacing: root.dp(3)
        Repeater {
            model: 7
            Rectangle {
                id: weekday
                required property int index
                readonly property bool today: weekday.index === root.weekIndex
                Layout.fillWidth: true
                implicitHeight: root.dp(20)
                radius: height / 2
                color: weekday.today ? root.accent : "transparent"
                FaceText {
                    face: root
                    anchors.centerIn: parent
                    // Monday 2024-01-01 is a fixed Monday: its week gives the locale's narrow names in order.
                    text: Translation.locale.toString(new Date(2024, 0, 1 + weekday.index), "ddd").replace(/\./g, "").slice(0, 2)
                    size: 10.5
                    weight: weekday.today ? Font.DemiBold : Font.Medium
                    color: weekday.today ? root.onFill(root.accent) : weekday.index >= 5 ? root.inkTertiary : root.inkSecondary
                }
            }
        }
    }

    // The minute's seconds as a lane with a dot that hops along it.
    component Lane: Item {
        implicitHeight: root.dp(6)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.dp(3)
            radius: height / 2
            color: root.fill
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.dp(6)
            height: width
            radius: width / 2
            color: root.highlight
            x: (parent.width - width) * root.now.getSeconds() / 59
            Behavior on x { enabled: root.beating; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        }
    }

    FaceDial {
        id: dial
        visible: root.analog && !root.designed
        face: root
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.small ? parent.width : parent.height
        height: width
        time: root.now
        seconds: root.seconds
        caption: root.small ? Translation.locale.toString(root.now, "ddd d").replace(/\./g, "") : ""
    }

    ColumnLayout {
        visible: !root.keys && (!root.analog || !root.small) && !root.designed
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

    // Keys, small: the date over two rows of keys.
    ColumnLayout {
        visible: root.keys && root.small && !root.designed
        anchors.fill: parent
        spacing: root.dp(6)
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(4)
            FaceText {
                face: root
                text: Translation.locale.toString(root.now, "ddd").replace(/\./g, "")
                color: root.highlight
                size: 12.5
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: Translation.locale.toString(root.now, "d MMM").replace(/\./g, "")
                color: root.inkSecondary
                size: 12.5
            }
            FaceText {
                face: root
                visible: root.twelve
                text: root.morning ? "AM" : "PM"
                color: root.inkSecondary
                size: 11
                weight: Font.DemiBold
            }
        }
        Time {
            Layout.fillWidth: true
            Layout.fillHeight: true
            stacked: true
            figure: 34
        }
    }

    // Keys, medium and large: the date line, the keys, the seconds lane and the week.
    ColumnLayout {
        visible: root.keys && !root.small && !root.designed
        anchors.fill: parent
        spacing: root.dp(root.large ? 12 : 7)
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(6)
            FaceText {
                face: root
                text: root.weekday
                color: root.highlight
                size: root.large ? 15 : 13
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.longDate
                color: root.inkSecondary
                size: root.large ? 15 : 13
            }
            // AM / PM as a two-way key, the hour's half lit.
            Rectangle {
                visible: root.twelve
                implicitWidth: meridiem.implicitWidth + root.dp(4)
                implicitHeight: root.dp(20)
                radius: height / 2
                color: root.fillQuiet
                Row {
                    id: meridiem
                    anchors.centerIn: parent
                    Repeater {
                        model: ["AM", "PM"]
                        Rectangle {
                            id: half
                            required property string modelData
                            required property int index
                            readonly property bool lit: (half.index === 0) === root.morning
                            width: halfText.implicitWidth + root.dp(10)
                            height: root.dp(16)
                            radius: height / 2
                            color: half.lit ? root.fillActive : "transparent"
                            FaceText {
                                id: halfText
                                face: root
                                anchors.centerIn: parent
                                text: half.modelData
                                size: 10
                                weight: Font.DemiBold
                                color: half.lit ? root.ink : root.inkTertiary
                            }
                        }
                    }
                }
            }
        }
        Time {
            Layout.fillWidth: true
            Layout.fillHeight: true
            figure: root.large ? 76 : 44
        }
        Lane {
            visible: root.seconds
            Layout.fillWidth: true
        }
        Week { Layout.fillWidth: true }
        // Large: where the year stands.
        FaceText {
            face: root
            visible: root.large
            Layout.fillWidth: true
            text: {
                const start = new Date(root.now.getFullYear(), 0, 1)
                const day = Math.floor((root.now - start) / 86400000) + 1
                const thursday = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate() + 3 - root.weekIndex)
                const week = 1 + Math.round(((thursday - new Date(thursday.getFullYear(), 0, 4)) / 86400000 - 3 + (new Date(thursday.getFullYear(), 0, 4).getDay() + 6) % 7) / 7)
                return Translation.tr("Week %1 · Day %2 of the year").arg(week).arg(day)
            }
            color: root.inkTertiary
            size: 12
        }
    }
}
